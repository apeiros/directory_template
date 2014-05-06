# encoding: utf-8



class DirectoryTemplate
  class Processor

    # The standard processor for file- and directory-paths. It simply uses String#% style
    # keyword replacement. I.e., `%{key}` is replaced by the variable value passed with
    # :key.
    RbFormat = Processor.register(:rb_format, '*.rbformat', '%{variable} format processor') do |data|
      data.content = data.content % data.content_variables
      data.chomp_suffix!
    end
  end
end
