WPSS Validation Tool version 4.6.0
-----------------------------------

The WPSS Validation Tool provides web developers and quality assurance testers the ability to perform a number of web site and web page validation tasks at one time. The tool crawls a site to find all of the documents then analyses each document with a number of validation tools.

Version 4.6.0 contains the following updates and additions

WPSS_Tool
---------

    - Update GoC core subject thesaurus to November 2013 (latest) version.
    - Reduce the memory requirements to avoid "Out of memory" errors.
 

Reminder: The WPSS Tool DOES NOT validate HTML5 markup.


Open Data Tool
--------------

    - Reduce the memory requirements to avoid "Out of memory" errors.
 

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
  - https://github.com/wet-boew/wet-boew-wpss/releases/download/4.6.0/WPSS_Tool.exe
