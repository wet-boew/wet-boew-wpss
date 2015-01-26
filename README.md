WPSS Validation Tool version 4.8.0
-----------------------------------

The WPSS Validation Tool provides web developers and quality assurance testers the ability to perform a number of web site and web page validation tasks at one time. The tool crawls a site to find all of the documents then analyses each document with a number of validation tools.

Version 4.8.0 contains the following updates and additions

WPSS_Tool
---------

    - Add crawl depth option to limit the depth of a crawl.
    - Check if image alt is the same as the src URL or the image file
      name (with or without suffix) - WCAG_2.0-F30
    - Check for missing, invalid or broken src in <track> tags - WCAG_2.0-F8
    - Check for missing captions and descriptions tracks in <video> tag - WCAG_2.0-G87
    - Add Nu Markup Checker for HTML5 validation - WCAG_2.0-G134
    - Add W3C TTML validaton for ttml/xml validation - WCAG_2.0-G134
    - Check for duplicate attributes in XML content - WCAG_2.0-F77
    - Only report error for <hr /> that preceeds a <h1> heading
      not any other heading - WCAG_2.0-F43
 

Note: <b>The WPSS Tool now validates HTML5 markup.</b>


Open Data Tool
--------------
 

WPSS_Tool Installer
---------------------

The tool installer, WPSS_Tool.exe, does NOT include the required Perl or Python installers (as was the case for previous releases).  Perl and Python must be installed on the workstation prior to installing the WPSS_Tool.

Supported versions of Perl include
- Strawberry Perl 5.18 (32 bit) available from http://strawberry-perl.googlecode.com/files/strawberry-perl-5.18.1.1-32bit.msi

Supported versions of Python include
- Python 2.7.6 available from http://python.org/ftp/python/2.7.6/python-2.7.6.msi

The WPSS_Tool has been tested on the following platforms
- Windows 7 (32 bit), Strawberry Perl 5.18 (32 bit), Python 2.7.6

The WPSS Tool installer is available as a release in this repository
  - https://github.com/wet-boew/wet-boew-wpss/releases/download/4.8.0/WPSS_Tool.exe
