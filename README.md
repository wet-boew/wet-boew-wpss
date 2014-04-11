WPSS Validation Tool version 4.3.0
-----------------------------------

The WPSS Validation Tool provides web developers and quality assurance testers the ability to perform a number of web site and web page validation tasks at one time. The tool crawls a site to find all of the documents then analyses each document with a number of validation tools.

Version 4.3.0 contains the following updates and additions

WPSS_Tool
---------

- Check for alt text that contains only whitespace for decorative images - WCAG_2.0-F39
- Check aria-label, aria-labelledby, aria-describedby attributes in decorative images - WCAG_2.0-F39
- Check role attributes in decorative images - WCAG_2.0-F38
- Check for label appearing before radio button or checkbox inputs - WCAG_2.0-H44
- Check HTML data attributes for document section markers (WET 4.0).
- Accept file: URLs in the list of URLs to analyse.
- Add checks for WAI-ARIA techniques - WCAG_2.0.
    ARIA1, ARIA2, ARIA6, ARIA7, ARIA8, ARIA9, ARIA10, ARIA12, ARIA13, ARIA15, ARIA16
- Don't add whitespace around content from tags that do not act as word boundaries (e.g. <sub>) - WCAG_2.0-F32



Reminder: The WPSS Tool DOES NOT validate HTML5 markup.


Open Data Tool
--------------

- Accept a dataset description URL (JSON format from data.gc.ca) to specify a dataset's files.
- Do case insensitive checks on dictionary terms.
- Use the format specified in the JSON dataset description to help determine the URL content format (e.g. csv, xml).



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
  - https://github.com/wet-boew/wet-boew-wpss/releases/download/4.3.0/WPSS_Tool.exe
