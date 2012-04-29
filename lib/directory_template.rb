# encoding: utf-8



require 'fileutils'
require 'directory_template/process_data'
require 'directory_template/processor'
require 'directory_template/version'



# @version: 1.0.0
#
# DirectoryTemplate
# Create directory structures from template directory structures or template data.
#
# Preregistered processors
# * '*.stop': Stops the preprocessing chain, it's advised to add that to all files for
#             future-proofness.
class DirectoryTemplate
  # All registered processors
  Processors = []

  # The standard processor for file- and directory-paths. It simply uses String#% style
  # keyword replacement. I.e., "%\{key}" is replaced by the variable value passed with :key.
  StandardPathProcessor = proc { |data|
    data.path = data.path % data.path_variables if data.path_variables
  }

  # The default options used by DirectoryTemplate
  DefaultOptions  = {
    :verbose        => false,
    :silent         => false,
    :out            => $stdout,
    :processors     => Processors,
    :path_processor => StandardPathProcessor,
    :meta           => {},
  }

  # You can register custom processors for templates. They're triggered based on the
  # pattern.
  # A processor can change the ProcessData struct passed to it, which will be reflected
  # when creating the file or directory
  #
  # @param [DirectoryTemplate::Processor] processor
  #   The processor to register
  #
  def self.register(processor)
    Processors << processor
  end
  Processor.register(:stop, '*.stop', 'Terminate processing queue', 'After .stop, no processor will be run anymore') { |data| data.chomp_suffix!; throw :stop_processing }
  Processor.register_all

  # Create a DirectoryTemplate from an existing directory structure.
  def self.directory(template_path, options={})
    data    = Dir.chdir(template_path) {
      paths   =  Dir['**/{*,.*}']
      paths  -= paths.grep(/(?:^|\/)\.\.?$/)
      directories, files = paths.sort.partition { |path| File.directory?(path) }
      filemap = Hash[files.map { |path| [path, File.read(path)] }]

      {:directories => directories, :files => filemap}
    }

    new(data, options)
  end

  # @private
  # Converts a recursive hash into a suitable data structure for DirectoryTemplate::new
  def self.convert_recursive_structure(current, stack=[], dirs=[], files={})
    current.each do |segment, content|
      new_stack = stack+[segment]
      path      = new_stack.join('/')
      case content
        when String,nil
          files[path] = content || ''
        when Hash
          dirs << path
          convert_recursive_structure(content, new_stack, dirs, files)
        else
          raise "Invalid structure"
      end
    end

    return dirs, files
  end

  # Create a DirectoryTemplate from a nested hash structure.
  # The hash should just be a recursive hash of strings. Use an empty hash to indicate
  # an empty directory. Leaf-strings are considered to be the content of a file. Use nil
  # to indicate an empty file.
  def self.from_hash(hash, options=nil)
    dirs, files = convert_recursive_structure(hash)
    data        = {:directories => dirs, :files => files}

    new(data, options)
  end

  # Create a DirectoryTemplate from a YAML file.
  # The yaml should just be a recursive hash of strings. Use an empty hash to indicate
  # an empty directory. Leaf-strings are considered to be the content of a file. Use nil
  # to indicate an empty file.
  def self.yaml_file(path, options=nil)
    from_hash(YAML.load_file(path), options)
  end

  # Meta information can be used by processors. There's no requirements on them, except
  # that the toplevel container is a hash.
  attr_reader   :meta

  # @return [Array] All directories of the template
  attr_reader   :directories

  # @return [Hash<String,String>] All files of the template and their content.
  attr_reader   :files

  # @return [Array<DirectoryTemplate::Processor>] The content processors used by this template.
  attr_reader   :processors

  # @return [#call] The path processor used by this template.
  attr_reader   :path_processor

  # @return [IO, #puts] The object on which info and debug messages are printed
  attr_reader   :out

  # @private
  # @return [Boolean] Whether the current run is a dry-run or not.
  attr_reader   :dry_run

  # When true, will not even output info messages
  attr_accessor :silent

  # When true, will additionally output debug messages
  attr_accessor :verbose

  # Create a new DirectoryTemplate
  #
  # @param [Hash] data
  #   A hash with the two keys :directories and :files, where :directories contains an
  #   Array of all directory names, and :files contains a Hash of all file names and their
  #   unprocessed content.
  #
  # @param [Hash, nil] options
  #   An options hash, @see DirectoryTemplate::DefaultOptions for a list of all available
  #   options.
  #
  # @see DirectoryTemplate::directory
  #   To create a DirectoryTemplate from an existing directory structure.
  # @see DirectoryTemplate::from_yaml
  #   To create a DirectoryTemplate from a description in a YAML file.
  def initialize(data, options=nil)
    options               = options ? DefaultOptions.merge(options) : DefaultOptions.dup
    @directories          = data[:directories] || []
    @files                = data[:files] || []
    @meta                 = options.delete(:meta)
    @verbose              = options.delete(:verbose)
    @silent               = options.delete(:silent)
    @out                  = options.delete(:out)
    @processors           = options.delete(:processors)
    @path_processor       = options.delete(:path_processor)
    @dry_run              = false
    raise ArgumentError, "Unknown options: #{options.keys.join(', ')}" unless options.empty?
  end

  # Same as #materialize, but doesn't actually do anything, except print the debug and
  # info messages. It additionally prints an info message, containing the file content
  # of files that would be created.
  def dry_run(in_path='.', env={}, &on_collision)
    @dry_run = true
    materialize(in_path, env, &on_collision)
  ensure
    @dry_run = false
  end

  # Creates all the directories and files from the template in the given path.
  # @see #dry_run For a way to see what would happen with materialize
  def materialize(in_path='.', env={}, &on_collision)
    in_path = File.expand_path(in_path)
    create_directory(in_path) { "Creating root '#{in_path}'" }

    Dir.chdir(in_path) do
      if @directories.empty? then
        info { "No directories to create" }
      else
        info { "Creating directories" }
        @directories.each do |source_dir_path|
          target_dir_path = process_path(source_dir_path, env)
          create_directory(target_dir_path) { "  #{target_dir_path}" }
        end
      end
  
      if @files.empty? then
        info { "No files to create" }
      else
        info { "Creating files" }
        @files.each do |source_file_path, content|
          target_file_path  = process_path(source_file_path, env)
          data              = process_content(target_file_path, content, env)
          if File.exist?(data.path) then
            if block_given? && yield(data) then
              create_file(data.path, data.content) { "  #{data.path} (overwrite)" }
            else
              info { "  #{data.path} (exists already)" }
            end
          else
            create_file(data.path, data.content) { "  #{data.path} (new)" }
          end
        end
      end
    end

    self
  end

  # @private
  # Preprocesses the given path
  def process_path(path, env)
    ProcessData.new(self, path, nil, env).tap(&@path_processor).path
  end

  # @private
  # Preprocesses the given content
  def process_content(path, content, env)
    data = ProcessData.new(self, path, content, env)
    catch(:stop_processing) {
      #p :process_content => path, :available => @processors.size, :processors => processors_for(data).tap { |x| x && x.size }
      while processor = processor_for(data)
        debug { "  -> Applying #{processor.name}" }
        processor.call(data)
      end
    }

    data
  end

  # @private
  # Create the given directory and emit an info message (unless in dry_run mode).
  #
  # @note The mode param is currently unused.
  def create_directory(path, mode=0755, &message)
    unless File.exist?(path) then
      info(&message)
      FileUtils.mkdir_p(path) unless @dry_run
    end
  end

  # @private
  # Create the given file and emit an info message (unless in dry_run mode).
  #
  # @note The mode param is currently unused.
  def create_file(path, content="", mode=0644, &message)
    info(&message)
    if @dry_run then
      info { "  Content:\n#{content.gsub(/^/, '    ')}" }
    else
      File.open(path, 'wb:binary') do |fh|
        fh.write(content)
      end
    end
  end

  # @private
  # @param [String] path
  #   The path to extract the processor from.
  #
  # @return [Processor, nil]
  #   Returns the processor or nil
  def processor_for(data)
    @processors.enum_for(:grep, data).first
  end

  # @private
  # Emit an info string (the return value of the block). Will not be emitted if
  # DirectoryTemplate#silent is true
  def info
    @out.puts yield unless @silent
  end

  # @private
  # Emit a debug string (the return value of the block). Will only be emitted if
  # DirectoryTemplate#debug is true
  def debug
    @out.puts yield if @verbose
  end
end
