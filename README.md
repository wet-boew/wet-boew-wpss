WPSS Validation Tool version 5.2.0
-----------------------------------

The WPSS Validation Tool provides web developers and quality assurance testers the ability to perform a number of web site and web page validation tasks at one time. The tool crawls a site to find all of the documents then analyses each document with a number of validation tools.

Version 5.2.0 contains the following updates and additions

WPSS_Tool
---------

    - If a link has a non JavaScript onclick attribute, use that as the href value.
    - Reset heading levels inside section tags - TP_PW_H.
    - Update HTML5 validator to version 15.6.29.
    - Check if the captions file mime type matches the data type attribute of the track tag - 
      WCAG_2.0-F8
    - Mobile optimization: Check for no content in supporting files - NUM_HTTP
    - Mobile optimization: Check for no styles in CSS stylesheet file - NUM_HTTP
    - When checking dc.subject values, allow values with either windows right single 
      quote or regular single quote - Metadata Content
    - Don't report baseline technologies error if frames are used in HTML 5 - TP_PW_TECH
    - Add testcase group profile for Canada.ca sites using the PWGSC developed WET 4.0 
      template package.
    - Check for and remove any BOM from TTML files before validation.

Open Data Tool
--------------

    - Decode data dictionary files if they are UTF-8 encoded to fix bug with CSV headers 
      that have accented characters - OD_CSV_1
    - Do case sensitive checks for dictionary terms and CSV headers - OD_CSV_1


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
  - https://github.com/wet-boew/wet-boew-wpss/releases/download/5.2.0/WPSS_Tool.exe
