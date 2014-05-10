# encoding: utf-8

class DirectoryTemplate
  class Processor
    # The stop processor removes the ".stop" file extension and then terminates the processing queue.
    # This can be used to have suffixes before the stop which would be processed, but should not.
    # E.g. template.html.haml.stop.erb, the .erb part will be processed. But the haml won't be converted to html.
    Stop = Processor.register(
      :stop,
      "*.stop",
      "Terminate processing queue",
      "After .stop, no processor will be run anymore",
    ) do |data|
      data.chomp_suffix!
      throw :stop_processing
    end
  end
end
