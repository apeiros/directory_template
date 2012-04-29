# encoding: utf-8

class DirectoryTemplate

  # The definition of a processor
  class Processor

    # Searches for all processors and registers them
    def self.register_all
      $LOAD_PATH.each do |path|
        Dir.glob(File.join(path, 'directory_template', 'processor', '**', '*.rb')) do |processor|
          require processor
        end
      end
    end

    # Creates a Processor and registers it
    def self.register(*arguments, &block)
      processor = new(*arguments, &block)
      DirectoryTemplate.register(processor)

      processor
    end

    # The pattern matching proc used to figure whether the processor applies to a
    # ProcessData or not.
    attr_reader :pattern

    # The source used to create the pattern proc. I.e., the value passed to ::new as the
    # pattern parameter.
    attr_reader :pattern_source

    # A human identifiable name
    attr_reader :name

    # A human understandable description of the processor
    attr_reader :description

    # The implementation of the processor. I.e., the block passed to ::new.
    attr_reader :execute

    # @param [String] pattern
    #   A glob-like-pattern, e.g. '*.html.haml'
    #
    # @param [String] name
    #   The name of the processor
    #
    # @param [String] description
    #   A description, what the processor does
    #
    # @param [#call] execute
    #   The implementation of the processor.
    def initialize(id, pattern, name=nil, description=nil, &execute)
      raise ArgumentError, "ID must be a Symbol" unless id.is_a?(Symbol)
      @id             = id
      @pattern_source = pattern
      @pattern        = case pattern
        when String then proc { |data| File.fnmatch?(pattern, data.path) }
        when Regexp then proc { |data| pattern =~ data.path }
        when Proc   then pattern
        else
          raise ArgumentError, "Expected a String, Regexp or Proc as pattern, but got #{pattern.class}"
      end
      @name         = name
      @description  = description
      @execute      = execute
    end

    # Whether the processor is suitable for the given ProcessData
    def ===(process_data)
      @pattern.call(process_data)
    end

    # Apply the processor on a ProcessData instance.
    #
    # @param [DirectoryTemplate::ProcessData] process_data
    #   The process data to apply this processor on.
    #
    # @return [DirectoryTemplate::ProcessData]
    #   The process_data passed to this method.
    def call(process_data)
      @execute.call(process_data)

      process_data
    end
  end
end
