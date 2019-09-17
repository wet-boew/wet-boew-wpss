## Web and Open Data Validator version 6.10.0

The Web and Open Data Validator provides web developers and quality assurance testers the ability to perform a number of web site, web page validation and Open data validation tasks at one time. Web site checking includes
- WCAG 2.0 A and AA
- Link checking (e.g. broken links, broken anchors, cross language links)
- Mark-up validation (HTML, CSS, XML, Javascript)
- Mobile optimization (based on Yahoo's best practices)

Open data checking includes
- CSV, JSON, JSON schema and XML validation
- Content validation based on data dictionary patterns

## Major Changes

Web Tool

```
    - Update HTML5 validator to version 18.8.29- HTML_VALIDATION
    - Changes and additional JAR files for Open JDK version 11 support.
    - Update to epubcheck 4.1.0 - EPUB_VALIDATION
```

Open Data_Tool

```
    - Remove punctuation only after letters (i.e. not in numbers) to reduce false 
       errors - TP_PW_OD_CONT
    - Check for at least 1 comma in the first line of CSV file - OD_VAL
    - Check for possible tab separator rather than comma separator in CSV files - OD_VAL
    - Report possible currency values in CSV fields (leading or trailing $ sign) - TP_PW_OD_CONT
    - Report thousands separator in numeric values in CSV fields (comma or space 
      separator) - TP_PW_OD_CONT
    - Report MARC validation errors as content errors rather than Open Data errors - TP_PW_OD_CONT
    - Validate very large XML files (> 100Mb) with a command line validator. Perl validation may fail
       due to a limitation in the XML::Parser module - OD_VAL
    - Check for very large text cells (> 32767 characters) in CSV files. These may be truncated by 
      spreadsheet tools (e.g. Excel) - TP_PW_OD_CONT
```

Version 6.10.0 contains the following updates and additions

## Web

```
    - Update HTML5 validator to version 18.8.29- HTML_VALIDATION
    - Skip check of property attribute in meta tags - SWI_E_RDFA
    - Check for illegal ancestor tag for main landmark - WCAG_2.0-SC1.3.1
    - Changes and additional JAR files for Open JDK version 11 support.
    - Update to epubcheck 4.1.0 - EPUB_VALIDATION
```

## Open Data

```
    - Include headings from data dictionary in file inventory CSV.
    - Remove punctuation only after letters (i.e. not in numbers) to reduce false 
       errors - TP_PW_OD_CONT
    - Check for at least 1 comma in the first line of CSV file - OD_VAL
    - Check for possible tab separator rather than comma separator in CSV files - OD_VAL
    - Include floating point (e.g. 0.00) as zero/blank values when checking for duplicate 
      columns - TP_PW_OD_CONT
    - Report possible currency values in CSV fields (leading or trailing $ sign) - TP_PW_OD_CONT
    - Report thousands separator in numeric values in CSV fields (comma or space 
       separator) - TP_PW_OD_CONT
    - Report MARC validation errors as content errors rather than Open Data errors - TP_PW_OD_CONT
    - Validate very large XML files (> 100Mb) with a command line validator.  Perl validation 
       may fail due to a limitation in the XML::Parser module - OD_VAL
    - Check that ZIP file is properly received before attempting to read it.
    - Check for very large text cells (> 32767 characters) in CSV files. These may be truncated 
       by spreadsheet tools (e.g. Excel) - TP_PW_OD_CONT
```

## Web and Open Data Validator Installer

The tool installer, WPSS_Tool.exe, does NOT include the required Perl or Python installers.  
Perl and Python must be installed on the workstation prior to installing the WPSS_Tool.

Supported versions of Perl include
- Strawberry Perl 5.24 (32 bit) available from http://strawberryperl.com/download/5.24.4.1/strawberry-perl-5.24.4.1-32bit.msi

Does NOT work with Strawberry Perl versions greater than 5.25, or 64 bit versions.

Supported versions of Python include
- Python 2.7.6 available from http://python.org/ftp/python/2.7.6/python-2.7.6.msi

Required version of Java
- The HTML5 validator required Oracle Java 8 or later and OpenJDK version 11.

The WPSS_Tool has been tested on the following platforms
- Windows 10 (64 bit), Strawberry Perl 5.24 (32 bit), Python 2.7.6

The WPSS Tool installer is available as a release in this repository
- https://github.com/wet-boew/wet-boew-wpss/releases/download/6.10.0/WPSS_Tool.exe
