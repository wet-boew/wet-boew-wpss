WPSS Validation Tool version 5.1.0
-----------------------------------

The WPSS Validation Tool provides web developers and quality assurance testers the ability to perform a number of web site and web page validation tasks at one time. The tool crawls a site to find all of the documents then analyses each document with a number of validation tools.

Version 5.1.0 contains the following updates and additions

WPSS_Tool
---------

    - Don't include <script> content when analysing actual page content - SWU_E2.2.6
    - Add results tab and checks for mobile optimization based on YAHOObest practices.
    - Move supporting programs to a bin folder from the top level folder.
    - Additional firewall blocked link pattern.
    - Update GC Core Subject Thesaurus to March 26th, 2015 version.
    - Correct handling of dcterms.subject and the core subject thesaurus.
    - Limit error message in CSV to 10K characters to avoid Excel limitation.
    - Remove WCAG 2.0 SCR21 technique from WCAG 2.0 profile as it results in a large number of 
      false errors.
    - Add testcase profile for markup validation.  Default profile will validate web pagse 
      only (e.g. HTML) and exclude supporting files (e.g. CSS, JavaScript).
    - Check for inconsistent charset values in HTTP::Headers and meta tags in HTML 
      pages - SWI_C.
    - Don't report errors for input outside of a form.  JavaScript may provide the 
      behaviour - WCAG_2.0-F43
    - Check for possible formid attribute on inputs to associate an input that is outside 
      of a form back to a form - WCAG_2.0-F43
    - Check for captions for <audio> tags - WCAG_2.0-G87
    - Include ARIA attributes when constructing labels - WCAG_2.0-H44.
    - Add firewall check URL to allow the program to authenticate to the PWGSC firewall 
      before analysing sites or pages.

Note: <b>The WPSS Tool validates HTML5 markup.</b>


Open Data Tool
--------------

    - Allow for and validate JSON data files.
    - Run web accessibility checks (WCAG 2.0) on HTML URLs. 

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
  - https://github.com/wet-boew/wet-boew-wpss/releases/download/5.1.0/WPSS_Tool.exe
