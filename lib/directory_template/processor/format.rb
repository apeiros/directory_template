# encoding: utf-8

class DirectoryTemplate
  class Processor
    # The standard processor for file- and directory-paths. It simply uses String#% style
    # keyword replacement. I.e., `%{key}` is replaced by the variable value passed with
    # :key.
    Format = Processor.new(:format, nil, "%{variable} format processor") do |data|
      data.path = data.path % data.path_variables if data.path_variables
    end
  end
end
