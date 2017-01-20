## Web and Open Data Validator version 6.3.0

The Web and Open Data Validator (formerly the WPSS Validation Tool) provides web developers and quality assurance testers the ability to perform a number of web site, web page validation and Open data validation tasks at one time.

## Major Changes

Web Tool

```
- Update HTML 5 validator to June 29, 2016 version.  This version requires a Java 8 
  environment.
```

Open Data_Tool

```
- Check for required fields in JSON dataset description file - OD_VAL
- Check for required data dictionary and data files in JSON dataset 
   description - TP_PW_OD_DATA
- If a JSON file contains a $schema specification, validate the contents against the 
   schema using the jsonschema validator - OD_VAL
```

Version 6.3.0 contains the following updates and additions

## Web

```
- Set appropriate Java stack size depending on 32 or 64 bit Windows system.
- Create unique, temporary cache directory and cookie file for the crawler 
   module to allow multiple instances of the tool to run on the same
   workstation.
```

## Open Data

```
- Skip open data checks for alternate format data files (e.g. Excel)
- Report broken or malformed URLs for dataset files - OD_URL
- Include file checksum in inventory CSV file.
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
- https://github.com/wet-boew/wet-boew-wpss/releases/download/6.3.0/WPSS_Tool.exe
