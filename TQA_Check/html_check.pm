#***********************************************************************
#
# Name:   html_check.pm
#
# $Revision: 6540 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/TQA_Check/Tools/html_check.pm $
# $Date: 2014-01-09 12:03:53 -0500 (Thu, 09 Jan 2014) $
#
# Description:
#
#   This file contains routines that parse HTML files and check for
# a number of technical quality assurance check points.
#
# Public functions:
#     Set_HTML_Check_Language
#     Set_HTML_Check_Debug
#     Set_HTML_Check_Testcase_Data
#     Set_HTML_Check_Test_Profile
#     Set_HTML_Check_Valid_Markup
#     HTML_Check
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

package html_check;

use strict;
use HTML::Parser;
use HTML::Entities;
use URI::URL;
use File::Basename;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Set_HTML_Check_Language
                  Set_HTML_Check_Debug
                  Set_HTML_Check_Testcase_Data
                  Set_HTML_Check_Test_Profile
                  Set_HTML_Check_Valid_Markup
                  HTML_Check
                  HTML_Check_Link_Anchor_Alt_Title_Check
                  HTML_Check_Other_Tool_Results
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (%testcase_data, %template_comment_map_en);
my (@paths, $this_path, $program_dir, $program_name, $paths);

my (%tqa_check_profile_map, $current_tqa_check_profile);

my (@color_stack,  $current_a_href,
    $last_heading_line_number, $last_heading_column_number,
    %input_id_location, %label_for_location, %accesskey_location,
    $table_nesting_index, @table_start_line, @table_header_values,
    @table_start_column, @table_has_headers, @table_summary,
    %test_case_desc_map, $have_text_handler, @text_handler_tag_list,
    @text_handler_text_list, $inside_h_tag_set, %anchor_name,
    %anchor_text_href_map, %anchor_location, $current_color,
    $current_heading_level, %found_legend_tag, $current_text_handler_tag,
    $fieldset_tag_index, @td_attributes, @inside_thead,
    $embed_noembed_count, $last_embed_line, $last_embed_col,
    $object_nest_level, $last_image_alt_text,
    $current_url, $in_form_tag, $found_input_button, $found_title_tag,
    $found_frame_tag, $doctype_line, $doctype_column, $doctype_label,
    $doctype_language, $doctype_version, $doctype_class, $doctype_text,
    %id_attribute_values, $have_metadata, $results_list_addr,
    $content_heading_count, $total_heading_count,
    $last_radio_checkbox_name, $content_section_handler,
    $current_a_title, %content_section_found, $last_tag, $last_open_tag,
    $current_content_lang_code, $inside_label, %last_label_attributes,
    $text_between_tags, $in_head_tag, @tag_order_stack, $wcag_2_0_h74_reported,
    @param_lists, $inside_anchor,
    $image_found_inside_anchor, $wcag_2_0_f70_reported,
    %html_tags_allowed_only_once_location, $last_a_href, $last_a_contains_image,
    %abbr_acronym_text_title_lang_map, $current_lang, $abbr_acronym_title,
    %abbr_acronym_text_title_lang_location, @lang_stack, @tag_lang_stack, 
    $last_lang_tag, %abbr_acronym_title_text_lang_map,
    %abbr_acronym_title_text_lang_location, @list_item_count, 
    $current_list_level, $number_of_writable_inputs, %form_label_value,
    %form_legend_value, %form_title_value, %legend_text_value,
    @inside_list_item, $last_heading_text, $have_figcaption, 
    $image_in_figure_with_no_alt, $fig_image_line, $fig_image_column,
    $fig_image_text, $in_figure, $found_onclick_onkeypress,
    $onclick_onkeypress_line, $onclick_onkeypress_column,
    @onclick_onkeypress_tag, $onclick_onkeypress_text, $have_focusable_item,
    $pseudo_header, $emphasis_count, $anchor_inside_emphasis,
    @missing_table_headers, @table_header_locations, @table_header_types,
);

my ($is_valid_html) = -1;

my ($tags_allowed_events) = " a area button form input select ";
my ($tags_with_color_attribute) = " BODY TABLE TD TH HR ";
my ($input_types_requiring_label_before)  = " file password text ";
my ($input_types_requiring_label_after)  = " checkbox radio ";
my ($input_types_requiring_label) = $input_types_requiring_label_before .
                                    $input_types_requiring_label_after;
my ($input_types_not_using_label)  = " button hidden image reset submit ";
my ($input_types_requiring_value)  = " button reset submit ";
my ($max_error_message_string)= 2048;
my ($click_here_patterns) =  " here click here more ici cliquez ici plus ";
my (%section_markers) = ();
my ($have_content_markers) = 0;
my (@required_content_sections) = ("CONTENT");
my ($pseudo_header_length) = 50;

#
# Maximum length of a heading or title
#
my ($max_heading_title_length) = 500;

my (%html_tags_with_no_end_tag) = (
        "area", "area",
        "base", "base",
        "br", "br",
        "col", "col",
        "command", "command",
        "embed", "embed",
        "frame", "frame",
        "hr", "hr",
        "img", "img",
        "input", "input",
        "keygen", "keygen",
        "link", "link",
        "meta", "meta",
        "param", "param",
        "source", "source",
        "track", "track",
        "wbr", "wbr",
);
my ($mouse_only_event_handlers) = " onmousedown onmouseup onmouseover onmouseout ";
my ($keyboard_only_event_handlers) = " onkeydown onkeyup onfocus onblur ";
my (%html_tags_cannot_nest) = (
        "a", "a",
        "abbr", "abbr",
        "acronym", "acronym",
        "b", "b",
        "em", "em",
        "figure", "figure",
        "h1", "h1",
        "h2", "h2",
        "h3", "h3",
        "h4", "h4",
        "h5", "h5",
        "h6", "h6",
        "hr", "hr",
        "img", "img",
        "p", "p",
        "strong", "strong",
);

#
# Tags that must have text between the start and end tags.
# This is the list of tags that don't have any other special
# handling.
#
my (%tags_that_must_have_content) = (
    "address", "",
    "cite",    "",
    "code",    "",
    "dd",      "",
    "dfn",     "",
    "dt",      "",
    "em",      "",
    "li",      "",
    "pre",     "",
    "strong",  "",
    "sub",  "",
    "sup",  "",
);


#
# Status values
#
my ($tqa_check_pass)       = 0;
my ($tqa_check_fail)       = 1;

#
# Deprecated HTML 4 tags
#
my (%deprecated_html4_tags) = (
    "applet",   "",
    "basefont", "",
    "center",   "",
    "dir",      "",
    "font",     "",
    "isindex",  "",
    "menu",     "",
    "s",        "",
    "strike",   "",
    "u",        "",
);

#
# Deprecated XHTML tags
# Source: http://webdesign.about.com/od/htmltags/a/bltags_deprctag.htm
#
my (%deprecated_xhtml_tags) = (
    "applet",     "",
#    "b",          "",
    "basefont",   "",
    "blackface",  "",
    "center",     "",
    "dir",        "",
    "embed",      "",
    "font",       "",
#    "i",          "",
    "isindex",    "",
    "layer",      "",
    "menu",       "",
    "noembed",    "",
    "s",          "",
    "shadow",     "",
    "strike",     "",
    "u",          "",
);

#
# Deprecated HTML 5 tags
# Source: http://www.w3.org/TR/html5-diff/
#
my (%deprecated_html5_tags) = (
    "acronym",   "",
    "applet",   "",
    "isindex",   "",
    "basefont",   "",
    "blackface",  "", # XHTML
    "big",   "",
    "center",   "",
    "dir",   "",
    "font",   "",
    "frame",   "",
    "frameset",   "",
    "hgroup",   "",
    "isindex",   "",
    "layer",      "", # XHTML
    "menu",       "", # XHTML
    "noframes",   "",
    "s",          "", # XHTML
    "shadow",     "", # XHTML
    "strike",   "",
    "tt",   "",
);

#
# Deprecated HTML 4 attributes, hash table with index being an attribute
# and the value a list of tags (with leading and trailing space).
#
my (%deprecated_html4_attributes) = (
);

#
# Deprecated XHTML attributes, hash table with index being an attribute
# and the value a list of tags (with leading and trailing space).
# Source: http://webdesign.about.com/od/htmltags/a/bltags_deprctag.htm
#
my (%deprecated_xhtml_attributes) = (
    "align",      " applet caption div h1 h2 h3 h4 h5 h6 hr iframe img input legend object p table ",
    "alink",      " body ",
    "alt",        " applet ",
    "archive",    " applet ",
    "background", " body ",
    "bgcolor",    " body table td th tr ",
    "border",     " img object ",
    "clear",      " br ",
    "code",       " applet ",
    "codebase",   " applet ",
    "color",      " basefont font ",
    "compact",    " dir dl menu ol ul ",
    "face",       " basefont font ",
    "height",     " td th ",
    "hspace",     " img object ",
    "language",   " script ",
    "link",       " body ",
    "name",       " applet ",
    "noshade",    " hr ",
    "nowrap",     " td th ",
    "object",     " applet ",
    "prompt",     " isindex ",
    "size",       " basefont font hr ",
    "start",      " ol ",
    "text",       " body ",
    "type",       " li ol ul ",
    "value",      " li ",
    "version",    " html ",
    "vlink",      " body ",
    "vspace",     " img object ",
    "width",      " applet hr pre td th ",
);

#
# Deprecated HTML 5 attributes, hash table with index being an attribute
# and the value a list of tags (with leading and trailing space).
# Source: http://www.w3.org/TR/html5-diff/
#
# Note: Some deprecated/obsolete attributes do not result in the page
# being non-conforming.  We will continue to report these attributes as
# depreceted in order to encourage web developers to remove/replace the
# attributes (http://www.w3.org/TR/html5/obsolete.html#obsolete)
#
my (%deprecated_html5_attributes) = (
    "abbr",       " td th ",
    "align",      " applet caption col colgroup div h1 h2 h3 h4 h5 h6 hr iframe img input legend object p table tbody td tfoot th thead tr ",
    "alink",      " body ", # XHTML
    "alt",        " applet ", # XHTML
    "archive",    " applet object ", 
    "axis",       " td th ",
    "background", " body ", # XHTML
    "bgcolor",    " body table td th tr ", # XHTML
    "border",     " img object ", # XHTML
    "cellpadding", " table ",
    "cellspacing", " table ",
    "char",       " col colgroup tbody td tfoot th thead tr ",
    "charoff",    " col colgroup tbody td tfoot th thead tr ",
    "classid",    " object ", 
    "clear",      " br ", # XHTML
    "charset",    " a link ",
    "code",       " applet ", # XHTML
    "codebase",   " applet object ", 
    "codetype",   " object ", 
    "color",      " basefont font ", # XHTML
    "compact",    " dir dl menu ol ul ", # XHTML
    "coords",     " a ",
    "declare",    " object ", 
    "face",       " basefont font ", # XHTML
    "frame",      " table ", 
    "form",       " progress meter ", 
    "frameborder", " iframe ", 
    "height",     " td th ", # XHTML
    "hspace",     " img object ", # XHTML
    "language",   " script ", # XHTML
    "link",       " body ", # XHTML
    "longdesc",   " iframe img ",
    "marginheight", " iframe ", 
    "marginwidth", " iframe ", 
    "media",      " a area ",
    "name",       " a applet img ",
    "nohref",     " area ",
    "noshade",    " hr ", # XHTML
    "nowrap",     " td th ", # XHTML
    "object",     " applet ", # XHTML
    "profile",    " head ",
    "prompt",     " isindex ", # XHTML
    "pubdate",    " time ", 
    "rules",      " table ", 
    "scheme",     " meta ",
    "size",       " basefont font hr ", # XHTML
    "rev",        " a link ",
    "scope",      " td ",
    "scrolling",  " iframe ", 
    "shape",      " a ",
    "standby",    " object ", 
    "summary",    " table ",
    "target",     " link ",
    "text",       " body ", # XHTML
    "time",       " pubdate ",
    "type",       " li param ul ",
    "valign",     " col colgroup tbody td tfoot th thead tr ",
    "valuetype",  " param ", 
    "version",    " html ", # XHTML
    "vlink",      " body ", # XHTML
    "vspace",     " img object ", # XHTML
    "width",      " applet col colgroup hr pre table td th ",
);

#
# List of HTML 4 tags with an implicit end tag.
# The tag is implicitly closed if it is followed by one of the
# specified start tags.
#
my (%implicit_html4_end_tag_start_handler) = (
);

#
# List of HTML 4 tags with an implicit end tag.
# The tag is implicitly closed if it is followed by one of the
# specified close tags.
#
my (%implicit_html4_end_tag_end_handler) = (
);

#
# List of XHTML tags with an implicit end tag.
# The tag is implicitly closed if it is followed by one of the
# specified start tags.
#
my (%implicit_xhtml_end_tag_start_handler) = (
);

#
# List of XHTML tags with an implicit end tag.
# The tag is implicitly closed if it is followed by one of the
# specified close tags.
#
my (%implicit_xhtml_end_tag_end_handler) = (
);

#
# List of HTML 5 tags with an implicit end tag.
# The tag is implicitly closed if it is followed by one of the
# specified start tags.
# Source: http://dev.w3.org/html5/spec/Overview.html#optional-tags
#
my (%implicit_html5_end_tag_start_handler) = (
  "address", "p ",
  "article", "p ",
  "aside", "p ",
  "blockquote", "p ",
  "dd", " dd dt ",
  "dir", "p ",
  "dl", "p ",
  "dt", " dd dt ",
  "fieldset", "p ",
  "footer", "p ",
  "form", "p ",
  "h1", "p ",
  "h2", "p ",
  "h3", "p ",
  "h4", "p ",
  "h5", "p ",
  "h6", "p ",
  "header", "p ",
  "hgroup", "p ",
  "hr", "p ",
  "li", " li ",
  "menu", "p ",
  "nav", "p ",
  "ol", "p ",
  "p", "p ",
  "pre", "p ",
  "rp", " rp rt ",
  "rt", " rp rt ",
  "table", "p ",
  "tbody", " tbody tfoot ",
  "thead", " tbody tfoot ",
  "tfoot", " tbody ",
  "td", " td th ",
  "th", " td th ",
  "tr", " tr ",
  "ul", "p ",
);

#
# List of HTML 5 tags with an implicit end tag.
# The tag is implicitly closed if it is followed by one of the
# specified close tags.
# Source: http://dev.w3.org/html5/spec/Overview.html#optional-tags
#
my (%implicit_html5_end_tag_end_handler) = (
  "dd", " dl ",
  "li", " ol ul ",
  "p",  " address article aside blockquote body button dd del details div" .
        " dl fieldset figure form footer header ins li map menu nav ol" .
        " pre section table td th ul ",
  "tbody", " table ",
  "thead", " table ",
  "tfoot", " table ",
  "td", " table ",
  "th", " table ",
  "tr", " table ",
);

#
# Pointer to deprecated tag and attribute table
#
my ($deprecated_tags, $deprecated_attributes);
my ($implicit_end_tag_end_handler, $implicit_end_tag_start_handler);

#
# List of HTML tags that cannot appear multiple times in a
# single document.
#
my (%html_tags_allowed_only_once) = (
    "body",  "body",
    "head",  "head",
    "html",  "html",
    "title", "title",
);

#
# Valid values for the rel attribute of tags
#
my %valid_xhtml_rel_values = ();

#
# Valid values for the rel attribute of tags
#  Source: http://www.w3.org/TR/2011/WD-html5-20110525/links.html#linkTypes
#  Value "shortcut" is not listed in the above page but is a valid value
#  for <link> tags.
#  Date: 2012-11-09
#
my %valid_html5_rel_values = (
   "a",    " alternate author bookmark external help license next nofollow noreferrer prefetch prev search sidebar tag ",
   "area", " alternate author bookmark external help license next nofollow noreferrer prefetch prev search sidebar tag ",
   "link", " alternate author help icon license next pingback prefetch prev search shortcut sidebar stylesheet tag ",
);

#
# Values for the rel attribute of tags
#  Source: http://microformats.org/wiki/existing-rel-values#HTML5_link_type_extensions
#  Date: 2012-11-09
#
$valid_html5_rel_values{"a"} .= "attachment category disclosure entry-content external home index profile publisher rendition sidebar widget http://docs.oasis-open.org/ns/cmis/link/200908/acl ";
$valid_html5_rel_values{"area"} .= "attachment category disclosure entry-content external home index profile publisher rendition sidebar widget http://docs.oasis-open.org/ns/cmis/link/200908/acl ";
$valid_html5_rel_values{"link"} .= "apple-touch-icon apple-touch-icon-precomposed apple-touch-startup-image attachment canonical category dns-prefetch EditURI home index meta openid.delegate openid.server openid2.local_id openid2.provider p3pv1 pgpkey pingback prerender profile publisher rendition servive shortlink sidebar sitemap timesheet widget wlwmanifest image_src  http://docs.oasis-open.org/ns/cmis/link/200908/acl stylesheet/less ";

my ($valid_rel_values);

#
# String table for error strings.
#
my %string_table_en = (
    "Fails validation",               "Fails validation, see validation results for details.",
    "DOCTYPE missing",                "DOCTYPE missing",
    "Metadata missing",               "Metadata missing",
    "Missing alt attribute for",      "Missing 'alt' attribute for ",
    "Missing alt content for",        "Missing 'alt' content for ",
    "Insufficient color contrast for tag",                 "Insufficient color contrast for tag ",
    "color is",                       " color is ",
    "Missing title attribute for",   "Missing 'title' attribute for ",
    "Missing table summary",         "Missing table 'summary'",
    "No legend found in fieldset",   "No <legend> found in <fieldset>",
    "No table header tags found",    "No table header tags found",
    "Missing id attribute for",      "Missing 'id' attribute for ",
    "Invalid CSS file referenced",   "Invalid CSS file referenced",
    "No table header reference",     "No table header reference",
    "Missing html language attribute",  "Missing <html> attribute",
    "Page redirect not allowed",     "Page redirect not allowed",
    "Page refresh not allowed",      "Page refresh not allowed",
    "Deprecated tag found",          "Deprecated tag found ",
    "Deprecated attribute found",    "Deprecated attribute found ",
    "E-mail domain",                 "E-mail domain ",
    "Link contains JavaScript",      "Link contains JavaScript",
    "New heading level",             "New heading level ",
    "is not equal to last level",    " is not equal to last level ",
    "Missing text in",               "Missing text in ",
    "Missing text in table header",  "Missing text in table header ",
    "click here link found",         "'click here' link found",
    "Multiple links with same anchor text", "Multiple links with same anchor text ",
    "Multiple links with same title text", "Multiple links with same 'title' text ",
    "Previous instance found at",    "Previous instance found at (line:column) ",
    "Required testcase not executed","Required testcase not executed",
    "No label matching id attribute","No <label> matching 'id' attribute ",
    "No label for",                  "No <label> for ",
    "Missing template comment",      "content",
    "or",                            " or ",
    "link",                          "link",
    "No matching noembed for embed", "No matching <noembed> for <embed>",
    "Duplicate table summary and caption", "Duplicate table 'summary' and <caption>",
    "Found label before input type",   "Found <label> before <input> type ",
    "Missing label before",            "Missing <label> before ",
    "Missing title content for",       "Missing 'title' content for ",
    "Combining adjacent image and text links for the same resource",   "Combining adjacent image and text links for the same resource",
    "Missing longdesc content for",    "Missing 'longdesc' content for ",
    "Broken link in longdesc for",     "Broken link in 'longdesc' for ",
    "Invalid URL in longdesc for",     "Invalid URL in 'longdesc' for ",
    "Missing cite content for",        "Missing 'cite' content for ",
    "Broken link in cite for",         "Broken link in 'cite' for ",
    "Missing alt or title in",         "Missing 'alt' or 'title' in ",
    "Missing label id or title for",   "Missing <label> 'id' or 'title' for ",
    "Missing event handler from pair", "Missing event handler from pair ",
    "for tag",                         " for tag ",
    "in tag",                          " in tag ",
    "No button found in form",         "No button found in form",
    "Image alt same as src",           "Image 'alt' same as 'src'",
    "Meta refresh with timeout",       "Meta 'refresh' with timeout ",
    "Mismatching lang and xml:lang attributes", "Mismatching 'lang' and 'xml:lang' attributes",
    "Anchor and image alt text the same", "Anchor and image 'alt' text the same",
    "Missing value attribute in",       "Missing 'value' attribute in ",
    "Missing value in",                 "Missing value in ",
    "Missing id content for",           "Missing 'id' content for ",
    "Duplicate anchor name",            "Duplicate anchor name ",
    "Duplicate label id",               "Duplicate <label> 'id' ",
    "Duplicate id",                     "Duplicate 'id' ",
    "Duplicate id in headers",          "Duplicate 'id' in 'headers'",
    "Missing",                          "Missing",
    "found in header",                  "found in header",
    "Self reference in headers",        "Self reference in 'headers'",
    "Header defined at",                "Header defined at (line:column)",
    "Duplicate",                        "Duplicate",
    "Duplicate accesskey",              "Duplicate 'accesskey' ",
    "Invalid content for",              "Invalid content for ",
    "Blinking text in",                 "Blinking text in ",
    "GIF animation exceeds 5 seconds",  "GIF animation exceeds 5 seconds",
    "GIF flashes more than 3 times in 1 second", "GIF flashes more than 3 times in 1 second",
    "Missing <title> tag",              "Missing <title> tag",
    "Found tag",                        "Found tag ",
    "Found label for",                  "Found <label> for ",
    "Label found for hidden input",      "<label> found for <input type=\"hidden\">",
    "Duplicate attribute",              "Duplicate attribute ",
    "Missing xml:lang attribute",       "Missing 'xml:lang' attribute ",
    "Missing lang attribute",           "Missing 'lang' attribute ",
    "Anchor text same as href",         "Anchor text same as 'href'",
    "Anchor text same as title",        "Anchor text same as 'title'",
    "Anchor title same as href",        "Anchor 'title' same as 'href'",
    "onclick or onkeypress found in tag", "'onclick' or 'onkeypress' found in tag ",
    "Unused label, for attribute",      "Unused <label>, 'for' attribute ",
    "at line:column",                   " at (line:column) ",
    "Anchor text is a URL",             "Anchor text is a URL",
    "found",                            "found",
    "previously found",                 "previously found",
    "in",                               " in ",
    "No headings found",                "No headings found in content area",
    "No links found",                   "No links found",
    "Missing fieldset",                 "Missing <fieldset> tag",
    "HTML language attribute",          "HTML language attribute",
    "does not match content language",  "does not match content language",
    "Label not explicitly associated to", "Label not explicitly associated to ",
    "Previous label not explicitly associated to", "Previous label not explicitly associated to ",
    "Text",                             "Text",
    "not marked up as a <label>",       "not marked up as a <label>",
    "Expecting end tag",                "Expecting end tag",
    "Span language attribute",          "Span language attribute",
    "Mouse only event handlers found",  "Mouse only event handlers found",
    "Invalid title",                    "Invalid title",
    "End tag",                          "End tag",
    "forbidden",                        "forbidden",
    "Invalid alt text value",           "Invalid 'alt' text value",
    "Invalid title text value",         "Invalid 'title' text value",
    "Link inside of label",             "Link inside of <label>",
    "Null alt on an image",             "Null alt on an image where the image is the only content in a link",
    "Using white space characters to control spacing within a word in tag", "Using white space characters to control spacing within a word in tag",
    "Fieldset found outside of a form", "Fieldset found outside of a <form>",
    "Using script to remove focus when focus is received", "Using script to remove focus when focus is received",
    "Missing close tag for",            "Missing close tag for",
    "started at line:column",           "started at (line:column) ",
    "Multiple instances of",            "Multiple instances of",
    "Title values do not match for",    "'title' values do not match for",
    "Found",                            "Found",
    "Content same as title for",        "Content same as 'title' for ",
    "Content values do not match for",  "Content values do not match for ",
    "Missing content in",               "Missing content in ",
    "No li found in list",              "No <li> found in list ",
    "No dt found in list",              "No <dt> found in list ",
    "used for decoration",              "used for decoration",
    "followed by",                      " followed by ",
    "Tag not allowed here",             "Tag not allowed here ",
    "Missing content before new list",  "Missing content before new list ",
    "for",                              "for ",
    "Missing href, id or name in <a>",  "Missing attribute href, id or name in <a>",
    "Missing rel attribute in",       "Missing 'rel' attribute in ",
    "Missing rel value in",           "Missing 'rel' value in ",
    "Invalid rel value",              "Invalid 'rel' value",
    "Missing rel value",              "Missing 'rel' value",
    "Content does not contain letters for", "Content does not contain letters for ",
    "Invalid attribute combination found", "Invalid attribute combination found",
    "Table headers",                  "Table 'headers'",
    "not defined within table",       "not defined within <table>",
    "Heading text greater than 500 characters",  "Heading text greater than 500 characters",
    "Title text greater than 500 characters",            "Title text greater than 500 characters",
    "Title same as id for",               "'title' same as 'id' for ",
    "Text styled to appear like a heading", "Text styled to appear like a heading",
);


#
# String table for error strings (French).
#
my %string_table_fr = (
    "Fails validation",              "Échoue la validation, voir les résultats de validation pour plus de détails.",
    "DOCTYPE missing",               "DOCTYPE manquant",
    "Metadata missing",              "Métadonnées manquantes",
    "Missing alt attribute for",     "Attribut 'alt' manquant pour ",
    "Missing alt content for",       "Le contenu de 'alt' est manquant pour ",
    "Insufficient color contrast for tag", "Contrast de couleurs insuffisant pour balise ",
    "color is",                      " la couleur est ",
    "Missing title attribute for",   "Attribut 'title' manquant pour ",
    "Missing table summary",         "Résumé de tableau manquant",
    "No legend found in fieldset",   "Aucune <legend> retrouvé dans le <fieldset>",
    "No table header tags found",    "Aucune balise d'en-tête de tableau retrouvée",
    "Missing id attribute for",      "Attribut 'id' manquant pour ",
    "Invalid CSS file referenced",   "Fichier CSS non valide retrouvé",
    "No table header reference",     "Aucun en-tête de tableau retrouvé",
    "Missing html language attribute","Attribut manquant pour <html>",
    "Page redirect not allowed",     "Page rediriger pas autorisé",
    "Page refresh not allowed",      "Page raffraîchissement pas autorisé",
    "Deprecated tag found",          "Balise dépréciée retrouvée ",
    "Deprecated attribute found",    "Attribut dépréciée retrouvée ",
    "E-mail domain",                 "Domaine du courriel ",
    "Link contains JavaScript",      "Lien contient du JavaScript",
    "New heading level",             "Nouveau niveau d'en-tête ",
    "is not equal to last level",    " n'est pas égal à au dernier niveau ",
    "Missing text in",               "Texte manquant dans ",
    "Missing text in table header",  "Texte manquant tête de tableau ",
    "click here link found",         "Lien 'cliquez ici' retrouvé",
    "Multiple links with same anchor text",  "Liens multiples avec la même texte de lien ",
    "Multiple links with same title text",  "Liens multiples avec la même texte de 'title' ",
    "Previous instance found at",    "Instance précédente trouvée à (la ligne:colonne) ",
    "Required testcase not executed","Cas de test requis pas exécuté",
    "No label matching id attribute","Aucun <label> correspondant à l'attribut 'id' ",
    "No label for",                  "Aucun <label> pour ",
    "Missing template comment",      "Commentaire manquant dans le modèle",
    "or",                            " ou ",
    "link",                          "lien",
    "No matching noembed for embed", "Aucun <noembed> correspondant à <embed>",
    "Duplicate table summary and caption", "Éléments 'summary' et <caption> du tableau en double",
    "Found label before input type",   "<label> trouvé devant le type <input> ",
    "Missing label before",            "Élément <label> manquant avant ",
    "Missing title content for",       "Contenu de l'élément 'title' manquant pour ",
    "Combining adjacent image and text links for the same resource",   "Combiner en un même lien une image et un intitulé de lien pour la même ressource",
    "Missing longdesc content for",    "Contenu de l'élément 'longdesc' manquant pour ",
    "Broken link in longdesc for",     "Lien brisé dans l'élément 'longdesc' pour ",
    "Invalid URL in longdesc for",     "URL non valide dans 'longdesc' pour ",
    "Missing cite content for",        "Contenu de l'élément 'cite' manquant pour ",
    "Broken link in cite for",         "Lien brisé dans l'élément 'cite' pour ",
    "Missing alt or title in",         "Attribut 'alt' ou 'title' manquant dans  ",
    "Missing label id or title for",   "Éléments 'id' ou 'title' de l'élément <label> manquants pour ",
    "Missing event handler from pair", "Gestionnaire d'événements manquant dans la paire ",
    "for tag",                         " pour balise ",
    "in tag",                          " dans balise ",
    "No button found in form",         "Aucun bouton trouvé dans le <form>",
    "Image alt same as src",           "'alt' et 'src'identiques pour l'image",
    "Meta refresh with timeout",       "Méta 'refresh' avec délai d'inactivité ",
    "Mismatching lang and xml:lang attributes", "Erreur de correspondance des attributs 'lang' et 'xml:lang'",
    "Anchor and image alt text the same", "Textes de l'ancrage et de l'attribut 'alt' de l'image identiques",
    "Missing value attribute in",       "Attribut 'value' manquant dans ",
    "Missing value in",                 "Valeur manquante dans ",
    "Missing id content for",           "Contenu de l'élément 'id' manquant pour ",
    "Duplicate anchor name",            "Doublon du nom d'ancrage ",
    "Duplicate label id",               "Doublon <label> 'id' ",
    "Duplicate id",                     "Doublon 'id' ",
    "Duplicate id in headers",          "Doublon 'id' dans 'headers'",
    "Missing",                          "Manquantes",
    "found in header",                  "trouvé dans les en-têtes",
    "Self reference in headers",        "référence auto dans 'headers'",
    "Header defined at",                "En-tête défini à (la ligne:colonne)",
    "Duplicate",                        "Doublon",
    "Duplicate accesskey",              "Doublon 'accesskey' ",
    "Invalid content for",              "Contenu invalide pour ",
    "Blinking text in",                 "Texte clignotant dans ",
    "GIF animation exceeds 5 seconds",  "Clignotement de l'image GIF supérieur à 5 secondes",
    "GIF flashes more than 3 times in 1 second", "Clignotement de l'image GIF supérieur à 3 par seconde",
    "Missing <title> tag",              "Balise <title> manquant",
    "Found tag",                        "Balise trouvé ",
    "Found label for",                  "<label> trouvé pour ",
    "Label found for hidden input",      "<label> trouvé pour <input type=\"hidden\">",
    "Duplicate attribute",              "Doublon attribut ",
    "Missing xml:lang attribute",       "Attribut 'xml:lang' manquant ",
    "Missing lang attribute",           "Attribut 'lang' manquant ",
    "Anchor text same as href",         "Texte d'ancrage identique à 'href'",
    "Anchor text same as title",        "Texte d'ancrage identique à 'title'",
    "Anchor title same as href",        "'title' d'ancrage identique à 'href'",
    "onclick or onkeypress found in tag", "'onclick' ou 'onkeypress' trouvé dans la balise ",
    "Unused label, for attribute",      "<label> ne pas utilisé, l'attribut 'for' ",
    "at line:column",                   " à (la ligne:colonne) ",
    "Anchor text is a URL",             "Texte d'ancrage est une URL",
    "found",                            "trouvé",
    "previously found",                 "trouvé avant",
    "in",                               " dans ",
    "No headings found",                "Pas des têtes qui se trouvent dans la zone de contenu",
    "No links found",                   "Pas des liens qui se trouvent",
    "Missing fieldset",                 "Élément <fieldset> manquant",
    "HTML language attribute",          "L'attribut du langage HTML",
    "does not match content language",  "ne correspond pas à la langue de contenu",
    "Label not explicitly associated to", "Étiquette pas explicitement associée à la ",
    "Previous label not explicitly associated to", "Étiquette précédente pas explicitement associée à la ",
    "Text",                            "Texte",
    "not marked up as a <label>",      "pas marqué comme un <label>",
    "Expecting end tag",               "S'attendant balise de fin",
    "Span language attribute",         "Attribut de langue 'span'",
    "Mouse only event handlers found", "Gestionnaires de la souris ne se trouve que l'événement",
    "Invalid title",                   "Titre invalide",
    "End tag",                         "Balise de fin",
    "forbidden",                       "interdite",
    "Invalid alt text value",          "Valeur de texte 'alt' est invalide",
    "Invalid title text value",        "Valeur de texte 'title' est invalide",
    "Link inside of label",            "Un lien dans une <label>",
    "Null alt on an image",            "Utiliser un attribut alt vide pour une image qui est le seul contenu d'un lien",
    "Using white space characters to control spacing within a word in tag", "Utiliser des caractères blancs pour contrôler l'espacement à l'intérieur d'un mot dans balise",
    "Fieldset found outside of a form", "Fieldset trouvé en dehors d'une <form>",
    "Using script to remove focus when focus is received", "Utiliser un script pour enlever le focus lorsque le focus est reçu",
    "Missing close tag for",           "Balise de fin manquantes pour",
    "started at line:column",          "a commencé à (la ligne:colonne) ",
    "Multiple instances of",           "Plusieurs instances de",
    "Title values do not match for",   "Valeurs 'title' ne correspondent pas pour ",
    "Found",                           "Trouvé",
    "Content same as title for",       "Contenu et 'title' identiques pour ",
    "Content values do not match for",  "Valeurs contenu ne correspondent pas pour ",
    "Missing content in",               "Contenu manquant dans ",
    "No li found in list",              "Pas de <li> trouvé dans la liste ",
    "No dt found in list",              "Pas de <dt> trouvé dans la liste ",
    "used for decoration",              "utilisé pour la dcoration",
    "followed by",                      " suivie par ",
    "Tag not allowed here",             "Balise pas autorisé ici ",
    "Missing content before new list",  "Contenu manquant avant la nouvelle liste ",
    "for",                              "pour ",
    "Missing href, id or name in <a>",  "Attribut href, id ou name manquant dans <a>",
    "Missing rel attribute in",       "Attribut 'rel' manquant dans ",
    "Missing rel value in",           "Valeur manquante dans 'rel' ",
    "Invalid rel value",              "Valeur de texte 'rel' est invalide",
    "Missing rel value",              "Valeur manquante pour 'rel'",
    "Content does not contain letters for", "Contenu ne contient pas des lettres pour ",
    "Invalid attribute combination found", "Combinaison d'attribut non valide trouvé",
    "Table headers",                  "'headers' de tableau",
    "not defined within table",       "pas défini dans le <table>",
    "Heading text greater than 500 characters",  "Texte du têtes supérieure 500 caractères",
    "Title text greater than 500 characters",    "Texte du title supérieure 500 caractères",
    "Title same as id for",               "'title' identique à 'id' pour ",
    "Text styled to appear like a heading", "Texte de style pour apparaître comme un titre",
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_HTML_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_HTML_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_HTML_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_HTML_Check_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_HTML_Check_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_HTML_Check_Language, language = English\n" if $debug;
        $string_table = \%string_table_en;
    }
}

#**********************************************************************
#
# Name: String_Value
#
# Parameters: key - string table key
#
# Description:
#
#   This function returns the value in the string table for the
# specified key.  If there is no entry in the table an error string
# is returned.
#
#**********************************************************************
sub String_Value {
    my ($key) = @_;

    #
    # Do we have a string table entry for this key ?
    #
    if ( defined($$string_table{$key}) ) {
        #
        # return value
        #
        return ($$string_table{$key});
    }
    else {
        #
        # No string table entry, either we are missing a string or
        # we have a typo in the key name.
        #
        return ("*** No string for $key ***");
    }
}

#***********************************************************************
#
# Name: Set_HTML_Check_Testcase_Data
#
# Parameters: testcase - testcase identifier
#             data - string of data
#
# Description:
#
#   This function copies the passed data into a hash table
# for the specified testcase identifier.
#
#***********************************************************************
sub Set_HTML_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_HTML_Check_Test_Profile
#
# Parameters: profile - TQA check test profile
#             tqa_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by TQA testcase name.
#
#***********************************************************************
sub Set_HTML_Check_Test_Profile {
    my ($profile, $tqa_checks ) = @_;

    my (%local_tqa_checks);
    my ($key, $value);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_HTML_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_tqa_checks = %$tqa_checks;
    $tqa_check_profile_map{$profile} = \%local_tqa_checks;
}

#***********************************************************************
#
# Name: Set_HTML_Check_Valid_Markup
#
# Parameters: valid_html - flag
#
# Description:
#
#   This function copies the passed flag into the global
# variable is_valid_html.  The possible values are
#    1 - valid HTML
#    0 - not valid HTML
#   -1 - unknown validity.
# This value is used when assessing WCAG 2.0-G134
#
#***********************************************************************
sub Set_HTML_Check_Valid_Markup {
    my ($valid_html) = @_;

    #
    # Copy the data into global variable
    #
    if ( defined($valid_html) ) {
        $is_valid_html = $valid_html;
    }
    else {
        $is_valid_html = -1;
    }
    print "Set_HTML_Check_Valid_Markup, validity = $is_valid_html\n" if $debug;
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - TQA check test profile
#             local_results_list_addr - address of results list.
#
# Description:
#
#   This function initializes the test case results table.
#
#***********************************************************************
sub Initialize_Test_Results {
    my ($profile, $local_results_list_addr) = @_;

    my ($test_case, @comment_lines, $line, $english_comment, $french_comment);
    my ($name);

    #
    # Set current hash tables
    #
    $current_tqa_check_profile = $tqa_check_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;

    #
    # Check to see if we were told that this document is not
    # valid HTML
    #
    if ( $is_valid_html == 0 ) {
        Record_Result("WCAG_2.0-G134", -1, 0, "",
                      String_Value("Fails validation"));
    }

    #
    # Initialize other global variables
    #
    $current_color         = "";
    $current_a_href        = "";
    $current_heading_level = 0;
    @color_stack           = ();
    %label_for_location    = ();
    %accesskey_location    = ();
    %input_id_location     = ();
    %form_label_value      = ();
    %form_legend_value     = ();
    %form_title_value      = ();
    %id_attribute_values   = ();
    $table_nesting_index   = -1;
    @table_start_line      = ();
    @table_start_column    = ();
    @table_has_headers     = ();
    @table_header_values   = ();
    @table_header_types    = ();
    @missing_table_headers = ();
    @table_header_locations = ();
    $inside_h_tag_set      = 0;
    %anchor_text_href_map  = ();
    %anchor_location       = ();
    %anchor_name           = ();
    %found_legend_tag      = ();
    $fieldset_tag_index    = 0;
    $have_text_handler     = 0;
    $current_text_handler_tag = "";
    @text_handler_tag_list = ();
    @text_handler_text_list = ();
    $embed_noembed_count   = 0;
    $object_nest_level     = 0;
    $found_title_tag       = 0;
    $found_frame_tag       = 0;
    $doctype_line          = -1;
    $doctype_column        = -1;
    $doctype_label         = "";
    $have_metadata         = 0;
    $content_heading_count = 0;
    $total_heading_count   = 0;
    $last_radio_checkbox_name = "";
    $current_a_title       = "";
    $current_content_lang_code = "";
    $inside_label          = 0;
    $last_tag              = "";
    $last_open_tag         = "";
    %last_label_attributes = ();
    $text_between_tags     = "";
    $in_head_tag           = 0;
    @tag_order_stack       = ();
    $wcag_2_0_h74_reported = 0;
    $wcag_2_0_f70_reported = 0;
    @param_lists           = ();
    $image_found_inside_anchor = 0;
    $inside_anchor         = 0;
    $in_form_tag           = 0;
    $number_of_writable_inputs = 0;
    %html_tags_allowed_only_once_location = ();
    $last_a_href           = "";
    $last_a_contains_image = 0;
    %abbr_acronym_text_title_lang_map = ();
    %abbr_acronym_text_title_lang_location = ();
    %abbr_acronym_title_text_lang_map = ();
    %abbr_acronym_title_text_lang_location = ();
    $current_lang          = "eng";
    push(@lang_stack, $current_lang);
    push(@tag_lang_stack, "top");
    $last_lang_tag         = "top";
    @list_item_count       = ();
    $current_list_level    = -1;
    $in_head_tag           = 0;
    %legend_text_value     = ();
    $last_heading_text     = "";
    $current_text_handler_tag = "";
    $pseudo_header         = "";
    $emphasis_count        = 0;
    $anchor_inside_emphasis = 0;

    #
    # Initialize content section found flags to false
    #
    foreach $name (@required_content_sections) {
        $content_section_found{$name} = 0;
    }

    #
    # Initially assume this is a HTML 4.0 document, if it turn out to
    # be XHTML or HTML 5, we will catch that in the declaration line.
    # Set list of deprecated tags.
    #
    $deprecated_tags = \%deprecated_html4_tags;
    $deprecated_attributes = \%deprecated_html4_attributes;
    $implicit_end_tag_end_handler = \%implicit_html4_end_tag_end_handler;
    $implicit_end_tag_start_handler = \%implicit_html4_end_tag_start_handler;
    $valid_rel_values = \%valid_xhtml_rel_values;
}

#***********************************************************************
#
# Name: Print_Error
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             error_string - error string
#
# Description:
#
#   This function prints error messages if debugging is enabled..
#
#***********************************************************************
sub Print_Error {
    my ( $line, $column, $text, $error_string ) = @_;

    #
    # Print error message if we are in debug mode
    #
    if ( $debug ) {
        print "$error_string\n";

        #
        # Check for line -1, this means that we are missing content
        # from the HTML document.
        #
        if ( $line > 0 ) {
            #
            # Print line containing error
            #
            print "Starting with tag at line:$line, column:$column\n";
            printf( " %" . $column . "s^^^^\n\n", "^" );
        }
    }
}

#***********************************************************************
#
# Name: Record_Result
#
# Parameters: testcase - testcase identifier
#             line - line number
#             column - column number
#             text - text from tag
#             error_string - error string
#
# Description:
#
#   This function records the testcase result.
#
#***********************************************************************
sub Record_Result {
    my ( $testcase, $line, $column, $text, $error_string ) = @_;

    my ($result_object);

    #
    # Is this testcase included in the profile
    #
    if ( defined($testcase) && defined($$current_tqa_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $tqa_check_fail,
                                                TQA_Testcase_Description($testcase),
                                                $line, $column, $text,
                                                $error_string, $current_url);
        $result_object->testcase_groups(TQA_Testcase_Groups($testcase));
        push (@$results_list_addr, $result_object);

        #
        # Print error string to stdout
        #
        Print_Error($line, $column, $text, "$testcase : $error_string");
    }
}

#***********************************************************************
#
# Name: Clean_Text
#
# Parameters: text - text string
#
# Description:
#
#   This function eliminates leading and trailing white space from text.
# It also compresses multiple white space characters into a single space.
#
#***********************************************************************
sub Clean_Text {
    my ($text) = @_;
    
    #
    # Encode entities.
    #
    $text = encode_entities($text);

    #
    # Convert &nbsp; into a single space.
    # Convert newline into a space.
    # Convert return into a space.
    #
    $text =~ s/\&nbsp;/ /g;
    $text =~ s/\n/ /g;
    $text =~ s/\r/ /g;
    
    #
    # Convert multiple spaces into a single space
    #
    $text =~ s/\s\s+/ /g;
    
    #
    # Trim leading and trailing white space
    #
    $text =~ s/^\s*//g;
    $text =~ s/\s*$//g;
    
    #
    # Return cleaned text
    #
    return($text);
}

#***********************************************************************
#
# Name: Get_Text_Handler_Content
#
# Parameters: self - reference to a HTML::Parse object
#             separator - text to separate content components
#
# Description:
#
#   This function gets the text from the text handler.  It
# joins all the text together and trims off whitespace.
#
#***********************************************************************
sub Get_Text_Handler_Content {
    my ($self, $separator) = @_;
    
    my ($content) = "";
    
    #
    # Add a text handler to save text
    #
    print "Get_Text_Handler_Content separator = \"$separator\"\n" if $debug;
    
    #
    # Do we have a text handler ?
    #
    if ( $have_text_handler ) {
        #
        # Get any text.
        #
        $content = join($separator, @{ $self->handler("text") });
    }
    
    #
    # Return the content
    #
    return($content);
}

#***********************************************************************
#
# Name: Destroy_Text_Handler
#
# Parameters: self - reference to a HTML::Parse object
#             tag - current tag
#
# Description:
#
#   This function destroys a text handler.
#
#***********************************************************************
sub Destroy_Text_Handler {
    my ($self, $tag) = @_;
    
    my ($saved_text, $current_text);

    #
    # Destroy text handler
    #
    print "Destroy_Text_Handler for tag $tag\n" if $debug;

    #
    # Do we have a text handler ?
    #
    if ( $have_text_handler ) {
        #
        # Get the text from the handler
        #
        $current_text = Get_Text_Handler_Content($self, " ");
        
        #
        # Destroy the text handler
        #
        $self->handler( "text", undef );
        $have_text_handler = 0;
        
        #
        # Get tag name for previous tag (if there was one)
        #
        if ( @text_handler_tag_list > 0 ) {
            $current_text_handler_tag = pop(@text_handler_tag_list);
            print "Restart text handler for tag $current_text_handler_tag\n" if $debug;
            
            #
            # We have to create a new text handler to restart the
            # text collection for the previous tag.  We also have to place
            # the saved text back in the handler.
            #
            $saved_text = pop(@text_handler_text_list);
            $self->handler( text => [], '@{dtext}' );
            $have_text_handler = 1;
            print "Push \"$saved_text\" into text handler\n" if $debug;
            push(@{ $self->handler("text")}, $saved_text);
            
            #
            # Do we add the text from the just destroyed text handler to
            # the previous tag's handler ?  In most cases we do.
            #
            if ( ($tag eq "a") && ($current_text_handler_tag eq "label") ) {
                #
                # Don't add anchor tag text to a label tag.
                #
                print "Not adding <a> text to <label> text handler\n" if $debug;
            }
            else {
                #
                # Add text from this tag to the previous tag's text handler
                #
                print "Adding \"$current_text\" text to text handler\n" if $debug;
                push(@{ $self->handler("text")}, " $current_text ");
            }
        }
        else {
            #
            # No previous text handler, set current text handler tag name
            # to an empty string.
            #
            $current_text_handler_tag = "";
        }
    } else {
        #
        # No text handler to destroy.
        #
        print "No text handler to destroy\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Have_Text_Handler_For_Tag
#
# Parameters: tag - tag name
#
# Description:
#
#   This function returns true if a text handler has been started for
# the named tag.
#
#***********************************************************************
sub Have_Text_Handler_For_Tag {
    my ($tag) = @_;

    my ($this_tag);

    #
    # Do we have an active text handler ?
    # 
    if ( $have_text_handler ) {
        #
        # Check the tag names for each active handler
        #
        foreach $this_tag (@text_handler_tag_list) {
            if ( $this_tag eq $tag ) {
                #
                # Found text handler for this tag
                #
                return(1);
            }
        }
    }

    #
    # If we got here, we have no text handler for the specified tag
    #
    return(0);
}

#***********************************************************************
#
# Name: Start_Text_Handler
#
# Parameters: self - reference to a HTML::Parse object
#             tag - current tag
#
# Description:
#
#   This function starts a text handler.  If one is already set, it
# is destroyed and recreated (to erase any existing saved text).
#
#***********************************************************************
sub Start_Text_Handler {
    my ($self, $tag) = @_;
    
    my ($current_text);
    
    #
    # Add a text handler to save text
    #
    print "Start_Text_Handler for tag $tag\n" if $debug;
    
    #
    # Do we already have a text handler ?
    #
    if ( $have_text_handler ) {
        #
        # Save any text we may have already captured.  It belongs
        # to the previous tag.  We have to start a new handler to
        # save text for this tag.
        #
        $current_text = Get_Text_Handler_Content($self, " ");
        push(@text_handler_tag_list, $current_text_handler_tag);
        print "Saving \"$current_text\" for $current_text_handler_tag tag\n" if $debug;
        push(@text_handler_text_list, $current_text);
        
        #
        # Destoy the existing text handler so we don't include text from the
        # current tag's handler for this tag.
        #
        $self->handler( "text", undef );
    }
    
    #
    # Create new text handler
    #
    $self->handler( text => [], '@{dtext}' );
    $have_text_handler = 1;
    $current_text_handler_tag = $tag;
}

#***********************************************************************
#
# Name: Check_Character_Spacing
#
# Parameters: tag - name of HTML tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function checks a block of text for using white space characters
# to control spacing within a word. It checks for a series of single
# characters with spaces between them.  This isn't a 100% fool proof
# method of catching using white space characters to control spacing
# within a word, it is based on the assumption that it is very unlikely
# that 4 or more single letter words would appear in a row.
#
#***********************************************************************
sub Check_Character_Spacing {
    my ($tag, $line, $column, $text) = @_;
    
    #
    # Check for 4 or more single character words in the
    # text string.
    #
    if ( $text =~ /\s+[a-z]\s+[a-z]\s+[a-z]\s+[a-z]\s+/i ) {
        Record_Result("WCAG_2.0-F32", $line, $column, $text,
                      String_Value("Using white space characters to control spacing within a word in tag") . " $tag");
    }
}

#***********************************************************************
#
# Name: Check_For_Alt_Attribute
#
# Parameters: tcid - testcase id
#             tag - name of HTML tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks for the presence of an alt attribute.
#
#***********************************************************************
sub Check_For_Alt_Attribute {
    my ( $tcid, $tag, $line, $column, $text, %attr ) = @_;

    #
    # Look for alt attribute
    #
    print "Check for alt attribute\n" if $debug;
    if ( ! defined($attr{"alt"}) ) {
        Record_Result($tcid, $line, $column, $text,
                      String_Value("Missing alt attribute for") . "$tag");
    }
}

#***********************************************************************
#
# Name: Check_Alt_Content
#
# Parameters: tcid - testcase id
#             tag - name of HTML tag
#             self - reference to object
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks for alt text content.
#
#***********************************************************************
sub Check_Alt_Content {
    my ( $tcid, $tag, $self, $line, $column, $text, %attr ) = @_;

    my ($alt);

    #
    # Do we have an alt attribute ? If not we don't generate
    # an error message here, it will already have been done by
    # a call to the function Check_For_Alt_Attribute (possibly
    # with a different testcase id).
    #
    if ( defined($attr{"alt"}) ) {
        $alt = $attr{"alt"};

        #
        # Remove whitespace and check to see if we have any text.
        #
        $alt =~ s/\s*//g;
        if ( $alt eq "" ) {
            Record_Result($tcid, $line, $column, $text,
                          String_Value("Missing alt content for") . "$tag");
        }
    }
}

#***********************************************************************
#
# Name: Tag_Not_Allowed_Here
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function records an error when a tag is found out of context
# (e.g. <td> outside of a <table>).
#
#***********************************************************************
sub Tag_Not_Allowed_Here {
    my ( $tagname, $line, $column, $text ) = @_;

    #
    # Tag found where it is not expected.
    #
    print "Tag $tagname found out of context\n" if $debug;
    Record_Result("WCAG_2.0-H88", $line, $column, $text,
                  String_Value("Tag not allowed here") . "<$tagname>");
}

#***********************************************************************
#
# Name: Frame_Tag_Handler
#
# Parameters: tag - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the frame or iframe tag, it looks for
# a title attribute.
#
#***********************************************************************
sub Frame_Tag_Handler {
    my ( $tag, $line, $column, $text, %attr ) = @_;

    my ($title);

    #
    # Found a Frame tag, set flag so we can verify that the doctype
    # class is frameset
    #
    $found_frame_tag = 1;

    #
    # Look for a title attribute
    #
    if ( !defined( $attr{"title"} ) ) {
        Record_Result("WCAG_2.0-H64", $line, $column, $text,
                      String_Value("Missing title attribute for") . "<$tag>");
    }
    else {
        #
        # Is the title an empty string ?
        #
        $title = $attr{"title"};
        $title =~ s/\s*//g;
        if ( $title eq "" ) {
            Record_Result("WCAG_2.0-H64", $line, $column, $text,
                          String_Value("Missing title content for") . "<$tag>");
        }
    }
    
    #
    # Check longdisc attribute
    #
    if ( defined($$current_tqa_check_profile{"WCAG_2.0-H88"}) ) {
        Check_Longdesc_Attribute("WCAG_2.0-H88", "<frame>", $line, $column,
                                 $text, %attr);
    }
}

#***********************************************************************
#
# Name: Table_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the table tag, it looks at any color attribute
# to see that it has an appropriate value.
#
#***********************************************************************
sub Table_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    my ($summary, %header_values, %missing_header_references);
    my (%header_locations, %header_types);

    #
    # Increment table nesting index and initialise the table
    # variables.
    #
    $table_nesting_index++;
    $table_start_line[$table_nesting_index] = $line;
    $table_start_column[$table_nesting_index] = $column;
    $table_has_headers[$table_nesting_index] = 0;
    $table_header_values[$table_nesting_index] = \%header_values;
    $table_header_locations[$table_nesting_index] = \%header_locations;
    $table_header_types[$table_nesting_index] = \%header_types;
    $missing_table_headers[$table_nesting_index] = \%missing_header_references;
    $inside_thead[$table_nesting_index] = 0;

    #
    # Do we have a summary attribute ?
    #
    if ( defined( $attr{"summary"} ) ) {
        $summary = Clean_Text($attr{"summary"});

        #
        # Save summary value to check against a possible caption
        #
        $table_summary[$table_nesting_index] = lc($summary);

        #
        # Are we missing a summary ?
        #
        if ( $summary eq "" ) {
            Record_Result("WCAG_2.0-H73", $line, $column, $text,
                          String_Value("Missing table summary"));
        }
    }
    else {
        $table_summary[$table_nesting_index] = "";
    }
}

#***********************************************************************
#
# Name: End_Fieldset_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the end field set tag.
#
#***********************************************************************
sub End_Fieldset_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($tcid, @tcids);

    #
    # Did we see a legend inside the fieldset ?
    #
    if ( $fieldset_tag_index > 0 ) {
        if ( ! $found_legend_tag{$fieldset_tag_index} ) {
            #
            # Determine testcase
            #
            if ( defined($$current_tqa_check_profile{"WCAG_2.0-H71"}) ) {
                push(@tcids, "WCAG_2.0-H71");
            }
            if ( defined($$current_tqa_check_profile{"WCAG_2.0-H91"}) ) {
                push(@tcids, "WCAG_2.0-H91");
            }

            #
            # Missing legend for fieldset
            #
            foreach $tcid (@tcids) {
                Record_Result($tcid, $line, $column, $text,
                              String_Value("No legend found in fieldset"));
            }
        }

        #
        # Close this <fieldset> .. </fieldset> tag pair.
        #
        $found_legend_tag{$fieldset_tag_index} = 0;
        $fieldset_tag_index--;
    }
    else {
        print "End fieldset without corresponding start fieldset\n" if $debug;
    }

    #
    # Was this fieldset found within a <form> ? If not then it was
    # probable used to give a border to a block of text.
    #
    if ( ! $in_form_tag ) {
        Record_Result("WCAG_2.0-F43", $line, $column, $text,
                      String_Value("Fieldset found outside of a form"));
    }
}

#***********************************************************************
#
# Name: End_Table_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the end table tag, it looks to see if column
# or row labels (headers) were used.
#
#***********************************************************************
sub End_Table_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($start_line, $start_column, $table_ref, $list_ref, $id);
    my ($h_ref, $h_line, $h_column, $h_headers, $h_text);
    my ($header_values);

    #
    # Check to see if table headers were used in this table.
    #
    if ( $table_nesting_index >= 0 ) {
        #
        # Check for any missing table header definitions
        #
        $table_ref = $missing_table_headers[$table_nesting_index];
        $header_values = $table_header_values[$table_nesting_index];
        foreach $id (keys %$table_ref) {
            $list_ref = $$table_ref{$id};
            foreach $h_ref (@$list_ref) {
                ($h_line, $h_column, $h_headers, $h_text) = split(":", $h_ref, 4);
                if ( ! defined($$header_values{$id}) ) {
                    Record_Result("WCAG_2.0-H43", $h_line, $h_column, $h_text,
                                  String_Value("Table headers") .
                                  " \"$id\" " .
                                  String_Value("not defined within table"));
                }
            }
        }

        #
        # Remove table headers values
        #
        undef $table_header_values[$table_nesting_index];
        undef $table_header_locations[$table_nesting_index];
        undef $missing_table_headers[$table_nesting_index];
        undef $table_header_types[$table_nesting_index];

        #
        # Decrement global table nesting value
        #
        $table_nesting_index--;
    }
}

#***********************************************************************
#
# Name: HR_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the hr tag, it looks at any color attribute
# to see that it has an appropriate value.
#
#***********************************************************************
sub HR_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    my ($used_for_decoration);

    #
    # Does this HR appear to be used for decoration only ?
    # Was the last tag an <hr> tag also ?
    #
    if ( $last_tag eq "hr" ) {
        $used_for_decoration = 1;
    }
    #
    # Was the last tag a heading ?
    #
    elsif ( $last_tag =~ /^h\d$/ ) {
        $used_for_decoration = 1;
    }
    else {
        #
        # Does not appear to be used for decoration
        #
        $used_for_decoration = 0;
    }

    #
    # Did we find the <hr> tag being used for decoration ?
    #
    if ( $used_for_decoration ) {
        Record_Result("WCAG_2.0-F43", $line, $column, $text,
                      "<$last_tag>" . String_Value("followed by") . "<hr> " .
                      String_Value("used for decoration"));
    }
}

#***********************************************************************
#
# Name: Blink_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the blink tag.
#
#***********************************************************************
sub Blink_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    #
    # Have blinking that the user cannot control.
    #
    Record_Result("WCAG_2.0-F47", $line, $column, $text,
                  String_Value("Blinking text in") . "<blink>");
}

#***********************************************************************
#
# Name: Check_Label_Id_and_Title
#
# Parameters: self - reference to object
#             tag - HTML tag name
#             label_required - flag to indicate if label is required
#               before this tag.
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks for the presence of a title attribute (with
# content other than an empty string).  If this is not found, it checks
# for an id attribute and a corresponding label.
#
#***********************************************************************
sub Check_Label_Id_and_Title {
    my ( $self, $tag, $label_required, $line, $column, $text, %attr ) = @_;

    my ($id, $title, $label, $last_seen_text, $complete_title);
    my ($found_label) = 0;

    #
    # Get possible id attribute and corresponding label
    #
    print "Check_Label_Id_and_Title for $tag, label_required = $label_required\n" if $debug;
    if ( defined($attr{"id"}) ) {
        $id = $attr{"id"};
        $id =~ s/^\s*//g;
        $id =~ s/\s*$//g;
        print "Have id = \"$id\"\n" if $debug;

        #
        # See if we have a label (we may not have one if it comes
        # after this input).
        #
        if ( defined($label_for_location{$id}) ) {
            $label = $label_for_location{$id};
            $found_label = 1;
            print "Have label = \"$label\"\n" if $debug;
        }
    }

    #
    # Get possible title attribute
    #
    if ( defined($attr{"title"}) ) {
        $title = $attr{"title"};
        $title =~ s/^\s*//g;
        $title =~ s/\s*$//g;
        print "Have title = \"$title\"\n" if $debug;

        #
        # Did we have an id value ?
        #
        if ( defined($id) ) {
            #
            # Is the Title the same as the id ?
            #
            if ( lc($title) eq lc($id) ) {
                Record_Result("WCAG_2.0-H65", $line, $column, $text,
                              String_Value("Title same as id for") . $tag);
            }
        }
    }

    #
    # Check for the use of technique H65, using a title attribute
    # to identify form controls where the label element cannot
    # be used.
    #
    if ( (! $found_label) && defined($title) ) {
        #
        # Do we have a title value ?
        #
        if ( $title eq "" ) {
            #
            # Missing title value
            #
            Record_Result("WCAG_2.0-H65", $line, $column, $text,
                          String_Value("Missing title content for") . $tag);
        }
        else {
            #
            # Title acts as a label
            #
            print "Found 'title' to act as a label\n" if $debug;
            $found_label = 1;

            #
            # If we are inside a <table> include the table location in the
            # <label> to make it unique to the table.  The same <label> may
            # appear in seperate <table>s in the same <form>
            #
            $complete_title = $title;
            if ( $table_nesting_index > -1 ) {
                $complete_title .= " table " .
                                   $table_start_line[$table_nesting_index] .
                                   $table_start_column[$table_nesting_index];
            }

            #
            # Have we seen this title before ?
            #
            if ( defined($form_title_value{lc($complete_title)}) ) {
                Record_Result("WCAG_2.0-H65", $line, $column,
                              $text, String_Value("Duplicate") .
                              " title \"$title\" " .
                              String_Value("for") . $tag .
                              String_Value("Previous instance found at") .
                              $form_title_value{lc($complete_title)});
            }
            else {
                #
                # Save title location
                #
                $form_title_value{lc($complete_title)} = "$line:$column"
            }
        }
    }

    #
    # Check for an id attribute that may be used to match a label tag.
    #
    if ( (! $found_label) && defined($id) ) {
        #
        # Do we have content for the id attribute ?
        #
        $found_label = 1;
        if ( $id eq "" ) {
            #
            # Missing id value
            #
            Record_Result("WCAG_2.0-H65", $line, $column, $text,
                          String_Value("Missing id content for") . $tag);
        }
        else {
            #
            # Do we have a label and are we expect one ?
            # If we are not expecting one (e.g. may follow this tag),
            # we will catch a missing label once we complete this document.
            #
            if ( (! defined($label)) && $label_required ) {
                #
                # If we are inside a fieldset, it (and it's legend) can
                # act as a label (WCAG 2.0 H71).
                #
                if ( $fieldset_tag_index > 0 ) {
                    #
                    # Inside a fieldset, the legend acts as a label.
                    # Do we have a title attribute and value for the input ?
                    #
                    print "Inside a fieldset, label is optional\n" if $debug;
                    if ( defined($title) && ($title eq "") ) {
                        Record_Result("WCAG_2.0-H65", $line, $column, $text,
                                   String_Value("Missing title content for") .
                                      $tag);
                    }
                    elsif ( ! defined($title) ) {
                        #
                        # Is this input inside a label and is the label not
                        # explicitly associated with the label ?
                        #
                        print "inside_label = $inside_label, last_tag = $last_tag, text_between_tags = \"$text_between_tags\"\n" if $debug;
                        if ( $inside_label ) {
                            Record_Result("WCAG_2.0-F68", $line, $column, $text,
                                          String_Value("Found tag") . $tag .
                                          String_Value("in") . "<label>");
                        }
                        #
                        # If the last tag was a <label>, check the last label
                        # for a "for" attribute.
                        #
                        elsif ( ($last_tag eq "label")  &&
                                (! defined($last_label_attributes{"for"})) ) {
                            Record_Result("WCAG_2.0-F68", $line, $column, $text,
                                   String_Value("Previous label not explicitly associated to") .
                                          $tag);
                        }
                        #
                        # No title attribute to act as label
                        #
                        else {
                            Record_Result("WCAG_2.0-H65", $line, $column, $text,
                                   String_Value("Missing title attribute for") .
                                          $tag);
                        }
                    }
                }
                else {
                    #
                    # Missing label and no fieldset
                    #
                    Record_Result("WCAG_2.0-F68", $line, $column,
                                  $text,
                                  String_Value("Missing label before") . $tag);
                }
            }
        }
    }

    #
    # Check for no id attribute, we may have an implicit label
    #
    if ( ! defined($id) ) {
        #
        # Is this input inside a label and is the label not
        # explicitly associated with the label ?
        #
        print "inside_label = $inside_label, last_tag = $last_tag, text_between_tags = \"$text_between_tags\"\n" if $debug;
        if ( $inside_label ) {
            $found_label = 1;
            Record_Result("WCAG_2.0-F68", $line, $column, $text,
                          String_Value("Found tag") . $tag .
                          String_Value("in") . "<label>");
        }
        #
        # If the last tag was a <label>, check the last label for a "for" attribute.
        #
        elsif ( ($last_tag eq "label")  &&
                (! defined($last_label_attributes{"for"})) ) {
            $found_label = 1;
            Record_Result("WCAG_2.0-F68", $line, $column, $text,
                   String_Value("Previous label not explicitly associated to") .
                          $tag);
        }
    }

    #
    # Check for no id attribute, we may have an implicit label
    #
    if ( (! $found_label) && ( ! defined($id)) ) {
        #
        # See if there is any text handler active, we may have text preceeding
        # this input.
        #
        if ( $have_text_handler ) {
            $last_seen_text = Get_Text_Handler_Content($self, "");
        }

        #
        # Is there some text preceeding this input that may be
        # acting as a label
        #
        if ( defined($last_seen_text) && ($last_seen_text ne "") ) {
            $found_label = 1;
            Record_Result("WCAG_2.0-F68", $line, $column, $text,
                          String_Value("Text") . " \"$last_seen_text\" " .
                          String_Value("not marked up as a <label>"));
        }
    }

    #
    # Catch all case, no id and no title, so we don't have an
    # explicit label association.
    #
    if ( ! $found_label )  {
        Record_Result("WCAG_2.0-F68", $line, $column, $text,
                      String_Value("Label not explicitly associated to") .
                      $tag);
    }
}

#***********************************************************************
#
# Name: Hidden_Input_Tag_Handler
#
# Parameters: self - reference to object
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the input tag which are marked as 'hidden'.
#
#***********************************************************************
sub Hidden_Input_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($input_type, $id, $input_tag_type, $label);

    #
    # Check the type attribute
    #
    print "Hidden_Input_Tag_Handler\n" if $debug;
    if ( defined( $attr{"type"} ) ) {
        $input_type = lc($attr{"type"});
        print "Input type = $input_type\n" if $debug;
    }
    else {
        #
        # No type field, assume it defaults to type text
        #
        $input_type = "text";
        print "No input type specified, assuming text\n" if $debug;
    }
    $input_tag_type = "<input type=\"$input_type\">";

    #
    # Check to see if there is an id attribute that may be associated
    # with a label.
    #
    if ( (defined($attr{"id"}) && ($attr{"id"} ne "") ) ) {
        $id = $attr{"id"};
        $id =~ s/^\s*//g;
        $id =~ s/\s*$//g;
        print "Have id = \"$id\"\n" if $debug;

        #
        # See if we have a label (we may not have one if it comes
        # after this input).
        #
        if ( defined($label_for_location{$id}) ) {
            $label = $label_for_location{$id};
            print "Have label = \"$label\"\n" if $debug;
            Record_Result("WCAG_2.0-H44", $line, $column,
                          $text, String_Value("Label found for hidden input"));
        }
    }
}

#***********************************************************************
#
# Name: Input_Tag_Handler
#
# Parameters: self - reference to object
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the input tag, it looks for an id attribute
# for any input that appears to be used for getting information.
#
#***********************************************************************
sub Input_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($input_type, $id, $value, $input_tag_type);
    my ($found_label) = 0;

    #
    # Is this a read only or disabled input ?
    #
    if ( defined($attr{"readonly"}) || defined($attr{"disabled"}) ) {
        print "Readonly or disabled input\n" if $debug;
        return;
    }
    #
    # Is this a hidden input ?
    #
    elsif ( (defined($attr{"type"}) && ($attr{"type"} eq "hidden") ) ) {
        Hidden_Input_Tag_Handler($self, $line, $column, $text, %attr);
        return;
    }

    #
    # Increment the number of writable inputs.
    #
    $number_of_writable_inputs++;

    #
    # Check the type attribute
    #
    if ( defined( $attr{"type"} ) ) {
        $input_type = lc($attr{"type"});
        print "Input type = $input_type\n" if $debug;
    }
    else {
        #
        # No type field, assume it defaults to type text
        #
        $input_type = "text";
        print "No input type specified, assuming text\n" if $debug;
    }
    $input_tag_type = "<input type=\"$input_type\">";

    #
    # Is an image use for this input ? If so it must include alt text.
    #
    if ( $input_type eq "image" ) {
        #
        # Check alt attributes ?
        #
        Check_For_Alt_Attribute("WCAG_2.0-F65", $input_tag_type, $line,
                                $column, $text, %attr);

        #
        # Check for alt text content
        #
        Check_Alt_Content("WCAG_2.0-H36", $input_tag_type, $self, $line,
                          $column, $text, %attr);

        #
        # Do we have alt text or title ?
        #
        if ( (defined($attr{"alt"}) && $attr{"alt"} ne "") ||
             (defined($attr{"title"}) && $attr{"title"} ne "") ) {
            #
            # Have either alt text or a title
            #
            print "Image has alt or title\n" if $debug;
        }
        else {
            Record_Result("WCAG_2.0-H91", $line, $column, $text,
                          String_Value("Missing alt or title in") .
                          "$input_tag_type");
        }
    }
    #
    # Check to see if the input type should have a label associated
    # with it.
    #
    elsif ( index($input_types_requiring_label, " $input_type ") != -1 ) {
        #
        # Check for one of a title or label
        #
        if ( index($input_types_requiring_label_before,
                   " $input_type ") != -1 ) {
            #
            # Should expect a label for this input before input.
            #
            Check_Label_Id_and_Title($self, $input_tag_type, 1, $line,
                                     $column, $text, %attr);
        }
        else {
            #
            # Label may appear after this input.  Label check will happen
            # at the end of the document.
            #
            Check_Label_Id_and_Title($self, $input_tag_type, 0, $line, $column,
                                     $text, %attr);
        }
    }

    #
    # Check buttons for a value attribute
    #
    elsif ( index($input_types_requiring_value, " $input_type ") != -1 ) {
        #
        # Do we have a value attribute
        #
        if ( ! defined($attr{"value"}) ) {
            Record_Result("WCAG_2.0-H91", $line, $column, $text,
                          String_Value("Missing value attribute in") .
                          "$input_tag_type");
        }
        else {
            #
            # Do we have non-whitespace value ?
            #
            $value = $attr{"value"};
            $value =~ s/\s//g;
            if ( $value eq "" ) {
                Record_Result("WCAG_2.0-H91", $line, $column, $text,
                              String_Value("Missing value in") .
                              "$input_tag_type");
            }
        }
    }

    #
    # Do we have an id attribute that matches a label for inputs that
    # must not have labels ?
    #
    if ( (defined($attr{"id"})) &&
         (index($input_types_not_using_label, " $input_type ") != -1) ) {
        $id = $attr{"id"};
        if ( defined($label_for_location{"$id"}) ) {
            #
            # Label must not be used for this input type
            #
            Record_Result("WCAG_2.0-H44", $line, $column,
                          $text, String_Value("Found label for") .
                          "$input_tag_type");
        }
    }

    #
    # Save the location of this input id
    #
    if ( defined($attr{"id"}) ) {
        #
        # We ignore id on input types that do not use labels
        #
        if ( index($input_types_not_using_label, " $input_type ") == -1 ) {
            #
            # We ignore id on inputs that are contained within a fieldset
            # (WCAG 2.0 H71).
            #
            if ( $fieldset_tag_index == 0 ) {
                $id = $attr{"id"};
                $id =~ s/^\s*//g;
                $id =~ s/\s*$//g;
                $input_id_location{"$id"} = "$line,$column";
            }

            #
            # Do we have a label that matches this id ?
            #
            if ( defined($label_for_location{"$id"}) ) {
                $found_label = 1;
            }
        }
    }

    #
    # Is this a button ? if so set flag to indicate there is one in the
    # form.
    #
    if ( ($input_type eq "image") ||
         ($input_type eq "submit")  ) {
        if ( $in_form_tag ) {
            print "Found image or submit in form\n" if $debug;
            $found_input_button = 1;
        }
        else {
            print "Found image or submit outside of form\n" if $debug;
        }

        #
        # Do we have a value ? if so add it to the text handler
        # so we can check it's value when we get to the end of the block tag.
        #
        if ( $have_text_handler && 
             defined($attr{"value"}) && ($attr{"value"} ne "") ) {
            push(@{ $self->handler("text")}, $attr{"value"});
        }
    }

    #
    # Check for accesskey attribute
    #
    Check_Accesskey_Attribute($input_tag_type, $line, $column, $text, %attr);

    #
    # Check to see if this is a radio button or check box
    #
    if ( ($input_type eq "checkbox") ||
         ($input_type eq "radio")  ) {
        #
        # If the name attribute of this input is the same as the last
        # one, we expect them to be part of a fieldset.
        #
        if ( defined($attr{"name"}) && ($attr{"name"} ne "") ) {
            if ( $last_radio_checkbox_name eq "" ) {
                #
                # First checkbox or radio button in the list ?
                #
                $last_radio_checkbox_name = $attr{"name"};
                print "First $input_type of a potential list, name = $last_radio_checkbox_name\n" if $debug;
            }
            #
            # Is the name value the same as the last one ?
            #
            elsif ( $attr{"name"} eq $last_radio_checkbox_name ) {
                #
                # Are we inside a fieldset and we don't have an
                # explicit label ? 
                #
                print "Next $input_type of a list, name = " . $attr{"name"} .
                      " last input name = $last_radio_checkbox_name\n" if $debug;
                if ( ($fieldset_tag_index == 0) && ( ! $found_label) ) {
                    #
                    # No fieldset for these inputs
                    #
                    Record_Result("WCAG_2.0-H71", $line, $column, $text,
                                  String_Value("Missing fieldset"));
                    Record_Result("WCAG_2.0-F68", $line, $column, $text,
                                  String_Value("No label for") . "<input>");
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Select_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the select tag, it looks for an id attribute
# or a title.
#
#***********************************************************************
sub Select_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($id);

    #
    # Is this a read only or hidden input ?
    #
    if ( defined($attr{"readonly"}) ||
         defined($attr{"disabled"}) ||
         (defined($attr{"type"}) && ($attr{"type"} eq "hidden") ) ) {
        print "Hidden or readonly select\n" if $debug;
        return;
    }
  
    #
    # Increment the number of writable inputs.
    #
    $number_of_writable_inputs++;

    #
    # Check for one of a title or a label
    #
    Check_Label_Id_and_Title($self, "<select>", 1, $line, $column, $text,
                             %attr);

    #
    # Save the location of this select id if we are not inside a <fieldset>.
    # The <fieldset> and <legend> will act as a label.
    #
    if ( ($fieldset_tag_index == 0) && defined($attr{"id"}) ) {
        $id = $attr{"id"};
        $id =~ s/^\s*//g;
        $id =~ s/\s*$//g;
        $input_id_location{"$id"} = "$line,$column";
    }
}

#***********************************************************************
#
# Name: Check_Accesskey_Attribute
#
# Parameters: tag - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks for an accesskey attribute.
#
#***********************************************************************
sub Check_Accesskey_Attribute {
    my ( $tag, $line, $column, $text, %attr ) = @_;

    my ($accesskey);

    #
    # Do we have an accesskey attribute ?
    #
    if ( defined($attr{"accesskey"}) ) {
        $accesskey = $attr{"accesskey"};
        $accesskey =~ s/^\s*//g;
        $accesskey =~ s/\s*$//g;
        print "Accesskey attribute = \"$accesskey\"\n" if $debug;

        #
        # Check length of accesskey, it must be a single character.
        #
        if ( length($accesskey) == 1 ) {
            #
            # Have we seen this label id before ?
            #
            if ( defined($accesskey_location{"$accesskey"}) ) {
                Record_Result("WCAG_2.0-F17", $line, $column,
                              $text, String_Value("Duplicate accesskey") .
                              "'$accesskey'" .  " " .
                              String_Value("Previous instance found at") .
                              $accesskey_location{$accesskey});
            }

            #
            # Save label location
            #
            $accesskey_location{"$accesskey"} = "$line:$column";
        }
        else {
             #
             # Invalid accesskey value.  The validator does not always
             # report this so we will.
             #
             Record_Result("WCAG_2.0-F17", $line, $column,
                           $text, String_Value("Invalid content for") .
                           "'accesskey'");
        }
    }
}

#***********************************************************************
#
# Name: Label_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the label tag, it saves the id of the
# label in a global hash table.
#
#***********************************************************************
sub Label_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($label_for);

    #
    # We are inside a label
    #
    $inside_label = 1;
    %last_label_attributes = %attr;

    #
    # Check for "for" attribute
    #
    if ( defined( $attr{"for"} ) ) {
        $label_for = $attr{"for"};
        $label_for =~ s/^\s*//g;
        $label_for =~ s/\s*$//g;
        print "Label for attribute = \"$label_for\"\n" if $debug;

        #
        # Check for missing value, we don't have to report it here
        # as the validator will catch it.
        #
        if ( $label_for ne "" ) {
            #
            # Have we seen this label id before ?
            #
            if ( defined($label_for_location{"$label_for"}) ) {
                Record_Result("WCAG_2.0-F17", $line, $column,
                              $text, String_Value("Duplicate label id") .
                              "'$label_for'" .  " " .
                              String_Value("Previous instance found at") .
                              $label_for_location{$label_for});
            }

            #
            # Save label location
            #
            $label_for_location{"$label_for"} = "$line:$column";
        }
    }

    #
    # Check for accesskey attribute
    #
    Check_Accesskey_Attribute("label", $line, $column, $text, %attr);

    #
    # Add a text handler to save the text portion of the label
    # tag.
    #
    Start_Text_Handler($self, "label");
}

#***********************************************************************
#
# Name: End_Label_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end label tag.
#
#***********************************************************************
sub End_Label_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($this_text, $last_line, $last_column, $clean_text);
    my ($complete_label);

    #
    # Get all the text found within the label tag
    #
    if ( ! $have_text_handler ) {
        print "End label tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the label text as a string, remove excess white space
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
    print "End_Label_Tag_Handler: text = \"$clean_text\"\n" if $debug;
    
    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<label>", $line, $column, $clean_text);

    #
    # Are we missing label text ?
    #
    if ( $clean_text eq "" ) {
        Record_Result("WCAG_2.0-H44", $line, $column,
                      $text, String_Value("Missing text in") . "<label>");
        Record_Result("WCAG_2.0-G131", $line, $column,
                      $text, String_Value("Missing text in") . "<label>");
    }
    else {
        #
        # If we are inside a <fieldset> prefix the <label> with
        # any <legend> text.  JAWS reads both the <legend> and 
        # <label> for the user. This allows for the same <label>
        # to appear in separate <fieldset>s.
        #
        if ( $fieldset_tag_index > 0 ) {
            $complete_label = $legend_text_value{$fieldset_tag_index} .
                                $clean_text;
        }
        else {
            $complete_label = $clean_text;
        }

        #
        # If we are inside a <table> include the table location in the
        # <label> to make it unique to the table.  The same <label> may
        # appear in seperate <table>s in the same <form>
        #
        if ( $table_nesting_index > -1 ) {
            print "Add table location to label value\n" if $debug;
            $complete_label .= " table " .
                               $table_start_line[$table_nesting_index] .
                               $table_start_column[$table_nesting_index];
        }

        #
        # Have we seen this label before ?
        #
        if ( defined($form_label_value{lc($complete_label)}) ) {
            Record_Result("WCAG_2.0-H44", $line, $column,
                          $text, String_Value("Duplicate") .
                          " <label> \"$clean_text\" " .
                          String_Value("Previous instance found at") .
                          $form_label_value{lc($complete_label)});
        }
        else {
            #
            # Save label location
            #
            $form_label_value{lc($complete_label)} = "$line:$column"
        }
    }

    #
    # Destroy the text handler that was used to save the text
    # portion of the label tag.
    #
    Destroy_Text_Handler($self, "label");

    #
    # We are no longer inside a label
    #
    $inside_label = 0;
}

#***********************************************************************
#
# Name: Textarea_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the textarea tag.
#
#***********************************************************************
sub Textarea_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($id_value);

    #
    # Is this a read only or hidden input ?
    #
    print "Textarea_Tag_Handler\n" if $debug;
    if ( defined($attr{"readonly"}) ||
         defined($attr{"disabled"}) ||
         (defined($attr{"type"}) && ($attr{"type"} eq "hidden") ) ) {
        print "Hidden or readonly textarea\n" if $debug;
        return;
    }
  
    #
    # Increment the number of writable inputs.
    #
    $number_of_writable_inputs++;

    #
    # Check to see if the textarea has a label or title
    #
    Check_Label_Id_and_Title($self, "<textarea>", 0, $line, $column, $text,
                             %attr);

    #
    # Check for accesskey attribute
    #
    Check_Accesskey_Attribute("<textarea>", $line, $column, $text, %attr);
}

#***********************************************************************
#
# Name: Marquee_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the marquee tag.
#
#***********************************************************************
sub Marquee_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    #
    # Found marquee tag which generates moving text.
    #
    Record_Result("WCAG_2.0-F16", $line, $column,
                  $text, String_Value("Found tag") . "<marquee>");
}


#***********************************************************************
#
# Name: Fieldset_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the field set tag.
#
#***********************************************************************
sub Fieldset_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    #
    # Set counter to indicate we are within a <fieldset> .. </fieldset>
    # tag pair and that we have not seen a <legend> yet.
    #
    $fieldset_tag_index++;
    $found_legend_tag{$fieldset_tag_index} = 0;
    $legend_text_value{$fieldset_tag_index} = "";
}

#***********************************************************************
#
# Name: Legend_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the legend tag.
#
#***********************************************************************
sub Legend_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Set flag to indicate we have seen a <legend> tag.
    #
    if ( $fieldset_tag_index > 0 ) {
        $found_legend_tag{$fieldset_tag_index} = 1;
        $legend_text_value{$fieldset_tag_index} = "";
    }

    #
    # Check for accesskey attribute
    #
    Check_Accesskey_Attribute("legend", $line, $column, $text, %attr);

    #
    # Add a text handler to save the text portion of the legend
    # tag.
    #
    Start_Text_Handler($self, "legend");
}

#***********************************************************************
#
# Name: End_Legend_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end legend tag.
#
#***********************************************************************
sub End_Legend_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($this_text, $last_line, $last_column, $clean_text);

    #
    # Get all the text found within the legend tag
    #
    if ( ! $have_text_handler ) {
        print "End legend tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the legend text as a string, remove excess white space
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
    print "End_Legend_Tag_Handler: text = \"$clean_text\"\n" if $debug;

    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<legend>", $line, $column, $clean_text);

    #
    # Are we missing legend text ?
    #
    if ( $clean_text eq "" ) {
        Record_Result("WCAG_2.0-H71", $line, $column,
                      $text, String_Value("Missing text in") . "<legend>");
        Record_Result("WCAG_2.0-G131", $line, $column,
                      $text, String_Value("Missing text in") . "<legend>");
    }
    #
    # Have we seen this legend before ?
    #
    else {
        #
        # Save legend text
        #
        if ( $fieldset_tag_index > 0 ) {
            $legend_text_value{$fieldset_tag_index} = $clean_text;
        }

        #
        # Have we seen this legend before in this for ?
        #
        if ( defined($form_legend_value{lc($clean_text)}) ) {
            Record_Result("WCAG_2.0-H71", $line, $column,
                          $text, String_Value("Duplicate") .
                          " <legend> \"$clean_text\" " .
                          String_Value("Previous instance found at") .
                          $form_legend_value{lc($clean_text)});
        }
        else {
            #
            # Save legend location
            #
            $form_legend_value{lc($clean_text)} = "$line:$column"
        }
    }

    #
    # Destroy the text handler that was used to save the text
    # portion of the legend tag.
    #
    Destroy_Text_Handler($self, "legend");
}

#***********************************************************************
#
# Name: P_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the p tag.
#
#***********************************************************************
sub P_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Add a text handler to save the text portion of the p
    # tag.
    #
    Start_Text_Handler($self, "p");
}

#***********************************************************************
#
# Name: End_P_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end p tag.
#
#***********************************************************************
sub End_P_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($this_text, $clean_text);

    #
    # Get all the text found within the p tag
    #
    if ( ! $have_text_handler ) {
        #
        # If we don't have a text handler, it was hijacked by some other
        # tag (e.g. anchor tag).  We only care about simple paragraphs
        # so if there is no handler, we ignore this paragraph.
        #
        print "End p tag found no text handler at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the p text as a string
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, " "));

    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<p>", $line, $column, $clean_text);

    #
    # Was there a pseudo-header ? Is it the entire contents of the 
    # paragraph ? (not just emphasised text inside the paragraph)
    #
    if ( ($pseudo_header ne "") &&
         ($pseudo_header eq $clean_text) ) {
        print "Possible pseudo-header paragraph \"$clean_text\" at $line:$column\n" if $debug;
        Record_Result("WCAG_2.0-F2", $line, $column, $text,
                      String_Value("Text styled to appear like a heading") .
                      " \"$pseudo_header\"");
    }
    else {
        #
        # Have no pseudo-header
        #
        $pseudo_header = ""
    }

    #
    # Destroy the text handler that was used to save the text
    # portion of the p tag.
    #
    Destroy_Text_Handler($self, "p");
}

#***********************************************************************
#
# Name: Emphasis_Tag_Handler
#
# Parameters: self - reference to this parser
#             tag - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles tags that convey emphasis (e.g. strong, em, b, i).
# 
# It checks to see if the last open tag is a paragraph tag, a div tag, or
# we are already within an emphasis block.
#
#***********************************************************************
sub Emphasis_Tag_Handler {
    my ( $self, $tag, $line, $column, $text, %attr ) = @_;

    #
    # Was the last open tag a paragraph, div or are we already inside an
    # emphasis block ?
    #
    if ( ($last_open_tag eq "p") || 
         ($emphasis_count > 0) ) {
        #
        # Increment emphasis level count
        #
        $emphasis_count++;

        #
        # Add a text handler to save the text portion of this tag
        #
        Start_Text_Handler($self, $tag);
    }
}

#***********************************************************************
#
# Name: End_Emphasis_Tag_Handler
#
# Parameters: self - reference to this parser
#             tag - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles end tags that convey emphasis (e.g. strong, em,
#  b, i).
#
#***********************************************************************
sub End_Emphasis_Tag_Handler {
    my ( $self, $tag, $line, $column, $text ) = @_;

    my ($this_text, $last_line, $last_column, $clean_text);

    #
    # Get all the text found within the tag
    #
    if ( ! $have_text_handler ) {
        #
        # No text handler, this emphasis tag may not have been within a
        # paragraph, so it can be ignored.
        #
        print "Ignore end emphasis tag $tag\n" if $debug;
        return;
    }

    #
    # Get the tag text as a string, remove all white space and convert
    # to lowercase
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, " "));
    print "End_Emphasis_Tag_Handler: text = \"$clean_text\"\n" if $debug;

    $pseudo_header = "";
    #
    # Are we missing text ?
    #
    if ( $clean_text eq "" ) {
        Record_Result("WCAG_2.0-G115", $line, $column,
                      $text, String_Value("Missing text in") . "<$tag>");
    }
    #
    # If this emphasis is inside a block tag such as <caption>, it
    # is ignored as it is not a heading.  Also ignore it if it is
    # a table header (<th>, <td>).
    #
    elsif ( Have_Text_Handler_For_Tag("caption") ||
            Have_Text_Handler_For_Tag("summary") ||
            Have_Text_Handler_For_Tag("td") ||
            Have_Text_Handler_For_Tag("th")    ) {
        print "Ignore possible pseudo-heading inside block tag\n" if $debug;
    }
    #
    # Does the text end with a period ? This suggests it is a sentence
    # rather than a heading.  Wont ignore other punctuation such as
    # a question mark as they can appear in FAQ type of headings.
    #
    elsif ( $clean_text =~ /\.$/ ) {
        print "Ignore possible pseudo-heading that end with a period\n" if $debug;
    }
    #
    # Do we have an anchor inside the emphasis block ?
    # Ignore this text as the anchor may be bolded.
    #
    elsif ( $anchor_inside_emphasis ) {
        print "Ignore possible pseudo-heading that contains an anchor\n" if $debug;
    }
    #
    # Check the length of the text, if it is below a certain threshold
    # it may be acting as a pseudo-header
    #
    elsif ( length($clean_text) < $pseudo_header_length ) {
        #
        # Possible pseudo-header
        #
        $pseudo_header = $clean_text;
        print "Possible pseudo-header \"$clean_text\" at $line:$column\n" if $debug;
    }

    #
    # Destroy the text handler that was used to save the text
    # portion of the tag.
    #
    Destroy_Text_Handler($self, $tag);

    #
    # Decrement the emphasis tag level
    #
    $emphasis_count--;

    #
    # If we are outside any emphasis block, reset the "anchor in emphasis"
    # flag.
    #
    if ( $emphasis_count <= 0 ) {
        $anchor_inside_emphasis = 0;
        $emphasis_count = 0;
    }
}

#***********************************************************************
#
# Name: Check_Headers_Attribute
#
# Parameters: tag - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks for a headers attribute for the specified tag.
# It checks to see if all the headers of the headers are referenced
# (e.g. is this tag references header id=h1, this tag should also
# reference all headers of the tag that defines id=h1).  
#
# From: http://www.w3.org/TR/html5/tabular-data.html#attr-tdth-headers
# A th element with ID id is said to be directly targeted by all td 
# and th elements in the same table that have headers attributes whose 
# values include as one of their tokens the ID id. A th element A is 
# said to be targeted by a th or td element B if either A is directly 
# targeted by B or if there exists an element C that is itself targeted 
# by the element B and A is directly targeted by C.
#
# It returns a complete list of headers that should be referenced.  
# If a referenced header is not defined (e.g. defined later in the 
# HTML stream), the reference is saved for later checking.
#
#***********************************************************************
sub Check_Headers_Attribute {
    my ( $tag, $line, $column, $text, %attr ) = @_;

    my ($header_values, $id, $headers, $table_ref, $list_ref);
    my ($complete_headers, %headers_set, $p_headers, $p_id);
    my ($location_ref, %h43_reported, $types_ref);

    #
    # Do we have a headers attribute ?
    #
    if ( defined($attr{"headers"}) && ($attr{"headers"} ne "") ) {
        $headers = $attr{"headers"};
        $headers =~ s/^\s*//g;
        $headers =~ s/\s*$//g;

        #
        # Do a first pass through the list of headers to check
        # for duplicates.
        #
        foreach $id (split(/\s+/, $headers)) {
            #
            # Have we seen this id already in the list of headers ?
            #
            if ( defined($headers_set{$id}) ) {
                Record_Result("WCAG_2.0-H88", $line, $column, $text,
                              String_Value("Duplicate id in headers") .
                              " headers=\"$id\"");
            }
            else {
                #
                # Save id value
                #
                $headers_set{$id} = $id;
            }
        }

        #
        # Generate a complete list of specified header id values
        #
        $complete_headers = join(" ", keys(%headers_set));

        #
        # Second pass through the headers, check that the id values
        # reference headers within this table. Check that headers of
        # headers appear in this tag's headers list.
        #
        $header_values = $table_header_values[$table_nesting_index];
        $location_ref = $table_header_locations[$table_nesting_index];
        $types_ref = $table_header_types[$table_nesting_index];
        foreach $id (keys(%headers_set)) {
            #
            # Have we seen this id in a header ?
            #
            if ( defined($$header_values{$id}) ) {
                print "Check header id $id\n" if $debug;

                #
                # Is this id from a th tag ? Only th tag header ids are
                # targeted headers.
                #
                if ( $$types_ref{$id} eq "th") {
                    #
                    # Check to see if all the id values in the 'headers'
                    # attribute of this header also appear in this tags
                    # 'headers' attribute (i.e. header references must
                    # be explicit and not transitive).
                    #
                    $p_headers = $$header_values{$id};

                    #
                    # Check that each id in the parent header list is in
                    # this tag's list.
                    #
                    foreach $p_id (split(/\s+/, $p_headers)) {
                        #
                        # Report error if parent id is not in the set of
                        # headers (only report once per possible parent id)
                        #
                        print "Check parent header $p_id\n" if $debug;
                        if ( (! defined($headers_set{$p_id})) && 
                             (! defined($h43_reported{$p_id})) ) {
                            Record_Result("WCAG_2.0-H43", $line, $column, $text,
                                          String_Value("Missing") .
                                          " 'headers=\"$p_id\"' " .
                                          String_Value("found in header") .
                                          " 'id=\"$id\"'. " .
                                          String_Value("Header defined at") .
                                          " " . $$location_ref{$id});
                            $h43_reported{$p_id} = $p_id;
                        }

                        #
                        # Add this header to the list of complete headers
                        # for this tag.  This speeds up future checking
                        # as we don't have to iterate up the parent header
                        # chain.
                        #
                        if ( ! defined($headers_set{$p_id}) ) {
                            $headers_set{$p_id} = $p_id;
                        }
                    }
                }
                else {
                    print "Skip non <th> header\n" if $debug;
                }
            }
            else {
                #
                # Record this header reference as a potential error.
                # The header definition may appear later in the
                # table. Get the list of references to this id value.
                #
                $table_ref = $missing_table_headers[$table_nesting_index];
                if ( ! defined($$table_ref{$id}) ) {
                    my (@empty_list);
                    $$table_ref{$id} = \@empty_list;
                }
                $list_ref = $$table_ref{$id};

                #
                # Store the location and text of this reference.
                #
                push(@$list_ref, "$line:$column:$complete_headers:$text");
            }
        }

        #
        # Generate a complete list of specified and required headers
        #
        $complete_headers = join(" ", keys(%headers_set));
    }
    else {
        #
        # No headers
        #
        $complete_headers = "";
    }

    #
    # Return cmoplete list of headers
    #
    return($complete_headers);
}

#***********************************************************************
#
# Name: Delayed_Headers_Attribute_Check
#
# Parameters: id - header id
#
# Description:
#
#   This function performs delayed checks on  headers attributes for 
# headers that are defined after they are used.  It checks to see if all
# the references to this header include references to this header's
# headers  (e.g. is this tag references header id=h1, this tag should also
#
# reference all headers of the tag that defines id=h1).
# From: http://www.w3.org/TR/html5/tabular-data.html#attr-tdth-headers
# A th element with ID id is said to be directly targeted by all td 
# and th elements in the same table that have headers attributes whose 
# values include as one of their tokens the ID id. A th element A is 
# said to be targeted by a th or td element B if either A is directly 
# targeted by B or if there exists an element C that is itself targeted 
# by the element B and A is directly targeted by C.
#
#***********************************************************************
sub Delayed_Headers_Attribute_Check {
    my ($id) = @_;

    my ($header_values, $headers, $table_ref, $list_ref);
    my ($r_ref, $p_id, $location_ref, %h43_reported);
    my ($r_line, $r_column, $r_headers, $r_text, $types_ref);

    #
    # Get list of references to this header
    #
    $location_ref = $table_header_locations[$table_nesting_index];
    $header_values = $table_header_values[$table_nesting_index];
    $table_ref = $missing_table_headers[$table_nesting_index];
    $types_ref = $table_header_types[$table_nesting_index];
    $list_ref = $$table_ref{$id};

    #
    # Do we have any headers and is this a th header (not a td header) ?
    #
    $headers = $$header_values{$id};
    if ( ($headers ne "") && ($$types_ref{$id} eq "th") ) {
        #
        # Check each reference to this header to see if they include
        # all header reference we have.
        #
        foreach $r_ref (@$list_ref) {
            #
            # Get the details of the header reference
            #
            ($r_line, $r_column, $r_headers, $r_text) = split(/:/, $r_ref, 4);

            #
            # Check that each id in this headers list is in
            # this referenced tag's header list.
            #
            foreach $p_id (split(/\s+/, $headers)) {
                if ( index(" $r_headers ", " $p_id ") == -1 ) {
                    #
                    # Report error only report once per possible parent id.
                    #
                    if ( ! defined($h43_reported{$p_id}) ) {
                        Record_Result("WCAG_2.0-H43", $r_line, $r_column,
                                      $r_text,
                                      String_Value("Missing") .
                                      " 'headers=\"$p_id\"' " . 
                                      String_Value("found in header") .
                                      " 'id=\"$id\"'. " .
                                      String_Value("Header defined at") .
                                      " " . $$location_ref{$id});
                        $h43_reported{$p_id} = $p_id;
                    }
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: TH_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the th tag.
#
#***********************************************************************
sub TH_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($header_values, $id, $table_ref, $complete_headers, $h_id);
    my ($header_location, $header_type);

    #
    # If we are inside a table, set table headers present flag
    #
    if ( $table_nesting_index >= 0 ) {
        #
        # Table has headers.
        #
        $table_has_headers[$table_nesting_index] = 1;

        #
        # Check for a headers attribute to reference table headers
        #
        $complete_headers = Check_Headers_Attribute("th", $line, $column,
                                                    $text, %attr);

        #
        # Do we have an id attribute ?
        #
        if ( defined($attr{"id"}) && ($attr{"id"} ne "") ) {
            $id = $attr{"id"};

            #
            # Save id value in table headers
            #
            $header_values = $table_header_values[$table_nesting_index];
            $$header_values{$id} = $complete_headers;
            $header_location = $table_header_locations[$table_nesting_index];
            $$header_location{$id} = "$line:$column";
            $header_type = $table_header_types[$table_nesting_index];
            $$header_type{$id} = "th";

            #
            # Clear any possible table header references we have saved
            # as potential errors (reference preceeds definition).
            #
            $table_ref = $missing_table_headers[$table_nesting_index];
            if ( defined($$table_ref{$id}) ) {
                Delayed_Headers_Attribute_Check($id);
                delete $$table_ref{$id};
            }

            #
            # Check to see if this tag references it's own id in the
            # list of headers.
            #
            foreach $h_id (split(/\s+/, $complete_headers)) {
                if ( $h_id eq $id ) {
                    Record_Result("WCAG_2.0-H88", $line, $column, $text,
                                  String_Value("Self reference in headers") .
                                  " <th id=\"$id\" headers=\"$id\">");
                    last;
                }
            }
        }
    }
    else {
        #
        # Found <th> outside of a table.
        #
        Tag_Not_Allowed_Here("th", $line, $column, $text);
    }

    #
    # Add a text handler to save the text portion of the th
    # tag.
    #
    Start_Text_Handler($self, "th");
}

#***********************************************************************
#
# Name: End_TH_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end th tag.
#
#***********************************************************************
sub End_TH_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($clean_text);

    #
    # Get all the text found within the p tag
    #
    if ( ! $have_text_handler ) {
        print "End th tag found no text handler at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the th text as a string, remove excess white space
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
    print "End_TH_Tag_Handler: text = \"$clean_text\"\n" if $debug;

    #
    # Are we missing heading text ?
    #
    if ( $clean_text eq "" ) {
        Record_Result("WCAG_2.0-H51", $line, $column, $text,
                      String_Value("Missing text in table header") . "<th>");
    }

    #
    # Destroy the text handler that was used to save the text
    # portion of the legend tag.
    #
    Destroy_Text_Handler($self, "th");
}

#***********************************************************************
#
# Name: Thead_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the thead tag.
#
#***********************************************************************
sub Thead_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    #
    # If we are inside a table, set table headers present flag
    #
    if ( $table_nesting_index >= 0 ) {
        #
        # Table has headers.
        #
        $table_has_headers[$table_nesting_index] = 1;
        $inside_thead[$table_nesting_index] = 1;
    }
    else {
        #
        # Found <thead> outside of a table.
        #
        Tag_Not_Allowed_Here("thead", $line, $column, $text);
    }

}

#***********************************************************************
#
# Name: TD_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the td tag, it looks at any color attribute
# to see that it has an appropriate value.  It also looks for
# a headers attribute to ensure it is marked up properly.
#
#***********************************************************************
sub TD_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my (%local_attr, $header_values, $id, $headers, $table_ref, $list_ref);
    my ($complete_headers, $header_location, $header_type);

    #
    # Are we inside a table ?
    #
    if ( $table_nesting_index >= 0 ) {
        #
        # Save a copy of the <td> tag attributes
        #
        %local_attr = %attr;
        $td_attributes[$table_nesting_index] = \%local_attr;

        #
        # Check for a headers attribute to reference table headers
        #
        $complete_headers = Check_Headers_Attribute("td", $line, $column,
                                                    $text, %attr);

        #
        # Do we have an id attribute ?
        #
        if ( defined($attr{"id"}) && ($attr{"id"} ne "") ) {
            $id = $attr{"id"};

            #
            # Save id value in table headers
            #
            $header_values = $table_header_values[$table_nesting_index];
            $$header_values{$id} = $complete_headers;
            $header_location = $table_header_locations[$table_nesting_index];
            $$header_location{$id} = "$line:$column";
            $header_type = $table_header_types[$table_nesting_index];
            $$header_type{$id} = "td";

            #
            # Clear any possible table header references we have saved
            # as potential errors (reference preceeds definition).
            #
            $table_ref = $missing_table_headers[$table_nesting_index];
            if ( defined($$table_ref{$id}) ) {
                Delayed_Headers_Attribute_Check($id);
                delete $$table_ref{$id};
            }
        }
    }
    else {
        #
        # Found <td> outside of a table.
        #
        Tag_Not_Allowed_Here("td", $line, $column, $text);
    }

    #
    # Check headers attributes later once we get the end
    # <td> tag.  Depending on the content, we may not need
    # a header reference. We don't need a header if the cell
    # does not convey any meaningful information.
    #

    #
    # Add a text handler to save the text portion of the table cell.
    #
    Start_Text_Handler($self, "td");
}

#***********************************************************************
#
# Name: End_TD_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the end td tag, it looks for
# header attributes from the <td> tag to ensure it is marked up properly.
#
#***********************************************************************
sub End_TD_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($attr, $clean_text);

    #
    # Are we not inside a table ?
    #
    if ( $table_nesting_index <0 ) {
        print "End <td> found outside a table\n" if $debug;
        return;
    }

    #
    # Get saved copy of the <td> tag attributes
    #
    $attr = $td_attributes[$table_nesting_index];

    #
    # Get all the text found within the td tag
    #
    if ( ! $have_text_handler ) {
        print "End td tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
    print "Table cell content = \"$clean_text\"\n" if $debug;

    #
    # Look for a headers attribute to associate a table header
    # with this table cell.
    #
    if ( (! defined( $$attr{"headers"} )) &&
         (! defined( $$attr{"colspan"} )) ) {
        #
        # No table header or colspan attribute, do we have
        # an axis attribute ?
        #   TD cells that set the axis attribute are also treated
        #   as header cells.
        #
        if ( ( ! $table_has_headers[$table_nesting_index] ) &&
             ( ! defined( $$attr{"axis"}) ) ) {
            #
            # No headers and no axis attribute, check to see if the
            # cell contains text (if not is has no meaningful information
            # and does not need a header reference).
            #
            if ( ($clean_text ne "") || ($inside_thead[$table_nesting_index]) ) {
                Record_Result("WCAG_2.0-H43", $line, $column, $text,
                              String_Value("No table header reference"));
            }
        }
        #
        # Does this td have a scope=row or scope=col attribute ?
        # If so then this td provides header information for the row/col
        #
        elsif ( defined($$attr{"scope"}) &&
                (($$attr{"scope"} eq "row") || ($$attr{"scope"} eq "col")) ) {
            #
            # Do we have table cell text ?
            #
            if ( $clean_text eq "" ) {
                Record_Result("WCAG_2.0-H51", $line, $column, $text,
                              String_Value("Missing text in table header") . 
                              "<td scope=\"" . $$attr{"scope"} . "\">");
            }
        }
    }

    #
    # Destroy the text handler that was used to save the text
    # portion of the td tag.
    #
    Destroy_Text_Handler($self, "td");
}

#***********************************************************************
#
# Name: Area_Tag_Handler
#
# Parameters: self - reference to this parser
#             language - url language
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the area tag, it looks at alt text.
#
#***********************************************************************
sub Area_Tag_Handler {
    my ( $self, $language, $line, $column, $text, %attr ) = @_;

    #
    # Check for rel attribute of the tag
    #
    Check_Rel_Attribute("area", $line, $column, $text, 0, %attr);

    #
    # Check alt attribute
    #
    Check_For_Alt_Attribute("WCAG_2.0-F65", "<area>", $line, $column, $text, %attr);

    #
    # Check for alt text content
    #
    Check_Alt_Content("WCAG_2.0-H24", "<area>", $self, $line, $column, $text, %attr);

    #
    # Check for accesskey attribute
    #
    Check_Accesskey_Attribute("<area>", $line, $column, $text, %attr);
}

#***********************************************************************
#
# Name: Check_Longdesc_Attribute
#
# Parameters: tcid - testcase id
#             tag - name of HTML tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks the value of the longdesc attribute.
#
#***********************************************************************
sub Check_Longdesc_Attribute {
    my ( $tcid, $tag, $line, $column, $text, %attr ) = @_;

    my ($longdesc, $href, $resp_url, $resp);

    #
    # Look for longdesc attribute
    #
    if ( defined($attr{"longdesc"}) ) {
        #
        # Check value, this should be a URI
        #
        $longdesc = $attr{"longdesc"};
        print "Check_Longdesc_Attribute, longdesc = $longdesc\n" if $debug;

        #
        # Do we have a value ?
        #
        $longdesc =~ s/^\s*//g;
        $longdesc =~ s/\s*$//g;
        if ( $longdesc eq "" ) {
            #
            # Missing longdesc value
            #
            Record_Result($tcid, $line, $column, $text,
                          String_Value("Missing longdesc content for") .
                          "$tag");
        }
        else {
            #
            # Convert possible relative url into an absolute one based
            # on the URL of the current document.  If we don't have
            # a current URL, then HTML_Check was called with just a block
            # of HTML text rather than the result of a GET.
            #
            if ( $current_url ne "" ) {
                $href = url($longdesc)->abs($current_url);
                print "longdesc url = $href\n" if $debug;

                #
                # Get long description URL
                #
                ($resp_url, $resp) = Crawler_Get_HTTP_Response($href,
                                                               $current_url);

                #
                # Is this a valid URI ?
                #
                if ( ! defined($resp) ) {
                    Record_Result($tcid, $line, $column, $text,
                                  String_Value("Invalid URL in longdesc for") .
                                  "$tag");
                }
                #
                # Is it a broken link ?
                #
                elsif ( ! $resp->is_success ) {
                    Record_Result($tcid, $line, $column, $text,
                                  String_Value("Broken link in longdesc for") .
                                  "$tag");
                }
            }
            else {
                #
                # Skip check of URL, if it is relative we cannot
                # make it absolute.
                #
                print "No current URL, cannot make longdesc an absolute URL\n" if $debug;
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Flickering_Image
#
# Parameters: tag - name of tag
#             href - URL of image file
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks to see if animated images flicker for
# too long.
#
#***********************************************************************
sub Check_Flickering_Image {
    my ($tag, $href, $line, $column, $text, %attr) = @_;

    my ($resp, %image_details);

    #
    # Convert possible relative URL into a absolute URL
    # for the image.
    #
    print "Check_Flickering_Image in $tag, href = $href\n" if $debug;
    $href = url($href)->abs($current_url);

    #
    # Get image details
    #
    %image_details = Image_Details($href);

    #
    # Is this a GIF image ?
    #
    if ( defined($image_details{"file_media_type"}) &&
         $image_details{"file_media_type"} eq "image/gif" ) {

        #
        # Is the image animated for 5 or more seconds ?
        #
        if ( $image_details{"animation_time"} > 5 ) {
            #
            # Animated image with animation time greater than 5 seconds.
            #
            Record_Result("WCAG_2.0-G152", $line, $column, $text,
                          String_Value("GIF animation exceeds 5 seconds"));
        }

        #
        # Does the image flash more than 3 times in any 1 second
        # time period ?
        #
        if ( $image_details{"most_frames_per_sec"} > 3 ) {
            #
            # Animated image that flashes more than 3 times in 1 second
            #
            Record_Result("WCAG_2.0-G19", $line, $column, $text,
                     String_Value("GIF flashes more than 3 times in 1 second"));
        }
    }
}

#***********************************************************************
#
# Name: Image_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the image tag, it looks for alt text.
#
#***********************************************************************
sub Image_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($alt, $invalid_alt);

    #
    # Are we inside an anchor tag ?
    #
    if ( $inside_anchor ) {
        #
        # Set flag to indicate we found an image inside the anchor tag.
        #
        $image_found_inside_anchor = 1;
        print "Image found inside anchor tag\n" if $debug;
    }

    #
    # Check alt attributes ? We can't check for alt content as this
    # may be just a decorative image.
    # 1) If this image is inside a <figure> the alt is optional as a
    #   <figcaption> can provide the alt text.
    # 2) If the image tag as an empty generator-unable-to-provide-required-alt
    #    attribute it may omit the alt attribute.  This does not make the page
    #    a conforming page but does tell the conformance checking tool (this
    #    tool) that the process that generated the page was unable to
    #    provide accurate alt text.
    #  reference http://www.w3.org/html/wg/drafts/html/master/embedded-content-0.html#guidance-for-conformance-checkers
    #
    if ( ! $in_figure ) {
        Check_For_Alt_Attribute("WCAG_2.0-F65", "<img>", $line,
                                $column, $text, %attr);
    }
    #
    # Check for possible empty "generator-unable-to-provide-required-alt"
    # attribute
    #
    elsif ( defined($attr{"generator-unable-to-provide-required-alt"}) &&
            ($attr{"generator-unable-to-provide-required-alt"} eq "") ) {
        #
        # Found empty "generator-unable-to-provide-required-alt", do we NOT
        # have an alt attribute ?
        #
        if ( ! defined($attr{"alt"}) ) {
            #
            # Alt is omitted
            #
            print "Have generator-unable-to-provide-required-alt and no alt\n" if $debug;
        }
        else {
            #
            # We have an alt as well as generator-unable-to-provide-required-alt,
            # this is not allowed.
            #
            Record_Result("WCAG_2.0-H88", $line, $column, $text,
                          String_Value("Invalid attribute combination found") .
                          " <img generator-unable-to-provide-required-alt=\"\" alt= >");
        }
    }

    #
    # Save value of alt text
    #
    if ( defined($attr{"alt"}) ) {
        #
        # Remove whitespace and convert to lower case for easy comparison
        #
        $last_image_alt_text = $attr{"alt"};
        $last_image_alt_text = Clean_Text($last_image_alt_text);
        $last_image_alt_text = lc($last_image_alt_text);

        #
        # If we have a text handler capturing text, add the alt text
        # to that text.
        #
        if ( $have_text_handler ) {
            push(@{ $self->handler("text")}, "ALT:" . $attr{"alt"});
        }
    }
    else {
        $last_image_alt_text = "";

        #
        # No alt, are we inside a <figure> ?
        #
        if ( $in_figure ) {
            $image_in_figure_with_no_alt = 1;
            $fig_image_line = $line;
            $fig_image_column = $column;
            $fig_image_text = $text;
        }
    }

    #
    # Check longdesc attribute
    #
    if ( defined($$current_tqa_check_profile{"WCAG_2.0-H45"}) ) {
        Check_Longdesc_Attribute("WCAG_2.0-H45", "<image>", $line, $column,
                                 $text, %attr);
    }

    #
    # Check for alt and src attributes
    #
    if ( defined($attr{"alt"}) && defined($attr{"src"}) ) {
        print "Have alt = " . $attr{"alt"} . " and src = " . $attr{"src"} .
              " in image\n" if $debug;

        #
        # Check for duplicate alt and src (using a URL for the alt text)
        #
        if ( $attr{"alt"} eq $attr{"src"} ) {
            print "src eq alt\n" if $debug;
            Record_Result("WCAG_2.0-F30", $line, $column, $text,
                          String_Value("Image alt same as src"));
        }
    }

    #
    # Check value of alt attribute to see if it is a forbidden
    # word or phrase (reference: http://oaa-accessibility.org/rule/28/)
    #
    if ( defined($attr{"alt"}) && ($attr{"alt"} ne "") ) {
        #
        # Do we have invalid alt text phrases defined ?
        #
        if ( defined($testcase_data{"WCAG_2.0-F30"}) ) {
            $alt = lc($attr{"alt"});
            foreach $invalid_alt (split(/\n/, $testcase_data{"WCAG_2.0-F30"})) {
                #
                # Do we have a match on the invalid alt text ?
                #
                if ( $alt =~ /^$invalid_alt$/i ) {
                    Record_Result("WCAG_2.0-F30", $line, $column, $text,
                                  String_Value("Invalid alt text value") .
                                  " '" . $attr{"alt"} . "'");
                }
            }
        }
    }

    #
    # Check for a src attribute, if we have one check for a
    # flickering image.
    #
    if ( defined($attr{"src"}) ) {
        Check_Flickering_Image("<image>", $attr{"src"}, $line, $column,
                               $text, %attr);
    }
}

#***********************************************************************
#
# Name: HTML_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the html tag, it checks to see that the
# language specified matches the document language.
#
#***********************************************************************
sub HTML_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    my ($lang) = "unknown";

    #
    # If this is not XHTML 2.0, we must have a 'lang' attribute
    #
    if ( ! (($doctype_label =~ /xhtml/i) && ($doctype_version >= 2.0)) ) {
        #
        # Do we have a lang ?
        #
        if ( ! defined( $attr{"lang"}) ) {
            #
            # Missing language attribute
            #
            Record_Result("WCAG_2.0-H57", $line, $column, $text,
                          String_Value("Missing html language attribute") .
                          " 'lang'");
        }
        else {
            #
            # Save language code, but strip off any dialect value
            #
            $lang = lc($attr{"lang"});
            $lang =~ s/-.*$//g;
        }
    }

    #
    # If this is XHTML, we must have a 'xml:lang' attribute
    #
    if ( $doctype_label =~ /xhtml/i ) {
        #
        # Do we have a xml:lang attribute ?
        #
        if ( ! defined( $attr{"xml:lang"}) ) {
            #
            # Missing language attribute
            #
            Record_Result("WCAG_2.0-H57", $line, $column, $text,
                          String_Value("Missing html language attribute") .
                          " 'xml:lang'");
        }
        else {
            #
            # Save language code, but strip off any dialect value
            #
            $lang = lc($attr{"xml:lang"});
            $lang =~ s/-.*$//g;
        }
    }

    #
    # Do we have both attributes ?
    #
    if ( defined( $attr{"lang"}) && defined( $attr{"xml:lang"}) ) {
        #
        # Do the values match ?
        #
        if ( lc($attr{"lang"}) ne lc($attr{"xml:lang"}) ) {
            Record_Result("WCAG_2.0-H57", $line, $column, $text,
                          String_Value("Mismatching lang and xml:lang attributes") .
                          String_Value("for tag") . "<html>");
        }
    }

    #
    # Were we able to determine the language of the content ?
    #
    if ( $current_content_lang_code ne "" ) {
        #
        # Convert language code into a 3 character code.
        #
        $lang = ISO_639_2_Language_Code($lang);

        #
        # Does the lang attribute match the content language ?
        #
        if ( $lang ne $current_content_lang_code ) {
            Record_Result("WCAG_2.0-H57", $line, $column, $text,
                          String_Value("HTML language attribute") .
                          " '$lang' " .
                          String_Value("does not match content language") .
                          " '$current_content_lang_code'");
        }
    }
}

#***********************************************************************
#
# Name: Meta_Tag_Handler
#
# Parameters: language - url language
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the meta tag, it looks to see if it is used
# for page refreshing
#
#***********************************************************************
sub Meta_Tag_Handler {
    my ( $language, $line, $column, $text, %attr ) = @_;

    my ($content, @values, $value);

    #
    # Are we outside of the <head> section of the document ?
    #
    if ( ! $in_head_tag ) {
        Tag_Not_Allowed_Here("meta", $line, $column, $text);
    }

    #
    # Do we have a http-equiv attribute ?
    #
    if ( defined($attr{"http-equiv"}) && ($attr{"http-equiv"} =~ /refresh/i) ) {
        #
        # WCAG 2.0, check if there is a content attribute with a numeric
        # timeout value.  We don't check both F40 and F41 as the test
        # is the same and would result in 2 messages for the same issue.
        #
        if ( defined($$current_tqa_check_profile{"WCAG_2.0-F40"}) &&
             defined($attr{"content"}) ) {
            $content = $attr{"content"};

            #
            # Split content on semi-colon then check each value
            # to see if it contains only digits (and whitespace).
            #
            @values = split(/;/, $content);
            foreach $value (@values) {
                if ( $value =~ /\s*\d+\s*/ ) {
                    #
                    # Found timeout value, is it greater than 0 ?
                    # A 0 value is a client side redirect, which is a
                    # WCAG AAA check.
                    #
                    print "Meta refresh with timeout $value\n" if $debug;
                    if ( $value > 0 ) {
                        #
                        # Do we have a URL in the content, implying a redirect
                        # rather than a refresh ?
                        #
                        if ( ($content =~ /http/) || ($content =~ /url=/) ) {
                            Record_Result("WCAG_2.0-F40", $line, $column, $text,
                                  String_Value("Meta refresh with timeout") .
                                          "'$value'");
                        }
                        else {
                            Record_Result("WCAG_2.0-F41", $line, $column, $text,
                                  String_Value("Meta refresh with timeout") .
                                          "'$value'");
                        }
                    }

                    #
                    # Don't need to look for any more values.
                    #
                    last;
                }
            }
        }
    }

    #
    # Do we have a name and content attribute ?
    #
    if ( defined($attr{"name"}) && defined($attr{"content"}) ) {
        #
        # We have metadata on this page
        #
        $have_metadata = 1;
    }
}

#***********************************************************************
#
# Name: Check_Deprecated_Tags
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks to see if the named tag is deprecated.
#
#***********************************************************************
sub Check_Deprecated_Tags {
    my ( $tagname, $line, $column, $text, %attr ) = @_;

    #
    # Check tag name
    #
    if ( defined( $$deprecated_tags{$tagname} ) ) {
        Record_Result("WCAG_2.0-H88", $line, $column, $text,
                      String_Value("Deprecated tag found") . "<$tagname>");
    }
}

#***********************************************************************
#
# Name: Check_Deprecated_Attributes
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks to see if there are any deprecated attributes
# for this tag.
#
#***********************************************************************
sub Check_Deprecated_Attributes {
    my ( $tagname, $line, $column, $text, %attr ) = @_;

    my ($attribute, $tag_list);

    #
    # Check all attributes
    #
    foreach $attribute (keys %attr) {
        if ( defined( $$deprecated_attributes{$attribute} ) ) {
            $tag_list = $$deprecated_attributes{$attribute};

            #
            # Is this tag in the tag list for the deprecated attribute ?
            #
            if ( index( $tag_list, " $tagname " ) != -1 ) {
                Record_Result("WCAG_2.0-H88", $line, $column, $text,
                              String_Value("Deprecated attribute found") .
                              "<$tagname $attribute= >");
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Rel_Attribute
#
# Parameters: tag - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             required - flag to indicate if the rel attribute
#                        is required
#             attr - hash table of attributes
#
# Description:
#
#    This function checks the rel attribute of a tag. It checks
# to see the attribute is present and has a value.
#
#***********************************************************************
sub Check_Rel_Attribute {
    my ($tag, $line, $column, $text, $required, %attr) = @_;

    my ($rel_value, $rel, $valid_values);

    #
    # Do we have a rel attribute ?
    #
    if ( ! defined($attr{"rel"}) ) {
        #
        # Is it required ?
        #
        if ( $required ) {
            Record_Result("WCAG_2.0-H88", $line, $column, $text,
                          String_Value("Missing rel attribute in") . "<$tag>");
        }
    }
    #
    # Do we have a value for the rel attribute ?
    #
    elsif ( $attr{"rel"} eq "" ) {
        #
        # Is it required ?
        #
        if ( $required ) {
            Record_Result("WCAG_2.0-H88", $line, $column, $text,
                          String_Value("Missing rel value in") . "<$tag>");
        }
    }
    #
    # Check validity of the value
    #
    else {
        #
        # Convert rel value to lowercase to make checking easier
        #
        $rel = lc($attr{"rel"});
        print "Rel = $rel\n" if $debug;

        #
        # Do we have a set of valid values for this tag ?
        #
        $valid_values = $$valid_rel_values{$tag};
        if ( defined($valid_values) ) {
            #
            # Check each possible value (may be a whitespace separated list)
            #
            foreach $rel_value (split(/\s+/, $rel)) {
                if ( index($valid_values, " $rel_value ") == -1 ) {
                    print "Unknown rel value '$rel_value'\n" if $debug;
                    Record_Result("WCAG_2.0-H88", $line, $column, $text,
                                  String_Value("Invalid rel value") .
                                  " \"$rel_value\"");
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Link_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles link tags.
#
#***********************************************************************
sub Link_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    #
    # Check for rel attribute of the tag
    #
    Check_Rel_Attribute("link", $line, $column, $text, 1, %attr);
}

#***********************************************************************
#
# Name: Anchor_Tag_Handler
#
# Parameters: self - reference to this parser
#             language - url language
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles anchor tags.
#
#***********************************************************************
sub Anchor_Tag_Handler {
    my ( $self, $language, $line, $column, $text, %attr ) = @_;

    my ($href, $name, $title);

    #
    # Add a text handler to save the text portion of the anchor
    # tag.
    #
    Start_Text_Handler($self, "a");
    
    #
    # Check for rel attribute of the tag
    #
    Check_Rel_Attribute("a", $line, $column, $text, 0, %attr);

    #
    # Clear any image alt text value.  If we have images in this
    # anchor we will want to check the value in the end anchor.
    #
    $last_image_alt_text = "";
    $image_found_inside_anchor = 0;

    #
    # Do we have an href attribute
    #
    $current_a_href = "";
    $current_a_title = "";
    if ( defined($attr{"href"}) ) {
        #
        # Set flag to indicate we are inside an anchor tag
        #
        $inside_anchor = 1;

        #
        # Are we inside a label ? If so we have an accessibility problem
        # because the user may select the link when they want to select
        # the label (to get focus to an input).
        #
        if ( $inside_label ) {
            Record_Result("WCAG_2.0-H44", $line, $column,
                          $text, String_Value("Link inside of label"));
        }

        #
        # Save the href value in a global variable.  We may need it when
        # processing the end of the anchor tag.
        #
        $href = $attr{"href"};
        $href =~ s/^\s*//g;
        $href =~ s/\s*$//g;
        $current_a_href = $href;
        print "Anchor_Tag_Handler, current_a_href = \"$current_a_href\"\n" if $debug;

        #
        # Do we have a title attribute for this link ?
        #
        if ( defined( $attr{"title"} ) ) {
            $current_a_title = $attr{"title"};

            #
            # Check for duplicate title and href (using a
            # URL for the title text)
            #
            if ( $current_a_href eq $current_a_title ) {
                print "title eq href\n" if $debug;
                Record_Result("WCAG_2.0-H33", $line, $column, $text,
                              String_Value("Anchor title same as href"));
            }
            elsif ( $current_a_title eq "" ) {
                #
                # Title attribute with no content
                #
                print "title is empty string\n" if $debug;
                Record_Result("WCAG_2.0-H33", $line, $column, $text,
                              String_Value("Missing title content for") .
                              "<a>");
            }
        }
    }
    #
    # Is this a named anchor ?
    #
    elsif ( defined($attr{"name"}) ) {
        $name = $attr{"name"};
        $name =~ s/^\s*//g;
        $name =~ s/\s*$//g;
        print "Anchor_Tag_Handler, name = \"$name\"\n" if $debug;

        #
        # Check for missing value, we don't have to report it here
        # as the validator will catch it.
        #
        if ( $name ne "" ) {
            #
            # Have we seen an anchor with this name before ?
            #
            if ( defined($anchor_name{$name}) ) {
                Record_Result("WCAG_2.0-F77", $line, $column,
                              $text, String_Value("Duplicate anchor name") .
                              "'$name'" .  " " .
                              String_Value("Previous instance found at") .
                              $anchor_name{$name});
            }

            #
            # Save anchor name and location
            #
            $anchor_name{$name} = "$line:$column";
        }
    }

    #
    # Check for accesskey attribute
    #
    Check_Accesskey_Attribute("a", $line, $column, $text, %attr);

    #
    # Check that there is at least 1 of href, name or id attributes
    #
    if ( defined($attr{"href"}) || defined($attr{"id"}) || 
         defined($attr{"name"}) ) {
        print "Anchor has href, id or name\n" if $debug;
    }
    else {
        Record_Result("WCAG_2.0-G115", $line, $column, $text,
                      String_Value("Missing href, id or name in <a>"));
    }

    #
    # Are we inside an emphasis block ? If so set a flag to indicate we
    # found an anchor tag.
    #
    if ( $emphasis_count > 0 ) {
        $anchor_inside_emphasis = 1;
    }
}

#***********************************************************************
#
# Name: Declaration_Handler
#
# Parameters: text - declaration text
#             line - line number
#             column - column number
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the declaration line in an HTML document.
#
#***********************************************************************
sub Declaration_Handler {
    my ( $text, $line, $column ) = @_;

    my ($this_dtd, @dtd_lines, $testcase);
    my ($top, $availability, $registration, $organization, $type, $label);
    my ($language, $url);

    #
    # Save declaration location
    #
    $doctype_line          = $line;
    $doctype_column        = $column;
    $doctype_text          = $text;

    #
    # Convert any newline or return characters into whitespace
    #
    $text =~ s/\r/ /g;
    $text =~ s/\n/ /g;

    #
    # Parse the declaration line to get its fields, we only care about the FPI
    # (Formal Public Identifier) field.
    #
    #  <!DOCTYPE root-element PUBLIC "FPI" ["URI"]
    #    [ <!-- internal subset declarations --> ]>
    #
    ($top, $availability, $registration, $organization, $type, $label, $language, $url) =
         $text =~ /^\s*\<!DOCTYPE\s+(\w+)\s+(\w+)\s+"(.)\/\/(\w+)\/\/(\w+)\s+([\w\s\.\d]*)\/\/(\w*)".*>\s*$/io;

    #
    # Did we get an FPI ?
    #
    if ( defined($label) ) {
        #
        # Parse out the language (HTML vs XHTML), the version number
        # and the class (e.g. strict)
        #
        $doctype_label = $label;
        ($doctype_language, $doctype_version, $doctype_class) =
            $doctype_label =~ /^([\w\s]+)\s+(\d+\.\d+)\s*(\w*)\s*.*$/io;
    }
    #
    # No Formal Public Identifier, perhaps this is a HTML 5 document ?
    #
    elsif ( $text =~ /\s*<!DOCTYPE\s+html>\s*/i ) {
        $doctype_label = "HTML";
        $doctype_version = 5.0;
        $doctype_class = "";

        #
        # Set deprecated tags and attributes to the HTML set.
        #
        $deprecated_tags = \%deprecated_html5_tags;
        $deprecated_attributes = \%deprecated_html5_attributes;
        $implicit_end_tag_end_handler = \%implicit_html5_end_tag_end_handler;
        $implicit_end_tag_start_handler = \%implicit_html5_end_tag_start_handler;
        $valid_rel_values = \%valid_html5_rel_values;
    }
    print "DOCTYPE label = $doctype_label, version = $doctype_version, class = $doctype_class\n" if $debug;

    #
    # Is this an XHTML document ? If so we have to reset the list
    # of deprecated tags (initially set to the HTML list).
    #
    if ( $text =~ /xhtml/i ) {
        $deprecated_tags = \%deprecated_xhtml_tags;
        $deprecated_attributes = \%deprecated_xhtml_attributes;
        $implicit_end_tag_end_handler = \%implicit_xhtml_end_tag_end_handler;
        $implicit_end_tag_start_handler = \%implicit_xhtml_end_tag_start_handler;
        $valid_rel_values = \%valid_xhtml_rel_values;
    }
}

#***********************************************************************
#
# Name: Start_H_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - heading tag name
#             line - line number
#             column - column number
#             text - text from tag
#             level - heading level
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the h tag, it checks to see if headings
# are created in order (h1, h2, h3, ...).
#
#***********************************************************************
sub Start_H_Tag_Handler {
    my ( $self, $tagname, $line, $column, $text, %attr ) = @_;

    my ($level);

    #
    # Get heading level number from the tag
    #
    $level = $tagname;
    $level =~ s/^h//g;
    print "Found heading $tagname\n" if $debug;
    $total_heading_count++;

    #
    # Are we inside the content area ?
    #
    print "Content section " . $content_section_handler->current_content_section() . "\n" if $debug;
    if ( $content_section_handler->in_content_section("CONTENT") ) {
        #
        # Increment the heading count
        #
        $content_heading_count++;
        print "Content area heading count $content_heading_count\n" if $debug;
    }

    #
    # Set global flag to indicate we are inside an <h> ... </h> tag
    # set
    #
    $inside_h_tag_set = 1;

    #
    # Save new heading level and line number
    #
    $current_heading_level = $level;
    $last_heading_line_number = $line;
    $last_heading_column_number = $column;

    #
    # Did we find a <hr> tag being used for decoration prior to this tag ?
    #
    if ( $last_tag eq "hr" ) {
        Record_Result("WCAG_2.0-F43", $line, $column, $text,
                      "<hr>" . String_Value("followed by") . "<$tagname> " .
                      String_Value("used for decoration"));
    }

    #
    # Add a text handler to save the text portion of the h
    # tag.
    #
    Start_Text_Handler($self, $tagname);
}

#***********************************************************************
#
# Name: End_H_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end h tag.
#
#***********************************************************************
sub End_H_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($this_text, $last_line, $last_column, $clean_text);

    #
    # Get all the text found within the h tag
    #
    if ( ! $have_text_handler ) {
        print "End h tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the heading text as a string, remove all white space
    #
    $last_heading_text = Clean_Text(Get_Text_Handler_Content($self, " "));
    $last_heading_text = decode_entities($last_heading_text);
    print "End_H_Tag_Handler: text = \"$last_heading_text\"\n" if $debug;

    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<h$current_heading_level>", $line, $column,
                            $last_heading_text);
    
    #
    # Are we missing heading text ?
    #
    if ( $last_heading_text eq "" ) {
        Record_Result("WCAG_2.0-F43", $line, $column,
                      $text, String_Value("Missing text in") . "<h>");
        Record_Result("WCAG_2.0-G130", $line, $column,
                      $text, String_Value("Missing text in") . "<h>");
    }
    #
    # Is heading too long (perhaps it is a paragraph).
    # This isn't an exact test, what we want to find is if the heading
    # is descriptive.  A very long heading would not likely be descriptive,
    # it may be more of a complete sentense or a paragraph.
    #
    elsif ( length($last_heading_text) > $max_heading_title_length ) {
        Record_Result("WCAG_2.0-H42", $line, $column,
                      $text, String_Value("Heading text greater than 500 characters") . " \"$last_heading_text\"");
    }

    #
    # Destroy the text handler that was used to save the text
    # portion of the h tag.
    #
    Destroy_Text_Handler($self, "h$current_heading_level");

    #
    # UnSet global flag to indicate we are no longer inside an
    # <h> ... </h> tag set
    #
    $inside_h_tag_set = 0;
}

#***********************************************************************
#
# Name: Object_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles object tags.
#
#***********************************************************************
sub Object_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Increment object nesting level and counter for 
    # <param> list
    #
    $object_nest_level++;

    #
    # Save attributes of object tag.  These will be added to with
    # any found in <param> tags to get the total set of attributes
    # for this object.
    #
    push(@param_lists, \%attr);

    #
    # Add a text handler to save the text portion of the object
    # tag (unless we already have one established).
    #
    if ( $object_nest_level == 1 ) {
        Start_Text_Handler($self, "object");
    }
}

#***********************************************************************
#
# Name: End_Object_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end object tag.
#
#***********************************************************************
sub End_Object_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($this_text, $last_line, $last_column, $tcid);
    my (@tcids, $clean_text);

    #
    # Decrement object nesting level
    #
    if ( $object_nest_level > 0 ) {
        $object_nest_level--;
    }

    #
    # Get all the text found within the object tag
    #
    if ( ! $have_text_handler ) {
        print "End object tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the object text as a string and get rid of excess white space
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, " "));
    print "End_Object_Tag_Handler: text = \"$clean_text\"\n" if $debug;

    #
    # A lack of text in an object can fail multiple testcases
    #
    if ( defined($$current_tqa_check_profile{"WCAG_2.0-H27"}) ) {
        push(@tcids, "WCAG_2.0-H27");
    }
    if ( defined($$current_tqa_check_profile{"WCAG_2.0-H53"}) ) {
        push(@tcids, "WCAG_2.0-H53");
    }

    #
    # Are we missing object text ?
    #
    if ( (@tcids > 0) && ($clean_text eq "") ) {
        foreach $tcid (@tcids) {
            Record_Result($tcid, $line, $column,
                          $text, String_Value("Missing text in") . "<object>");
        }
    }

    #
    # If this is not part of a nested object tag structure, we
    # destroy the text handler that was used to save the text
    # portion of the object tag.
    #
    if ( $object_nest_level == 0 ) {
        Destroy_Text_Handler($self, "object");
    }
}

#***********************************************************************
#
# Name: Applet_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles applet tags.
#
#***********************************************************************
sub Applet_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($href);

    #
    # Check alt attribute
    #
    Check_For_Alt_Attribute("WCAG_2.0-H35", "<applet>", $line, $column,
                            $text, %attr);

    #
    # Check alt text content ?
    #
    Check_Alt_Content("WCAG_2.0-H35", "<applet>", $self, $line,
                      $column, $text, %attr);

    #
    # Add a text handler to save the text portion of the applet
    # tag.
    #
    Start_Text_Handler($self, "applet");
}

#***********************************************************************
#
# Name: End_Applet_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end applet tag.
#
#***********************************************************************
sub End_Applet_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($this_text, $last_line, $last_column, $clean_text);

    #
    # Get all the text found within the applet tag
    #
    if ( ! $have_text_handler ) {
        print "End applet tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the applet text as a string and get rid of excess white space
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, " "));
    print "End_Applet_Tag_Handler: text = \"$clean_text\"\n" if $debug;

    #
    # Are we missing applet text ?
    #
    if ( $clean_text eq "" ) {
        Record_Result("WCAG_2.0-H35", $line, $column,
                      $text, String_Value("Missing text in") . "<applet>");
    }

    #
    # Destroy the text handler that was used to save the text
    # portion of the applet tag.
    #
    Destroy_Text_Handler($self, "applet");
}

#***********************************************************************
#
# Name: Embed_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles embed tags.
#
#***********************************************************************
sub Embed_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    #
    # Increment count of <embed> tags and record the location
    # of this tag.
    #
    $embed_noembed_count++;
    $last_embed_line = $line;
    $last_embed_col = $column;
}

#***********************************************************************
#
# Name: Noembed_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles noembed tags.
#
#***********************************************************************
sub Noembed_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    #
    # Decrement embed/noembed counter
    #
    $embed_noembed_count--;
}

#***********************************************************************
#
# Name: Param_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles param tags.
#
#***********************************************************************
sub Param_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    my ($attr_addr, $name, $value);

    #
    # Are we inside an object or embed ?
    #
    print "Param_Tag_Handler, object nesting level $object_nest_level\n" if $debug;
    if ( $object_nest_level > 0 ) {
        $attr_addr = $param_lists[$object_nest_level - 1];

        #
        # Look for 'name' attribute, its content is the name of the attribute.
        #
        if ( defined($attr{"name"}) ) {
            $name = lc($attr{"name"});

            #
            # Look for a 'value' attribute.
            #
            if ( ($name ne "") && defined($attr{"value"}) ) {
                $value = $attr{"value"};

                #
                # If we don't have this attribute add it to the set.
                #
                if ( ! defined($$attr_addr{$name}) ) {
                    print "Add attribute $name value $value\n" if $debug;
                    $$attr_addr{$name} = $value;
                }
                else {
                    #
                    # Append to the existing value
                    #
                    print "Append to attribute $name value $value\n" if $debug;
                    $$attr_addr{$name} .= ";$value";
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Button_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles button tags.
#
#***********************************************************************
sub Button_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($id);

    #
    # Add a text handler to save the text portion of the button
    # tag.
    #
    Start_Text_Handler($self, "button");

    #
    # Is this a submit button ? if so set flag to indicate there is one in the
    # form.
    #
    if ( defined($attr{"type"}) && ($attr{"type"} eq "submit") ) {
        if ( $in_form_tag ) {
            $found_input_button = 1;
            print "Found button in form\n" if $debug;
        }
        else {
            print "Found button outside of form\n" if $debug;
        }
    }

    #
    # Do we have an id attribute that matches a label ?
    #
    if ( defined($attr{"id"}) ) {
        $id = $attr{"id"};
        if ( defined($label_for_location{"$id"}) ) {
            #
            # Label must not be used for a button
            #
            Record_Result("WCAG_2.0-H44", $line, $column,
                          $text, String_Value("Found label for") . "<button>");
        }
    }

    #
    # Check for accesskey attribute
    #
    Check_Accesskey_Attribute("button", $line, $column, $text, %attr);

    #
    # Do we have a title ? if so add it to the button text handler
    # so we can check it's value when we get to the end button
    # tag.
    #
    if ( defined($attr{"title"}) && ($attr{"title"} ne "") ) {
        push(@{ $self->handler("text")}, $attr{"title"});
    }
}

#***********************************************************************
#
# Name: End_Button_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end button tag.
#
#***********************************************************************
sub End_Button_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($this_text, $last_line, $last_column, $clean_text);

    #
    # Get all the text found within the button tag plus any title attribute
    #
    if ( ! $have_text_handler ) {
        print "End button tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the button text as a string, remove excess white space
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, " "));
    print "End_Button_Tag_Handler: text = \"$clean_text\"\n" if $debug;

    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<button>", $line, $column, $clean_text);

    #
    # Are we missing button text ?
    #
    if ( $clean_text eq "" ) {
        Record_Result("WCAG_2.0-H91", $line, $column,
                      $text, String_Value("Missing text in") . "<button>");
    }

    #
    # Destroy the text handler that was used to save the text
    # portion of the button tag.
    #
    Destroy_Text_Handler($self, "button");
}

#***********************************************************************
#
# Name: Caption_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles caption tags.
#
#***********************************************************************
sub Caption_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Add a text handler to save the text portion of the caption
    # tag.
    #
    Start_Text_Handler($self, "caption");
}

#***********************************************************************
#
# Name: End_Caption_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end caption tag.
#
#***********************************************************************
sub End_Caption_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($this_text, $last_line, $last_column, $clean_text);

    #
    # Get all the text found within the caption tag
    #
    if ( ! $have_text_handler ) {
        print "End caption tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the caption text as a string, remove all white space and convert
    # to lowercase
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, " "));
    print "End_Caption_Tag_Handler: text = \"$clean_text\"\n" if $debug;

    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<caption>", $line, $column, $clean_text);

    #
    # Are we missing caption text ?
    #
    if ( $clean_text eq "" ) {
        Record_Result("WCAG_2.0-H39", $line, $column,
                      $text, String_Value("Missing text in") . "<caption>");
    }
    #
    # Have caption text
    #
    else {
        #
        # Is the caption the same as the table summary ?
        #
        print "Table summary = \"" . $table_summary[$table_nesting_index] .
              "\"\n" if $debug;
        if ( lc($clean_text) eq
             lc($table_summary[$table_nesting_index]) ) {
            #
            # Caption the same as table summary.
            #
            Record_Result("WCAG_2.0-H39", $line, $column,
                          $text,
                          String_Value("Duplicate table summary and caption"));
            Record_Result("WCAG_2.0-H73", $line, $column,
                          $text,
                          String_Value("Duplicate table summary and caption"));
        }
    }

    #
    # Destroy the text handler that was used to save the text
    # portion of the caption tag.
    #
    Destroy_Text_Handler($self, "caption");
}

#***********************************************************************
#
# Name: Figcaption_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles figcaption tags.
#
#***********************************************************************
sub Figcaption_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Add a text handler to save the text portion of the figcaption
    # tag.
    #
    Start_Text_Handler($self, "figcaption");
}

#***********************************************************************
#
# Name: End_Figcaption_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end figcaption tag.
#
#***********************************************************************
sub End_Figcaption_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($clean_text);

    #
    # Get all the text found within the figcaption tag
    #
    if ( ! $have_text_handler ) {
        print "End figcaption tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the figcaption text as a string, remove all excess white space.
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, " "));
    print "End_Figcaption_Tag_Handler: text = \"$clean_text\"\n" if $debug;

    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<figcaption>", $line, $column, $clean_text);

    #
    # Are we missing figcaption text ?
    #
    if ( $clean_text eq "" ) {
        Record_Result("WCAG_2.0-G115", $line, $column,
                      $text, String_Value("Missing text in") . "<figcaption>");
    }
    #
    # We have a figure caption
    #
    else {
        $have_figcaption = 1;
    }

    #
    # Destroy the text handler that was used to save the text
    # portion of the figcaption tag.
    #
    Destroy_Text_Handler($self, "figcaption");
}

#***********************************************************************
#
# Name: Option_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles option tags.
#
#***********************************************************************
sub Option_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Add a text handler to save the text portion of the option
    # tag.
    #
    Start_Text_Handler($self, "option");
}

#***********************************************************************
#
# Name: End_Option_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end option tag.
#
#***********************************************************************
sub End_Option_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($this_text, $last_line, $last_column, $clean_text);

    #
    # Get all the text found within the option tag
    #
    if ( ! $have_text_handler ) {
        print "End option tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the option text as a string, remove all white space and convert
    # to lowercase
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, " "));
    print "End_Option_Tag_Handler: text = \"$clean_text\"\n" if $debug;

    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<option>", $line, $column, $clean_text);

    #
    # Are we missing option text ?
    #
    if ( $clean_text eq "" ) {
        Record_Result("WCAG_2.0-G115", $line, $column,
                      $text, String_Value("Missing text in") . "<option>");
    }

    #
    # Destroy the text handler that was used to save the text
    # portion of the option tag.
    #
    Destroy_Text_Handler($self, "option");
}

#***********************************************************************
#
# Name: Figure_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles figure tags.
#
#***********************************************************************
sub Figure_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Set flag to indicate we do not have a figcaption or an image
    # inside the figure.
    #
    $have_figcaption = 0;
    $image_in_figure_with_no_alt = 0;
    $fig_image_line = 0;
    $fig_image_column = 0;
    $fig_image_text = "";
    $in_figure = 1;
}

#***********************************************************************
#
# Name: End_Figure_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end figure tag.
#
#***********************************************************************
sub End_Figure_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    #
    # Are we inside a figure ?
    #
    if ( ! $in_figure ) {
        print "End figure tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Did we find an image in this figure that did not have an alt
    # attribute ?
    #
    if ( $image_in_figure_with_no_alt ) {
        #
        # Was there a figcaption ? The figcaption can act as the alt
        # text for the image.
        #  Reference: http://www.w3.org/html/wg/drafts/html/master/embedded-content-0.html#guidance-for-conformance-checkers
        #
        if ( ! $have_figcaption ) {
            #
            # No figcaption and no alt attribute on image.
            #
            Record_Result("WCAG_2.0-F65", $fig_image_line, $fig_image_column,
                          $fig_image_text,
                          String_Value("Missing alt attribute for") . "<img>");
        }
    }

    #
    # End of figure tag
    #
    $in_figure = 0;
}

#***********************************************************************
#
# Name: Check_Event_Handlers
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks for event handler attributes to the tag.
#
#***********************************************************************
sub Check_Event_Handlers {
    my ( $tagname, $line, $column, $text, %attr ) = @_;

    my ($error, $attribute);
    my ($mouse_only) = 0;
    my ($keyboard_only) = 0;

    #
    # Check for mouse only event handlers (i.e. missing keyboard
    # event handlers).
    #
    print "Check_Event_Handlers\n" if $debug;
    foreach $attribute (keys(%attr)) {
        if ( index($mouse_only_event_handlers, " $attribute ") > -1 ) {
            $mouse_only = 1;
        }
        if ( index($keyboard_only_event_handlers, " $attribute ") > -1 ) {
            $keyboard_only = 1;
        }
    }
    if ( $mouse_only && (! $keyboard_only) ) {
        print "Mouse only event handlers found\n" if $debug;
        Record_Result("WCAG_2.0-F54", $line, $column, $text,
                      String_Value("Mouse only event handlers found"));
    }
    else {
        #
        # Check for event handler pairings for mouse & keyboard.
        # Do we have a mouse event handler with no corresponding keyboard
        # handler ?
        #
        $error = "";
        if ( defined($attr{"onmousedown"}) && (! defined($attr{"onkeydown"})) ) {
            $error .= "; onmousedown, onkeydown";
        }
        if ( defined($attr{"onmouseup"}) && (! defined($attr{"onkeyup"})) ) {
            if ( defined($error) ) {
                $error .= "; onmouseup, onkeyup";
            }
        }
        if ( defined($attr{"onclick"}) && (! defined($attr{"onkeypress"})) ) {
            #
            # Although click is in principle a mouse event handler, most HTML
            # and XHTML user agents process this event when the control is
            # activated, regardless of whether it was activated with the mouse
            # or the keyboard. In practice, therefore, it is not necessary to
            # duplicate this event. It is included here for completeness since
            # non-HTML user agents do have this issue.
            # See http://www.w3.org/TR/2010/NOTE-WCAG20-TECHS-20101014/SCR20
            #
            #if ( defined($error) ) {
            #    $error .= "; onclick, onkeypress";
            #}
        }
        if ( defined($attr{"onmouseover"}) && (! defined($attr{"onfocus"})) ) {
            if ( defined($error) ) {
                $error .= "; onmouseover, onfocus";
            }
        }
        if ( defined($attr{"onmouseout"}) && (! defined($attr{"onblur"})) ) {
            if ( defined($error) ) {
                $error .= "; onmouseout, onblur";
            }
        }

        #
        # Get rid of any possible leading "; "
        #
        $error =~ s/^; //g;

        #
        # Did we find a missing pairing ?
        #
        if ( $error ne "" ) {
            Record_Result("WCAG_2.0-SCR20", $line, $column, $text,
                          String_Value("Missing event handler from pair") .
                          "'$error'" . String_Value("for tag") . "<$tagname>");
        }
    }

    #
    # Check for scripting events that emulate links on non-link
    # tags.  Look for onclick or onkeypress for tags that should
    # not have them.
    #
    if ( defined($attr{"onclick"}) or defined($attr{"onkeypress"}) ) {
        if ( index( $tags_allowed_events, " $tagname " ) == -1 ) {
            #
            # Is this a tag that has no explicit end tag ? If so report
            # the problem here.
            #
            if ( defined($html_tags_with_no_end_tag{$tagname}) ) {
                Record_Result("WCAG_2.0-F42", $line, $column, $text,
                            String_Value("onclick or onkeypress found in tag") .
                              "<$tagname>");
            }
            else {
                #
                # Save this tag and location.  If there is a focusable item
                # inside the tag, then the onclick/onkeypress is
                # acceptable.
                #
                print "Found onclick/onkeypress in attribute list for $tagname\n" if $debug;
                $found_onclick_onkeypress = 1;
                $onclick_onkeypress_line = $line;
                $onclick_onkeypress_column = $column;
                $onclick_onkeypress_text = $text;
                $have_focusable_item = 0;
            }
        }
    }

    #
    # If we have onclick/onkeypress save this tag and location.
    # If there is a focusable item inside the tag, then the
    # onclick/onkeypress is acceptable.
    #
    if ( $found_onclick_onkeypress && 
         (! defined($html_tags_with_no_end_tag{$tagname})) ) {
        print "Add $tagname to onclick_onkeypress_tag stack\n" if $debug;
        push(@onclick_onkeypress_tag, $tagname);
    }

    #
    # Are we inside a tag with onclick/onkeypress and is this tag
    # a focusable item ?
    #
    if ( $found_onclick_onkeypress && 
         (index( $tags_allowed_events, " $tagname " ) > -1) ) { 
        print "Found focusable item while inside onclick/onkeypress\n" if $debug;
        $have_focusable_item = 1;
    }
}

#***********************************************************************
#
# Name: Start_Title_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles title tags.
#
#***********************************************************************
sub Start_Title_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # We found a title tag.
    #
    $found_title_tag = 1;
    print "Start_Title_Tag_Handler\n" if $debug;

    #
    # Are we outside of the <head> section of the document ?
    #
    if ( ! $in_head_tag ) {
        Tag_Not_Allowed_Here("title", $line, $column, $text);
    }

    #
    # Add a text handler to save the text portion of the title
    # tag.
    #
    Start_Text_Handler($self, "title");
}

#***********************************************************************
#
# Name: Start_Form_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the form tag.
#
#***********************************************************************
sub Start_Form_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    #
    # Set flag to indicate we are within a <form> .. </form>
    # tag pair and that we have not seen a button yet.
    #
    print "Start of form\n" if $debug;
    $in_form_tag = 1;
    $found_input_button = 0;
    $last_radio_checkbox_name = "";
    $number_of_writable_inputs = 0;
    %input_id_location     = ();
    %label_for_location    = ();
    %form_label_value      = ();
    %form_legend_value     = ();
    %form_title_value      = ();
}

#***********************************************************************
#
# Name: End_Form_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the end form tag.
#
#***********************************************************************
sub End_Form_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    #
    # Set flag to indicate we are outside a <form> .. </form>
    # tag pair.
    #
    print "End of form\n" if $debug;
    $in_form_tag = 0;

    #
    # Did we see a button inside the form ?
    #
    if ( (! $found_input_button) && ($number_of_writable_inputs > 0) ) {
        #
        # Missing submit button (input type="submit", input type="image",
        # or button type="submit")
        #
        Record_Result("WCAG_2.0-H32", $line, $column, $text,
                      String_Value("No button found in form"));
    }

    #
    # Check for extra or missing labels
    #
    Check_Missing_And_Extra_Labels();
}

#***********************************************************************
#
# Name: Start_Head_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the head tag.  It sets a global variable
# indicating we are inside the <head>..</head> section.
#
#***********************************************************************
sub Start_Head_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    #
    # Set flag to indicate we are within a <head> .. </head>
    # tag pair.
    #
    print "Start of head\n" if $debug;
    $in_head_tag = 1;
}

#***********************************************************************
#
# Name: End_Head_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the end head tag. It sets a global variable
# indicating we are inside the <head>..</head> section.
#
#***********************************************************************
sub End_Head_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    #
    # Set flag to indicate we are outside a <head> .. </head>
    # tag pair.
    #
    print "End of head\n" if $debug;
    $in_head_tag = 0;
}

#***********************************************************************
#
# Name: Abbr_Acronym_Tag_handler
#
# Parameters: self - reference to this parser
#             tag - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the abbr and acronym tags.  It checks for a
# title attribute and starts a text handler to capture the abbreviation
# or acronym.
#
#***********************************************************************
sub Abbr_Acronym_Tag_handler {
    my ( $self, $tag, $line, $column, $text, %attr ) = @_;

    #
    # Check for "title" attribute
    #
    print "Abbr_Acronym_Tag_handler, tag = $tag\n" if $debug;
    if ( defined( $attr{"title"} ) ) {
        $abbr_acronym_title = Clean_Text($attr{"title"});
        print "Title attribute = \"$abbr_acronym_title\"\n" if $debug;

        #
        # Check for missing value.
        #
        if ( $abbr_acronym_title eq "" ) {
            Record_Result("WCAG_2.0-G115", $line, $column, $text,
                          String_Value("Missing title content for") . "<$tag>");
        }
    }
    else {
        #
        # Missing title attribute
        #
        Record_Result("WCAG_2.0-G115", $line, $column, $text,
                      String_Value("Missing title attribute for") . "<$tag>");
        $abbr_acronym_title = "";
    }

    #
    # Add a text handler to save the text portion of the abbr
    # tag.
    #
    Start_Text_Handler($self, $tag);
}

#***********************************************************************
#
# Name: Check_Acronym_Abbr_Consistency
#
# Parameters: tag - name of tag
#             title - title of acronym or abbreviation
#             content - value of acronym or abbreviation
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function checks the consistency of acronym and abbreviations.
# It checks that the title value is consistent and the there are not
# multiple acronyms or abbreviations with the same title value.
#
#***********************************************************************
sub Check_Acronym_Abbr_Consistency {
    my ( $tag, $title, $content, $line, $column, $text ) = @_;

    my ($last_line, $last_column, $text_table, $location_table, $title_table);
    my ($prev_title, $prev_location, $prev_text, $location);
    my ($save_acronym) = 1;

    #
    # Check acronym/abbr consistency.
    #
    print "Check_Acronym_Abbr_Consistency: tag = $tag, content = \"$content\", title = \"$title\", lang = $current_lang\n" if $debug;
    $title = lc($title);

    #
    # Convert &#39; style quote to an &rsquo; before comparison.
    #
    $title =~ s/\&#39;/\&rsquo;/g;

    #
    # Do we have any abbreviations or acronyms for the current
    # language ?
    #
    if ( ! defined($abbr_acronym_text_title_lang_map{$current_lang}) ) {
        #
        # No table for this language, create one
        #
        print "Create new language table ($current_lang) for acronym text\n" if $debug;
        my (%new_text_table, %new_location_table);
        $abbr_acronym_text_title_lang_map{$current_lang} = \%new_text_table;
        $abbr_acronym_text_title_lang_location{$current_lang} = \%new_location_table;
    }

    #
    # Get address of acronym/abbreviation value tables
    #
    $text_table = $abbr_acronym_text_title_lang_map{$current_lang};
    $location_table = $abbr_acronym_text_title_lang_location{$current_lang};

    #
    # Have we seen this abbreviation/acronym text before ?
    #
    if ( defined($$text_table{$content}) ) {
        #
        # Do the title values match ?
        #
        $prev_title = $$text_table{$content};
        print "Saw text before with title \"$prev_title\"\n" if $debug;
        if ( $prev_title ne $title ) {
            #
            # Get previous location
            #
            $prev_location = $$location_table{$content};
            print "Title mismatch, previous location is $prev_location\n" if $debug;

            #
            # Record result
            #
            Record_Result("WCAG_2.0-G197", $line, $column, $text,
              String_Value("Title values do not match for") .
              " <$tag> " . 
              String_Value("Found") . " \"$title\" " .
              String_Value("previously found") .
              " \"$prev_title\" ".
              String_Value("at line:column") . $prev_location);
        }

        #
        # Since the acronym/abbreviation is in the table already, we
        # dont have to save it.
        #
        $save_acronym = 0;
    }

    #
    # Do we have any abbreviation or acronym titles for the current
    # language ?
    #
    if ( ! defined($abbr_acronym_title_text_lang_map{$current_lang}) ) {
        #
        # No table for this language, create one
        #
        print "Create new language table ($current_lang) for acronym title\n" if $debug;
        my (%new_title_table, %new_location_table);
        $abbr_acronym_title_text_lang_map{$current_lang} = \%new_title_table;
        $abbr_acronym_title_text_lang_location{$current_lang} = \%new_location_table;
    }

    #
    # Get address of acronym title tables
    #
    $title_table = $abbr_acronym_title_text_lang_map{$current_lang};
    $location_table = $abbr_acronym_title_text_lang_location{$current_lang};

    #
    # Have we seen this abbreviation/acronym title before ?
    #
    if ( defined($$title_table{$title}) ) {
        #
        # Do the text values match ?
        #
        $prev_text = $$title_table{$title};
        print "Saw text before with content \"$prev_text\"\n" if $debug;
        if ( $prev_text ne $content ) {
            #
            # Get previous location
            #
            $prev_location = $$location_table{$title};
            print "Content mismatch, previous location is $prev_location\n" if $debug;

            #
            # Record result
            #
            Record_Result("WCAG_2.0-G197", $line, $column, $text,
              String_Value("Content values do not match for") .
              " <$tag title=\"$title\" > " . 
              String_Value("Found") . " \"$content\" " .
              String_Value("previously found") .
              " \"$prev_text\" ".
              String_Value("at line:column") . $prev_location);
        }

        #
        # Since the acronym/abbreviation is in the table already, we
        # dont have to save it.
        #
        $save_acronym = 0;
    }
    #
    # Do we save this acronym/abbreviation ?
    #
    if ( $save_acronym ) {
        #
        # Save acronym/abbreviation content
        #
        print "Save acronym/abbr content and title\n" if $debug;
        $text_table = $abbr_acronym_text_title_lang_map{$current_lang};
        $location_table = $abbr_acronym_text_title_lang_location{$current_lang};
        $$text_table{$content} = $title;
        $$location_table{$content} = "$line:$column";

        #
        # Save acronym/abbreviation title
        #
        $title_table = $abbr_acronym_title_text_lang_map{$current_lang};
        $location_table = $abbr_acronym_title_text_lang_location{$current_lang};
        $$title_table{$title} = $content;
        $$location_table{$title} = "$line:$column";

    }
}

#***********************************************************************
#
# Name: End_Abbr_Acronym_Tag_handler
#
# Parameters: self - reference to this parser
#             tag - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end abbr and acronym tags.  It checks that an
# abbreviation/acronym was found and checks to see if it is used
# consistently if it appeared earlier in the page.
#
#***********************************************************************
sub End_Abbr_Acronym_Tag_handler {
    my ( $self, $tag, $line, $column, $text ) = @_;

    my ($last_line, $last_column, $text_title_map, $clean_text);
    my ($prev_title, $prev_location, $text_title_location);
    my ($save_acronym) = 1;

    #
    # Get all the text found within the tag
    #
    if ( ! $have_text_handler ) {
        print "End $tag tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the text as a string, remove excess white space
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
    print "End_Abbr_Acronym_Tag_handler: tag = $tag, text = \"$clean_text\"\n" if $debug;
    
    #
    # Check the text content, have we seen this value or title before ?
    #
    if ( $clean_text ne "" ) {
        #
        # Check for using white space characters to control spacing
        # within a word
        #
        Check_Character_Spacing("<$tag>", $line, $column, $clean_text);

        #
        # Did we find any letters in the acronym ? An acronym cannot consist
        # of all digits or punctuation.
        #  http://www.w3.org/TR/html-markup/abbr.html
        #
#
# Ignore this check.  WCAG uses <abbr> with no letters in some examples.
# http://www.w3.org/TR/2012/NOTE-WCAG20-TECHS-20120103/H90
#
#        if ( ! ($clean_text =~ /[a-z]/i) ) {
#            Record_Result("WCAG_2.0-G115", $line, $column, $text,
#                          String_Value("Content does not contain letters for") .
#                          " <$tag>");
#        }

        #
        # Did we get a title in the start tag ? (if it is missing it was
        # reported in the start tag).
        #
        if ( $abbr_acronym_title ne "" ) {
            #
            # Is the title same as the text ?
            #
            print "Have title and text\n" if $debug;
            if ( lc($clean_text) eq lc($abbr_acronym_title) ) {
                print "Text eq title\n" if $debug;
                Record_Result("WCAG_2.0-G115", $line, $column, $text,
                              String_Value("Content same as title for") .
                              " <$tag>");
            }
            else {
                #
                # Check consistency of content and title
                #
                Check_Acronym_Abbr_Consistency($tag, $abbr_acronym_title,
                                               $clean_text, $line, $column,
                                               $text);
            }
        }
    }
    else {
        #
        # Missing text for abbreviation or acronym
        #
        print "Missing text for $tag\n" if $debug;
        Record_Result("WCAG_2.0-G115", $line, $column, $text,
                      String_Value("Missing text in") . "<$tag>");
    }

    #
    # Destroy the text handler that was used to save the text.
    #
    Destroy_Text_Handler($self, "$tag");
}

#***********************************************************************
#
# Name: Tag_Must_Have_Content_handler
#
# Parameters: self - reference to this parser
#             tag - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles start tags for tags that must have content.
# It starts a text handler to capture the text between the start and 
# end tags.
#
#***********************************************************************
sub Tag_Must_Have_Content_handler {
    my ( $self, $tag, $line, $column, $text, %attr ) = @_;

    #
    # Start of tag that must have content
    #
    print "Tag_Must_Have_Content_handler, tag = $tag\n" if $debug;

    #
    # Add a text handler to save the text portion of the tag
    #
    Start_Text_Handler($self, $tag);
}

#***********************************************************************
#
# Name: End_Tag_Must_Have_Content_handler
#
# Parameters: self - reference to this parser
#             tag - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a handler for end tags for tags that must
# have content.  It checks to see that there was text between
# the start and end tags.
#
#***********************************************************************
sub End_Tag_Must_Have_Content_handler {
    my ( $self, $tag, $line, $column, $text ) = @_;

    my ($clean_text);

    #
    # Get all the text found within the tag
    #
    if ( ! $have_text_handler ) {
        print "End $tag tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the text as a string, remove excess white space
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
    print "End_Tag_Must_Have_Content_handler: tag = $tag, text = \"$clean_text\"\n" if $debug;
    
    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<$tag>", $line, $column, $clean_text);

    #
    # Check that we have some content.
    #
    if ( $clean_text eq "" ) {
        #
        # Missing text for tag
        #
        print "Missing text for $tag\n" if $debug;
        Record_Result("WCAG_2.0-G115", $line, $column, $text,
                      String_Value("Missing text in") . "<$tag>");
    }

    #
    # Destroy the text handler that was used to save the text.
    #
    Destroy_Text_Handler($self, "$tag");
}

#***********************************************************************
#
# Name: Q_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the q tag, it looks for an
# optional cite attribute and it starts a text handler to
# capture the text between the start and end tags.
#
#***********************************************************************
sub Q_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($cite, $href, $resp_url, $resp);

    #
    # Start of q, look for an optional cite attribute.
    #
    print "Q_Tag_Handler\n" if $debug;
    Check_Cite_Attribute("WCAG_2.0-H88", "<q>", $line, $column,
                         $text, %attr);

    #
    # Add a text handler to save the text portion of the tag
    #
    Start_Text_Handler($self, "q");

}

#***********************************************************************
#
# Name: End_Q_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a handler for end q tag.
# It checks to see that there was text between the start and end tags.
#
#***********************************************************************
sub End_Q_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($clean_text);

    #
    # Get all the text found within the tag
    #
    if ( ! $have_text_handler ) {
        print "End q tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the text as a string, remove excess white space
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
    print "End_Q_Tag_Handler: text = \"$clean_text\"\n" if $debug;

    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<q>", $line, $column, $clean_text);

    #
    # Check that we have some content.
    #
    if ( $clean_text eq "" ) {
        #
        # Missing text for tag
        #
        print "Missing text for q\n" if $debug;
        Record_Result("WCAG_2.0-G115", $line, $column, $text,
                      String_Value("Missing text in") . "<q>");
    }

    #
    # Destroy the text handler that was used to save the text.
    #
    Destroy_Text_Handler($self, "q");
}

#***********************************************************************
#
# Name: Check_Cite_Attribute
#
# Parameters: tcid - testcase id
#             tag - name of HTML tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks the value of the cite attribute.
#
#***********************************************************************
sub Check_Cite_Attribute {
    my ( $tcid, $tag, $line, $column, $text, %attr ) = @_;

    my ($cite, $href, $resp_url, $resp);

    #
    # Look for cite attribute
    #
    if ( defined($attr{"cite"}) ) {
        #
        # Check value, this should be a URI
        #
        $cite = $attr{"cite"};
        print "Check_Cite_Attribute, cite = $cite\n" if $debug;

        #
        # Do we have a value ?
        #
        $cite =~ s/^\s*//g;
        $cite =~ s/\s*$//g;
        if ( $cite eq "" ) {
            #
            # Missing cite value
            #
            Record_Result($tcid, $line, $column, $text,
                          String_Value("Missing cite content for") .
                          "$tag");
        }
        else {
            #
            # Convert possible relative url into an absolute one based
            # on the URL of the current document.  If we don't have
            # a current URL, then HTML_Check was called with just a block
            # of HTML text rather than the result of a GET.
            #
            if ( $current_url ne "" ) {
                $href = url($cite)->abs($current_url);
                print "cite url = $href\n" if $debug;

                #
                # Get long description URL
                #
                ($resp_url, $resp) = Crawler_Get_HTTP_Response($href,
                                                               $current_url);

                #
                # Is this a valid URI ?
                #
                if ( (! defined($resp)) || (! $resp->is_success) ) {
                    Record_Result($tcid, $line, $column, $text,
                                  String_Value("Broken link in cite for") .
                                  "$tag");
                }
            }
            else {
                #
                # Skip check of URL, if it is relative we cannot
                # make it absolute.
                #
                print "No current URL, cannot make cite an absolute URL\n" if $debug;
            }
        }
    }
}

#***********************************************************************
#
# Name: Blockquote_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the blockquote tag, it looks for an
# optional cite attribute and it starts a text handler to
# capture the text between the start and end tags.
#
#***********************************************************************
sub Blockquote_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($cite, $href, $resp_url, $resp);

    #
    # Start of blockquote, look for an optional cite attribute.
    #
    print "Blockquote_Tag_Handler\n" if $debug;
    Check_Cite_Attribute("WCAG_2.0-H88", "<blockquote>", $line, $column,
                         $text, %attr);

    #
    # Add a text handler to save the text portion of the tag
    #
    Start_Text_Handler($self, "blockquote");

}

#***********************************************************************
#
# Name: End_Blockquote_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a handler for end blockquote tag.
# It checks to see that there was text between the start and end tags.
#
#***********************************************************************
sub End_Blockquote_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($clean_text);

    #
    # Get all the text found within the tag
    #
    if ( ! $have_text_handler ) {
        print "End blockquote tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the text as a string, remove excess white space
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
    print "End_Blockquote_Tag_Handler: text = \"$clean_text\"\n" if $debug;

    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<blockquote>", $line, $column, $clean_text);

    #
    # Check that we have some content.
    #
    if ( $clean_text eq "" ) {
        #
        # Missing text for tag
        #
        print "Missing text for blockquote\n" if $debug;
        Record_Result("WCAG_2.0-G115", $line, $column, $text,
                      String_Value("Missing text in") . "<blockquote>");
    }

    #
    # Destroy the text handler that was used to save the text.
    #
    Destroy_Text_Handler($self, "blockquote");
}

#***********************************************************************
#
# Name: Li_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the li tag.
#
#***********************************************************************
sub Li_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Increment count of <li> tags in this list
    #
    if ( $current_list_level > -1 ) {
        $list_item_count[$current_list_level]++;
        $inside_list_item[$current_list_level] = 1;
    }
    else {
        #
        # Not in a list
        #
        Tag_Not_Allowed_Here("li", $line, $column, $text);
    }

    #
    # Add a text handler to save the text portion of the li
    # tag.
    #
    Start_Text_Handler($self, "li");
}

#***********************************************************************
#
# Name: End_Li_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end li tag.
#
#***********************************************************************
sub End_Li_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($clean_text);

    #
    # Get all the text found within the li tag
    #
    if ( ! $have_text_handler ) {
        print "End li tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Set flag to indicate we are no longer inside a list item
    #
    if ( $current_list_level > -1 ) {
        $inside_list_item[$current_list_level] = 0;
    }

    #
    # Get the li text as a string, remove excess white space
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
    print "End_Li_Tag_Handler: text = \"$clean_text\"\n" if $debug;

    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<li>", $line, $column, $clean_text);

    #
    # Are we missing li content or text ?
    #
    if ( $clean_text eq "" ) {
        Record_Result("WCAG_2.0-G115", $line, $column,
                      $text, String_Value("Missing content in") . "<li>");
    }

    #
    # Destroy the text handler that was used to save the text
    # portion of the li tag.
    #
    Destroy_Text_Handler($self, "li");
}

#***********************************************************************
#
# Name: Check_Start_of_New_List
#
# Parameters: self - reference to this parser
#             tag - list tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function checks to see if this new list is within an
# existing list.  It checks for text preceeding the new list 
# that acts as a header for the list.
#
#***********************************************************************
sub Check_Start_of_New_List {
    my ( $self, $tag, $line, $column, $text ) = @_;

    my ($clean_text);

    #
    # Was the last open tag a <li> or <dd> and we are inside a list ?
    #
    print "Check_Start_of_New_List $tag, last open tag = $last_open_tag, list level = $current_list_level\n" if $debug;
    if ( ($current_list_level > 0) && 
         (($last_open_tag eq "li") || ($last_open_tag eq "dd")) ) {
        print "New list inside an existing list\n" if $debug;

        #
        # New list as the value of an existing list.  Do we have
        # any text that acts as a header ?
        #
        if ( $have_text_handler ) {
            #
            # Get the list item text as a string, remove excess white space
            #
            $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
        }
        else {
            #
            # No text handler so no text.
            #
            $clean_text = "";
        }

        #
        # Are we missing header text ?
        #
        print "Check_Start_of_New_List: text = \"$clean_text\"\n" if $debug;
        if ( $clean_text eq "" ) {
            Record_Result("WCAG_2.0-G115", $line, $column, $text,
                          String_Value("Missing content before new list") .
                          "<$tag>");
        }
    }
}

#***********************************************************************
#
# Name: Ol_Ul_Tag_Handler
#
# Parameters: self - reference to this parser
#             tag - list tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the ol and ul tags.
#
#***********************************************************************
sub Ol_Ul_Tag_Handler {
    my ( $self, $tag, $line, $column, $text, %attr ) = @_;

    #
    # Increment list level count and set list item count to zero
    #
    $current_list_level++;
    $list_item_count[$current_list_level] = 0;
    $inside_list_item[$current_list_level] = 0;
    print "Start new $tag list, level $current_list_level\n" if $debug;

    #
    # Start of new list, are we already inside a list ?
    #
    Check_Start_of_New_List($self, $tag, $line, $column, $text);
}

#***********************************************************************
#
# Name: End_Ol_Ul_Tag_Handler
#
# Parameters: tag - list tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end ol or ul tags.
#
#***********************************************************************
sub End_Ol_Ul_Tag_Handler {
    my ( $tag, $line, $column, $text ) = @_;

    #
    # Check that we found some list items in the list
    #
    if ( $current_list_level > -1 ) {
        $inside_list_item[$current_list_level] = 0;
        print "End $tag list, level $current_list_level, item count ".
              $list_item_count[$current_list_level] . "\n" if $debug;
        if ( $list_item_count[$current_list_level] == 0 ) {
            #
            # No items in list
            #
            Record_Result("WCAG_2.0-H48", $line, $column, $text,
                          String_Value("No li found in list") . "<$tag>");
        }

        #
        # Decrement list level
        #
        $current_list_level--;
    }
}

#***********************************************************************
#
# Name: Dt_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the dt tag.
#
#***********************************************************************
sub Dt_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Increment count of <dt> tags in this list
    #
    if ( $current_list_level > -1 ) {
        $list_item_count[$current_list_level]++;
    }
    else {
        #
        # Not in a list
        #
        Tag_Not_Allowed_Here("dt", $line, $column, $text);
    }

    #
    # Add a text handler to save the text portion of the dt
    # tag.
    #
    Start_Text_Handler($self, "dt");
}

#***********************************************************************
#
# Name: End_Dt_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end dt tag.
#
#***********************************************************************
sub End_Dt_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($clean_text);

    #
    # Get all the text found within the dt tag
    #
    if ( ! $have_text_handler ) {
        print "End dt tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the dt text as a string, remove excess white space
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
    print "End_Dt_Tag_Handler: text = \"$clean_text\"\n" if $debug;

    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<dt>", $line, $column, $clean_text);

    #
    # Are we missing dt content or text ?
    #
    if ( $clean_text eq "" ) {
        Record_Result("WCAG_2.0-G115", $line, $column,
                      $text, String_Value("Missing content in") . "<dt>");
    }

    #
    # Destroy the text handler that was used to save the text
    # portion of the dt tag.
    #
    Destroy_Text_Handler($self, "dt");
}

#***********************************************************************
#
# Name: Dl_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the dl.
#
#***********************************************************************
sub Dl_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Increment list level count and set list item count to zero
    #
    $current_list_level++;
    $list_item_count[$current_list_level] = 0;
    print "Start new dl list, level $current_list_level\n" if $debug;

    #
    # Start of new list, are we already inside a list ?
    #
    Check_Start_of_New_List($self, "dl", $line, $column, $text);
}

#***********************************************************************
#
# Name: End_Dl_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end dl tag.
#
#***********************************************************************
sub End_Dl_Tag_Handler {
    my ( $line, $column, $text ) = @_;

    #
    # Check that we found some list items in the list
    #
    if ( $current_list_level > -1 ) {
        print "End dl list, level $current_list_level, item count ".
              $list_item_count[$current_list_level] . "\n" if $debug;
        if ( $list_item_count[$current_list_level] == 0 ) {
            #
            # No items in list
            #
            Record_Result("WCAG_2.0-H48", $line, $column, $text,
                          String_Value("No dt found in list") . "<dl>");
        }

        #
        # Decrement list level
        #
        $current_list_level--;
    }
}

#***********************************************************************
#
# Name: Check_ID_Attribute
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attrseq - reference to an array of attributes
#             attr - hash table of attributes
#
# Description:
#
#   This function checks common attributes for tags.
#
#***********************************************************************
sub Check_ID_Attribute {
    my ( $tagname, $line, $column, $text, $attrseq, %attr ) = @_;

    my ($id);

    #
    # Do we have an id attribute ?
    #
    print "Check_ID_Attribute\n" if $debug;
    if ( defined($attr{"id"}) ) {
        $id = $attr{"id"};
        $id =~ s/^\s*//g;
        $id =~ s/\s*$//g;
        print "Found id \"$id\" in tag $tagname at $line:$column\n" if $debug;

        #
        # Have we seen this id before ?
        #
        if ( defined($id_attribute_values{$id}) ) {
            Record_Result("WCAG_2.0-F77", $line, $column,
                          $text, String_Value("Duplicate id") .
                          "'$id'" .  " " .
                          String_Value("Previous instance found at") .
                          $id_attribute_values{$id});
        }

        #
        # Save id location
        #
        $id_attribute_values{$id} = "$line:$column";
    }
}

#***********************************************************************
#
# Name: Check_Duplicate_Attributes
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attrseq - reference to an array of attributes
#             attr - hash table of attributes
#
# Description:
#
#   This function checks for duplicate attributes.  Attributes are only
# allowed to appear once in a tag.
#
#***********************************************************************
sub Check_Duplicate_Attributes {
    my ( $tagname, $line, $column, $text, $attrseq, %attr ) = @_;

    my ($attribute, $this_attribute, @attribute_list);

    #
    # Check for duplicate attributes
    #
    print "Check_Duplicate_Attributes\n" if $debug;
    if ( defined($$current_tqa_check_profile{"WCAG_2.0-H94"}) ) {

        #
        # Get a copy of the attribute list that we can work with
        #
        @attribute_list = @$attrseq;

        #
        # Check each attribute in the list
        #
        $attribute = shift(@attribute_list);
        while ( defined($attribute) ) {
            print "Check attribute $attribute\n" if $debug;
            foreach $this_attribute (@attribute_list) {
                print "Check against attribute $this_attribute\n" if $debug;
                if ( $this_attribute eq $attribute ) {
                    #
                    # Have a duplicate attribute
                    #
                    Record_Result("WCAG_2.0-H94", $line, $column,
                                  $text, String_Value("Duplicate attribute") .
                                  "'$attribute'" .
                                  String_Value("for tag") .
                                  "<$tagname>");
                }
            }

            #
            # Get next attribute in the list
            #
            $attribute = shift(@attribute_list);
        }
    }
}

#***********************************************************************
#
# Name: Check_Lang_Attribute
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attrseq - reference to an array of attributes
#             attr - hash table of attributes
#
# Description:
#
#   This function checks the lang attribute.  It this is an XHTML document
# then if a language attribute is present, both lang and xml:lang must
# specified, with the same value.  It also checks that the value is
# formatted correctly, a 2 character code with an optional dialect.
#
#***********************************************************************
sub Check_Lang_Attribute {
    my ( $tagname, $line, $column, $text, $attrseq, %attr ) = @_;

    my ($lang, $xml_lang);

    #
    # Do we have a lang attribute ?
    #
    if ( defined($attr{"lang"}) ) {
        $lang = lc($attr{"lang"});
    }

    #
    # Do we have a xml:lang attribute ?
    #
    if ( defined($attr{"xml:lang"}) ) {
        $xml_lang = lc($attr{"xml:lang"});
    }

    #
    # Is this an XHTML 1.0 document ? Check the any lang and xml:lang
    # attributes match.  Don't do this check for the <html> tag, that
    # has already been handled in the HTML_Tag function.
    #
    print "Check_Lang_Attribute\n" if $debug;
    if ( ($tagname ne "html") && ($doctype_label =~ /xhtml/i) && 
         ($doctype_version == 1.0) ) {
        #
        # Do we have a lang attribute ?
        #
        if ( defined($lang) ) {

            #
            # Are we missing the xml:lang attribute ?
            #
            if ( ! defined($xml_lang) ) {
                #
                # Missing xml:lang attribute
                #
                print "Have lang but not xml:lang attribute\n" if $debug;
                Record_Result("WCAG_2.0-H58", $line, $column, $text,
                              String_Value("Missing xml:lang attribute") .
                              String_Value("for tag") . "<$tagname>");

            }
        }

        #
        # Do we have a xml:lang attribute ?
        #
        if ( defined($xml_lang) ) {
            #
            # Are we missing the lang attribute ?
            #
            if ( ! defined($lang) ) {
                #
                # Missing lang attribute
                #
                print "Have xml:lang but not lang attribute\n" if $debug;
                Record_Result("WCAG_2.0-H58", $line, $column,
                              $text, String_Value("Missing lang attribute") .
                              String_Value("for tag") . "<$tagname>");

            }
        }

        #
        # Do we have a value for both attributes ?
        #
        if ( defined($lang) && defined($xml_lang) ) {
            #
            # Do the values match ?
            #
            if ( $lang ne $xml_lang ) {
                Record_Result("WCAG_2.0-H58", $line, $column, $text,
                              String_Value("Mismatching lang and xml:lang attributes") .
                              String_Value("for tag") . "<$tagname>");
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_OnFocus_Attribute
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attrseq - reference to an array of attributes
#             attr - hash table of attributes
#
# Description:
#
#   This function checks the onfocus attribute.  It checks to see if
# JavaScript is used to blur this tag once it receives focus.
#
#***********************************************************************
sub Check_OnFocus_Attribute {
    my ( $tagname, $line, $column, $text, $attrseq, %attr ) = @_;

    my ($onfocus);

    #
    # Do we have an onfocus attribute ?
    #
    if ( defined($attr{"onfocus"}) ) {
        $onfocus = $attr{"onfocus"};

        #
        # Is the content 'this.blur()', which is used to blur the
        # tag ?
        #
        print "Have onfocus=\"$onfocus\"\n" if $debug;
        if ( $onfocus =~ /^\s*this\.blur\(\)\s*/i ) {
            #
            # JavaScript causing tab to blur once it has focus
            #
            Record_Result("WCAG_2.0-F55", $line, $column, $text,
                          String_Value("Using script to remove focus when focus is received") .
                          String_Value("in tag") . "<$tagname>");
         }
    }
}

#***********************************************************************
#
# Name: Check_Attributes
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attrseq - reference to an array of attributes
#             attr - hash table of attributes
#
# Description:
#
#   This function checks common attributes for tags.
#
#***********************************************************************
sub Check_Attributes {
    my ( $tagname, $line, $column, $text, $attrseq, %attr ) = @_;

    my ($error, $id, $attribute, $this_attribute, @attribute_list);

    #
    # Check id attribute
    #
    print "Check_Attributes for tag $tagname\n" if $debug;
    Check_ID_Attribute($tagname, $line, $column, $text, $attrseq, %attr);

    #
    # Check for duplicate attributes
    #
    Check_Duplicate_Attributes($tagname, $line, $column, $text, $attrseq, %attr);

    #
    # Check lang & xml:lang attributes
    #
    Check_Lang_Attribute($tagname, $line, $column, $text, $attrseq, %attr);

    #
    # Check onfocus attribute
    #
    Check_OnFocus_Attribute($tagname, $line, $column, $text, $attrseq, %attr);
}

#***********************************************************************
#
# Name: Check_Tag_Nesting
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function checks the nesting of tags.
#
#***********************************************************************
sub Check_Tag_Nesting {
    my ( $tagname, $line, $column, $text ) = @_;

    my ($tag_item, $tag, $location);

    #
    # Is this a tag that cannot be nested ?
    #
    if ( defined($html_tags_cannot_nest{$tagname}) ) {
        #
        # Cannot nest this tag, do we already have on on the tag stack ?
        #
        foreach $tag_item (@tag_order_stack) {
            #
            # Split tag item into tag and location
            #
            ($tag, $location) = split(/\s+/, $tag_item, 2);

            #
            # Do we have a match on tags ?
            #
            if ( $tagname eq $tag ) {
                #
                # Tag started again without seeing a close.
                # Report this error only once per document.
                #
                if ( ! $wcag_2_0_f70_reported ) {
                    print "Start tag found $tagname when already open\n" if $debug;
                    Record_Result("WCAG_2.0-F70", $line, $column, $text,
                                  String_Value("Missing close tag for") .
                                               " <$tagname> " .
                                  String_Value("started at line:column") .
                                  $location);
                    $wcag_2_0_f70_reported = 1;
                }

                #
                # Found tag, break out of loop.
                #
                last;
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Multiple_Instances_of_Tag
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function checks to see that there are not multiple instances
# of a tag that can have only 1 instance.
#
#***********************************************************************
sub Check_Multiple_Instances_of_Tag {
    my ( $tagname, $line, $column, $text ) = @_;

    my ($prev_location);

    #
    # Is this a tag that can have only 1 instance ?
    #
    if ( defined($html_tags_allowed_only_once{$tagname}) ) {
        #
        # Have we seen this tag before >
        #
        if ( defined($html_tags_allowed_only_once_location{$tagname}) ) {
            #
            # Get previous instance location
            #
            $prev_location = $html_tags_allowed_only_once_location{$tagname};

            #
            # Report error
            #
            print "Multiple instnaces of $tagname previously seen at $prev_location\n" if $debug;
            Record_Result("WCAG_2.0-H88", $line, $column, $text,
                          String_Value("Multiple instances of") .
                                       " <$tagname> " .
                          String_Value("Previous instance found at") .
                          $prev_location);
        }
        else {
            #
            # Record location for future check.
            #
            $html_tags_allowed_only_once_location{$tagname} = "$line:$column"; 
        }
    }
}

#***********************************************************************
#
# Name: Check_For_Change_In_Language
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks for a change in language through the
# use of the lang (or xml:lang) attribute.  If a lang attribute it found,
# the current language is updated and the tag is added to the
# language stack.  The tag is also added to the stack even if it does not
# have a lang attribute, if the tag is the same as the last tag with
# a lang attribute.
#
#***********************************************************************
sub Check_For_Change_In_Language {
    my ( $tagname, $line, $column, $text, %attr ) = @_;

    my ($lang);

    #
    # Check for a lang attribute
    #
    print "Check_For_Change_In_Language in tag $tagname\n" if $debug;
    if ( defined($attr{"lang"}) ) {
        $lang = lc($attr{"lang"});
        print "Found lang $lang in $tagname\n" if $debug;
    }
    #
    # Check for xml:lang (ignore the possibility that there is both
    # a lang and xml:lang and that they could be different).
    #
    elsif ( defined($attr{"xml:lang"})) {
        $lang = lc($attr{"xml:lang"});
        print "Found xml:lang $lang in $tagname\n" if $debug;
    }

    #
    # Did we find a language attribute ?
    #
    if ( defined($lang) ) {
        #
        # Convert language code into a 3 character code.
        #
        $lang = ISO_639_2_Language_Code($lang);

        #
        # Does this tag have a matching end tag ?
        #
        if ( ! defined ($html_tags_with_no_end_tag{$tagname}) ) {
            #
            # Update the current language and push this one on the language
            # stack. Save the current tag name also.
            #
            push(@lang_stack, $current_lang);
            push(@tag_lang_stack, $last_lang_tag);
            $last_lang_tag = $tagname;
            $current_lang = $lang;
            print "Push $tagname, $current_lang on language stack\n" if $debug;
        }
    }
    else {
        #
        # No language.  If this tagname is the same as the last one with a
        # language, pretend this one has a language also.  This avoids
        # premature ending of a language span when the end tag is reached
        # (and the language is popped off the stack).
        #
        if ( $tagname eq $last_lang_tag ) {
            push(@lang_stack, $current_lang);
            push(@tag_lang_stack, $tagname);
            print "Push copy of $tagname, $current_lang on language stack\n"
              if $debug;
        }
    }
}

#***********************************************************************
#
# Name: Check_For_Implicit_End_Tag_Before_Start_Tag
#
# Parameters: self - reference to this parser
#             language - url language
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             skipped_text - text since the last tag
#             attrseq - reference to an array of attributes
#             attr - hash table of attributes
#
# Description:
#
#   This function checks for an implicit end tag caused by a start tag.
#
#***********************************************************************
sub Check_For_Implicit_End_Tag_Before_Start_Tag {
    my ( $self, $language, $tagname, $line, $column, $text, $skipped_text,
         $attrseq, @attr ) = @_;

    my ($last_start_tag, $tag_item, $location, $tag_list, $last_item);

    #
    # Get last start tag.
    #
    print "Check_For_Implicit_End_Tag_Before_Start_Tag for $tagname\n" if $debug;
    $last_item = @tag_order_stack - 1;
    if ( $last_item >= 0 ) {
        $tag_list = join(" ", @tag_order_stack);
        print "Current tag stack $tag_list\n" if $debug;
        $tag_item = $tag_order_stack[$last_item];

        #
        # Split tag item into tag and location
        #
        ($last_start_tag, $location) = split(/\s+/, $tag_item, 2);
        print "Last tag order stack item $last_start_tag at $location\n" if $debug;
    }
    else {
        print "Tag order stack is empty\n" if $debug;
        return;
    }

    #
    # Check to see if there is a list of tags that may be implicitly
    # ended by this start tag.
    #
    print "Check for implicit end tag caused by start tag $tagname at $line:$column\n" if $debug;
    if ( defined($$implicit_end_tag_start_handler{$tagname}) ) {
        #
        # Is the last tag in the list of tags that
        # implicitly closed by the current tag ?
        #
        $tag_list = $$implicit_end_tag_start_handler{$tagname};
        if ( index($tag_list, " $last_start_tag ") != -1 ) {
            #
            # Call End Handler to close the last tag
            #
            print "Tag $last_start_tag implicitly closed by $tagname\n" if $debug;
            End_Handler($self, $last_start_tag, $line, $column, "", ());

            #
            # Check the end tag order again after implicitly
            # ending the last start tag above.
            #
#            print "Check for implicitly ended tag after implicitly ending $last_start_tag\n" if $debug;
#            Check_For_Implicit_End_Tag_Before_Start_Tag($self, $language,
#                                                        $tagname, $line,
#                                                        $column, $text, 
#                                                        $skipped_text,
#                                                        $attrseq, @attr);
        }
        else {
            #
            # The last tag is not implicitly closed by this tag.
            #
            print "Tag $last_start_tag not implicitly closed by $tagname\n" if $debug;
        }
    }
    else {
        #
        # No implicit end tag possible, we have a tag ordering
        # error.
        #
        print "No tags implicitly closed by $tagname\n" if $debug;
    }
    print "Finish Check_For_Implicit_End_Tag_Before_Start_Tag for $tagname\n" if $debug;
}

#***********************************************************************
#
# Name: Start_Handler
#
# Parameters: self - reference to this parser
#             language - url language
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             skipped_text - text since the last tag
#             attrseq - reference to an array of attributes
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the start of HTML tags.
#
#***********************************************************************
sub Start_Handler {
    my ( $self, $language, $tagname, $line, $column, $text, $skipped_text,
         $attrseq, @attr ) = @_;

    my (%attr_hash) = @attr;
    my ($tag_item, $tag, $location);

    #
    # Check to see if this start tag implicitly closes any
    # open tags.
    #
    print "Start_Handler tag $tagname at $line:$column\n" if $debug;
    Check_For_Implicit_End_Tag_Before_Start_Tag($self, $language, $tagname,
                                                $line, $column, $text,
                                                $skipped_text, $attrseq, @attr);

    #
    # Save skipped text in a global variable for use by other
    # functions.
    #
    $skipped_text =~ s/^\s*//;
    $text_between_tags = $skipped_text;

    #
    # If this tag is not an anchor tag or we have skipped over some
    # text, we clear any previous anchor information. We do not have
    # adjacent anchors.
    #
    if ( ($tagname ne "a") || ($skipped_text ne "") ) {
        $last_a_contains_image = 0;
        $last_a_href = "";
    }

    #
    # Check for a change in language using the lang attribute.
    #
    Check_For_Change_In_Language($tagname, $line, $column, $text, %attr_hash);

    #
    # Check tag nesting
    #
    Check_Tag_Nesting($tagname, $line, $column, $text);

    #
    # Check to see if we have multiple instances of tags that we
    # can have only 1 instance of.
    #
    Check_Multiple_Instances_of_Tag($tagname, $line, $column, $text);

    #
    # Check for start of content section
    #
    $content_section_handler->check_start_tag($tagname, $line, $column,
                                              %attr_hash);
                                                    
    #
    # See which content section we are in
    #
    if ( $content_section_handler->current_content_section() ne "" ) {
        $content_section_found{$content_section_handler->current_content_section()} = 1;
    }

    #
    # Check anchor tags
    #
    $tagname =~ s/\///g;
    if ( $tagname eq "a" ) {
        Anchor_Tag_Handler($self, $language, $line, $column, $text, %attr_hash);
    }

    #
    # Check abbr tag
    #
    elsif ( $tagname eq "abbr" ) {
        Abbr_Acronym_Tag_handler( $self, $tagname, $line, $column, $text,
                                  %attr_hash );
    }

    #
    # Check acronym tag
    #
    elsif ( $tagname eq "acronym" ) {
        Abbr_Acronym_Tag_handler( $self, $tagname, $line, $column, $text,
                                  %attr_hash );
    }

    #
    # Check applet tags
    #
    elsif ( $tagname eq "applet" ) {
        Applet_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check areas
    #
    elsif ( $tagname eq "area" ) {
        Area_Tag_Handler($self, $language, $line, $column, $text, %attr_hash);
    }

    #
    # Check b tag
    #
    elsif ( $tagname eq "b" ) {
        Emphasis_Tag_Handler($self, $tagname, $line, $column, $text,
                             %attr_hash);
    }

    #
    # Check blink tag
    #
    elsif ( $tagname eq "blink" ) {
        Blink_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check blockquote tag
    #
    elsif ( $tagname eq "blockquote" ) {
        Blockquote_Tag_Handler($self, $line, $column, $text, %attr_hash);
    }

    #
    # Check button
    #
    elsif ( $tagname eq "button" ) {
        Button_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check caption
    #
    elsif ( $tagname eq "caption" ) {
        Caption_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check dl tag
    #
    elsif ( $tagname eq "dl" ) {
        Dl_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check dt tag
    #
    elsif ( $tagname eq "dt" ) {
        Dt_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check em tag
    #
    elsif ( $tagname eq "em" ) {
        Emphasis_Tag_Handler($self, $tagname, $line, $column, $text,
                             %attr_hash);
    }

    #
    # Check embed tag
    #
    elsif ( $tagname eq "embed" ) {
        Embed_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check fieldset tag
    #
    elsif ( $tagname eq "fieldset" ) {
        Fieldset_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check figcaption
    #
    elsif ( $tagname eq "figcaption" ) {
        Figcaption_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check figure
    #
    elsif ( $tagname eq "figure" ) {
        Figure_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check frame tag
    #
    elsif ( $tagname eq "frame" ) {
        Frame_Tag_Handler( "frame", $line, $column, $text, %attr_hash );
    }

    #
    # Check form tag
    #
    elsif ( $tagname eq "form" ) {
        Start_Form_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check h tag
    #
    elsif ( $tagname =~ /^h[0-9]?$/ ) {
        Start_H_Tag_Handler( $self, $tagname, $line, $column, $text,
                            %attr_hash );
    }

    #
    # Check head tag
    #
    elsif ( $tagname eq "head" ) {
        Start_Head_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check hr tag
    #
    elsif ( $tagname eq "hr" ) {
        HR_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check html tag
    #
    elsif ( $tagname eq "html" ) {
        HTML_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check i tag
    #
    elsif ( $tagname eq "i" ) {
        Emphasis_Tag_Handler($self, $tagname, $line, $column, $text,
                             %attr_hash);
    }

    #
    # Check iframe tag
    #
    elsif ( $tagname eq "iframe" ) {
        Frame_Tag_Handler( "iframe", $line, $column, $text, %attr_hash );
    }

    #
    # Check input tag
    #
    elsif ( $tagname eq "input" ) {
        Input_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check image tag
    #
    elsif ( $tagname eq "img" ) {
        Image_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check label tag
    #
    elsif ( $tagname eq "label" ) {
        Label_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check legend tag
    #
    elsif ( $tagname eq "legend" ) {
        Legend_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check li tag
    #
    elsif ( $tagname eq "li" ) {
        Li_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check link tag
    #
    elsif ( $tagname eq "link" ) {
        Link_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check marquee tag
    #
    elsif ( $tagname eq "marquee" ) {
        Marquee_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check meta tags
    #
    elsif ( $tagname eq "meta" ) {
        Meta_Tag_Handler( $language, $line, $column, $text, %attr_hash );
    }

    #
    # Check noembed tag
    #
    elsif ( $tagname eq "noembed" ) {
        Noembed_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check object tags
    #
    elsif ( $tagname eq "object" ) {
        Object_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check ol tag
    #
    elsif ( $tagname eq "ol" ) {
        Ol_Ul_Tag_Handler( $self, $tagname, $line, $column, $text, %attr_hash );
    }

    #
    # Check option
    #
    elsif ( $tagname eq "option" ) {
        Option_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check p tags
    #
    elsif ( $tagname eq "p" ) {
        P_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check param tag
    #
    elsif ( $tagname eq "param" ) {
        Param_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check q tag
    #
    elsif ( $tagname eq "q" ) {
        Q_Tag_Handler($self, $line, $column, $text, %attr_hash);
    }

    #
    # Check select tag
    #
    elsif ( $tagname eq "select" ) {
        Select_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check strong tag
    #
    elsif ( $tagname eq "strong" ) {
        Emphasis_Tag_Handler($self, $tagname, $line, $column, $text,
                             %attr_hash);
    }

    #
    # Check table tag
    #
    elsif ( $tagname eq "table" ) {
        Table_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check textarea tag
    #
    elsif ( $tagname eq "textarea" ) {
        Textarea_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check td tag
    #
    elsif ( $tagname eq "td" ) {
        TD_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check th tag
    #
    elsif ( $tagname eq "th" ) {
        TH_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check thead tag
    #
    elsif ( $tagname eq "thead" ) {
        Thead_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check title tag
    #
    elsif ( $tagname eq "title" ) {
        Start_Title_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check ul tag
    #
    elsif ( $tagname eq "ul" ) {
        Ol_Ul_Tag_Handler( $self, $tagname, $line, $column, $text, %attr_hash );
    }

    #
    # Check for tags that are not handled above, yet must still
    # contain some text between the start and end tags.
    #
    elsif ( defined($tags_that_must_have_content{$tagname}) ) {
        Tag_Must_Have_Content_handler( $self, $tagname, $line, $column, $text,
                                       %attr_hash );
    }

    #
    # Look for deprecated tags
    #
    else {
        Check_Deprecated_Tags( $tagname, $line, $column, $text, %attr_hash );
    }

    #
    # Look for deprecated tag attributes
    #
    Check_Deprecated_Attributes($tagname, $line, $column, $text, %attr_hash);

    #
    # Check event handlers
    #
    Check_Event_Handlers( $tagname, $line, $column, $text, %attr_hash );

    #
    # Check attributes
    #
    Check_Attributes($tagname, $line, $column, $text, $attrseq, %attr_hash);

    #
    # Push current color value onto the stack
    # (it will be removed when we hit the end of this tag).
    #
    if ( index( $tags_with_color_attribute, " $tagname " ) != -1 ) {
        push( @color_stack, $current_color );
    }

    #
    # Is this a tag that has no end tag ? If so we must set the last tag
    # seen value here rather than in the End_Handler function.
    #
    if ( defined ($html_tags_with_no_end_tag{$tagname}) ) {
        $last_tag = $tagname;
    }
    else {
        #
        # Tag with an end tag, push this tag on the tag stack so we
        # can see if we get the end tags in the correct order
        #
        print "Push tag onto tag order stack $tagname at $line:$column\n" if $debug;
        push(@tag_order_stack, "$tagname $line:$column");
    }

    #
    # Set last open tag seen
    #
    $last_open_tag = $tagname;
}

#***********************************************************************
#
# Name: Check_Click_Here_Link
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             link_text - text of the link
#
# Description:
#
#   This function checks the link text looking for a 'click here' type
# of link.
#
#***********************************************************************
sub Check_Click_Here_Link {
    my ( $line, $column, $text, $link_text ) = @_;

    #
    # Is the value of the link text 'here' or 'click here' ?
    #
    print "Check_Click_Here_Link, text = \"$link_text\"\n" if $debug;
    $link_text = lc($link_text);
    $link_text =~ s/^\s*//g;
    $link_text =~ s/\s*$//g;
    $link_text =~ s/\.*$//g;
    if ( index($click_here_patterns, " $link_text ") != -1 ) {
        Record_Result("WCAG_2.0-H30", $line, $column, $text,
                      String_Value("click here link found"));
    }
}

#***********************************************************************
#
# Name: Production_Development_URL_Match
#
# Parameters: href1 - href value
#             href2 - href value
#
# Description:
#
#   This function checks to see if the 2 href values are the same
# except for the domain portion.  If the domains are production and
# development instances of the same server, the href values are deemed
# to match.
#
#***********************************************************************
sub Production_Development_URL_Match {
    my ($href1, $href2) = @_;

    my ($href_match) = 0;
    my ($protocol1, $domain1, $dir1, $query1, $url1);
    my ($protocol2, $domain2, $dir2, $query2, $url2);

    #
    # Extract the URL components
    #
    ($protocol1, $domain1, $dir1, $query1, $url1) = URL_Check_Parse_URL($href1);
    ($protocol2, $domain2, $dir2, $query2, $url2) = URL_Check_Parse_URL($href2);

    #
    # Do the directory and query portions match ?
    #
    if ( ($dir1 eq $dir2) && ($query1 eq $query2) ) {
        #
        # Are the domains the prod/dev equivalents of each other ?
        #
        if ( (Crawler_Get_Prod_Dev_Domain($domain1) eq $domain2) ||
             (Crawler_Get_Prod_Dev_Domain($domain2) eq $domain1) ) {
            #
            # Domains are prod/dev equivalents, the href values 'match'
            #
            $href_match = 1;
        }
    }

    #
    # Return match status
    #
    return($href_match);
}

#***********************************************************************
#
# Name: End_Anchor_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end anchor </a> tag.
#
#***********************************************************************
sub End_Anchor_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($this_text, @anchor_text_list, $last_line, $last_column);
    my (@tc_list, $anchor_text, $n, $link_text, $tcid);
    my ($all_anchor_text) = "";
    my ($image_alt_in_anchor) = "";

    #
    # Get all the text & image paths found within the anchor tag
    #
    if ( ! $have_text_handler ) {
        print "End anchor tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }
    @anchor_text_list = @{ $self->handler("text") };

    #
    # Loop through the text items
    #
    foreach $this_text (@anchor_text_list) {
        #
        # Do we have Image alt text ?
        #
        if ( $this_text =~ /^ALT:/ ) {
            #
            # Add it to the anchor text
            #
            $this_text =~ s/^ALT://g;
            $all_anchor_text .= $this_text;
            $image_alt_in_anchor .= $this_text;
        }

        #
        # Anchor text or title
        #
        else {
            #
            # Save all anchor text as a single string.
            #
            $all_anchor_text .= $this_text;

            #
            # Check for duplicate anchor text and image alt text
            #
            if ( $last_image_alt_text ne "" ) {
                #
                # Remove all white space and convert to lower case to
                # make comparison easier.
                #
                $this_text = Clean_Text($this_text);
                $this_text = lc($this_text);

                #
                # Does the anchor text match the alt text from the
                # image within this anchor ?
                #
                if ( $this_text eq $last_image_alt_text ) {
                    print "Anchor and image alt text the same \"$last_image_alt_text\"\n" if $debug;
                    Record_Result("WCAG_2.0-H2", $line, $column, $text,
                           String_Value("Anchor and image alt text the same"));
                }
            }
        }
    }

    #
    # Look for adjacent links to the same href, one containing an image
    # and the other not containing an image.
    #
    if ( $last_a_href eq $current_a_href ) {
        #
        # Same href, does exactly 1 of the anchors contain an image ?
        #
        print "Adjacent links to same href\n" if $debug;
        if ( $image_found_inside_anchor xor $last_a_contains_image ) {
            #
            # One anchor contains an image.
            # Note: This can be a false error, we cannot always detect text
            # between anchors if the anchors are within the same paragraph.
            #
            Record_Result("WCAG_2.0-H2", $line, $column, $text,
                          String_Value("Combining adjacent image and text links for the same resource"));
        }
    }

    #
    # Did we have a title attribute on the start tag ?
    #
    if ( $current_a_title ne "" ) {
        #
        # Is the anchor text the same as the title attribute ?
        #
#
# Skip check for title = anchor text.  We have many instances of this
# within our sites and it may not be an error.
#
#        if ( lc(Trim_Whitespace($current_a_title)) eq
#             lc(Trim_Whitespace($all_anchor_text)) ) {
#            Record_Result("WCAG_2.0-H33", $line, $column,
#                          $text, String_Value("Anchor text same as title"));
#        }
    }

    #
    # Remove leading and trailing white space, and
    # convert multiple spaces into a single space.
    #
    $all_anchor_text = Clean_Text($all_anchor_text);

    #
    # Remove leading and trailing white space, and
    # convert multiple spaces into a single space.
    #
    $image_alt_in_anchor = Clean_Text($image_alt_in_anchor);

    #
    # Do we have a URL and no anchor text ?
    #
    if ( ($all_anchor_text eq "") && ($current_a_href ne "") ) {
        #
        # Was there an image inside this anchor ?
        #
        print "No anchor text, image_found_inside_anchor = $image_found_inside_anchor\n" if $debug;
        if ( $image_found_inside_anchor ) {
            #
            # Anchor contains an image with no alt text and no link text.
            # Do we have title text on the anchor tag ? We can use
            # the 'title' attribute to supplemt the link text.
            #
            if ( $current_a_title eq "" ) {
                Record_Result("WCAG_2.0-F89", $line, $column,
                              $text, String_Value("Null alt on an image"));
            }
        }
        else {
            #
            # Are we checking for the presence of anchor text ?
            #
            @tc_list = ();
            if ( defined($$current_tqa_check_profile{"WCAG_2.0-H30"}) ) {
                push(@tc_list, "WCAG_2.0-H30");
            }
            if ( defined($$current_tqa_check_profile{"WCAG_2.0-H91"}) ) {
                push(@tc_list, "WCAG_2.0-H91");
            }

            foreach $tcid (@tc_list) {
                Record_Result($tcid, $line, $column,
                              $text, String_Value("Missing text in") .
                              String_Value("link"));
            }
        }
    }

    #
    # Decode entities into special characters
    #
    $all_anchor_text = decode_entities($all_anchor_text);
    print "End_Anchor_Tag_Handler, anchor text = \"$all_anchor_text\", current_a_href = \"$current_a_href\"\n" if $debug;

    #
    # Check for a 'here' or 'click here' link using link text
    # plus any title attribute.
    #
    Check_Click_Here_Link($line, $column, $text, $all_anchor_text . $current_a_title);

    #
    # Check to see if the anchor text appears to be a URL
    #
    $n = @anchor_text_list;
    if ( $n > 0 ) {
        $anchor_text = $anchor_text_list[$n - 1];
        $anchor_text =~ s/^\s*//g;
        $anchor_text =~ s/\s*$//g;
        if ( URL_Check_Is_URL($anchor_text) ) {
            Record_Result("WCAG_2.0-H30", $line, $column, $text,
                          String_Value("Anchor text is a URL"));
        }
        #
        # Check href and anchor values (if they are non-null)
        #
        elsif ( ($current_a_href ne "") &&
             (lc($all_anchor_text) eq lc($current_a_href)) ) {
            Record_Result("WCAG_2.0-H30", $line, $column,
                          $text, String_Value("Anchor text same as href"));
        }
    }

    #
    # Convert URL into an absolute URL.  Ignore any links to anchors
    # within this document.
    #
    if ( $current_a_href ne "" ) {
        $current_a_href = url($current_a_href)->abs($current_url);
        if ( $current_a_href =~ /^#/ ) {
            $current_a_href = "";
        }
    }

    #
    # Do we have anchor text and a URL ?
    #
    if ( ($all_anchor_text ne "") && ($current_a_href ne "") ) {
        #
        # Have we seen this anchor text before in the same heading context ?
        # We include heading text if the link appears in a list.
        #
        if ( ($current_list_level > -1) && 
             ($inside_list_item[$current_list_level]) ) {
            print "Link inside a list item\n" if $debug;
            $link_text = $last_heading_text . $all_anchor_text;
        }
        else {
            $link_text = $all_anchor_text;
        }
        print "Check link text = $link_text\n" if $debug;
        if ( defined($anchor_text_href_map{$link_text}) ) {
            #
            # Do the href values match ?
            #
            if ( $current_a_href ne $anchor_text_href_map{$link_text} ) {

                #
                # Values do not match, is it a case of a development
                # URL and the equivalent production URL ?
                #
                if ( ! Production_Development_URL_Match($current_a_href,
                                  $anchor_text_href_map{$link_text}) ) {
                    #
                    # Different href values and not a prod/dev
                    # instance.
                    #
                    ($last_line, $last_column) =
                            split(/:/, $anchor_location{$link_text});

                    Record_Result("WCAG_2.0-H30", $line, $column, $text,
                          String_Value("Multiple links with same anchor text") .
                          "\"$all_anchor_text\" href $current_a_href \n" .
                          String_Value("Previous instance found at") .
                          "$last_line:$last_column href " . 
                          $anchor_text_href_map{$link_text});
                }
            }
        } else {
            #
            # Save the anchor text and href in a hash table
            #
            $anchor_text_href_map{$link_text} = $current_a_href;
            $anchor_location{$link_text} = "$line:$column";
        }
    }

    #
    # Record information about this anchor in case we find an adjacent
    # anchor.
    #
    $last_a_contains_image = $image_found_inside_anchor;
    $last_a_href = $current_a_href;

    #
    # Reset current anchor href to empty string and clear flag that
    # indicates we are inside an anchor
    #
    $current_a_href = "";
    $inside_anchor = 0;
    $image_found_inside_anchor = 0;

    #
    # Destroy the text handler that was used to save the text
    # portion of the anchor tag.
    #
    Destroy_Text_Handler($self, "a");
}

#***********************************************************************
#
# Name: End_Title_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the end title tag.
#
#***********************************************************************
sub End_Title_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($attr, $protocol, $domain, $file_path, $query, $url);
    my ($invalid_title, $clean_text);

    #
    # Get all the text found within the title tag
    #
    if ( ! $have_text_handler ) {
        print "End title tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, " "));
    $clean_text = decode_entities($clean_text);
    print "End_Title_Tag_Handler, title = \"$clean_text\"\n" if $debug;

    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<title>", $line, $column, $clean_text);

    #
    # Are we inside the <head></head> section ?
    #
    if ( $in_head_tag ) {
        #
        # Is the title an empty string ?
        #
        if ( $clean_text eq "" ) {
            Record_Result("WCAG_2.0-F25", $line, $column, $text,
                          String_Value("Missing text in") . "<title>");
        }
        #
        # Is title too long (perhaps it is a paragraph).
        # This isn't an exact test, what we want to find is if the title
        # is descriptive.  A very long title would not likely be descriptive,
        # it may be more of a complete sentense or a paragraph.
        #
        elsif ( length($clean_text) > $max_heading_title_length ) {
            Record_Result("WCAG_2.0-H25", $line, $column,
                          $text, String_Value("Heading text greater than 500 characters") . " \"$clean_text\"");
        }
        else {
            #
            # See if the title is the same as the file name from the URL
            #
            ($protocol, $domain, $file_path, $query, $url) = URL_Check_Parse_URL($current_url);
            $file_path =~ s/^.*\///g;
            if ( lc($clean_text) eq lc($file_path) ) {
                Record_Result("WCAG_2.0-F25", $line, $column, $text,
                              String_Value("Invalid title") . " '$clean_text'");
            }

            #
            # Check the value of the title to see if it is an invalid title.
            # See if it is the default place holder title value generated
            # by a number of authoring tools.  Invalid titles may include
            # "untitled", "new document", ...
            #
            if ( defined($testcase_data{"WCAG_2.0-F25"}) ) {
                foreach $invalid_title (split(/\n/, $testcase_data{"WCAG_2.0-F25"})) {
                    #
                    # Do we have a match on the invalid title text ?
                    #
                    if ( $clean_text =~ /^$invalid_title$/i ) {
                        Record_Result("WCAG_2.0-F25", $line, $column, $text,
                                      String_Value("Invalid title text value") .
                                      " '$clean_text'");
                    }
                }
            }
        }
    }

    #
    # Destroy the text handler that was used to save the text
    # portion of the title tag.
    #
    Destroy_Text_Handler($self, "title");
}

#***********************************************************************
#
# Name: Check_End_Tag_Order
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks end tag ordering.  It checks to see if the
# supplied end tag is valid, and that it matches the last start tag.
# It also fills in implicit end tags where an explicit end tag is 
# optional.
#
#***********************************************************************
sub Check_End_Tag_Order {
    my ( $self, $tagname, $line, $column, $text, @attr ) = @_;

    my ($last_start_tag, $tag_item, $location, $tag_list);
    my ($tag_error) = 0;

    #
    # Is this an end tag that has no start tag ?
    #
    print "Check_End_Tag_Order for $tagname\n" if $debug;
    if ( defined($html_tags_with_no_end_tag{$tagname}) ) {
        print "End tag, $tagname, found when forbidden\n" if $debug;
        Record_Result("WCAG_2.0-H74", $line, $column, $text,
                      String_Value("End tag") . " </$tagname> " .
                      String_Value("forbidden"));
        $wcag_2_0_h74_reported = 1;
    }
    else {
        #
        # Does this tag match the one on the top of the tag stack ?
        # If not we have start/end tags out of order.
        # Report this error only once per document.
        #
        $tag_list = join(" ", @tag_order_stack);
        print "Current tag stack $tag_list\n" if $debug;
        $tag_item = pop(@tag_order_stack);

        #
        # Split tag item into tag and location
        #
        ($last_start_tag, $location) = split(/\s+/, $tag_item, 2);
        print "Pop tag off tag order stack $last_start_tag at $location\n" if $debug;
        print "Check tag with tag order stack $tagname at $line:$column\n" if $debug;

        #
        # Did we find the tag we were expecting.
        #
        if ( $tagname ne $last_start_tag ) {
            #
            # Possible tag out of order, check for an implicit end tag
            # of the last tag on the stack
            #
            if ( defined($$implicit_end_tag_end_handler{$last_start_tag}) ) {
                #
                # Is the this tag in the list of tags that
                # implicitly close the last tag in the tag stack ?
                #
                $tag_list = $$implicit_end_tag_end_handler{$last_start_tag};
                if ( index($tag_list, " $tagname ") != -1 ) {
                    #
                    # Push tag item back onto tag stack, it will be checked
                    # again in the following call to End_Handler
                    #
                    push(@tag_order_stack, $tag_item);

                    #
                    # Call End Handler to close the last tag
                    #
                    print "Tag $last_start_tag implicitly closed by $tagname\n" if $debug;
                    End_Handler($self, $last_start_tag, $line, $column, "", ());

                    #
                    # Check the end tag order again after implicitly
                    # ending the last start tag above.
                    #
                    print "Check tag order again after implicitly ending $last_start_tag\n" if $debug;
                    Check_End_Tag_Order($self, $tagname, $line, $column,
                                        $text, @attr);
                }
                else {
                    #
                    # The last tag is not implicitly closed by this tag.
                    #
                    print "Tag $last_start_tag not implicitly closed by $tagname\n" if $debug;
                    print "Tag is implicitly closed by $tag_list\n" if $debug;
                    $tag_error = 1;
                }
            }
            else {
                #
                # No implicit end tag possible, we have a tag ordering
                # error.
                #
                print "No tags implicitly closed by $last_start_tag\n" if $debug;
                $tag_error = 1;
            }
        }

        #
        # Do we record an error ? We only report it once for the URL.
        #
        if ( $tag_error && (! $wcag_2_0_h74_reported) ) {
            print "Start/End tags out of order, found end $tagname, expecting $last_start_tag\n" if $debug;
            Record_Result("WCAG_2.0-H74", $line, $column, $text,
                          String_Value("Expecting end tag") . " </$last_start_tag> " .
                          String_Value("found") . " </$tagname> " .
                          String_Value("started at line:column") .
                          $location);
            $wcag_2_0_h74_reported = 1;
        }
    }

    #
    # Save last tag name
    #
    $last_tag = $tagname;
}

#***********************************************************************
#
# Name: End_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end of HTML tags.
#
#***********************************************************************
sub End_Handler {
    my ( $self, $tagname, $line, $column, $text, @attr ) = @_;

    my (%attr_hash) = @attr;
    my (@anchor_text_list, $n);

    #
    # Pop last color value from the stack if this tag has possible
    # color attributes (if it didn't have any actual attributes it
    # would have been 'assigned' an attribute in the start handler, so
    # it is safe to pop a color off the stack).
    #
    print "End_Handler tag $tagname at $line:$column\n" if $debug;
    if ( index( $tags_with_color_attribute, " $tagname " ) != -1 ) {
        $current_color = pop(@color_stack);
        $n = @color_stack;
        $current_color = $color_stack[$n];

        #
        # If we have too many end tags, we will get an undefined colour.
        # Reset colour to "" if it is not defined.
        #
        if ( ! defined($current_color) ) {
            $current_color = "";
        }
    }

    #
    # Check end tag order, does this end tag close the last open
    # tag ?
    #
    Check_End_Tag_Order($self, $tagname, $line, $column, $text, @attr);

    #
    # If this is an end anchor tag, reset current anchor href to empty string
    #
    if ( $tagname eq "a" ) {

        #
        # See if there are any problems with the anchor tag
        #
        End_Anchor_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check abbr tag
    #
    elsif ( $tagname eq "abbr" ) {
        End_Abbr_Acronym_Tag_handler( $self, $tagname, $line, $column, $text);
    }

    #
    # Check acronym tag
    #
    elsif ( $tagname eq "acronym" ) {
        End_Abbr_Acronym_Tag_handler( $self, $tagname, $line, $column, $text);
    }

    #
    # Check applet tag
    #
    elsif ( $tagname eq "applet" ) {
        End_Applet_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check b tag
    #
    elsif ( $tagname eq "b" ) {
        End_Emphasis_Tag_Handler($self, $tagname, $line, $column, $text);
    }

    #
    # Check blockquote tag
    #
    elsif ( $tagname eq "blockquote" ) {
        End_Blockquote_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check button tag
    #
    elsif ( $tagname eq "button" ) {
        End_Button_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check caption tag
    #
    elsif ( $tagname eq "caption" ) {
        End_Caption_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check dl tag
    #
    elsif ( $tagname eq "dl" ) {
        End_Dl_Tag_Handler($line, $column, $text);
    }

    #
    # Check dt tag
    #
    elsif ( $tagname eq "dt" ) {
        End_Dt_Tag_Handler( $self, $line, $column, $text );
    }

    #
    # Check em tag
    #
    elsif ( $tagname eq "em" ) {
        End_Emphasis_Tag_Handler($self, $tagname, $line, $column, $text);
    }

    #
    # Check fieldset tag
    #
    elsif ( $tagname eq "fieldset" ) {
        End_Fieldset_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check figcaption tag
    #
    elsif ( $tagname eq "figcaption" ) {
        End_Figcaption_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check figure tag
    #
    elsif ( $tagname eq "figure" ) {
        End_Figure_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check form tag
    #
    elsif ( $tagname eq "form" ) {
        End_Form_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check heading tag
    #
    elsif ( $tagname =~ /^h[0-9]?$/ ) {
        End_H_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check head tag
    #
    elsif ( $tagname eq "head" ) {
        End_Head_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check i tag
    #
    elsif ( $tagname eq "i" ) {
        End_Emphasis_Tag_Handler($self, $tagname, $line, $column, $text);
    }

    #
    # Check label tag
    #
    elsif ( $tagname eq "label" ) {
        End_Label_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check frame legend
    #
    elsif ( $tagname eq "legend" ) {
        End_Legend_Tag_Handler( $self, $line, $column, $text);
    }

    #
    # Check li tag
    #
    elsif ( $tagname eq "li" ) {
        End_Li_Tag_Handler( $self, $line, $column, $text );
    }

    #
    # Check object tag
    #
    elsif ( $tagname eq "object" ) {
        End_Object_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check ol tag
    #
    elsif ( $tagname eq "ol" ) {
        End_Ol_Ul_Tag_Handler($tagname, $line, $column, $text);
    }

    #
    # Check option tag
    #
    elsif ( $tagname eq "option" ) {
        End_Option_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check p tag
    #
    elsif ( $tagname eq "p" ) {
        End_P_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check q tag
    #
    elsif ( $tagname eq "q" ) {
        End_Q_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check strong tag
    #
    elsif ( $tagname eq "strong" ) {
        End_Emphasis_Tag_Handler($self, $tagname, $line, $column, $text);
    }

    #
    # Check table tag
    #
    elsif ( $tagname eq "table" ) {
        End_Table_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check td tag
    #
    elsif ( $tagname eq "td" ) {

        #
        # See if table headers were used
        #
        End_TD_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check th tag
    #
    elsif ( $tagname eq "th" ) {
        End_TH_Tag_Handler( $self, $line, $column, $text );
    }

    #
    # Check thead tag
    #
    elsif ( $tagname eq "thead" ) {

        #
        # No longer in a <thead> .. </thead> pair
        #
        if ( $table_nesting_index >= 0 ) {
            $inside_thead[$table_nesting_index] = 0;
        }
    }

    #
    # Check title tag
    #
    elsif ( $tagname eq "title" ) {
        End_Title_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check ul tag
    #
    elsif ( $tagname eq "ul" ) {
        End_Ol_Ul_Tag_Handler($tagname, $line, $column, $text);
    }

    #
    # Check for tags that are not handled above, yet must still
    # contain some text between the start and end tags.
    #
    elsif ( defined($tags_that_must_have_content{$tagname}) ) {
        End_Tag_Must_Have_Content_handler( $self, $tagname, $line, $column,
                                           $text);
    }

    #
    # Is this tag the last one that had a language ?
    #
    if ( $tagname eq $last_lang_tag ) {
        #
        # Pop the last language and tag name from the stacks
        #
        print "End $tagname found\n" if $debug;
        $current_lang = pop(@lang_stack);
        $last_lang_tag = pop(@tag_lang_stack);
        if ( ! defined($last_lang_tag) ) {
            print "last_lang_tag not defined\n" if $debug;
        }
        print "Pop $last_lang_tag, $current_lang from language stack\n" if $debug;
    }

    #
    # If we previously found an onclick/onkeypress, pop this tag off the stack
    #
    if ( $found_onclick_onkeypress ) {
        pop(@onclick_onkeypress_tag);

        #
        # Have we popped all the tags from the stack ? 
        #
        if ( @onclick_onkeypress_tag == 0 ) {
            #
            # If we did not find a focusable item, there is an error
            # as the tag with onclick/onkeypress is acting like a link
            #
            print "End of onclick/onkeypress tag stack\n" if $debug;
            if ( ! $have_focusable_item ) {
                Record_Result("WCAG_2.0-F42", $onclick_onkeypress_line, 
                              $onclick_onkeypress_column,
                              $onclick_onkeypress_text,
                            String_Value("onclick or onkeypress found in tag") .
                              "<$tagname>");
            }

            #
            # Clear onclick/onkeypress flag
            #
            $found_onclick_onkeypress = 0;
        }
    }

    #
    # Check for end of a document section
    #
    $content_section_handler->check_end_tag($tagname, $line, $column);
}

#***********************************************************************
#
# Name: Check_Baseline_Technologies
#
# Parameters: none
#
# Description:
#
#   This function checks that the appropriate baseline technologie is
# used in the web page.
#
#***********************************************************************
sub Check_Baseline_Technologies {

    #
    # Did we not find a DOCTYPE line ?
    #
    if ( $doctype_line == -1 ) {
        #
        # Missing DOCTYPE
        #
        Record_Result("WCAG_2.0-G134", -1, 0, "",
                      String_Value("DOCTYPE missing"));
    }
}

#***********************************************************************
#
# Name: Check_Missing_And_Extra_Labels
#
# Parameters: none
#
# Description:
#
#   This function checks to see if there are ny missing labels (referenced
# but not defined). It also checks for extra labels that were not used.
#
#***********************************************************************
sub Check_Missing_And_Extra_Labels {

    my ($label_id, $line, $column, $comment, $found, $label_for);

    #
    # Are we checking for missing labels ?
    #
    if ( defined($$current_tqa_check_profile{"WCAG_2.0-F68"}) ) {
        #
        # Check that a label is defined for each one referenced
        #
        foreach $label_id (keys %input_id_location) {
            #
            # Did we find a <label> tag with a matching for= value ?
            #
            if ( ! defined($label_for_location{"$label_id"}) ) {
                ($line, $column) = split(/,/, $input_id_location{"$label_id"});
                Record_Result("WCAG_2.0-F68", $line, $column, "",
                              String_Value("No label matching id attribute") .
                              "'$label_id'" . String_Value("for tag") .
                              " <input>");
            }
        }
    }


#
# ****************************************
#
#  Ignore extra labels, they are not necessarily errors.
#
#    #
#    # Are we checking for extra labels ?
#    #
#    if ( defined($$current_tqa_check_profile{"WCAG_2.0-H44"}) ) {
#        #
#        # Check that there is a reference for every label
#        #
#        foreach $label_for (keys %label_for_location) {
#            #
#            # Did we find a reference for this label (i.e. a
#            # id= matching the value) ?
#            #
#            if ( ! defined($input_id_location{"$label_for"}) ) {
#                ($line, $column) = split(/:/, $label_for_location{"$label_for"});
#                Record_Result("WCAG_2.0-H44", $line, $column, "",
#                              String_Value("Unused label, for attribute") .
#                              "'$label_for'" . String_Value("at line:column") .
#                              $label_for_location{"$label_for"});
#            }
#        }
#    }
#
# ****************************************
#
}

#***********************************************************************
#
# Name: Check_Language_Spans
#
# Parameters: none
#
# Description:
#
#   This function checks that the content inside language spans matches
# the language in the span's lang attribute.  Content from all spans with
# the same lang attribute is concetenated together for a single test. This is
# done because the minimum content needed for a language check is 1000
# characters.
#
#***********************************************************************
sub Check_Language_Spans {

    my (%span_language_text, $span_lang, $content_lang, $content);
    my ($lang, $status);
    
    #
    # Get text from all sections of the content (from last
    # call to TextCat_Extract_Text_From_HTML)
    #
    print "Check_Language_Spans\n" if $debug;
    %span_language_text = TextCat_All_Language_Spans();
    
    #
    # Check each span
    #
    while ( ($span_lang, $content) = each %span_language_text ) {
        print "Check span language $span_lang, content length = " .
              length($content) . "\n" if $debug;

        #
        # Convert language code into a 3 character code.
        #
        $span_lang = ISO_639_2_Language_Code($span_lang);

        #
        # Is this a supported language ?
        #
        if ( TextCat_Supported_Language($span_lang) ) {
            #
            # Get language of this content section
            #
            ($content_lang, $lang, $status) = TextCat_Text_Language($content);

            #
            # Does the lang attribute match the content language ?
            #
            print "status = $status, content_lang = $content_lang, span_lang = $span_lang\n" if $debug;
            if ( ($status == 0 ) && ($content_lang ne "" ) &&
                 ($span_lang ne $content_lang) ) {
                print "Span language error\n" if $debug;
                #print "Content = $content\n" if $debug;
                Record_Result("WCAG_2.0-H58", -1, -1, "",
                              String_Value("Span language attribute") .
                              " '$span_lang' " .
                              String_Value("does not match content language") .
                              " '$content_lang'");
            }
        }
        else {
            print "Unsupported language $span_lang\n" if $debug;
        }
    }
}

#***********************************************************************
#
# Name: Check_Document_Errors
#
# Parameters: none
#
# Description:
#
#   This function checks test cases that act on the document as a whole.
#
#***********************************************************************
sub Check_Document_Errors {

    my ($label_id, $line, $column, $comment, $found);
    my ($english_comment, $french_comment, @comment_lines, $name);

    #
    # Do we have an imbalance in the number of <embed> and <noembed>
    # tags ?
    #
    if ( $embed_noembed_count > 0 ) {
        Record_Result("WCAG_2.0-H46", $last_embed_line, $last_embed_col, "",
                      String_Value("No matching noembed for embed"));
    }

    #
    # Did we find a <title> tag in the document ?
    #
    if ( ! $found_title_tag ) {
        Record_Result("WCAG_2.0-H25", -1,  0, "",
                      String_Value("Missing <title> tag"));
    }

    #
    # Did we find the content area ?
    #
    if ( $content_section_found{"CONTENT"} ) {
        #
        # Did we find zero headings ?
        #
        if ( $content_heading_count == 0 ) {
            Record_Result("WCAG_2.0-G130", -1, 0, "",
                          String_Value("No headings found"));
        }
    }
    #
    # Did not find content area, did we find zero headings in the
    # entire document ?
    #
    elsif ( $total_heading_count == 0 ) {
        Record_Result("WCAG_2.0-G130", -1, 0, "",
                      String_Value("No headings found"));
    }

    #
    # Did we find any links in this document ?
    #
    if ( keys(%anchor_text_href_map) == 0 ) {
        #
        # No links found in this document
        #
        Record_Result("WCAG_2.0-G125", -1, 0, "",
                      String_Value("No links found"));
    }

    #
    # Check baseline technologies
    #
    Check_Baseline_Technologies();
}

#***********************************************************************
#
# Name: HTML_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             resp - HTTP::Response object
#             content - HTML content
#
# Description:
#
#   This function runs a number of technical QA checks on HTML content.
#
#***********************************************************************
sub HTML_Check {
    my ( $this_url, $language, $profile, $resp, $content ) = @_;

    my ($parser, @tqa_results_list, $result_object, $testcase);
    my ($lang_code, $lang, $status);

    #
    # Do we have a valid profile ?
    #
    print "HTML_Check: Checking URL $this_url, lanugage = $language, profile = $profile\n" if $debug;
    if ( ! defined($tqa_check_profile_map{$profile}) ) {
        print "HTML_Check: Unknown TQA testcase profile passed $profile\n";
        return(@tqa_results_list);
    }

    #
    # Save URL in global variable
    #
    if ( $this_url =~ /^http/i ) {
        $current_url = $this_url;
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of HTML
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Did we get any content ?
    #
    if ( length($content) > 0 ) {
        #
        # Get content language
        #
        ($lang_code, $lang, $status) = TextCat_HTML_Language($content);

        #
        # Did we get a language from the content ?
        #
        if ( $status == 0 ) {
            #
            # Save language in a global variable
            #
            $current_content_lang_code = $lang_code;

            #
            # Check the language of all spans in the content to see
            # that the language code and content language agree.
            #
            Check_Language_Spans();
        }
        else {
            $current_content_lang_code = "";
        }

        #
        # Create a document parser
        #
        $parser = HTML::Parser->new;

        #
        # Create a content section object
        #
        $content_section_handler = content_sections->new;

        #
        # Add handlers for some of the HTML tags
        #
        $parser->handler(
            declaration => \&Declaration_Handler,
            "text,line,column"
        );
        $parser->handler(
            start => \&Start_Handler,
            "self,\"$language\",tagname,line,column,text,skipped_text,attrseq,\@attr"
        );
        $parser->handler(
            end => \&End_Handler,
            "self,tagname,line,column,text,\@attr"
        );

        #
        # Parse the content.
        #
        $parser->parse($content);
    }
    else {
        print "No content passed to HTML_Checker\n" if $debug;
        return(@tqa_results_list);
    }

    #
    # Check for document global errors (e.g. missing labels)
    #
    Check_Document_Errors();

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "HTML_HTML_Check results\n";
        foreach $result_object (@tqa_results_list) {
            print "Testcase: " . $result_object->testcase;
            print "  status   = " . $result_object->status . "\n";
            print "  message  = " . $result_object->message . "\n";
        }
    }

    #
    # Reset valid HTML flag to unknown before we are called again
    #
    $is_valid_html = -1;

    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Trim_Whitespace
#
# Parameters: string
#
# Description:
#
#   This function removes leading and trailing whitespace from a string.
# It also collapses multiple whitespace sequences into a single
# white space.
#
#***********************************************************************
sub Trim_Whitespace {
    my ($string) = @_;

    #
    # Remove leading & trailing whitespace
    #
    $string =~ s/\r*$/ /g;
    $string =~ s/\n*$/ /g;
    $string =~ s/\&nbsp;/ /g;
    $string =~ s/^\s*//g;
    $string =~ s/\s*$//g;
    #
    # Compress whitespace
    #
    $string =~ s/\s+/ /g;

    #
    # Return trimmed string.
    #
    return($string);
}

#***********************************************************************
#
# Name: Import_Packages
#
# Parameters: none
#
# Description:
#
#   This function imports any required packages that cannot
# be handled via use statements.
#
#***********************************************************************
sub Import_Packages {

    my ($package);
    my (@package_list) = ("crawler", "css_check", "image_details",
                          "css_validate", "javascript_validate",
                          "javascript_check", "tqa_testcases",
                          "url_check", "tqa_result_object", "textcat",
                          "pdf_check", "content_sections", "language_map",
                          "crawler");

    #
    # Import packages, we don't use a 'use' statement as these packages
    # may not be in the INC path.
    #
    foreach $package (@package_list) {
        #
        # Import the package routines.
        #
        if ( ! defined($INC{$package}) ) {
            require "$package.pm";
        }
        $package->import();
    }
}

#***********************************************************************
#
# Mainline
#
#***********************************************************************

#
# Get our program directory, where we find supporting files
#
$program_dir  = dirname($0);
$program_name = basename($0);

#
# If directory is '.', search the PATH to see where we were found
#
if ( $program_dir eq "." ) {
    $paths = $ENV{"PATH"};
    @paths = split( /:/, $paths );

    #
    # Loop through path until we find ourselves
    #
    foreach $this_path (@paths) {
        if ( -x "$this_path/$program_name" ) {
            $program_dir = $this_path;
            last;
        }
    }
}

#
# Import required packages
#
Import_Packages;

#
# Return true to indicate we loaded successfully
#
return 1;

