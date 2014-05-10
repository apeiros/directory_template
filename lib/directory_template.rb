# encoding: utf-8

require "fileutils"
require "directory_template/process_data"
require "directory_template/processor"
require "directory_template/version"

# @version  1.0.1
# @author   Stefan Rusterholz <stefan.rusterholz@gmail.com>
#
# DirectoryTemplate
# Create directory structures from template directory structures or template data.
#
# Preregistered processors
# * :stop: Stops the preprocessing chain, it's advised to add that to all files for
#          future-proofness.
class DirectoryTemplate

  # All registered processors
  Processors = []

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
  Processor.register_all

  # The standard path processor, just replaces `%{sprintf_style_variables}` with their
  # values.
  StandardPathProcessor = Processor::Format

  # The default options used by DirectoryTemplate
  DefaultOptions  = {
    :verbose        => false,
    :silent         => false,
    :out            => $stdout,
    :processors     => Processors,
    :path_processor => StandardPathProcessor,
    :source         => "(unknown)",
    :meta           => {},
  }

  # Create a DirectoryTemplate from an existing directory structure.
  def self.directory(template_path, options={})
    data = Dir.chdir(template_path) {
      paths   =  Dir["**/{*,.*}"]
      paths  -= paths.grep(/(?:^|\/)\.\.?$/)
      directories, files = paths.sort.partition { |path| File.directory?(path) }
      filemap = Hash[files.map { |path| [path, File.read(path)] }]

      {:directories => directories, :files => filemap}
    }

    new(data, {:source => template_path}.merge(options))
  end

  # @private
  # Converts a recursive hash into a suitable data structure for DirectoryTemplate::new
  def self.convert_recursive_structure(current, stack=[], dirs=[], files={})
    current.each do |segment, content|
      new_stack = stack + [segment]
      path      = new_stack.join("/")
      case content
        when String,nil
          files[path] = content || ""
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
  def self.from_hash(hash, options={})
    dirs, files = convert_recursive_structure(hash)
    data        = {:directories => dirs, :files => files}

    new(data, {:source => "(hash:#{caller(1,1).first})"}.merge(options))
  end

  # Create a DirectoryTemplate from a YAML file.
  # The yaml should just be a recursive hash of strings. Use an empty hash to indicate
  # an empty directory. Leaf-strings are considered to be the content of a file. Use nil
  # to indicate an empty file.
  def self.yaml_file(path, options={})
    from_hash(YAML.load_file(path), {:source => template_path}.merge(options))
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
    @source               = options.delete(:source)
    @meta                 = options.delete(:meta)
    @verbose              = options.delete(:verbose)
    @silent               = options.delete(:silent)
    @out                  = options.delete(:out)
    @processors           = options.delete(:processors)
    @path_processor       = options.delete(:path_processor)
    @dry_run              = options.delete(:dry_run) { false }
    raise ArgumentError, "Unknown options: #{options.keys.join(", ")}" unless options.empty?
  end

  # Same as #materialize, but doesn't actually do anything, except print the debug and
  # info messages. It additionally prints an info message, containing the file content
  # of files that would be created.
  def dry_run(in_path=".", env={}, &on_collision)
    @output_indent = 0
    old_dry_run = @dry_run
    @dry_run    = true
    materialize(in_path, env, &on_collision)
  ensure
    @dry_run = old_dry_run
  end

  # Creates all the directories and files from the template in the given path.
  #
  # @param [String] in_path
  #   The directory within which to generate the structure.
  #
  # @param [Hash] env
  #   A hash with various information used to generate the structure. Most important one
  #   being the :variables value.
  # @option env [Hash] :variables
  #   A hash with variables available to both, path and content processing
  # @option env [Hash] :path_variables
  #   A hash with variables available to path processing
  # @option env [Hash] :content_variables
  #   A hash with variables available to content processing
  #
  # @see #dry_run For a way to see what would happen with materialize
  def materialize(in_path=".", env={}, &on_collision)
    @output_indent = 0
    in_path = File.expand_path(in_path)
    create_directory(in_path) { |created|
      created ? "Creating root '#{in_path}'" : "Root already exists '#{in_path}'"
    }

    change_directory(in_path) do
      if @directories.empty? then
        info { "No directories to create" }
      else
        info { "Creating directories" }
        @directories.each do |source_dir_path|
          target_dir_path = process_path(source_dir_path, env)
          create_directory(target_dir_path) { |created| "  #{target_dir_path}#{" (exists already)" unless created}" }
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
              create_file(data.path, data.content) { "  #{data.path} (exists already, overwriting)" }
            else
              info { "  #{data.path} (exists already, keeping)" }
            end
          else
            create_file(data.path, data.content) { "  #{data.path} (new)" }
          end
        end
      end
    end

    self
  end

  def change_directory(dir)
    info { "In #{dir}"}
    @output_indent += 1
    if @dry_run
      yield
    else
      Dir.chdir(dir) do yield end
    end
  ensure
    @output_indent -= 1
  end

  # @private
  # Preprocesses the given path
  def process_path(path, env)
    @path_processor.call(ProcessData.new(self, path, nil, env)).path
  end

  # @private
  # Preprocesses the given content
  def process_content(path, content, env)
    data = ProcessData.new(self, path, content, env)
    catch(:stop_processing) {
      #p :process_content => path, :available => @processors.size, :processors => processors_for(data).tap { |x| x && x.size }
      processor = processor_for(data)
      while processor
        debug { "  -> Applying #{processor.name}" }
        processor.call(data)
        processor = processor_for(data)
      end
    }

    data
  end

  # @private
  # Create the given directory and emit an info message (unless in dry_run mode).
  #
  # @note The mode param is currently unused.
  def create_directory(path, mode=0755, &message)
    info(!File.exists?(path), &message)
    unless File.exist?(path) then
      FileUtils.mkdir_p(path) unless @dry_run
    end
  end

  # @private
  # Create the given file and emit an info message (unless in dry_run mode).
  #
  # @note The mode param is currently unused.
  def create_file(path, content="", mode=0644, &message)
    info(!File.exists?(path), &message)
    if @dry_run then
      debug { "  Content:#{content.empty? ? " (empty)" : "\n" + content.gsub(/^/, "    ") }" }
    else
      File.open(path, "wb:binary") do |fh|
        fh.write(content)
      end
    end
  end

  # @private
  # @param [ProcessData] data
  #   The data which the processor should apply to.
  #
  # @return [Processor, nil]
  #   Returns the processor or nil
  def processor_for(data)
    @processors.find { |processor| processor === data }
  end

  # @private
  # Emit an info string (the return value of the block). Will not be emitted if
  # DirectoryTemplate#silent is true
  def info(*args)
    @out.puts indent_output + yield(*args) unless @silent
  end

  # @private
  # Emit a debug string (the return value of the block). Will only be emitted if
  # DirectoryTemplate#debug is true
  def debug(*args)
    @out.puts indent_output + yield(*args) if @verbose
  end

  def indent_output
    "  " * @output_indent
  end

  # @private
  # See Object#inspect
  def inspect
    sprintf "#<%s:0x%x source=%p>", self.class, object_id << 1, @source
  end
end
