# WPSS Validation Tool version 3.11.0

The WPSS Validation Tool provides web developers and quality assurance testers the ability to perform a number of web site and web page validation tasks at one time. The tool crawls a site to find all of the documents then analyses each document with a number of validation tools.

Version 3.11.0 contains the following updates and additions
  - Additional mime-type values for web feeds.
  - Perform some accessibility checks for CSV files, ensure they are well formed.
  - Remove support for ActiveState Perl 5.10, only support 5.14.
  - Report non-HTML primary format documents (e.g. PDF) in features tab
  - Update help URLs for Standard on Web Usability checkpoints.
  - Check for mismatches in opening links in new windows for GC and Site navigation, in pages using the Standard on Web Usability template.
  - Report soft 404 errors in link check. A soft 404 is a page that looks like a 404 error page but has a 200 code.
  - Create small upgrade install package that does not include Perl or Python.
  - Support Strawberry Perl 5.18.

Reminder: The WPSS Tool DOES NOT validate HTML5 markup.

# WPSS_Tool Installer

The tool installer, WPSS_Tool.exe, does NOT include the required Perl or Python installers (as was the case for previous releases).  Perl and Python must be installed on the worksation prior to installing the WPSS_Tool.

Supported versions of Perl include
  - ActiveState Perl 5.14 (does not support 5.16)
  - Strawberry Perl 5.18 (32 bit) available from http://strawberry-perl.googlecode.com/files/strawberry-perl-5.18.1.1-32bit.msi

Supported versions of Python include
  - Python 2.7.3 available from http://python.org/ftp/python/2.7.3/python-2.7.3.msi

The WPSS_Tool has been tested on the following platforms
  - Windows XP (32 bit), ActiveState Perl 5.14, Python 2.7.3
  - Windows XP (32 bit), Strawberry Perl 5.18, Python 2.7.3
  - Windows 7 (64 bit), Strawberry Perl 5.18 (32 bit), Python 2.7.3

The WPSS Tool installer is available as a release in this repository
  - https://github.com/wet-boew/wet-boew-wpss/releases/download/3.11.0/WPSS_Tool.exe
