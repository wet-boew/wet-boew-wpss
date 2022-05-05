http://www.htmlhelp.com/tools/validator/offline/README

Offline HTMLHelp.com Validator README
=====================================

For help on the Offline HTMLHelp.com Validator, run "validate --help".

For updates, go to <http://www.htmlhelp.com/tools/validator/offline/>.

Please send bug reports, suggestions, patches, or strong praise to Liam Quinn
<liam@htmlhelp.com>.


License
=======
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.


Using Custom DTDs
=================
The Offline HTMLHelp.com Validator comes with most W3C standard and draft DTDs
for HTML.  You can also add your own DTDs to support non-standard HTML features
such as the EMBED element or the LEFTMARGIN attribute on BODY.

See <http://www.htmlhelp.com/tools/validator/customdtd.html> for a tutorial on
extending the HTML 4.0 Transitional DTD to support some non-standard features.

Once you have your DTD, you can add support for it to the Offline HTMLHelp.com
Validator through these steps:

1. Add the DTD to the directory specified by the $sgmlDir variable in the
"validate" Perl script (by default this directory is
"/usr/local/share/wdg/sgml-lib").

2. Edit the file named "catalog" in the $sgmlDir directory, adding a public
identifier for your DTD followed by the filename.  I recommend modeling your
public identifier after those already in the catalog.  For example, you might
copy

PUBLIC "-//W3C//DTD HTML 4.01//EN"

and change "W3C" to a string identifying you or your organization, and change
"HTML 4.01" to a description of your version of HTML.

3. Edit the "validate" script, adding your public identifier and a description
of it to %HTMLversion, and mapping your description to an SGML declaration in
%sgmlDecl.  This step is optional, and is only useful when using the --verbose
option or when you want to specify an SGML declaration other than "custom.dcl".
If this step is not performed, "validate --verbose" will report that the level
of HTML is "Unknown" rather than giving a more descriptive label for your
custom DTD.

4. At the beginning of your HTML documents, before any tags, include a DOCTYPE
with your public identifier and a URL at which your DTD is available. For
example:

<!DOCTYPE html PUBLIC "-//Foo//DTD FooHTML 0.9//EN"
   "http://www.example.com/foo.dtd">

Note that you may skip steps 1-3 if you don't mind fetching the DTD over the
network (at the specified URL) each time a document is validated.

