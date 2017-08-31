## Web and Open Data Validator version 6.6.0

The Web and Open Data Validator provides web developers and quality assurance testers the ability to perform a number of web site, web page validation and Open data validation tasks at one time. Web site checking includes
- WCAG 2.0 A an AA
- Link checking (e.g. broken links, broken anchors, cross language links)
- Mark-up validation (HTML, CSS, XML, Javascript)
- Mobile optimization (based on Yahoo's best practices)

Open data checking includes
- CSV, JSON, JSON schema and XML validation
- Content validation based on data dictionary patterns

## Major Changes

Web Tool

```
- Fix bug in PDF file checker which can cause it to hang.
- Check for multiple <main> tags or tags with role="main" - WCAG_2.0-SC1.3.1
```

Open Data_Tool

```
- Don't analyze content to determine encoding of data files, only use the charset 
  HTTP::Response header or the presence of a UTF-8 BOM - OD_ENC
- If there is no data dictionary, don't report errors with JSON-CSV field names - TP_PW_OD_DATA
- Remove leading and trailing whitespace from JSON field names before checking 
  data dictionary - TP_PW_OD_DATA
- To allow for offline installations, add Python module vcversioner version 2.16 
  (used by jsonschema).
```

Version 6.6.0 contains the following updates and additions

## Web

```
- Fix bug in PDF file checker which can cause it to hang.
- Check for multiple <main> tags or tags with role="main" - WCAG_2.0-SC1.3.1
```

## Open Data

```
- Don't analyze content to determine encoding of data files, only use the charset 
  HTTP::Response header or the presence of a UTF-8 BOM - OD_ENC
- If there is no data dictionary, don't report errors with JSON-CSV field names - TP_PW_OD_DATA
- Remove leading and trailing whitespace from JSON field names before checking 
  data dictionary - TP_PW_OD_DATA
- Correct bug with CSV row field count check - OD_DATA
- Update csv-validator to version 1.2-RC2
- Update jsonschema to version 2.6.0
- To allow for offline installations, add Python module vcversioner version 2.16 
  (used by jsonschema).
- Improve exception handling for headings and lists in CSV data cells - OD_DATA
```

## Web and Open Data Validator Installer

The tool installer, WPSS_Tool.exe, does NOT include the required Perl or Python installers.  
Perl and Python must be installed on the workstation prior to installing the WPSS_Tool.

Supported versions of Perl include
- Strawberry Perl 5.18 (32 bit) available from http://strawberry-perl.googlecode.com/files/strawberry-perl-5.18.1.1-32bit.msi

Supported versions of Python include
- Python 2.7.6 available from http://python.org/ftp/python/2.7.6/python-2.7.6.msi

Required version of Java
- The HTML5 validator required Java 8 or later.

The WPSS_Tool has been tested on the following platforms
- Windows 7 (32 bit), Strawberry Perl 5.18 (32 bit), Python 2.7.6

The WPSS Tool installer is available as a release in this repository
- https://github.com/wet-boew/wet-boew-wpss/releases/download/6.6.0/WPSS_Tool.exe
