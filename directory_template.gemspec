# encoding: utf-8

Gem::Specification.new do |s|
  s.name                      = "directory_template"
  s.version                   = "0.0.1"
  s.authors                   = "Stefan Rusterholz"
  s.homepage                  = "https://github.com/apeiros/directory_template"
  s.description               = <<-DESCRIPTION.gsub(/^    /, '').chomp
    Create directories from templates.
    Existing directory structures, yaml files and ruby datastructures can all serve as
    sources of a template.
    Can preprocess pathnames and content.
    Path- and ContentProcessors are exchangeable.
  DESCRIPTION
  s.summary                   = <<-SUMMARY.gsub(/^    /, '').chomp
    Create directories from templates, optionally preprocessing paths and contents.
  SUMMARY
  s.email                     = "stefan.rusterholz@gmail.com"

  s.files                     =
    Dir['bin/**/*'] +
    Dir['lib/**/*'] +
    Dir['rake/**/*'] +
    Dir['examples/**/*'] +
    Dir['documentation/**/*'] +
    Dir['test/**/*'] +
    Dir['*.gemspec'] +
    %w[
      Rakefile
      README.markdown
    ]

  if File.directory?('bin') then
    executables = Dir.chdir('bin') { Dir.glob('**/*').select { |f| File.executable?(f) } }
    s.executables = executables unless executables.empty?
  end

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1")
  s.rubygems_version          = "1.3.1"
  s.specification_version     = 3
end
