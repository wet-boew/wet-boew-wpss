#***********************************************************************
#
# Name:   html_check.pm
#
# $Revision: 7633 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/TQA_Check/Tools/html_check.pm $
# $Date: 2016-07-22 03:07:27 -0400 (Fri, 22 Jul 2016) $
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
#     HTML_Check_EPUB_File
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

#
# Use WPSS_Tool program modules
#
use content_sections;
use crawler;
use css_check;
use css_validate;
use html_landmark;
use image_details;
use javascript_check;
use javascript_validate;
use language_map;
use pdf_check;
use textcat;
use tqa_result_object;
use tqa_tag_object;
use tqa_testcases;
use url_check;
use xml_ttml_check;
use xml_ttml_text;
use xml_ttml_validate;

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
                  HTML_Check_EPUB_File
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

my (%tqa_check_profile_map, $current_tqa_check_profile,
    $current_a_href, $current_tqa_check_profile_name,
    %input_id_location, %label_for_location, %accesskey_location,
    $table_nesting_index, @table_start_line, @table_header_values,
    @table_start_column, @table_has_headers, @table_summary,
    %test_case_desc_map, $have_text_handler, @text_handler_tag_list,
    @text_handler_all_text_list, $inside_h_tag_set, %anchor_name,
    @text_handler_tag_text_list, %anchor_text_href_map, %anchor_location,
    @text_handler_all_text, @text_handler_tag_text,
    $current_heading_level, %found_legend_tag, $current_text_handler_tag,
    $fieldset_tag_index, @td_attributes, @inside_thead,
    $embed_noembed_count, $last_embed_line, $last_embed_col,
    $object_nest_level, $last_image_alt_text, %object_has_label,
    $current_url, $in_form_tag, $found_input_button, $found_title_tag,
    $found_frame_tag, $doctype_line, $doctype_column, $doctype_label,
    $doctype_language, $doctype_version, $doctype_class, $doctype_text,
    %id_attribute_values, $have_metadata, $results_list_addr,
    $content_heading_count, $total_heading_count,
    $last_radio_checkbox_name, $content_section_handler,
    $current_a_title, %content_section_found, $last_close_tag, $last_open_tag,
    $current_content_lang_code, $inside_label, %last_label_attributes,
    $text_between_tags, $in_head_tag, @tag_order_stack, $wcag_2_0_h74_reported,
    @param_lists, $inside_anchor, $last_label_text, $last_tag,
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
    $inline_style_count, %css_styles, $current_tag_object,
    %input_instance_not_allowed_label, %aria_describedby_location,
    %aria_labelledby_location, %fieldset_input_count,
    $current_a_arialabel, %last_option_attributes, $tag_is_visible,
    $current_tag_styles, $tag_is_hidden, @table_th_td_in_thead_count,
    $modified_content, $first_html_tag_lang, $summary_tag_content,
    @table_th_td_in_tfoot_count, @inside_tfoot, $inside_video,
    %video_track_kind_map, $found_content_after_heading, $in_header_tag,
    %form_id_values, %input_form_id, %audio_track_kind_map, $inside_audio,
    @list_heading_text, $form_count, @content_lines, @table_is_layout,
    %f32_reported, @inside_dd, $main_content_start,
    $current_landmark, $landmark_marker,
);

my ($is_valid_html) = -1;

my ($tags_allowed_events) = " a area button form input select ";
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
my ($html_is_part_of_epub) = 0;

#
# Status codes for text catagorization (taken from textcat.pm)
#
my ($NOT_ENOUGH_TEXT) = -1;
my ($LANGUAGES_TOO_CLOSE) = -2;
my ($INVALID_CONTENT) = -3;
my ($CATAGORIZATION_OK) = 0;

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
#        "track", "track",
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
    "article", "",
    "cite",    "",
    "del",     "",
    "code",    "",
    "dd",      "",
    "dfn",     "",
    "dt",      "",
    "em",      "",
    "ins",     "",
    "li",      "",
    "pre",     "",
    "section", "",
    "strong",  "",
    "sub",     "",
    "sup",     "",
);

#
# Tags that must not have role="resentation". These tags
# are used to convey information or relationships.
#
my (%tags_that_must_not_have_role_presentation) = (
    "a",       1,
    "abbr",    1,
    "address", 1,
    "article", 1,
    "aside",   1,
    "audio",   1,
    "b",       1,
    "bdi",     1,
    "bdo",     1,
    "blockquote", 1,
    "button",  1,
    "canvas",  1,
    "cite",    1,
    "code",    1,
    "caption", 1,
    "data",    1,
    "datalist", 1,
    "dd",      1,
    "del",     1,
    "dfn",     1,
#    "div",     1,
    "dl",      1,
    "dt",      1,
    "em",      1,
    "embed",   1,
    "fieldset",1,
    "figure",  1,
    "footer",  1,
    "form",    1,
    "h1",      1,
    "h2",      1,
    "h3",      1,
    "h4",      1,
    "h5",      1,
    "h6",      1,
    "header",  1,
#    "hr",      1, # A <hr> may be decorative and have role=presentation
    "i",       1,
    "iframe",  1,
#    "img",     1, # Decorative images may have role=presentation
    "input",   1,
    "ins",     1,
    "kbd",     1,
    "keygen",  1,
    "label",   1,
    "legend",  1,
    "li",      1,
    "main",    1,
    "map",     1,
    "mark",    1,
    "math",    1,
    "meter",   1,
    "nav",     1,
    "object",  1,
    "ol",      1,
    "output",  1,
    "p",       1,
    "pre",     1,
    "progress", 1,
    "q",       1,
    "ruby",    1,
    "s",       1,
    "samp",    1,
    "section", 1,
    "select",  1,
    "small",   1,
    "span",    1,
    "strong",   1,
    "sub",     1,
    "sup",     1,
    "svg",     1,
#    "table",   1, # Layout tables can have role=presentation
    "td",      1,
    "textarea", 1,
    "time",    1,
    "title",   1,
    "tr",      1,
    "u",       1,
    "ul",      1,
    "var",     1,
    "video",   1,
    "wbr",     1,
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
  "address", " p ",
  "article", " p ",
  "aside", " p ",
  "blockquote", " p ",
  "dd", " dd dt ",
  "dir", " p ",
  "dl", " p ",
  "dt", " dd dt ",
  "fieldset", " p ",
  "footer", " p ",
  "form", " p ",
  "h1", " p ",
  "h2", " p ",
  "h3", " p ",
  "h4", " p ",
  "h5", " p ",
  "h6", " p ",
  "header", " p ",
  "hgroup", " p ",
  "hr", " p ",
  "li", " li ",
  "menu", " p ",
  "nav", " p ",
  "ol", " p ",
  "p", " p ",
  "pre", " p ",
  "rp", " rp rt ",
  "rt", " rp rt ",
  "table", " p ",
  "tbody", " tbody tfoot ",
  "thead", " tbody tfoot ",
  "tfoot", " tbody ",
  "td", " td th ",
  "th", " td th ",
  "tr", " tr ",
  "track", " source track ",
  "ul", " p ",
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
  "track", " video ",
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
# Set of tags that do not act as word boundaries. This is used to control
# whether or not whitespace is added to text handlers to seperate text within
# these tags from text of the container tags.
#
my (%non_word_boundary_tag) = (
    "del", 1,
    "ins", 1,
    "sub", 1,
    "sup", 1,
);

#
# Set of tags who's text is not included in it's containers text
#
my (%tag_content_not_included_in_parent) = (
#    "summary", 1,
);

#
# List of tags that are allowed an alt attribute
#  http://www.w3.org/TR/html5/index.html#attributes-1
#
my (%tags_allowed_alt_attribute) = (
    "area", 1,
    "img", 1,
    "input", 1,
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
$valid_html5_rel_values{"link"} .= "apple-touch-icon apple-touch-icon-precomposed apple-touch-startup-image attachment canonical category dns-prefetch EditURI home index meta openid.delegate openid.server openid2.local_id openid2.provider p3pv1 pgpkey pingback prerender profile publisher rendition servive shortlink sidebar sitemap timesheet widget wlwmanifest image_src  http://docs.oasis-open.org/ns/cmis/link/200908/acl stylesheet/less schema.dc schema.dcterms ";

#
# Values for the rel attribute of tags
#   http://microformats.org/wiki/rel-pronunciation
#   Date: 2017-11-19
#
$valid_html5_rel_values{"link"} .= "pronunciation ";

my ($valid_rel_values);

#
# WAI-ARIA landmark role values
#  http://www.w3.org/TR/wai-aria/roles#landmark_roles
#
my (%landmark_role) = (
    "application", 1,
    "banner", 1,
    "complementary", 1,
    "contentinfo", 1,
    "form", 1,
    "main", 1,
    "navigation", 1,
    "region", 1,
    "search", 1,
);

#
# Required context roles for WAI-ARIA role values
#   https://www.w3.org/TR/wai-aria-1.1/
# Key is a role and the value is a space seperated list of context roles.
#
my (%aria_required_context_roles) = (
    "cell",         "row",
    "columnheader", "row",
    "gridcell",     "row",
    "listitem",     "group list",
    "menuitem",     "group menu menubar",
    "menuitemcheckbox", "menu menubar",
    "menuitemradio", "group menu menubar",
    "option",       "listbox",
    "row",          "grid rowgroup table treegrid",
    "rowgroup",     "grid table treegrid",
    "rowheader",    "row",
    "tab",          "tablist",
    "treeitem",     "group tree",
);

#
# Used in roles for WAI-ARIA attributes
#   https://www.w3.org/TR/wai-aria-1.1/
# Key is an attribute name and the value is a space seperated list of roles.
#
my (%aria_used_in_roles) = (
    "aria-activedescendant", "application composite group textbox",
    "aria-selected",         "gridcell option row tab",
    "aria-autocomplete",     "combobox textbox",
    "aria-checked",          "checkbox option radio switch",
    "aria-colcount",         "table",
    "aria-colindex",         "cell row",
    "aria-colspan",          "cell",
    "aria-expanded",         "button combobox document link section sectionhead window",
    "aria-level",            "grid heading listitem row tablist",
    
);

#
# Implicit WAI-ARIA roles for HTML tags
#   https://www.w3.org/TR/html-aria/#docconformance
# Key is a HTML tag and the value is a space separated list of implicit roles.
#
my (%implicit_aria_roles) = (
    "a",                "link",
    "area",             "link",
    "article",          "article",
    "aside",            "complementary",
    "body",             "document",
    "button",           "button",
    "datalist",         "listbox",
    "dd",               "definition",
    "details",          "group",
    "dl",               "list",
    "dialog",           "dialog",
    "dt",               "listitem",
    "fieldset",         "group",
    "figure",           "figure",
    "footer",           "contentinfo",
    "form",             "form",
    "h1",               "heading",
    "h2",               "heading",
    "h3",               "heading",
    "h4",               "heading",
    "h5",               "heading",
    "h6",               "heading",
    "header",           "banner",
    "img",              "img",
    "input",            "button checkbox radio searchbox slider spinbutton textbox",
    "li",               "listitem",
    "link",             "link",
    "main",             "main",
    "math",             "math",
    "menu",             "menu",
    "menuitem",         "menuitem menuitemcheckbox menuitemradio",
    "nav",              "navigation",
    "ol",               "list",
    "optgroup",         "group",
    "option",           "option",
    "output",           "status",
    "progress",         "progressbar",
    "section",          "region",
    "select",           "combobox listbox",
    "summary",          "button",
    "table",            "table",
    "textarea",         "textbox",
    "tbody",            "rowgroup",
    "thead",            "rowgroup",
    "tfoot",            "rowgroup",
    "td",               "cell",
    "th",               "columnheader rowheader",
    "tr",               "row",
    "ul",               "list",
);

#
#
# NOTE: The following data structure is not being used. It is
# left here for potential use in determining the role of a HTML
# tag in the case that the tag may have different roles based
# on other attributes or values.
#
# Conditions for implicit WAI-ARIA roles for HTML tags
#   https://www.w3.org/TR/html-aria/
# Key is a HTML tag and the value is a condition and role.
# The conditions are coded as a colon seperated list of condition
# type, value(s) and the implicit role. If there are multiple
# conditions, the conditions are separated by spaces.
# The condition types are
#
#    attr:<name>:<role> - attribute required on tag
#      <name> - name of attribute
#      <role> - implicit WAI-ARIA role
#
#    attrvalue:<name>:<value>:<role> - attribute with specific value required
#      <name> - name of attribute
#      <value> - specific value
#      <role> - implicit WAI-ARIA role
#
#
my (%implicit_aria_role_conditions) = (
    "a",                "attr:href:link",
    "area",             "attr:href:link",
    "button",           "attrvalue:type:menu:button",
    "input",            "attrvalue:type:button:button " .
                        "attrvalue:type:checkbox:checkbox " .
                        "attrvalue:type:email:textbox " .
                        "attrvalue:type:image:button " .
                        "attrvalue:type:number:spinbutton " .
                        "attrvalue:type:radio:radio " .
                        "attrvalue:type:range:slider" .
                        "attrvalue:type:reset:button " .
                        "attrvalue:type:search:searchbox " .
                        "attrvalue:type:submit:button " .
                        "attrvalue:type:tel:textbox " .
                        "attrvalue:type:text:textbox " .
                        "attrvalue:type:url:textbox",
    "link",             "attr:href:link",
    "menuitem",         "attrvalue:type:command:menuitem " .
                        "attrvalue:type:checkbox:menuitemcheckbox " .
                        "attrvalue:type:radio:menuitemradio",
);

#
# Tags for which we ignore any id attribute to suppress
# any WCAG_2.0-F77 errors.
#
my (%tags_to_ignore_id_attribute) = (
    "script",  1,
);

#
# String table for error strings.
#
my %string_table_en = (
    "Alt attribute not allowed on this tag", "'alt' attribute not allowed on this tag.",
    "Anchor and image alt text the same", "Anchor and image 'alt' text the same",
    "Anchor text is a URL",          "Anchor text is a URL",
    "Anchor text same as href",      "Anchor text same as 'href'",
    "Anchor text same as title",     "Anchor text same as 'title'",
    "Anchor title same as href",     "Anchor 'title' same as 'href'",
    "and",                           "and",
    "at line:column",                " at (line:column) ",
    "Blinking text in",              "Blinking text in ",
    "Broken link in cite for",       "Broken link in 'cite' for ",
    "Broken link in longdesc for",   "Broken link in 'longdesc' for ",
    "Broken link in src for",        "Broken link in 'src' for ",
    "caption found in layout table", "<caption> found in layout table",
    "click here link found",         "'click here' link found",
    "color is",                      " color is ",
    "Combining adjacent image and text links for the same resource",   "Combining adjacent image and text links for the same resource",
    "Content does not contain letters for", "Content does not contain letters for ",
    "Content referenced by",         "Content referenced by",
    "Content same as title for",     "Content same as 'title' for ",
    "Content type does not match",   "Content type does not match",
    "Content values do not match for",  "Content values do not match for ",
    "defined at",                    "defined at (line:column)",
    "Deprecated attribute found",    "Deprecated attribute found ",
    "Deprecated tag found",          "Deprecated tag found ",
    "DOCTYPE missing",               "DOCTYPE missing",
    "does not match content language",  "does not match content language",
    "does not match previous value", "does not match previous value",
    "Duplicate accesskey",           "Duplicate 'accesskey' ",
    "Duplicate anchor name",         "Duplicate anchor name ",
    "Duplicate attribute",           "Duplicate attribute ",
    "Duplicate id in headers",       "Duplicate 'id' in 'headers'",
    "Duplicate id",                  "Duplicate 'id' ",
    "Duplicate label id",            "Duplicate <label> 'id' ",
    "Duplicate table summary and caption", "Duplicate table 'summary' and <caption>",
    "Duplicate",                     "Duplicate",
    "E-mail domain",                 "E-mail domain ",
    "End tag",                       "End tag",
    "Expecting end tag",             "Expecting end tag",
    "expecting one of",              "expecting one of ",
    "Fails validation",              "Fails validation, see validation results for details.",
    "followed by",                   " followed by ",
    "for tag",                       " for tag ",
    "for",                           "for ",
    "forbidden",                     "forbidden",
    "found in header",               "found in header",
    "found inside of link",          "found inside of link",
    "Found label before input type", "Found <label> before <input> type ",
    "found outside of a form",       "found outside of a <form>",
    "Found tag",                     "Found tag ",
    "Found",                         "Found",
    "found",                         "found",
    "GIF animation exceeds 5 seconds",  "GIF animation exceeds 5 seconds",
    "GIF flashes more than 3 times in 1 second", "GIF flashes more than 3 times in 1 second",
    "Header defined at",             "Header defined at (line:column)",
    "Heading text greater than 500 characters",  "Heading text greater than 500 characters",
    "HTML language attribute",       "HTML language attribute",
    "id defined at",                 "'id' defined at (line:column)",
    "Image alt same as src",         "Image 'alt' same as 'src'",
    "in tag used to convey information or relationships", "in tag used to convey information or relationships",
    "in tag",                        " in tag ",
    "in",                            " in ",
    "in decorative image",           " in decorative image.",
    "Insufficient color contrast for tag",                 "Insufficient color contrast for tag ",
    "Invalid alt text value",        "Invalid 'alt' text value",
    "Invalid aria-label text value", "Invalid 'aria-label' text value",
    "Invalid attribute combination found", "Invalid attribute combination found",
    "Invalid content for",           "Invalid content for ",
    "Invalid CSS file referenced",   "Invalid CSS file referenced",
    "Invalid rel value",             "Invalid 'rel' value",
    "Invalid title text value",      "Invalid 'title' text value",
    "Invalid title",                 "Invalid title",
    "Invalid URL in longdesc for",   "Invalid URL in 'longdesc' for ",
    "Invalid URL in src for",        "Invalid URL in 'src' for ",
    "is hidden",                     "is hidden",
    "is not equal to last level",    " is not equal to last level ",
    "is not visible",                "is not visible",
    "Label found for hidden input",  "<label> found for <input type=\"hidden\">",
    "label not allowed before",      "<label> not allowed before ",
    "label not allowed for",         "<label> not allowed for ",
    "Label not explicitly associated to", "Label not explicitly associated to ",
    "Label referenced by",           "<label> referenced by",
    "Link contains JavaScript",      "Link contains JavaScript",
    "Link inside of label",          "Link inside of <label>",
    "link",                          "link",
    "Meta refresh with timeout",     "Meta 'refresh' with timeout ",
    "Meta viewport maximum-scale less than 5.0", "Meta viewport maximum-scale less than 5.0",
    "Meta viewport with user-scalable disabled", "Meta viewport with user-scalable disabled",
    "Metadata missing",              "Metadata missing",
    "Mismatching lang and xml:lang attributes", "Mismatching 'lang' and 'xml:lang' attributes",
    "Missing <title> tag",           "Missing <title> tag",
    "Missing alt attribute for",     "Missing 'alt' attribute for ",
    "Missing alt content for",       "Missing 'alt' content for ",
    "Missing alt or text alternative for",     "Missing 'alt' or text alternative for ",
    "Missing alt or title in",       "Missing 'alt' or 'title' in ",
    "Missing cite content for",      "Missing 'cite' content for ",
    "Missing close tag for",         "Missing close tag for",
    "Missing content before list",   "Missing content before list",
    "Missing content in",            "Missing content in ",
    "Missing event handler from pair", "Missing event handler from pair ",
    "Missing fieldset",              "Missing <fieldset> tag",
    "Missing href, id, name or xlink in <a>",  "Missing href, id, name or xlink in <a>",
    "Missing html language attribute",  "Missing <html> attribute",
    "Missing id content for",        "Missing 'id' content for ",
    "Missing label before",          "Missing <label> before ",
    "Missing label id or title for", "Missing <label> 'id' or 'title' for ",
    "Missing lang attribute",        "Missing 'lang' attribute ",
    "Missing longdesc content for",  "Missing 'longdesc' content for ",
    "Missing rel attribute in",      "Missing 'rel' attribute in ",
    "Missing rel value in",          "Missing 'rel' value in ",
    "Missing required context role for", "Missing required context role for",
    "Missing required context role for implicit role", "Missing required context role for implicit role",
    "Missing required context role for WAI-ARIA attribute", "Missing required context role for WAI-ARIA attribute",
    "Missing src attribute",         "Missing 'src' attribute ",
    "Missing src value",             "Missing 'src' value ",
    "Missing table summary",         "Missing table 'summary'",
    "Missing template comment",      "content",
    "Missing text in table header",  "Missing text in table header ",
    "Missing text in",               "Missing text in ",
    "Missing title attribute for",   "Missing 'title' attribute for ",
    "Missing title content for",     "Missing 'title' content for ",
    "Missing value attribute in",    "Missing 'value' attribute in ",
    "Missing value in",              "Missing value in ",
    "Missing xml:lang attribute",    "Missing 'xml:lang' attribute ",
    "Missing",                       "Missing",
    "Mouse only event handlers found",  "Mouse only event handlers found",
    "Multiple instances of",         "Multiple instances of",
    "Multiple links with same anchor text", "Multiple links with same anchor text ",
    "Multiple links with same title text", "Multiple links with same 'title' text ",
    "Multiple main content areas found, previous instance found", "Multiple main content areas found, previous instance found",
    "New heading level",             "New heading level ",
    "No button found in form",       "No button found in form",
    "No captions found for",         "No captions found for",
    "No closed caption content found", "No closed caption content found",
    "No content found in track",     "No content found in track",
    "No dt found in list",           "No <dt> found in list ",
    "No form found with",            "No form found with",
    "No headers found inside thead", "No headers found inside <thead>",
    "No headings found",             "No headings found in content area",
    "No label for",                  "No <label> for ",
    "No label matching id attribute","No <label> matching 'id' attribute ",
    "No legend found in fieldset",   "No <legend> found in <fieldset>",
    "No li found in list",           "No <li> found in list ",
    "No links found",                "No links found",
    "No matching noembed for embed", "No matching <noembed> for <embed>",
    "No table header reference",     "No table header reference",
    "No tag with id attribute",      "No tag with 'id' attribute ",
    "No td, th found inside tfoot",  "No <td>, <th> found inside <tfoot>",
    "Non-decorative image loaded via CSS with", "Non-decorative image loaded via CSS with",
    "Non null title text",           "Non null 'title' text ",
    "not defined within table",      "not defined within <table>",
    "not marked up as a <label>",    "not marked up as a <label>",
    "Null alt on an image",          "Null alt on an image where the image is the only content in a link",
    "onclick or onkeypress found in tag", "'onclick' or 'onkeypress' found in tag ",
    "or",                            " or ",
    "Page redirect not allowed",     "Page redirect not allowed",
    "Page refresh not allowed",      "Page refresh not allowed",
    "Previous instance found at",    "Previous instance found at (line:column) ",
    "Previous label not explicitly associated to", "Previous label not explicitly associated to ",
    "previously found",                 "previously found",
    "Required testcase not executed","Required testcase not executed",
    "Self reference in headers",        "Self reference in 'headers'",
    "Span language attribute",          "Span language attribute",
    "started at line:column",           "started at (line:column) ",
    "summary found in layout table",    "<summary> found in layout table",
    "Table header found in layout table", "Table header found in layout table",
    "Table headers",                  "Table 'headers'",
    "Tag not allowed here",             "Tag not allowed here ",
    "Text styled to appear like a heading", "Text styled to appear like a heading",
    "Text",                             "Text",
    "Title same as id for",               "'title' same as 'id' for ",
    "Title text greater than 500 characters",            "Title text greater than 500 characters",
    "Title values do not match for",    "'title' values do not match for",
    "Unable to determine content language, possible languages are", "Unable to determine content language, possible languages are",
    "Unused label, for attribute",      "Unused <label>, 'for' attribute ",
    "used for decoration",              "used for decoration",
    "Using script to remove focus when focus is received", "Using script to remove focus when focus is received",
    "Using white space characters to control spacing within a word in tag", "Using white space characters to control spacing within a word in tag",
);


#
# String table for error strings (French).
#
my %string_table_fr = (
    "Alt attribute not allowed on this tag", "L'attribut 'alt' pas autorisés sur cette balise.",
    "Anchor and image alt text the same", "Textes de l'ancrage et de l'attribut 'alt' de l'image identiques",
    "Anchor text is a URL",            "Texte d'ancrage est une URL",
    "Anchor text same as href",        "Texte d'ancrage identique à 'href'",
    "Anchor text same as title",       "Texte d'ancrage identique à 'title'",
    "Anchor title same as href",       "'title' d'ancrage identique à 'href'",
    "and",                             "et",
    "at line:column",                  " à (la ligne:colonne) ",
    "Blinking text in",                "Texte clignotant dans ",
    "Broken link in cite for",         "Lien brisé dans l'élément 'cite' pour ",
    "Broken link in longdesc for",     "Lien brisé dans l'élément 'longdesc' pour ",
    "Broken link in src for",          "Lien brisé dans l'élément 'src' pour ",
    "caption found in layout table",   "<caption> trouvé dans la table de mise en page",
    "click here link found",           "Lien 'cliquez ici' retrouvé",
    "color is",                        " la couleur est ",
    "Combining adjacent image and text links for the same resource",   "Combiner en un même lien une image et un intitulé de lien pour la même ressource",
    "Content does not contain letters for", "Contenu ne contient pas des lettres pour ",
    "Content referenced by",           "Contenu référencé par",
    "Content same as title for",       "Contenu et 'title' identiques pour ",
    "Content type does not match",     "Content type does not match",
    "Content values do not match for", "Valeurs contenu ne correspondent pas pour ",
    "defined at",                      "défini à (la ligne:colonne)",
    "Deprecated attribute found",      "Attribut dépréciée retrouvée ",
    "Deprecated tag found",            "Balise dépréciée retrouvée ",
    "DOCTYPE missing",                 "DOCTYPE manquant",
    "does not match content language", "ne correspond pas à la langue de contenu",
    "does not match previous value",   "ne correspond pas à la valeur précédente",
    "Duplicate accesskey",             "Doublon 'accesskey' ",
    "Duplicate anchor name",           "Doublon du nom d'ancrage ",
    "Duplicate attribute",             "Doublon attribut ",
    "Duplicate id in headers",         "Doublon 'id' dans 'headers'",
    "Duplicate id",                    "Doublon 'id' ",
    "Duplicate label id",              "Doublon <label> 'id' ",
    "Duplicate table summary and caption", "Éléments 'summary' et <caption> du tableau en double",
    "Duplicate",                       "Doublon",
    "E-mail domain",                   "Domaine du courriel ",
    "End tag",                         "Balise de fin",
    "Expecting end tag",               "S'attendant balise de fin",
    "expecting one of",                "expectant une de ",
    "Fails validation",                "Échoue la validation, voir les résultats de validation pour plus de détails.",
    "followed by",                     " suivie par ",
    "for tag",                         " pour balise ",
    "for",                             "pour ",
    "forbidden",                       "interdite",
    "found in header",                 "trouvé dans les en-têtes",
    "found inside of link",            "trouvé dans une lien",
    "Found label before input type",   "<label> trouvé devant le type <input> ",
    "found outside of a form",         "trouvé en dehors d'une <form>",
    "Found tag",                       "Balise trouvé ",
    "found",                           "trouvé",
    "Found",                           "Trouvé",
    "GIF animation exceeds 5 seconds", "Clignotement de l'image GIF supérieur à 5 secondes",
    "GIF flashes more than 3 times in 1 second", "Clignotement de l'image GIF supérieur à 3 par seconde",
    "Header defined at",               "En-tête défini à (la ligne:colonne)",
    "Heading text greater than 500 characters",  "Texte du têtes supérieure 500 caractères",
    "HTML language attribute",         "L'attribut du langage HTML",
    "id defined at",                   "'id' défini à (la ligne:colonne)",
    "Image alt same as src",           "'alt' et 'src'identiques pour l'image",
    "in tag used to convey information or relationships", "dans la balise utilisée pour transmettre des informations ou des relations",
    "in tag",                          " dans balise ",
    "in",                              " dans ",
    "in decorative image",             " dans l'image décoratives.",
    "Insufficient color contrast for tag", "Contrast de couleurs insuffisant pour balise ",
    "Invalid alt text value",          "Valeur de texte 'alt' est invalide",
    "Invalid aria-label text value",   "Valeur de texte 'aria-label' est invalide",
    "Invalid attribute combination found", "Combinaison d'attribut non valide trouvé",
    "Invalid content for",             "Contenu invalide pour ",
    "Invalid CSS file referenced",     "Fichier CSS non valide retrouvé",
    "Invalid rel value",               "Valeur de texte 'rel' est invalide",
    "Invalid title text value",        "Valeur de texte 'title' est invalide",
    "Invalid title",                   "Titre invalide",
    "Invalid URL in longdesc for",     "URL non valide dans 'longdesc' pour ",
    "Invalid URL in src for",          "URL non valide dans 'src' pour ",
    "is hidden",                       "est caché",
    "is not equal to last level",      " n'est pas égal à au dernier niveau ",
    "is not visible",                  "est pas visible",
    "Label found for hidden input",    "<label> trouvé pour <input type=\"hidden\">",
    "label not allowed before",        "<label> pas permis avant ",
    "label not allowed for",           "<label> pas permis pour ",
    "Label not explicitly associated to", "Étiquette pas explicitement associée à la ",
    "Label referenced by",             "<label> référencé par",
    "Link contains JavaScript",      "Lien contient du JavaScript",
    "Link inside of label",            "lien dans une <label>",
    "link",                          "lien",
    "Meta refresh with timeout",       "Méta 'refresh' avec délai d'inactivité ",
    "Meta viewport maximum-scale less than 5.0", "Meta viewport maximale échelle inférieure à 5,0",
    "Meta viewport with user-scalable disabled", "Meta viewport utilisateur évolutive désactivée",
    "Metadata missing",              "Métadonnées manquantes",
    "Mismatching lang and xml:lang attributes", "Erreur de correspondance des attributs 'lang' et 'xml:lang'",
    "Missing <title> tag",              "Balise <title> manquant",
    "Missing alt attribute for",     "Attribut 'alt' manquant pour ",
    "Missing alt content for",       "Le contenu de 'alt' est manquant pour ",
    "Missing alt or text alternative for", "Manquant 'alt' ou texte alternatif pour ",
    "Missing alt or title in",         "Attribut 'alt' ou 'title' manquant dans  ",
    "Missing cite content for",        "Contenu de l'élément 'cite' manquant pour ",
    "Missing close tag for",           "Balise de fin manquantes pour",
    "Missing content before list",     "Contenu manquant avant la liste",
    "Missing content in",              "Contenu manquant dans ",
    "Missing event handler from pair", "Gestionnaire d'événements manquant dans la paire ",
    "Missing fieldset",                 "Élément <fieldset> manquant",
    "Missing href, id, name or xlink in <a>", "Attribut href, id, name ou xlink manquant dans <a>",
    "Missing html language attribute","Attribut manquant pour <html>",
    "Missing id content for",        "Contenu de l'élément 'id' manquant pour ",
    "Missing label before",          "Élément <label> manquant avant ",
    "Missing label id or title for", "Éléments 'id' ou 'title' de l'élément <label> manquants pour ",
    "Missing lang attribute",        "Attribut 'lang' manquant ",
    "Missing longdesc content for",  "Contenu de l'élément 'longdesc' manquant pour ",
    "Missing rel attribute in",      "Attribut 'rel' manquant dans ",
    "Missing rel value in",          "Valeur manquante dans 'rel' ",
    "Missing required context role for", "Le rôle de contexte requis manquant pour",
    "Missing required context role for implicit role", "Le rôle de contexte requis manquant pour le rôle implicite",
    "Missing required context role for WAI-ARIA attribute", "Rôle de contexte requis manquant pour l'attribut WAI-ARIA",
    "Missing src attribute",         "Valeur manquante dans 'src' ",
    "Missing src value",             "Missing 'src' value ",
    "Missing table summary",         "Résumé de tableau manquant",
    "Missing template comment",      "Commentaire manquant dans le modèle",
    "Missing text in table header",  "Texte manquant tête de tableau ",
    "Missing text in",               "Texte manquant dans ",
    "Missing title attribute for",   "Attribut 'title' manquant pour ",
    "Missing title content for",     "Contenu de l'élément 'title' manquant pour ",
    "Missing value attribute in",    "Attribut 'value' manquant dans ",
    "Missing value in",              "Valeur manquante dans ",
    "Missing xml:lang attribute",    "Attribut 'xml:lang' manquant ",
    "Missing",                       "Manquantes",
    "Mouse only event handlers found", "Gestionnaires de la souris ne se trouve que l'événement",
    "Multiple instances of",         "Plusieurs instances de",
    "Multiple links with same anchor text",  "Liens multiples avec la même texte de lien ",
    "Multiple links with same title text",  "Liens multiples avec la même texte de 'title' ",
    "Multiple main content areas found, previous instance found", "Plusieurs domaines de contenu principal ont été trouvés, l'instance précédente a été trouvée",
    "New heading level",             "Nouveau niveau d'en-tête ",
    "No button found in form",       "Aucun bouton trouvé dans le <form>",
    "No captions found for",         "Pas de sous-titres trouvés pour",
    "No closed caption content found", "Aucun de sous-titrage trouvé",
    "No content found in track",     "Contenu manquant dans <track>",
    "No dt found in list",           "Pas de <dt> trouvé dans la liste ",
    "No form found with",            "Pas de <form> trouvé avec",
    "No headers found inside thead", "Pas de têtes trouvées à l'intérieur de <thead>",
    "No headings found",             "Pas des têtes qui se trouvent dans la zone de contenu",
    "No label for",                  "Aucun <label> pour ",
    "No label matching id attribute","Aucun <label> correspondant à l'attribut 'id' ",
    "No legend found in fieldset",   "Aucune <legend> retrouvé dans le <fieldset>",
    "No li found in list",           "Pas de <li> trouvé dans la liste ",
    "No links found",                "Pas des liens qui se trouvent",
    "No matching noembed for embed", "Aucun <noembed> correspondant à <embed>",
    "No table header reference",     "Aucun en-tête de tableau retrouvé",
    "No tag with id attribute",      "Aucon balise avec l'attribut 'id'",
    "No td, th found inside tfoot",  "Pas de <td>, <th> trouve à l'intérieur de <tfoot>",
    "Non-decorative image loaded via CSS with", "Image non-décoratif chargé par CSS avec",
    "Non null title text",           "Non le texte 'title' nuls ",
    "not defined within table",      "pas défini dans le <table>",
    "not marked up as a <label>",    "pas marqué comme un <label>",
    "Null alt on an image",          "Utiliser un attribut alt vide pour une image qui est le seul contenu d'un lien",
    "onclick or onkeypress found in tag", "'onclick' ou 'onkeypress' trouvé dans la balise ",
    "or",                            " ou ",
    "Page redirect not allowed",     "Page rediriger pas autorisé",
    "Page refresh not allowed",      "Page raffraîchissement pas autorisé",
    "Previous instance found at",    "Instance précédente trouvée à (la ligne:colonne) ",
    "Previous label not explicitly associated to", "Étiquette précédente pas explicitement associée à la ",
    "previously found",                 "trouvé avant",
    "Required testcase not executed","Cas de test requis pas exécuté",
    "Self reference in headers",        "référence auto dans 'headers'",
    "Span language attribute",         "Attribut de langue 'span'",
    "started at line:column",          "a commencé à (la ligne:colonne) ",
    "summary found in layout table", "<summary> trouvé dans la table de mise en page",
    "Table header found in layout table", "En-tête de table trouvée dans la table de mise en page",
    "Table headers",                   "'headers' de tableau",
    "Tag not allowed here",            "Balise pas autorisé ici ",
    "Text styled to appear like a heading", "Texte de style pour apparaître comme un titre",
    "Text",                            "Texte",
    "Title same as id for",               "'title' identique à 'id' pour ",
    "Title text greater than 500 characters",    "Texte du title supérieure 500 caractères",
    "Title values do not match for",   "Valeurs 'title' ne correspondent pas pour ",
    "Unable to determine content language, possible languages are", "Impossible de déterminer la langue du contenu, les langues possibles sont",
    "Unused label, for attribute",      "<label> ne pas utilisé, l'attribut 'for' ",
    "used for decoration",             "utilisé pour la dcoration",
    "Using script to remove focus when focus is received", "Utiliser un script pour enlever le focus lorsque le focus est reçu",
    "Using white space characters to control spacing within a word in tag", "Utiliser des caractères blancs pour contrôler l'espacement à l'intérieur d'un mot dans balise",
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
    
    #
    # Set debug flag for supporting modules
    #
    HTML_Landmark_Debug($debug);
    XML_TTML_Text_Debug($debug);
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
    $current_tqa_check_profile_name = $profile;
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
    $current_a_href        = "";
    $current_heading_level = 0;
    $current_landmark      = "";
    $landmark_marker       = "";
    %label_for_location    = ();
    %accesskey_location    = ();
    %input_id_location     = ();
    %aria_describedby_location = ();
    %aria_labelledby_location = ();
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
    @table_is_layout       = ();
    @table_th_td_in_thead_count = ();
    @table_th_td_in_thead_count = ();
    @missing_table_headers = ();
    @table_header_locations = ();
    $inside_h_tag_set      = 0;
    $inside_video          = 0;
    $inside_audio          = 0;
    %video_track_kind_map  = ();
    %audio_track_kind_map  = ();
    %anchor_text_href_map  = ();
    %anchor_location       = ();
    %anchor_name           = ();
    %found_legend_tag      = ();
    %fieldset_input_count  = ();
    $fieldset_tag_index    = 0;
    $have_text_handler     = 0;
    $current_text_handler_tag = "";
    @text_handler_tag_list = ();
    @text_handler_all_text_list = ();
    @text_handler_tag_text_list = ();
    @text_handler_all_text = ();
    @text_handler_tag_text = ();
    $embed_noembed_count   = 0;
    $object_nest_level     = 0;
    %object_has_label      = ();
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
    $current_a_arialabel   = "";
    $current_content_lang_code = "";
    $inside_label          = 0;
    $last_tag              = "";
    $last_close_tag        = "";
    $last_open_tag         = "";
    %last_label_attributes = ();
    $last_label_text       = "";
    $text_between_tags     = "";
    @tag_order_stack       = ();
    $current_tag_object    = undef;
    $wcag_2_0_h74_reported = 0;
    $wcag_2_0_f70_reported = 0;
    @param_lists           = ();
    $image_found_inside_anchor = 0;
    $inside_anchor         = 0;
    $in_form_tag           = 0;
    $form_count            = 0;
    $number_of_writable_inputs = 0;
    %html_tags_allowed_only_once_location = ();
    $last_a_href           = "";
    $last_a_contains_image = 0;
    %abbr_acronym_text_title_lang_map = ();
    %abbr_acronym_text_title_lang_location = ();
    %abbr_acronym_title_text_lang_map = ();
    %abbr_acronym_title_text_lang_location = ();
    $current_lang          = "eng";
    @lang_stack            = ($current_lang);
    @tag_lang_stack        = ("top");
    $last_lang_tag         = "top";
    @list_item_count       = ();
    $current_list_level    = -1;
    $in_head_tag           = 0;
    $in_header_tag         = 0;
    %legend_text_value     = ();
    $last_heading_text     = "";
    $current_text_handler_tag = "";
    $pseudo_header         = "";
    $emphasis_count        = 0;
    $anchor_inside_emphasis = 0;
    $inline_style_count    = 0;
    %css_styles            = ();
    %input_instance_not_allowed_label = ();
    %last_option_attributes = ();
    $tag_is_visible         = 1;
    $tag_is_hidden          = 0;
    $current_tag_styles     = "";
    $modified_content       = 0;
    undef($first_html_tag_lang);
    undef($summary_tag_content);
    $found_content_after_heading = 0;
    %form_id_values         = ();
    %input_form_id          = ();
    %f32_reported           = ();
    $main_content_start     = "";

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
    my ($testcase, $line, $column, $text, $error_string) = @_;

    my ($result_object, $source_line, $new_column);

    #
    # Is this testcase included in the profile
    #
    if ( defined($testcase) && defined($$current_tqa_check_profile{$testcase}) ) {
        #
        # Get source lines, use line before to get a better context
        #
        if ( $line > 1 ) {
            $source_line = $content_lines[$line - 2] . "\n";
            $new_column = length($line) + $column;
        }
        else {
            $new_column = $column;
        }

        #
        # Add current line and next to get a better context
        #
        if ( $line > 0 ) {
            $source_line .= $content_lines[$line - 1] . "\n" .
                            $content_lines[$line] . "\n";
        }
        else {
            $source_line = "";
            $new_column = $column;
        }

        #
        # Limit source line to 200 characters
        #
        if ( $new_column > 100 ) {
            $source_line = substr($source_line, $new_column - 100, 200);
        }
        else {
            $source_line = substr($source_line, 0, 200);
        }
                        
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $tqa_check_fail,
                                                TQA_Testcase_Description($testcase),
                                                $line, $column, $source_line,
                                                $error_string, $current_url);
        $result_object->testcase_groups(TQA_Testcase_Groups($testcase));
        $result_object->landmark($current_landmark);
        $result_object->landmark_marker($landmark_marker);
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
    $text =~ s/\r\n|\r|\n/ /g;
    
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
# Name: Text_Handler
#
# Parameters: text - content for the tag
#
# Description:
#
#   This function adds the provided text to the global text
# lists for the current tag.
#
#***********************************************************************
sub Text_Handler {
    my ($text) = @_;

    #
    # Save text in both the all text and the tag only text lists
    #
    if ( $have_text_handler ) {
        push(@text_handler_all_text, "$text");
        push(@text_handler_tag_text, "$text");
    }
}

#***********************************************************************
#
# Name: Get_Text_Handler_Content_For_Parent_Tag
#
# Parameters: none
#
# Description:
#
#   This function gets the text from the text handler for the parent
# tag of the current tag.
#
#***********************************************************************
sub Get_Text_Handler_Content_For_Parent_Tag {

    my ($content) = "";

    #
    # Do we have any saved text ?
    #
    if ( @text_handler_all_text_list > 0 ) {
        $content = $text_handler_all_text_list[@text_handler_all_text_list - 2];
    }

    #
    # Return content
    #
    print "Parent tag content = \"$content\"\n" if $debug;
    return($content); 
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
        $content = join($separator, @text_handler_all_text);
    }

    #
    # Return the content
    #
    print "content = \"$content\"\n" if $debug;
    return($content);
}

#***********************************************************************
#
# Name: Get_Text_Handler_Tag_Content
#
# Parameters: self - reference to a HTML::Parse object
#             separator - text to separate content components
#
# Description:
#
#   This function gets the tag text from the text handler.  This is
# text from the tag only, it does not include text from nested
# tags. It joins all the text together and trims off whitespace.
#
#***********************************************************************
sub Get_Text_Handler_Tag_Content {
    my ($self, $separator) = @_;
    
    my ($content) = "";
    
    #
    # Add a text handler to save text
    #
    print "Get_Text_Handler_Tag_Content separator = \"$separator\"\n" if $debug;
    
    #
    # Do we have a text handler ?
    #
    if ( $have_text_handler ) {
        #
        # Get any text.
        #
        $content = join($separator, @text_handler_tag_text);
    }

    #
    # Return the content
    #
    print "content = \"$content\"\n" if $debug;
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
    
    my ($current_tag_text, $current_all_text, $current_text);

    #
    # Destroy text handler
    #
    print "Destroy_Text_Handler for tag $tag\n" if $debug;
    
    #
    # Do we have a text handler ?
    #
    if ( $have_text_handler ) {
        #
        # Is the current text handler for this tag ?
        #
        if ( $current_text_handler_tag ne $tag ) {
            #
            # Not the right tag, we will continue with the destroy but note the
            # error.  This may be caused by a mismatch in open/close tags.
            #
            print "Error: Trying to destroy text handler for $tag, current handler is for $current_text_handler_tag\n" if $debug;
        }

        #
        # Get the text from the handler
        #
        $current_text = join(" ", @text_handler_tag_text);
        print "Text handler tag text \"$current_text\"\n" if $debug;
        $current_text = join(" ", @text_handler_all_text);
        print "Text handler text \"$current_text\"\n" if $debug;
        @text_handler_all_text = ();
        @text_handler_tag_text = ();

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
            print "Text handler stack is " . join(" ", @text_handler_tag_list) . "\n" if $debug;

            #
            # Discard any saved content for the current tag, we want the
            # saved content for the parent tag.
            #
            $current_all_text = pop(@text_handler_all_text_list);
            $current_tag_text = pop(@text_handler_tag_text_list);
            print "Discard saved text for current tag \"$current_all_text\"\n" if $debug;
            print "Discard saved tag text for current tag \"$current_tag_text\"\n" if $debug;

            #
            # We have to create a new text handler to restart the
            # text collection for the previous tag.  We also have to place
            # the saved text back in the handler.
            #
            $current_all_text = pop(@text_handler_all_text_list);
            $current_tag_text = pop(@text_handler_tag_text_list);
            $self->handler(text => \&Text_Handler, "dtext");
            $have_text_handler = 1;
            print "Previously saved text is \"$current_all_text\"\n" if $debug;
            print "Previously saved tag text is \"$current_tag_text\"\n" if $debug;

            #
            # Is this a tag that should not be treated as a word boundary ?
            # In this case we don't add whitespace around the text when
            # putting it back into the text handler.
            #
            if ( defined($non_word_boundary_tag{$tag}) ) {
                print "Adding \"$current_text\" text with no extra whitespace to text handler\n" if $debug;
                $current_all_text .= $current_text;
            }
            #
            # Is this a tag that doesn't propagate it's content to it's parent ?
            #
            elsif ( defined($tag_content_not_included_in_parent{$tag}) ) {
                print "Text not to be included in parent tag\n" if $debug;
                $current_tag_text = "";
            }
            #
            # We don't need script tag text, it is not part of the
            # web page content.
            #
            elsif ( $tag eq "script" ) {
                print "Discard script tag text\n" if $debug;
                $current_tag_text = "";
            }
            #
            # Don't add anchor tag text to a label tag.
            #
            elsif ( ($tag eq "a") && ($current_text_handler_tag eq "label") ) {
                print "Not adding <a> text to <label> text handler\n" if $debug;
                $current_tag_text = "";
            }
            #
            # Append text to parent tag's text
            # 
            else {
                print "Adding \"$current_text\" text with whitespace to text handler\n" if $debug;
                $current_all_text .= " $current_text";
            }

            #
            # Save content in text handler for the parent tag.
            #
            print "Place \"$current_all_text\" text in text handler\n" if $debug;
            print "Place \"$current_tag_text\" text in tag text handler\n" if $debug;
            push(@text_handler_all_text, "$current_all_text");
            push(@text_handler_tag_text, "$current_tag_text");
            print "Text handler now contains \"" . join(" ", @text_handler_all_text) . "\"\n" if $debug;
            print "Text handler tag text now contains \"" . join(" ", @text_handler_tag_text) . "\"\n" if $debug;

            #
            # Add empty string to text handlers for the restarted text handler
            #
            push(@text_handler_all_text_list, "");
            push(@text_handler_tag_text_list, "");
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
# Name: Discard_Saved_Text
#
# Parameters: self - reference to a HTML::Parse object
#             tag - current tag
#
# Description:
#
#   This function discards text for the current tag (e.g. text from a table
# cell <td>).  This prevents the text from being included in the parent tag.
#
#***********************************************************************
sub Discard_Saved_Text {
    my ($self, $tag) = @_;

    my ($current_tag_text, $current_all_text, $current_text);

    #
    # Discard saved text
    #
    print "Discard_Saved_Text for tag $tag\n" if $debug;

    #
    # Do we have a text handler ?
    #
    if ( $have_text_handler ) {
        #
        # Is the current text handler for this tag ?
        #
        if ( $current_text_handler_tag ne $tag ) {
            #
            # Not the right tag, don't discard text.
            #
            print "Error: Trying to discard text handler for $tag, current handler is for $current_text_handler_tag\n" if $debug;
        }
        else {
            #
            # Discard the text from the handler
            #
            @text_handler_tag_text = ();

            #
            # Add empty string to text handler to be passed to parent tag.
            #
            push(@text_handler_tag_text_list, "");
        }
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
    
    my ($current_tag_text, $current_all_text, $text);
    
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
        $current_all_text = pop(@text_handler_all_text_list);
        $text = join(" ", @text_handler_all_text);
        push(@text_handler_all_text_list, "$current_all_text $text");
        print "Saving \"$current_all_text $text\" for $current_text_handler_tag tag\n" if $debug;
        print "Text handler stack is " . join(" ", @text_handler_tag_list) . "\n" if $debug;

        $current_tag_text = pop(@text_handler_tag_text_list);
        $text = join(" ", @text_handler_tag_text);
        push(@text_handler_tag_text_list, "$current_tag_text $text");

        #
        # Destoy the existing text handler so we don't include text from the
        # current tag's handler for this tag.
        #
        $self->handler( "text", undef );
        push(@text_handler_tag_list, $current_text_handler_tag);
    }

    #
    # Create new text handler
    #
    push(@text_handler_all_text_list, "");
    push(@text_handler_tag_text_list, "");
    @text_handler_tag_text = ();
    @text_handler_all_text = ();
    $self->handler(text => \&Text_Handler, "dtext");
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

    my ($i1, $t, $i2);

    #
    # Check for 4 or more single character words in the
    # text string.
    #
    if ( $tag_is_visible &&
         ($text =~ /\s+[a-z]\s+[a-z]\s+[a-z]\s+[a-z]\s+/i) ) {
        ($i1, $t, $i2) = $text =~ /^(.*)(\s+[a-z]\s+[a-z]\s+[a-z]\s+[a-z]\s+)(.*)$/io;
        
        #
        # Have we already reported this error, we could be reporting the
        # same error for parent tags of the inner most tag set that
        # contains this string.  There is a chance that if the same
        # string appears in different places on the page we will not
        # report all instances, however, eliminating duplicate error
        # messages is preferred.
        #
        if ( ! defined($f32_reported{$t}) ) {
            Record_Result("WCAG_2.0-F32", $line, $column, $text,
                      String_Value("Using white space characters to control spacing within a word in tag") .
                                   " $tag \"$t\"");
            $f32_reported{$t} = 1;
        }
    }
}

#***********************************************************************
#
# Name: Check_For_Alt_or_Text_Alternative
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
#   This function checks for the presence of an alt attribute or other
# text alternative (e.g. ARIA).
#
#***********************************************************************
sub Check_For_Alt_or_Text_Alternative {
    my ($tcid, $tag, $line, $column, $text, %attr) = @_;
    
    my ($aid, $aria_labelledby);

    #
    # Look for alt attribute or other text alternative
    #
    if ( defined($attr{"alt"}) ) {
        print "Found alt attribute\n" if $debug;
    }
    elsif ( defined($attr{"aria-labelledby"}) ) {
        print "Found aria-labelledby attribute\n" if $debug;
        $aria_labelledby = $attr{"aria-labelledby"};
        $aria_labelledby =~ s/^ //g;
        $aria_labelledby =~ s/ $//g;
        
        #
        # Do we have content for the aria-labelledby attribute ?
        #
        if ( $aria_labelledby eq "" ) {
            #
            # Missing aria-labelledby value
            #
            if ( $tag_is_visible ) {
                Record_Result($tcid, $line, $column, $text,
                              String_Value("Missing content in") .
                              "'aria-labelledby='" .
                              String_Value("for tag") . "$tag");
            }
        }
        else {
            #
            # Record location of aria-labelledby references
            #
            foreach $aid (split(/\s+/, $aria_labelledby)) {
                $aria_labelledby_location{"$aid"} = "$line:$column:$tag:$tcid";
            }
        }
    }
    elsif ( defined($attr{"aria-label"}) ) {
        print "Found aria-label attribute\n" if $debug;
    }
    elsif ( defined($attr{"title"}) ) {
        print "Found title attribute\n" if $debug;
    }
    else {
        print "No alt or text laternative found\n" if $debug;
        Record_Result($tcid, $line, $column, $text,
                      String_Value("Missing alt or text alternative for") . "$tag");
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
    # a call to the function Check_For_Alt_or_Text_Alternative (possibly
    # with a different testcase id).
    #
    if ( defined($attr{"alt"}) ) {
        $alt = $attr{"alt"};

        #
        # Remove whitespace and check to see if we have any text.
        # Report error only if tag is visible.
        #
        $alt =~ s/\s*//g;
        if ( $tag_is_visible && ($alt eq "") ) {
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
    # Look for a title attribute.  Don't report any errors if 
    # the content is not visible.
    #
    if ( $tag_is_visible ) {
        if ( !defined( $attr{"title"} ) ) {
            Record_Result("WCAG_2.0-H64", $line, $column, $text,
                          String_Value("Missing title attribute for") .
                          "<$tag>");
        }
        else {
            #
            # Is the title an empty string ?
            #
            $title = $attr{"title"};
            $title =~ s/\s*//g;
            if ( $title eq "" ) {
                Record_Result("WCAG_2.0-H64", $line, $column, $text,
                              String_Value("Missing title content for") .
                              "<$tag>");
            }
        }
    }
    
    #
    # Check longdesc attribute
    #
    Check_Longdesc_Attribute("WCAG_2.0-H88", "<$tag>", $line, $column,
                             $text, %attr);
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
    $inside_tfoot[$table_nesting_index] = 0;
    $table_th_td_in_thead_count[$table_nesting_index] = 0;
    $table_th_td_in_tfoot_count[$table_nesting_index] = 0;

    #
    # Is this a layout table, role="presentation"
    #
    if ( defined($attr{"role"}) && ($attr{"role"} eq "presentation") ) {
        print "Table is a layout table\n" if $debug;
        $table_is_layout[$table_nesting_index] = 1;
    }
    else {
        $table_is_layout[$table_nesting_index] = 0;
    }

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
        # Don't report error if the table is not visible.
        #
        if ( $tag_is_visible && ($summary eq "") ) {
            Record_Result("WCAG_2.0-H73", $line, $column, $text,
                          String_Value("Missing table summary"));
        }
        
        #
        # Are we inside a layout table ? There must not be a summary in
        # layout tables.
        #
        if ( $table_is_layout[$table_nesting_index] ) {
            Record_Result("WCAG_2.0-F46", $line, $column, $text,
                          String_Value("summary found in layout table"));
        }
    }
    else {
        $table_summary[$table_nesting_index] = "";
    }
    
    #
    # Since we don't include table contents in the contents of the
    # parent tag (table contents may contain single characters that
    # may be caught as using spacing between text for presentation
    # effect) add some dummy text to the parent tag's text handler.
    #
    if ( $have_text_handler ) {
        push(@text_handler_all_text, "table$table_nesting_index");
        push(@text_handler_tag_text, "table$table_nesting_index");
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

    my ($tcid, @tcids, $start_tag_attr);

    #
    # Get start tag attributes
    #
    $start_tag_attr = $current_tag_object->attr();

    #
    # Did we see a label or legend inside the fieldset ?
    #
    if ( $fieldset_tag_index > 0 ) {
        #
        # Did we find a <aria-label> for the fieldset ?
        #
        if ( defined($start_tag_attr) &&
            (defined($$start_tag_attr{"aria-label"})) &&
            ($$start_tag_attr{"aria-label"} ne "") ) {
            #
            # Technique
            #   ARIA14: Using aria-label to provide an invisible label
            #   where a visible label cannot be used
            # used for label
            #
            print "Found aria-label attribute on fieldset ARIA14\n" if $debug;
        }
        #
        # Did we find a <aria-labelledby> for the fieldset ?
        #
        elsif ( defined($start_tag_attr) &&
            (defined($$start_tag_attr{"aria-labelledby"})) &&
            ($$start_tag_attr{"aria-labelledby"} ne "") ) {
            #
            # Technique
            #   ARIA9: Using aria-labelledby to concatenate a label from
            #   several text nodes
            # used for label
            #
            print "Found aria-labelledby attribute on fieldset ARIA9\n" if $debug;
        }
        #
        # Did we find a <legend> for the fieldset ?
        #
        elsif ( $found_legend_tag{$fieldset_tag_index} ) {
            #
            # Technique
            #   H91: Using HTML form controls and links
            # used for label
            #
            print "Found legend inside fieldset H91\n" if $debug;
        }
        #
        # No label found
        #
        else {
            #
            # Determine testcase id
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
        $fieldset_input_count{$fieldset_tag_index} = 0;
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
                      "<fieldset> " . String_Value("found outside of a form"));
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

    #
    # Set flag to indicate we have content after a heading.
    #
    $found_content_after_heading = 1;
    print "Found content after heading\n" if $debug;
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
    # Does it have a role attribute with the value 
    # "separator" or "presentation" ?
    #
    if ( defined($attr{"role"}) &&
         ($attr{"role"} eq "presentation" || $attr{"role"} eq "separator") ) {
        #
        # Used for decoration with a role that specifies it.
        #
        $used_for_decoration = 0;
    }
    #
    # Was the last tag an <hr> tag also ?
    #
    elsif ( $last_tag eq "hr" ) {
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
    # Don't report error if it is not visible.
    #
    if ( $tag_is_visible && $used_for_decoration ) {
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
# Name: Check_Label_Aria_Id_or_Title
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
#   This function checks for the presence of a label.  It looks for
# one of the following cases
# 1) title attribute (with content other than an empty string)
# 2) an id attribute and a corresponding label
# 3) aria-describedby and a matching id
#
#***********************************************************************
sub Check_Label_Aria_Id_or_Title {
    my ( $self, $tag, $label_required, $line, $column, $text, %attr ) = @_;

    my ($id, $title, $label, $last_seen_text, $complete_title);
    my ($aria_describedby, $aria_labelledby, $aid, $clean_text);
    my ($label_line, $label_column, $label_is_visible, $label_is_hidden);
    my ($aria_label);
    my ($found_label) = 0;
    my ($found_fieldset) = 0;

    #
    # Get possible title attribute
    #
    print "Check_Label_Aria_Id_or_Title for $tag, label_required = $label_required\n" if $debug;
    if ( defined($attr{"title"}) ) {
        $title = $attr{"title"};
        $title =~ s/^\s*//g;
        $title =~ s/\s*$//g;
        print "Have title = \"$title\"\n" if $debug;
    }

    #
    # Get possible id attribute
    #
    if ( defined($attr{"id"}) ) {
        $id = $attr{"id"};
        $id =~ s/^\s*//g;
        $id =~ s/\s*$//g;

        #
        # Do we have content for the id attribute ?
        #
        if ( $id eq "" ) {
            #
            # Missing id value
            #
            Record_Result("WCAG_2.0-H65", $line, $column, $text,
                          String_Value("Missing id content for") . $tag);
        }
    }

    #
    # If we are inside a fieldset, it (and it's legend) can
    # act as a label (WCAG 2.0 H71).
    #
    if ( $fieldset_tag_index > 0 ) {
        #
        # Inside a fieldset, the legend can act as a label.
        #
        print "Inside a fieldset, legend can be the label\n" if $debug;
        $found_fieldset = 1;

        #
        # Increment count of inputs inside this fieldset
        #
        $fieldset_input_count{$fieldset_tag_index}++;
    }

    #
    # Get possible aria-describedby attribute
    #
    if ( defined($attr{"aria-describedby"}) ) {
        $aria_describedby = $attr{"aria-describedby"};
        print "Have aria-describedby = \"$aria_describedby\"\n" if $debug;
        $found_label = 1;
    }

    #
    # Get possible aria-label attribute
    #
    if ( defined($attr{"aria-label"}) ) {
        $aria_label = $attr{"aria-label"};
        print "Have aria-label = \"$aria_label\"\n" if $debug;
        $found_label = 1;
    }

    #
    # Get possible aria-labelledby attribute
    #
    if ( defined($attr{"aria-labelledby"}) ) {
        $aria_labelledby = $attr{"aria-labelledby"};
        print "Have aria-labelledby = \"$aria_labelledby\"\n" if $debug;
        $found_label = 1;
    }

    #
    # Check id attribute and corresponding label
    #
    if ( (! $found_label) && defined($id) ) {
        print "Have id = \"$id\"\n" if $debug;
        $found_label = 1;

        #
        # See if we have a label (we may not have one if it comes
        # after this input).
        #
        if ( defined($label_for_location{$id}) ) {
            ($label_line, $label_column, $label_is_visible, $label_is_hidden) = split(/:/,
                 $label_for_location{$id});
            print "Have label with id = $id at $label_line:$label_column\n" if $debug;

            #
            # Check to see if we are inside a label, the label tag may
            # be before the input, but the label text may not be.
            #
            if ( $label_required && $inside_label ) {
                #
                # Does the last label have a 'for' attribute and
                # does it match the id we are looking for ?
                #
                if ( defined($last_label_attributes{"for"}) &&
                     ($last_label_attributes{"for"} eq $id) ) {
                    #
                    # We are nested inside our label, have we seen
                    # any label text yet ?
                    #
                    $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
                    if ( $tag_is_visible && ($clean_text eq "") ) {
                        print "No label text before input\n" if $debug;
                        Record_Result("WCAG_2.0-F68", $line, $column, $text,
                                      String_Value("Missing label before") .
                                      $tag);
                    }
                }
            }

            #
            # Is the input visible and the label hidden ?
            #
            if (  $tag_is_visible && $label_is_hidden ) {
                Record_Result("WCAG_2.0-H44", $line, $column, "",
                              String_Value("Label referenced by") .
                              " 'id=\"$id\"' " .
                              String_Value("is hidden") . ". <label> " .
                              String_Value("started at line:column") .
                              " $label_line:$label_column");
            }
            #
            # Is the input visible and the label not visible ?
            #
            elsif (  $tag_is_visible && (! $label_is_visible) ) {
                Record_Result("WCAG_2.0-H44", $line, $column, "",
                              String_Value("Label referenced by") .
                              " 'id=\"$id\"' " .
                              String_Value("is not visible") . ". <label> " .
                              String_Value("started at line:column") .
                              " $label_line:$label_column");
            }
        }
        #
        # Must the label preceed the input ?
        #
        elsif ( $label_required ) {
            #
            # Missing label definition before input.
            # Don't report error if
            #  a) we are inside a fieldset and there is more than 1 input
            #  b) we have a title attribute and value
            #
            if ( $found_fieldset && 
                 ($fieldset_input_count{$fieldset_tag_index} == 1) ) {
                print "Fieldset legend to act as label\n" if $debug;
            }
            elsif ( defined($title) && ($title ne "") ) {
                print "Title attribute to act as label\n" if $debug;
            }
            #
            # Don't report error if <input> is not visible
            #
            elsif ( $tag_is_visible ) {
                Record_Result("WCAG_2.0-F68", $line, $column, $text,
                              String_Value("Missing label before") . $tag);
            }
        }
        #
        # Label does not have to preceed the input
        #
        else {
            #
            # Label definition may be after input.
            # Don't record label reference if
            #  a) we are inside a fieldset and there is more than 1 input
            #  b) we have a title attribute and value
            # We record this id reference to make sure we find it
            # before the form ends.
            #
            if ( $found_fieldset &&
                 ($fieldset_input_count{$fieldset_tag_index} == 1) ) {
                print "Fieldset legend to act as label\n" if $debug;
            }
            elsif ( defined($title) && ($title ne "") ) {
                print "Title attribute to act as label\n" if $debug;
            }
            else {
                $input_id_location{"$id"} = "$line:$column:tag_is_visible:$tag_is_hidden";
            }
        }
    }

    #
    # Is this input inside a label ?
    # If we haven't found a label yet then we don't have an id,
    # aria-describedby, fieldset or any other label.  This must be an
    # input simply nested inside a label and not explicitly associated
    # with the input ?
    #
    # Change to F68 technique description in 2015.  Nesting
    # inputs in labels are valid.
    #
#    if ( (! $found_label) && $inside_label ) {
#        print "Input inside of label\n" if $debug;
#        $found_label = 1;
#        if ( $tag_is_visible ) {
#           Record_Result("WCAG_2.0-F68", $line, $column, $text,
#                         String_Value("Found tag") . $tag .
#                         String_Value("in") . "<label>");
#        }
#    }

    #
    # Get possible title attribute
    #
    if ( defined($title) ) {
        print "Have title = \"$title\"\n" if $debug;

        #
        # Did we have an id value ? and is it the same as the title ?
        #
        if ( defined($id) && (lc($title) eq lc($id)) ) {
            Record_Result("WCAG_2.0-H65", $line, $column, $text,
                          String_Value("Title same as id for") . $tag);
        }

        #
        # If we don't have a label yet, do we have a title value
        # to act as the title ?
        #
        if ( (! $found_label) && ($title eq "") ) {
            if ( $tag_is_visible ) {
                Record_Result("WCAG_2.0-H65", $line, $column, $text,
                              String_Value("Missing title content for") . $tag);
            }
        }
        elsif ( ! $found_label ) {
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
                if ( $tag_is_visible ) {
                    Record_Result("WCAG_2.0-H65", $line, $column,
                                  $text, String_Value("Duplicate") .
                                  " title \"$title\" " .
                                  String_Value("for") . $tag .
                                  String_Value("Previous instance found at") .
                                  $form_title_value{lc($complete_title)});
                }
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
    # If the last tag was a <label>, check the last label
    # for a "for" attribute.
    #
    if ( (! $found_label) && ($last_close_tag eq "label") ) {
        print "Last tag is label, text_between_tags = \"$text_between_tags\"\n" if $debug;

        #
        # Did the last label have a for attribute ?
        # If it didn't, this input may be implicitly associated with the
        # label.
        #
        if ( ! defined($last_label_attributes{"for"}) ) {
            $found_label = 1;
            if ( $tag_is_visible ) {
                Record_Result("WCAG_2.0-F68", $line, $column, $text,
                   String_Value("Previous label not explicitly associated to") .
                                    $tag);
            }
        }
    }

    #
    # If we still don't have a label, check for text preceeding the input.
    #
    if ( (! $found_label) && $have_text_handler) {
        #
        # Get the text before the input.
        #
        $last_seen_text = Get_Text_Handler_Content($self, "");

        #
        # Is there some text preceeding this input that may be
        # acting as a label
        #
        if ( defined($last_seen_text) && ($last_seen_text ne "") ) {
            $found_label = 1;
            if ( $tag_is_visible ) {
                Record_Result("WCAG_2.0-F68", $line, $column, $text,
                              String_Value("Text") . " \"$last_seen_text\" " .
                              String_Value("not marked up as a <label>"));
            }
        }
    }

    #
    # Catch all case, no id, no aria attributes, no title, so we don't have an
    # explicit label association.
    #
    if ( (! $found_label) && ( $tag_is_visible) )  {
        Record_Result("WCAG_2.0-F68", $line, $column, $text,
                      String_Value("Label not explicitly associated to") .
                      $tag);
    }

    #
    # Return status
    #
    return($found_label);
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
            Record_Result("WCAG_2.0-H44", $line, $column, $text,
                          String_Value("Label found for hidden input"));
        }
    }
}

#***********************************************************************
#
# Name: Check_Aria_Required_Attribute
#
# Parameters: tag - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks that if both an aria-required and HTML5
# required attribute is present that their semantics match.
#
#***********************************************************************
sub Check_Aria_Required_Attribute {
    my ($tag, $line, $column, $text, %attr) = @_;

    #
    # Is there a HTML5 required attribute and aria-required attribute ?
    #
    if ( defined($attr{"required"}) && defined($attr{"aria-required"}) ) {
        #
        # Is the aria-required attribute value "true" ?
        #
        if ( $attr{"aria-required"} ne "true" ) {
            Record_Result("WCAG_2.0-ARIA2", $line, $column, $text,
                          String_Value("Invalid attribute combination found") .
                          " 'required' " . String_Value("and") .
                          " 'aria-required=\"" . $attr{"aria-required"} . 
                          "\"'");
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

    my ($input_type, $id, $value, $input_tag_type, $label_location);
    my ($label_error, $clean_text, $label_line, $label_column);
    my ($label_is_visible, $label_is_hidden);
    my ($found_label) = 0;

    #
    # Was this input found within a <form> ?
    #
    if ( Is_A_Form_Input("input", $line, $column, $text, %attr) ) {
        print "Input found inside form\n" if $debug;
    }

    #
    # Is this input inside an anchor ?
    #
    if ( $inside_anchor ) {
        Record_Result("WCAG_2.0-F43", $line, $column, $text,
                      "<input> " . String_Value("found inside of link"));
    }

    #
    # Is this a read only input ?
    #
    if ( defined($attr{"readonly"}) ) {
        #
        # Don't need to check for a label as screen readers will skip over
        # these inputs.
        #
        print "Readonly input\n" if $debug;
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
        Check_For_Alt_or_Text_Alternative("WCAG_2.0-F65", $input_tag_type,
                                          $line, $column, $text, %attr);

        #
        # Check for alt text content
        #
        Check_Alt_Content("WCAG_2.0-H36", $input_tag_type, $self, $line,
                          $column, $text, %attr);

        #
        # Do we have alt text ?
        #
        if ( defined($attr{"alt"}) && ($attr{"alt"} ne "") ) {
            #
            # Technique
            #   H37: Using alt attributes on img elements
            #  used for label
            #
            print "Image has alt H37\n" if $debug;
        }
        #
        # Do we have a title attribute ?
        #
        elsif ( defined($attr{"title"} && $attr{"title"} ne "") ) {
            #
            # Technique
            #   H65: Using the title attribute to identify form controls
            #   when the label element cannot be used
            # used for label
            #
            print "Image has title H65\n" if $debug;
        }
        #
        # Did we find a <aria-label> attribute ?
        #
        elsif ( (defined($attr{"aria-label"})) &&
                ($attr{"aria-label"} ne "") ) {
            #
            # Technique
            #   ARIA14: Using aria-label to provide an invisible label
            #   where a visible label cannot be used
            # used for label
            #
            print "Found aria-label attribute ARIA14\n" if $debug;
        }
        #
        # Did we find a <aria-labelledby> attribute ?
        #
        elsif ( (defined($attr{"aria-labelledby"})) &&
                ($attr{"aria-labelledby"} ne "") ) {
            #
            # Technique
            #   ARIA9: Using aria-labelledby to concatenate a label from
            #   several text nodes
            # used for label
            #
            print "Found aria-labelledby attribute ARIA9\n" if $debug;
        }
        #
        # Check for a ARIA attributes that act as the text
        # alternative for this label.  We don't check for a value here,
        # that is checked in function Check_Aria_Attributes.
        #
        elsif ( defined($attr{"aria-label"})
                || defined($attr{"aria-labelledby"}) ) {
            #
            # Technique
            #   ARIA14: Using aria-label to provide an invisible label
            #   where a visible label cannot be used
            # used.
            #
            print "Image has aria-label or aria-labelledby ARIA14\n" if $debug;
        }
        #
        # Report error only if input is visible
        #
        elsif ( $tag_is_visible ) {
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
            $found_label = Check_Label_Aria_Id_or_Title($self, $input_tag_type,
                                                        1, $line, $column,
                                                        $text, %attr);
        }
        else {
            #
            # Label may appear after this input.  Label check will happen
            # at the end of the document.
            #
            $found_label = Check_Label_Aria_Id_or_Title($self, $input_tag_type,
                                                        0, $line, $column,
                                                        $text, %attr);

            #
            # Since this an input that that must have the label after, check
            # that the label is not before the input.
            #
            if ( defined($attr{"id"}) ) {
                #
                # Do we already have a label for this id value ?
                #
                $id = $attr{"id"};
                if ( defined($label_for_location{$id}) ) {
                    ($label_line, $label_column, $label_is_visible, $label_is_hidden) =
                        split(/:/, $label_for_location{$id});
                    $label_location = "$label_line:$label_column";
                    $label_error = 0;

                    #
                    # Are we inside a label ? It is possible that this
                    # label is the one we are referencing and we are
                    # nested within it.  If this is the case, we don't
                    # use the location of the label tag, we check for
                    # the actual label text.
                    #
                    if ( $inside_label ) {
                        #
                        # Does the last label have a 'for' attribute and
                        # does it match the id we are looking for ?
                        #
                        if ( defined($last_label_attributes{"for"}) &&
                             ($last_label_attributes{"for"} eq $id) ) {
                            #
                            # We are nested inside our label, have we seen
                            # any label text yet ?
                            #
                            $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
                            if ( $clean_text ne "" ) {
                                print "Found label text \"$clean_text\" before input\n" if $debug;
                                $label_error = 1;
                            }
                        }
                        else {
                            #
                            # Nested inside a label but this label is not
                            # programatically associated with this input
                            #
                            $label_error = 1;
                        }
                    }
                    else {
                        #
                        # Not inside a label, the label has appeared before
                        # the input.
                        #
                        $label_error = 1;
                    }

                    #
                    # Do we have an error with the label ?
                    #
                    if ( $label_error ) {
                        Record_Result("WCAG_2.0-H44", $line, $column, $text,
                                      String_Value("label not allowed before") .
                                      "<input type=\"$input_type\", <label> " .
                                      String_Value("defined at") .
                                      " $label_location");
                    }
                }
            }
        }
    }

    #
    # Check buttons for a value attribute
    #
    elsif ( index($input_types_requiring_value, " $input_type ") != -1 ) {
        #
        # Do we have a value attribute ?
        #
        if ( defined($attr{"value"}) ) {
            $value = $attr{"value"};
            $value =~ s/\s//g;
        }
        else {
            $value = "";
        }

        #
        # Did we find a <aria-label> attribute ?
        #
        if ( (defined($attr{"aria-label"})) &&
                ($attr{"aria-label"} ne "") ) {
            #
            # Technique
            #   ARIA14: Using aria-label to provide an invisible label
            #   where a visible label cannot be used
            # used for label
            #
            print "Found aria-label attribute ARIA14\n" if $debug;
        }
        #
        # Did we find a <aria-labelledby> attribute ?
        #
        elsif ( (defined($attr{"aria-labelledby"})) &&
                ($attr{"aria-labelledby"} ne "") ) {
            #
            # Technique
            #   ARIA9: Using aria-labelledby to concatenate a label from
            #   several text nodes
            # used for label
            #
            print "Found aria-labelledby attribute ARIA9\n" if $debug;
        }
        #
        # Do we have a value attribute
        #
        elsif ( defined($attr{"value"}) ) {
            #
            # Do we have an actual value ?
            #
            if ( $value ne "" ) {
                #
                # Technique
                #   H91: Using HTML form controls and links
                # used for label
                #
                print "Found value attribute H91\n" if $debug;
            }
            #
            # is tag visible ?
            #
            elsif ( $tag_is_visible ) {
                Record_Result("WCAG_2.0-H91", $line, $column, $text,
                              String_Value("Missing value in") .
                              "$input_tag_type");
            }
        }
        elsif ( $tag_is_visible ) {
            #
            # No value attribute
            #
            Record_Result("WCAG_2.0-H91", $line, $column, $text,
                          String_Value("Missing value attribute in") .
                          "$input_tag_type");
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
            if ( $tag_is_visible ) {
                Record_Result("WCAG_2.0-H44", $line, $column,
                              $text, String_Value("label not allowed for") .
                              "$input_tag_type");
            }
        }
        else {
            #
            # Record this input in case a label appears after
            # it.
            #
            $input_instance_not_allowed_label{$id} = "$input_type:$line:$column";
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
            push(@text_handler_all_text, $attr{"value"});
        }
    }

    #
    # Check aria-required attribute
    #
    Check_Aria_Required_Attribute("input", $line, $column, $text, %attr);

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
                if ( $tag_is_visible && ($fieldset_tag_index == 0) &&
                     (! $found_label) ) {
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
# Name: Is_A_Form_Input
#
# Parameters: tag - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks to see if a tag is part of a form or not.
# It checks for:
#   1) a form attribute that references a form on the page
#   2) if the input is nested within a form
#   3) an onchange attribute that indicates JavaScript is associated
#      with the input (so may not be part of a form)
#
#***********************************************************************
sub Is_A_Form_Input {
    my ($tag, $line, $column, $text, %attr) = @_;

    my ($form_id, @locations, $list_addr, $part_of_form);

    #
    # Do we have a form attribute to associate this tag
    # with a form elsewhere on the page ?
    #
    print "Is_A_Form_Input tag = $tag\n" if $debug;
    if ( defined($attr{"form"}) ) {
        $form_id = $attr{"form"};
        $form_id =~ s/^\s*//g;
        $part_of_form = 1;

        #
        # Check form value, it must not be an empty string.
        #
        if ( $form_id eq "" ) {
            Record_Result("WCAG_2.0-F62", $line, $column, $text,
                          String_Value("Missing content in") .
                          "'form='" .
                          String_Value("for tag") . "<$tag>");
        }
        #
        # Check to see if we have a form with this id.
        # Note: form may either preceed or follow the input.
        #
        if ( defined($form_id_values{$form_id}) ) {
            #
            # Tag associated with form
            #
            print "Tag associated with <form> at " . $form_id_values{$form_id} .
                  "\n" if $debug;
        }
        else {
            #
            # No form yet with this id, save id so it can be checked later
            #
            if ( ! defined($input_form_id{$form_id}) ) {
                $input_form_id{$form_id} = \@locations;
            }

            #
            # Save tag name and location
            #
            $list_addr = $input_form_id{$form_id};
            push(@$list_addr, "$tag:$line:$column:$text");
            print "Add $tag:$line:$column to form id $form_id\n" if $debug;
        }
    }
    #
    # No form attribute, are we inside a form ?
    #
    elsif ( $in_form_tag ) {
        $part_of_form = 1;
        print "Input found inside of a form\n" if $debug;
    }
    #
    # Do we have an onchange attribute, thereby using JavaScript to
    # add behaviour to the tag ?
    #
    elsif ( defined($attr{"onchange"}) ) {
        #
        # Not part of a form, the JavaScript provides behaviour
        #
        $part_of_form = 0;
        print "Input found outside of a form, but with onchange attribute\n" if $debug;
    }
    #
    # Do we have an onclick attribute, thereby using JavaScript to
    # add behaviour to the tag ?
    #
    elsif ( defined($attr{"onclick"}) ) {
        #
        # Not part of a form, the JavaScript provides behaviour
        #
        $part_of_form = 0;
        print "Input found outside of a form, but with onclick attribute\n" if $debug;
    }
    else {
        #
        # Not inside a form and not associated with a form
        #
        print "Input found outside of a form\n" if $debug;
        $part_of_form = 0;
    }
    
    #
    # Return flag indicating whether or not this input is part of a form
    #
    return($part_of_form);
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

    #
    # Is this input part of a form ?
    #
    if ( Is_A_Form_Input("select", $line, $column, $text, %attr) ) {
        #
        # Is this a read only or hidden input ?
        #
        if ( defined($attr{"readonly"}) ||
             (defined($attr{"type"}) && ($attr{"type"} eq "hidden") ) ) {
            print "Hidden or readonly select\n" if $debug;
            return;
        }
  
        #
        # Increment the number of writable inputs.
        #
        $number_of_writable_inputs++;
    }

    #
    # Check for one of a title or a label
    #
    Check_Label_Aria_Id_or_Title($self, "<select>", 1, $line, $column, $text,
                                 %attr);

    #
    # Check aria-required attribute
    #
    Check_Aria_Required_Attribute("select", $line, $column, $text, %attr);
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
                Record_Result("WCAG_2.0-F77", $line, $column,
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
             Record_Result("WCAG_2.0-F77", $line, $column,
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

    my ($label_for, $input_tag_type, $input_line, $input_column);
    my ($label_line, $label_column, $label_is_visible, $label_is_hidden);

    #
    # We are inside a label
    #
    $inside_label = 1;
    %last_label_attributes = %attr;
    $last_label_text = "";

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
                ($label_line, $label_column, $label_is_visible, $label_is_hidden) = split(/:/,
                                     $label_for_location{"$label_for"});
                Record_Result("WCAG_2.0-F77", $line, $column,
                              $text, String_Value("Duplicate label id") .
                              "'$label_for'" .  " " .
                              String_Value("Previous instance found at") .
                              "$label_line:$label_column");
            }

            #
            # Was this label referenced by an input that is not allowed
            # to have a label (e.g. submit buttons).
            #
            if ( defined($input_instance_not_allowed_label{$label_for}) ) {
                ($input_tag_type, $input_line, $input_column) = split(/:/,
                            $input_instance_not_allowed_label{$label_for});
                Record_Result("WCAG_2.0-H44", $line, $column,
                              $text, String_Value("label not allowed for") .
                              "<input type=\"$input_tag_type\" " .
                              String_Value("defined at") .
                              " $input_line:$input_column");
            }

            #
            # Save label location and visibility
            #
            print "Save label location $line:$column:$tag_is_visible:$tag_is_hidden\n" if $debug;
            $label_for_location{"$label_for"} = "$line:$column:$tag_is_visible:$tag_is_hidden";
        }
    }
}

#***********************************************************************
#
# Name: Complete_Label
#
# Parameters: text - text from label
#
# Description:
#
#   This function generated a complete label using the supplied text
# along with
#  - table headers
#  - fieldset legend
#  - last heading
#  - list heading text
#
#***********************************************************************
sub Complete_Label {
    my ($text) = @_;

    my ($complete_label, $attr);

    #
    # If we are inside a <fieldset> prefix the <label> with
    # any <legend> text.  JAWS reads both the <legend> and
    # <label> for the user. This allows for the same <label>
    # to appear in separate <fieldset>s.
    #
    print "Complete_Label text = $text\n" if $debug;
    if ( $fieldset_tag_index > 0 ) {
        print "Inside fieldset index $fieldset_tag_index, legend = \"" .
              $legend_text_value{$fieldset_tag_index} . "\"\n" if $debug;
        $complete_label = $legend_text_value{$fieldset_tag_index} .
                            " $text";
    }
    else {
        $complete_label = $text;
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

        #
        # Get saved copy of the <td> tag attributes.
        # Add any headers attribute from the <td> to the
        # label to get a more complete label (headers can add
        # context to differentiate labels).
        #
        $attr = $td_attributes[$table_nesting_index];
        if ( defined($$attr{"headers"}) ) {
            $complete_label .= " " . $$attr{"headers"};
        }
    }
    
    #
    # Are we inside a sub list ?  The parent list's list item text can
    # be used to provide context for a label.
    #
    if ( $current_list_level > 1 ) {
        print "Add list heading text \"" .
              $list_heading_text[$current_list_level] .
              "\"to the label\n" if $debug;
        $complete_label .= " " . $list_heading_text[$current_list_level];
    }
    
    #
    # Add last heading text to the label.  Screen readers can provide
    # users with the last heading when identifying the label of an
    # input.
    #
    $complete_label = $last_heading_text . " $complete_label";

    #
    # Return the complete label
    #
    print "Complete_Label = $complete_label\n" if $debug;
    return($complete_label);
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
    my ($complete_label, $attr);

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
    $last_label_text = $clean_text;

    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<label>", $line, $column, $clean_text);

    #
    # Are we missing label text ?
    #
    if ( $clean_text eq "" ) {
        if ( $tag_is_visible ) {
            Record_Result("WCAG_2.0-H44", $line, $column,
                          $text, String_Value("Missing text in") . "<label>");
            Record_Result("WCAG_2.0-G131", $line, $column,
                          $text, String_Value("Missing text in") . "<label>");
        }
    }
    else {
        #
        # Get the complete label that may include table headings
        # and fieldset legends.
        #
        $complete_label = Complete_Label($clean_text);

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

    #
    # Is this a read only or hidden input ?
    #
    print "Textarea_Tag_Handler\n" if $debug;
    if ( defined($attr{"readonly"}) ||
         (defined($attr{"type"}) && ($attr{"type"} eq "hidden") ) ) {
        print "Hidden or readonly textarea\n" if $debug;
        return;
    }

    #
    # Was this input found within a <form> ?
    #
    if ( Is_A_Form_Input("textarea", $line, $column, $text, %attr) ) {
        print "Textarea found inside form\n" if $debug;
    }

    #
    # Increment the number of writable inputs.
    #
    $number_of_writable_inputs++;

    #
    # Check to see if the textarea has a label or title
    #
    Check_Label_Aria_Id_or_Title($self, "<textarea>", 0, $line, $column, $text,
                                 %attr);
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
    if ( $tag_is_visible ) {
        Record_Result("WCAG_2.0-F16", $line, $column,
                      $text, String_Value("Found tag") . "<marquee>");
    }
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
    $fieldset_input_count{$fieldset_tag_index} = 0;
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

    my ($this_text, $last_line, $last_column, $clean_text, $complete_legend);

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
        if ( $tag_is_visible ) {
            Record_Result("WCAG_2.0-H71", $line, $column,
                          $text, String_Value("Missing text in") . "<legend>");
            Record_Result("WCAG_2.0-G131", $line, $column,
                          $text, String_Value("Missing text in") . "<legend>");
        }
    }
    #
    # Have we seen this legend before ?
    #
    else {
        #
        # Save legend text.  First add the previous heading value to the
        # legend text, a screen reader can announce the heading and legend
        # text if it is used as an input label.
        #
        $complete_legend = "$last_heading_text $clean_text";
        if ( $fieldset_tag_index > 0 ) {
            $legend_text_value{$fieldset_tag_index} = $clean_text;
            print "Legend for fieldset index $fieldset_tag_index = \"$clean_text\"\n" if $debug;
        }

        #
        # Have we seen this legend before in this for ?
        #
        if ( defined($form_legend_value{lc($complete_legend)}) ) {
            Record_Result("WCAG_2.0-H71", $line, $column,
                          $text, String_Value("Duplicate") .
                          " <legend> \"$clean_text\" " .
                          String_Value("Previous instance found at") .
                          $form_legend_value{lc($complete_legend)});
        }
        else {
            #
            # Save legend location
            #
            $form_legend_value{lc($complete_legend)} = "$line:$column"
        }
    }
}

#***********************************************************************
#
# Name: Possible_Pseudo_Heading
#
# Parameters: text - text
#
# Description:
#
#   This function checks the supplied text to see if it may be a
# pseudo heading.  It checks that the content is
#  - not in a table
#  - does not end in a period
#  - is not inside an anchor
#  - is less than a pseudo header maximum length
#
#***********************************************************************
sub Possible_Pseudo_Heading {
    my ( $text ) = @_;

    my ($possible_heading) = 0;
    my ($decoded_text);

    #
    # Convert any HTML entities into actual characters so we can get
    # an accurate text length.
    #
    $decoded_text = decode_entities($text);

    #
    # If this emphasis is inside a block tag such as <caption>, it
    # is ignored as it is not a heading.  Also ignore it if it is
    # a table header (<th>, <td>).  Check for emphasis inside a
    # heading tag (e.g. <h3><div><strong>Heading text</strong></div></h3>).
    #
    print "Possible_Pseudo_Heading\n" if $debug;
    if ( Have_Text_Handler_For_Tag("caption") ||
            Have_Text_Handler_For_Tag("h1") ||
            Have_Text_Handler_For_Tag("h2") ||
            Have_Text_Handler_For_Tag("h3") ||
            Have_Text_Handler_For_Tag("h4") ||
            Have_Text_Handler_For_Tag("h5") ||
            Have_Text_Handler_For_Tag("h6") ||
            Have_Text_Handler_For_Tag("summary") ||
            Have_Text_Handler_For_Tag("td") ||
            Have_Text_Handler_For_Tag("th")    ) {
        print "Ignore possible pseudo-heading inside block/heading/table tag\n" if $debug;
    }
    #
    # Does the text end with a period ? This suggests it is a sentence
    # rather than a heading.
    #
    elsif ( $text =~ /\.$/ ) {
        print "Ignore possible pseudo-heading that end with a period\n" if $debug;
    }
    #
    # Does the text end with a some other punctuation that suggests
    # it is not a heading ?
    #
    elsif ( $text =~ /[\?!:]$/ ) {
        print "Ignore possible pseudo-heading that end with punctuation\n" if $debug;
    }
    #
    # Does the text begin and end with a bracket ?
    # This may be a note rather than a heading.
    #
    elsif ( $text =~ /^\[.*\]$/ ) {
        print "Ignore possible pseudo-heading that is enclosed in brackets\n" if $debug;
    }
    #
    # Does the text begin or end with a quote character ?
    # This may be a quote rather than a heading.
    #
    elsif ( ($decoded_text =~ /^'.*/) || ($decoded_text =~ /^".*/) ||
            ($decoded_text =~ /.*'$/) || ($decoded_text =~ /.*"$/) ) {
        print "Ignore possible pseudo-heading that has quotes\n" if $debug;
    }
    #
    # Does the text begin and end with a parenthesis ?
    # This may be a note for a table rather than a heading.
    #
    elsif ( $text =~ /^\(.*\)$/ ) {
        print "Ignore possible pseudo-heading that is enclosed in parentheses\n" if $debug;
    }
    #
    # Do we have an anchor inside the emphasis block ?
    # Ignore this text as the anchor may be bolded.
    #
    elsif ( $anchor_inside_emphasis ) {
        print "Ignore possible pseudo-heading that contains an anchor\n" if $debug;
    }
    #
    # Is the emphasized text a label ?
    #
    elsif ( $inside_label || ($text eq $last_label_text) ) {
        print "Ignore possible pseudo-heading that are labels\n" if $debug;
    }
    #
    # Check the length of the text, if it is below a certain threshold
    # it may be acting as a pseudo-header
    #
    elsif ( length($decoded_text) < $pseudo_header_length ) {
        #
        # Possible pseudo-header
        #
        $possible_heading = 1;
        print "Possible pseudo-header \"$text\"\n" if $debug;
    }

    #
    # Return status
    #
    return($possible_heading);
}

#***********************************************************************
#
# Name: Check_Pseudo_Heading
#
# Parameters: tag - tagname
#             content - text between the open & close tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function checks for a pseudo heading.  It checks to see
# if a possible psedue heading was detected (emphasised text) and if
# it matches this tag's text.  It checks for any CSS emphasis on this
# tag that makes it appear as a heading.
#
#***********************************************************************
sub Check_Pseudo_Heading {
    my ( $tag, $content, $line, $column, $text ) = @_;

    my ($has_emphasis, $found_heading, $style, $style_object);

    #
    # Was there a pseudo-header ? Is it the entire contents of the 
    # paragraph ? (not just emphasised text inside the paragraph)
    #
    if ( ($pseudo_header ne "") &&
         ($pseudo_header eq $content) ) {
        print "Possible pseudo-header paragraph \"$content\" at $line:$column\n" if $debug;
        if ( $found_content_after_heading ) {
            if ( $tag_is_visible ) {
                Record_Result("WCAG_2.0-F2", $line, $column, $text,
                              String_Value("Text styled to appear like a heading") .
                              " \"$pseudo_header\"");
            }
            $found_heading = 1;
        }
        else {
            print "Pseudo header found right after real heading\n" if $debug;
        }
    }
    else {
        #
        # Have no pseudo-header, reset global variable
        #
        $pseudo_header = "";
        $found_heading = 0;
    }

    #
    # Check styles associated with this tag.
    #
    print "Check for inline style \"$current_tag_styles\" for tag $tag\n" if $debug;
    if ( ($tag_is_visible) && ($tag ne "") &&
         ($content ne "") && (! $found_heading) ) {
        #
        # Do we have a CSS style for the style name ?
        #
        foreach $style (split(/\s+/, $current_tag_styles)) {
            if ( defined($css_styles{$style}) ) {
                $style_object = $css_styles{$style};

                $has_emphasis = CSS_Check_Does_Style_Have_Emphasis($style,
                                                                   $style_object);

                #
                # Did we find CSS emphasis ?
                #
                if ( $has_emphasis ) {
                    if ( Possible_Pseudo_Heading($content) ) {
                        print "Possible pseudo-header \"$content\" at $line:$column\n" if $debug;
                        if ( $found_content_after_heading ) {
                            if ( $tag_is_visible ) {
                                Record_Result("WCAG_2.0-F2", $line, $column, $text,
                                  String_Value("Text styled to appear like a heading") .
                                      " \"$content\"");
                            }
                        }
                        else {
                            print "Pseudo header found right after real heading\n" if $debug;
                        }
                    }
                    
                    #
                    # Found 1 style with emphasis, stop checking for other
                    # styles.
                    #
                    last;
                }
            }
        }
    }
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

    my ($this_text, $clean_text, $style, $style_object, $has_emphasis);

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
    Check_Pseudo_Heading("p", $clean_text, $line, $column, $text);
    
    #
    # Was there any text in the paragraph ?
    #
    if ( $clean_text ne "" && (! $in_header_tag) ) {
        $found_content_after_heading = 1;
        print "Found content after heading\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Div_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the div tag.
#
#***********************************************************************
sub Div_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;
}

#***********************************************************************
#
# Name: End_Div_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end div tag.
#
#***********************************************************************
sub End_Div_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($this_text, $clean_text, $style, $style_object, $has_emphasis);

    #
    # Get all the text found within the div tag
    #
    if ( ! $have_text_handler ) {
        #
        # If we don't have a text handler, ignore it.
        #
        print "End div tag found no text handler at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the div text as a string
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, " "));

    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<div>", $line, $column, $clean_text);

    #
    # Was there a pseudo-header ? Is it the entire contents of the
    # div ? (not just emphasised text inside the div)
    #
    Check_Pseudo_Heading("div", $clean_text, $line, $column, $text);

    #
    # Was there any text in the paragraph ?
    #
    if ( $clean_text ne "" && (! $in_header_tag) ) {
        $found_content_after_heading = 1;
        print "Found content after heading\n" if $debug;
    }
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
    print "Start Emphasis text handler for $tag\n" if $debug;
    if ( ($last_open_tag eq "p") || 
         ($last_open_tag eq "div") || 
         ($emphasis_count > 0) ) {
        #
        # Increment emphasis level count
        #
        $emphasis_count++;
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

    #
    # Are we missing text ?
    #
    $pseudo_header = "";
    if ( $clean_text eq "" ) {
        if ( $tag_is_visible ) {
            Record_Result("WCAG_2.0-G115", $line, $column,
                          $text, String_Value("Missing text in") . "<$tag>");
        }
    }
    #
    # Check for possible pseudo heading based on content
    #
    elsif ( Possible_Pseudo_Heading($clean_text) ) {
        #
        # Possible pseudo-header
        #
        $pseudo_header = $clean_text;
        print "Possible pseudo-header \"$clean_text\" at $line:$column\n" if $debug;
    }

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
#   This function performs delayed checks on headers attributes for
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
        # Are we inside a layout table ? There must not be headers in
        # layout tables.
        #
        if ( $table_is_layout[$table_nesting_index] ) {
            Record_Result("WCAG_2.0-F46", $line, $column, $text,
                          String_Value("Table header found in layout table"));
        }
        
        #
        # Table has headers.
        #
        $table_has_headers[$table_nesting_index] = 1;
        
        #
        # Are we inside a <thead> ?
        #
        if ( $inside_tfoot[$table_nesting_index] ) {
            $table_th_td_in_tfoot_count[$table_nesting_index]++;
        }

        #
        # Are we inside a <thead> ?
        #
        if ( $inside_thead[$table_nesting_index] ) {
            $table_th_td_in_thead_count[$table_nesting_index]++;
        }

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
    # Are we not inside a table ?
    #
    if ( $table_nesting_index <0 ) {
        print "End <td> found outside a table\n" if $debug;
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
    else {
        #
        # Check for using white space characters to control spacing within a word
        #
        Check_Character_Spacing("<th>", $line, $column, $clean_text);
    }
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
# Name: End_Thead_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the end thead tag.
#
#***********************************************************************
sub End_Thead_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    #
    # No longer in a <thead> .. </thead> pair
    #
    if ( $table_nesting_index >= 0 ) {
        #
        # Did we find any headers inside the thead ?
        #
        if ( $table_th_td_in_thead_count[$table_nesting_index] == 0 ) {
            if ( $tag_is_visible ) {
                Record_Result("WCAG_2.0-G115", $line, $column,
                              $text, String_Value("No headers found inside thead"));
            }
        }

        #
        # Clear in thead flag.
        #
        $inside_thead[$table_nesting_index] = 0;
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
        # Are we inside a <thead> ?
        #
        if ( $inside_tfoot[$table_nesting_index] ) {
            $table_th_td_in_tfoot_count[$table_nesting_index]++;
        }

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
            # Are we inside a <thead> ?
            #
            if ( $inside_thead[$table_nesting_index] ) {
                $table_th_td_in_thead_count[$table_nesting_index]++;
            }

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
    if ( $table_nesting_index < 0 ) {
        print "End <td> found outside a table\n" if $debug;
        return;
    }
    
    #
    # Are we inside a layout table ? If so we skip headers checks.
    #
    if ( $table_is_layout[$table_nesting_index] ) {
        print "Skip header checking for td inside layout table\n" if $debug;
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
    # Discard any text from this tag, we don't include it in the parent tag
    # content.
    #
    Discard_Saved_Text($self, "td");
}

#***********************************************************************
#
# Name: Tfoot_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the tfoot tag.
#
#***********************************************************************
sub Tfoot_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    #
    # If we are inside a table, set table foot flag
    #
    if ( $table_nesting_index >= 0 ) {
        $inside_tfoot[$table_nesting_index] = 1;
    }
    else {
        #
        # Found <tfoot> outside of a table.
        #
        Tag_Not_Allowed_Here("tfoot", $line, $column, $text);
    }
}

#***********************************************************************
#
# Name: End_Tfoot_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the end tfoot tag.
#
#***********************************************************************
sub End_Tfoot_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    #
    # No longer in a <tfoot> .. </tfoot> pair
    #
    if ( $table_nesting_index >= 0 ) {
        #
        # Did we find any td or th tags inside the tfoot ?
        #
        if ( $table_th_td_in_tfoot_count[$table_nesting_index] == 0 ) {
            if ( $tag_is_visible ) {
                Record_Result("WCAG_2.0-G115", $line, $column,
                              $text, String_Value("No td, th found inside tfoot"));
            }
        }

        #
        # Clear in tfoot flag.
        #
        $inside_tfoot[$table_nesting_index] = 0;
    }
}

#***********************************************************************
#
# Name: Check_Track_Src
#
# Parameters: resp - HTTP::Response object
#             src - URL of src attribute
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks to see if the mime-type and content type of the
# track's src URL match the data type.
#
#***********************************************************************
sub Check_Track_Src {
    my ($resp, $src, $line, $column, $text, %attr) = @_;

    my ($header, $mime_type, $content, $data_type, $is_ttml, $ttml_content);
    my ($ttml_lang);

    #
    # Get mime-type of content
    #
    $header = $resp->headers;
    $mime_type = $header->content_type;
    $content = Crawler_Decode_Content($resp);
    print "Check_Track_Src, url = $src, data-type = $data_type, mime-type = $mime_type\n" if $debug;

    #
    # Do we have content ?
    #
    if ( length($content) == 0 ) {
        Record_Result("WCAG_2.0-F8", $line, $column, $text,
                      String_Value("No content found in track"));
        return;
    }

    #
    # Check for optional data-type attribute
    #
    if ( defined($attr{"data-type"}) ) {
        $data_type = $attr{"data-type"};
    }
    else {
        $data_type = "";
    }
    
    #
    # Is the mime type XML ?
    #
    if ( ($mime_type =~ /application\/atom\+xml/) ||
         ($mime_type =~ /application\/ttml\+xml/) ||
         ($mime_type =~ /application\/xhtml\+xml/) ||
         ($mime_type =~ /text\/xml/) ||
         ($src =~ /\.xml$/i) ) {
        #
        # Is the content TTML ?
        #
        $is_ttml = XML_TTML_Validate_Is_TTML($src, \$content);
    }
    else {
        $is_ttml = 0;
    }
    
    #
    # Check that the track data-type attribute.
    # If the content is TTML, does the data-type match ?
    #
    if ( $data_type ne "" ) {
        if ( $is_ttml && ($data_type =~ /application\/ttml\+xml/i) ) {
            print "data-type is TTML\n" if $debug;
        }
        elsif ( $is_ttml ) {
            print "data-type does not match content type\n" if $debug;
            Record_Result("WCAG_2.0-F8", $line, $column, $text,
                          String_Value("Content type does not match") .
                          " data-type=\"$data_type\" src=\"$src\"" .
                          String_Value("for tag") . "<track>" .
                          " Content-type = $mime_type");
        }
    }
    
    #
    # If this is TTML content, do we have any captions in the content
    #
    if ( $is_ttml ) {
        ($ttml_lang, $ttml_content) = XML_TTML_Text_Extract_Text($content);

        #
        # Did we find any content ?
        #
        $ttml_content =~ s/\n|\r| |\t//g;
        print "TTML content = \"$ttml_content\"\n" if $debug;
        if ( $ttml_content eq "" ) {
            Record_Result("WCAG_2.0-F8", $line, $column, $text,
                          String_Value("No closed caption content found"));
        }
    }
}

#***********************************************************************
#
# Name: Track_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the track tag.
#
#***********************************************************************
sub Track_Tag_Handler {
    my ($line, $column, $text, %attr) = @_;

    my ($src, $kind, $tcid, $href, $resp_url, $resp);

    #
    # Are we inside a video tag ?
    #
    if ( $inside_video ) {
        #
        # Do we have a kind attribute ?
        #
        if ( defined($attr{"kind"}) ) {
            $kind = $attr{"kind"};
        }
        else {
            $kind = "subtitles";
        }
        $video_track_kind_map{$kind} = 1;

        #
        # Is this a caption or description track ?
        #
        if ( ($kind eq "captions") || ($kind eq "descriptions") ) {
            $tcid = "WCAG_2.0-F8";
        }
        else {
            $tcid = "WCAG_2.0-H88";
        }

        #
        # Do we have a src attribute ?
        #
        if ( defined($attr{"src"}) ) {
            $src = $attr{"src"};
            $src =~ s/^\s*//g;
            $src =~ s/\s*$//g;
        }
        else {
            #
            # Missing src attribute
            #
            Record_Result($tcid, $line, $column,
                          $text, String_Value("Missing src attribute") .
                          String_Value("for tag") . "<track>");
        }

        #
        # Check for valid src
        #
        if ( defined($src) ) {
            #
            # Is src an empty string ?
            #
            if ( $src eq "" ) {
                #
                # Missing src attribute
                #
                Record_Result($tcid, $line, $column,
                              $text, String_Value("Missing src value") .
                              String_Value("for tag") . "<track>");
            }
            #
            # Check to see if the track is available (check only for
            # captions and description tracks).
            #
            elsif ( ($kind eq "captions") || ($kind eq "descriptions") ) {
                #
                # Convert possible relative url into an absolute one based
                # on the URL of the current document.  If we don't have
                # a current URL, then HTML_Check was called with just a block
                # of HTML text rather than the result of a GET.
                #
                if ( $current_url ne "" ) {
                    $href = URL_Check_Make_URL_Absolute($src, $current_url);
                    print "src url = $href\n" if $debug;

                    #
                    # Get track URL
                    #
                    ($resp_url, $resp) = Crawler_Get_HTTP_Response($href,
                                                                   $current_url);

                    #
                    # Is this a valid URI ?
                    #
                    if ( ! defined($resp) ) {
                        Record_Result("WCAG_2.0-F8", $line, $column, $text,
                                      String_Value("Invalid URL in src for") .
                                      "<track>");
                    }
                    #
                    # Is it a broken link ?
                    #
                    elsif ( ! $resp->is_success ) {
                        Record_Result("WCAG_2.0-F8", $line, $column, $text,
                                      String_Value("Broken link in src for") .
                                      "<track>");
                    }
                    else {
                        #
                        # Check track src
                        #
                        Check_Track_Src($resp, $resp_url, $line, $column,
                                        $text, %attr);
                    }
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: End_Track_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the end track tag.
#
#***********************************************************************
sub End_Track_Tag_Handler {
    my ($line, $column, $text) = @_;

}

#***********************************************************************
#
# Name: Audio_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the audio tag.
#
#***********************************************************************
sub Audio_Tag_Handler {
    my ($line, $column, $text, %attr) = @_;

    #
    # Set flag to indicate we are inside a audio tag set.
    #
    $inside_audio = 1;
    %audio_track_kind_map = ();
}

#***********************************************************************
#
# Name: End_Audio_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the end audio tag.
#
#***********************************************************************
sub End_Audio_Tag_Handler {
    my ($line, $column, $text) = @_;

    #
    # No longer in a <audio> .. </audio> pair
    #
    $inside_audio = 0;

    #
    # Did we find any closed captions or decsriptions tracks for
    # the audio ?
    #
    if (     (! defined($audio_track_kind_map{"captions"}))
          && (! defined($audio_track_kind_map{"descriptions"})) ) {
        Record_Result("WCAG_2.0-G87", $line, $column, $text,
                      String_Value("No captions found for") . " <audio>");
    }

    #
    # Set flag to indicate we have content after a heading.
    #
    $found_content_after_heading = 1;
    print "Found content after heading\n" if $debug;
}

#***********************************************************************
#
# Name: Video_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the video tag.
#
#***********************************************************************
sub Video_Tag_Handler {
    my ($line, $column, $text, %attr) = @_;

    #
    # Set flag to indicate we are inside a video tag set.
    #
    $inside_video = 1;
    %video_track_kind_map = ();
}

#***********************************************************************
#
# Name: End_Video_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the end video tag.
#
#***********************************************************************
sub End_Video_Tag_Handler {
    my ($line, $column, $text) = @_;

    #
    # No longer in a <video> .. </video> pair
    #
    $inside_video = 0;
    
    #
    # Did we find any closed captions or decsriptions tracks for
    # the video ?
    #
    print "End video tag, check tracks\n" if $debug;
    if (     (! defined($video_track_kind_map{"captions"}))
          && (! defined($video_track_kind_map{"descriptions"})) ) {
        Record_Result("WCAG_2.0-G87", $line, $column, $text,
                      String_Value("No captions found for") . " <video>");
    }

    #
    # Set flag to indicate we have content after a heading.
    #
    $found_content_after_heading = 1;
    print "Found content after heading\n" if $debug;
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
    Check_For_Alt_or_Text_Alternative("WCAG_2.0-F65", "<area>", $line,
                                      $column, $text, %attr);

    #
    # Check for alt text content
    #
    Check_Alt_Content("WCAG_2.0-H24", "<area>", $self, $line, $column, $text, %attr);
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
                $href = URL_Check_Make_URL_Absolute($longdesc, $current_url);
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
        if ( $tag_is_visible && ($image_details{"animation_time"} > 5) ) {
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
        if ( $tag_is_visible && ($image_details{"most_frames_per_sec"} > 3) ) {
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

    my ($alt, $invalid_alt, $aria_label, $src, $src_url);
    my ($protocol, $domain, $query, $new_url, $file_name, $file_name_no_suffix);
    my ($f30_reported) = 0;

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
        Check_For_Alt_or_Text_Alternative("WCAG_2.0-F65", "<img>", $line,
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
        if ( $have_text_handler && ($attr{"alt"} ne "") ) {
            push(@text_handler_all_text, "ALT:" . $attr{"alt"});
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
    Check_Longdesc_Attribute("WCAG_2.0-H45", "<image>", $line, $column,
                             $text, %attr);

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
                    $f30_reported = 1;
                }
            }
        }
    }

    #
    # Check for alt and src attributes
    #
    if ( (! $f30_reported)
         && defined($attr{"alt"})
         && ($attr{"alt"} ne "")
         && defined($attr{"src"}) ) {
        print "Have alt = " . $attr{"alt"} . " and src = " . $attr{"src"} .
              " in image\n" if $debug;

        #
        # Convert the src attribute into an absolute URL
        #
        $src = $attr{"src"};
        $src_url = URL_Check_Make_URL_Absolute($src, $current_url);
        ($protocol, $domain, $file_name, $query, $new_url) = URL_Check_Parse_URL($src_url);
        $file_name =~ s/^.*\///g;
        $file_name_no_suffix = $file_name;
        $file_name_no_suffix =~ s/\.[^.]*$//g;

        #
        # Check for
        #  1. duplicate alt and src (using a URL for the alt text)
        #  2. alt is the absolute URL for src
        #  3. alt is src file name component (directory paths removed)
        #  4. alt is the src file name minus file suffix
        #
        if ( ($attr{"alt"} eq $src)
              || ($attr{"alt"} eq $src_url)
              || ($attr{"alt"} eq $file_name)
              || ($attr{"alt"} eq $file_name_no_suffix) ) {
            print "src eq alt\n" if $debug;
            Record_Result("WCAG_2.0-F30", $line, $column, $text,
                          String_Value("Image alt same as src"));
            $f30_reported = 1;
        }
    }

    #
    # Check value of aria-label attribute to see if it is a forbidden
    # word or phrase (reference: http://oaa-accessibility.org/rule/28/)
    #
    if ( (! $f30_reported)
         && defined($attr{"aria-label"})
         && ($attr{"aria-label"} ne "") ) {
        #
        # Do we have invalid aria-label text phrases defined ?
        #
        if ( defined($testcase_data{"WCAG_2.0-F30"}) ) {
            $aria_label = lc($attr{"aria-label"});
            foreach $invalid_alt (split(/\n/, $testcase_data{"WCAG_2.0-F30"})) {
                #
                # Do we have a match on the invalid alt text ?
                #
                if ( $aria_label =~ /^$invalid_alt$/i ) {
                    Record_Result("WCAG_2.0-F30", $line, $column, $text,
                                  String_Value("Invalid aria-label text value") .
                                  " '" . $attr{"aria-label"} . "'");
                    $f30_reported = 1;
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
    
    #
    # Check for empty alt and non empty title
    #
    if ( defined($attr{"alt"}) && ($attr{"alt"} eq "") ) {
        #
        # Is title absent or empty ?
        #
        if ( defined($attr{"title"}) && ($attr{"title"} ne "") ) {
           Record_Result("WCAG_2.0-H67", $line, $column, $text,
                         String_Value("Non null title text") .
                         $attr{"title"} .
                         String_Value("in decorative image"));
        }
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
        if ( ! defined($attr{"lang"}) ) {
            #
            # Missing language attribute
            #
            if ( ! $modified_content ) {
                Record_Result("WCAG_2.0-H57", $line, $column, $text,
                              String_Value("Missing html language attribute") .
                              " 'lang'");
            }
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
        if ( ! defined($attr{"xml:lang"}) ) {
            #
            # Missing language attribute
            #
            if ( ! $modified_content ) {
                Record_Result("WCAG_2.0-H57", $line, $column, $text,
                              String_Value("Missing html language attribute") .
                              " 'xml:lang'");
            }
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
    if ( defined($attr{"lang"}) && defined($attr{"xml:lang"}) ) {
        #
        # Do the values match ?
        #
        if ( lc($attr{"lang"}) ne lc($attr{"xml:lang"}) ) {
            if ( ! $modified_content ) {
                Record_Result("WCAG_2.0-H57", $line, $column, $text,
                              String_Value("Mismatching lang and xml:lang attributes") .
                              String_Value("for tag") . "<html>");
            }
        }
    }

    #
    # Convert language code into a 3 character code.
    #
    $lang = ISO_639_2_Language_Code($lang);

    #
    # Were we able to determine the language of the content ?
    #
    if ( ($current_content_lang_code ne "") && (! $modified_content) ) {
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
    
    #
    # If we are processing modified content (i.e Internet Explorer conditional
    # comments removed) and this is the first HTML tag encountered,
    # record this tag's language as the initial document language.
    #
    if ( $modified_content ) {
        if ( ! defined($first_html_tag_lang) ) {
            #
            # Save this language for checking possible other <html> tags.
            #
            $first_html_tag_lang = $lang;
        }
        elsif ( $lang ne $first_html_tag_lang ) {
            #
            # Languages do not match for <html> tags.
            # If the IE conditional content is enabled, the language
            # is different in some cases (which it should not be).
            #
            Record_Result("WCAG_2.0-H57", $line, $column, $text,
                          String_Value("HTML language attribute") .
                          " '$lang' " .
                          String_Value("does not match previous value") .
                          " '$first_html_tag_lang'");
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
    # Are we outside of the <head> section of a non HTML5 document ?
    #
    if ( ($doctype_label eq "HTML")
         && ($doctype_version != 5.0 )
         && (! $in_head_tag) ) {
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

    #
    # Do we have name="viewport" ?
    # If so check for scaling limitations the would prevent
    # text zooming.  Reference: https://dequeuniversity.com/rules/axe/1.1/meta-viewport
    #
    if ( defined($attr{"name"}) && ($attr{"name"} =~ /viewport/i) ) {
        #
        # Do we have a content attributte ?
        #
        if ( defined($attr{"content"}) ) {
            $content = $attr{"content"};

            #
            # Split content on comma then check each value
            #
            @values = split(/,/, $content);
            foreach $value (@values) {
                #
                # Do we have a content attribute and does it contain
                # user-scalable=no ? This setting prevents zooming text in
                # some moble devices (e.g. IOS).
                #
                if ( $value =~ /user-scalable=no/i ) {
                    Record_Result("WCAG_2.0-SC1.4.4", $line, $column, $text,
                                   String_Value("Meta viewport with user-scalable disabled"));
                }
                #
                # Do we have a maximum scaling value ?
                #
                elsif ( $value =~ /maximum-scale/ ) {
                    #
                    # Is the maximum scaling less than 5 ?
                    #
                    $value =~ s/^maximum-scale=//g;
                    print "maximum-scale = $value\n" if $debug;
                    if ( $value < 5.0 ) {
                        Record_Result("WCAG_2.0-SC1.4.4", $line, $column, $text,
                                      String_Value("Meta viewport maximum-scale less than 5.0"));
                    }
                }
            }
        }
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
# Name: Check_Aria_Labelledby_Attribute
#
# Parameters: self - reference to this parser
#             tag - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#    This function checks ARIA attributes of a tag. It checks
# to see an attribute is present and has a value.  If an 
# aria-labelledby attribute is found, it checks the id values.
#
#***********************************************************************
sub Check_Aria_Labelledby_Attribute {
    my ($self, $tag, $line, $column, $text, %attr) = @_;

    my ($aria_labelledby, $aid, $tcid, $role);

    #
    # Do we have a aria-labelledby attribute ?
    #
    if ( defined($attr{"aria-labelledby"}) ) {
        $aria_labelledby = $attr{"aria-labelledby"};
        $aria_labelledby =~ s/^\s*//g;
        $aria_labelledby =~ s/\s*$//g;
        print "Have aria-labelledby = \"$aria_labelledby\"\n" if $debug;

        #
        # Determine the testcase that is appropriate for the tag
        #
        if ( $tag eq "a" ) {
            $tcid = "WCAG_2.0-ARIA7";
        }
        elsif ( $tag eq "button" ) {
            $tcid = "WCAG_2.0-ARIA16";
        }
        elsif ( $tag eq "embed" ) {
            $tcid = "WCAG_2.0-ARIA10";
        }
        elsif ( $tag eq "input" ) {
            $tcid = "WCAG_2.0-ARIA16";
        }
        elsif ( $tag eq "object" ) {
            $tcid = "WCAG_2.0-ARIA10";
        }
        elsif ( $tag eq "p" ) {
            $tcid = "WCAG_2.0-ARIA10";
        }
        elsif ( $tag eq "select" ) {
            $tcid = "WCAG_2.0-ARIA16";
        }
        elsif ( $tag eq "textarea" ) {
            $tcid = "WCAG_2.0-ARIA9";
        }
        else {
            #
            # Do we have a role attribute values that is a landmark role ?
            # http://www.w3.org/TR/wai-aria/roles#landmark_roles
            #
            if ( defined($attr{"role"}) ) {
                #
                # Check each role value against the set of landmark
                # role values.  If we find a match then we must be using
                # technique ARIA13.
                #
                foreach $role (split(/\s+/, $attr{"role"})) {
                    if ( defined($landmark_role{$role}) ) {
                        #
                        # Found landmark role
                        #
                        $tcid = "WCAG_2.0-ARIA13";
                       last;
                    }
                }
            }

            #
            # If we don't have a specific tag, use technique ARIA10
            #
            if ( ! defined($tcid) ) {
                $tcid = "WCAG_2.0-ARIA10";
            }
        }

        #
        # Do we have content for the aria-labelledby attribute ?
        #
        if ( $aria_labelledby eq "" ) {
            #
            # Missing aria-labelledby value
            #
            if ( $tag_is_visible ) {
                Record_Result($tcid, $line, $column, $text,
                              String_Value("Missing content in") .
                              "'aria-labelledby='" .
                              String_Value("for tag") . "<$tag>");
            }
        }
        else {
            #
            # Record location of aria-labelledby references
            #
            foreach $aid (split(/\s+/, $aria_labelledby)) {
                print "Record aria_labelledby_location $aid:$line:$column:$tag:$tcid\n" if $debug;
                $aria_labelledby_location{"$aid"} = "$line:$column:$tag:$tcid";
            }

            #
            # If we have a text handler and
            #  - are inside an anchor tag
            #  - are inside a button tag
            #  - are inside an input tag
            #  - are inside an object tag
            #  - are inside a select tag
            #  - are inside a textarea tag
            # this aria-labelledby can act as a text alternative.
            #
            if ( $have_text_handler &&
                 ($inside_anchor || ($tag eq "button") ||
                                    ($tag eq "input") ||
                                    ($tag eq "object") ||
                                    ($tag eq "select") ||
                                    ($tag eq "textarea")) ) {
                push(@text_handler_all_text, "ALT:" . $attr{"aria-labelledby"});
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Aria_Describedby_Attribute
#
# Parameters: self - reference to this parser
#             tag - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#    This function checks ARIA attributes of a tag. It checks
# to see an attribute is present and has a value.  If an 
# aria-describedby attribute is found, it checks the id values.
#
#***********************************************************************
sub Check_Aria_Describedby_Attribute {
    my ($self, $tag, $line, $column, $text, %attr) = @_;

    my ($aria_describedby, $aid, $tcid, $role);

    #
    # Do we have a aria-describedby attribute ?
    #
    if ( defined($attr{"aria-describedby"}) ) {
        $aria_describedby = $attr{"aria-describedby"};
        $aria_describedby =~ s/^\s*//g;
        $aria_describedby =~ s/\s*$//g;
        print "Have aria-describedby = \"$aria_describedby\"\n" if $debug;

        #
        # Determine the testcase that is appropriate for the tag
        #
        if ( $tag eq "a" ) {
            $tcid = "WCAG_2.0-ARIA1";
        }
        elsif ( $tag eq "button" ) {
            $tcid = "WCAG_2.0-ARIA1";
        }
        elsif ( $tag eq "img" ) {
            $tcid = "WCAG_2.0-ARIA15";
        }
        elsif ( $tag eq "input" ) {
            $tcid = "WCAG_2.0-ARIA1";
        }
        elsif ( $tag eq "label" ) {
            $tcid = "WCAG_2.0-ARIA16";
        }
        elsif ( $tag eq "select" ) {
            $tcid = "WCAG_2.0-ARIA1";
        }
        elsif ( $tag eq "title" ) {
            $tcid = "WCAG_2.0-ARIA1";
        }
        else {
            #
            # If we don't have a specific tag, use technique ARIA1
            #
            $tcid = "WCAG_2.0-ARIA1";
        }

        #
        # Do we have content for the aria-describedby attribute ?
        #
        if ( $aria_describedby eq "" ) {
            #
            # Missing aria-describedby value
            #
            if ( $tag_is_visible ) {
                Record_Result($tcid, $line, $column, $text,
                              String_Value("Missing content in") .
                              "'aria-describedby='" .
                              String_Value("for tag") . "<$tag>");
            }
        }
        else {
            #
            # Record location of aria-describedby references
            #
            foreach $aid (split(/\s+/, $aria_describedby)) {
                $aria_describedby_location{"$aid"} = "$line:$column:$tag:$tcid";
            }

            #
            # If we have a text handler and
            #  - are inside an anchor tag
            #  - are inside a button tag
            #  - are inside an input tag
            #  - are inside a select tag
            # this aria-describedby can act as a text alternative.
            #
            if ( $have_text_handler &&
                 ($inside_anchor || ($tag eq "button") ||
                                    ($tag eq "input") ||
                                    ($tag eq "select")) ) {
                push(@text_handler_all_text, "ALT:" . $attr{"aria-describedby"});
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
# Name: Main_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles main tags.
#
#***********************************************************************
sub Main_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;
    
    my ($last_main, $last_line, $last_column);

    #
    # Have we already seen a <main> or a <section> or <div> tag
    # with a role="main" attribute?
    #
    if ( $main_content_start ne "" ) {
        #
        # Multiple main content areas in page.
        #
        ($last_main, $last_line, $last_column) = split(/:/, $main_content_start);

        #
        # Check line and column of this tag and last main tag.
        # If we have <main role="main">, don't report an error.
        #
        if ( ($line != $last_line) || ($column != $last_column) ) {
            print "Multiple main content areas\n" if $debug;
            Record_Result("WCAG_2.0-SC1.3.1", $line, $column, $text,
                          String_Value("Multiple main content areas found, previous instance found") .
                          " $last_main " . String_Value("at line:column") .
                          " $last_line:$last_column");
        }
    }
    else {
        #
        # Record the details of the start of the main content area
        #
        print "Found main content at <main>\n" if $debug;
        $main_content_start = "<main>:$line:$column";
    }
}

#***********************************************************************
#
# Name: End_Main_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end main tag.
#
#***********************************************************************
sub End_Main_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($clean_text);

    #
    # Get all the text found within the main tag
    #
    if ( ! $have_text_handler ) {
        print "End main tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the main text as a string and get rid of excess white space
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, " "));
    print "End_Main_Tag_Handler: text = \"$clean_text\"\n" if $debug;

    #
    # Do we have text within the main tags ?
    #
    if ( $clean_text eq "" ) {
        print "Main tag has no text\n" if $debug;
        Record_Result("WCAG_2.0-SC1.3.1", $line, $column, $text,
                      String_Value("Missing text in") . "<main>");
    }
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

    my ($href, $name);

    #
    # Check for rel attribute on the tag
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
    $current_a_arialabel = "";
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
        if ( $tag_is_visible && $inside_label ) {
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
        # Do we have a aria-label attribute for this link ?
        #
        if ( defined( $attr{"aria-label"} ) ) {
            $current_a_arialabel = $attr{"aria-label"};
        }

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
                if ( $tag_is_visible ) {
                    Record_Result("WCAG_2.0-H33", $line, $column, $text,
                                  String_Value("Anchor title same as href"));
                }
            }
            elsif ( $current_a_title eq "" ) {
                #
                # Title attribute with no content
                #
                print "title is empty string\n" if $debug;
#
# Don't treat empty title as an error.
#
#                if ( $tag_is_visible ) {
#                    Record_Result("WCAG_2.0-H33", $line, $column, $text,
#                                  String_Value("Missing title content for") .
#                                  "<a>");
#                }
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
    # Check that there is at least 1 of href, id, name or xlink attributes
    #
    if ( defined($attr{"href"}) || defined($attr{"id"}) || 
         defined($attr{"name"}) || defined($attr{"xlink:title"})) {
        print "Anchor has href, id, name or xlink:title\n" if $debug;
    }
    elsif ( $tag_is_visible) {
        Record_Result("WCAG_2.0-G115", $line, $column, $text,
                      String_Value("Missing href, id, name or xlink in <a>"));
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
    # Save new heading level
    #
    $current_heading_level = $level;
    
    #
    # Did we find a <hr> tag being used for decoration prior a <h1> tag ?
    #
    if ( ($level == 1) && ($last_tag eq "hr") ) {
        Record_Result("WCAG_2.0-F43", $line, $column, $text,
                      "<hr>" . String_Value("followed by") . "<$tagname> " .
                      String_Value("used for decoration"));
    }

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
    $last_heading_text =~ s/ALT://g;
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
        if ( $tag_is_visible ) {
            Record_Result("WCAG_2.0-F43", $line, $column,
                          $text, String_Value("Missing text in") . "<h>");
            Record_Result("WCAG_2.0-G130", $line, $column,
                          $text, String_Value("Missing text in") . "<h>");
        }
    }
    #
    # Is heading too long (perhaps it is a paragraph).
    # This isn't an exact test, what we want to find is if the heading
    # is descriptive.  A very long heading would not likely be descriptive,
    # it may be more of a complete sentense or a paragraph.
    #
    elsif ( length($last_heading_text) > $max_heading_title_length ) {
        if ( $tag_is_visible ) {
            Record_Result("WCAG_2.0-H42", $line, $column, $text,
                      String_Value("Heading text greater than 500 characters") .
                      " \"$last_heading_text\"");
        }
    }

    #
    # Unset global flag to indicate we are no longer inside an
    # <h> ... </h> tag set
    #
    $inside_h_tag_set = 0;
    
    #
    # Unset flag to indicate we found content after a heading.
    #
    $found_content_after_heading = 0;
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
    # If this is a nested object tag, if the parent has a label, then
    # this tag will inherit the label.
    #
    if ( $object_nest_level > 1 ) {
        $object_has_label{$object_nest_level} = $object_has_label{$object_nest_level - 1};
    }

    #
    # Check for an aria-label attribute that acts as the text
    # alternative for this label.  We don't check for a value here,
    # that is checked in function Check_Aria_Attributes.
    #
    print "Check for aria-label attribute\n" if $debug;
    if ( defined($attr{"aria-label"}) ) {
        $object_has_label{$object_nest_level} = 1;
    }

    #
    # Check for an aria-labelledby attribute that acts as the text
    # alternative for this label.
    #
    print "Check for aria-labelledby attribute\n" if $debug;
    if ( defined($attr{"aria-labelledby"}) ) {
        #
        # We have a label for the object
        #
        $object_has_label{$object_nest_level} = 1;
    }

    #
    # Save attributes of object tag.  These will be added to with
    # any found in <param> tags to get the total set of attributes
    # for this object.
    #
    push(@param_lists, \%attr);
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
    # Do we have a label attribute (e.g. aria-label) ?
    #
    if ( $object_has_label{$object_nest_level} == 1 ) {
        print "Object tag has label attribute\n" if $debug;
    }
    #
    # Do we have text within the object tags ?
    #
    elsif ( $clean_text ne "" ) {
        print "Object tag has text\n" if $debug;
    }
    #
    # No text alternative for object tag.
    #
    elsif ( $tag_is_visible) {
        if ( @tcids > 0 ) {
            foreach $tcid (@tcids) {
                Record_Result($tcid, $line, $column, $text,
                              String_Value("Missing text in") . "<object>");
            }
        }
    }

    #
    # Decrement object nesting level
    #
    if ( $object_nest_level > 0 ) {
        $object_nest_level--;
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
    if ( ! defined($attr{"alt"}) ) {
        Record_Result("WCAG_2.0-H35", $line, $column, $text,
                      String_Value("Missing alt attribute for") . "<applet>");
    }

    #
    # Check alt text content ?
    #
    Check_Alt_Content("WCAG_2.0-H35", "<applet>", $self, $line,
                      $column, $text, %attr);
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
    if ( $tag_is_visible && ($clean_text eq "") ) {
        Record_Result("WCAG_2.0-H35", $line, $column,
                      $text, String_Value("Missing text in") . "<applet>");
    }
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
# Name: Br_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles br tags.  It checks for a possible pseudo-heading
# that appears at the beginning of a block (e.g. 
#    <p><strong> some text </strong><br/> more text </p>)
#
# Suppress this check for now, there are a number of false errors
# being generated.
#
#***********************************************************************
sub Br_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($clean_text);

    #
    # Get text of parent tag of the br tag
    #
#    $clean_text = Clean_Text(Get_Text_Handler_Content($self, " "));

    #
    # Check for emphasised text at the beginning of a p or div that
    # comes before this tag.  If we have saved emphasised text and it
    # matches the parent tags text, we have a pseudo heading.
    #
#    Check_Pseudo_Heading("", $clean_text, $line, $column, $text);
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
    # Is this a submit button ? if so set flag to indicate there is one in the
    # form.
    #
    if ( defined($attr{"type"}) ) {
        #
        # Is the type value "submit" or empty string (default is submit) ?
        #
        if ( ($attr{"type"} eq "submit") || ($attr{"type"} eq "") ) {
            #
            # Is this input part of a form ?
            #
            if ( Is_A_Form_Input("button type=\"submit\"", $line, $column,
                                 $text, %attr) ) {
                $found_input_button = 1;
                print "Found button in form\n" if $debug;
            }
        }
        #
        # Is this a reset button outside of a form ?
        #
        elsif ( $attr{"type"} eq "reset" ) {
            #
            # Is this input part of a form ?
            #
            if ( Is_A_Form_Input("button type=\"reset\"", $line, $column,
                                 $text, %attr) ) {
                $found_input_button = 1;
                print "Found button in form\n" if $debug;
            }
        }
    }

    #
    # Do we have an id attribute that matches a label ?
    #
    if ( defined($attr{"id"}) ) {
        $id = $attr{"id"};
        if ( $tag_is_visible && defined($label_for_location{"$id"}) ) {
            #
            # Label must not be used for a button
            #
            Record_Result("WCAG_2.0-H44", $line, $column, $text,
                          String_Value("label not allowed for") . "<button>");
        }
    }

    #
    # Do we have a title ? if so add it to the button text handler
    # so we can check it's value when we get to the end button
    # tag.
    #
    if ( defined($attr{"title"}) && ($attr{"title"} ne "") ) {
        push(@text_handler_all_text, $attr{"title"});
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

    my ($this_text, $last_line, $last_column, $clean_text, $start_tag_attr);
    my ($complete_label);

    #
    # Get start tag attributes
    #
    $start_tag_attr = $current_tag_object->attr();

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
    # Did we find a <aria-describedby> attribute ?
    #
    if ( defined($start_tag_attr) &&
        (defined($$start_tag_attr{"aria-describedby"})) &&
        ($$start_tag_attr{"aria-describedby"} ne "") ) {
        #
        # Technique
        #   ARIA1: Using the aria-describedby property to provide a
        #   descriptive label for user interface controls
        #
        print "Found aria-describedby attribute ARIA1\n" if $debug;
    }
    #
    # Did we find a <aria-label> attribute ?
    #
    elsif ( defined($start_tag_attr) &&
        (defined($$start_tag_attr{"aria-label"})) &&
        ($$start_tag_attr{"aria-label"} ne "") ) {
        #
        # Technique
        #   ARIA14: Using aria-label to provide an invisible label
        #   where a visible label cannot be used
        # used for label
        #
        print "Found aria-label attribute ARIA14\n" if $debug;
    }
    #
    # Did we find a <aria-labelledby> attribute ?
    #
    elsif ( defined($start_tag_attr) &&
        (defined($$start_tag_attr{"aria-labelledby"})) &&
        ($$start_tag_attr{"aria-labelledby"} ne "") ) {
        #
        # Technique
        #   ARIA9: Using aria-labelledby to concatenate a label from
        #   several text nodes
        # used for label
        #
        print "Found aria-labelledby attribute ARIA9\n" if $debug;
    }
    #
    # Do we have button text ?
    #
    elsif ( $clean_text ne "" ) {
        #
        # Technique
        #   H91: Using HTML form controls and links
        # used for label
        #
        print "Found text in button H91\n" if $debug;

        #
        # Get the complete label that may include table headings
        # and fieldset legends.
        #
        $complete_label = Complete_Label($clean_text);

#
# Don't check for duplicate buttons.  There are cases where this is acceptable
# (e.g. video player with a play button in the poster image and in the
# controls).
#
#        #
#        # Have we seen this label before ?
#        #
#        if ( defined($form_label_value{lc($complete_label)}) ) {
#            Record_Result("WCAG_2.0-G197", $line, $column,
#                          $text, String_Value("Duplicate") .
#                          " <button> \"$clean_text\" " .
#                          String_Value("Previous instance found at") .
#                          $form_label_value{lc($complete_label)});
#        }
#        else {
#            #
#            # Save label location
#            #
#            $form_label_value{lc($complete_label)} = "$line:$column"
#        }
    }
    #
    # Is tag visible ?
    #
    elsif ( $tag_is_visible ) {
        Record_Result("WCAG_2.0-H91", $line, $column,
                      $text, String_Value("Missing text in") . "<button>");
    }
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
    # Are we inside a layout table ? There must not be a caption in
    # layout tables.
    #
    if ( $table_is_layout[$table_nesting_index] ) {
        Record_Result("WCAG_2.0-F46", $line, $column, $text,
                      String_Value("caption found in layout table"));
    }
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
        if ( $tag_is_visible ) {
            Record_Result("WCAG_2.0-H39", $line, $column, $text,
                          String_Value("Missing text in") . "<caption>");
        }
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
            if ( $tag_is_visible ) {
                Record_Result("WCAG_2.0-H39", $line, $column, $text,
                              String_Value("Duplicate table summary and caption"));
                Record_Result("WCAG_2.0-H73", $line, $column, $text,
                              String_Value("Duplicate table summary and caption"));
            }
        }
    }
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
    # Do we have figcaption text ?
    #
    if ( $clean_text ne "" ) {
        $have_figcaption = 1;
    }
    elsif ( $tag_is_visible ) {
        #
        # Missing text
        #
        Record_Result("WCAG_2.0-G115", $line, $column, $text,
                      String_Value("Missing text in") . "<figcaption>");
    }
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
    # Save the option's attributes
    #
    %last_option_attributes = %attr;
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
        #
        # Check for possible label attribute that provides
        # the option value.
        #
        if ( defined($last_option_attributes{"label"}) &&
             (! ($last_option_attributes{"label"} =~ /^\s*$/)) ) {
            print "Label attribute acts as option content\n" if $debug;
        }
        elsif ( $tag_is_visible ) {
            Record_Result("WCAG_2.0-G115", $line, $column, $text,
                          String_Value("Missing text in") . "<option>");
        }
    }

    #
    # Clear last option attributes table
    #
    %last_option_attributes = ();
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
        if ( ($tag_is_visible ) && (! $have_figcaption) ) {
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
# Name: Details_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles details tags.
#
#***********************************************************************
sub Details_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Clear any summary tag content
    #
    undef($summary_tag_content);
}

#***********************************************************************
#
# Name: End_Details_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end details tag.
#
#***********************************************************************
sub End_Details_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($clean_text);

    #
    # Get all the text found within the details tag
    #
    if ( ! $have_text_handler ) {
        print "End details tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the details text as a string, remove all white space and convert
    # to lowercase
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
    print "End_Details_Tag_Handler: text = \"$clean_text\"\n" if $debug;

    #
    # Do we have any <summary> text ?
    #
    if ( defined($summary_tag_content) ) {
        #
        # Remove the summary content to see if we have any additional details
        # content.
        #
        print "Remove summary content \"$summary_tag_content\"\n" if $debug;
        eval {$clean_text =~ s/$summary_tag_content//};
    }

    #
    # Is there any details text ?
    #
    $clean_text =~ s/\s//g;
    print "Check for empty details content \"$clean_text\"\n" if $debug;
    if ( $clean_text eq "" ) {
        if ( $tag_is_visible ) {
            Record_Result("WCAG_2.0-G115", $line, $column,
                          $text, String_Value("Missing text in") . "<details>");
        }
    }
}

#***********************************************************************
#
# Name: Summary_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles summary tags.
#
#***********************************************************************
sub Summary_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;
}

#***********************************************************************
#
# Name: End_Summary_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end summary tag.
#
#***********************************************************************
sub End_Summary_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($clean_text);

    #
    # Get all the text found within the summary tag
    #
    if ( ! $have_text_handler ) {
        print "End summary tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the summary text as a string, remove all white space and convert
    # to lowercase
    #
    $summary_tag_content = Clean_Text(Get_Text_Handler_Content($self, ""));
    print "End_Summary_Tag_Handler: text = \"$summary_tag_content\"\n" if $debug;

    #
    # Is there any summary text ?
    #
    $clean_text = $summary_tag_content;
    $clean_text =~ s/\s//g;
    if ( $clean_text eq "" ) {
        if ( $tag_is_visible ) {
            Record_Result("WCAG_2.0-G115", $line, $column,
                          $text, String_Value("Missing text in") . "<summary>");
        }
    }
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
        if ( $tag_is_visible ) {
            Record_Result("WCAG_2.0-F54", $line, $column, $text,
                          String_Value("Mouse only event handlers found"));
        }
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
        if ( $tag_is_visible && ($error ne "") ) {
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
    my ($line, $column, $text, %attr) = @_;

    my ($id);
    
    #
    # Set flag to indicate we are within a <form> .. </form>
    # tag pair and that we have not seen a button yet.
    #
    print "Start of form\n" if $debug;
    $in_form_tag = 1;
    $form_count++;
    $found_input_button = 0;
    $last_radio_checkbox_name = "";
    $number_of_writable_inputs = 0;
    %input_id_location     = ();
    %label_for_location    = ();
    %form_label_value      = ();
    %form_legend_value     = ();
    %form_title_value      = ();
    
    #
    # Get the form's id value
    #
    if ( defined($attr{"id"}) ) {
        $id = $attr{"id"};
        $id =~ s/^\s*//g;
        $form_id_values{$id} = "$line:$column";
        
        #
        # We can remove any saved inputs that reference this form if those
        # inputs preceeded the form. This saves checking those inputs for
        # a valid form at the end of the page.
        #
        if ( defined($input_form_id{$id}) ) {
            print "Remove saved inputs that referenced this form\n" if $debug;
            undef($input_form_id{$id});
        }
    }
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
    if ( $form_count > 0 ) {
      $form_count--;
    }
    else {
        $form_count = 0;
    }
    if ( $form_count == 0 ) {
      $in_form_tag = 0;
    }

    #
    # Did we see a button inside the form ?
    #
    if ( $tag_is_visible &&
         ((! $found_input_button) && ($number_of_writable_inputs > 0)) ) {
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
    Check_Missing_And_Extra_Labels_In_Form();
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
# Name: Start_Header_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the header tag.  It sets a global variable
# indicating we are inside the <header>..</header> section.
#
#***********************************************************************
sub Start_Header_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    #
    # Set flag to indicate we are within a <header> .. </header>
    # tag pair.
    #
    print "Start of header\n" if $debug;
    $in_header_tag = 1;
}

#***********************************************************************
#
# Name: End_Header_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the end header tag. It sets a global variable
# indicating we are inside the <header>..</header> section.
#
#***********************************************************************
sub End_Header_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    #
    # Set flag to indicate we are outside a <header> .. </header>
    # tag pair.
    #
    print "End of header\n" if $debug;
    $in_header_tag = 0;
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
    $abbr_acronym_title = "";
    if ( defined( $attr{"title"} ) ) {
        $abbr_acronym_title = Clean_Text($attr{"title"});
        print "Title attribute = \"$abbr_acronym_title\"\n" if $debug;

        #
        # Check for missing value.
        #
        if ( $tag_is_visible && ($abbr_acronym_title eq "") ) {
            Record_Result("WCAG_2.0-G115", $line, $column, $text,
                          String_Value("Missing title content for") . "<$tag>");
        }
    }
    elsif ( $tag_is_visible ) {
        #
        # Missing title attribute
        #
        Record_Result("WCAG_2.0-G115", $line, $column, $text,
                      String_Value("Missing title attribute for") . "<$tag>");
    }
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
    $content = lc($content);

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
            if ( $tag_is_visible ) {
                Record_Result("WCAG_2.0-G197", $line, $column, $text,
                              String_Value("Title values do not match for") .
                              " <$tag>$content</$tag>  " . 
                              String_Value("Found") . " \"$title\" " .
                              String_Value("previously found") .
                              " \"$prev_title\" ".
                              String_Value("at line:column") . $prev_location);
           }
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
            if ( $tag_is_visible ) {
                Record_Result("WCAG_2.0-G197", $line, $column, $text,
                              String_Value("Content values do not match for") .
                              " <$tag title=\"$title\" > " . 
                              String_Value("Found") . " \"$content\" " .
                              String_Value("previously found") .
                              " \"$prev_text\" ".
                              String_Value("at line:column") . $prev_location);
            }
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
                if ( $tag_is_visible ) {
                    Record_Result("WCAG_2.0-G115", $line, $column, $text,
                                  String_Value("Content same as title for") .
                                  " <$tag>$clean_text</$tag>");
                }
            }
            else {
                #
                # Check consistency of content and title
                #
                Check_Acronym_Abbr_Consistency($tag, $abbr_acronym_title,
                                               $clean_text, $line, $column,
                                               $text);
            }
            
            #
            # Add the acronym/abbreviation title to the text handler to be
            # included in the tag's content.
            #
            Text_Handler($abbr_acronym_title);
        }
    }
    elsif ( $tag_is_visible ) {
        #
        # Missing text for abbreviation or acronym
        #
        print "Missing text for $tag\n" if $debug;
        Record_Result("WCAG_2.0-G115", $line, $column, $text,
                      String_Value("Missing text in") . "<$tag>");
    }
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

    my ($clean_text, $attr);

    #
    # Get all the text found within the tag
    #
    print "End_Tag_Must_Have_Content_handler: tag = $tag\n" if $debug;
    if ( ! $have_text_handler ) {
        print "End $tag tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Is this a <section> tag?
    #
    if ( $tag eq "section" ) {
        #
        # Get attribute list from corresponding start tag
        #
        if ( defined($current_tag_object) ) {
            $attr = $current_tag_object->attr();

            #
            # Do we have a role="main" for the start tag?
            #
            if ( defined($$attr{"role"}) && ($$attr{"role"} eq "main") ) {
                #
                # Don't check missing content here, it will be checked later
                # in function Check_End_Role_Main, which checks
                # the main content area.
                #
                print "Skip content check for <section role=\"main\"\n" if $debug;
                return;
            }
        }
    }

    #
    # Get the text as a string, remove excess white space
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
    print "text = \"$clean_text\"\n" if $debug;
    
    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<$tag>", $line, $column, $clean_text);

    #
    # Check that we have some content.
    #
    if ( $tag_is_visible && ($clean_text eq "") ) {
        #
        # Missing text for tag
        #
        print "Missing text for $tag\n" if $debug;
        Record_Result("WCAG_2.0-G115", $line, $column, $text,
                      String_Value("Missing text in") . "<$tag>");
    }
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
    if ( $tag_is_visible && ($clean_text eq "") ) {
        #
        # Missing text for tag
        #
        print "Missing text for q\n" if $debug;
        Record_Result("WCAG_2.0-G115", $line, $column, $text,
                      String_Value("Missing text in") . "<q>");
    }
}

#***********************************************************************
#
# Name: Script_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the script tag.
#
#***********************************************************************
sub Script_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;
}

#***********************************************************************
#
# Name: End_Script_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a handler for end script tag.
# It checks to see that there was text between the start and end tags.
#
#***********************************************************************
sub End_Script_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($clean_text);

    #
    # Get all the text found within the tag
    #
    if ( ! $have_text_handler ) {
        print "End script tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the text as a string, remove excess white space
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
    print "End_Script_Tag_Handler: text = \"$clean_text\"\n" if $debug;
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
            if ( $tag_is_visible ) {
                Record_Result($tcid, $line, $column, $text,
                              String_Value("Missing cite content for") .
                              "$tag");
            }
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
                if ( $tag_is_visible &&
                     ((! defined($resp)) || (! $resp->is_success)) ) {
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
    if ( $tag_is_visible && ($clean_text eq "") ) {
        #
        # Missing text for tag
        #
        print "Missing text for blockquote\n" if $debug;
        Record_Result("WCAG_2.0-G115", $line, $column, $text,
                      String_Value("Missing text in") . "<blockquote>");
    }
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
    if ( $tag_is_visible && ($clean_text eq "") ) {
        Record_Result("WCAG_2.0-G115", $line, $column,
                      $text, String_Value("Missing content in") . "<li>");
    }
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
# that acts as a header or introduction text for the list.
#
#***********************************************************************
sub Check_Start_of_New_List {
    my ( $self, $tag, $line, $column, $text ) = @_;

    my ($clean_text, $i, $parent_list_headings);

    #
    # Is this a nested list ?
    #
    print "Check_Start_of_New_List $tag, list level = $current_list_level\n" if $debug;
    if ( $current_list_level > -1 ) {
        print "New list inside an existing list\n" if $debug;

        #
        # A new list as the content of an existing list item.  Do we have
        # any text that acts as a header ?
        #
        if ( $have_text_handler ) {
            #
            # Get the list item text as a string, remove excess white space
            #
            $clean_text = Clean_Text(Get_Text_Handler_Content_For_Parent_Tag());
        }
        else {
            #
            # No text handler so no text.
            #
            $clean_text = "";
        }

        #
        # If we are inside a <fieldset>, we can use the <legend> as
        # the introduction text.
        #
        if ( $fieldset_tag_index > 0 ) {
            $clean_text .= " " . $legend_text_value{$fieldset_tag_index};
        }

        #
        # Are we missing header text ?
        #
        print "Check_Start_of_New_List: text = \"$clean_text\"\n" if $debug;
        if ( $tag_is_visible && ($clean_text eq "") ) {
            #
            # Are we inside a <dd> tag? If so the <dt> content acts
            # as the list header.
            #
            if ( ($current_list_level > -1) &&
                 ($inside_dd[$current_list_level] == 1) ) {
                print "Inside a <dd>, the <dt> is the list introduction text\n" if $debug;
            }
            #
            # No content before the list
            #
            else {
                Record_Result("WCAG_2.0-G115", $line, $column, $text,
                              String_Value("Missing content before list") .
                              " <$tag>");
            }
        }
        
        #
        # If we have nested lists, use the heading text from all lists to
        # get a, hopefully, unique heading.
        #
        $parent_list_headings = "";
        for ($i = 0; $i < $current_list_level; $i++) {
            $parent_list_headings .= $list_heading_text[$i];
        }
        print "Parent lists heading text = \"$parent_list_headings\"\n" if $debug;
        $clean_text = $parent_list_headings . $clean_text;
        
        #
        # Save list heading text
        #
        print "List heading text = \"$clean_text\"\n" if $debug;
        $list_heading_text[$current_list_level] = $clean_text;
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
    # Start of new list, are we already inside a list ?
    #
    Check_Start_of_New_List($self, $tag, $line, $column, $text);

    #
    # Increment list level count and set list item count to zero
    #
    $current_list_level++;
    $list_item_count[$current_list_level] = 0;
    $inside_list_item[$current_list_level] = 0;
    $list_heading_text[$current_list_level] = "";
    $inside_dd[$current_list_level] = 0;
    print "Start new $tag list, level $current_list_level\n" if $debug;
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
        if ( $tag_is_visible && ($list_item_count[$current_list_level] == 0) ) {
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
# Name: Dd_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the dd tag.
#
#***********************************************************************
sub Dd_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Set flag to indicate we are inside a dd tag
    #
    if ( $current_list_level > -1 ) {
        $inside_dd[$current_list_level] = 1;
        print "Start new dd, level $current_list_level\n" if $debug;
    }
}

#***********************************************************************
#
# Name: End_Dd_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end dd tag.
#
#***********************************************************************
sub End_Dd_Tag_Handler {
    my ( $line, $column, $text ) = @_;

    #
    # Clear flag to indicate we are no longer inside a dd tag
    #
    if ( $current_list_level > -1 ) {
        $inside_dd[$current_list_level] = 0;
        print "End dd, level $current_list_level\n" if $debug;
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
    if ( $tag_is_visible && ($clean_text eq "") ) {
        Record_Result("WCAG_2.0-G115", $line, $column,
                      $text, String_Value("Missing content in") . "<dt>");
    }
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
    # Start of new list, are we already inside a list ?
    #
    Check_Start_of_New_List($self, "dl", $line, $column, $text);

    #
    # Increment list level count and set list item count to zero
    #
    $current_list_level++;
    $list_item_count[$current_list_level] = 0;
    $inside_dd[$current_list_level] = 0;
    print "Start new dl list, level $current_list_level\n" if $debug;
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
        if ( $tag_is_visible && ($list_item_count[$current_list_level] == 0) ) {
            #
            # No items in list
            #
            Record_Result("WCAG_2.0-H48", $line, $column, $text,
                          String_Value("No dt found in list") . "<dl>");
        }

        #
        # Decrement list level
        #
        $inside_dd[$current_list_level] = 0;
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

    my ($id, $id_line, $id_column, $id_is_visible, $id_is_hidden, $id_tag);
    
    #
    # Are we ignoring id attributes for this tag ?
    #
    print "Check_ID_Attribute\n" if $debug;
    if ( defined($tags_to_ignore_id_attribute{$tagname}) ) {
        print "Ignore id attribute for this tag\n" if $debug;
    }
    #
    # Do we have an id attribute ?
    #
    elsif ( defined($attr{"id"}) ) {
        $id = $attr{"id"};
        $id =~ s/^\s*//g;
        $id =~ s/\s*$//g;
        print "Found id \"$id\" in tag $tagname at $line:$column\n" if $debug;

        #
        # Have we seen this id before ?
        #
        if ( defined($id_attribute_values{$id}) ) {
            ($id_line, $id_column, $id_is_visible, $id_is_hidden, $id_tag) = split(/:/, $id_attribute_values{$id});
            Record_Result("WCAG_2.0-F77", $line, $column,
                          $text, String_Value("Duplicate id") .
                          "'<$tagname id=\"$id\">' " .
                          String_Value("Previous instance found at") .
                          "$id_line:$id_column <$id_tag id=\"$id\">");
        }

        #
        # Save id location
        #
        $id_attribute_values{$id} = "$line:$column:$tag_is_visible:$tag_is_hidden,$tagname";
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
            #
            # Skip possible blank attribute
            #
            if ( $attribute eq "" ) {
               next;
            }

            #
            # Check for another instance of this attribute in the list
            #
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
                    last;
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
# Name: Check_Style_to_Hide_Content
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             style_names - style names on tag
#
# Description:
#
#   This function checks for styles that hide content.  It checks for
# - display:none
# - visibility:hidden
# - width or height of 0
# - clip: rect(1px, 1px, 1px, 1px)
#
#***********************************************************************
sub Check_Style_to_Hide_Content {
    my ($tagname, $line, $column, $text, $style_names) = @_;

    my ($style, $style_object, $value);
    my ($found_hide_style) = 0;
    my ($found_off_screen_style) = 0;
    my ($found_display) = 0;

    #
    # Is the parent tag hidden ? If so we don't need to check this one
    #
    if ( $tag_is_hidden ) {
        print "Skip Check_Style_to_Hide_Content for tag $tagname, parent tag is hidden\n" if $debug;
        return;
    }

    #
    # Check all possible style names
    #
    print "Check_Style_to_Hide_Content for tag $tagname\n" if $debug;
    foreach $style (split(/\s+/, $style_names)) {
        #
        # Ignore styles with :after or :before attributes, that content
        # may be hidden, but it is decorative content.
        #
        if ( ($style =~ /:after/i) || ($style =~ /:before/i) ) {
            print "Skip :after/:before style $style\n" if $debug;
            next;
        }
        
        #
        # If the style is defined, get it's properties.
        #
        if ( defined($css_styles{$style}) ) {
            $style_object = $css_styles{$style};
            #
            # Do we have a content property ?
            #
#            $value = CSS_Check_Style_Get_Property_Value($style, $style_object,
#                                                        "content");

            #
            # Do we have clip: rect(1px, 1px, 1px, 1px) ?
            #
            $value = CSS_Check_Style_Get_Property_Value($style, $style_object,
                                                        "clip");
            if ( defined($value)
                 && ( $value =~ /rect\s*\(1px\s*[,]?\s*1px\s*[,]?\s*1px\s*[,]?\s*1px\s*[,]?\s*\)/ ) ) {
                #
                # Do we also have position: absolute ?
                #
                $value = CSS_Check_Style_Get_Property_Value($style,
                                                            $style_object,
                                                            "position");
                if ( $value =~ /absolute/ ) {
                    $found_off_screen_style = 1;
                    print "Found rect(1px, 1px, 1px, 1px) in style $style\n" if $debug;
                    last;
                }
            }

            #
            # Do we have display property ?
            #
            $value = CSS_Check_Style_Get_Property_Value($style, $style_object,
                                                        "display");

            #
            # Is the value "none" and this is the first occurance of
            # display in any style ?
            #
            if ( defined($value) && (! $found_display) && ($value =~ /^none$/i) ) {
                $found_hide_style = 1;
                print "Found display:none in style $style\n" if $debug;
            }
            #
            # If the value is not none, set hide style to false
            #
            elsif ( defined($value) && (! ($value =~ /^none$/i)) ) {
                $found_hide_style = 0;
                print "Found display:$value in style $style\n" if $debug;
            }

            #
            # If we have a value, set flag to indicate we found it
            #
            if ( defined($value) ) {
                $found_display = 1;
            }

            #
            # Do we have height: 0px ?
            #
            if ( CSS_Check_Style_Has_Property_Value($style, $style_object,
                                                    "height", "0px") ) {
                $found_hide_style = 1;
                print "Found height: 0px in style $style\n" if $debug;
                last;
            }

            #
            # Do we have visibility:hidden ?
            #
            if ( CSS_Check_Style_Has_Property_Value($style, $style_object,
                                                    "visibility", "hidden") ) {
                $found_hide_style = 1;
                print "Found visibility:hidden in style $style\n" if $debug;
                last;
            }
            
            #
            # Do we have width: 0px ?
            #
            if ( CSS_Check_Style_Has_Property_Value($style, $style_object,
                                                    "width", "0px") ) {
                $found_hide_style = 1;
                print "Found width: 0px in style $style\n" if $debug;
                last;
            }
        }
    }

    #
    # Did we find a class that hides content ?  If we didn't we use the
    # value from the parent tag.
    #
    if ( $found_hide_style ) {
        #
        # Set global tag hidden and tag visible flags
        #
        $tag_is_hidden = 1;
        $tag_is_visible = 0;
        print "Tag is hidden\n" if $debug;
    }
    #
    # Did we find a class that hides content ?  If we didn't we use the
    # value from the parent tag.
    #
    elsif ( $found_off_screen_style ) {
        #
        # Set global tag visible flags
        #
        $tag_is_visible = 0;
        print "Tag is offscreen\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Check_Presentation_Attributes
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
#   This function checks for presentation attributes.  This
# may, for example, be a 'style' attribute a 'class' attribute.  If styles
# are found they are recorded in a style stack for the tag.
#
#   A check is also made to see if a style specifies 'display:none',
# which hides content from screen readers.  This is needed as some
# accessibility issues are not applicable if the content is not
# available to screen readers.
#
# See http://webaim.org/techniques/css/invisiblecontent/ for details.
#
#***********************************************************************
sub Check_Presentation_Attributes {
    my ($tagname, $line, $column, $text, $attrseq, %attr) = @_;

    my ($a_style, %style_map);
    my ($style_names) = "";

    #
    # Save the current style names, visibility and hidden values
    #
    print "Check_Presentation_Attributes for tag $tagname\n" if $debug;

    #
    # Do we have a style attribute ?
    #
    if ( defined($attr{"style"}) && ($attr{"style"} ne "") ) {
        #
        # Generate a unique style name for this inline style
        #
        $inline_style_count++;
        $style_names = "inline_" . $inline_style_count . "_$tagname";
        print "Found inline style in tag $tagname, generated class = $style_names\n" if $debug;
        %style_map = CSS_Check_Get_Styles_From_Content($current_url,
                                      "$style_names {" . $attr{"style"} . "}",
                                                       "text/html");

        #
        # Add this style to the CSS styles for this URL
        #
        $css_styles{$style_names} = $style_map{$style_names};
    }

    #
    # Do we have a class attribute ?
    #
    if ( defined($attr{"class"}) && ($attr{"class"} ne "") ) {
        #
        # We may have a list of style names include style names with and
        # without the tag name
        #
        foreach $a_style (split(/\s+/, $attr{"class"})) {
            $style_names .=  " $tagname.$a_style .$a_style"
                           . " $tagname.$a_style:before .$a_style:before"
                           . " $tagname.$a_style:after .$a_style:after";
        }
        print "Found classes $style_names\n" if $debug;
    }
    
    #
    # Save style list in tag object
    #
    $current_tag_object->styles($style_names);

    #
    # Check for a hidden attribute
    #
    if ( defined($attr{"hidden"}) ) {
        #
        # Set global tag hidden and tag visibility flag
        #
        print "Found attribute 'hidden' on tag\n" if $debug;
        $tag_is_hidden = 1;
        $tag_is_visible = 0;
    }

    #
    # Check for a aria-hidden attribute
    #
    if ( defined($attr{"aria-hidden"}) && ($attr{"aria-hidden"} eq "true") ) {
        #
        # Set global tag hidden and tag visibility flag
        #
        print "Found attribute 'aria-hidden' on tag\n" if $debug;
        $tag_is_hidden = 1;
        $tag_is_visible = 0;
    }

    #
    # Check for CSS used to hide content
    #
    if ( $style_names ne "" ) {
        Check_Style_to_Hide_Content($tagname, $line, $column, $text, $style_names);
    }

    #
    # Save hidden and visibility attributes in tag object
    #
    $current_tag_object->is_hidden($tag_is_hidden);
    $current_tag_object->is_visible($tag_is_visible);

    #
    # Set global variable for styles associated to the current tag.
    #
    $current_tag_styles = $style_names;
    print "Current tag_is_visible = $tag_is_visible, tag_is_hidden = $tag_is_hidden for tag $tagname\n" if $debug;
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
        if ( $tag_is_visible && ($onfocus =~ /^\s*this\.blur\(\)\s*/i) ) {
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
# Name: Check_Role_Attribute
#
# Parameters: tagname - tag name
#             role_list - list of role values
#
# Description:
#
#   This function checks the implicit and explicit ARIA role attributes
# of tags in the tag stack to see if they match one of the supplied
# roles.  This function returns the first role match.
#
#***********************************************************************
sub Check_Role_Attribute {
    my ($tagname, $role_list) = @_;

    my ($context_role, $tag, $tag_role, $attr_addr, $found_role);
    my ($found_required_context_role, $implicit_roles);

    #
    # Step up the tag stack looking for a tag with an appropriate
    # role value
    #
    print "Check_Role_Attribute: Check for roles $role_list\n" if $debug;
    $found_required_context_role = 0;
    $found_role = "";
    foreach $tag (reverse @tag_order_stack) {
        #
        # Check for a role attribute on the tag item
        #
        $attr_addr = $tag->attr();
        print "Check role value in tag " . $tag->tag() . "\n" if $debug;
        if ( defined($attr_addr) && defined($$attr_addr{"role"}) ) {
            $tag_role = $$attr_addr{"role"};

            #
            # Does the role match one of the required roles?
            #
            foreach $context_role (split(/\s+/, $role_list)) {
                if ( $tag_role eq $context_role ) {
                    print "Found required context role $tag_role in tag\n" if $debug;
                    $found_required_context_role = 1;
                    $found_role = $tag_role;
                    last;
                }
            }
        }

        #
        # Did we find a required context role value?
        #
        if ( $found_required_context_role ) {
            last;
        }

        #
        # Check the tag's implicit role
        #
        $implicit_roles = $tag->implicit_role();
        if ( defined($implicit_roles) && ($implicit_roles ne "") ) {
            #
            # Check all possible implicit roles
            #
            print "Check tag's implicit roles $implicit_roles\n" if $debug;
            foreach $tag_role (split(/\s+/, $implicit_roles)) {
                #
                # Does the role match one of the required context roles?
                #
                foreach $context_role (split(/\s+/, $role_list)) {
                    if ( $tag_role eq $context_role ) {
                        print "Found required context role $tag_role in tag\n" if $debug;
                        $found_required_context_role = 1;
                        $found_role = $tag_role;
                        last;
                    }
                }

                #
                # Did we find the required context role value?
                #
                if ( $found_required_context_role ) {
                    last;
                }
            }
        }
    }
    
    #
    # Return the matched role value
    #
    return($found_role);
}

#***********************************************************************
#
# Name: Check_Aria_Role_Attribute
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks the ARIA role attribute.  It checks
# for a 
#
#***********************************************************************
sub Check_Aria_Role_Attribute {
    my ($tagname, $line, $column, $text, %attr) = @_;

    my ($role, $last_main, $last_line, $last_column);
    my ($context_role, $context_role_list);

    #
    # Check for possible role attribute
    #
    if ( defined($attr{"role"}) ) {
        $role = $attr{"role"};
        $role =~ s/^\s*//g;
        $role =~ s/\s*//g;

        #
        # Check for role="heading" on a tag other than a h tag
        #
        print "Check for heading in role=\"$role\" attribute\n" if $debug;
        if ( ($role eq "heading") && (! ($tagname =~ /^h[0-9]?$/)) ) {

            #
            # Check for a possible aria-level attribute.  If
            # we have one and it's value is greater than 6, we
            # don't report an error as there is no <h7>, or higher, tag.
            #
            if ( defined($attr{"aria-level"}) && ($attr{"aria-level"} > 6) ) {
                #
                # Found aria-level greater than 6, this heading role is
                # acceptable
                #
            }
            else {
                #
                # Either no aria-level or the value is less than 7
                #
                Record_Result("WCAG_2.0-ARIA12", $line, $column, $text,
                              String_Value("Found") .
                              " role=\"heading\" " . 
                              String_Value("in tag") . "<$tagname>");
            }
        }

        #
        # Check role for group or radiogroup, if we have one we also
        # expect 1 of aria-label or aria-labelledby
        #
        if ( ($role eq "group") || ($role eq "radiogroup") ) {
            if ( defined($attr{"aria-label"}) || 
                 defined($attr{"aria-labelledby"}) ) {
                print "Have role=\"$role\" and one of aria-label or aria-labelledby\n" if $debug;
            }
            else {
                #
                # Missing aria-label or aria-labelledby
                #
                Record_Result("WCAG_2.0-ARIA17", $line, $column, $text,
                              String_Value("Found") .
                              " role=\"$role\". " . 
                              String_Value("Missing") .
                              " \"aria-label\"" . String_Value("or") .
                              "\"aria-labelledby\"");
            }
        }

        #
        # Check role for alertdialog, if we have one we also
        # expect 1 of aria-label or aria-labelledby
        #
        if ( $role eq "alertdialog" ) {
            if ( defined($attr{"aria-label"}) || 
                 defined($attr{"aria-labelledby"}) ) {
                print "Have role=\"$role\" and one of aria-label or aria-labelledby\n" if $debug;
            }
            else {
                #
                # Missing aria-label or aria-labelledby
                #
                Record_Result("WCAG_2.0-ARIA18", $line, $column, $text,
                              String_Value("Found") .
                              " role=\"$role\". " . 
                              String_Value("Missing") .
                              " \"aria-label\"" . String_Value("or") .
                              "\"aria-labelledby\"");
            }
        }

        #
        # Check role for main, it indicates the beginning of the main content
        # area
        #
        if ( $role eq "main" ) {
            #
            # Have we already seen a <main> or a <section> or <div> tag
            # with a role="main" attribute?
            #
            if ( $main_content_start ne "" ) {
                #
                # Multiple main content areas in page.
                #
                ($last_main, $last_line, $last_column) = split(/:/, $main_content_start);
                
                #
                # Check line and column of this tag and last main tag.
                # If we have <main role="main">, don't report an error.
                #
                if ( ($line != $last_line) || ($column != $last_column) ) {
                    Record_Result("WCAG_2.0-SC1.3.1", $line, $column, $text,
                                  String_Value("Multiple main content areas found, previous instance found") .
                                  " $last_main " . String_Value("at line:column") .
                                  " $last_line:$last_column");
                }
            }
            else {
                #
                # Record the details of the start of the main content area
                #
                $main_content_start = "<$tagname role=\"main\">:$line:$column";
            }
        }
        
        #
        # Check for any required context roles
        #
        if ( defined($aria_required_context_roles{$role}) ) {
            $context_role_list = $aria_required_context_roles{$role};
            print "Role $role requires context roles of $context_role_list\n" if $debug;
            $context_role = Check_Role_Attribute($tagname, $context_role_list);

            #
            # Did we find a required context role value?
            #
            if ( $context_role eq "" ) {
                Record_Result("WCAG_2.0-H88", $line, $column, $text,
                              String_Value("Missing required context role for") .
                              " role=\"$role\" " .
                              String_Value("expecting one of") .
                              " \"$context_role_list\"");
            }
        }

#
# Skip check for role="presentation".  Generated markup from WET pages
# include a large number of tags with this attribute.
#
#        #
#        # Check for role="presentation" on tags that convey content or
#        # relationships
#        #
#        if ( ($role eq "presentation") &&
#             defined($tags_that_must_not_have_role_presentation{$tagname}) ) {
#            #
#            # Found role="presentation" where not allowed
#            #
#            Record_Result("WCAG_2.0-F92", $line, $column, $text,
#                          String_Value("Found") .
#                          " role=\"$role\" " .
#                          String_Value("in tag used to convey information or relationships"));
#        }
    }

    #
    # Check any implicit role(s) for this tag to ensure any required
    # context roles are present.
    #
    if ($current_tag_object->implicit_role() ne "" ) {
        $role = $current_tag_object->implicit_role();
        print "Check implicit role $role for this tag\n" if $debug;
        
        #
        # Check for any required context roles
        #
        if ( defined($aria_required_context_roles{$role}) ) {
            $context_role_list = $aria_required_context_roles{$role};
            print "Role $role requires context roles of $context_role_list\n" if $debug;
            $context_role = Check_Role_Attribute($tagname, $context_role_list);

            #
            # Did we find a required context role value?
            #
            if ( $context_role eq "" ) {
                Record_Result("WCAG_2.0-H88", $line, $column, $text,
                              String_Value("Missing required context role for implicit role") .
                              " \"$role\" " .
                              String_Value("expecting one of") .
                              " \"$context_role_list\"");
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Aria_Attributes
#
# Parameters: self - reference to this parser
#             tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attrseq - reference to an array of attributes
#             attr - hash table of attributes
#
# Description:
#
#   This function checks for some WAI-ARIA attribues such as
#     aria-label
#     aria-labelledby
#
#***********************************************************************
sub Check_Aria_Attributes {
    my ($self, $tagname, $line, $column, $text, $attrseq, %attr) = @_;

    my ($value, $tcid, $attribute, $roles_list, $context_role);

    #
    # Check for aria-label attribute
    #
    print "Check_Aria_Attributes\n" if $debug;
    print "Check for aria-label attribute\n" if $debug;
    if ( defined($attr{"aria-label"}) ) {
        $value = $attr{"aria-label"};
        $value =~ s/^\s*//g;
        $value =~ s/\s*$//g;

        #
        # Determine the testcase that is appropriate for the tag
        #
        if ( $tagname eq "a" ) {
            $tcid = "WCAG_2.0-ARIA8";
        }
        else {
            $tcid = "WCAG_2.0-ARIA6";
        }

        #
        # Do we have content for the aria-label attribute ?
        #
        if ( $tag_is_visible && ($value eq "") ) {
            #
            # Missing value
            #
            Record_Result($tcid, $line, $column, $text,
                          String_Value("Missing content in") .
                          "'aria-label='" .
                          String_Value("for tag") . "<$tagname>");
        }

        #
        # If we are inside an anchor tag, this aria-label can act
        # as a text alternative for an image link.
        #
        if ( $inside_anchor && $have_text_handler && ($attr{"aria-label"} ne "") ) {
            push(@text_handler_all_text, "ALT:" . $attr{"aria-label"});
        }
    }
    
    #
    # Do we have an ARIA attribute that has some role attribute requirements
    #
    foreach $attribute (keys(%attr)) {
        if ( defined($aria_used_in_roles{$attribute}) ) {
            $roles_list = $aria_used_in_roles{$attribute};
            $context_role = Check_Role_Attribute($tagname, $roles_list);

            #
            # Did we find a required context role value?
            #
            if ( $context_role eq "" ) {
                Record_Result("WCAG_2.0-H88", $line, $column, $text,
                              String_Value("Missing required context role for WAI-ARIA attribute") .
                              " \"$attribute\" " .
                              String_Value("expecting one of") .
                              " \"$roles_list\"");
            }
        }
    }

    #
    # Check role attribute
    #
    Check_Aria_Role_Attribute($tagname, $line, $column, $text, %attr);

    #
    # Check aria-describedby attribute
    #
    Check_Aria_Describedby_Attribute($self, $tagname, $line, $column, $text,
                                     %attr);

    #
    # Check aria-labelledby attribute
    #
    Check_Aria_Labelledby_Attribute($self, $tagname, $line, $column, $text,
                                    %attr);
}

#***********************************************************************
#
# Name: Check_Alt_Attribute
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
#   This function checks for the alt attribute on tags that should not
# have an alt.  If an attribute is found, it then checks for a class
# attribute that specifies a CSS style that loads an image.
#
#***********************************************************************
sub Check_Alt_Attribute {
    my ($tagname, $line, $column, $text, $attrseq, %attr) = @_;

    my ($alt, $tcid, $style, $value, $style_object);

    #
    # Check for alt attribute on a tag that should not have alt and if
    # we havve styles for this tag
    #
    print "Check_Alt_Attribute\n" if $debug;
    if ( defined($attr{"alt"}) 
         && ($attr{"alt"} ne "")
         && ($current_tag_styles ne "")
         && (! defined($tags_allowed_alt_attribute{$tagname})) ) {
        #
        # We have alt content on a tag that should not have alt
        #
        $alt = $attr{"alt"};
        print "Found alt=\"$alt\" on tag $tagname\n" if $debug;

        #
        # Check all possible style names
        #
        foreach $style (split(/\s+/, $current_tag_styles)) {
            if ( defined($css_styles{$style}) ) {
                $style_object = $css_styles{$style};

                #
                # Do we have a 'background-image' property ?
                #
                $value = CSS_Check_Style_Get_Property_Value($style,
                                                            $style_object,
                                                            "background-image");

                #
                # Do we have a url value ?
                #
                if ( $value =~ /url\s*\(/i ) {
                    #
                    # Image loaded via CSS
                    #
                    Record_Result("WCAG_2.0-F3", $line, $column, $text,
                                  String_Value("Non-decorative image loaded via CSS with") .
                                  " alt=\"$alt\" " .
                                  String_Value("for tag") . "<$tagname>" .
                                  " CSS property: background-image. " .
                                  String_Value("Alt attribute not allowed on this tag"));
                    last;
                }

                #
                # Do we have a 'background' property ?
                #
                $value = CSS_Check_Style_Get_Property_Value($style,
                                                            $style_object,
                                                            "background");

                #
                # Do we have a url value ?
                #
                if ( $value =~ /url\s*\(/i ) {
                    Record_Result("WCAG_2.0-F3", $line, $column, $text,
                                  String_Value("Non-decorative image loaded via CSS with") .
                                  " alt=\"$alt\" " .
                                  String_Value("for tag") . "<$tagname>" .
                                  " CSS property: background-image. " .
                                  String_Value("Alt attribute not allowed on this tag"));
                    last;
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Attributes
# 
# Parameters: self - reference to this parser
#             tagname - tag name
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
    my ( $self, $tagname, $line, $column, $text, $attrseq, %attr ) = @_;

    my ($error, $id, $attribute, $this_attribute, @attribute_list);

    #
    # Check id attribute
    #
    print "Check_Attributes for tag $tagname\n" if $debug;
    Check_ID_Attribute($tagname, $line, $column, $text, $attrseq, %attr);

    #
    # Check for duplicate attributes
    #
    Check_Duplicate_Attributes($tagname, $line, $column, $text, $attrseq,
                               %attr);

    #
    # Check lang & xml:lang attributes
    #
    Check_Lang_Attribute($tagname, $line, $column, $text, $attrseq, %attr);

    #
    # Check for presentation (e.g. style) attributes
    #
    Check_Presentation_Attributes($tagname, $line, $column, $text, $attrseq, %attr);

    #
    # Check for alt attribute on tags that should not have alt
    #
    Check_Alt_Attribute($tagname, $line, $column, $text, $attrseq, %attr);

    #
    # Check onfocus attribute
    #
    Check_OnFocus_Attribute($tagname, $line, $column, $text, $attrseq, %attr);

    #
    # Check some WAI-ARIA attributes
    #
    Check_Aria_Attributes($self, $tagname, $line, $column, $text, $attrseq,
                          %attr);

    #
    # Check for accesskey attribute
    #
    Check_Accesskey_Attribute($tagname, $line, $column, $text, %attr);

    #
    # Look for deprecated tag attributes
    #
    Check_Deprecated_Attributes($tagname, $line, $column, $text, %attr);
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
            # Get the tag and location
            #
            $tag = $tag_item->tag;
            $location = $tag_item->line_no . ":" . $tag_item->column_no;

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

    my ($last_start_tag, $tag_item, $location, $last_item, $tag_list);

    #
    # Get last start tag.
    #
    print "Check_For_Implicit_End_Tag_Before_Start_Tag for $tagname\n" if $debug;
    $last_item = @tag_order_stack - 1;
    if ( $last_item >= 0 ) {
        $tag_item = $tag_order_stack[$last_item];

        #
        # Get tag and location
        #
        $last_start_tag = $tag_item->tag;
        $location = $tag_item->line_no . ":" . $tag_item->column_no;
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
#             length - position in the content stream
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
    my ($self, $language, $tagname, $line, $column, $text,
        $skipped_text, $attrseq, @attr ) = @_;

    my (%attr_hash) = @attr;
    my ($tag_item, $tag, $location);

    #
    # Check to see if this start tag implicitly closes any
    # open tags.
    #
    print "Start_Handler tag $tagname at $line:$column\n" if $debug;
    $tagname =~ s/\///g;
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
    # Start a text handler for this tag if it has an end tag
    #
    if ( ! defined ($html_tags_with_no_end_tag{$tagname}) ) {
        Start_Text_Handler($self, $tagname);
    }

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
    # Create a new tag object
    #
    $current_tag_object = tqa_tag_object->new($tagname, $line, $column,
                                              \%attr_hash);
    push(@tag_order_stack, $current_tag_object);

    #
    # Compute the current landmark and implicit roled and add
    # them to the tag object.
    #
    ($current_landmark, $landmark_marker) = HTML_Landmark($tagname, $line,
                       $column, $current_landmark, $landmark_marker,
                       \@tag_order_stack, %attr_hash);
    $current_tag_object->landmark($current_landmark);
    $current_tag_object->landmark_marker($landmark_marker);
    if ( defined($implicit_aria_roles{$tagname}) ) {
        $current_tag_object->implicit_role($implicit_aria_roles{$tagname});
    }

    #
    # Check attributes
    #
    Check_Attributes($self, $tagname, $line, $column, $text, $attrseq,
                     %attr_hash);
                     
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
    # Check area tag
    #
    elsif ( $tagname eq "area" ) {
        Area_Tag_Handler($self, $language, $line, $column, $text, %attr_hash);
    }

    #
    # Check audio tag
    #
    elsif ( $tagname eq "audio" ) {
        Audio_Tag_Handler( $line, $column, $text, %attr_hash );
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
    # Check br tag
    #
    elsif ( $tagname eq "br" ) {
        #Br_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check button tag
    #
    elsif ( $tagname eq "button" ) {
        Button_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check caption tag
    #
    elsif ( $tagname eq "caption" ) {
        Caption_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check details tag
    #
    elsif ( $tagname eq "details" ) {
        Details_Tag_Handler($self, $line, $column, $text, %attr_hash);
    }

    #
    # Check div tag
    #
    elsif ( $tagname eq "div" ) {
        Div_Tag_Handler($self, $language, $line, $column, $text, %attr_hash);
    }

    #
    # Check dd tag
    #
    elsif ( $tagname eq "dd" ) {
        Dd_Tag_Handler( $self, $line, $column, $text, %attr_hash );
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
    # Check figure tag
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
    # Check header tag
    #
    elsif ( $tagname eq "header" ) {
        Start_Header_Tag_Handler( $line, $column, $text, %attr_hash );
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
    # Check image tag
    #
    elsif ( $tagname eq "img" ) {
        Image_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check input tag
    #
    elsif ( $tagname eq "input" ) {
        Input_Tag_Handler( $self, $line, $column, $text, %attr_hash );
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
    # Check main tag
    #
    elsif ( $tagname eq "main" ) {
        Main_Tag_Handler( $line, $column, $text, %attr_hash );
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
    # Check option tag
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
    # Check script tag
    #
    elsif ( $tagname eq "script" ) {
        Script_Tag_Handler($self, $line, $column, $text, %attr_hash);
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
    # Check summary tag
    #
    elsif ( $tagname eq "summary" ) {
        Summary_Tag_Handler($self, $line, $column, $text, %attr_hash);
    }

    #
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
    # Check tfoot tag
    #
    elsif ( $tagname eq "tfoot" ) {
        Tfoot_Tag_Handler( $line, $column, $text, %attr_hash );
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
    # Check track tag
    #
    elsif ( $tagname eq "track" ) {
        Track_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check ul tag
    #
    elsif ( $tagname eq "ul" ) {
        Ol_Ul_Tag_Handler( $self, $tagname, $line, $column, $text, %attr_hash );
    }

    #
    # Check video tag
    #
    elsif ( $tagname eq "video" ) {
        Video_Tag_Handler( $line, $column, $text, %attr_hash );
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
    # Check event handlers
    #
    Check_Event_Handlers( $tagname, $line, $column, $text, %attr_hash );

    #
    # Is this a tag that has no end tag ? If so we must set the last tag
    # seen value here rather than in the End_Handler function.
    #
    if ( defined ($html_tags_with_no_end_tag{$tagname}) ) {
        $last_close_tag = $tagname;
        $current_tag_object = pop(@tag_order_stack);
        $current_landmark = $current_tag_object->landmark();
        $landmark_marker = $current_tag_object->landmark_marker();
    }

    #
    # Set last open tag seen
    #
    $last_open_tag = $tagname;
    $last_tag = $tagname;
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
    if ( $tag_is_visible &&
         (index($click_here_patterns, " $link_text ") != -1) ) {
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
    my (@tc_list, $anchor_text, $n, $link_text, $tcid, $http_href);
    my ($start_tag_attr, $on_page_id_reference);
    my ($all_anchor_text) = "";
    my ($image_alt_in_anchor) = "";

    #
    # Get start tag attributes
    #
    if ( defined($current_tag_object) ) {
        $start_tag_attr = $current_tag_object->attr();
    }

    #
    # Get all the text & image paths found within the anchor tag
    #
    if ( ! $have_text_handler ) {
        print "End anchor tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }
    @anchor_text_list = @text_handler_all_text;

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
                if ( $tag_is_visible && ($this_text eq $last_image_alt_text) ) {
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
        if ( $tag_is_visible &&
             ($image_found_inside_anchor xor $last_a_contains_image) ) {
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
    # Did we have a title attribute on the start anchor tag ?
    #
    if ( $current_a_title ne "" ) {
        #
        # If we have no anchor text use the title attribute as the tag's
        # content (may be needed by parent tag).
        #
        if ( $have_text_handler && ($all_anchor_text =~ /^\s*$/) ) {
            push(@text_handler_all_text, " $current_a_title");
            print "Add anchor title \"$current_a_title\" to text handler\n" if $debug;
        }

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
    # Do we have aria-labelledby attribute ?
    #
    if ( defined($start_tag_attr) &&
        (defined($$start_tag_attr{"aria-labelledby"})) &&
        ($$start_tag_attr{"aria-labelledby"} ne "") ) {
        #
        # Technique
        #   ARIA7: Using aria-labelledby for link purpose
        # used for label
        #
        print "Found aria-labelledby attribute on anchor ARIA7\n" if $debug;
    }
    #
    # Do we have aria-label attribute ?
    #
    elsif ( defined($start_tag_attr) &&
        (defined($$start_tag_attr{"aria-label"})) &&
        ($$start_tag_attr{"aria-label"} ne "") ) {
        #
        # Technique
        #   ARIA8: Using aria-label for link purpose
        # used for label
        #
        print "Found aria-label attribute on anchor ARIA8\n" if $debug;
    }
    #
    # Do we have a URL and no anchor text ?
    #
    elsif ( ($all_anchor_text eq "") && ($current_a_href ne "") ) {
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
            if ( $tag_is_visible && ($current_a_title eq "") ) {
                Record_Result("WCAG_2.0-F89", $line, $column,
                              $text, String_Value("Null alt on an image"));
            }
        }
        elsif ( $tag_is_visible ) {
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
            #
            # Is the link is visible?
            # Don't report an error is the HTML is part of an EPUB document.
            # A URL as link text is acceptable if the document may be printed.
            #
            if ( $tag_is_visible && (! $html_is_part_of_epub) ) {
                Record_Result("WCAG_2.0-H30", $line, $column, $text,
                              String_Value("Anchor text is a URL"));
            }
        }
        #
        # Check href and anchor values (if they are non-null)
        #
        elsif ( ($current_a_href ne "") &&
             (lc($all_anchor_text) eq lc($current_a_href)) ) {
            if ( $tag_is_visible ) {
                Record_Result("WCAG_2.0-H30", $line, $column, $text,
                              String_Value("Anchor text same as href"));
            }
        }
    }

    #
    # Convert URL into an absolute URL.
    #
    if ( $current_a_href ne "" ) {
        #
        # Is this is an on page renference ?
        #
        if ( $current_a_href =~ /^#/ ) {
            $current_a_href = "";
            $on_page_id_reference = 1;
        }
        else {
            $on_page_id_reference = 0;
        }
        
        #
        # Convert href to an absolute href
        #
        $current_a_href = URL_Check_Make_URL_Absolute($current_a_href,
                                                      $current_url);
    }

    #
    # Do we have anchor text and a URL ?
    #
    if ( ($all_anchor_text ne "") && ($current_a_href ne "") ) {
        #
        # We include heading text if the link appears in a list.
        #
        if ( ($current_list_level > 0) &&
             ($inside_list_item[$current_list_level]) ) {
            $link_text = join(",", @list_heading_text);
            print "Link inside a list item with heading text \"$link_text\"\n" if $debug;
            $link_text = $link_text . $all_anchor_text;
        }
        else {
            $link_text = $last_heading_text . $all_anchor_text;
        }

        #
        # Include aria-label in anchor text
        #
        $link_text .= $current_a_arialabel;

        #
        # Have we seen this anchor text before in the same heading context ?
        # Don't compare link text if the previous one was to an on page
        # reference.
        #
        print "Check link text = $link_text\n" if $debug;
        if ( defined($anchor_text_href_map{$link_text}) &&
             ($anchor_text_href_map{$link_text} ne "#") ) {
            #
            # Do the href values match ?
            #
            $http_href = $current_a_href;
            $http_href =~ s/^https/http/g;
            if ( $http_href ne $anchor_text_href_map{$link_text} ) {

                #
                # Is this link an on page link ?
                # We don't check on page references as we may have a link
                # to a section of the page (e.g. a link menu) that contains
                # a link with the same text that points to another page.  We
                # may miss links to different anchors on the same page with
                # the same text.
                #
                if ( $on_page_id_reference ) {
                    print "Skip href mismatch for on page reference\n" if $debug;
                }
                #
                # Values do not match, is it a case of a development
                # URL and the equivalent production URL ?
                #
                elsif ( Production_Development_URL_Match($current_a_href,
                                  $anchor_text_href_map{$link_text}) ) {
                    print "Equavalent production and development URLs\n" if $debug;
                }
                #
                # Different href values and not a prod/dev
                # instance.
                #
                else {
                    #
                    # Get the previous location
                    #
                    ($last_line, $last_column) =
                            split(/:/, $anchor_location{$link_text});

                    #
                    # If the link is visible, report error
                    #
                    if ( $tag_is_visible ) {
                        Record_Result("WCAG_2.0-H30", $line, $column, $text,
                          String_Value("Multiple links with same anchor text") .
                          "\"$all_anchor_text\" href $current_a_href \n" .
                          String_Value("Previous instance found at") .
                          "$last_line:$last_column href " . 
                          $anchor_text_href_map{$link_text});
                    }
                }
            }
        }
        #
        # Save the anchor text and href in a hash table.
        #
        elsif ( ! defined($anchor_text_href_map{$link_text}) ) {
            #
            # Is this an on page reference, if so just use # as the href
            # value so can detect on page references in subsequent link
            # checks.
            #
            if ( $on_page_id_reference ) {
                $http_href = "#";
            }
            else {
                $http_href = $current_a_href;
                $http_href =~ s/^https/http/g;
            }
            
            #
            # Save the anchor text and href in a hash table
            #
            $anchor_text_href_map{$link_text} = $http_href;
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
    # Ignore the possibility of a pseudo header coming from a link.
    # The link text may have emphasis, but it shouldn't be considered as
    # a header.
    #
    $pseudo_header = "";

    #
    # Reset current anchor href to empty string and clear flag that
    # indicates we are inside an anchor
    #
    $current_a_href = "";
    $inside_anchor = 0;
    $image_found_inside_anchor = 0;
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
                          $text, String_Value("Title text greater than 500 characters") . " \"$clean_text\"");
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

    my ($last_start_tag, $location, $tag_list);
    my ($tag_error) = 0;
    my (%attr_hash) = @attr;

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
        $current_tag_object = pop(@tag_order_stack);

        #
        # Get tag and location
        #
        if ( defined($current_tag_object) ) {
            $last_start_tag = $current_tag_object->tag;
            $location = $current_tag_object->line_no . ":" .
                        $current_tag_object->column_no;
            $current_landmark = $current_tag_object->landmark();
            $landmark_marker = $current_tag_object->landmark_marker();
        }
        else {
            $last_start_tag = "";
            $location ="0:0";
            $current_tag_styles = "";
            $tag_is_visible = 1;
            $tag_is_hidden = 0;
            $current_landmark = "";
            $landmark_marker = "";
        }
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
                    push(@tag_order_stack, tqa_tag_object->new($last_start_tag,
                                                               $line,
                                                               $column,
                                                               \%attr_hash));

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
    $last_close_tag = $tagname;
    $last_tag = $tagname;
}

#***********************************************************************
#
# Name: Check_Styled_Text
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
#   This function checks text for possible styling errors.
#
#***********************************************************************
sub Check_Styled_Text {
    my ($self, $tagname, $line, $column, $text, %attr) = @_;

    my ($tag_text, $results_object, @results_list);

    #
    # Is this tag visible and does it have styling ?
    #
    if ( $tag_is_visible && ($current_tag_styles ne "") ) {
        #
        # Get the text from the tag only, not nested tags.
        # If there is no text we don't have any checks.
        #
        $tag_text = Clean_Text(Get_Text_Handler_Tag_Content($self, " "));
        if ( $tag_text ne "" ) {
            print "Check_Styled_Text\n" if $debug;

            #
            # Check for possible styling errors (e.g. colour
            # contrast).
            #
            @results_list = CSS_Check_Check_Styled_Text($current_url,
                                        $current_tqa_check_profile_name,
                                        $tagname, $line, $column, $text,
                                        $current_tag_styles, \%css_styles);

            #
            # Add any testcase results from the CSS check to the
            # global list.
            #
            foreach $results_object (@results_list) {
                push(@$results_list_addr, $results_object);
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_End_Role_Main
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function checks text to see if the current end tag's corresponding
# start tag had a role="main" attribute.  If it is a main content area,
# the size of the content is checked.
#
#***********************************************************************
sub Check_End_Role_Main {
    my ($self, $tagname, $line, $column, $text) = @_;

    my ($clean_text, $attr, $start_main, $start_line, $start_column);

    #
    # Get attribute list from corresponding start tag
    #
    if ( defined($current_tag_object) ) {
        $attr = $current_tag_object->attr();
        
        #
        # Do we have a role="main" for the start tag?
        #
        if ( defined($attr) && defined($$attr{"role"}) &&
             ($$attr{"role"} eq "main") ) {
            #
            # Get name and location of start tag
            #
            $start_line = $current_tag_object->line_no();
            $start_column = $current_tag_object->column_no();
            print "Found end tag for role=main started at $start_line:$start_column\n" if $debug;
            
            #
            # Get the main text as a string and get rid of excess white space
            #
            $clean_text = Clean_Text(Get_Text_Handler_Content($self, " "));
            print "Check_End_Role_Main: text = \"$clean_text\"\n" if $debug;

            #
            # Do we have text within the main content ?
            #
            if ( $clean_text eq "" ) {
                print "Main content area has no text\n" if $debug;
                Record_Result("WCAG_2.0-SC1.3.1", $start_line, $start_column, "",
                      String_Value("Missing text in") . "<$tagname role=\"main\">");
            }
        }
    }
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
    my ($self, $tagname, $line, $column, $text, @attr) = @_;

    my (%attr_hash) = @attr;
    my (@anchor_text_list, $n, $tag_text, $last_start_tag);
    my ($last_item, $tag_item);

    #
    # Check end tag order, does this end tag close the last open
    # tag ?
    #
    Check_End_Tag_Order($self, $tagname, $line, $column, $text, @attr);

    #
    # Check anchor tag
    #
    if ( $tagname eq "a" ) {
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
    # Check audio tag
    #
    elsif ( $tagname eq "audio" ) {
        End_Audio_Tag_Handler($line, $column, $text);
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
    # Check details tag
    #
    elsif ( $tagname eq "details" ) {
        End_Details_Tag_Handler($self, $line, $column, $text);
    }

    #
    #
    # Check div tag
    #
    elsif ( $tagname eq "div" ) {
        End_Div_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check dd tag
    #
    elsif ( $tagname eq "dd" ) {
        End_Dd_Tag_Handler($line, $column, $text);
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
        End_Dt_Tag_Handler($self, $line, $column, $text);
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
    # Check header tag
    #
    elsif ( $tagname eq "header" ) {
        End_Header_Tag_Handler($self, $line, $column, $text);
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
        End_Li_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check main tag
    #
    elsif ( $tagname eq "main" ) {
        End_Main_Tag_Handler($self, $line, $column, $text);
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
    # Check script tag
    #
    elsif ( $tagname eq "script" ) {
        End_Script_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check strong tag
    #
    elsif ( $tagname eq "strong" ) {
        End_Emphasis_Tag_Handler($self, $tagname, $line, $column, $text);
    }

    #
    # Check summary tag
    #
    elsif ( $tagname eq "summary" ) {
        End_Summary_Tag_Handler($self, $line, $column, $text);
    }

    #
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
        End_TD_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check tfoot tag
    #
    elsif ( $tagname eq "tfoot" ) {
        End_Tfoot_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check th tag
    #
    elsif ( $tagname eq "th" ) {
        End_TH_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check thead tag
    #
    elsif ( $tagname eq "thead" ) {
        End_Thead_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check title tag
    #
    elsif ( $tagname eq "title" ) {
        End_Title_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check track tag
    #
    elsif ( $tagname eq "track" ) {
        End_Track_Tag_Handler($line, $column, $text);
    }

    #
    # Check ul tag
    #
    elsif ( $tagname eq "ul" ) {
        End_Ol_Ul_Tag_Handler($tagname, $line, $column, $text);
    }

    #
    # Check video tag
    #
    elsif ( $tagname eq "video" ) {
        End_Video_Tag_Handler($line, $column, $text);
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
            if ( $tag_is_visible && (! $have_focusable_item) ) {
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

    #
    # Check for styled text
    #
    Check_Styled_Text($self, $tagname, $line, $column, $text, %attr_hash);
    
    #
    # Check for end of main content area
    #
    Check_End_Role_Main($self, $tagname, $line, $column, $text);

    #
    # Restore global tag visibility and hidden status values.
    #
    $last_item = @tag_order_stack - 1;
    if ( $last_item >= 0 ) {
        $tag_item = $tag_order_stack[$last_item];
        $current_tag_styles = $tag_item->styles;
        $tag_is_visible = $tag_item->is_visible;
        $tag_is_hidden = $tag_item->is_hidden;
        $last_start_tag = $tag_item->tag;
        $current_landmark = $tag_item->landmark();
        $landmark_marker = $tag_item->landmark_marker();
    }
    else {
        $current_tag_styles = "";
        $tag_is_visible = 1;
        $tag_is_hidden = 0;
        $last_start_tag = "";
        $current_landmark = "";
        $landmark_marker = "";
    }
    print "Restore tag_is_visible = $tag_is_visible for last start tag $last_start_tag\n" if $debug;
    print "Restore tag_is_hidden = $tag_is_hidden for last start tag $last_start_tag\n" if $debug;

    #
    # Destroy the text handler that was used to save the text
    # portion of this tag.
    #
    Destroy_Text_Handler($self, $tagname);
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
# Name: Check_Missing_And_Extra_Labels_In_Form
#
# Parameters: none
#
# Description:
#
#   This function checks to see if there are any missing labels (referenced
# but not defined). It also checks for extra labels that were not used.
#
#***********************************************************************
sub Check_Missing_And_Extra_Labels_In_Form {

    my ($label_id, $line, $column, $comment, $found, $label_for);
    my ($label_is_visible, $label_is_hidden, $input_is_visible, $input_is_hidden);

    #
    # Check that a label is defined for each one referenced
    #
    print "Check_Missing_And_Extra_Labels_In_Form\n" if $debug;
    foreach $label_id (keys %input_id_location) {
        #
        # Did we find a <label> tag with a matching for= value ?
        #
        ($line, $column, $input_is_visible, $input_is_hidden) = split(/:/, $input_id_location{"$label_id"});
        if ( ! defined($label_for_location{"$label_id"}) ) {
            Record_Result("WCAG_2.0-F68", $line, $column, "",
                          String_Value("No label matching id attribute") .
                          "'$label_id'" . String_Value("for tag") .
                          " <input>");
        }
        #
        # Have a label
        #
        else {
            ($line, $column, $label_is_visible, $label_is_hidden) = split(/:/, $label_for_location{"$label_id"});
            print "Check label id = $label_id, $line:$column:$label_is_visible:$label_is_hidden\n" if $debug;
            #
            # Is input visible and the label hidden ?
            #
            if ( $input_is_visible && $label_is_hidden ) {
                Record_Result("WCAG_2.0-H44", $line, $column, "",
                              String_Value("Label referenced by") .
                              " 'id=\"$label_id\"' " .
                              String_Value("is hidden") . ". <label> " .
                              String_Value("started at line:column") .
                              " $line:$column");
            }
            #
            # Is the input visible and the label visible ?
            #
            elsif ( $input_is_visible && (! $label_is_visible) ) {
                Record_Result("WCAG_2.0-H44", $line, $column, "",
                              String_Value("Label referenced by") .
                              " 'id=\"$label_id\"' " .
                              String_Value("is not visible") . ". <label> " .
                              String_Value("started at line:column") .
                              " $line:$column");
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
#                ($line, $column, $is_visible, $is_hidden) = split(/:/, $label_for_location{"$label_for"});
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
            ($content_lang, $lang, $status) = TextCat_Text_Language(\$content);

            #
            # Does the lang attribute match the content language ?
            #
            print "status = $status, content_lang = $content_lang, span_lang = $span_lang\n" if $debug;
            if ( ($status == 0 ) && ($content_lang ne "" ) &&
                 ($span_lang ne $content_lang) ) {
                print "Span language error\n" if $debug;
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
# Name: Check_Missing_Aria_Id
#
# Parameters: none
#
# Description:
#
#   This function checks to see if there are any missing ARIA id
# values (referenced but not defined).
#
#***********************************************************************
sub Check_Missing_Aria_Id {

    my ($aria_id, $line, $column, $tag, $tcid);
    my ($id_line, $id_column, $id_is_visible, $id_is_hidden, $id_tag);

    #
    # Are we checking for missing ARIA aria-describedby values ?
    #
    print "Check_Missing_Aria_Id\n" if $debug;
    if ( defined($$current_tqa_check_profile{"WCAG_2.0-ARIA1"}) ) {
        #
        # Check that a id is defined for each one referenced
        #
        print "Check aria_describedby_location\n" if $debug;
        foreach $aria_id (keys %aria_describedby_location) {
            #
            # Did we find a tag with a matching id= value ?
            #
            ($line, $column, $tag, $tcid) = split(/:/, $aria_describedby_location{"$aria_id"});
            if ( ! defined($id_attribute_values{"$aria_id"}) ) {
                Record_Result($tcid, $line, $column, "",
                              String_Value("No tag with id attribute") .
                              " '$aria_id' ");
            }
#
# Target does not have to be visible to be referenced.
# http://www.w3.org/TR/html5/editing.html#the-hidden-attribute
#
#            else {
#                #
#                # Is the target visible ?
#                #
#                ($id_line, $id_column, $id_is_visible, $id_is_hidden, $id_tag) = split(/:/, $id_attribute_values{$aria_id});
#                if ( $id_is_hidden ) {
#                    Record_Result($tcid, $line, $column, "",
#                                  String_Value("Content referenced by") .
#                                  " 'aria-describedby=\"$aria_id\"' " .
#                                  String_Value("is hidden") . ", " .
#                                  String_Value("id defined at") .
#                                  " $id_line:$id_column");
#                }
#            }
        }
    }

    #
    # Check that a id is defined for each one referenced
    #
    print "Check aria_describedby_location\n" if $debug;
    foreach $aria_id (keys %aria_labelledby_location) {
        #
        # Did we find a tag with a matching id= value ?
        #
        ($line, $column, $tag, $tcid) = split(/:/, $aria_labelledby_location{"$aria_id"});
        print "Check aria_labelledby_location $aria_id:$line:$column:$tag:$tcid\n" if $debug;
        if ( ! defined($id_attribute_values{"$aria_id"}) ) {
            Record_Result($tcid, $line, $column, "",
                          String_Value("No tag with id attribute") .
                          "'$aria_id'");
        }
#
# Target does not have to be visible to be referenced.
# http://www.w3.org/TR/html5/editing.html#the-hidden-attribute
#
#        else {
#            #
#            # Is the target visible ?
#            #
#            ($id_line, $id_column, $id_is_visible, $id_is_hidden, $id_tag) = split(/:/, $id_attribute_values{$aria_id});
#            if ( ! $id_is_not_hidden ) {
#                Record_Result($tcid, $line, $column, "",
#                              String_Value("Content referenced by") .
#                                  " 'aria-labelledby=\"$aria_id\"' " .
#                                  String_Value("is hidden") . ", " .
#                                  String_Value("id defined at") .
#                                  " $id_line:$id_column");
#            }
#        }
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

    my ($label_id, $line, $column, $comment, $found, $form_id, $text);
    my ($english_comment, $french_comment, @comment_lines, $name);
    my ($list_addr, $entry, $tag);

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
    # Did we find any links or frames in this document ?
    #
    if ( (keys(%anchor_text_href_map) == 0)
         && (! $found_frame_tag) ) {
        #
        # No links or frames found in this document.
        # Don't report error if this is part of an EPUB document.  EPUB
        # documents have global navigation (i.e. table of contents) and the
        # content may not link to any web resources.
        #
        if ( ! $html_is_part_of_epub ) {
            Record_Result("WCAG_2.0-G125", -1, 0, "",
                          String_Value("No links found"));
        }
    }
    
    #
    # Did we find any inputs that reference forms that do not exist ?
    #
    foreach $form_id (keys(%input_form_id)) {
        $list_addr = $input_form_id{$form_id};
        
        #
        # Process each entry in the list for this form id value
        #
        foreach $entry (@$list_addr) {
            ($tag, $line, $column, $text) = split(/:/, $entry, 4);
            Record_Result("WCAG_2.0-F62", $line, $column, $text,
                          String_Value("No form found with") .
                          " 'id=\"$form_id\"'");
        }
    }

    #
    # Are we missing any ARIA identifiers ?
    #
    Check_Missing_Aria_Id();

    #
    # Check baseline technologies
    #
    Check_Baseline_Technologies();
}

#***********************************************************************
#
# Name: Modified_Content_Start_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             line - line number
#             column - column number
#             length - position in the content stream
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the start of HTML tags.
#
#***********************************************************************
sub Modified_Content_Start_Handler {
    my ( $self, $tagname, $line, $column, $text, @attr ) = @_;

    my (%attr_hash) = @attr;
    my ($tag_item, $tag, $location);

    #
    # Check html tags
    #
    $tagname =~ s/\///g;
    if ( $tagname eq "html" ) {
        HTML_Tag_Handler( $line, $column, $text, %attr_hash );
    }
}

#***********************************************************************
#
# Name: Modified_Content_HTML_Check
#
# Parameters: this_url - a URL
#             resp - HTTP::Response object
#             content - HTML content pointer
#
# Description:
#
#   This function modifies the original HTML content to remove IE conditional
# comments and expose the markup.  The main HTML_Check function would not
# have processed the conditional code as it would appear as HTML comments.
# Once modified, the content is tested for a limited number of checkpoints.
#
#***********************************************************************
sub Modified_Content_HTML_Check {
    my ($this_url, $resp, $content) = @_;

    my ($parser, $mod_content);

    #
    # Create a document parser
    #
    print "Check modified content\n" if $debug;
    $parser = HTML::Parser->new;

    #
    # Add handlers for some of the HTML tags
    #
    $parser->handler(
        start => \&Modified_Content_Start_Handler,
        "self,tagname,line,column,text,\@attr"
    );

    #
    # Remove IE conditional comments from content
    #
    #
    # Remove conditional comments from the content that control
    # IE file inclusion (conditionals found in WET template files).
    #
    $mod_content = $$content;
    $mod_content =~ s/<!--\[if[^>]*>//g;
    $mod_content =~ s/<!--if[^>]*>//g;
    $mod_content =~ s/<!--<!\[endif\]-->//g;
    $mod_content =~ s/<!--<!endif-->//g;
    $mod_content =~ s/<!\[endif\]-->//g;
    $mod_content =~ s/<!endif-->//g;
    $mod_content =~ s/<!-->//g;
    $modified_content = 1;

    #
    # Parse the content.
    #
    @content_lines = split(/\n/, $mod_content);
    $parser->parse($mod_content);
}

#***********************************************************************
#
# Name: HTML_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             resp - HTTP::Response object
#             content - HTML content pointer
#             links - address of a list of link objects
#
# Description:
#
#   This function runs a number of technical QA checks on HTML content.
#
#***********************************************************************
sub HTML_Check {
    my ($this_url, $language, $profile, $resp, $content, $links) = @_;

    my ($parser, @tqa_results_list, $result_object, $testcase);
    my ($lang_code, $lang, $status, $css_content, %on_page_styles);
    my ($selector, $style);

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
    if ( ($this_url =~ /^http/i) || ($this_url =~ /^file/i) ) {
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
    if ( length($$content) > 0 ) {
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
        elsif ( $status == $LANGUAGES_TOO_CLOSE ) {
            #
            # Could not determine the language of the content, the 
            # top language choices were too close.  Report an error
            # as it might be that the content contains several languages
            # that are not properly spanned.
            #
            Record_Result("WCAG_2.0-H57", -1, -1, "",
                          String_Value("Unable to determine content language, possible languages are") .
                          " " . join(", ", TextCat_Too_Close_Languages()));
            $current_content_lang_code = "";
        }
        else {
            $current_content_lang_code = "";
        }

        #
        # Get CSS styles from linked style sheets
        #
        %css_styles = CSS_Check_Get_All_Styles($links);
        
        #
        # Extract any inline CSS from the HTML
        #
        print "Check for inline CSS\n" if $debug;
        $css_content = CSS_Validate_Extract_CSS_From_HTML($this_url,
                                                          $content);

        #
        # Get styles from the CSS content
        #
        if ( $css_content ne "" ) {
            %on_page_styles = CSS_Check_Get_Styles_From_Content($this_url,
                                                            $css_content,
                                                            "text/html");

            #
            # Copy styles into CSS styles table
            #
            while ( ($selector, $style) = each %on_page_styles ) {
                $css_styles{$selector} = $style;
            }
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
        @content_lines = split(/\n/, $$content);
        $parser->parse($$content);
        
        #
        # Run checks on modified HTML content (i.e. remove
        # Internet Explorer conditional comments).
        #
        Modified_Content_HTML_Check($this_url, $resp, $content);
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
# Name: HTML_Check_EPUB_File
#
# Parameters: this_url - a URL
#             language - language of EPUB
#             profile - testcase profile
#             content - HTML content pointer
#
# Description:
#
#   This function runs a number of technical QA checks on HTML content that
# is part of an EPUB document.  Since HTML pages in an EPUD document are not
# stand alone web pages, a number of checks that apply to web pages do
# not apply (e.g. G125: Providing links to navigate to related Web pages).
#
#***********************************************************************
sub HTML_Check_EPUB_File {
    my ($this_url, $language, $profile, $content) = @_;
    
    my ($resp, @links, @tqa_results_list);
    
    #
    # Set global flag to indicate this HTML content is from an EPUB
    # document.
    #
    $html_is_part_of_epub = 1;
    
    #
    # Call HTML_Check to analyse the content
    #
    print "HTML_Check_EPUB_File: Call HTML_Check\n" if $debug;
    @tqa_results_list = HTML_Check($this_url, $language, $profile,
                                   $resp, $content, \@links);
    
    #
    # Clean the global flag indicating that HTML content is from an EPUB
    # document.
    #
    $html_is_part_of_epub = 0;

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
    # Remove leading & trailing whitespace and convert any HTML
    # non-breaking whitespace into a space.
    #
    $string =~ s/\&nbsp;/ /g;
    $string =~ s/[\n\r\s]*$/ /g;
    $string =~ s/^\s*//g;

    #
    # Compress multiple whitespace characters into a single character.
    #
    $string =~ s/\s+/ /g;

    #
    # Return trimmed string.
    #
    return($string);
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

