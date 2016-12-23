Web and Open Data Validator version 6.2.0
-----------------------------------------

The Web and Open Data Validator (formerly the WPSS Validation Tool) provides web developers and quality assurance testers the ability to perform a number of web site, web page validation and Open data validation tasks at one time.

Major Changes
----------------------
Web Tool

    - Change program folder and program names in Windows start menu.  Folder is "Web and Open Data Validator", 
      tools are "Web Tool" and "Open Data Tool".
    - Update Core Subject Thesaurus to July 4, 2016 version - DC Subject	
    - Add a PhantomJS markup server program to remain active for an analysis run and save the delays in 
      starting PhantomJS for each page retrieved.
    - When merging link details from original markup and generated markup, use line/column information 
      from the generated markup.

Open Data_Tool

    - Check for duplicate rows in CSV file - OD_CSV_1
    - Check for duplicate columns in CSV file - OD_CSV_1
    - If an XML data file contains a schema specification using the xsi:schemaLocation or 
      xsi:noNamespaceSchemaLocation attribute, validate the XML against the schema - OD_3
    - Check for BOM (Byte Order Mark) in all text files - OD_TP_PW_BOM
    - If an XML data file contains a DOCTYPE declaration, validate the XML against the DOCTYPE - OD_3
    - Generate a dataset inventory CSV file containing details of the dataset files (URL, size, mime-type, etc).
    - Check the alternate language versions of CSV datafiles contain the same number of columns - OD_CSV_1


Version 6.2.0 contains the following updates and additions

Web
---

    - Prefix all temporary file names with WPSS_TOOL_ for easy deletion.
    - Update Core Subject Thesaurus to July 4, 2016 version - DC Subject
    - Move supporting programs to a bin folder from the top level folder.
    - Add a PhantomJS markup server program to remain active for an analysis
      run and save the delays in starting PhantomJS for each page retrieved.
    - Change tool name to "Web and Open Data Validator" to better describe
      the purpose of the tool.
    - When merging link details from original markup and generated markup,
      use line/column information from the generated markup.
    - Change program folder and program names in Windows start menu.  Folder
      is "Web and Open Data Validator", tools are "Web Tool" and
      "Open Data Tool".

Open Data
---------

    - Check for duplicate rows in CSV file - OD_CSV_1
    - Check for duplicate columns in CSV file - OD_CSV_1
    - Remove API specific testcase identifiers
    - If an XML data file contains a schema specification using the
      xsi:schemaLocation or xsi:noNamespaceSchemaLocation attribute,
      validate the XML against the schema - OD_3
    - Use custom CSV file parser to avoid potential error in Text::CSV
      module and quoted fields with greater than 32K characters.
    - Check for BOM (Byte Order Mark) in all text files - OD_TP_PW_BOM
    - If an XML data file contains a DOCTYPE declaration, validate
      the XML against the DOCTYPE - OD_3
    - Replace the xsd-validator tool with the Xerces tool to validate
      XML against schema or a DOCTYPE.
    - Check for a DOCTYPE or schema specification in XML files - OD_3
    - Validate XML content against data patterns specified in the
      data dictionary - OD_XML_1
    - Update JSON open data description URL handling due to changes in
      the open.canada.ca site.
    - Generate a dataset inventory CSV file containing details of the
      dataset files (URL, size, mime-type, etc).
    - Check the alternate language versions of CSV datafiles contain the
      same number of columns - OD_CSV_1


Web and Open Data Validator Installer
-------------------------------------

The tool installer, WPSS_Tool.exe, does NOT include the required Perl or Python installers (as was the case for previous releases).  Perl and Python must be installed on the workstation prior to installing the WPSS_Tool.

Supported versions of Perl include
- Strawberry Perl 5.18 (32 bit) available from http://strawberry-perl.googlecode.com/files/strawberry-perl-5.18.1.1-32bit.msi

Supported versions of Python include
- Python 2.7.6 available from http://python.org/ftp/python/2.7.6/python-2.7.6.msi

The WPSS_Tool has been tested on the following platforms
- Windows 7 (32 bit), Strawberry Perl 5.18 (32 bit), Python 2.7.6

The WPSS Tool installer is available as a release in this repository
  - https://github.com/wet-boew/wet-boew-wpss/releases/download/6.2.0/WPSS_Tool.exe
