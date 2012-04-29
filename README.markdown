README
======


Summary
-------
Create directories from templates, optionally preprocessing paths and contents.


Installation
------------
`gem install directory_template`


Usage
-----

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
Create directories from templates.
Existing directory structures, yaml files and ruby datastructures can all serve as
sources of a template.
Can preprocess pathnames and content.
Path- and ContentProcessors are exchangeable.
