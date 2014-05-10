# encoding: utf-8



class DirectoryTemplate
  class Processor

    # The 
    Stop = Processor.register(:stop, "*.stop", "Terminate processing queue", "After .stop, no processor will be run anymore") do |data|
      data.chomp_suffix!
      throw :stop_processing
    end
  end
end
