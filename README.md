## Web and Open Data Validator version 6.12.0

The Web and Open Data Validator provides web developers and quality assurance testers the ability to perform a number of web site, web page validation and Open data validation tasks at one time. Web site checking includes
- Accessibility: WCAG 2.0, Deque AXE or Pa11y
- Link checking (e.g. broken links, broken anchors, cross language links)
- Mark-up validation (HTML, CSS, XML, Javascript)
- Mobile optimization (based on Yahoo's best practices)

Open data checking includes
- CSV, JSON, JSON schema and XML validation
- Content validation based on data dictionary patterns
- Data value consistency

## Major Changes

This version of the tool no longer works with Perl 5.24 or earlier on Windows.  You must upgrade to Perl 5.26 or later. It supports both 32 and 64 bit installations.

### Web Tool

```    
    - Upgrade Win32::GUI package to version 1.14
    - Allow installation on latest Perl version (5.30) as well as 64 bit installations on Windows. Minimum Perl version 5.26.1 for Windows.
    - Use axe-cli and axe-core to check Deque AXE testcases - AXE.
    - Allow div tag to be a child tag of a dl tag - WCAG_2.0-SC1.3.1
    - Add WCAG level A or AA to testcase results.
    - Add tag Xpath to testcase results.
```


### Open Data_Tool

```
    - Upgrade Win32::GUI package to version 1.14
    - Allow installation on latest Perl version (5.30) as well as 64 bit installations. Minimum Perl version 5.26.1  for Windows.
    - Convert accented characters to unaccented when checking for consistent values in CSV fields - TP_PW_OD_CONT_CONSISTENCY
    - Abort JSON schema validation if there are too many errors. This avoids the appearance of hanging when validating large JSON files that contain lots of validation errors - OD_VAL
    - Check for possible scientific notation (e.g. 1.3e-005) in CSV cell values - TP_PW_OD_CONT
    - Check for possible URLs in CSV cell values - TP_PW_OD_CONT
    - Check for newline, linefeed or return characters in CSV column headings - TP_PW_OD_DATA
    - Report multi-column data inconsistencies under a new testcase identifier - TP_PW_OD_CONT_COL_CONSISTENCY
    - Check the Flesch Kincaid reading level of the English dataset description in the JSON dataset object - OD_REG
```

A new Open Data testcase profile “PWGSC OD (core)” is available that eliminates duplicate data and inconsistent data checks from testing.  This should be used for datasets that have valid duplicate or inconsistent data cells as this reduces false error messages. 

Version 6.12.0 contains the following updates and additions

## Web

```
    - Upgrade Win32::GUI package to version 1.14
    - Allow installation on latest Perl version (5.30) as well as 64 bit installations on Windows. Minimum Perl version 5.26.1 for Windows.
    - Eliminate support for ActiveState Perl as Win32::GUI PPM will not install on the latest community releases.
    - Use axe-cli and axe-core to check Deque AXE testcases - AXE.
    - Allow div tag to be a child tag of a dl tag - WCAG_2.0-SC1.3.1
    - Defer some configuration and initialization until needed. This speeds up loading and starting of the program.
    - Check for whitespace in URL strings.
    - Report the list of URLs that are skipped during a crawl (e.g. duplicate content).
    - Add WCAG level A or AA to testcase results.
    - Add tag Xpath to testcase results.
```

## Open Data

```
   - Upgrade Win32::GUI package to version 1.14
    - Allow installation on latest Perl version (5.30) as well as 64 bit installations. Minimum Perl version 5.26.1  for Windows.
    - Allow spaces in file path for file: URLs.
    - Add optional field to data dictionary specification to allow the specification of consistency of value between pairs of data columns across data rows - TP_PW_OD_CONT_CONSISTENCY
    - Check JSON arrays for possible data dictionary terms, not just JSON objects.
    - Convert accented characters to unaccented when checking for consistent values in CSV fields - TP_PW_OD_CONT_CONSISTENCY
    - Abort JSON schema validation if there are too many errors. This avoids the appearance of hanging when validating large JSON files that contain lots of validation errors - OD_VAL
    - Check for possible scientific notation (e.g. 1.3e-005) in CSV cell values - TP_PW_OD_CONT
    - Check for possible URLs in CSV cell values - TP_PW_OD_CONT
    - Check for newline, linefeed or return characters in CSV column headings - TP_PW_OD_DATA
    - Defer some configuration and initialization until needed. This speeds up loading and starting of the program.
    - If a data dictionary heading has language specific labels, check that all required languages are found - TP_PW_OD_DD
    - Check some Open Government registry metata values (e.g. date released, data modified, update frequency) - OD_REG
    - Report multi-column data inconsistencies under a new testcase identifier - TP_PW_OD_CONT_COL_CONSISTENCY
    - Check the Flesch Kincaid reading level of the English dataset description in the JSON dataset object - OD_REG
```

## Web and Open Data Validator Installation on Windows

The tool installer, WPSS_Tool.exe, does NOT include the required Perl or Python installers.  
Perl and Python must be installed on the workstation prior to installing the WPSS_Tool.

Supported versions of Perl include
- Strawberry Perl 5.26 or later (32 or 64 bit) available from http://strawberryperl.com

Does NOT work with Strawberry Perl versions earlier than 5.26 and does not work with ActiveState Perl's community release.

Supported versions of Python include
- Python 2.7.6 or newer available from https://www.python.org/downloads/windows/
- Does not support Python 3.

Required version of Java
- The HTML5 validator required Oracle Java 8 or later and OpenJDK version 11.

The WPSS_Tool has been tested on the following platforms
- Windows 10 (64 bit), Strawberry Perl 5.26 (64 bit), Python 2.7.13



#### Chrome Headless User agent
  The Chrome headless user agent may be used rather than PhantomJS.  The following must be installed in order to use Chrome
      - Chrome version 69 or newer - https://www.google.com/chrome/
      - Node version 8 or newer - https://nodejs.org/en/download/
      - Puppeteer core module for node (install from command prompt) "npm install –g puppeteer-core"

If Chrome is not available, the WPSS_Tool will fall back to using PhantomJS and a message will be written to the stdout.txt file.

#### Pa11y Accessibility Test Tool
The Pa11y accessibility test tool may be run against web pages.  The checks cannot be performed on pages behind a login (e.g. applications).  A new accessibility testcase profile is available to enable this checking.  Details on the Pa11y tool are available at https://github.com/pa11y/pa11y.
This tool requires
      - Node version 8 or newer - https://nodejs.org/en/download/
      - Pa11y module for node (install from command prompt) "npm install –g pa11y"

#### Deque AXE accessibility tool
The Deque AXE  accessibility test tool may be run against web pages.  The checks cannot be performed on pages behind a login (e.g. applications).  A new accessibility testcase profile is available to enable this checking.  Details on the Deque AXE tool are available at o	https://github.com/dequelabs/axe-core and https://github.com/dequelabs/axe-cli.
This tool requires
      - Node version 8 or newer - https://nodejs.org/en/download/
      - Deque AXE core (install from command prompt) "npm install –g axe-core"
      - Deque AXE CLI (install from command prompt) "npm install –g axe-cli"


The WPSS Tool installer is available as a release in this repository
- https://github.com/wet-boew/wet-boew-wpss/releases/download/6.12.0/WPSS_Tool.exe

## Web and Open Data Validator Installation on Linux

The tool distribution, WPSS_Tool_Linux.zip, does NOT include the required Perl or Python installers.  
Perl and Python must be installed on the prior to installing the WPSS_Tool.

Supported versions of Perl include
- Perl 5.0 or later (32 or 64 bit).

Supported versions of Python include
- Python 2.7.6 or newer.
- Does not support Python 3.

Required version of Java
- The HTML5 validator required Oracle Java 8 or later and OpenJDK version 11.

The WPSS_Tool has been tested on the following platforms
- Redhat, Perl 5.24 (32 bit), Python 2.7.15

The Linux version has not been tested with headless chrome, pa11y or Deque AXE.

The WPSS Tool installer is available as a release in this repository
- https://github.com/wet-boew/wet-boew-wpss/releases/download/6.12.0/WPSS_Tool_Linux.zip

