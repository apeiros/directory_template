PATH PROCESSORS
===============


Included Processors
-------------------

DirectoryTemplate comes with a simple path processor, it just replaces variables in the
form of `%{variable_name}` within paths with the value in `variable_name`. It takes the
variables from :path_variables and :variables in the env (in that order).


Rolling your own
----------------

See {DirectoryTemplate::Processor} for informations on how to create a path processor.
For a path processor, you'll leave the pattern argument to nil.
