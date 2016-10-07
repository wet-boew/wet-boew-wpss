WPSS Validation Tool version 6.1.0
-----------------------------------

The WPSS Validation Tool provides web developers and quality assurance testers the ability to perform a number of web site and web page validation tasks at one time. The tool crawls a site to find all of the documents then analyses each document with a number of validation tools.

Major Changes
----------------------
This version of the tool makes use of a JavaScript aware headless user agent to retrieve HTML web documents.  The user agent executes JavaScript when the page loads and provides generated HTML mark-up to be used by the WPSS_Tool.

Version 6.1.0 contains the following updates and additions

WPSS_Tool
---------

    - Don't check alt text for images inside of anchor tags as the same image
      may be used with different alt text for different purposes (e.g. a
      calendar image to open a widget in a form) - WCAG_2.0-G197
    - Check for inputs of type email in login forms.
    - Allow for extra links in skip links section.  Generated markup
      includes 1 extra link - SWU_TEMPLATE
    - Report duplicate label id failures as WCAG 2.0 F77 (F17 has been
      removed from WCAG).
    - Add configuration items to set the size of the URL list and direct HTML input buffer sizes.
    - Check for PWGSC web analytics code (i.e. piwik) on pages - TP_PW_ANALYTICS
    - Check <meta name="viewport" for possible text resize restrictions - WCAG_2.0-SC1.4.4
    - Generate a summary results CSV file similar to the summary at the bottom of the text 
       results.
    - Treat tables with role="presentation" as layout tables. Check for summary, caption or 
       headers in layout tables.
    - Report the use of white space to control formatting only once for a given 
       string - WCAG_2.0-F32
    - Use the definition term <dt> as possible introduction text for a list - WCAG_2.0-G115
    - Report a runtime error if any external tool fails to run.
    - Skip checking of id attribute values for <script> tags.

Open Data Tool
--------------

    - Check for duplicate column headers in CSV files - TP_PW_OD_CSV_1
    - Check for duplicate data dictionary definitions - OD_TXT_1
    - If an XML file contains a schema specification using the xsi:schemaLocation 
       attribute, validate the XML against the schema.
    - Perform XML schema validation using the xsd-validator tool.
    - Parse and extract data dictionary details (headings, definitions, etc.) from 
       PWGSC formatted XML data dictionaries.
    - Perform CSV data validation using the csv-validator tool.


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
  - https://github.com/wet-boew/wet-boew-wpss/releases/download/6.1.0/WPSS_Tool.exe
