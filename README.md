WPSS Validation Tool version 4.5.0
-----------------------------------

The WPSS Validation Tool provides web developers and quality assurance testers the ability to perform a number of web site and web page validation tasks at one time. The tool crawls a site to find all of the documents then analyses each document with a number of validation tools.

Version 4.5.0 contains the following updates and additions

WPSS_Tool
---------

  - Don't report WCAG_2.0-ARIA12 error for tags that have role="heading" if it also has an aria-level attribute greater than 6.
  - Include external style sheets when performing style based checks (e.g. hidden labels, pseudo headings).
  - Check for details tag that only includes a summary - WCAG_2.0-G115
  - Check for tags other than area, img & input that contain an alt attribute and that load an image via CSS - WCAG_2.0-F3
  - Check for styling and markup used to move content off screen for some WCAG errors (e.g. H44 - visible labels).
  - Generate page inventory containing page details (URL, title, H1, breadcrumb, etc).
  - Update anchor text and href values for GC Web Usability theme to match Canada.ca domain - SWU.
  - Include last heading in labels and legends to distinguish similar labels - WCAG_2.0-H44 and WCAG_2.0-H71.
 

Reminder: The WPSS Tool DOES NOT validate HTML5 markup.


Open Data Tool
--------------



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
  - https://github.com/wet-boew/wet-boew-wpss/releases/download/4.5.0/WPSS_Tool.exe
