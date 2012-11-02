# WPSS Validation Tool version 3.6.0

The WPSS Validation Tool provides web developers and quality assurance testers the ability to perform a number of web site and web page validation tasks at one time. The tool crawls a site to find all of the documents then analyses each document with a number of validation tools.

Version 3.6.0 contains the following updates and additions
  - Perform checks on links for interoperability. Check that the rel attribute is present for <link> tags and the value is valid. For links to documents on other domains, check the site title value, if it is different from the current site, check for a rel="external" attribute.
  - Check that documents with different mime-type and the same title are linked with rel="alternate.
  - Use the eAccessibility PDF checker program to test PDF documents for a number of accessibility issues, PDF1, PDF2, PDF6, PDF12. (http://accessibility.egovmon.no/en/pdfcheck/)

