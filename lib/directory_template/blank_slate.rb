# encoding: utf-8



require "stringio"



class DirectoryTemplate

  # BlankSlate provides an abstract base class with no predefined
  # methods (except for <tt>\_\_send__</tt> and <tt>\_\_id__</tt>).
  # BlankSlate is useful as a base class when writing classes that
  # depend upon <tt>method_missing</tt> (e.g. dynamic proxies).
  #
  # === Copyright
  #
  # Copyright 2004, 2006 by Jim Weirich (jim@weirichhouse.org).
  # All rights reserved.
  # Permission is granted for use, copying, modification, distribution,
  # and distribution of modified versions of this work as long as the
  # above copyright notice is included.
  #
  # Modified by Stefan Rusterholz (stefan.rusterholz@gmail.com)
  class BlankSlate

    # Hide the method named +name+ in the BlankSlate class.  Don't
    # hide +instance_eval+ or any method beginning with "__".
    #
    # @return [self]
    def self.hide(name)
      verbosity = $VERBOSE
      stderr    = $stderr
      $VERBOSE  = nil
      $stderr   = StringIO.new

      methods = instance_methods.map(&:to_sym)
      if methods.include?(name.to_sym) && name !~ /^(__|instance_eval)/
        @hidden_methods ||= {}
        @hidden_methods[name.to_sym] = instance_method(name)
        undef_method name
      end

      self
    ensure
      $VERBOSE = verbosity
      $stderr  = stderr
    end

    # @return [UnboundMethod] The method that was hidden.
    def self.find_hidden_method(name)
      @hidden_methods ||= {}
      @hidden_methods[name] || superclass.find_hidden_method(name)
    end

    # Redefine a previously hidden method so that it may be called on a blank
    # slate object.
    #
    # @return [self]
    def self.reveal(name)
      hidden_method = find_hidden_method(name)
      fail "Don't know how to reveal method '#{name}'" unless hidden_method
      define_method(name, hidden_method)

      self
    end

    instance_methods.each { |m| hide(m) }
  end
end



# @private
# Extensions to Object for DirectoryTemplate::BlankSlate.
# Since Ruby is very dynamic, methods added to the ancestors of
# {DirectoryTemplate::BlankSlate} after BlankSlate is defined will show up in the
# list of available BlankSlate methods.  We handle this by defining a hook in the Object
# and Kernel classes that will hide any method defined after BlankSlate has been loaded.
#
module Kernel
  class << self
    # Preserve the original method
    alias_method :template_directory_blank_slate_method_added, :method_added
  end

  # @private
  # Detect method additions to Kernel and remove them in the
  # BlankSlate class.
  def self.method_added(name)
    result = template_directory_blank_slate_method_added(name)
    return result if self != ::Kernel
    DirectoryTemplate::BlankSlate.hide(name)
    result
  end
end

# @private
# Extensions to Object for DirectoryTemplate::BlankSlate.
# Since Ruby is very dynamic, methods added to the ancestors of
# {DirectoryTemplate::BlankSlate} after BlankSlate is defined will show up in the
# list of available BlankSlate methods.  We handle this by defining a hook in the Object
# and Kernel classes that will hide any method defined after BlankSlate has been loaded.
#
class Object
  class << self
    # Preserve the original method
    alias_method :template_directory_blank_slate_method_added, :method_added
  end

  # @private
  # Detect method additions to Object and remove them in the
  # BlankSlate class.
  def self.method_added(name)
    result = template_directory_blank_slate_method_added(name)
    return result if self != Object
    DirectoryTemplate::BlankSlate.hide(name)
    result
  end

  # @private
  # See DirectoryTemplate::BlankSlate::find_hidden_method
  # This just serves as a stopper/terminator of the lookup chain.
  def self.find_hidden_method(name)
    nil
  end
end

# @private
# Extensions to Module for DirectoryTemplate::BlankSlate.
# Modules included into Object need to be scanned and have their instance methods removed
# from {DirectoryTemplate::BlankSlate}. In theory, modules included into Kernel would have
# to be removed as well, but a "feature" of Ruby prevents late includes into modules from
# being exposed in the first place.
#
class Module

  # @private
  # Preserve the original method
  alias_method :template_directory_blank_slate_append_features, :append_features

  # @private
  # Monkey patch to the append_features callback of Module, used to update the BlankSlate.
  def append_features(mod)
    result = template_directory_blank_slate_append_features(mod)
    return result if mod != Object
    instance_methods.each do |name|
      DirectoryTemplate::BlankSlate.hide(name)
    end
    result
  end
end
