# encoding: utf-8



require 'erb'
require 'directory_template/blank_slate'



class DirectoryTemplate

  # = Indexing
  # @author:  Stefan Rusterholz <contact@apeiros.me>
  #
  # = About
  # A helper class for ERB, allows constructs like the one in the Synopsis to
  # enable simple use of variables/methods in templates.
  #
  # @example
  #     tmpl = Templater.new("Hello <%= name %>!")
  #     tmpl.result(self, :name => 'world') # => 'Hello World!'
  #
  class ErbTemplate

    # = Indexing
    # Author:   Stefan Rusterholz
    # Contact:  contact@apeiros.me
    # Version:  0.1.0
    #
    # = About
    # Similar to OpenStruct, but slightly optimized for create once, use once and
    # giving diagnostics on exceptions/missing keys.
    #
    # = Synopsis
    #   tmpl = Variables.new(delegator, :variable => "content") { |exception|
    #     do_something_with(exception)
    #   }
    #
    class Variables < BlankSlate
      # A proc for &on_error in SilverPlatter::Variables::new or SilverPlatter::Templater#result.
      # Raises the error further on.
      Raiser = proc { |e|
        raise(e)
      }

      # A proc for &on_error in SilverPlatter::Variables.new or SilverPlatter::Templater#result.
      # Inserts <<error_class: error_message>> in the place where the error
      # occurred.
      Teller = proc { |e|
        "<<#{e.class}: #{e}>>"
      }

      # An empty Hash
      EmptyHash     = {}.freeze

      # Regex to match setter method names
      SetterPattern = /=\z/.freeze

      # === Arguments
      # * delegate:      All method calls and undefined variables are delegated to this object as method call.
      # * variables:     A hash with variables in it, keys must be Symbols.
      # * on_error_name: Instead of a block you can pass the name of an existing handler, e.g. :Raiser or :Teller.
      # * &on_error:     The block is yielded in case of an exception with the exception as argument
      #
      def initialize(delegate=nil, variables={}, on_error_name=nil, &on_error)
        @delegate = delegate
        @table    = (@delegate ? Hash.new { |h,k| @delegate.send(k) } : EmptyHash).merge(variables)
        if !on_error && on_error_name then
          @on_error = self.class.const_get(on_error_name)
        else
          @on_error = on_error || Raiser
        end
      end

      # All keys this Variables instance provides, if the include_delegate argument is true and
      # the object to delegate to responds to __keys__, then it will add the keys of the delegate.
      def __keys__(include_delegate=true)
        @table.keys + ((include_delegate && @delegate.respond_to?(:__keys__)) ? @delegate.__keys__ : [])
      end

      # Make the binding publicly available
      def __binding__
        binding
      end

      # See Object#respond_to?
      def respond_to?(key)
        @table.respond_to?(key) || (@delegate && @delegate.respond_to?(key)) || super
      end

      def method_missing(m, *args) # :nodoc:
        argn = args.length
        if argn.zero? && @table.has_key?(m) then
          @table[m]
        elsif argn == 1 && m.to_s =~ SetterPattern
          @table[m] = args.first
        elsif @delegate
          @delegate.send(m, *args)
        end
      rescue => e
        @on_error.call(e)
      end

      def inspect # :nodoc:
        sprintf "#<%s:0x%08x @delegate=%s %s>",
          self.class,
          __id__,
          @table.map { |k,v| "#{k}=#{v.inspect}" }.join(', '),
          @delegate ? "#<%s:0x%08x ...>" %  [@delegate.class, @delegate.object_id << 1] : "nil"
      end
    end

    # Option defaults
    Opt = {
      :safe_level => nil,
      :trim_mode  => '%<>',
      :eoutvar    => '_erbout'
    }

    # The instance_eval method
    InstanceEvaler  = Object.instance_method(:instance_eval)


    # A proc for &on_error in SilverPlatter::Variables::new or SilverPlatter::Templater#result.
    # Raises the error further on.
    Raiser = proc { |e|
      raise
    }

    # A proc for &on_error in SilverPlatter::Variables.new or SilverPlatter::Templater#result.
    # Inserts <<error_class: error_message>> in the place where the error
    # occurred.
    Teller = proc { |e|
      "<<#{e.class}: #{e}>>"
    }

    # The template string
    attr_reader :string

    # Like Templater.new, but instead of a template string, the path to the file
    # containing the template. Sets :filename.
    def self.file(path, opt=nil)
      new(File.read(path), (opt || {}).merge(:filename => path))
    end

    # A convenience method, which evaluates the templates with the given variables and
    # returns the result.
    def self.replace(template, variables, &on_error)
      new(template).result(nil, variables, &on_error)
    end

    # ==== Arguments
    # * string: The template string, it becomes frozen
    # * opt:    Option hash, keys:
    #   * :filename:   The filename used for the evaluation (useful for error messages)
    #   * :safe_level: see ERB.new
    #   * :trim_mode:  see ERB.new
    #   * :eoutvar:    see ERB.new
    def initialize(string, opt={})
      opt, string   = string, nil if string.kind_of?(Hash)
      opt           = Opt.merge(opt)
      file          = opt.delete(:filename)
      @string       = string.freeze
      @erb          = ERB.new(@string, *opt.values_at(:safe_level, :trim_mode, :eoutvar))
      @erb.filename = file if file
    end

    # See Templater::Variables.new
    # Returns the evaluated template. Default &on_error is the Templater::Raiser
    # proc.
    def result(delegate=nil, variables={}, on_error_name=nil, &on_error)
      variables ||= {}
      on_error  ||= Raiser
      variables = Variables.new(delegate, variables, on_error_name, &on_error)
      @erb.result(variables.__binding__)
    rescue NameError => e
      raise NameError, e.message+" for #{self.inspect} with #{variables.inspect}", e.backtrace
    end

    # See Templater::Variables.new
    # Returns the evaluated template. Default &on_error is the Templater::Raiser
    # proc.
    def result_with(opt, &block)
      opt           = opt.dup
      variables     = opt.delete(:variables) || {}
      delegate      = opt.delete(:delegate)
      on_error      = opt.delete(:on_error) || Raiser
      on_error_name = opt.delete(:on_error_name) || Raiser
      variables = Variables.new(delegate, variables, on_error_name, block, &on_error)
      @erb.result(variables.__binding__)
    rescue NameError => e
      raise NameError, e.message+" for #{self.inspect} with #{variables.inspect}", e.backtrace
    end

    def inspect # :nodoc:
      sprintf "#<%s:0x%x string=%s>",
        self.class,
        object_id << 1,
        @string.inspect
    end
  end
end
