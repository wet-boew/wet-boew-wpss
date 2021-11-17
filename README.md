## Web and Open Data Validator version 6.13.0

The Web and Open Data Validator provides web developers and quality assurance testers the ability to perform a number of web site, web page validation and Open data validation tasks at one time. Web site checking includes
- Accessibility: WCAG 2.0, Deque AXE, ACT Rules, or Pa11y
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
    - Update HTML5 validator to version 20.6.30 - HTML_VALIDATION
    - Add testcase profile and checks for ACT rule set https://act-rules.github.io/rules/. 
    - Search for free port to use for markup server task.
    - Add user agent version/installation details to output tabs.
    - Add supporting tools (e.g. pa11y) versions to accessibility tab.
```


### Open Data_Tool

```
    - Check that the language appropriate label is used for headings with multiple language specific labels - OD_DATA
    - Check that heading order matches in language variants of data files - OD_DATA
    - Add testcase identifier TBS_QRS for TBS Quality Rating System checks.
    - Use csvlint program to check CSV files - TBS_QRS
    - Add testcase group profiles option
    - Abort JSON schema validation if there are too many errors. This avoids the appearance of hanging when 
       validating large JSON files that contain lots of validation errors - OD_VAL
```

A new Open Data testcase profile “PWGSC OD (core)” is available that eliminates duplicate data and inconsistent data checks from testing.  This should be used for datasets that have valid duplicate or inconsistent data cells as this reduces false error messages. 

Version 6.13.0 contains the following updates and additions

## Web

```
    - Don't use exclusive list for label types that require label, only list exceptions - WCAG_2.0-H44
    - Check for nested tables in thead, tfoot or th - WCAG_2.0-SC1.3.1
    - Check for data cells in tables - WCAG_2.0-H51
    - Check if multiple interface controls (input, button) have the same aria-labelledby reference - WCAG_2.0-ARIA16
    - Don't report error on focusable tags with tabindex = -1 if they nested in aria-hidden="true" - WCAG_2.0-SC4.1.2
    - Add option in configuration file to delay between fetches of pages from web sites to reduce the load on the web server.
    - Update list of valid rel attribute values for HTML5 - WCAG_2.0-H88
    - Update CSS validator to version cssval-20190320
    - Add testcase profile and checks for ACT rule set https://act-rules.github.io/rules/
    - Add runtime error messages to STDERR for supporting tools.
    - Update HTML5 validator to version 20.6.30 - HTML_VALIDATION
    - Check ChromeDriver version error with headless chrome.
    - Update Core Subject Thesaurus to December 11, 2020 version - DC Subject
    - Update the set of valid rel attribute values for tags.
    - Search for free port to use for markup server task.
    - Don't report error for allowed JavaScript in head (e.g. analytics) in mobile checks - JS_BOTTOM
    - Suppress reporting of invalid schema types and properties. The schema definition file is out of date - SWI_E_RDFA
    - Don't check supporting file version numbers for template consistency as there is no single version for 
       all supporting files - SWU_TEMPLATE
    - Add user agent version/installation details to output tabs.
    - Add supporting tools (e.g. pa11y) versions to accessibility tab.
    - Create new testcase group profiles for PSPC Internet, GC Intranet and Intranet.
    - Check for analytics markers in the HTML markup using patterns rather than just looking for links.
```

## Open Data

```
   - Add runtime error messages to STDERR for supporting tools.
    - Check that the language appropriate label is used for headings with multiple language specific labels - OD_DATA
    - Check that heading order matches in language variants of data files - OD_DATA
    - Do language variant checks only if one of the primary languages (English or French) are found.
    - Add testcase identifier TBS_QRS for TBS Quality Rating System checks.
    - Use csvlint program to check CSV files - TBS_QRS
    - Add testcase profile for TBS Quality Rating System checks
    - Add user agent version/installation details to output tabs.
    - Add supporting tools (e.g. pa11y) versions to accessibility tab.
    - Report missing JSON schema under testcase id TP_PW_OD_VAL.
    - Add testcase group profiles option.
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
- The HTML5 validator requires Oracle Java 8 or later and OpenJDK version 11.

The WPSS_Tool has been tested on the following platforms
- Windows 10 (64 bit), Strawberry Perl 5.26 (64 bit), Python 2.7.13

The WPSS Tool installer is available as a release in this repository
- https://github.com/wet-boew/wet-boew-wpss/releases/download/6.13.0/WPSS_Tool.exe

#### Chrome Headless User agent
  The Chrome headless user agent may be used rather than PhantomJS.  The following must be installed in order to use Chrome
- Node version 8 or newer - https://nodejs.org/en/download/
- Chrome version 69 or newer - https://www.google.com/chrome/
- ChromeDriver node module that matches the Chrome browser version
    * List locally installed chromedriver version ‘npm list chromedriver -g’
    * List all available chromedriver versions ‘npm view chromedriver versions’
    * Remove module ‘npm uninstall -g chromedriver’
    * Install a specific version ‘npm install -g chromedriver@89.0.0’
- Puppeteer core module for node (install from command prompt) "npm install –g puppeteer-core"

If Chrome is not available, the WPSS_Tool will fall back to using PhantomJS and a message will be written to the stdout.txt file.

#### Pa11y Accessibility Test Tool
The Pa11y accessibility test tool may be run against web pages.  The checks cannot be performed on pages behind a login (e.g. applications).  A new accessibility testcase profile is available to enable this checking.  Details on the Pa11y tool are available at https://github.com/pa11y/pa11y.
This tool requires
- Node version 8 or newer - https://nodejs.org/en/download/
- Pa11y module for node (install from command prompt) "npm install –g pa11y"

#### Deque AXE accessibility tool
The Deque AXE  accessibility test tool may be run against web pages.  The checks cannot be performed on pages behind a login (e.g. applications).  A new accessibility testcase profile is available to enable this checking.  Details on the Deque AXE tool are available at
- https://github.com/dequelabs/axe-core and https://github.com/dequelabs/axe-cli.

This tool requires
- Node version 8 or newer - https://nodejs.org/en/download/
- Deque AXE core module and command line interface (CLI) module. Installed via command prompt.
    * npm install @axe-core/cli -g
    * Install the required chromedriver module (see above).

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
- https://github.com/wet-boew/wet-boew-wpss/releases/download/6.13.0/WPSS_Tool_Linux.zip

Installation steps
- Unzip the package; 'unzip WPSS_Tool_Linux.zip'
- Go to the installation directory; 'cd WPSS_Tool_Linux'
- Run the install script; 'perl install.pl'


