README
======


Summary
-------
Lets you generate directory structures from a template, optionally processing paths
(variables in the path) and contents (e.g., render ERB templates).

Features
--------

* Generate directories and files
* Use a directory structure as template, or store the template in a YAML file
* Interpolate variables in directory- and filenames
* Render ERB and Markdown templates
* Write & use your own processors


Installation
------------
`gem install directory_template`


Usage
-----

The examples given below are working examples. The templates are part of the gem and can
be found in the directory 'examples'.

Create a template from an existing structure and materialize it (create directories &
files):

    require 'directory_template'
    variables = {
      namespace:    'Namespace',
      version:      '1.2.3',
      gem_name:     'gem-name',
      require_name: 'require_name',
      description:  "The description",
      summary:      "The summary"
    }
    template = DirectoryTemplate.directory('examples/dir_gem_template')
    template.materialize('new_project', variables: variables)

Create a template from a YAML file:

    require 'directory_template'
    variables = {
      namespace:    'Namespace',
      version:      '1.2.3',
      gem_name:     'gem-name',
      require_name: 'require_name',
      description:  "The description",
      summary:      "The summary"
    }
    template = DirectoryTemplate.yaml_file('examples/yaml_gem_template.yaml')
    template.materialize('new_project', variables: variables)


Description
-----------
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

Also take a look at the {file:documentation/ContentProcessors.markdown Content Processors Guide}
and the {file:documentation/ContentProcessors.markdown Path Processors Guide}.


Links
-----

* [Online API Documentation](http://rdoc.info/github/apeiros/directory_template/)
* [Public Repository](https://github.com/apeiros/directory_template)
* [Bug Reporting](https://github.com/apeiros/directory_template/issues)
* [RubyGems Site](https://rubygems.org/gems/directory_template)


Credits
-------

* Daniel Schärli, for proofreading the docs


License
-------

You can use this code under the {file:LICENSE.txt BSD-2-Clause License}, free of charge.
If you need a different license, please ask the author.
