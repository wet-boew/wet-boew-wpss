WPSS Validation Tool version 4.4.0
-----------------------------------

The WPSS Validation Tool provides web developers and quality assurance testers the ability to perform a number of web site and web page validation tasks at one time. The tool crawls a site to find all of the documents then analyses each document with a number of validation tools.

Version 4.4.0 contains the following updates and additions

WPSS_Tool
---------

  - Accept compressed (e.g. gzip) HTTP content from web servers.
  - Create temporary files in user's temp folder rather than the program folder to avoid possible permissions problems.
  - Skip markup validation if it not required for accessibility testing.
  - Don't include table cell or script  content when checking for whitespace spacing in content.
  - Check for styling and markup used to hide content and suppress some WCAG errors (e.g. missing frame title) if it is hidden.
  - Check for aria-label or aria-labelledby in tag with role = group or role = radiogroup - WCAG_2.0-ARIA17
  - Check for aria-label or aria-labelledby in tag with role = alertdialog - WCAG_2.0-ARIA18.
  - Check for role="presentation" on tags that convey information or relationships - WCAG_2.0-F92
  - Support for WET 4.0 based Web usability pages.
  - Report error if Google analytics is found.  Previously this was reported as information only, however since google analytics is not acceptable after June 30, 2014, an error is now reported.


Reminder: The WPSS Tool DOES NOT validate HTML5 markup.


Open Data Tool
--------------

  - Create temporary files in user's temp folder rather than the program folder to avoid possible permissions problems.
  - Accept compressed (e.g. gzip) HTTP content from web servers.
  - Handle resource type "api" in JSON description.


WPSS_Tool Installer
---------------------

The tool installer, WPSS_Tool.exe, does NOT include the required Perl or Python installers (as was the case for previous releases).  Perl and Python must be installed on the workstation prior to installing the WPSS_Tool.

Supported versions of Perl include
- ActiveState Perl 5.14 (does not support 5.16)
- Strawberry Perl 5.18 (32 bit) available from http://strawberry-perl.googlecode.com/files/strawberry-perl-5.18.1.1-32bit.msi

Supported versions of Python include
- Python 2.7.3
- Python 2.7.6 available from http://python.org/ftp/python/2.7.6/python-2.7.6.msi

The WPSS_Tool has been tested on the following platforms
- Windows XP (32 bit), ActiveState Perl 5.14, Python 2.7.3
- Windows XP (32 bit), Strawberry Perl 5.18, Python 2.7.3
- Windows XP (32 bit), Strawberry Perl 5.18, Python 2.7.6
- Windows 7 (64 bit), Strawberry Perl 5.18 (32 bit), Python 2.7.3

The WPSS Tool installer is available as a release in this repository
  - https://github.com/wet-boew/wet-boew-wpss/releases/download/4.4.0/WPSS_Tool.exe
