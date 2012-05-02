CONTENT PROCESSORS
==================


Included Processors
-------------------

DirectoryTemplate comes with the following content processors:

* :erb - Renders files with the '.erb' Suffix as ERB Templates.
* :html\_to\_markdown - Renders markdown files to html. It is applied to all files which
  have .html.markdown as suffix (only the .markdown will be dropped).


Rolling your own
----------------

See {DirectoryTemplate::Processor} for informations on how to create a content processor.

