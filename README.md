## Web and Open Data Validator version 6.11.0

The Web and Open Data Validator provides web developers and quality assurance testers the ability to perform a number of web site, web page validation and Open data validation tasks at one time. Web site checking includes
- Accessibility: WCAG 2.0, Deque AXE orPa11y
- Link checking (e.g. broken links, broken anchors, cross language links)
- Mark-up validation (HTML, CSS, XML, Javascript)
- Mobile optimization (based on Yahoo's best practices)

Open data checking includes
- CSV, JSON, JSON schema and XML validation
- Content validation based on data dictionary patterns
- Data value consistency

## Major Changes

### Web Tool

```
    - Update HTML5 validator to version 18.11.5 - HTML_VALIDATION
    - Check that ARIA properties have valid values - WCAG_2.0-SC4.1.2
    - Check that role values are valid - WCAG_2.0-SC4.1.2
    - Check for focusable content inside aria-hidden tags - WCAG_2.0-SC4.1.2
    - Don't report missing content for tags that have a presentation role - WCAG_2.0-G115
    - Use chrome as headless user agent if the browser and required node/puppeteer installation 
      is available.  Use PhantomJS as fallback.
    - Check for link text that is just punctuation - WCAG_2.0-H30
    - Check for nested interactive tags - WCAG_2.0-SC2.4.3
    - Check for valid role and tag combinations - WCAG_2.0-SC4.1.2
    - Check for text alternative on images with role="presentation" - WCAG_2.0-F39
    - Add testcases, checks and accessibility profile for Deque AXE rules.
    - Add testcases, checks and accessibility profile for Pa11y accessibility tool.
```

#### Chrome Headless User agent
  The Chrome headless user agent may be used rather than PhantomJS.  The following must be installed in order to use Chrome
      - Chrome version 69 or newer
      - Node version 8 or newer - https://nodejs.org/en/download/
      - Puppeteer core module for node (install from command prompt) "npm install –g puppeteer-core"

If Chrome is not available, the WPSS_Tool will fall back to using PhantomJS and a message will be written to the stdout.txt file.

#### Deque AXE accessibility ruleset
Some of the Deque AXE accessibility rules may be checked. A new accessibility testcase profile is available to enable this checking. Details of the ruleset is available at https://dequeuniversity.com/rules/axe/3.3. 

#### Pa11y Accessibility Test Tool
The Pa11y accessibility test tool may be run against web pages.  The checks cannot be performed on pages behind a login (e.g. applications).  A new accessibility testcase profile is available to enable this checking.  Details on the Pa11y tool are available at https://github.com/pa11y/pa11y.
This tool requires
      - Node version 8 or newer - https://nodejs.org/en/download/
      - Pa11y module for node (install from command prompt) "npm install –g pa11y"

### Open Data_Tool

```
    - Check that minimum and maximum values match in numeric and date columns for language 
      variants of data files - OD_DATA
    - Use first value in column as possible header label if no data dictionary is specified - OD_DATA
    - Check that heading descriptions are not the same as the heading label - TP_PW_OD_DD
    - Check that descriptions are different for each language - TP_PW_OD_DD
    - Don't check value inconsistencies for columns that have data patterns that would
      report errors - TP_PW_OD_CONT
    - Report duplicate data rows or columns under testcase id TP_PW_OD_CONT_DUP so it can be filtered
    - Report inconsistent data values under testcase id TP_PW_OD_CONT_CONSISTENCY so it can be 
       filtered
    - Check for inconsistent capitalization for short (fewer than 100 characters) text 
      cells - TP_PW_OD_CONT_CONSISTENCY
```

A new Open Data testcase profile “PWGSC OD (core)” is available that eliminates duplicate data and inconsistent data checks from testing.  This should be used for datasets that have valid duplicate or inconsistent data cells as this reduces false error messages. 

Version 6.11.0 contains the following updates and additions

## Web

```
    - Update HTML5 validator to version 18.11.5 - HTML_VALIDATION
    - Check that ARIA properties have valid values - WCAG_2.0-SC4.1.2
    - If there are multiple role values, use first non-abstract role.
    - Check that role values are valid - WCAG_2.0-SC4.1.2
    - Check for focusable content inside aria-hidden tags - WCAG_2.0-SC4.1.2
    - Don't report missing content for tags that have a presentation role - WCAG_2.0-G115
    - Use chrome as headless user agent if the browser and required node/puppeteer installation 
      is available.  Use PhantomJS as fallback.
    - If a <video> is inside a <figure>, the <figcaption> can be used for the video captions 
      text - WCAG_2.0-G87
    - Report missing captions or descriptions track for <audio> tags under technique 
      WCAG_2.0-G158 rather than G87.
    - Check that li, dt and dd tags appear in lists - WCAG_2.0-H88
    - Check for link text that is just punctuation - WCAG_2.0-H30
    - Check for nested interactive tags - WCAG_2.0-SC2.4.3
    - Check for valid role and tag combinations - WCAG_2.0-SC4.1.2
    - Update to epubcheck 4.2.1 - EPUB_VALIDATION
    - Check for text alternative on images with role="presentation" - WCAG_2.0-F39
    - Add testcases, checks and accessibility profile for Deque AXE rules.
      https://dequeuniversity.com/rules/axe/3.3
    - Add testcases, checks and accessibility profile for Pa11y
      accessibility tool. https://github.com/pa11y/pa11y
```

## Open Data

```
    - Don't check file suffix and mime-type for resources marked as "Other" in the
      dataset description JSON object - OD_URL
    - Check that minimum and maximum values match in numeric and date columns for language
      variants of data files - OD_DATA
    - Use first value in column as possible header label if no data dictionary is specified - OD_DATA
    - Check that heading descriptions are not the same as the heading label - TP_PW_OD_DD
    - Check that descriptions are different for each language - TP_PW_OD_DD
    - Record XML data file tags that match data dictionary terms as
      being equivalent to CSV column/Data dictionary headings.
    - Ignore directory paths when determining if data files are language variants of the same data.
    - Don't check value inconsistencies for columns that have data patterns that would report
      errors - TP_PW_OD_CONT
    - Check for duplicate resource URLs in dataset description JSON - TP_PW_OD_DATA
    - Update Xerces2 XML parser to version 2.12.0.
    - Report duplicate data rows or columns under testcase id TP_PW_OD_CONT_DUP so it can be filtered
    - Report inconsistent data values under testcase id TP_PW_OD_CONT_CONSISTENCY so it can be 
       filtered
    - Check for inconsistent capitalization for short (fewer than 100 characters) text 
      cells - TP_PW_OD_CONT_CONSISTENCY
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
- Windows 7 (64 bit), Strawberry Perl 5.24 (32 bit), Python 2.7.6

The WPSS Tool installer is available as a release in this repository
- https://github.com/wet-boew/wet-boew-wpss/releases/download/6.11.0/WPSS_Tool.exe
