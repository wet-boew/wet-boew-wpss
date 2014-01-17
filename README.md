WPSS Validation Tool version 4.1.0
-----------------------------------

The WPSS Validation Tool provides web developers and quality assurance testers the ability to perform a number of web site and web page validation tasks at one time. The tool crawls a site to find all of the documents then analyses each document with a number of validation tools.

Version 4.1.0 contains the following updates and additions

WPSS_Tool
---------

- Add checks for Web Analytics (reported in CLF tab), specifically not anonymizing IP addresses in Google analytics. - WA_ID.
- Report URLs that use Web Analytics (google, piwik) in HTML features tab.
- Don't report error if there is a onclick or onkeypress attribute on a tag if there is a focusable item inside a block tag - WCAG_2.0-F42
- Add checks for HTML Data for Web Interoperability.  Check for RDFa syntax and schema.org vocabulary - SWI_E.
- Record URLs that have HTML Data in the HTML features report.
- Add <button> tag to list of tags that are allowed event handlers - WCAG_2.0-F42.
- Report WCAG_2.0-G131 for missing label and legend content.
- Check for content after the body tag and before the skip links - SWU_2.2.6.
- Check for missing content in <option> tag - WCAG_2.0-G115.
- Check for styled text (e.g. bold) that looks like a heading - WCAG_2.0-F2.
- Check for missing table headers at the end of the table. This allows for header id definitions to come after a reference - WCAG_2.0-H43.
- Check for missing headers id values of headers that reference <th> headers (indirect headers) - WCAG_2.0-H43.
- Don't try to get absolute URL from relative URLs in direct HTML input mode. This generated false WCAG_2.0-G197 errors.

Reminder: The WPSS Tool DOES NOT validate HTML5 markup.


Open Data Tool
--------------

- Add fields to GUI to enter open data API URLs.
- Add checks for open data API URLs (JSON, XML).
- Add PWGSC open data checks (CSV header row).
- Change testcase identifiers to include technology type (e.g. txt, csv).


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
  - https://github.com/wet-boew/wet-boew-wpss/releases/download/4.1.0/WPSS_Tool.exe
