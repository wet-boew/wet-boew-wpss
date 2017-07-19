## Web and Open Data Validator version 6.4.0

The Web and Open Data Validator provides web developers and quality assurance testers the ability to perform a number of web site, web page validation and Open data validation tasks at one time.

## Major Changes

Web Tool

```
- Don't exit PhantomJS when there is a Javascript error, this can cause
  error dialogs to appear on Windows systems, which stalls the program.
```

Open Data_Tool

```
- Check for only whitespace as first line of a multi-line field in a CSV data file - OD_DATA
- Add link checking for supporting documentation HTML files.
- Check CSV text fields for possible WCAG 2.0 plain text technique accessibility 
   errors (e.g. lists in cells) - OD_DATA
- Check that there is the same number of language specific data files in a dataset - OD_URL
- Check that CSV column content types (e.g. numeric, text) match for all language 
   variations of a data file - OD_DATA
- Check that the sum of numeric CSV column values match for all language variations 
   of a data file - OD_DATA
- Check that the number of non-blank cells of CSV columns match for all language 
   variations of a data file - OD_DATA
```

Version 6.4.0 contains the following updates and additions

## Web

```
- Don't exit PhantomJS when there is a Javascript error, this can cause
  error dialogs to appear on Windows systems, which stalls the program.
- Update EPUB validator to version 4.0.2.
- Additional EPUB file checks (container.xml, OPF file) - WCAG_2.0-G134
```

## Open Data

```
- Check for only whitespace as first line of a multi-line field in a
  CSV data file - OD_DATA
- Add link checking for supporting documentation HTML files.
- Check for UTF-8 encoding of resource files of type text, HTML and XML
  only - OD_ENC
- Allow for multiple schema specifications in JSON data - OD_VAL
- Check CSV text fields for possible WCAG 2.0 plain text technique
  accessibility errors (e.g. lists in cells) - OD_DATA
- Check that there is the same number of language specific data files
  in a dataset - OD_URL
- Check that if there are language specific data files, that all
  required languages (e.g. English, French) are found - TP_PW_OD_DATA
- Check that CSV column content types (e.g. numeric, text) match
  for all language variations of a data file - OD_DATA
- Check that the sum of numeric CSV column values match for all
  language variations of a data file - OD_DATA
- Check that the number of non-blank cells of CSV columns match
  for all language variations of a data file - OD_DATA
- Check for $schemaExtension field for the specification of schema
  extensions that the JSON data file must comply to. - OD_VAL
- Check for BOM (Byte Order Mark) or HTTP::Response charset to
  specify UTF-8 encoding for JSON files - OD_ENC
- Check that data array items in JSON-CSV files contain the same
  number of fields  - OD_DATA
- Check that there are no duplicate data array items in JSON-CSV
  files - OD_DATA
- Check for a CSV file for each JSON-CSV file and that the number
  of data array items matches the CSV data row count - OD_DATA
```

## Web and Open Data Validator Installer

The tool installer, WPSS_Tool.exe, does NOT include the required Perl or Python installers (as was the case for previous releases).  Perl and Python must be installed on the workstation prior to installing the WPSS_Tool.

Supported versions of Perl include
- Strawberry Perl 5.18 (32 bit) available from http://strawberry-perl.googlecode.com/files/strawberry-perl-5.18.1.1-32bit.msi

Supported versions of Python include
- Python 2.7.6 available from http://python.org/ftp/python/2.7.6/python-2.7.6.msi

Required version of Java
- The HTML5 validator required Java 8 or later.

The WPSS_Tool has been tested on the following platforms
- Windows 7 (32 bit), Strawberry Perl 5.18 (32 bit), Python 2.7.6

The WPSS Tool installer is available as a release in this repository
- https://github.com/wet-boew/wet-boew-wpss/releases/download/6.4.0/WPSS_Tool.exe
