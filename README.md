# WPSS Validation Tool version 4.0.1

The WPSS Validation Tool provides web developers and quality assurance testers the ability to perform a number of web site and web page validation tasks at one time. The tool crawls a site to find all of the documents then analyses each document with a number of validation tools.

Version 4.0.1 contains the following updates and additions
 - Add open data checking tool (open_data_check.pl and desktop shortcut)  to check open dataset files (dictionary, data, resources).
 - Do case insensitive checks on titles to find matching HTML and PDF versions of a document.
 - Allow for binary data in CSV files (e.g. new-line in the cell content).
 - Report Interoperability failure for web feeds that do not parse properly - SWI_B.
 - Check for table headers that reference undefined headers or headers outside the current table - WCAG_2.0-H43.
 - Check for all language markers to determine if a page is archived or not (handles the case where wrong language message is used).
 - Encode text that is written to results tabs, this eliminates garbled French characters.
 - Report unknown mime-type documents as non-HTML primary format.
 - Accept enter key in URL list tab to move to the next input line.
 - Check for very long (> 500 characters) title and heading text - WCAG_2.0-H42, WCAG_2.0-H25
 - Don't report zoom failure for fix size fonts as current browsers can handle this - WCAG_2.0-G142
 - Decode HTML entities before checking the length of titles and headings to eliminate the length of the HTML code from the actual text length.


Reminder: The WPSS Tool DOES NOT validate HTML5 markup.

# WPSS_Tool Installer

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
  - https://github.com/wet-boew/wet-boew-wpss/releases/download/4.0.1/WPSS_Tool.exe
