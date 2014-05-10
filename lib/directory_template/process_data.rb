class DirectoryTemplate

  # ProcessData is the value that gets passed to processors.
  # The processor must mutate it.
  class ProcessData

    # A reference to the DirectoryTemplate of which this file/directory is part of
    attr_reader :directory_template

    # The path as it is in the current stage of processing.
    attr_reader :path

    # The filename, as it is in the current stage of processing.
    attr_reader :filename

    # The directory, as it is in the current stage of processing.
    attr_reader :directory

    # The suffix, as it is in the current stage of processing.
    attr_reader :suffix

    # The file-content, as it is in the current stage of processing (nil for directories).
    attr_accessor :content

    # Variables to be used for path preprocessing
    attr_reader :path_variables

    # Variables to be used for filecontent preprocessing
    attr_reader :content_variables

    # Variables to be used for both, path- and filecontent preprocessing
    attr_reader :variables

    # A content of nil means this is a directory
    # @param [Hash] env
    #   A hash with additional information, used to parametrize and preprocess the template.
    #   @options env [Hash<Symbol,String>] :variables
    #     Variables used for both, path- and filecontent processing.
    #   @options env [Hash<Symbol,String>] :path_variables
    #     Variables only used for path-processing.
    #   @options env [Hash<Symbol,String>] :content_variables
    #     Variables only used for filecontent processing.
    def initialize(directory_template, path, content, env)
      @directory_template = directory_template
      @content            = content
      @variables          = env[:variables] || {}
      @path_variables     = @variables.merge(env[:path_variables] || {})
      @content_variables  = @variables.merge(env[:content_variables] || {})
      self.path           = path
    end

    # Whether the processor is suitable for the given ProcessData.
    # Simply delegates the job to the Processor.
    #
    # @see Processor#===
    def ===(processor)
      processor === self
    end

    # @return [Boolean]
    #   Whether the item is a file. The alternative is, that it is a directory.
    #
    # @see #directory?
    def file?
      !!@content
    end

    # @return [Boolean]
    #   Whether the item is a directory. The alternative is, that it is a file.
    #
    # @see #file?
    def directory?
      !@content
    end

    # @param [String] value
    #   The new path
    #
    # Sets the path, filename, directory and suffix of this item.
    def path=(value)
      @path       = value
      @filename   = File.basename(value)
      @directory  = File.dirname(value)
      @suffix     = File.extname(value)
    end

    # Removes the current suffix. E.g. "foo/bar.baz.quuz" would be "foo/bar.baz" after the
    # operation.
    def chomp_suffix!
      self.path   = @path.chomp(@suffix)
    end
  end
end
