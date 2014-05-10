# encoding: utf-8

class DirectoryTemplate
  # The definition of a processor
  #
  # Use {Processor.register} to register a processor. A registered processor is available
  # in all DirectoryTemplate instances.
  #
  # Processor::register takes the same arguments as {Processor#initialize Processor::new}, so look there for how
  # to define a processor.
  #
  # Take a look at {ProcessData} to see what data your processor gets and can work on.
  class Processor
    # A matcher-proc to never match
    Never = proc { |data| false }

    # Searches for all processors and registers them
    def self.register_all
      $LOAD_PATH.each do |path|
        Dir.glob(File.join(path, "directory_template", "processor", "**", "*.rb")) do |processor|
          require processor
        end
      end
    end

    # Creates a Processor and registers it.
    # The arguments are passed verbatim to Processor::new.
    #
    # @return [Processor]
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

    attr_reader :id

    # @param [Symbol] id
    #   A (in the set of Processors) unique id
    #
    # @param [String, Regexp, Proc, #to_proc, nil] pattern
    #   The pattern determines upon what {ProcessData} this processor is being invoked.
    #
    #   If you provide a String, it is interpreted as a glob-like-pattern, e.g.
    #   '*.html.haml' will match any files whose suffix is '.html.haml'.
    #   See File::fnmatch for an extensive documentation of glob-patterns.
    #   
    #   If you provide a Regexp, the filename is matched against that regexp.
    #
    #   If you provide a Proc (or anything that is converted to a proc), the proc gets
    #   the ProcessData as sole argument and should return true/false, to indicate,
    #   whether the Processor should be invoked or not.
    #
    #   If you pass nil as pattern, the Processor will never be invoked. This is useful
    #   for processors that serve only as path processors.
    #
    # @param [String] name
    #   The name of the processor
    #
    # @param [String] description
    #   A description, what the processor does
    #
    # @param [#call] execute
    #   The implementation of the processor
    def initialize(id, pattern, name=nil, description=nil, &execute)
      raise ArgumentError, "ID must be a Symbol" unless id.is_a?(Symbol)
      @id             = id
      @pattern_source = pattern
      @pattern        = case pattern
        when String then proc { |data| File.fnmatch?(pattern, data.path) }
        when Regexp then proc { |data| pattern =~ data.path }
        when Proc   then pattern
        when nil    then Never
        else
          raise ArgumentError, "Expected a String, Regexp or Proc as pattern, but got #{pattern.class}"
      end
      @name         = name
      @description  = description
      @execute      = execute
    end

    # @return [Boolean]
    #   Whether the processor is suitable for the given ProcessData
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

    # Invokes Kernel#require, and fails with a custom error message.
    # @see Kernel#require
    def require(lib)
      super(lib)
    rescue LoadError
      raise "The #{@name || @id} processor requires #{lib} in order to work"
    end
  end
end
