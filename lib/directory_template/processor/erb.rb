# encoding: utf-8

require "directory_template/erb_template"

class DirectoryTemplate
  class Processor

    # The ERB Processor treats the file-content as ERB template.
    Erb = Processor.register(:erb, "*.erb", "ERB Template Processor") do |data|
      data.content = ErbTemplate.new(data.content).result(data.content_variables)
      data.chomp_suffix!
    end
  end
end
