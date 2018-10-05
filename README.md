## Web and Open Data Validator version 6.9.0

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
 - A number of new EPUB checks added based on the International Digital Publishing Forum 
   accessibility techniques.
- Include ARIA landmarks in error messages reported for HTML pages to help detect page 
   template issues.
- Check for proper use and nesting of WAI-ARIA role values.
```

Open Data_Tool

```
- Content errors are reported in a separate content tab and results file.
- A number of content checks are performed such as identical values in a column, 
   inconsistent spacing, punctuation, pluralization in values - TP_PW_OD_CONT
- Check for leading or trailing whitespace in CSV fields - TP_PW_OD_CONT
- Check for whitespace inside of heading labels - TP_PW_OD_CONT
- Allow for MARC data files.
```

Version 6.9.0 contains the following updates and additions

## Web

```
- Check heading levels are in proper nested order in EPUB files - EPUB_TITLE_002
- Check that there is only 1 top level heading in a <section> in EPUB files - EPUB_TITLE_002
- Check for list of tables in navigation if there are tables in EPUB content 
  documents - EPUB-ACCESS-002
- Check for no redirect URL after login form submission.
- Include ARIA landmarks in error messages reported for HTML pages to help detect 
  page template issues.
- Set the hash bang line in Perl and Python scripts in case of non-standard installs.
- Check that a tag with a role is contained by a tag with the required context 
  role - WCAG_2.0-H88.
- Check that tags that have WAI-ARIA attributes are contained in tags that have 
  an appropriate role value - WCAG_2.0-H88.
- Don't report errors for emphasised text inside headings - WCAG_2.0-F2
- Validate MARC files using the Metadata-qa-marc validator - WCAG_2.0-G134
- Add testcase group profile for PWGSC WET 4.0 Intranet.
- Check for required context roles if a tag has an explicit or implicit 
  WAI-ARIA role - WCAG_2.0-H88.
```

## Open Data

```
- Check for identical values for all cells in a column - TP_PW_OD_CONT
- Display content errors in content tab.
- Check for leading or trailing whitespace in CSV fields - TP_PW_OD_CONT
- Check for whitespace inside of heading labels - TP_PW_OD_CONT
- Check that the number of columns match for all data files in a dataset - TP_PW_OD_CONT
- Check that date (YYYY-MM-DD) columns match for language variants of data files - OD_DATA
- Check text columns for consistency in spacing, punctuation and pluralization 
   of values - TP_PW_OD_CONT
- Allow for MARC data files.
- Report duplicate CSV rows under testcase identifier TP_PW_OD_CONT
- Report duplicate JSON-CSV arrays under testcase identifier TP_PW_OD_CONT
- Accept application/csv as a mime type for CSV files.
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
- https://github.com/wet-boew/wet-boew-wpss/releases/download/6.9.0/WPSS_Tool.exe
