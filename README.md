## Web and Open Data Validator version 6.7.0

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
- Stop redirecting if a URL redirects back to itself.
- Allow input to be nested in label - WCAG_2.0-F68
```

Open Data_Tool

```
- Clarify error message if header row is not found - TP_PW_OD_DATA
- Ensure file: protocol URLs have 3 slash characters after the colon.
- Don't report row count mismatch errors for language variants of CSV files, report 
  mismatches in the number of non-blank cells in columns - OD_DATA
- Check data dictionary labels and CSV column headings for leading or trailing 
  whitespace - TP_PW_OD_DATA
- Check for UTF-8 BOM in JSON data files - TP_PW_OD_DATA
- Check for duplicate data files - OD_DATA
```

Version 6.7.0 contains the following updates and additions

## Web

```
- Stop redirecting if a URL redirects back to itself.
- Allow input to be nested in label - WCAG_2.0-F68
```

## Open Data

```
- Clarify error message if header row is not found - TP_PW_OD_DATA
- Ensure file: protocol URLs have 3 slash characters after the colon.
- Don't report row count mismatch errors for language variants of CSV files, report 
  mismatches in the number of non-blank cells in columns - OD_DATA
- Check data dictionary labels and CSV column headings for leading or trailing 
  whitespace - TP_PW_OD_DATA
- Check for UTF-8 BOM in JSON data files - TP_PW_OD_DATA
- Check for duplicate data files - OD_DATA
- Check for python 2.7.0 or later at install time.
- Set the user agent string for the non-robots user agent.
- Add "WPSS_Tool" to user agent string for Java tools.
- Strip named anchors from URL when checking <data_type> URL in data dictionary 
  to avoid possible multiple retrievals of the data dictionary file.
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
- https://github.com/wet-boew/wet-boew-wpss/releases/download/6.7.0/WPSS_Tool.exe
