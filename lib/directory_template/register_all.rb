# This file requires all registrators for DirectoryTemplate processors

require 'directory_template'
$LOAD_PATH.each do |path|
  Dir.glob(File.join(path, 'directory_template', 'register', '**', '*.rb')) do |registrator|
    require registrator
  end
end
