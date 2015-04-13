WPSS Validation Tool version 5.0.0
-----------------------------------

The WPSS Validation Tool provides web developers and quality assurance testers the ability to perform a number of web site and web page validation tasks at one time. The tool crawls a site to find all of the documents then analyses each document with a number of validation tools.

Testcase profile names have changed to be more descriptive, any existing profiles you may have will have to be changed.

A testcase group selector has been added to the configuration tab which can use used to set all testcase profiles, rather than having to set each profile.  The profile group names include the Network Scope, Theme and WET version, for example

    - Canada.ca WET 4.0
    - Internet TBS WET 3.0
    - Internet TBS WET 4.0
    - WCAG 2.0

Using the group setting will ensure testcase profiles are set consistently.

A CSV file of testcase results is generated and contains results from all tests.  The CSV file name has a _rslt.csv suffix.


Version 5.0.0 contains the following updates and additions

WPSS_Tool
---------

    - Add selector for testcase profile groups to set profiles for all checks.
    - Change names of testcase profiles to be more descriptive.
    - Don't report bold or emphasised text immediately after a heading as a pseudo-heading, 
      it may be supporting text - WCAG_2.0-F2
    - Create testcase profiles for WET 4.0 GC Intranet, WET 4.0 Internet and Canada.ca
    - Generate CSV version of testcase results. 

Note: <b>The WPSS Tool validates HTML5 markup.</b>


Open Data Tool
--------------

    - Check for supporting files in dataset and don't process them as data files.
    - Check for a match in the number of rows of language instances of CSV files - OD_CSV_1
    - Save dataset content in local files rather than HTTP::Response object to avoid 
      "out of memory" errors for very large dataset files.
    - Generate CSV version of testcase results.
 

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
  - https://github.com/wet-boew/wet-boew-wpss/releases/download/5.0.0/WPSS_Tool.exe
