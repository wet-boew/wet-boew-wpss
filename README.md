WPSS Validation Tool version 4.2.0
-----------------------------------

The WPSS Validation Tool provides web developers and quality assurance testers the ability to perform a number of web site and web page validation tasks at one time. The tool crawls a site to find all of the documents then analyses each document with a number of validation tools.

Version 4.2.0 contains the following updates and additions

WPSS_Tool
---------

- Correct bug with tracking nested RDFa HTML data types.
- Correct bug in formatting error messages in XML mode, some messages were not included in the output.
- Check for styled text (e.g. bold) that looks like a heading in div tags - WCAG_2.0-F2.
- Don't report emphasised labels as possible pseudo headings - WCAG_2.0-F2.
- Check for text that is styled with CSS to look like a heading - WCAG_2.0-F2.
- Extract src attribute from <iframe> tags as links.
- Extract data attribute from <object> tags as links.
- If 2 links to the same URL have different link or title text, accept string if one is a substring of the other - WCAG_2.0-G197
- Report error if we are unable to determine the language of text because the top 2 languages are too close - WCAG_2.0-H57.
- Create new link check profile to check for common errors, this new profile is the default profile.
- Add new values for some GC Navigation links (e.g. canada.ca) - SWU
- Bring results window to the top when an anslysis is started.


Reminder: The WPSS Tool DOES NOT validate HTML5 markup.


Open Data Tool
--------------

- Set the default for the maximum document size to 100 Mb to avoid truncating large data files.
- Report missing fields from header row - TP_PW_OD_CSV_1
- Handle ZIP archived data set files. Extract, analyse and report on each file in the archive.


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
  - https://github.com/wet-boew/wet-boew-wpss/releases/download/4.2.0/WPSS_Tool.exe
