WPSS Validation Tool version 6.0.0
-----------------------------------

The WPSS Validation Tool provides web developers and quality assurance testers the ability to perform a number of web site and web page validation tasks at one time. The tool crawls a site to find all of the documents then analyses each document with a number of validation tools.

Major Changes
----------------------
This version of the tool makes use of a JavaScript aware headless user agent to retrieve HTML web documents.  The user agent executes JavaScript when the page loads and provides generated HTML mark-up to be used by the WPSS_Tool.

Version 6.0.0 contains the following updates and additions

WPSS_Tool
---------

    - Use PhantomJS to get web page markup after initial JavaScript is run on the page. Use generated 
      source for most checks. Mark up validation will be run on the original (not generated) source.
    - Use LWP::RobotUA::Cached module to implement a disk cache to store local copies of documents 
      retrieved.
    - Use a connection cache to maintain connections to web servers between document requests to 
      improve performance.
    - Accept aria-label, aria-labelledby or title attribute as well as alt attribute for text 
      alternatives for images - WCAG_2.0-F65
    - Generate a snapshot image of web pages when content saving is enabled.
    - Remove check for role="presentation" since generated mark-up from WET pages contains a 
      large number of these attributes, leading to false failures - WCAG_2.0-F92
    - Validate EPUB files with the epubcheck tool.
    - Ignore text in <style> tags, is not part of the page content - SWU.
    - When extracting links from web pages, if link is within a list, use list introduction text as 
      part of the anchor text.
    - Accept <title>/dc.title matches is the dc.title is a substring of the <title> - 
      TITLE_DC_TITLE_MISMATCH
    - Add SSL_verify_mode setting to crawler to ignore SSL certificate host name verification.
    - Skip consistent labelling checks for on page anchors - WCAG_2.0-G197
    - Allow for nested forms in HTML.
    - Include up to 3 lines of source context in HTML error messages.
    - Avoid duplicate WCAG_2.0-F30 error messages for the same image tag.
    - Check for xlink attribute in anchor tags - WCAG_2.0-G115
    - Include help URL for testcases in CSV results file.
    - Speed up PWGSC template file checking by checking only critical files.
    - Get link details from generated content in addition to the original content.
    - Handle the defer attribute on <script> tags - Mobile
    - Don't report errors for <script> tags that are part of the generated content - Mobile


Open Data Tool
--------------

    - Report URL access problems in the crawl tab if open data URLs cannot be accessed or are malformed.
    - Include help URL for testcases in CSV results file.


WPSS_Tool Installer
---------------------

The tool installer, WPSS_Tool.exe, does NOT include the required Perl or Python installers (as was the case for previous releases).  Perl and Python must be installed on the workstation prior to installing the WPSS_Tool.

Supported versions of Perl include
- Strawberry Perl 5.18 (32 bit) available from http://strawberry-perl.googlecode.com/files/strawberry-perl-5.18.1.1-32bit.msi

Supported versions of Python include
- Python 2.7.6 available from http://python.org/ftp/python/2.7.6/python-2.7.6.msi

The WPSS_Tool has been tested on the following platforms
- Windows 7 (32 bit), Strawberry Perl 5.18 (32 bit), Python 2.7.6

The WPSS Tool installer is available as a release in this repository
  - https://github.com/wet-boew/wet-boew-wpss/releases/download/6.0.0/WPSS_Tool.exe
