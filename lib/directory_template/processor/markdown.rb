# encoding: utf-8

class DirectoryTemplate
  class Processor

    # The ERB Processor treats the file-content as ERB template.
    Markdown = Processor.register(:markdown_to_html, "*.html.markdown", "Markdown to HTML Template Processor") do |data|
      Markdown.require "kramdown"
      data.content = Kramdown::Document.new(data.content).to_html
      data.chomp_suffix!
    end
  end
end
