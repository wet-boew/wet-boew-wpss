## Web and Open Data Validator version 6.8.0

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
- Limit size of link check cache by content size as well as number of links to control memory usage.
- Update HTML5 validator to version 17.11.1.
- Generate a link details CSV file for all links in web pages.  
- Add checks for EPUB Accessibility Techniques version 1.0 
      http://www.idpf.org/epub/a11y/techniques/techniques.html
```

Open Data_Tool

```
- Check for blank column heading - TP_PW_OD_DATA
- Use JSON::PP, the pure Perl backend to JSON.pm.  In Strawberry Perl 5.22 and later on 
Windows, the JSON::XS module fails to decode a JSON string in a multi-threaded program.
- Include all non-blank lines in list item - OD_DATA
```

Version 6.8.0 contains the following updates and additions

## Web

```
- Add "WPSS_Tool" to user agent string for PhantomJS.
- Limit size of link check cache by content size as well as number of links to control memory usage.
- Update HTML5 validator to version 17.11.1.
- Generate a link details CSV file for all links in web pages.
- Add checks for EPUB Accessibility Techniques version 1.0 
   http://www.idpf.org/epub/a11y/techniques/techniques.html
- Add configuration item to limit the number of errors to report for a single URL.
```

## Open Data

```
- Check for blank column heading - TP_PW_OD_DATA
- Use JSON::PP, the pure Perl backend to JSON.pm.  In Strawberry Perl 5.22 and later on 
Windows, the JSON::XS module fails to decode a JSON string in a multi threaded program.
- Include all non-blank lines in list item - OD_DATA
- Add configuration item to limit the number of errors to report for  a single URL.
```

## Web and Open Data Validator Installer

The tool installer, WPSS_Tool.exe, does NOT include the required Perl or Python installers.  
Perl and Python must be installed on the workstation prior to installing the WPSS_Tool.

Supported versions of Perl include
- Strawberry Perl 5.18 (32 bit) available from http://strawberryperl.com/download/5.18.4.1/strawberry-perl-5.18.4.1-32bit.msi
  to
- Strawberry Perl 5.24 (32 bit) available from http://strawberryperl.com/download/5.24.3.1/strawberry-perl-5.24.3.1-32bit.msi
It does not work in Perl 5.26 as some required modules are not supported.

Supported versions of Python include
- Python 2.7.6 available from http://python.org/ftp/python/2.7.6/python-2.7.6.msi

Required version of Java
- The HTML5 validator required Java 8 or later.

The WPSS_Tool has been tested on the following platforms
- Windows 7 (32 bit), Strawberry Perl 5.18 (32 bit), Python 2.7.6

The WPSS Tool installer is available as a release in this repository
- https://github.com/wet-boew/wet-boew-wpss/releases/download/6.8.0/WPSS_Tool.exe
