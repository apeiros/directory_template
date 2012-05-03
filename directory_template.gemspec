# encoding: utf-8

Gem::Specification.new do |s|
  s.name                      = "directory_template"
  s.version                   = "1.0.1"
  s.authors                   = "Stefan Rusterholz"
  s.homepage                  = "https://github.com/apeiros/directory_template"
  s.description               = <<-DESCRIPTION.gsub(/^    /, '').chomp
    DirectoryTemplate is a library which lets you generate directory structures and files
    from a template structure. The template structure can be a real directory structure on
    the filesystem, or it can be stored in a yaml file. Take a look at the examples directory
    in the gem to get an idea, how a template can look.
    
    When generating a new directory structure from a template, DirectoryTemplate will process
    the pathname of each directory and file using the DirectoryTemplate#path_processor.
    It will also process the contents of each file with all processors that apply to a given
    file.
    The standard path processor allows you to use `%{variables}` in pathnames. The gem comes
    with a .erb (renders ERB templates) and .html.markdown processor (renders markdown to
    html).
    You can use the existing processors or define your own ones.
  DESCRIPTION
  s.summary                   = <<-SUMMARY.gsub(/^    /, '').chomp
    Lets you generate directory structures from a template, optionally processing paths
    (variables in the path) and contents (e.g., render ERB templates).
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
