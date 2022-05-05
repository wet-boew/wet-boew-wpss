http://cpansearch.perl.org/src/ABELTJE/Win32-IE-Mechanize-0.009/README

Win32::IE::Mechanize version 0.009
==================================

This module is mostly a port of the very popular WWW::Mechanize
module but uses InternetExplorer as the user-agent. This makes it
possible to also test JavaScript dependant webpages.
This version was based on WWW::Mechanize 1.08

The test-suite runs on stock cygwin-1.5.10/W2k

INSTALLATION

To install this module type the following:

   perl Makefile.PL
   nmake test
   nmake install

DEPENDENCIES

This module requires these other modules and libraries:

    URI
    Win32
    Win32::OLE

COPYRIGHT AND LICENCE

Copyright MMIV Abe Timmerman <abeltje@cpan.org> All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

