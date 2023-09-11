## Web and Open Data Validator version 6.15.0

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



### Web Tool

```    
    - Add checks for WCAG plain text techniques and failures for plain text web pages and portions of 
      HTML web pages using the "pre" tag - WCAG_2.0-T1, WCAG_2.0-T2, WCAG_2.0-T3
    - Checks for whitespace formatted tables and graphic character formatted tables in plain text web 
      pages and portions of HTML web pages using the "pre" tag - WCAG_2.0-F34
    - Ignore SSL certificate errors in web feed validator - XML_VALIDATION
```


### Open Data_Tool

```
    - Fix bug in handling ordered list items found in unordered lists in multi-line text cells in 
      CSV files - OD_data
    - Check for space separated or graphics character formatted tables and plain text lists and headings
      in multi-line text fields in JSON files - OD_data
    - Report plain text accessibility errors in accessibility tab rather than the open data tab.
    - Ignore a single leading whitespace character in list items - OD_DATA
    - Check roman numeral ordered lists in plain text content
    - Set default limit of errors reported per URL to 1000 to avoid memory consumption problems.
```

Version 6.14.0 contains the following updates and additions

## Web

```
    - Add checks for WCAG plain text techniques and failures for plain text web pages and portions of 
      HTML web pages using the "pre" tag - WCAG_2.0-T1, WCAG_2.0-T2, WCAG_2.0-T3
    - Checks for whitespace formatted tables and graphic character formatted tables in plain text web 
      pages and portions of HTML web pages using the "pre" tag - WCAG_2.0-F34
    - Add checks for WCAG plain text techniques and failures for plain
      text web pages and portions of HTML web pages using the
      "pre" tag - WCAG_2.0-T1, WCAG_2.0-T2, WCAG_2.0-T3
    - Correct function name in Deque Axe install script
    - Ignore SSL certificate errors in web feed validator - XML_VALIDATION
```

## Open Data

```
    - Fix bug in handling ordered list items found in unordered lists in multi-line text cells in 
      CSV files - OD_data
    - Check for space separated or graphics character formatted tables and plain text lists and headings
      in multi-line text fields in JSON files - OD_data
    - Report plain text accessibility errors in accessibility tab rather than the open data tab.
    - Ignore a single leading whitespace character in list items - OD_DATA
    - Check roman numeral ordered lists in plain text content
    - Ignore case when checking for scientific notation in CSV cells
    - Set default limit of errors reported per URL to 1000 to avoid memory consumption problems.
```

## Web and Open Data Validator Installation on Windows

The tool installer, WPSS_Tool.exe, does NOT include the required Perl or Python installers.  
Perl and Python must be installed on the workstation prior to installing the WPSS_Tool.

Supported versions of Perl include
- Strawberry Perl 5.26 or later (32 or 64 bit) available from http://strawberryperl.com

Does NOT work with Strawberry Perl versions earlier than 5.26 and does not work with ActiveState Perl's community release.

Supported versions of Python include
- Python 2.7.6 or newer available from https://www.python.org/downloads/windows/
- Python 3 or newer (some supporting tools don't work with Python 3, e.g. Web feed validator).

Required version of Java
- The HTML5 validator requires Oracle Java 8 or later and OpenJDK version 11.

The WPSS_Tool has been tested on the following platforms
- Windows 11 (64 bit), Strawberry Perl 5.26 (64 bit), Python 2.7.13
- Windows 11 (64 bit), Strawberry Perl 5.32 (64 bit), Python 3.10.0

The WPSS Tool installer is available as a release in this repository
- https://github.com/wet-boew/wet-boew-wpss/releases/download/6.15/WPSS_Tool.exe

#### Chrome Headless User agent (recommended)
The Chrome headless user agent and supporting files can be installed using the install_puppeteer.pl script in the WPSS_Tool folder.

If headless Chrome is not available, the WPSS_Tool will fall back to using PhantomJS and a message will be written to the stdout.txt file.

#### Pa11y Accessibility Test Tool
The Pa11y accessibility test tool (https://pa11y.org/) is an optional tool that may be used  to run tests against web pages.  The tool can be installed using the install_pa11y.pl script in the WPSS_Tool folder.

#### Deque AXE accessibility tool
The Deque AXE accessibility tool (https://github.com/dequelabs/axe-cli) is an optional tool that may be used to run tests against web pages. The tool can be installed using the install_deque_axe.pl script in the WPSS_Tool folder.

## Web and Open Data Validator Installation on Linux

The tool distribution, WPSS_Tool_Linux.zip, does NOT include the required Perl or Python installers.  
Perl and Python must be installed on the prior to installing the WPSS_Tool.

Supported versions of Perl include
- Perl 5.0 or later (32 or 64 bit).

Supported versions of Python include
- Python 2.7.6 or newer.
- Python 3 (some components will not work, e.g. Web feed validator)

Required version of Java
- The HTML5 validator required Oracle Java 8 or later and OpenJDK version 11.

The WPSS_Tool has been tested on the following platforms
- Redhat, Perl 5.24.2 (32 bit), Python 3.5.0

The Linux version has not been tested with headless chrome, pa11y or Deque AXE.

The WPSS Tool installer is available as a release in this repository
- https://github.com/wet-boew/wet-boew-wpss/releases/download/6.15/WPSS_Tool_Linux.zip

Installation steps
- Unzip the package; 'unzip WPSS_Tool_Linux.zip'
- Go to the installation directory; 'cd WPSS_Tool_Linux'
- Run the install script; 'perl install.pl'

## Building WPSS_Tool

The WPSS_Tool and open_data_tool can be built from the repository as follows

- Clone the source from the repository
- Go to the Build folder
`cd wet-boew-wpss-master/Build`
- Run the build_release.pl script. The default is to build a Windows release, to build a Linux release add the "Linux" argument.
`perl build_release.pl`
`perl build_release.pl Linux`
- Releases are saved in the distribution folder; WPSS_Tool for Windows and WPSS_Tool_Linux for Linux.
`cd ../distribution`
