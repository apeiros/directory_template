# encoding: utf-8

require "erb"
require "directory_template/blank_slate"

class DirectoryTemplate
  # @author Stefan Rusterholz <stefan.rusterholz@gmail.com>
  #
  # A helper class for ERB. Allows constructs like the one in the examples to
  # enable simple use of variables/methods in templates.
  #
  # @example A simple ERB template being rendered
  #     tmpl = DirectoryTemplate::ErbTemplate.new("Hello <%= name %>!")
  #     tmpl.result(self, :name => 'world') # => 'Hello World!'
  #
  class ErbTemplate
    # @author Stefan Rusterholz <stefan.rusterholz@gmail.com>
    #
    # Variables is similar to OpenStruct, but slightly optimized for create once, use once
    # and giving diagnostics on exceptions/missing keys.
    #
    # @example
    #   variables = Variables.new(delegator, :x => "Value of X") { |exception|
    #     do_something_with(exception)
    #   }
    #   variables.x # => "Value of X"
    #
    class Variables < BlankSlate
      # A proc for &on_error in DirectoryTemplate::ErbTemplate::Variables::new or
      # DirectoryTemplate::ErbTemplate#result.
      # Raises the error further on.
      Raiser = proc { |e|
        raise(e)
      }

      # A proc for &on_error in DirectoryTemplate::ErbTemplate::Variables.new or
      # DirectoryTemplate::ErbTemplate#result.
      # Inserts <<error_class: error_message>> in the place where the error
      # occurred.
      Teller = proc { |e|
        "<<#{e.class}: #{e}>>"
      }

      # An empty Hash
      EmptyHash     = {}.freeze

      # Regex to match setter method names
      SetterPattern = /=\z/.freeze

      # @param [Object] delegate
      #   All method calls and undefined variables are delegated to this object as method
      #   call.
      # @param [Hash<Symbol,Object>] variables
      #   A hash with variables in it, keys must be Symbols.
      # @param [Symbol] on_error_name
      #   Instead of a block you can pass the name of an existing handler, e.g. :Raiser
      #   or :Teller.
      #
      # @yield [exception] description
      #   The block is yielded in case of an exception with the exception as argument.
      #
      def initialize(delegate=nil, variables={}, on_error_name=nil, &on_error)
        @delegate = delegate
        @table    = (@delegate ? Hash.new { |h, k| @delegate.send(k) } : EmptyHash).merge(variables)
        if !on_error && on_error_name
          @on_error = self.class.const_get(on_error_name)
        else
          @on_error = on_error || Raiser
        end
      end

      # @return [Array<Symbol>]
      #   All keys this Variables instance provides, if the include_delegate argument is
      #   true and the object to delegate to responds to __keys__, then it will add the
      #   keys of the delegate.
      def __keys__(include_delegate=true)
        @table.keys + ((include_delegate && @delegate.respond_to?(:__keys__)) ? @delegate.__keys__ : [])
      end

      # @return [Binding] Make the binding publicly available
      def __binding__
        binding
      end

      # @private
      # @see Object#respond_to_missing?
      def respond_to_missing?(key)
        @table.respond_to?(key) || (@delegate && @delegate.respond_to?(key))
      end

      # @private
      # Set or get the value associated with the key matching the method name.
      def method_missing(m, *args) # :nodoc:
        argn = args.length
        if argn.zero? && @table.key?(m)
          @table[m]
        elsif argn == 1 && m.to_s =~ SetterPattern
          @table[m] = args.first
        elsif @delegate
          @delegate.send(m, *args)
        end
      rescue => e
        @on_error.call(e)
      end

      # @private
      # See Object#inspect
      def inspect # :nodoc:
        sprintf "#<%s:0x%08x @delegate=%s %s>",
          self.class,
          __id__,
          @table.map { |k, v| "#{k}=#{v.inspect}" }.join(", "),
          @delegate ? "#<%s:0x%08x ...>" %  [@delegate.class, @delegate.object_id << 1] : "nil"
      end
    end

    # Option defaults
    Opt = {
      :safe_level => nil,
      :trim_mode  => "%<>",
      :eoutvar    => "_erbout"
    }

    # An UnboundMethod instance of instance_eval
    InstanceEvaler  = Object.instance_method(:instance_eval)

    # A proc for &on_error in DirectoryTemplate::ErbTemplate::Variables::new or DirectoryTemplate::ErbTemplate#result.
    # Raises the error further on.
    Raiser = proc { |e|
      raise
    }

    # A proc for &on_error in DirectoryTemplate::ErbTemplate::Variables::new or DirectoryTemplate::ErbTemplate#result.
    # Inserts <<error_class: error_message>> in the place where the error
    # occurred.
    Teller = proc { |e|
      "<<#{e.class}: #{e}>>"
    }

    # The template string
    attr_reader :string

    # Like ErbTemplate.new, but instead of a template string, the path to the file
    # containing the template. Sets :filename.
    #
    # @param [String] path
    #   The path to the file to use as a template
    #
    # @param [Hash] options
    #   See ErbTemplate::new for the options
    def self.file(path, options=nil)
      options = options ? options.merge(:filename => path) : {:filename => path}

      new(File.read(path), options)
    end

    # @param [String] string
    #   The template string
    # @param [Hash] options
    #   A couple of options
    #
    # @option options [String] :filename
    #   The filename used for the evaluation (useful for error messages)
    # @option options [Integer] :safe_level
    #   See ERB.new
    # @option options [String] :trim_mode
    #   See ERB.new
    # @option options [Symbol, String] :eoutvar
    #   See ERB.new
    def initialize(string, options={})
      options, string = string, nil if string.kind_of?(Hash)
      options         = Opt.merge(options)
      filename        = options.delete(:filename)
      raise ArgumentError, "String or filename must be given" unless string || filename

      @string       = string || File.read(filename)
      @erb          = ERB.new(@string, *options.values_at(:safe_level, :trim_mode, :eoutvar))
      @erb.filename = filename if filename
    end

    # @return [String]
    #   The evaluated template. Default &on_error is the
    #   DirectoryTemplate::ErbTemplate::Raiser proc.
    def result(variables=nil, on_error_name=nil, &on_error)
      variables ||= {}
      on_error  ||= Raiser
      variables = Variables.new(nil, variables, on_error_name, &on_error)
      @erb.result(variables.__binding__)
    rescue NameError => e
      raise NameError, e.message + " for #{self.inspect} with #{variables.inspect}", e.backtrace
    end

    # @param [Hash] options
    #   A couple of options
    #
    # @option options [Hash] :variables
    #   A hash with all the variables that should be available in the template.
    # @option options [Object] :delegate
    #   An object, to which methods should be delegated.
    # @option options [Proc, Symbol, #to_proc] :on_error
    #   The callback to use in case of an exception.
    #
    # @return [String]
    #   The evaluated template. Default &on_error is the
    #   DirectoryTemplate::ErbTemplate::Raiser proc.
    def result_with(options, &block)
      options   = options.dup
      variables = options.delete(:variables) || {}
      delegate  = options.delete(:delegate)
      on_error  = options.delete(:on_error) || block
      if on_error.is_a?(Symbol)
        on_error_name = on_error
        on_error      = nil
      end
      variables = Variables.new(delegate, variables, on_error_name, &on_error)

      @erb.result(variables.__binding__)
    rescue NameError => e
      raise NameError, e.message + " for #{self.inspect} with #{variables.inspect}", e.backtrace
    end

    # @private
    # See Object#inspect
    def inspect # :nodoc:
      sprintf "#<%s:0x%x string=%s>",
        self.class,
        object_id << 1,
        @string.inspect
    end
  end
end
