## Web and Open Data Validator version 6.5.0

The Web and Open Data Validator provides web developers and quality assurance testers the ability to perform a number of web site, web page validation and Open data validation tasks at one time.

## Major Changes

Web Tool

```
- Check the mime-type of image links and favicon to ensure that it is an image 
  mime-type - BAD_IMAGE_MIME_TYPE
- Correct bug in URL parsing in PhantomJS user agent that caused some URLs to be truncated 
  when sent to web servers.
- Update HTML5 validator to version 17.7.0.
- Check for invalid separator for dc.subject terms - Metadata

```

Open Data_Tool

```
- Check for missing module when running JSON schema validator - OD_VAL
- Check for CSV version for each JSON-CSV data file - TP_PW_OD_DATA
- Check that each item in the JSON-CSV data array have the same number and fields and 
  same field names - OD_DATA
- Check that all data items match for JSON-CSV and CSV variants of data files - OD_DATA
```

Version 6.5.0 contains the following updates and additions

## Web

```
- Check the mime-type of image links and favicon to ensure that it is an image 
  mime-type - BAD_IMAGE_MIME_TYPE
- Correct bug in URL parsing in PhantomJS user agent that caused some URLs to be truncated 
  when sent to web servers.
- Correct merging of links from original, modified and generated HTML markup.
- Update HTML5 validator to version 17.7.0.
- Check for invalid separator for dc.subject terms - Metadata
- Check for 64 bit Perl installation.  The Win32::GUI module will not install on a 64 bit 
  Perl installation.  
```

## Open Data

```
- Check for missing module when running JSON schema validator - OD_VAL
- Check for CSV version for each JSON-CSV data file - TP_PW_OD_DATA
- Check that language variations of JSON-CSV data files have the same number of rows 
  and same fields - OD_DATA
- Check that CSV and JSON-CSV data files have the same number of data rows - OD_DATA
- Check that each item in the JSON-CSV data array have the same number and fields and 
  same field names - OD_DATA
- Check that CSV column headings and JSON-CSV data item field names match in JSON-CSV and 
  CSV variants of data files - OD_DATA
- Check that CSV column types and JSON-CSV data item field types match in JSON-CSV and 
  CSV variants of data files - OD_DATA
- Check that numeric CSV column sums and numeric JSON-CSV data field values match in 
  SON-CSV and CSV variants of data files - OD_DATA
- Check that all data items match for JSON-CSV and CSV variants of data files - OD_DATA
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
- https://github.com/wet-boew/wet-boew-wpss/releases/download/6.5.0/WPSS_Tool.exe
