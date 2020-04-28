#***********************************************************************
#
# Name:   tqa_testcases.pm
#
# $Revision: 1791 $
# $URL: svn://10.36.148.185/WPSS_Tool/TQA_Check/Tools/tqa_testcases.pm $
# $Date: 2020-04-27 09:30:18 -0400 (Mon, 27 Apr 2020) $
#
# Description:
#
#   This file contains routines that handle TQA testcase descriptions.
#
# Public functions:
#     TQA_Testcase_Language
#     TQA_Testcase_Debug
#     TQA_Testcase_Description
#     TQA_Testcase_Groups
#     TQA_Testcase_Group_Count
#     TQA_Testcase_Impact
#     TQA_Testcase_Read_URL_Help_File
#     TQA_Testcase_Success_Criteria_Description
#     TQA_Testcase_URL
#
# Terms and Conditions of Use
# 
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is 
# distributed under the MIT License.
# 
# MIT License
# 
# Copyright (c) 2011 Government of Canada
# 
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense, 
# and/or sell copies of the Software, and to permit persons to whom the 
# Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR 
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR 
# OTHER DEALINGS IN THE SOFTWARE.
# 
#***********************************************************************

package tqa_testcases;

use strict;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(TQA_Testcase_Language
                  TQA_Testcase_Debug
                  TQA_Testcase_Description
                  TQA_Testcase_Groups
                  TQA_Testcase_Group_Count
                  TQA_Testcase_Impact
                  TQA_Testcase_Read_URL_Help_File
                  TQA_Testcase_Success_Criteria_Description
                  TQA_Testcase_URL
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;

#
# String tables for testcase ID to testcase descriptions
#
my (%testcase_description_en) = (
#
# WCAG 2.0
#
"WCAG_2.0-ARIA1", "2.4.2, 2.4.4, 3.3.2 ARIA1: Using the aria-describedby property to provide a descriptive label for user interface controls",
"WCAG_2.0-ARIA2", "3.3.2, 3.3.3 ARIA2: Identifying a required field with the aria-required property",
"WCAG_2.0-ARIA6", "1.1.1 ARIA6: Using aria-label to provide labels for objects",
"WCAG_2.0-ARIA7", "2.4.4 ARIA7: Using aria-labelledby for link purpose",
"WCAG_2.0-ARIA8", "2.4.4 ARIA8: Using aria-label for link purpose",
"WCAG_2.0-ARIA9", "1.1.1, 3.3.2 ARIA9: Using aria-labelledby to concatenate a label from several text nodes",
"WCAG_2.0-ARIA10", "1.1.1 ARIA10: Using aria-labelledby to provide a text alternative for non-text content",
"WCAG_2.0-ARIA12", "1.3.1 ARIA12: Using role=heading to identify headings",
"WCAG_2.0-ARIA13", "1.3.1 ARIA13: Using aria-labelledby to name regions and landmarks",
"WCAG_2.0-ARIA15", "1.1.1 ARIA15: Using aria-describedby to provide descriptions of images",
"WCAG_2.0-ARIA16", "1.3.1, 4.1.2 ARIA16: Using aria-labelledby to provide a name for user interface controls",
"WCAG_2.0-ARIA17", "1.3.1, 3.3.2 ARIA17: Using grouping roles to identify related form controls",
"WCAG_2.0-ARIA18", "3.3.1, 3.3.3 ARIA18: Using aria-alertdialog to Identify Errors",
# C12: Using percent for font sizes 
#      Failures of this technique are reported under technique G142
# C13: Using named font sizes
#      Failures of this technique are reported under technique G142
# C14: Using em units for font sizes
#      Failures of this technique are reported under technique G142
#
"WCAG_2.0-C28", "1.4.4 C28: Specifying the size of text containers using em units",
"WCAG_2.0-F2", "1.3.1 F2: Failure of Success Criterion 1.3.1 due to using changes in text presentation to convey information without using the appropriate markup or text",
"WCAG_2.0-F3", "1.1.1 F3: Failure of Success Criterion 1.1.1 due to using CSS to include images that convey important information",
"WCAG_2.0-F4", "2.2.2 F4: Failure of Success Criterion 2.2.2 due to using text-decoration:blink without a mechanism to stop it in less than five seconds",
"WCAG_2.0-F8", "1.2.2 F8: Failure of Success Criterion 1.2.2 due to captions omitting some dialogue or important sound effects",
"WCAG_2.0-F16", "2.2.2 F16: Failure of Success Criterion 2.2.2 due to including scrolling content where movement is not essential to the activity without also including a mechanism to pause and restart the content",
"WCAG_2.0-F17", "1.3.1, 4.1.1 F17: Failure of Success Criterion 1.3.1 and 4.1.1 due to insufficient information in DOM to determine one-to-one relationships (e.g. between labels with same id) in HTML",
"WCAG_2.0-F25", "2.4.2 F25: Failure of Success Criterion 2.4.2 due to the title of a Web page not identifying the contents",
"WCAG_2.0-F30", "1.1.1, 1.2.1 F30: Failure of Success Criterion 1.1.1 and 1.2.1 due to using text alternatives that are not alternatives",
"WCAG_2.0-F32", "1.3.2 F32: Failure of Success Criterion 1.3.2 due to using white space characters to control spacing within a word",
"WCAG_2.0-F38", "1.1.1 F38: Failure of Success Criterion 1.1.1 due to omitting the alt-attribute for non-text content used for decorative purposes only in HTML",
"WCAG_2.0-F39", "1.1.1 F39: Failure of Success Criterion 1.1.1 due to providing a text alternative that is not null (e.g., alt='spacer' or alt='image') for images that should be ignored by assistive technology",
"WCAG_2.0-F40", "2.2.1 F40: Failure of Success Criterion 2.2.1 and 2.2.4 due to using meta redirect with a time limit",
"WCAG_2.0-F41", "2.2.1 F41: Failure of Success Criterion 2.2.1, 2.2.4 and 3.2.5 due to using meta refresh with a time limit",
"WCAG_2.0-F42", "1.3.1, 2.1.1 F42: Failure of Success Criterion 1.3.1 and 2.1.1 due to using scripting events to emulate links in a way that is not programmatically determinable",
"WCAG_2.0-F43", "1.3.1 F43: Failure of Success Criterion 1.3.1 due to using structural markup in a way that does not represent relationships in the content",
"WCAG_2.0-F44", "2.4.3 F44: Failure of Success Criterion 2.4.3 due to using tabindex to create a tab order that does not preserve meaning and operability",
"WCAG_2.0-F46", "1.3.1 F46: Failure of Success Criterion 1.3.1 due to using th elements, caption elements, or non-empty summary attributes in layout tables",
"WCAG_2.0-F47", "2.2.2 F47: Failure of Success Criterion 2.2.2 due to using the blink element",
"WCAG_2.0-F54", "2.1.1 F54: Failure of Success Criterion 2.1.1 due to using only pointing-device-specific event handlers (including gesture) for a function",
"WCAG_2.0-F55", "2.1.1, 2.4.7, 3.2.1 F55: Failure of Success Criteria 2.1.1, 2.4.7, and 3.2.1 due to using script to remove focus when focus is received",
"WCAG_2.0-F58", "2.2.1 F58: Failure of Success Criterion 2.2.1 due to using server-side techniques to automatically redirect pages after a time-out",
"WCAG_2.0-F62", "1.3.1, 4.1.1 F62: Failure of Success Criterion 1.3.1 and 4.1.1 due to insufficient information in DOM to determine specific relationships in XML",
"WCAG_2.0-F65", "1.1.1 F65: Failure of Success Criterion 1.1.1 due to omitting the alt attribute or text alternative on img elements, area elements, and input elements of type \"image\"",
"WCAG_2.0-F66", "3.2.3 F66: Failure of Success Criterion 3.2.3 due to presenting navigation links in a different relative order on different pages",
"WCAG_2.0-F68", "1.3.1, 4.1.2 F68: Failure of Success Criterion 1.3.1 and 4.1.2 due to the association of label and user interface controls not being programmatically determinable",
"WCAG_2.0-F70", "4.1.1 F70: Failure of Success Criterion 4.1.1 due to incorrect use of start and end tags or attribute markup",
"WCAG_2.0-F77", "4.1.1 F77: Failure of Success Criterion 4.1.1 due to duplicate values of type ID",
#
# F80: Failure of Success Criterion 1.4.4 when text-based form controls 
#      do not resize when visually rendered text is resized up to 200%
#      Failures of this technique are reported under technique C28
#
# F86: Failure of Success Criterion 4.1.2 due to not providing names for 
#      each part of a multi-part form field, such as a US telephone number
#      Failures of this technique are reported under technique H44
#
"WCAG_2.0-F87", "1.3.1 F87: Failure of Success Criterion 1.3.1 due to inserting non-decorative content by using :before and :after pseudo-elements and the 'content' property in CSS",
"WCAG_2.0-F89", "2.4.4, 4.1.2 F89: Failure of Success Criteria 2.4.4, 2.4.9 and 4.1.2 due to using null alt on an image where the image is the only content in a link",
"WCAG_2.0-F92", "1.3.1 F92: Failure of Success Criterion 1.3.1 due to the use of role presentation on content which conveys semantic information",
#
# G4: Allowing the content to be paused and restarted from where it was paused
#     Failures of this technique are reported under techniques F16
#
# G11: Creating content that blinks for less than 5 seconds
#      Failures of this technique are reported under techniques F4
#      for blink decoration and F47 for <blink> tag.
#
"WCAG_2.0-G18", "1.4.3 G18: Ensuring that a contrast ratio of at least 4.5:1 exists between text (and images of text) and background behind the text",
"WCAG_2.0-G19", "2.3.1 G19: Ensuring that no component of the content flashes more than three times in any 1-second period",
#
# G80: Providing a submit button to initiate a change of context
#      Failures of this technique are reported under technique H32
#
"WCAG_2.0-G87", "1.2.2 G87: Providing closed captions",
#
# G88: Providing descriptive titles for Web pages
#      Failures of this technique are reported under technique H25, PDF18
#
# G90: Providing keyboard-triggered event handlers
#      Failures of this technique are reported under technique SCR20
#
#"WCAG_2.0-G94", "1.1.1 G94: Providing short text alternative for non-text content that serves the same purpose and presents the same information as the non-text content",
"WCAG_2.0-G115", "1.3.1 G115: Using semantic elements to mark up structure",
"WCAG_2.0-G125", "2.4.5 G125: Providing links to navigate to related Web pages",
"WCAG_2.0-G130", "2.4.6 G130: Providing descriptive headings",
"WCAG_2.0-G131", "2.4.6, 3.3.2 G131: Providing descriptive labels",
"WCAG_2.0-G134", "4.1.1 G134: Validating Web pages",
#
# Advisory technique
#
#"WCAG_2.0-G141", "1.3.1 G141: Organizing a page using headings",
#
"WCAG_2.0-G142", "1.4.4 G142: Using a technology that has commonly-available user agents that support zoom",
"WCAG_2.0-G145", "1.4.3 G145: Ensuring that a contrast ratio of at least 3:1 exists between text (and images of text) and background behind the text",
"WCAG_2.0-G152", "2.2.2 G152: Setting animated gif images to stop blinking after n cycles (within 5 seconds)",
"WCAG_2.0-G158", "1.2.1 G158: Providing an alternative for time-based media for audio-only content",
#
# G162: Positioning labels to maximize predictability of relationships
#       Failures of this technique are reported under technique H44
#
# G192: Fully conforming to specifications
#      Failures of this technique are reported under technique G143
#
"WCAG_2.0-G197", "3.2.4 G197: Using labels, names, and text alternatives consistently for content that has the same functionality",
"WCAG_2.0-H2", "1.1.1 H2: Combining adjacent image and text links for the same resource",
"WCAG_2.0-H24", "1.1.1, 2.4.4 H24: Providing text alternatives for the area elements of image maps",
"WCAG_2.0-H25", "2.4.2 H25: Providing a title using the title element",
"WCAG_2.0-H27", "1.1.1 H27: Providing text and non-text alternatives for object",
"WCAG_2.0-H30", "1.1.1, 2.4.4 H30: Providing link text that describes the purpose of a link for anchor elements",
"WCAG_2.0-H32", "3.2.2 H32: Providing submit buttons",
"WCAG_2.0-H33", "2.4.4 H33: Supplementing link text with the title attribute",
"WCAG_2.0-H35", "1.1.1 H35: Providing text alternatives on applet elements",
"WCAG_2.0-H36", "1.1.1 H36: Using alt attributes on images used as submit buttons",
#"WCAG_2.0-H37", "1.1.1 H37: Using alt attributes on img elements",
"WCAG_2.0-H39", "1.3.1 H39: Using caption elements to associate data table captions with data tables",
"WCAG_2.0-H42", "1.3.1 H42: Using h1-h6 to identify headings",
"WCAG_2.0-H43", "1.3.1 H43: Using id and headers attributes to associate data cells with header cells in data tables",
"WCAG_2.0-H44", "1.1.1, 1.3.1, 3.3.2, 4.1.2 H44: Using label elements to associate text labels with form controls",
"WCAG_2.0-H45", "1.1.1 H45: Using longdesc",
"WCAG_2.0-H46", "1.1.1 H46: Using noembed with embed",
"WCAG_2.0-H48", "1.3.1 H48: Using ol, ul and dl for lists or groups of links",
"WCAG_2.0-H51", "1.3.1 H51: Using table markup to present tabular information",
"WCAG_2.0-H53", "1.1.1, 1.2.3 H53: Using the body of the object element",
"WCAG_2.0-H57", "3.1.1 H57: Using language attributes on the html element",
"WCAG_2.0-H58", "3.1.2 H58: Using language attributes to identify changes in the human language",
"WCAG_2.0-H64", "2.4.1, 4.1.2 H64: Using the title attribute of the frame and iframe elements",
"WCAG_2.0-H65", "1.3.1, 3.3.2, 4.1.2 H65: Using the title attribute to identify form controls when the label element cannot be used",
"WCAG_2.0-H67", "1.1.1 H67: Using null alt text and no title attribute on img elements for images that AT should ignore",
"WCAG_2.0-H71", "1.3.1, 3.3.2 H71: Providing a description for groups of form controls using fieldset and legend elements",
"WCAG_2.0-H73", "1.3.1 H73: Using the summary attribute of the table element to give an overview of data tables",
"WCAG_2.0-H74", "4.1.1 H74: Ensuring that opening and closing tags are used according to specification",
#
# H75: Ensuring that Web pages are well-formed
#      Failures of this technique are reported under technique G143
#
"WCAG_2.0-H88", "4.1.1, 4.1.2 H88: Using HTML according to spec",
"WCAG_2.0-H91", "2.1.1, 4.1.2 H91: Using HTML form controls and links",
#
# H93: Ensuring that id attributes are unique on a Web page
#      Failures of this technique are reported under technique F77
#
"WCAG_2.0-H94", "4.1.1 H94: Ensuring that elements do not contain duplicate attributes",
"WCAG_2.0-PDF1", "1.1.1 PDF1: Applying text alternatives to images with the Alt entry in PDF documents",
"WCAG_2.0-PDF2", "2.4.5 PDF2: Creating bookmarks in PDF documents",
"WCAG_2.0-PDF6", "1.3.1 PDF6: Using table elements for table markup in PDF Documents",
"WCAG_2.0-PDF12", "1.3.1, 4.1.2 PDF12: Providing name, role, value information for form fields in PDF documents",
"WCAG_2.0-PDF16", "3.1.1 PDF16: Setting the default language using the /Lang entry in the document catalog of a PDF document",
"WCAG_2.0-PDF18", "2.4.2 PDF18: Specifying the document title using the Title entry in the document information dictionary of a PDF document",
"WCAG_2.0-SC1.3.1", "1.3.1 SC1.3.1: Info and Relationships",
"WCAG_2.0-SC1.4.4", "1.4.4 SC1.4.4: Resize text",
"WCAG_2.0-SC2.4.3", "2.4.3 SC2.4.3: Focus Order",
"WCAG_2.0-SC3.1.1", "3.1.1 SC3.1.1: Language of Page",
"WCAG_2.0-SC4.1.2", "4.1.2 SC4.1.2: Name, Role, Value",
#
# SCR2: Using redundant keyboard and mouse event handlers
#       Failures of this technique are reported under technique SCR20
#
"WCAG_2.0-SCR20", "2.1.1 SCR20: Using both keyboard and other device-specific functions",
"WCAG_2.0-SCR21", "1.3.1 SCR21: Using functions of the Document Object Model (DOM) to add content to a page",
"WCAG_2.0-Guideline41", "4.1 Guideline41: Compatible",

#
# EPUB Accessibility Techniques 1.0 from http://www.idpf.org/epub/a11y/techniques/techniques.html
#
"EPUB-ACCESS-001", "1.3.2 ACCESS-001: Ensure linear reading order of the publication",
"EPUB-ACCESS-002", "2.4.5 ACCESS-002: Provide multiple ways to access the content",
"EPUB-DIST-001", "4.1.1 DIST-001: Do not restrict access through digital rights management",
"EPUB-META-001", "4.1.1 META-001: Identify primary access modes",
"EPUB-META-002", "4.1.1 META-002: Identify sufficient access modes",
"EPUB-META-003", "4.1.1 META-003: Identify accessibility features",
"EPUB-META-004", "4.1.1 META-004: Identify accessibility hazards",
"EPUB-META-005", "4.1.1 META-005: Include an accessibility summary",
"EPUB-META-006", "4.1.1 META-006: Identify ARIA Conformance",
"EPUB-META-007", "4.1.1 META-007: Identify Input Control Methods",
"EPUB-PAGE-001", "4.1.1 PAGE-001: Provide page break markers",
"EPUB-PAGE-003", "2.4.5 PAGE-001: Provide a page list",
"EPUB-SEM-001",  "1.3.1 SEM-001: Include ARIA and EPUB semantics",
"EPUB-SEM-003",  "2.4.5 SEM-003: Include EPUB landmarks",
"EPUB-TITLES-002", "1.3.1 TITLES-002: Ensure numbered headings reflect publication hierarchy",

#
# AXE Deque University testcases
#  https://dequeuniversity.com/rules/axe/3.3
#
"AXE-Audio_Caption", "1.2.1 AXE-Audio_Caption: <audio> elements must have a captions <track>",
"AXE-Blink", "2.2.2 AXE-Blink: <blink> elements are deprecated and must not be used",
"AXE-Definition_List", "1.3.1 <dl> elements must only directly contain properly-ordered <dt> and <dd> groups, <script>, or <template> elements",
"AXE-Dlitem", "1.3.1 AXE-Dlitem: <dt> and <dd> elements must be contained by a <dl>",
"AXE-Html_has_lang", "3.1.1 AXE-Html_has_lang: <html> element must have a lang attribute",
"AXE-Html_lang_valid", "3.1.1 AXE-Html_lang_valid: <html> element must have a valid value for the lang attribute",
"AXE-Html_xml_lang_mismatch", "3.1.1 AXE-Html_xml_lang_mismatch: <html> elements with lang and xml:lang must have the same base language",
"AXE-Listitem", "1.3.1 AXE-Listitem:<li> elements must be contained in a <ul> or <ol>",
"AXE-Marquee", "2.2.2 AXE-Marquee: <marquee> elements are deprecated and must not be used",
"AXE-Object_alt", "1.1.1 AXE-Object_alt: <object> elements must have alternate text",
"AXE-List", "1.3.1 AXE-List: <ul> and <ol> must only directly contain <li>, <script> or <template> elements",
"AXE-Video_Caption", "1.2.2, 1.2.3 AXE-Video_caption: <video> elements must have a <track> for captions",
"AXE-Video_Description", "1.2.5 AXE-Video_description: <video> elements must have an audio description <track>",
"AXE-Accesskeys", "4.1.1 AXE-Accesskeys: accesskey attribute value must be unique",
"AXE-Area_alt", "1.1.1 AXE-Area_alt: Active <area> elements must have alternate text",

"AXE-Td_headers_attr", "1.3.1 AXE-Td_headers_attr: All cells in a <table> element that use the headers attribute must only refer to other cells of that same <table>",

"AXE-Href_no_hash", "1.1.1, 2.4.4 AXE-Href_no_hash: Anchors must only be used as links with valid URLs or URL fragments",

"AXE-Aria_valid_attr", "4.1.2 AXE-Aria_valid_attr: ARIA attributes must conform to valid names",
"AXE-Aria_valid_attr_value", "4.1.2 AXE-Aria_valid_attr_value: ARIA attributes must conform to valid values",
"AXE-Aria_allowed_role", "4.1.2 AXE-Aria_allowed_role: ARIA role must be appropriate for the element",
"AXE-Aria_roles", "4.1.2 AXE-Aria_roles: ARIA roles used must conform to valid values",
"AXE-Aria_hidden_focus", "4.1.2 AXE-Aria_hidden_focus: aria-hidden elements do not contain focusable elements",
"AXE-Aria_hidden_body", "4.1.2 AXE-Aria_hidden_body: aria-hidden=\"true\" must not be present on the document <body>",

"AXE-Landmark_banner_is_top_level", "4.1.2 AXE-Landmark_banner_is_top_level: Banner landmark must not be contained in another landmark",
"AXE-P_as_heading", "1.3.1 AXE-P_as_heading: Bold, italic text and font-size are not used to style <p> elements as a heading",
"AXE-Button_name", "4.1.2 AXE-Button_name: Buttons must have discernible text",

"AXE-Aria_required_parent", "1.3.1 AXE-Aria_required_parent: Certain ARIA roles must be contained by particular parent elements",
"AXE-Aria_required_children", "1.3.1 AXE-Aria_required_children: Certain ARIA roles must contain particular children",
"AXE-Checkboxgroup", "1.3.1, 3.3.2 AXE-Checkboxgroup: Checkbox inputs with the same name attribute value must be part of a group",
"AXE-Landmark_complementary_is_top_level", "AXE-Landmark_complementary_is_top_level: Complementary landmarks and/or asides are top level",
"AXE-Landmark_contentinfo_is_top_level", "4.1.2 AXE-Landmark_contentinfo_is_top_level: Contentinfo landmark must not be contained in another landmark",

"AXE-Document_title", "2.4.2 AXE-Document_title: Documents must contain a title element to aid in navigation",
"AXE-Role_img_alt", "1.1.1 AXE-Role_img_alt: Elements containing role=\"img\" have an alternative text",

"AXE-Aria_allowed_attr", "4.1.2 AXE-Aria_allowed_attr: Elements must only use allowed ARIA attributes",
"AXE-Tabindex", "2.4.3 AXE-Tabindex: Elements should not have tabindex greater than zero",
"AXE-Label", "1.3.1 AXE-Label: Form <input> elements must have labels",
"AXE-Label_title_only", "3.3.2 AXE-Label_title_only: Form <input> elements should have a visible label",

"AXE-Form_field_multiple_labels", "1.3.1, 3.3.2 AXE-Form_field_multiple_labels: Form fields do not have duplicate labels",

"AXE-Frame_title_unique", "2.4.1, 4.1.2 AXE-Frame_title_unique: Frames must have a unique title attribute",
"AXE-Frame_title", "2.4.1, 4.1.2 AXE-Frame_title: Frames must have title attribute",
"AXE-Heading_order", "1.3.1 AXE-Heading_order: Heading levels should only increase by one",
"AXE-Empty_heading", "2.4.6 AXE-Empty_heading: Headings must not be empty",

"AXE-Duplicate_id", "4.1.1 AXE-Duplicate_id: ID attribute values must be unique",
"AXE-Input_image_alt", "1.1.1 AXE-Input_image_alt: Image buttons must have alternate text",
"AXE-Image_alt", "1.1.1 AXE-Image_alt: Images must have alternate text",

"AXE-Input_button_name", "4.1.2 AXE-Input_button_name: Input buttons must have discernible text",
"AXE-Label_content_name_mismatch", "2.5.3 AXE-Label_content_name_mismatch: Label and name from content mismatch",

"AXE-Valid_lang", "3.1.2 AXE-Valid_lang: lang attribute must have a valid value",
"AXE-Layout_table", "1.3.1 AXE-Layout_table: Layout tables must not use data table elements",

"AXE-Landmark_main_is_top_level", "1.3.1 AXE-Landmark_main_is_top_level: Main landmark must not be contained in another landmark",
"AXE-Page_has_heading_one", "1.3.1 AXE-Page_has_heading_one: Page must contain a level-one heading",

"AXE-Landmark_one_main", "1.3.1 AXE-Landmark_one_main: Page must have one main landmark",
"AXE-Landmark_no_duplicate_banner", "1.3.1 AXE-Landmark_no_duplicate_banner Page must not have more than one banner landmark",
"AXE-Landmark_no_duplicate_contentinfo", "1.3.1 AXE-Landmark_no_duplicate_contentinfo: Page must not have more than one contentinfo landmark",
"AXE-Radiogroup", "1.3.1, 3.3.2 AXE-Radiogroup: Radio inputs with the same name attribute value must be part of a group",
"AXE-Aria_required_attr", "4.1.2 AXE-Aria_required_attr: Required ARIA attributes must be provided",

"AXE-Table_duplicate_name", "1.3.1 AXE-Table_duplicate_name: The <caption> element should not contain the same text as the summary attribute",
"AXE-Meta_refresh", "2.2.1, 2.2.4, 3.2.5 AXE-Meta_refresh: Timed refresh must not exist",

"AXE-Image_redundant_alt", "1.1.1 AXE-Image_redundant_alt: Text of buttons and links should not be repeated in the image alternative",

"AXE-Aria_roledescription", "4.1.2 AXE-Aria_roledescription: Use aria-roledescription on elements with a semantic role",
"AXE-Meta_viewport_large", "1.4.4 AXE-Meta_viewport_large: Users should be able to zoom and scale the text up to 500%",
"AXE-Meta_viewport", "1.4.4 AXE-Meta_viewport: Zooming and scaling must not be disabled",

#
# Pa11y testcases
#  Pa11y is your automated accessibility testing pal
#  https://github.com/pa11y/pa11y
#
"Pa11y", "Pa11y: Automated accessibility testing pal",
);

my (%testcase_description_fr) = (
#
# WCAG 2.0
#  Text taken from http://www.braillenet.org/accessibilite/comprendre-wcag20/CAT20110222/Overview.html
#   https://www.w3.org/Translations/WCAG20-fr/
#   https://www.w3.org/Translations/NOTE-UNDERSTANDING-WCAG20-fr/media-equiv-av-only-alt.html
#
"WCAG_2.0-ARIA1", "2.4.2, 2.4.4, 3.3.2 ARIA1: Utilisation de la propriété aria-describedby pour nommer les contrôles de l'interface utilisateur au moyen d'une étiquette descriptive",
"WCAG_2.0-ARIA2", "3.3.2, 3.3.3 ARIA2: Identifie un champ obligatoire avec la propriété aria-required",
"WCAG_2.0-ARIA6", "1.1.1 ARIA6: Utilisation de aria-label pour fournir les étiquettes des objets",
"WCAG_2.0-ARIA7", "2.4.4 ARIA7: Utilisation de aria-labelledby pour la fonction de lien",
"WCAG_2.0-ARIA8", "2.4.4 ARIA8: Utilisation de aria-label pour la fonction de lien",
"WCAG_2.0-ARIA9", "1.1.1, 3.3.2 ARIA9: Utilisation de aria-labelledby pour concaténer une étiquette à partir de plusieurs nœuds textuels",
"WCAG_2.0-ARIA10", "1.1.1 ARIA10: Utilisation de aria-labelledby pour fournir le texte de remplacement d'un contenu non textuel",
"WCAG_2.0-ARIA12", "1.3.1 ARIA12: Utilisation de role=heading pour identifier les en-têtes",
"WCAG_2.0-ARIA13", "1.3.1 ARIA13: Utilisation de aria-labelledby pour nommer les régions et les repères",
"WCAG_2.0-ARIA15", "1.1.1 ARIA15: Utilisation de aria-describedby pour fournir une description des images",
"WCAG_2.0-ARIA16", "1.3.1, 4.1.2 ARIA16: Utilisation de aria-labelledby pour nommer les contrôles de l'interface utilisateur",
"WCAG_2.0-ARIA17", "1.3.1, 3.3.2 ARIA17: Utilisation de rôles de regroupement pour identifier les contrôles de formulaire connexes",
"WCAG_2.0-ARIA18", "3.3.1, 3.3.3 ARIA18: Utilisation de aria-alertdialog pour identifier des erreurs",
# C12: Using percent for font sizes 
#      Failures of this technique are reported under technique G142
# C13: Using named font sizes
#      Failures of this technique are reported under technique G142
# C14: Using em units for font sizes
#      Failures of this technique are reported under technique G142
#
"WCAG_2.0-C28", "1.4.4 C28: Spécifier la taille des conteneurs de texte en utilisant des unités em",
"WCAG_2.0-F2", "1.3.1 F2 : Échec du critère de succès 1.3.1 consistant à utiliser les changements dans la présentation du texte pour véhiculer de l'information sans utiliser le balisage ou le texte approprié",
"WCAG_2.0-F3", "1.1.1 F3: Échec du critère de succès 1.1.1 consistant à utiliser les CSS pour inclure une image qui véhicule une information importante",
"WCAG_2.0-F4", "2.2.2 F4: Échec du critère de succès 2.2.2 consistant à utiliser text-decoration:blink sans mécanisme pour l'arrêter en moins de 5 secondes",
"WCAG_2.0-F8", "1.2.2 F8: Échec du critère de succès 1.2.2 consistant à omettre certains dialogues ou effets sonores importants dans les sous-titres",
"WCAG_2.0-F16", "2.2.2 F16: Échec du critère de succès 2.2.2 consistant à inclure un contenu défilant lorsque le mouvement n'est pas essentiel à l'activité sans inclure aussi un mécanisme pour mettre ce contenu en pause et pour le redémarrer",
"WCAG_2.0-F17", "1.3.1, 4.1.1 F17: Échec du critère de succès 1.3.1 et 4.1.1 lié à l'insuffisance d'information dans le DOM pour déterminer des relations univoques en HTML (par exemple entre les étiquettes ayant un même id)",
"WCAG_2.0-F25", "2.4.2 F25: Échec du critère de succès 2.4.2 survenant quand le titre de la page Web n'identifie pas son contenu",
"WCAG_2.0-F30", "1.1.1, 1.2.1 F30: Échec du critère de succès 1.1.1 et 1.2.1 consistant à utiliser un équivalent textuel qui n'est pas équivalent (par exemple nom de fichier ou texte par défaut)",
"WCAG_2.0-F32", "1.3.2 F32: Échec du critère de succès 1.3.2 consistant à utiliser des caractères blancs pour contrôler l'espacement à l'intérieur d'un mot",
"WCAG_2.0-F38", "1.1.1 F38: Échec du critère de succès 1.1.1 consistant à omettre l'attribut alt pour un contenu non textuel utilisé de façon décorative, seulement en HTML",
"WCAG_2.0-F39", "1.1.1 F39: Échec du critère de succès 1.1.1 consistant à fournir un équivalent textuel non vide (par exemple alt='espaceur' ou alt='image') pour des images qui doivent être ignorées par les technologies d'assistance",
"WCAG_2.0-F40", "2.2.1 F40: Échec du critère de succès 2.2.1 et 2.2.4 consistant à utiliser une redirection meta avec un délai",
"WCAG_2.0-F41", "2.2.1 F41: Échec du critère de succès 2.2.1, 2.2.4 et 3.2.5 consistant à utiliser meta refresh avec un délai",
"WCAG_2.0-F42", "1.3.1, 2.1.1 F42: Échec du critère de succès 1.3.1 et 2.1.1 consistant à utiliser des événements de scripts pour émuler des liens d'une manière qui n'est pas déterminable par un programme informatique",
"WCAG_2.0-F43", "1.3.1 F43: Échec du critère de succès 1.3.1 consistant à utiliser un balisage structurel d'une façon qui ne représente pas les relations à l'intérieur du contenu",
"WCAG_2.0-F44", "2.4.3 F44: Échec du critère de succès 2.4.3 consistant à utiliser l'attribut tabindex pour créer un ordre de tabulation qui ne préserve pas la signification et l'opérabilité",
"WCAG_2.0-F46", "1.3.1 F46: F46 : Échec du critère de succès 1.3.1 consistant à utiliser les éléments th ou caption ou des attributs summary non vides dans des tableaux de présentation",
"WCAG_2.0-F47", "2.2.2 F47: Échec du critère de succès 2.2.2 consistant à utiliser l'élément 'blink'",
"WCAG_2.0-F54", "2.1.1 F54: Échec du critère de succès 2.1.1 consistant à utiliser seulement des événements au pointeur (y compris par geste) pour une fonction",
"WCAG_2.0-F55", "2.1.1, 2.4.7, 3.2.1 F55: Échec du critère de succès 2.1.1, 2.4.7 et 3.2.1 consistant à utiliser un script pour enlever le focus lorsque le focus est reçu",
"WCAG_2.0-F58", "2.2.1 F58: Échec du critère de succès 2.2.2 consistant à utiliser une technique côté serveur pour automatiquement rediriger la page après un arrêt",
"WCAG_2.0-F62", "1.3.1, 4.1.1 F62: Échec du critère de succès 1.3.1 et 4.1.1 lié à l'insuffisance d'information dans le DOM pour déterminer des relations spécifiques en XML",
"WCAG_2.0-F65", "1.1.1 F65: Échec du critère de succès 1.1.1 consistant à omettre l'attribut 'alt' ou texte de remplacement sur des éléments de 'img', des éléments de 'area', et des éléments de 'input' de type 'image'",
"WCAG_2.0-F66", "3.2.3 F66: Échec du critère de succès 3.2.3 consistant à présenter les liens de navigation dans un ordre relatif différent sur différentes pages",
"WCAG_2.0-F68", "1.3.1, 4.1.2 F68: Échec du critère de succès 1.3.1 et 4.1.2 lié au fait que l'association entre l'étiquette et le composant d'interface utilisateur n'est pas déterminable par programmation",
"WCAG_2.0-F70", "4.1.1 F70: Échec du critère de succès 4.1.1 lié à l'ouverture et à la fermeture incorrecte des balises et des attributs",
"WCAG_2.0-F77", "4.1.1 F77: Échec du critère de succès 4.1.1 lié à la duplication des valeurs de type ID",
#
# F80: Failure of Success Criterion 1.4.4 when text-based form controls
#      do not resize when visually rendered text is resized up to 200%
#      Failures of this technique are reported under technique C28
#
# F86: Failure of Success Criterion 4.1.2 due to not providing names for 
#      each part of a multi-part form field, such as a US telephone number
#      Failures of this technique are reported under technique H44
#
"WCAG_2.0-F87", "1.3.1 F87: Échec du critère de succès 1.3.1 consistant à utiliser les pseudo-éléments :before et :after et la propriété content en CSS",
"WCAG_2.0-F89", "2.4.4, 4.1.2 F89: Échec du critère de succès 2.4.4, 2.4.9 et 4.1.2 consistant à utiliser un attribut alt vide pour une image qui est le seul contenu d'un lien",
"WCAG_2.0-F92", "1.3.1 F92: Failure of Success Criterion 1.3.1 due to the use of role presentation on content which conveys semantic information",
#
# G4: Allowing the content to be paused and restarted from where it was paused
#     Failures of this technique are reported under techniques F16
#
# G11: Creating content that blinks for less than 5 seconds
#      Failures of this technique are reported under techniques F4
#      for blink decoration and F47 for <blink> tag.
#
"WCAG_2.0-G18", "1.4.3 G18: S'assurer qu'un rapport de contraste d'au moins 4,5 pour 1 existe entre le texte (et le texte sous forme d'image) et l'arrière-plan du texte",
"WCAG_2.0-G19", "2.3.1 G19: S'assurer qu'aucun composant du contenu ne flashe plus de 3 fois dans une même période d'une seconde",
#
# G80: Providing a submit button to initiate a change of context
#      Failures of this technique are reported under technique H32
#
"WCAG_2.0-G87", "1.2.2 G87 : Fournir des sous-titres fermés (à la demande)",
#
# G88: Providing descriptive titles for Web pages
#      Failures of this technique are reported under technique H25, PDF18
#
# G90: Providing keyboard-triggered event handlers
#      Failures of this technique are reported under technique SCR20
#
#"WCAG_2.0-G94", "1.1.1 G94: Fournir un court équivalent textuel pour un contenu non textuel qui a la même fonction et présente la même information que le contenu non textuel",
"WCAG_2.0-G115", "1.3.1 G115: Utiliser les éléments sémantiques pour baliser la structure",
"WCAG_2.0-G125", "2.4.5 G125: Fournir des liens de navigation vers les pages Web reliées",
"WCAG_2.0-G130", "2.4.6 G130: Fournir des en-têtes de section descriptifs",
"WCAG_2.0-G131", "2.4.6, 3.3.2 G131: Fournir des étiquettes descriptives",
"WCAG_2.0-G134", "4.1.1 G134: Valider les pages Web",
#
# Advisory technique
#
#"WCAG_2.0-G141", "1.3.1 G141: Organiser une page en utilisant les en-têtes de section",
#
"WCAG_2.0-G142", "1.4.4 G142: Grâce à une technologie qui a des agents utilisateurs couramment disponibles à l'appui de zoom",
"WCAG_2.0-G145", "1.4.3 G145: S'assurer qu'un rapport de contraste d'au moins 3 pour 1 existe entre le texte (et le texte sous forme d'image) et l'arrière-plan du texte",
"WCAG_2.0-G152", "2.2.2 G152: Configurer les gifs animés pour qu'ils s'arrêtent de clignoter après n cycles (pendant 5 secondes)",
"WCAG_2.0-G158", "1.2.1 G158: Fournir une version de remplacement pour un média temporel seulement audio",
#
# G162: Positioning labels to maximize predictability of relationships
#       Failures of this technique are reported under technique H44
#
# G192: Fully conforming to specifications
#      Failures of this technique are reported under technique G143
#
"WCAG_2.0-G197", "3.2.4 G197: Utiliser les étiquettes, les noms et les équivalents textuels de façon cohérente pour des contenus ayant la même fonctionnalité",
"WCAG_2.0-H2", "1.1.1 H2: Combiner en un même lien une image et un intitulé de lien pour la même ressource",
"WCAG_2.0-H24", "1.1.1, 2.4.4 H24: Fournir un équivalent textuel pour l'élément area d'une image à zones cliquables",
"WCAG_2.0-H25", "2.4.2 H25: H25 : Donner un titre à l'aide de l'élément <title>",
"WCAG_2.0-H27", "1.1.1 H27: Fournir un équivalent textuel et non textuel pour un objet",
"WCAG_2.0-H30", "1.1.1, 2.4.4 H30: Fournir un intitulé de lien qui décrit la fonction du lien pour un élément <anchor>",
"WCAG_2.0-H32", "3.2.2 H32: Fournir un bouton 'submit'",
"WCAG_2.0-H33", "2.4.4 H33: Compléter l'intitulé du lien à l'aide de l'attribut title",
"WCAG_2.0-H35", "1.1.1 H35: Fournir un équivalent textuel pour l'élément <applet>",
"WCAG_2.0-H36", "1.1.1 H36: Utiliser un attribut alt sur une image utilisée comme bouton soumettre",
#"WCAG_2.0-H37", "1.1.1 H37: Utilisation des attributs 'alt' avec les éléments <img>",
"WCAG_2.0-H39", "1.3.1 H39: Utiliser l'élément 'caption' pour associer un titre de tableau avec les données du tableau",
"WCAG_2.0-H42", "1.3.1 H42: Utiliser h1-h6 pour identifier les en-têtes de section",
"WCAG_2.0-H43", "1.3.1 H43: Utiliser les attributs 'id' et 'headers' pour associer les cellules de données avec les cellules d'en-têtes dans les tableaux de données",
"WCAG_2.0-H44", "1.1.1, 1.3.1, 3.3.2, 4.1.2 H44: Utiliser l'élément <label> pour associer les étiquettes avec les champs de formulaire",
"WCAG_2.0-H45", "1.1.1 H45: Utiliser 'longdesc'",
"WCAG_2.0-H46", "1.1.1 H46: Utiliser <noembed> avec <embed>",
"WCAG_2.0-H48", "1.3.1 H48: Utiliser ol, ul et dl pour les listes",
"WCAG_2.0-H51", "1.3.1 H51: Utiliser le balisage des tableaux pour présenter l'information tabulaire",
"WCAG_2.0-H53", "1.1.1, 1.2.3 H53: Utiliser le corps de l'élément <object>",
"WCAG_2.0-H57", "3.1.1 H57: Utiliser les attributs de langue dans l'élément <html>",
"WCAG_2.0-H58", "3.1.2 H58: Utiliser les attributs de langue pour identifier les changements de langue",
"WCAG_2.0-H64", "2.4.1, 4.1.2 H64: Utiliser l'attribut 'title' des éléments <frame> et <iframe>",
"WCAG_2.0-H65", "1.3.1, 3.3.2, 4.1.2 H65: Utiliser l'attribut 'title' pour identifier un champ de formulaire quand l'élément <label> ne peut pas être utilisé",
"WCAG_2.0-H67", "1.1.1 H67: Utiliser un attribut alt vide sans attribut title sur un élément img pour les images qui doivent être ignorées par les technologies d'assistance",
"WCAG_2.0-H71", "1.3.1, 3.3.2 H71: Fournir une description des groupes de champs à l'aide des éléments <fieldset> et <legend>",
"WCAG_2.0-H73", "1.3.1 H73: Utiliser l'attribut 'summary' de l'élément <table> pour donner un aperçu d'un tableau de données",
"WCAG_2.0-H74", "4.1.1 H74: S'assurer que les balises d'ouverture et de fermeture sont utilisées conformément aux spécifications",
#
# H75: Ensuring that Web pages are well-formed
#      Failures of this technique are reported under technique G143
#
"WCAG_2.0-H88", "4.1.1, 4.1.2 H88: Utiliser HTML conformément aux spécifications",
"WCAG_2.0-H91", "2.1.1, 4.1.2 H91: Utiliser des éléments de formulaire et des liens HTML",
#
# H93: Ensuring that id attributes are unique on a Web page
#      Failures of this technique are reported under technique F77
#
"WCAG_2.0-H94", "4.1.1 H94: S'assurer que les éléments ne contiennent pas d'attributs dupliqués",
"WCAG_2.0-PDF1", "1.1.1 PDF1 : Application d’équivalents textuels aux images au moyen de l’entrée Alt dans les documents PDF",
"WCAG_2.0-PDF2", "2.4.5 PDF2 : Création de signets dans les documents PDF",
"WCAG_2.0-PDF6", "1.3.1 PDF6 : Utilisation d’éléments de table pour le balisage des tables dans les documents PDF",
"WCAG_2.0-PDF12", "1.3.1, 4.1.2 PDF12 : Fourni le nom, le rôle, la valeur des renseignements des champs de formulaire des documents PDF",
"WCAG_2.0-PDF16", "3.1.1 PDF16 : Règle la langue par défaut au moyen de l’entrée /Lang dans le catalogue de document d’un document PDF",
"WCAG_2.0-PDF18", "2.4.2 PDF18 : Précise le titre du document au moyen de l’entrée du dictionnaire d’informations du document d’un document PDF",
"WCAG_2.0-SC1.3.1", "1.3.1 SC1.3.1: Information et relations",
"WCAG_2.0-SC1.4.4", "1.4.4 SC1.4.4: Redimensionnement du texte",
"WCAG_2.0-SC2.4.3", "2.4.3 SC2.4.3: Parcours du focusr",
"WCAG_2.0-SC3.1.1", "3.1.1 SC3.1.1: Langue de la page",
"WCAG_2.0-SC4.1.2", "4.1.2 SC4.1.2: Nom, rôle et valeur",
#
# SCR2: Using redundant keyboard and mouse event handlers
#       Failures of this technique are reported under technique SCR20
#
"WCAG_2.0-SCR20", "2.1.1 SCR20: Utiliser à la fois des fonctions au clavier et spécifiques à d'autres périphériques",
"WCAG_2.0-SCR21", "1.3.1 SCR21: Utiliser les fonctions du modèle objet de document (DOM) pour ajouter du contenu à la page",
"WCAG_2.0-Guideline41", "4.1 Guideline41: Compatible",

#
# EPUB Accessibility Techniques 1.0
#
"EPUB-ACCESS-001", "1.3.2 ACCESS-001: Ensure linear reading order of the publication",
"EPUB-ACCESS-002", "2.4.5 ACCESS-002: Provide multiple ways to access the content",
"EPUB-DIST-001", "4.1.1 DIST-001: Do not restrict access through digital rights management",
"EPUB-META-001", "4.1.1 META-001: Identify primary access modes",
"EPUB-META-002", "4.1.1 META-002: Identify sufficient access modes",
"EPUB-META-003", "4.1.1 META-003: Identify accessibility features",
"EPUB-META-004", "4.1.1 META-004: Identify accessibility hazards",
"EPUB-META-005", "4.1.1 META-005: Include an accessibility summary",
"EPUB-META-006", "4.1.1 META-006: Identify ARIA Conformance",
"EPUB-META-007", "4.1.1 META-007: Identify Input Control Methods",
"EPUB-PAGE-001", "4.1.1 PAGE-001: Provide page break markers",
"EPUB-PAGE-003", "2.4.5 PAGE-001: Provide a page list",
"EPUB-SEM-001",  "1.3.1 SEM-001: Include ARIA and EPUB semantics",
"EPUB-SEM-003",  "2.4.5 SEM-003: Include EPUB landmarks",
"EPUB-TITLES-002", "1.3.1 TITLES-002: Ensure numbered headings reflect publication hierarchy",

#
# AXE Deque University testcases
#  https://dequeuniversity.com/rules/axe/3.3
#
"AXE-Audio_Caption", "1.2.1 AXE-Audio_Caption: <audio> elements must have a captions <track>",
"AXE-Blink", "2.2.2 AXE-Blink: <blink> elements are deprecated and must not be used",
"AXE-Definition_List", "1.3.1 <dl> elements must only directly contain properly-ordered <dt> and <dd> groups, <script>, or <template> elements",
"AXE-Dlitem", "1.3.1 AXE-Dlitem: <dt> and <dd> elements must be contained by a <dl>",
"AXE-Html_has_lang", "3.1.1 AXE-Html_has_lang: <html> element must have a lang attribute",
"AXE-Html_lang_valid", "3.1.1 AXE-Html_lang_valid: <html> element must have a valid value for the lang attribute",
"AXE-Html_xml_lang_mismatch", "3.1.1 AXE-Html_xml_lang_mismatch: <html> elements with lang and xml:lang must have the same base language",
"AXE-Listitem", "1.3.1 AXE-Listitem:<li> elements must be contained in a <ul> or <ol>",
"AXE-Marquee", "2.2.2 AXE-Marquee: <marquee> elements are deprecated and must not be used",
"AXE-Object_alt", "1.1.1 AXE-Object_alt: <object> elements must have alternate text",
"AXE-List", "1.3.1 AXE-List: <ul> and <ol> must only directly contain <li>, <script> or <template> elements",
"AXE-Video_Caption", "1.2.2, 1.2.3 AXE-Video_caption: <video> elements must have a <track> for captions",
"AXE-Video_Description", "1.2.5 AXE-Video_description: <video> elements must have an audio description <track>",
"AXE-Accesskeys", "4.1.1 AXE-Accesskeys: accesskey attribute value must be unique",
"AXE-Area_alt", "1.1.1 AXE-Area_alt: Active <area> elements must have alternate text",

"AXE-Td_headers_attr", "1.3.1 AXE-Td_headers_attr: All cells in a <table> element that use the headers attribute must only refer to other cells of that same <table>",

"AXE-Href_no_hash", "1.1.1, 2.4.4 AXE-Href_no_hash: Anchors must only be used as links with valid URLs or URL fragments",

"AXE-Aria_valid_attr", "4.1.2 AXE-Aria_valid_attr: ARIA attributes must conform to valid names",
"AXE-Aria_valid_attr_value", "4.1.2 AXE-Aria_valid_attr_value: ARIA attributes must conform to valid values",
"AXE-Aria_allowed_role", "4.1.2 AXE-Aria_allowed_role: ARIA role must be appropriate for the element",
"AXE-Aria_roles", "4.1.2 AXE-Aria_roles: ARIA roles used must conform to valid values",
"AXE-Aria_hidden_focus", "4.1.2 AXE-Aria_hidden_focus: aria-hidden elements do not contain focusable elements",
"AXE-Aria_hidden_body", "4.1.2 AXE-Aria_hidden_body: aria-hidden=\"true\" must not be present on the document <body>",

"AXE-Landmark_banner_is_top_level", "4.1.2 AXE-Landmark_banner_is_top_level: Banner landmark must not be contained in another landmark",
"AXE-P_as_heading", "1.3.1 AXE-P_as_heading: Bold, italic text and font-size are not used to style <p> elements as a heading",
"AXE-Button_name", "4.1.2 AXE-Button_name: Buttons must have discernible text",

"AXE-Aria_required_parent", "1.3.1 AXE-Aria_required_parent: Certain ARIA roles must be contained by particular parent elements",
"AXE-Aria_required_children", "1.3.1 AXE-Aria_required_children: Certain ARIA roles must contain particular children",
"AXE-Checkboxgroup", "1.3.1, 3.3.2 AXE-Checkboxgroup: Checkbox inputs with the same name attribute value must be part of a group",
"AXE-Landmark_complementary_is_top_level", "AXE-Landmark_complementary_is_top_level: Complementary landmarks and/or asides are top level",
"AXE-Landmark_contentinfo_is_top_level", "4.1.2 AXE-Landmark_contentinfo_is_top_level: Contentinfo landmark must not be contained in another landmark",

"AXE-Document_title", "2.4.2 AXE-Document_title: Documents must contain a title element to aid in navigation",
"AXE-Role_img_alt", "1.1.1 AXE-Role_img_alt: Elements containing role=\"img\" have an alternative text",

"AXE-Aria_allowed_attr", "4.1.2 AXE-Aria_allowed_attr: Elements must only use allowed ARIA attributes",
"AXE-Tabindex", "2.4.3 AXE-Tabindex: Elements should not have tabindex greater than zero",
"AXE-Label", "1.3.1 AXE-Label: Form <input> elements must have labels",
"AXE-Label_title_only", "3.3.2 AXE-Label_title_only: Form <input> elements should have a visible label",

"AXE-Form_field_multiple_labels", "1.3.1, 3.3.2 AXE-Form_field_multiple_labels: Form fields do not have duplicate labels",

"AXE-Frame_title_unique", "2.4.1, 4.1.2 AXE-Frame_title_unique: Frames must have a unique title attribute",
"AXE-Frame_title", "2.4.1, 4.1.2 AXE-Frame_title: Frames must have title attribute",
"AXE-Heading_order", "1.3.1 AXE-Heading_order: Heading levels should only increase by one",
"AXE-Empty_heading", "2.4.6 AXE-Empty_heading: Headings must not be empty",

"AXE-Duplicate_id", "4.1.1 AXE-Duplicate_id: ID attribute values must be unique",
"AXE-Input_image_alt", "1.1.1 AXE-Input_image_alt: Image buttons must have alternate text",
"AXE-Image_alt", "1.1.1 AXE-Image_alt: Images must have alternate text",

"AXE-Input_button_name", "4.1.2 AXE-Input_button_name: Input buttons must have discernible text",
"AXE-Label_content_name_mismatch", "2.5.3 AXE-Label_content_name_mismatch: Label and name from content mismatch",

"AXE-Valid_lang", "3.1.2 AXE-Valid_lang: lang attribute must have a valid value",
"AXE-Layout_table", "1.3.1 AXE-Layout_table: Layout tables must not use data table elements",

"AXE-Landmark_main_is_top_level", "1.3.1 AXE-Landmark_main_is_top_level: Main landmark must not be contained in another landmark",
"AXE-Page_has_heading_one", "1.3.1 AXE-Page_has_heading_one: Page must contain a level-one heading",

"AXE-Landmark_one_main", "1.3.1 AXE-Landmark_one_main: Page must have one main landmark",
"AXE-Landmark_no_duplicate_banner", "1.3.1 AXE-Landmark_no_duplicate_banner Page must not have more than one banner landmark",
"AXE-Landmark_no_duplicate_contentinfo", "1.3.1 AXE-Landmark_no_duplicate_contentinfo: Page must not have more than one contentinfo landmark",
"AXE-Radiogroup", "1.3.1, 3.3.2 AXE-Radiogroup: Radio inputs with the same name attribute value must be part of a group",
"AXE-Aria_required_attr", "4.1.2 AXE-Aria_required_attr: Required ARIA attributes must be provided",

"AXE-Table_duplicate_name", "1.3.1 AXE-Table_duplicate_name: The <caption> element should not contain the same text as the summary attribute",

"AXE-Meta_refresh", "2.2.1, 2.2.4, 3.2.5 AXE-Meta_refresh: Timed refresh must not exist",

"AXE-Image_redundant_alt", "1.1.1 AXE-Image_redundant_alt: Text of buttons and links should not be repeated in the image alternative",

"AXE-Aria_roledescription", "4.1.2 AXE-Aria_roledescription: Use aria-roledescription on elements with a semantic role",
"AXE-Meta_viewport_large", "1.4.4 AXE-Meta_viewport_large: Users should be able to zoom and scale the text up to 500%",
"AXE-Meta_viewport", "1.4.4 AXE-Meta_viewport: Zooming and scaling must not be disabled",

#
# Pa11y testcases
#  Pa11y is your automated accessibility testing pal
#  https://github.com/pa11y/pa11y
#
"Pa11y", "Pa11y: Automated accessibility testing pal",
);

#
# Default messages to English
#
my ($testcase_description_table) = \%testcase_description_en;

#
# Create table of testcase id and the list of test groups.
# This is a mapping of technique to success criterion for WCAG 2.0
#
my (%testcase_groups_table) = (
"WCAG_2.0-ARIA1", "2.4.2, 2.4.4, 3.3.2",
"WCAG_2.0-ARIA2", "3.3.2, 3.3.3",
"WCAG_2.0-ARIA6", "1.1.1",
"WCAG_2.0-ARIA7", "2.4.4",
"WCAG_2.0-ARIA8", "2.4.4",
"WCAG_2.0-ARIA9", "1.1.1, 3.3.2",
"WCAG_2.0-ARIA10", "1.1.1",
"WCAG_2.0-ARIA12", "1.3.1",
"WCAG_2.0-ARIA13", "1.3.1",
"WCAG_2.0-ARIA15", "1.1.1",
"WCAG_2.0-ARIA16", "1.3.1, 4.1.2",
"WCAG_2.0-ARIA17", "1.3.1, 3.3.2",
"WCAG_2.0-ARIA18", "3.3.1, 3.3.3",
"WCAG_2.0-C28", "1.4.4",
"WCAG_2.0-F2", "1.3.1",
"WCAG_2.0-F3", "1.1.1",
"WCAG_2.0-F4", "2.2.2",
"WCAG_2.0-F8", "1.2.2",
"WCAG_2.0-F16", "2.2.2",
"WCAG_2.0-F17", "1.3.1, 4.1.1",
"WCAG_2.0-F25", "2.4.2",
"WCAG_2.0-F30", "1.1.1, 1.2.1",
"WCAG_2.0-F32", "1.3.2",
"WCAG_2.0-F38", "1.1.1",
"WCAG_2.0-F39", "1.1.1",
"WCAG_2.0-F40", "2.2.1",
"WCAG_2.0-F41", "2.2.1",
"WCAG_2.0-F42", "1.3.1, 2.1.1",
"WCAG_2.0-F43", "1.3.1",
"WCAG_2.0-F44", "2.4.3",
"WCAG_2.0-F46", "1.3.1",
"WCAG_2.0-F47", "2.2.2",
"WCAG_2.0-F54", "2.1.1",
"WCAG_2.0-F55", "2.1.1, 2.4.7, 3.2.1",
"WCAG_2.0-F58", "2.2.1",
"WCAG_2.0-F62", "1.3.1, 4.1.1",
"WCAG_2.0-F65", "1.1.1",
"WCAG_2.0-F66", "3.2.3",
"WCAG_2.0-F68", "1.3.1, 4.1.2",
"WCAG_2.0-F70", "4.1.1",
"WCAG_2.0-F77", "4.1.1",
"WCAG_2.0-F87", "1.3.1",
"WCAG_2.0-F89", "2.4.4, 4.1.2",
"WCAG_2.0-F92", "1.3.1",
"WCAG_2.0-G18", "1.4.3",
"WCAG_2.0-G19", "2.3.1",
"WCAG_2.0-G87", "1.2.2",
#"WCAG_2.0-G94", "1.1.1",
"WCAG_2.0-G115", "1.3.1",
"WCAG_2.0-G125", "2.4.5",
"WCAG_2.0-G130", "2.4.6",
"WCAG_2.0-G131", "2.4.6, 3.3.2",
"WCAG_2.0-G134", "4.1.1",
"WCAG_2.0-G142", "1.4.4",
"WCAG_2.0-G145", "1.4.3",
"WCAG_2.0-G152", "2.2.2",
"WCAG_2.0-G158", "1.2.1",
"WCAG_2.0-G197", "3.2.4",
"WCAG_2.0-H2", "1.1.1",
"WCAG_2.0-H24", "1.1.1, 2.4.4",
"WCAG_2.0-H25", "2.4.2",
"WCAG_2.0-H27", "1.1.1",
"WCAG_2.0-H30", "1.1.1, 2.4.4",
"WCAG_2.0-H32", "3.2.2",
"WCAG_2.0-H33", "2.4.4",
"WCAG_2.0-H35", "1.1.1",
"WCAG_2.0-H36", "1.1.1",
"WCAG_2.0-H39", "1.3.1",
"WCAG_2.0-H42", "1.3.1",
"WCAG_2.0-H43", "1.3.1",
"WCAG_2.0-H44", "1.1.1, 1.3.1, 3.3.2, 4.1.2",
"WCAG_2.0-H45", "1.1.1",
"WCAG_2.0-H46", "1.1.1",
"WCAG_2.0-H48", "1.3.1",
"WCAG_2.0-H51", "1.3.1",
"WCAG_2.0-H53", "1.1.1, 1.2.3",
"WCAG_2.0-H57", "3.1.1",
"WCAG_2.0-H58", "3.1.2",
"WCAG_2.0-H64", "2.4.1, 4.1.2",
"WCAG_2.0-H65", "1.3.1, 3.3.2, 4.1.2",
"WCAG_2.0-H67", "1.1.1",
"WCAG_2.0-H71", "1.3.1, 3.3.2",
"WCAG_2.0-H73", "1.3.1",
"WCAG_2.0-H74", "4.1.1",
"WCAG_2.0-H88", "4.1.1, 4.1.2",
"WCAG_2.0-H91", "2.1.1, 4.1.2",
"WCAG_2.0-H94", "4.1.1",
"WCAG_2.0-PDF1", "1.1.1",
"WCAG_2.0-PDF2", "2.4.5",
"WCAG_2.0-PDF2", "1.3.1",
"WCAG_2.0-PDF12", "1.3.1, 4.1.2",
"WCAG_2.0-PDF16", "3.1.1",
"WCAG_2.0-PDF18", "2.4.2",
"WCAG_2.0-SC1.3.1", "1.3.1",
"WCAG_2.0-SC1.4.4", "1.4.4",
"WCAG_2.0-SC2.4.3", "2.4.3",
"WCAG_2.0-SC3.1.1", "3.1.1",
"WCAG_2.0-SC4.1.2", "4.1.2",
"WCAG_2.0-SCR20", "2.1.1",
"WCAG_2.0-SCR21", "1.3.1",
"WCAG_2.0-Guideline41", "4.1",
#
# EPUB Accessibility Techniques 1.0
#
"EPUB-ACCESS-001", "1.3.2",
"EPUB-ACCESS-002", "2.4.5",
"EPUB-DIST-001", "4.1.1",
"EPUB-META-001", "4.1.1",
"EPUB-META-002", "4.1.1",
"EPUB-META-003", "4.1.1",
"EPUB-META-004", "4.1.1",
"EPUB-META-005", "4.1.1",
"EPUB-META-006", "4.1.1",
"EPUB-META-007", "4.1.1",
"EPUB-PAGE-001", "4.1.1",
"EPUB-PAGE-003", "2.4.5",
"EPUB-SEM-001",  "1.3.1",
"EPUB-SEM-003",  "2.4.5",
"EPUB-TITLES-002", "1.3.1",

#
# AXE 3.2 Deque University testcases
#  https://dequeuniversity.com/rules/axe/3.2
#
"AXE-Audio_Caption", "1.2.1",
"AXE-Blink", "2.2.2",
"AXE-Definition_List", "1.3.1",
"AXE-Dlitem", "1.3.1",
"AXE-Html_has_lang", "3.1.1",
"AXE-Html_lang_valid", "3.1.1",
"AXE-Html_xml_lang_mismatch", "3.1.1",
"AXE-Listitem", "1.3.1",
"AXE-Marquee", "2.2.2",
"AXE-Object_alt", "1.1.1",
"AXE-List", "1.3.1",
"AXE-Video_Caption", "1.2.2, 1.2.3",
"AXE-Video_Description", "1.2.5",
"AXE-Accesskeys", "4.1.1",
"AXE-Area_alt", "1.1.1",

"AXE-Td_headers_attr", "1.3.1",

"AXE-Href_no_hash", "1.1.1, 2.4.4",

"AXE-Aria_valid_attr", "4.1.2",
"AXE-Aria_valid_attr_value", "4.1.2",
"AXE-Aria_allowed_role", "4.1.2",
"AXE-Aria_roles", "4.1.2",
"AXE-Aria_hidden_focus", "4.1.2",
"AXE-Aria_hidden_body", "4.1.2",

"AXE-Landmark_banner_is_top_level", "4.1.2",
"AXE-P_as_heading", "1.3.1",
"AXE-Button_name", "4.1.2",

"AXE-Aria_required_parent", "1.3.1",
"AXE-Aria_required_children", "1.3.1",
"AXE-Checkboxgroup", "1.3.1, 3.3.2",
"AXE-Landmark_complementary_is_top_level", "4.1.2",
"AXE-Landmark_contentinfo_is_top_level", "4.1.2",

"AXE-Document_title", "2.4.2",
"AXE-Role_img_alt", "1.1.1",

"AXE-Aria_allowed_attr", "4.1.2",
"AXE-Tabindex", "2.4.3",
"AXE-Label", "1.3.1, 3.3.2",
"AXE-Label_title_only", "3.3.2",

"AXE-Form_field_multiple_labels", "3.3.2",

"AXE-Frame_title_unique", "2.4.1, 4.1.2",
"AXE-Frame_title", "2.4.1, 4.1.2",
"AXE-Heading_order", "1.3.1",
"AXE-Empty_heading", "2.4.6",

"AXE-Duplicate_id", "4.1.1",
"AXE-Input_image_alt", "1.1.1",
"AXE-Image_alt", "1.1.1",

"AXE-Input_button_name", "4.1.2",
"AXE-Label_content_name_mismatch", "2.5.3",

"AXE-Valid_lang", "3.1.2",
"AXE-Layout_table", "1.3.1",

"AXE-Landmark_main_is_top_level", "1.3.1",
"AXE-Page_has_heading_one", "1.3.1",

"AXE-Landmark_one_main", "1.3.1",
"AXE-Landmark_no_duplicate_banner", "1.3.1",
"AXE-Landmark_no_duplicate_contentinfo", "1.3.1",
"AXE-Radiogroup", "1.3.1, 3.3.2",
"AXE-Aria_required_attr", "4.1.2",

"AXE-Table_duplicate_name", "1.3.1",

"AXE-Meta_refresh", "2.2.1, 2.2.4, 3.2.5",

"AXE-Image_redundant_alt", "1.1.1",

"AXE-Aria_roledescription", "4.1.2",
"AXE-Meta_viewport_large", "1.4.4",
"AXE-Meta_viewport", "1.4.4",
);

#
# Table of number of testcase groups for testcase profile types
#
my (%testcase_group_counts) = (
"WCAG_2.0", 38,
);

#
# String tables for success criteria to descriptions
#
my (%testcase_sc_description_en) = (
"1.1.1", "1.1.1 Non-text Content Level A",
"1.2.1", "1.2.1 Audio-only and Video-only (Prerecorded) Level A",
"1.2.2", "1.2.2 Captions (Prerecorded)Level A",
"1.2.3", "1.2.3 Audio Description or Media Alternative (Prerecorded) Level A",
"1.2.4", "1.2.4 Captions (Live) Level AA",
"1.2.5", "1.2.5 Audio Description (Prerecorded) Level AA",
"1.3.1", "1.3.1 Info and Relationships Level A",
"1.3.2", "1.3.2 Meaningful Sequence Level A",
"1.3.3", "1.3.3 Sensory Characteristics Level A",
"1.4.1", "1.4.1 Use of Colour Level A",
"1.4.2", "1.4.2 Audio Control Level A",
"1.4.3", "1.4.3 Contrast (Minimum) Level AA",
"1.4.4", "1.4.4 Resize Text Level AA",
"1.4.5", "1.4.5 Images of Text Level AA",
"2.1.1", "2.1.1 Keyboard Level A",
"2.1.2", "2.1.2 No Keyboard Trap Level A",
"2.2.1", "2.2.1 Timing Adjustable Level A",
"2.2.2", "2.2.2 Pause, Stop, Hide Level A",
"2.3.1", "2.3.1 Three Flashes or Below Level A",
"2.4.1", "2.4.1 Bypass Blocks Level A",
"2.4.2", "2.4.2 Page Titled Level A",
"2.4.3", "2.4.3 Focus Order Level A",
"2.4.4", "2.4.4 Link Purpose (In Context) Level A",
"2.4.5", "2.4.5 Multiple Ways Level AA",
"2.4.6", "2.4.6 Headings and Labels Level AA",
"2.4.7", "2.4.7 Focus Visible Level AA",
"3.1.1", "3.1.1 Language of Page Level A",
"3.1.2", "3.1.2 Language of Parts Level AA",
"3.2.1", "3.2.1 On Focus Level A",
"3.2.2", "3.2.2 On Input Level A",
"3.2.3", "3.2.3 Consistent Navigation Level AA",
"3.2.4", "3.2.4 Consistent Identification Level AA",
"3.3.1", "3.3.1 Error Identification Level A",
"3.3.2", "3.3.2 Labels or Instructions Level A",
"3.3.3", "3.3.3 Error Suggestion Level AA",
"3.3.4", "3.3.4 Error Prevention (Legal, Financial, Data) Level AA",
"4.1", "4.1 Compatible",
"4.1.1", "4.1.1 Parsing Level A",
"4.1.2", "4.1.2 Name, Role, Value Level A",
);

my (%testcase_sc_description_fr) = (
#
#  Text taken from http://www.braillenet.org/accessibilite/comprendre-wcag20/CAT20110222/Overview.html
#
"1.1.1", "1.1.1 Contenu non textuel Niveau A",
"1.2.1", "1.2.1 Contenu seulement audio ou vidéo (pré-enregistré) Niveau A",
"1.2.2", "1.2.2 Sous-titres (pré-enregistrés) Niveau A",
"1.2.3", "1.2.3 Audio-description ou version de remplacement pour un média temporel (pré-enregistré) Niveau A",
"1.2.4", "1.2.4 Sous-titres (en direct) Niveau AA",
"1.2.5", "1.2.5 Audio-description (pré-enregistrée) Niveau AA",
"1.3.1", "1.3.1 Information et relations Niveau A",
"1.3.2", "1.3.2 Ordre séquentiel logique Niveau A",
"1.3.3", "1.3.3 Caractéristiques sensorielles Niveau A",
"1.4.1", "1.4.1 Utilisation de la couleur Niveau A",
"1.4.2", "1.4.2 Contrôle du son Niveau A",
"1.4.3", "1.4.3 Contraste (Minimum) Niveau AA",
"1.4.4", "1.4.4 Redimensionnement du texte Niveau AA",
"1.4.5", "1.4.5 Texte sous forme d'image Niveau AA",
"2.1.1", "2.1.1 Clavier Niveau A",
"2.1.2", "2.1.2 Pas de piège au clavier Niveau A",
"2.2.1", "2.2.1 Réglage du délai Niveau A",
"2.2.2", "2.2.2 Mettre en pause, arrêter, masquer Niveau A",
"2.3.1", "2.3.1 Pas plus de trois flashs ou sous le seuil critique Niveau A",
"2.4.1", "2.4.1 Contourner des blocs Niveau A",
"2.4.2", "2.4.2 Titre de page Niveau A",
"2.4.3", "2.4.3 Parcours du focus Niveau A",
"2.4.4", "2.4.4[Fonction du lien (selon le contexte) Niveau A",
"2.4.5", "2.4.5 Accès multiples Niveau AA",
"2.4.6", "2.4.6 En-têtes et étiquettes Niveau AA",
"2.4.7", "2.4.7 Visibilité du focus Niveau AA",
"3.1.1", "3.1.1 Langue de la page Niveau A",
"3.1.2", "3.1.2 Langue d'un passaage Niveau AA",
"3.2.1", "3.2.1 Au focus Niveau A",
"3.2.2", "3.2.2 À la saisie Niveau A",
"3.2.3", "3.2.3 Navigation cohérente Niveau AA",
"3.2.4", "3.2.4 Identification cohérente Niveau AA",
"3.3.1", "3.3.1 Identification des erreurs Niveau A",
"3.3.2", "3.3.2 Étiquettes ou instructions Niveau A",
"3.3.3", "3.3.3 Suggestion après une erreur Niveau AA",
"3.3.4", "3.3.4 Prévention des erreurs (juridiques, financières, de données) Niveau AA",
"4.1", "4.1 Compatible",
"4.1.1", "4.1.1 Analyse syntaxique Niveau A",
"4.1.2", "4.1.2 Nom, rôle et valeur Niveau A",
);

#
# Create table of testcase id and the level of the test.
#
my (%testcase_level_table) = (
"WCAG_2.0-ARIA1", "A",
"WCAG_2.0-ARIA2", "A",
"WCAG_2.0-ARIA6", "A",
"WCAG_2.0-ARIA7", "A",
"WCAG_2.0-ARIA8", "A",
"WCAG_2.0-ARIA9", "A",
"WCAG_2.0-ARIA10", "A",
"WCAG_2.0-ARIA12", "A",
"WCAG_2.0-ARIA13", "A",
"WCAG_2.0-ARIA15", "A",
"WCAG_2.0-ARIA16", "A",
"WCAG_2.0-ARIA17", "A",
"WCAG_2.0-ARIA18", "A",
"WCAG_2.0-C28", "AA",
"WCAG_2.0-F2", "A",
"WCAG_2.0-F3", "A",
"WCAG_2.0-F4", "A",
"WCAG_2.0-F8", "A",
"WCAG_2.0-F16", "A",
"WCAG_2.0-F17", "A",
"WCAG_2.0-F25", "A",
"WCAG_2.0-F30", "A",
"WCAG_2.0-F32", "A",
"WCAG_2.0-F38", "A",
"WCAG_2.0-F39", "A",
"WCAG_2.0-F40", "A",
"WCAG_2.0-F41", "A",
"WCAG_2.0-F42", "A",
"WCAG_2.0-F43", "A",
"WCAG_2.0-F44", "A",
"WCAG_2.0-F46", "A",
"WCAG_2.0-F47", "A",
"WCAG_2.0-F54", "A",
"WCAG_2.0-F55", "A",
"WCAG_2.0-F58", "A",
"WCAG_2.0-F62", "A",
"WCAG_2.0-F65", "A",
"WCAG_2.0-F66", "AA",
"WCAG_2.0-F68", "A",
"WCAG_2.0-F70", "A",
"WCAG_2.0-F77", "A",
"WCAG_2.0-F87", "A",
"WCAG_2.0-F89", "A",
"WCAG_2.0-F92", "A",
"WCAG_2.0-G18", "AA",
"WCAG_2.0-G19", "A",
"WCAG_2.0-G87", "A",
#"WCAG_2.0-G94", "A",
"WCAG_2.0-G115", "A",
"WCAG_2.0-G125", "AA",
"WCAG_2.0-G130", "AA",
"WCAG_2.0-G131", "A",
"WCAG_2.0-G134", "A",
"WCAG_2.0-G142", "AA",
"WCAG_2.0-G145", "AA",
"WCAG_2.0-G152", "A",
"WCAG_2.0-G158", "A",
"WCAG_2.0-G197", "AA",
"WCAG_2.0-H2", "A",
"WCAG_2.0-H24", "A",
"WCAG_2.0-H25", "A",
"WCAG_2.0-H27", "A",
"WCAG_2.0-H30", "A",
"WCAG_2.0-H32", "A",
"WCAG_2.0-H33", "A",
"WCAG_2.0-H35", "A",
"WCAG_2.0-H36", "A",
"WCAG_2.0-H39", "A",
"WCAG_2.0-H42", "A",
"WCAG_2.0-H43", "A",
"WCAG_2.0-H44", "A",
"WCAG_2.0-H45", "A",
"WCAG_2.0-H46", "A",
"WCAG_2.0-H48", "A",
"WCAG_2.0-H51", "A",
"WCAG_2.0-H53", "A",
"WCAG_2.0-H57", "A",
"WCAG_2.0-H58", "AA",
"WCAG_2.0-H64", "A",
"WCAG_2.0-H65", "A",
"WCAG_2.0-H67", "A",
"WCAG_2.0-H71", "A",
"WCAG_2.0-H73", "A",
"WCAG_2.0-H74", "A",
"WCAG_2.0-H88", "A",
"WCAG_2.0-H91", "A",
"WCAG_2.0-H94", "A",
"WCAG_2.0-PDF1", "A",
"WCAG_2.0-PDF2", "AA",
"WCAG_2.0-PDF2", "A",
"WCAG_2.0-PDF12", "A",
"WCAG_2.0-PDF16", "A",
"WCAG_2.0-PDF18", "A",
"WCAG_2.0-SC1.3.1", "A",
"WCAG_2.0-SC1.4.4", "AA",
"WCAG_2.0-SC2.4.3", "A",
"WCAG_2.0-SC3.1.1", "A",
"WCAG_2.0-SC4.1.2", "A",
"WCAG_2.0-SCR20", "A",
"WCAG_2.0-SCR21", "A",
"WCAG_2.0-Guideline41", "A",
);

#
# Default messages to English
#
my ($testcase_sc_description_table) = \%testcase_sc_description_en;

#
# Create reverse table, indexed by description
#
my (%reverse_testcase_description_en) = reverse %testcase_description_en;
my (%reverse_testcase_description_fr) = reverse %testcase_description_fr;
my ($reverse_testcase_description_table) = \%reverse_testcase_description_en;

#
#******************************************************************
#
# String table for testcase help URLs
#
#******************************************************************
#

my (%testcase_url_en, %testcase_url_fr);

#
# Default URLs to English
#
my ($url_table) = \%testcase_url_en;

#***********************************************************************
#
# Name: TQA_Testcase_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub TQA_Testcase_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: TQA_Testcase_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of testcase description messages.
#
#***********************************************************************
sub TQA_Testcase_Language {
    my ($language) = @_;


    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "TQA_Testcase_Language, language = French\n" if $debug;
        $testcase_description_table = \%testcase_description_fr;
        $reverse_testcase_description_table = \%reverse_testcase_description_fr;
        $url_table = \%testcase_url_fr;
        $testcase_sc_description_table = \%testcase_sc_description_fr;
    }
    else {
        #
        # Default language is English
        #
        print "TQA_Testcase_Language, language = English\n" if $debug;
        $testcase_description_table = \%testcase_description_en;
        $reverse_testcase_description_table = \%reverse_testcase_description_en;
        $url_table = \%testcase_url_en;
        $testcase_sc_description_table = \%testcase_sc_description_en;
    }
}

#**********************************************************************
#
# Name: TQA_Testcase_Description
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase description 
# table for the specified key.  If there is no entry in the table an error
# string is returned.
#
#**********************************************************************
sub TQA_Testcase_Description {
    my ($key) = @_;

    #
    # Do we have a testcase description table entry for this key ?
    #
    if ( defined($$testcase_description_table{$key}) ) {
        #
        # return value
        #
        return ($$testcase_description_table{$key});
    }
    else {
        #
        # No testcase description table entry, either we are missing
        # a string or we have a typo in the key name.
        #
        return ("*** No string for $key ***");
    }
}

#**********************************************************************
#
# Name: TQA_Testcase_Success_Criteria_Description
#
# Parameters: key - success criteria
#
# Description:
#
#   This function returns the value in the success criteria description
# table for the specified key.  If there is no entry in the table an error
# string is returned.
#
#**********************************************************************
sub TQA_Testcase_Success_Criteria_Description {
    my ($key) = @_;

    #
    # Do we have a success criteria description table entry for this key ?
    #
    if ( defined($$testcase_sc_description_table{$key}) ) {
        #
        # return value
        #
        return ($$testcase_sc_description_table{$key});
    }
    else {
        #
        # No testcase success criteria table entry, either we are missing
        # a string or we have a typo in the key name.
        #
        return ("*** No string for $key ***");
    }
}

#**********************************************************************
#
# Name: TQA_Testcase_Groups
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase group
# table for the specified key.  If there is no entry in the table an 
# empty string is returned.
#
#**********************************************************************
sub TQA_Testcase_Groups {
    my ($key) = @_;

    #
    # Do we have a testcase group entry for this key ?
    #
    if ( defined($testcase_groups_table{$key}) ) {
        #
        # return value
        #
        return($testcase_groups_table{$key});
    }
    else {
        #
        # No testcase group table entry, return empty string.
        #
        return("");
    }
}

#**********************************************************************
#
# Name: TQA_Testcase_Group_Count
#
# Parameters: key - group type
#
# Description:
#
#   This function returns the value in the testcase group count
# table for the specified key.  If there is no entry in the table an
# empty string is returned.
#
#**********************************************************************
sub TQA_Testcase_Group_Count {
    my ($key) = @_;

    #
    # Do we have a testcase group count entry for this key ?
    #
    if ( defined($testcase_group_counts{$key}) ) {
        #
        # return value
        #
        return($testcase_group_counts{$key});
    }
    else {
        #
        # No testcase group count table entry, return empty string.
        #
        return("");
    }
}

#**********************************************************************
#
# Name: TQA_Testcase_Impact
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase level
# table for the specified key.  If there is no entry in the table
# an empty string is returned.
#
#**********************************************************************
sub TQA_Testcase_Impact {
    my ($key) = @_;
    
    #
    # Do we have an entry in the level table for this testcase id?
    #
    if ( defined($testcase_level_table{$key}) ) {
        return($testcase_level_table{$key});
    }
    else {
        return("");
    }
}

#**********************************************************************
#
# Name: TQA_Testcase_URL
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase URL 
# table for the specified key.
#
#**********************************************************************
sub TQA_Testcase_URL {
    my ($key) = @_;

    #
    # Do we have a string table entry for this key ?
    #
    print "TQA_Testcase_URL, key = $key\n" if $debug;
    if ( defined($$url_table{$key}) ) {
        #
        # return value
        #
        print "value = " . $$url_table{$key} . "\n" if $debug;
        return ($$url_table{$key});
    }
    #
    # Was the testcase description provided rather than the testcase
    # identifier ?
    #
    elsif ( defined($$reverse_testcase_description_table{$key}) ) {
        #
        # return value
        #
        $key = $$reverse_testcase_description_table{$key};
        print "value = " . $$url_table{$key} . "\n" if $debug;
        return ($$url_table{$key});
    }
    else {
        #
        # No string table entry, either we are missing a string or
        # we have a typo in the key name.
        #
        return;
    }
}

#**********************************************************************
#
# Name: TQA_Testcase_Read_URL_Help_File
#
# Parameters: filename - path to help file
#
# Description:
#
#   This function reads a testcase help file.  The file contains
# a list of testcases and the URL of a help page or standard that
# relates to the testcase.  A language field allows for English & French
# URLs for the testcase.
#
#**********************************************************************
sub TQA_Testcase_Read_URL_Help_File {
    my ($filename) = @_;

    my (@fields, $tcid, $lang, $url);

    #
    # Clear out any existing testcase/url information
    #
    %testcase_url_en = ();
    %testcase_url_fr = ();

    #
    # Check to see that the help file exists
    #
    if ( !-f "$filename" ) {
        print "Error: Missing URL help file\n" if $debug;
        print " --> $filename\n" if $debug;
        return;
    }

    #
    # Open configuration file at specified path
    #
    print "TQA_Testcase_Read_URL_Help_File Openning file $filename\n" if $debug;
    if ( ! open(HELP_FILE, "$filename") ) {
        print "Failed to open file\n" if $debug;
        return;
    }

    #
    # Read file looking for testcase, language and URL
    #
    while (<HELP_FILE>) {
        #
        # Ignore comment and blank lines.
        #
        chop;
        if ( /^#/ ) {
            next;
        }
        elsif ( /^$/ ) {
            next;
        }

        #
        # Split the line into fields.
        #
        @fields = split(/\s+/, $_, 3);

        #
        # Did we get 3 fields ?
        #
        if ( @fields == 3 ) {
            $tcid = $fields[0];
            $lang = $fields[1];
            $url  = $fields[2];
            print "Add Testcase/URL mapping $tcid, $lang, $url\n" if $debug;

            #
            # Do we have an English URL ?
            #
            if ( $lang =~ /eng/i ) {
                $testcase_url_en{$tcid} = $url;
                $reverse_testcase_description_en{$url} = $tcid;
            }
            #
            # Do we have a French URL ?
            #
            elsif ( $lang =~ /fra/i ) {
                $testcase_url_fr{$tcid} = $url;
                $reverse_testcase_description_fr{$url} = $tcid;
            }
            else {
                print "Unknown language $lang\n" if $debug;
            }
        }
        else {
            print "Line does not contain 3 fields, ignored: \"$_\"\n" if $debug;
        }
    }
    
    #
    # Close configuration file
    #
    close(HELP_FILE);
}

#***********************************************************************
#
# Mainline
#
#***********************************************************************

#
# Return true to indicate we loaded successfully
#
return 1;

