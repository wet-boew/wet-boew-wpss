#***********************************************************************
#
# Name:   html_check.pm
#
# $Revision: 2554 $
# $URL: svn://10.36.148.185/WPSS_Tool/TQA_Check/Tools/html_check.pm $
# $Date: 2023-07-31 11:13:12 -0400 (Mon, 31 Jul 2023) $
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
use tqa_pa11y;
use tqa_deque_axe;
use pdf_check;
use textcat;
use text_check;
use tqa_result_object;
use tqa_tag_object;
use tqa_testcases;
use url_check;
use tqa_wai_aria;
use validate_markup;
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
    @table_td_count, $current_video_tag,
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
    %id_value_references, $content_heading_count, $total_heading_count,
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
    $inline_style_count, %css_styles, $current_tag_object, $parent_tag_object,
    %input_instance_not_allowed_label, %fieldset_input_count,
    $current_a_arialabel, %last_option_attributes, $tag_is_visible,
    $current_tag_styles, $tag_is_hidden, @table_th_td_in_thead_count,
    $modified_content, $first_html_tag_lang, $summary_tag_content,
    @table_th_td_in_tfoot_count, @inside_tfoot, $inside_video,
    %video_track_kind_map, $found_content_after_heading, $in_header_tag,
    %form_id_values, %input_form_id, %audio_track_kind_map, $inside_audio,
    @list_heading_text, $form_count, @content_lines, @table_is_layout,
    %f32_reported, @inside_dd, @dt_tag_found, $main_content_start,
    $current_landmark, $landmark_marker, $tag_is_aria_hidden,
    $video_in_figure_with_no_caption, $parent_tag, %frame_title_location,
    @heading_level_stack, $found_h1, %landmark_count, $inside_frame,
    %frame_landmark_count, $current_required_children_roles, $current_end_tag,
    %aria_labelledby_controls_location, %aria_owns_tag, $last_img_title,
    $found_title_tag_in_body, $found_valid_meta_refresh,
);

my ($is_valid_html) = -1;

my ($tags_allowed_events) = " a area button form input select ";
my ($input_types_requiring_label_before)  = " file password search text ";
my ($input_types_requiring_label_after)  = " checkbox radio ";
my ($input_types_not_using_label)  = " button hidden image reset submit ";
my ($input_types_requiring_value)  = " button reset submit ";
my ($max_error_message_string)= 2048;
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
#         https://www.oreilly.com/library/view/html-and-xhtml/9780596527273/re05.html
#
my (%deprecated_xhtml_attributes) = (
    "align",      " applet caption div h1 h2 h3 h4 h5 h6 hr iframe img input legend object p table ",
    "alink",      " body ",
#    "alt",        " applet ",
    "archive",    " applet ",
    "background", " body ",
    "bgcolor",    " body table td th tr ",
    "border",     " img object ",
    "clear",      " br ",
#    "code",       " applet ",
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
    "width",      " hr pre td th ",
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
  "track", " audio video ",
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
#    "title", "title", # title can appear in svg tag
);

#
# List of tags and their expected child tags.
# The child tag value may be a comma separated list of
# tags. The list must not contain spaces.
#
my (%parent_child_tags) = (
    "dl", "dd,div,dt,script,template",
    "ol", "li,script,template",
    "ul", "li,script,template",
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
# List of tags that are interactive tags (i.e. will naturally receive focus)
#   https://www.w3.org/TR/html5/dom.html#interactive-content-2
#
my (%interactive_tag) = (
    "a",        1,
    "audio",    1,
    "button",   1,
    "details",  1,
    "embed",    1,
    "iframe",   1,
    "img",      1,
    "input",    1,
    "label",    1,
    "select",   1,
    "textarea", 1,
    "video",    1,
);

#
# Set of tags that are acceptable parent interactive tags. These
# do not create a focus conflict.
#
my (%acceptable_parent_interactive_tag) = (
    "details", 1,
    "label",   1,
);

#
# Valid values for the rel attribute of tags
#
my %valid_xhtml_rel_values = ();

#
# Valid values for the rel attribute of tags
#  Source: https://html.spec.whatwg.org/multipage/links.html#sec-link-types
#          https://www.w3.org/TR/resource-hints/
#  Value "shortcut" is not listed in the above page but is a valid value
#  for <link> tags.
#  Date: 2020-07-30
#
my %valid_html5_rel_values = (
   "a",    " alternate author bookmark external help license next nofollow" .
           " noopener noreferrer opener prefetch prev search sidebar tag ",
   "area", " alternate author bookmark external help license next nofollow" .
           " noopener noreferrer opener prefetch prev search sidebar tag ",
   "form", " external help license next nofollow noopener noreferrer opener prev search ",
   "link", " alternate author canonical dns-prefetch help icon license manifest" .
           " modulepreload next pingback preconnect prefetch preload prerender" .
           " prev search shortcut sidebar stylesheet tag ",
);

#
# Values for the rel attribute of tags
#  Source: http://microformats.org/wiki/existing-rel-values#HTML5_link_type_extensions
#  Date: 2012-11-09
#
$valid_html5_rel_values{"a"} .= "amphtml archived attachment category code-license" .
       " code-repository disclosure entry-content external home hub in-reply-to root index issues jslicense last lightbox lightvideo prerender profile" .
       " publisher radioepg rendition reply-to sidebar syndication webmention widget http://docs.oasis-open.org/ns/cmis/link/200908/acl ";
$valid_html5_rel_values{"area"} .= "amphtml archived attachment category" .
       " code-license code-repository disclosure entry-content external home hub" .
       " in-reply-to root index issues jslicense last lightbox lightvideo prerender profile publisher radioepg rendition reply-to sidebar syndication webmention widget http://docs.oasis-open.org/ns/cmis/link/200908/acl ";
$valid_html5_rel_values{"link"} .= "amphtml apple-touch-icon apple-touch-icon-precomposed" .
       " apple-touch-startup-image archived attachment authorization_endpoint" .
       " canonical category code-license code-repository component" .
       " DCTERMS.conformsTo DCTERMS.contributor DCTERMS.creator DCTERMS.description" .
       " DCTERMS.hasFormat DCTERMS.hasPart DCTERMS.hasVersion DCTERMS.isFormatOf" .
       " DCTERMS.isPartOf DCTERMS.isReferencedBy DCTERMS.isReplacedBy" .
       " DCTERMS.isRequiredBy DCTERMS.isVersionOf DCTERMS.license DCTERMS.mediator" .
       " DCTERMS.publisher DCTERMS.references DCTERMS.relation DCTERMS.replaces" .
       " DCTERMS.requires DCTERMS.rightsHolder DCTERMS.source DCTERMS.subject" .
       " disclosure discussion dns-prefetch edit EditURI enclosure entry-content" .
       " external first gbfs gtfs-static gtfs-realtime home hub import in-reply-to" .
       " root index issues jslicense last lightbox lightvideo manifest" .
       " mask-icon meta micropub openid.delegate openid.server openid2.local_id" .
       " openid2.provider p3pv1 pgpkey pingback preconnect prerender profile" .
       " publisher radioepg rendition reply-to schema.DCTERMS servive shortlink" .
       " sidebar sitemap subresource sword syndication timesheet token_endpoint" .
       " webmention widget wlwmanifest image_src" .
       " http://docs.oasis-open.org/ns/cmis/link/200908/acl stylesheet/less" .
       " schema.dc schema.dcterms yandex-tableau-widget ";

#
# Values for the rel attribute of tags
#   http://microformats.org/wiki/rel-pronunciation
#   Date: 2020-07-30
#
$valid_html5_rel_values{"link"} .= "pronunciation ";

my ($valid_rel_values);

#
# Allowed children roles for WAI-ARIA role values
#   https://www.w3.org/TR/wai-aria-1.1/
# Key is a role and the value is a space seperated list of children roles.
#
# XXXXXX
my (%aria_allowed_children_roles) = (
    "combobox",     "dialog grid listbox textbox tree",
    "feed",         "article",
    "grid",         "row rowgroup",
    "list",         "group listitem",
    "listbox",      "option",
    "menu",         "group menuitem menuitemcheckbox menuitemradio",
    "menubar",      "group menuitem menuitemcheckbox menuitemradio",
    "radiogroup",   "radio",
    "row",          "cell columnheader gridcell rowheader",
    "rowgroup",     "row",
    "table",        "row rowgroup",
    "tablist",      "tab",
    "tree",         "group treeitem",
    "treegrid",     "row rowgroup",
);


#
# Used in roles for WAI-ARIA attributes
#   https://www.w3.org/TR/wai-aria-1.1/
# Key is an attribute name and the value is a space seperated list of roles.
#
my (%aria_used_in_roles) = (
    "aria-activedescendant", "application composite group textbox combobox grid listbox menu menubar radiogroup row searchbox select spinbutton tablist toolbar tree treegrid",
    "aria-selected",         "gridcell option row tab columnheader rowheader treeitem",
    "aria-autocomplete",     "combobox textbox searchbox",
    "aria-checked",          "checkbox option radio switch menuitemcheckbox menuitemradio treeitem",
    "aria-colcount",         "table grid treegrid",
    "aria-colindex",         "cell row columnheader gridcell rowheader",
    "aria-colspan",          "cell columnheader gridcell rowheader",
    "aria-expanded",         "button combobox document link section sectionhead window " .
                             "alert alertdialog article banner cell columnheader complementary contentinfo definition dialog ".
                             "directory feed figure form grid gridcell group heading img landmark list listbox listitem " .
                             "log main marquee math menu menubar navigation note progressbar radiogroup region row rowheader " .
                             "search select status tab table tabpanel term timer toolbar tooltip tree treegrid treeitem",
    "aria-level",            "grid heading listitem row tablist treegrid treeitem",

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
    "h1",               "attr:aria-label:heading",
    "h2",               "attr:aria-label:heading",
    "h3",               "attr:aria-label:heading",
    "h4",               "attr:aria-label:heading",
    "h5",               "attr:aria-label:heading",
    "h6",               "attr:aria-label:heading",
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
# Form element role values.
# The key is the role, the value is the HTML tags with that implicit role.
#
my (%form_element_role_values) = (
    "button",     1,
    "checkbox",   1,
    "combobox",   1,
    "group",      1,
    "listbox",    1,
    "option",     1,
    "radio",      1,
    "searchbox",  1,
    "slider",     1,
    "spinbutton", 1,
    "textbox",    1,
);

#
# Allowed WAI-ARIA roles for HTML tags
#   https://w3c.github.io/html-aria/#docconformance
# Key is a HTML tag and the value is a space separated list of allowed roles.
# If there is no value for the valid roles, then no role may be assigned.
# If the allowed list contains a "string:value" the string is a required
# tag attribute and "value" is an optional value for the roles list.
#
my (%allowed_aria_roles) = (
    "a",               "href: button checkbox menuitem menuitemcheckbox menuitemradio option radio switch tab treeitem",
    "article",         "application document feed main none presentation region",
    "area",            "",
    "aside",           "feed none note presentation region search",
    "audio",           "application",
    "base",            "",
    "body",            "",
    "button",          "checkbox link menuitem menuitemcheckbox menuitemradio option radio switch tab",
    "caption",         "",
    "col",             "",
    "colgroup",        "",
    "datalist",        "",
    "dd",              "",
    "del",             "",
    "dialog",          "alertdialog",
    "dl",              "group list none presentation",
    "dt",              "listitem",
    "embed",           "application document img none presentation",
    "figcaption",      "group none presentation",
    "fieldlist",       "none presentation",
    "footer",          "group none presentation",
    "form",            "none presentation search",
    "h1",              "none presentation tab",
    "h2",              "none presentation tab",
    "h3",              "none presentation tab",
    "h4",              "none presentation tab",
    "h5",              "none presentation tab",
    "h6",              "none presentation tab",
    "head",            "",
    "header",          "banner group none presentation",
    "hr",              "none presentation",
    "html",            "",
    "iframe",          "application document img none presentation",
    "input",           "type:button link menuitem menuitemcheckbox menuitemradio option radio switch tab",
    "input",           "type:checkbox button menuitemcheckbox option switch",
    "input",           "type:color",
    "input",           "type:date",
    "input",           "type:datetime-local",
    "input",           "type:file",
    "input",           "type:hidden",
    "input",           "type:image link menuitem menuitemcheckbox menuitemradio radio switch tab",
    "input",           "type:month",
    "input",           "type:number",
    "input",           "type:password",
    "input",           "type:radio menuitemradio",
    "input",           "type:range",
    "input",           "type:reset",
    "input",           "type:submit",
    "input",           "type:time",
    "input",           "type:week",
    "ins",             "",
    "label",           "",
    "legend",          "",
    "link",            "href:",
    "main",            "",
    "map",             "",
    "math",            "",
    "meta",            "",
    "meter",           "",
    "noscript",        "",
    "object",          "application document img",
    "ol",              "directory group listbox menu menubar none presentation radiogroup tablist toolbar tree",
    "optgroup",        "",
    "param",           "",
    "picture",         "",
    "progress",        "",
    "script",          "",
    "slot",            "",
    "source",          "",
    "style",           "",
    "SVG",             "application document img",
    "template",        "",
    "textarea",        "",
    "title",           "",
    "track",           "",
    "ul",              "directory group listbox menu menubar none presentation radiogroup tablist toolbar tree",
    "video",           "application",
);

#
# Disallowed WAI-ARIA roles for HTML tags
#   https://www.w3.org/TR/html-aria/#docconformance
# Key is a HTML tag and the value is a space separated list of disallowed roles.
# If the allowed list contains a "string:value" the string is a required
# tag attribute and "value" is an optional value for the roles list
#
my (%disallowed_aria_roles) = (
    "a",               "href: link",
    "area",            "href: link",
    "article",         "article",
    "aside",           "complementary",
    "body",            "document",
    "button",          "button",
    "datalist",        "listbox",
    "dd",              "definition",
    "dialog",          "dialog",
    "dt",              "term",
    "fieldlist",       "group",
    "form",            "form",
    "h1",              "aria-level: heading",
    "h2",              "aria-level: heading",
    "h3",              "aria-level: heading",
    "h4",              "aria-level: heading",
    "h5",              "aria-level: heading",
    "h6",              "aria-level: heading",
    "hr",              "separator",
    "input",           "type:button button",
    "input",           "type:checkbox checkbox",
    "input",           "type:image button",
    "input",           "type:number spinbutton",
    "input",           "type:radio radio",
    "input",           "type:range slider",
    "input",           "type:reset button",
    "input",           "type:submit button",
    "link",            "href: link",
    "main",            "main",
    "math",            "math",
    "nav",             "navigation",
    "ol",              "list",
    "optgroup",        "group",
    "output",          "status",
    "progress",        "progressbar",
    "table",           "table",
    "textarea",        "textbox",
    "tbody",           "rowgroup",
    "thead",           "rowgroup",
    "tfoot",           "rowgroup",
    "td",              "cell",
    "th",              "columnheader rowheader",
    "ul",              "list",
);

#
# Valid values for WAI-ARIA attributes
#    https://www.w3.org/TR/wai-aria-1.1/#state_prop_def
# Attributes that do not have a fixed value set are not included
# in the table.
#
# Values ID, INTEGER, NUMBER and STRING represent classes of
# values, not literal values.
#
my(%valid_aria_attribute_values) = (
   "aria-activedescendant", "ID",
   "aria-atomic",           "false true",
   "aria-autocomplete",     "both inline list none",
   "aria-busy",             "false true",
   "aria-checked",          "false mixed true undefined",
   "aria-colcount",         "INTEGER",
   "aria-colindex",         "INTEGER",
   "aria-colspan",          "INTEGER",
   "aria-controls",         "ID LIST",
   "aria-current",          "date false location page step time true",
   "aria-describedby",      "ID LIST",
   "aria-details",          "ID",
   "aria-disabled",         "false true",
   "aria-dropeffect",       "copy execute link move none popup",
   "aria-errormessage",     "ID",
   "aria-expanded",         "false true undefined",
   "aria-flowto",           "ID LIST",
   "aria-grabbed",          "false true undefined",
   "aria-haspopup",         "dialog false grid listbox menu tree true",
   "aria-hidden",           "false true undefined",
   "aria-invalid",          "false grammar spelling true",
   "aria-keyshortcuts",     "STRING",
   "aria-label",            "STRING",
   "aria-labelledby",       "ID LIST",
   "aria-level",            "INTEGER",
   "aria-live",             "assertive off polite",
   "aria-modal",            "false true",
   "aria-multiline",        "false true",
   "aria-multiselectable",  "false true",
   "aria-orientation",      "horizontal undefined vertical",
   "aria-owns",             "ID LIST",
   "aria-placeholder",      "STRING",
   "aria-posinset",         "INTEGER",
   "aria-pressed",          "false mixed true",
   "aria-readonly",         "false true",
   "aria-relevant",         "additions additions_text all removals text",
   "aria-required",         "false true",
   "aria-roledescription",  "STRING",
   "aria-rowcount",         "INTEGER",
   "aria-rowindex",         "INTEGER",
   "aria-rowspan",          "INTEGER",
   "aria-selected",         "false true undefined",
   "aria-setsize",          "INTEGER",
   "aria-sort",             "ascending descending none other",
   "aria-valuemax",         "NUMBER",
   "aria-valuemin",         "NUMBER",
   "aria-valuenow",         "NUMBER",
   "aria-valuetext",        "STRING",
);

#
# ARIA roles that require accessible name to content matches
#    https://dequeuniversity.com/rules/axe/3.2/label-content-name-mismatch
#  https://www.w3.org/TR/wai-aria-1.1/#namefromcontent
#
my (%aria_accessible_name_content_match) = (
    "button",           1,
    "checkbox",         1,
    "gridcell",         1,
    "link",             1,
    "menuitem",         1,
    "menuitemcheckbox", 1,
    "menuitemradio",    1,
    "option",           1,
    "radio",            1,
    "searchbox",        1,
    "switch",           1,
    "tab",              1,
    "treeitem",         1,
);

#
# Allowed ARIA roles, states and properties
#    https://www.w3.org/TR/html-aria/#allowed-aria-roles-states-and-properties
# Global ARIA properties
#
# Table updated 2019-09-16
#
my (%global_aria_properties) = (
    "aria-atomic",          1,
    "aria-busy",            1,
    "aria-controls",        1,
    "aria-current",         1,
    "aria-describedby",     1,
    "aria-details",         1,
    "aria-disabled",        1,
    "aria-dropeffect",      1,
    "aria-errormessage",    1,
    "aria-flowto",          1,
    "aria-grabbed",         1,
    "aria-haspopup",        1,
    "aria-hidden",          1,
    "aria-invalid",         1,
    "aria-keyshortcuts",    1,
    "aria-label",           1,
    "aria-labelledby",      1,
    "aria-live",            1,
    "aria-owns",            1,
    "aria-relevant",        1,
    "aria-roledescription", 1,
);

#
# Allowed ARIA roles, states and properties
#    https://www.w3.org/TR/html-aria/#allowed-aria-roles-states-and-properties
# Specific ARIA properties for individual roles.  The table is indexed by
# the role and the value is a space separated list of required and
# allowed properties.
#
# Table updated 2019-09-16
#
my (%role_specific_supported_aria_properties) = (
    "alert",               " aria-expanded ",
    "alertdialog",         " aria-expanded aria-modal ",
    "application",         " aria-activedescendant aria-expanded ",
    "article",             " aria-expanded ",
    "banner",              " aria-expanded ",
    "button",              " aria-expanded aria-pressed aria-required ",
    "checkbox",            " aria-readonly aria-required ",
    "cell",                " aria-colspan aria-colindex aria-rowindex aria-rowspan ",
    "columnheader",        " aria-sort aria-readonly aria-required aria-selected aria-expanded aria-colspan aria-colindex aria-rowindex aria-rowspan ",
    "combobox",            " aria-autocomplete aria-required aria-activedescendant aria-orientation ",
    "complementary",       " aria-expanded ",
    "contentinfo",         " aria-expanded ",
    "definition",          " aria-expanded ",
    "dialog",              " aria-expanded aria-modal ",
    "directory",           " aria-expanded ",
    "document",            " aria-expanded ",
    "feed",                " aria-expanded ",
    "figure",              " aria-expanded ",
    "form",                " aria-expanded ",
    "grid",                " aria-level aria-multiselectable aria-readonly aria-activedescendant aria-expanded aria-colcount aria-rowcount ",
    "gridcell",            " aria-readonly aria-required aria-selected aria-expanded aria-colindex aria-colspan aria-rowindex aria-rowspan ",
    "group",               " aria-activedescendant aria-expanded ",
    "heading",             " aria-level aria-expanded",
    "img",                 " aria-expanded ",
    "link",                " aria-expanded ",
    "list",                " aria-expanded ",
    "listbox",             " aria-required aria-multiselectable aria-expanded aria-activedescendant aria-orientation ",
    "listitem",            " aria-level aria-posinset aria-setsize aria-expanded ",
    "log",                 " aria-expanded ",
    "main",                " aria-expanded ",
    "marquee",             " aria-expanded ",
    "math",                " aria-expanded ",
    "menu",                " aria-expanded aria-activedescendant aria-orientation ",
    "menubar",             " aria-expanded aria-activedescendant aria-orientation ",
    "menuitem",            " aria-posinset aria-setsize ",
    "menuitemcheckbox",    " aria-posinset aria-setsize ",
    "menuitemradio",       " aria-posinset aria-setsize ",
    "navigation",          " aria-expanded ",
    "none",                "",
    "note",                " aria-expanded ",
    "option",              " aria-checked aria-posinset aria-selected aria-setsize ",
    "presentation",        "",
    "progressbar",         " aria-valuemax aria-valuemin aria-valuenow aria-valuetext ",
    "radio",               " aria-posinset aria-required aria-selected aria-setsize ",
    "radiogroup",          " aria-required aria-activedescendant aria-expanded aria-orientation ",
    "region",              " aria-expanded ",
    "row",                 " aria-colindex aria-rowindex aria-level aria-selected aria-activedescendant aria-expanded ",
    "rowgroup",            "",
    "rowheader",           " aria-readonly aria-required aria-selected aria-expanded aria-colspan aria-colindex aria-rowindex aria-rowspan ",
    "scrollbar",           " aria-expanded aria-orientation aria-valuemax aria-valuemin aria-valuetext ",
    "search",              " aria-expanded aria-required ",
    "searchbox",           " aria-activedescendant aria-autocomplete aria-multiline aria-placeholder aria-readonly aria-required ",
    "separator",           " aria-valuetext aria-orientation aria-valuemax aria-valuemin aria-valuenow ",
    "slider",              " aria-valuetext aria-orientation aria-required ",
    "spinbutton",          " aria-valuetext aria-required aria-readonly aria-required ",
    "status",              " aria-expanded ",
    "switch",              " aria-readonly ",
    "tab",                 " aria-selected aria-posinset aria-setsize aria-expanded ",
    "table",               " aria-colcount aria-rowcount ",
    "tablist",             " aria-level aria-activedescendant aria-orientation aria-multiselectable ",
    "tabpanel",            " aria-expanded ",
    "term",                " aria-expanded ",
    "textbox",             " aria-activedescendant aria-autocomplete aria-multiline aria-placeholder aria-readonly aria-required ",
    "timer",               " aria-expanded ",
    "toolbar",             " aria-activedescendant aria-expanded aria-orientation ",
    "tooltip",             " aria-expanded ",
    "tree",                " aria-multiselectable aria-required aria-activedescendant aria-expanded aria-orientation ",
    "treegrid",            " aria-level aria-multiselectable aria-readonly aria-activedescendant aria-expanded aria-required aria-orientation aria-colcount aria-rowcount ",
    "treeitem",            " aria-level aria-posinset aria-setsize aria-expanded aria-checked aria-selected ",
);

#
# Required ARIA attributes for specific ARIA roles
#    https://www.w3.org/TR/html-aria/#allowed-aria-roles-states-and-properties
# Specific ARIA attributes for individual roles.  The table is indexed by
# the role and the value is a space separated list of required properties.
#
# Table updated 2019-09-16
#
my (%role_specific_required_aria_properties) = (
    "checkbox",            " aria-checked ",
    "combobox",            " aria-controls aria-expanded ",
    "menuitemcheckbox",    " aria-checked ",
    "menuitemradio",       " aria-checked ",
    "radio",               " aria-checked ",
    "scrollbar",           " aria-controls aria-valuenow ",
                             # Attributes aria-orientation aria-valuemax aria-valuemin have default values
#    "separator",           " aria-valuemax aria-valuemin aria-valuenow ",
    "slider",              " aria-valuemax aria-valuemin aria-valuenow ",
    "spinbutton",          " aria-valuemax aria-valuemin aria-valuenow ",
    "switch",              " aria-checked ",
);

#
# Mapping table for HTML attributes that can be used in place of ARIA
# attributes. The table is indexed by the HTML attribute and the
# value is the aria equivalent attribute.
#
# https://www.w3.org/TR/html-aria/#allowed-aria-roles-states-and-properties
#
# Table updated 2019-09-16
#
my (%html_aria_attribute_equivalence) = (
    "checked",             "aria-checked",
);

#
# Tags for which we ignore any id attribute to suppress
# any WCAG_2.0-F77 errors.
#
my (%tags_to_ignore_id_attribute) = (
    "script",  1,
);

#
# Set of elements that are not valid ancestors for a hierarchically
# correct main element.
#  Reference: http://w3c.github.io/html/grouping-content.html#the-main-element
#             https://stackoverflow.com/questions/20815584/should-the-main-tag-be-inside-section-tag
#
my (%invalid_main_ancestors) = (
    "article",     1,
    "aside",       1,
    "footer",      1,
    "header",      1,
    "nav",         1,
    "section",     1,
);

#
# Right to left languages using 3 ISO 639-2/T language codes
#
my (%right_to_left_languages) = (
    "ara", 1,
    "arc", 1,
    "aze", 1,
    "div", 1,
    "heb", 1,
    "kur", 1,
    "fas", 1,
    "urd", 1,
);

#
# Valid field names for autocomplete attribute contact information.
#
# https://html.spec.whatwg.org/#autofill-detail-tokens
#
# Table updated 2020-07-22
#
my (%autocomplete_valid_contact_info_field_names) = (
    "shipping", 1,
    "billing", 1,
);

#
# Valid field names for autocomplete attribute.  The value is
# the valid control group for the field.
#
# https://html.spec.whatwg.org/#autofill-detail-tokens
#
# Table updated 2020-07-22
#
my (%autocomplete_valid_field_names) = (
    "name", "text",
    "honorific-prefix", "text",
    "given-name", "text",
    "additional-name", "text",
    "family-name", "text",
    "honorific-suffix", "text",
    "nickname", "text",
    "username", "text",
    "new-password", "password",
    "current-password", "password",
    "one-time-code", "password",
    "organization-title", "text",
    "organization", "multiline",
    "street-address", "text",
    "address-line1", "text",
    "address-line2", "text",
    "address-line3", "text",
    "address-level4", "text",
    "address-level3", "text",
    "address-level2", "text",
    "address-level1", "text",
    "country", "text",
    "country-name", "text",
    "postal-code", "text",
    "cc-name", "text",
    "cc-given-name", "text",
    "cc-additional-name", "text",
    "cc-family-name", "text",
    "cc-number", "text",
    "cc-exp", "month",
    "cc-exp-month", "numeric",
    "cc-exp-year", "numeric",
    "cc-csc", "text",
    "cc-type", "text",
    "transaction-currency", "text",
    "transaction-amount", "numeric",
    "language", "text",
    "bday", "date",
    "bday-day", "numeric",
    "bday-month", "numeric",
    "bday-year", "numeric",
    "sex", "text",
    "url", "url",
    "photo", "url",
);

#
# Valid field names for autocomplete attribute prefix for telephone and email.
#
# https://html.spec.whatwg.org/#autofill-detail-tokens
#
# Table updated 2020-07-22
#
my (%autocomplete_valid_telephone_prefix_field_names) = (
    "home", 1,
    "work", 1,
    "mobile", 1,
    "fax", 1,
    "pager", 1,
);

#
# Valid field names for autocomplete attribute for telephone and email.
# The value is the valid control group for the field.
#
# https://html.spec.whatwg.org/#autofill-detail-tokens
#
# Table updated 2020-07-22
#
my (%autocomplete_valid_telephone_field_names) = (
    "tel", "tel",
    "tel-country-code", "text",
    "tel-national", "text",
    "tel-area-code", "text",
    "tel-local", "text",
    "tel-local-prefix", "text",
    "tel-local-suffix", "text",
    "tel-extension", "text",
    "email", "e-mail",
    "impp", "url",
);

#
# Autocomplete control group to input type details.  The key
# is the control group, the value is a space separated list of tags that
# are valid for the type. The tag may include an optional attribute and value
# (separated by colons).
#
# https://html.spec.whatwg.org/#autofill-detail-tokens
#
my (%autocomplete_control_group_details) = (
    "text", "input:type:hidden input:type:text input:type:search textarea select",
    "multiline", "input:type:hidden textarea select",
    "password", "input:type:hidden input:type:text input:type:search input:type:password textarea select",
    "url", "input:type:hidden input:type:text input:type:search input:type:url textarea select",
    "e-mail", "input:type:hidden input:type:text input:type:search input:type:e-mail textarea select",
    "tel", "input:type:hidden input:type:text input:type:search input:type:telephone textarea select",
    "numeric", "input:type:hidden input:type:text input:type:search input:type:number textarea select",
    "month", "input:type:hidden input:type:text input:type:search input:type:month textarea select",
    "date", "input:type:hidden input:type:text input:type:search input:type:date textarea select",
);

#
# String table for error strings.
#
my %string_table_en = (
    "Accessible name does not begin with visible text", "Accessible name does not begin with visible text",
    "Alt attribute not allowed on this tag", "'alt' attribute not allowed on this tag.",
    "Anchor and image alt text the same", "Anchor and image 'alt' text the same",
    "Anchor text is a URL",          "Anchor text is a URL",
    "Anchor text is single character punctuation", "Anchor text is single character punctuation",
    "Anchor text same as href",      "Anchor text same as 'href'",
    "Anchor text same as title",     "Anchor text same as 'title'",
    "Anchor title same as href",     "Anchor 'title' same as 'href'",
    "and",                           "and",
    "aria-hidden cannot be reset",   "aria-hidden cannot be reset",
    "aria-hidden must not be present on the document body", "aria-hidden=\"true\" must not be present on the document <body>",
    "ARIA attribute not allowed",    "ARIA attribute not allowed",
    "ARIA role not allowed on tag",  "ARIA role not allowed on tag",
    "at line:column",                " at (line:column) ",
    "attribute",                     "attribute",
    "Blinking text in",              "Blinking text in ",
    "Broken link in cite for",       "Broken link in 'cite' for ",
    "Broken link in longdesc for",   "Broken link in 'longdesc' for ",
    "Broken link in src for",        "Broken link in 'src' for ",
    "cannot be used before token",   "cannot be used before token",
    "caption found in layout table", "<caption> found in layout table",
    "click here link found",         "'click here' link found",
    "color is",                      " color is ",
    "Combining adjacent image and text links for the same resource",   "Combining adjacent image and text links for the same resource",
    "Contact information type token must precede phone type token", "Contact information type token must precede phone type token",
    "Container landmark is",         "Container landmark is",
    "Content does not contain letters for", "Content does not contain letters for ",
    "Content hidden from assistive technology", "Content hidden from assistive technology",
    "Content referenced by",         "Content referenced by",
    "Content same as title for",     "Content same as 'title' for ",
    "Content type does not match",   "Content type does not match",
    "Content values do not match for",  "Content values do not match for ",
    "defined at",                    "defined at (line:column)",
    "Deprecated attribute found",    "Deprecated attribute found ",
    "Deprecated tag found",          "Deprecated tag found ",
    "Did not match any control group conditions", "Did not match any control group conditions",
    "dl must contain only dt, dd, div, script or template tags", "<dl> must contain only <dt>, <dd>, <div>, <script> or <template> tags",
    "DOCTYPE missing",               "DOCTYPE missing",
    "does not match content language",  "does not match content language",
    "does not match previous value", "does not match previous value",
    "Duplicate accesskey",           "Duplicate 'accesskey' ",
    "Duplicate anchor name",         "Duplicate anchor name ",
    "Duplicate attribute",           "Duplicate attribute ",
    "Duplicatge attribute in tag",   "Duplicatge attribute in tag",
    "Duplicate aria-labelledby reference on interface controls", "Duplicate aria-labelledby reference on interface controls",
    "Duplicate label for",           "Duplicate <label> 'for=\"",
    "Duplicate frame title",         "Duplicate <frame> title",
    "Duplicate id in headers",       "Duplicate 'id' in 'headers'",
    "Duplicate id",                  "Duplicate 'id' ",
    "Duplicate table summary and caption", "Duplicate table 'summary' and <caption>",
    "Duplicate",                     "Duplicate",
    "E-mail domain",                 "E-mail domain ",
    "Empty text alternative value",  "Empty text alternative value",
    "End tag",                       "End tag",
    "expected",                      "expected",
    "expecting a non-blank text value", "expecting a non-blank text value",
    "Expecting end tag",             "Expecting end tag",
    "expecting ID value",            "expecting ID value",
    "expecting integer value",       "expecting integer value",
    "expecting numerical value",     "expecting numerical value",
    "expecting one of",              "expecting one of ",
    "Fails validation",              "Fails validation, see validation results for details.",
    "Focusable content inside aria-hidden tag", "Focusable content inside aria-hidden tag",
    "followed by",                   " followed by ",
    "for parent tag",                "for parent tag",
    "for tag",                       " for tag ",
    "for",                           "for ",
    "forbidden",                     "forbidden",
    "found at",                      "found at (line:column)",
    "found in header",               "found in header",
    "found inside of link",          "found inside of link",
    "Found label before input type", "Found <label> before <input> type ",
    "found outside of a form",       "found outside of a <form>",
    "Found tag",                     "Found tag ",
    "Found",                         "Found",
    "found",                         "found",
    "Frame contains more than 1 landmark with", "Frame contains more than 1 landmark with",
    "GIF animation exceeds 5 seconds",  "GIF animation exceeds 5 seconds",
    "GIF flashes more than 3 times in 1 second", "GIF flashes more than 3 times in 1 second",
    "Header defined at",             "Header defined at (line:column)",
    "Heading level, aria-level mismatch", "Heading level, aria-level mismatch",
    "Heading level increased by more than one, expected", "Heading level increased by more than one, expected",
    "Heading text greater than 500 characters",  "Heading text greater than 500 characters",
    "HTML language attribute",       "HTML language attribute",
    "id defined at",                 "'id' defined at (line:column)",
    "Image alt same as src",         "Image 'alt' same as 'src'",
    "in tag used to convey information or relationships", "in tag used to convey information or relationships",
    "in tag",                        " in tag ",
    "in",                            " in ",
    "in decorative image",           " in decorative image.",
    "Incomplete autocomplete term",  "Incomplete autocomplete term",
    "Interactive tag has an interactive parent tag", "Interactive tag has an interactive parent tag",
    "Insufficient color contrast for tag",                 "Insufficient color contrast for tag ",
    "Invalid alt text value",        "Invalid 'alt' text value",
    "Invalid aria-label text value", "Invalid 'aria-label' text value",
    "Invalid ARIA role value",       "Invalid ARIA role value",
    "Invalid autocomplete term token", "Invalid autocomplete term token",
    "Invalid attribute combination found", "Invalid attribute combination found",
    "Invalid attribute value",       "Invalid attribute value",
    "Invalid content for",           "Invalid content for ",
    "Invalid CSS file referenced",   "Invalid CSS file referenced",
    "Invalid direction for left to right language", "Invalid direction for left to right language",
    "Invalid direction for right to left language", "Invalid direction for right to left language",
    "Invalid language attribute value", "Invalid language attribute value",
    "Invalid list separator, expecting space character", "Invalid list separator, expecting space character",
    "Invalid owned element role",    "Invalid owned element role",
    "Invalid rel value",             "Invalid 'rel' value",
    "Invalid role value",            "Invalid 'role' value",
    "Invalid tag nesting",           "Invalid tag nesting",
    "Invalid text alternative value", "Invalid text alternative value",
    "Invalid title text value",      "Invalid 'title' text value",
    "Invalid title",                 "Invalid title",
    "Invalid URL in longdesc for",   "Invalid URL in 'longdesc' for ",
    "Invalid URL in src for",        "Invalid URL in 'src' for ",
    "Invalid value for WAI-ARIA attribute", "Invalid value for WAI-ARIA attribute",
    "Invalid WAI-ARIA attribute",    "Invalid WAI-ARIA attribute",
    "is",                            "is",
    "is hidden",                     "is hidden",
    "is not equal to last level",    " is not equal to last level ",
    "is not visible",                "is not visible",
    "is inside aria-hidden tag",     "is inside aria-hidden tag",
    "is only allowed on tags with a role", "is only allowed on tags with a role",
    "Label found for hidden input",  "<label> found for <input type=\"hidden\">",
    "label not allowed before",      "<label> not allowed before ",
    "label not allowed for",         "<label> not allowed for ",
    "Label not explicitly associated to", "Label not explicitly associated to ",
    "Label referenced by",           "<label> referenced by",
    "Landmark",                      "Landmark",
    "Link contains onclick",         "Link contains onclick",
    "Link href contains JavaScript", "Link href contains JavaScript",
    "Link href ends with #",         "Link href ends with #",
    "Link inside of label",          "Link inside of <label>",
    "link",                          "link",
    "Main landmark must not be nested in", "Landmark 'main' must not be nested in",
    "Main landmark nested in",       "'main' landmark nested in",
    "Meta refresh with timeout",     "Meta 'refresh' with timeout ",
    "Meta viewport maximum-scale less than", "Meta viewport maximum-scale less than",
    "Meta viewport with user-scalable disabled", "Meta viewport with user-scalable disabled",
    "Metadata missing",              "Metadata missing",
    "Mismatching lang and xml:lang attributes", "Mismatching 'lang' and 'xml:lang' attributes",
    "Missing <title> tag",           "Missing <title> tag",
    "Missing alt attribute for",     "Missing 'alt' attribute for ",
    "Missing alt content for",       "Missing 'alt' content for ",
    "Missing alt or text alternative for",     "Missing 'alt' or text alternative for ",
    "Missing alt or title in",       "Missing 'alt' or 'title' in ",
    "Missing aria-label content for", "Missing 'aria-label' content for",
    "Missing aria-labelledby content for", "Missing 'aria-labelledby' content for",
    "Missing cite content for",      "Missing 'cite' content for ",
    "Missing close tag for",         "Missing close tag for",
    "Missing content before list",   "Missing content before list",
    "Missing content in",            "Missing content in ",
    "Missing dd tag after last dt tag in definition list", "Missing <dd> tag after last <dt> tag in definition list",
    "Missing dd tag between previous dt tag and this dt tag", "Missing <dd> tag between previous <dt> tag and this <dt> tag",
    "Missing dir attribute for right to left language", "Missing 'dir' attribute for right to left language",
    "Missing dt tag before dd tag",  "Missing <dt> tag before <dd> tag",
    "Missing event handler from pair", "Missing event handler from pair ",
    "Missing fieldset",              "Missing <fieldset> tag",
    "Missing href, id, name or xlink in <a>",  "Missing href, id, name or xlink in <a>",
    "Missing html language attribute",  "Missing <html> attribute",
    "Missing id content for",        "Missing 'id' content for ",
    "Missing label before",          "Missing <label> before ",
    "Missing label id or title for", "Missing <label> 'id' or 'title' for ",
    "Missing lang attribute",        "Missing 'lang' attribute ",
    "Missing language attribute value", "Missing language attribute value",
    "Missing longdesc content for",  "Missing 'longdesc' content for ",
    "Missing rel attribute in",      "Missing 'rel' attribute in ",
    "Missing rel value in",          "Missing 'rel' value in ",
    "Missing required ARIA attribute", "Missing required ARIA attribute",
    "Missing required ARIA attribute value", "Missing required ARIA attribute value",
    "Missing required owned elements for role", "Missing required owned elements for role",
    "Missing required context role for", "Missing required context role for",
    "Missing required context role for implicit role", "Missing required context role for implicit role",
    "Missing required context role for WAI-ARIA attribute", "Missing required context role for WAI-ARIA attribute",
    "Missing src attribute",         "Missing 'src' attribute ",
    "Missing src value",             "Missing 'src' value ",
    "Missing table summary",         "Missing table 'summary'",
    "Missing template comment",      "content",
    "Missing text alternative for",  "Missing text alternative for",
    "Missing text in",               "Missing text in ",
    "Missing text in table header",  "Missing text in table header ",
    "Missing title attribute for",   "Missing 'title' attribute for ",
    "Missing title content for",     "Missing 'title' content for ",
    "Missing value attribute in",    "Missing 'value' attribute in ",
    "Missing value in",              "Missing value in ",
    "Missing xml:lang attribute",    "Missing 'xml:lang' attribute ",
    "Missing",                       "Missing",
    "More than 1 landmark in frame", "More than 1 'landmark' in frame",
    "Mouse only event handlers found",  "Mouse only event handlers found",
    "Multiple instances of",         "Multiple instances of",
    "Multiple links with same anchor text", "Multiple links with same anchor text ",
    "Multiple links with same title text", "Multiple links with same 'title' text ",
    "Multiple main content areas found, previous instance found", "Multiple main content areas found, previous instance found",
    "must be contained by",          "must be contained by",
    "must not be contained in another landmark", "must not be contained in another landmark",
    "New heading level",             "New heading level ",
    "No button found in form",       "No button found in form",
    "No captions found for",         "No captions found for",
    "No closed caption content found", "No closed caption content found",
    "No content found in track",     "No content found in track",
    "No controls on automatically played audio or video", "No controls on automatically played audio or video",
    "No data cells found in table",  "No data cells found in table",
    "No descriptions found for",     "No descriptions found for",
    "No dt found in list",           "No <dt> found in list ",
    "No form found with",            "No form found with",
    "No headers found inside thead", "No headers found inside <thead>",
    "No headings found",             "No headings found in content area",
    "No label for",                  "No <label> for ",
    "No label matching id attribute","No <label> matching 'id' attribute ",
    "No legend found in fieldset",   "No <legend> found in <fieldset>",
    "No li found in list",           "No <li> found in list ",
    "No links found",                "No links found",
    "No level one heading found",    "No level one heading found",
    "No matching noembed for embed", "No matching <noembed> for <embed>",
    "No table header reference",     "No table header reference",
    "No tag with id attribute",      "No tag with 'id' attribute ",
    "No td, th found inside tfoot",  "No <td>, <th> found inside <tfoot>",
    "Non-decorative image loaded via CSS with", "Non-decorative image loaded via CSS with",
    "Non null title text",           "Non null 'title' text ",
    "Not all of visible text is included in accessible name", "Not all of visible text is included in accessible name",
    "not defined within table",      "not defined within <table>",
    "not marked up as a <label>",    "not marked up as a <label>",
    "Null alt on an image",          "Null alt on an image where the image is the only content in a link",
    "ol, ul must contain only li, script or template tags", "<ol>, <ul> must contain only <li>, <script> or <template> tags",
    "onclick or onkeypress found in tag", "'onclick' or 'onkeypress' found in tag ",
    "Only label for",                "Only label for",
    "Only 1 contact information type token allowed", "Only 1 contact information type token allowed",
    "or",                            " or ",
    "Page contains more than 1 landmark with", "Page contains more than 1 'landmark' with",
    "Page redirect not allowed",     "Page redirect not allowed",
    "Page refresh not allowed",      "Page refresh not allowed",
    "Previous instance found at",    "Previous instance found at (line:column) ",
    "Previous label not explicitly associated to", "Previous label not explicitly associated to ",
    "previously found",              "previously found",
    "Required testcase not executed","Required testcase not executed",
    "Section grouping must be first token in term", "Section grouping must be first token in term",
    "Self reference in headers",     "Self reference in 'headers'",
    "Span language attribute",       "Span language attribute",
    "started at line:column",        "started at (line:column) ",
    "summary found in layout table", "<summary> found in layout table",
    "Tabindex value greater than zero", "Tabindex value greater than zero",
    "Table found in table header",   "Table found in table header",
    "Table found in table footer",   "Table found in table footer",
    "Table found in th",             "Table found in <th>",
    "Table header found in layout table", "Table header found in layout table",
    "Table headers",                 "Table 'headers'",
    "Tag",                           "Tag",
    "Tag contains decorative and non-decorative attributes", "Tag contains decorative and non-decorative attributes",
    "Tag has accessible name but not in the accessible tree", "Tag has accessible name but not in the accessible tree",
    "Tag has empty accessible name", "Tag has empty accessible name",
    "Tag not allowed here",          "Tag not allowed here ",
    "Text alternative",              "Text alternative",
    "Text styled to appear like a heading", "Text styled to appear like a heading",
    "Text",                          "Text",
    "Title same as id for",          "'title' same as 'id' for ",
    "Title text greater than 500 characters",            "Title text greater than 500 characters",
    "Title values do not match for", "'title' values do not match for",
    "Unable to determine content language, possible languages are", "Unable to determine content language, possible languages are",
    "Unused label, for attribute",      "Unused <label>, 'for' attribute ",
    "used for decoration",              "used for decoration",
    "Using script to remove focus when focus is received", "Using script to remove focus when focus is received",
    "Using white space characters to control spacing within a word in tag", "Using white space characters to control spacing within a word in tag",
    "WAI-ARIA attribute",            "WAI-ARIA attribute",
);


#
# String table for error strings (French).
#
my %string_table_fr = (
    "Accessible name does not begin with visible text", "Le nom accessible ne commence pas par du texte visible",
    "Alt attribute not allowed on this tag", "L'attribut 'alt' pas autoris�s sur cette balise.",
    "Anchor and image alt text the same", "Textes de l'ancrage et de l'attribut 'alt' de l'image identiques",
    "Anchor text is single character punctuation", "Texte d'ancrage est une ponctuation d'un seul caract�re",
    "Anchor text is a URL",            "Texte d'ancrage est une URL",
    "Anchor text same as href",        "Texte d'ancrage identique � 'href'",
    "Anchor text same as title",       "Texte d'ancrage identique � 'title'",
    "Anchor title same as href",       "'title' d'ancrage identique � 'href'",
    "and",                             "et",
    "aria-hidden cannot be reset",     "aria-hidden ne peut pas �tre r�initialis�",
    "aria-hidden must not be present on the document body", "aria-hidden=\"true\" ne doit pas �tre pr�sent sur le document <body>",
    "ARIA attribute not allowed",      "Attribut ARIA non autoris�",
    "ARIA role not allowed on tag",    "Le r�le ARIA n'est pas autoris� sur cette balise",
    "at line:column",                  " � (la ligne:colonne) ",
    "attribute",                       "attribut",
    "Blinking text in",                "Texte clignotant dans ",
    "Broken link in cite for",         "Lien bris� dans l'�l�ment 'cite' pour ",
    "Broken link in longdesc for",     "Lien bris� dans l'�l�ment 'longdesc' pour ",
    "Broken link in src for",          "Lien bris� dans l'�l�ment 'src' pour ",
    "cannot be used before token",     "ne peut pas �tre utilis� avant le jeton",
    "caption found in layout table",   "<caption> trouv� dans la table de mise en page",
    "click here link found",           "Lien 'cliquez ici' retrouv�",
    "color is",                        " la couleur est ",
    "Combining adjacent image and text links for the same resource",   "Combiner en un m�me lien une image et un intitul� de lien pour la m�me ressource",
    "Contact information type token must precede phone type token", "Le jeton de type d'informations de contact doit pr�c�der le jeton de type de t�l�phone",
    "Container landmark is",           "Landmark du conteneur est",
    "Content does not contain letters for", "Contenu ne contient pas des lettres pour ",
    "Content hidden from assistive technology", "Contenu cach� de la technologie d'assistance",
    "Content referenced by",           "Contenu r�f�renc� par",
    "Content same as title for",       "Contenu et 'title' identiques pour ",
    "Content type does not match",     "Content type does not match",
    "Content values do not match for", "Valeurs contenu ne correspondent pas pour ",
    "defined at",                      "d�fini � (la ligne:colonne)",
    "Deprecated attribute found",      "Attribut d�pr�ci�e retrouv�e ",
    "Deprecated tag found",            "Balise d�pr�ci�e retrouv�e ",
    "Did not match any control group conditions", "Ne correspond � aucune condition du groupe t�moin",
    "dl must contain only dt, dd, div, script or template tags", "<dl> ne doit contenir que des balises <dt>, <dd>, <div>, <script> ou <template>",
    "DOCTYPE missing",                 "DOCTYPE manquant",
    "does not match content language", "ne correspond pas � la langue de contenu",
    "does not match previous value",   "ne correspond pas � la valeur pr�c�dente",
    "Duplicate accesskey",             "Doublon 'accesskey' ",
    "Duplicate anchor name",           "Doublon du nom d'ancrage ",
    "Duplicate attribute",             "Doublon attribut ",
    "Duplicatge attribute in tag",     "Attribut en double dans la balise",
    "Duplicate aria-labelledby reference on interface controls", "R�f�rence aria-labelledby en double sur les contr�les d'interface",
    "Duplicate label for",             "Doublon <label> 'for=\"",
    "Duplicate frame title",           "Titre du <frame> en double",
    "Duplicate id in headers",         "Doublon 'id' dans 'headers'",
    "Duplicate id",                    "Doublon 'id' ",
    "Duplicate table summary and caption", "�l�ments 'summary' et <caption> du tableau en double",
    "Duplicate",                       "Doublon",
    "E-mail domain",                   "Domaine du courriel ",
    "Empty text alternative value",    "Valeur alternative du texte vide",
    "End tag",                         "Balise de fin",
    "expected",                        "attendu",
    "expecting a non-blank text value", "attendant une valeur de texte non vide",
    "Expecting end tag",               "Attendre la balise de fin",
    "expecting ID value",              "attente d'une valeur d'ID",
    "expecting integer value",         "attendant une valeur enti�re",
    "expecting numerical value",       "attente d'une valeur num�rique",
    "expecting one of",                "expectant une de ",
    "Fails validation",                "�choue la validation, voir les r�sultats de validation pour plus de d�tails.",
    "Focusable content inside aria-hidden tag", "Contenu pouvant �tre mis au point dans une balise aria-hidden",
    "followed by",                     " suivie par ",
    "for parent tag",                  "pour la balise parent",
    "for tag",                         " pour balise ",
    "for",                             "pour ",
    "forbidden",                       "interdite",
    "found at",                        "trouv�e � (la ligne:colonne)",
    "found in header",                 "trouv� dans les en-t�tes",
    "found inside of link",            "trouv� dans une lien",
    "Found label before input type",   "<label> trouv� devant le type <input> ",
    "found outside of a form",         "trouv� en dehors d'une <form>",
    "Found tag",                       "Balise trouv� ",
    "found",                           "trouv�",
    "Found",                           "Trouv�",
    "Frame contains more than 1 landmark with", "Cette 'frame' contient plus d'un 'landmark' avec",
    "GIF animation exceeds 5 seconds", "Clignotement de l'image GIF sup�rieur � 5 secondes",
    "GIF flashes more than 3 times in 1 second", "Clignotement de l'image GIF sup�rieur � 3 par seconde",
    "Header defined at",               "En-t�te d�fini � (la ligne:colonne)",
    "Heading level, aria-level mismatch", "Niveau de titre, ne correspond pas 'aria-level'",
    "Heading level increased by more than one, expected", "Niveau de cap augment� de plus d'un, pr�vu",
    "Heading text greater than 500 characters",  "Texte du t�tes sup�rieure 500 caract�res",
    "HTML language attribute",         "L'attribut du langage HTML",
    "id defined at",                   "'id' d�fini � (la ligne:colonne)",
    "Image alt same as src",           "'alt' et 'src'identiques pour l'image",
    "in tag used to convey information or relationships", "dans la balise utilis�e pour transmettre des informations ou des relations",
    "in tag",                          " dans balise ",
    "in",                              " dans ",
    "in decorative image",             " dans l'image d�coratives.",
    "Incomplete autocomplete term",    "Terme de saisie autocomplete incomplet",
    "Interactive tag has an interactive parent tag", "La balise interactive a une balise parent interactive",
    "Insufficient color contrast for tag", "Contrast de couleurs insuffisant pour balise ",
    "Invalid alt text value",          "Valeur de texte 'alt' est invalide",
    "Invalid aria-label text value",   "Valeur de texte 'aria-label' est invalide",
    "Invalid ARIA role value",         "Valeur de r�le ARIA non valide",
    "Invalid attribute combination found", "Combinaison d'attribut non valide trouv�",
    "Invalid attribute value",         "Valeur d'attribut non valide",
    "Invalid autocomplete term token", "Jeton de terme de saisie autocomplete non valide",
    "Invalid content for",             "Contenu invalide pour ",
    "Invalid CSS file referenced",     "Fichier CSS non valide retrouv�",
    "Invalid direction for left to right language", "Direction non valide pour la langue de gauche � droite",
    "Invalid direction for right to left language", "Direction non valide pour la langue de droite � gauche",
    "Invalid language attribute value", "Valeur d'attribut de langue invalide",
    "Invalid list separator, expecting space character", "S�parateur de liste non valide, attend un caract�re d'espace",
    "Invalid owned element role",      "R�le d'�l�ment d�tenu non valide",
    "Invalid rel value",               "Valeur de texte 'rel' est invalide",
    "Invalid role value",              "Valeur de texte 'role' est invalide",
    "Invalid tag nesting",             "Imbrication de balise non valide",
    "Invalid text alternative value",  "Valeur alternative de texte non valide",
    "Invalid title text value",        "Valeur de texte 'title' est invalide",
    "Invalid title",                   "Titre invalide",
    "Invalid URL in longdesc for",     "URL non valide dans 'longdesc' pour ",
    "Invalid URL in src for",          "URL non valide dans 'src' pour ",
    "Invalid value for WAI-ARIA attribute", "Valeur non valide pour l'attribut WAI-ARIA",
    "Invalid WAI-ARIA attribute",      "Attribut WAI-ARIA invalide",
    "is",                              "est",
    "is hidden",                       "est cach�",
    "is inside aria-hidden tag",       "est dans une balise aria-hidden",
    "is not equal to last level",      " n'est pas �gal � au dernier niveau ",
    "is not visible",                  "est pas visible",
    "is only allowed on tags with a role",  "n'est autoris� que sur les balises avec un role" ,
    "Label found for hidden input",    "<label> trouv� pour <input type=\"hidden\">",
    "label not allowed before",        "<label> pas permis avant ",
    "label not allowed for",           "<label> pas permis pour ",
    "Label not explicitly associated to", "�tiquette pas explicitement associ�e � la ",
    "Label referenced by",             "<label> r�f�renc� par",
    "Landmark",                        "Landmark",
    "Link contains onclick",           "Le lien contient onclick",
    "Link href contains JavaScript",   "Le lien href contient du JavaScript",
    "Link href ends with #",           "Le lien href se termine par #",
    "Link inside of label",            "lien dans une <label>",
    "link",                            "lien",
    "Main landmark must not be nested in", "Le point de rep�re 'main' ne doit pas �tre imbriqu�",
    "Main landmark nested in",         "Point de rep�re 'main' nich� dans",
    "Meta refresh with timeout",       "M�ta 'refresh' avec d�lai d'inactivit� ",
    "Meta viewport maximum-scale less than", "Meta viewport maximale �chelle inf�rieure �",
    "Meta viewport with user-scalable disabled", "Meta viewport utilisateur �volutive d�sactiv�e",
    "Metadata missing",              "M�tadonn�es manquantes",
    "Mismatching lang and xml:lang attributes", "Erreur de correspondance des attributs 'lang' et 'xml:lang'",
    "Missing <title> tag",              "Balise <title> manquant",
    "Missing alt attribute for",     "Attribut 'alt' manquant pour ",
    "Missing alt content for",       "Le contenu de 'alt' est manquant pour ",
    "Missing alt or text alternative for", "Manquant 'alt' ou texte alternatif pour ",
    "Missing alt or title in",         "Attribut 'alt' ou 'title' manquant dans  ",
    "Missing aria-label content for",  "Le contenu de 'aria-label' est manquant pour ",
    "Missing aria-labelledby content for", "Le contenu de 'aria-labelledby' est manquant pour ",
    "Missing cite content for",        "Contenu de l'�l�ment 'cite' manquant pour ",
    "Missing close tag for",           "Balise de fin manquantes pour",
    "Missing content before list",     "Contenu manquant avant la liste",
    "Missing content in",              "Contenu manquant dans ",
    "Missing dd tag after last dt tag in definition list", "Balise <dd> manquante apr�s la derni�re balise dt dans la liste de d�finitions",
    "Missing dd tag between previous dt tag and this dt tag", "Balise <dd> manquante entre la balise <dt> pr�c�dente et cette balise <dt>",
    "Missing dir attribute for right to left language", "Attribut 'dir' manquant pour la langue de droite � gauche",
    "Missing dt tag before dd tag",    "Balise <dt> manquante avant balise <dd>",
    "Missing event handler from pair", "Gestionnaire d'�v�nements manquant dans la paire ",
    "Missing fieldset",                 "�l�ment <fieldset> manquant",
    "Missing href, id, name or xlink in <a>", "Attribut href, id, name ou xlink manquant dans <a>",
    "Missing html language attribute","Attribut manquant pour <html>",
    "Missing id content for",        "Contenu de l'�l�ment 'id' manquant pour ",
    "Missing label before",          "�l�ment <label> manquant avant ",
    "Missing label id or title for", "�l�ments 'id' ou 'title' de l'�l�ment <label> manquants pour ",
    "Missing lang attribute",        "Attribut 'lang' manquant ",
    "Missing language attribute value", "Valeur d'attribut de langue manquante",
    "Missing longdesc content for",  "Contenu de l'�l�ment 'longdesc' manquant pour ",
    "Missing rel attribute in",      "Attribut 'rel' manquant dans ",
    "Missing rel value in",          "Valeur manquante dans 'rel' ",
    "Missing required ARIA attribute", "Attribut ARIA requis manquant",
    "Missing required ARIA attribute value", "Valeur d'attribut ARIA obligatoire manquante",
    "Missing required owned elements for role", "�l�ments poss�d�s manquants requis pour le 'role'",
    "Missing required context role for", "Le 'role' de contexte requis manquant pour",
    "Missing required context role for implicit role", "Le r�le de contexte requis manquant pour le r�le implicite",
    "Missing required context role for WAI-ARIA attribute", "R�le de contexte requis manquant pour l'attribut WAI-ARIA",
    "Missing src attribute",         "Valeur manquante dans 'src' ",
    "Missing src value",             "Missing 'src' value ",
    "Missing table summary",         "R�sum� de tableau manquant",
    "Missing template comment",      "Commentaire manquant dans le mod�le",
    "Missing text alternative for",  "Alternative textuelle manquante pour",
    "Missing text in",               "Texte manquant dans ",
    "Missing text in table header",  "Texte manquant t�te de tableau ",
    "Missing title attribute for",   "Attribut 'title' manquant pour ",
    "Missing title content for",     "Contenu de l'�l�ment 'title' manquant pour ",
    "Missing value attribute in",    "Attribut 'value' manquant dans ",
    "Missing value in",              "Valeur manquante dans ",
    "Missing xml:lang attribute",    "Attribut 'xml:lang' manquant ",
    "Missing",                       "Manquantes",
    "More than 1 landmark in frame", "Plus d'un 'landmark' dans le cadre",
    "Mouse only event handlers found", "Gestionnaires de la souris ne se trouve que l'�v�nement",
    "Multiple instances of",         "Plusieurs instances de",
    "Multiple links with same anchor text",  "Liens multiples avec la m�me texte de lien ",
    "Multiple links with same title text",  "Liens multiples avec la m�me texte de 'title' ",
    "Multiple main content areas found, previous instance found", "Plusieurs domaines de contenu principal ont �t� trouv�s, l'instance pr�c�dente a �t� trouv�e",
    "must be contained by",          "doit �tre contenu par",
    "must not be contained in another landmark", "ne doit pas �tre contenu dans un autre landmark",
    "New heading level",             "Nouveau niveau d'en-t�te ",
    "No button found in form",       "Aucun bouton trouv� dans le <form>",
    "No captions found for",         "Pas de sous-titres trouv�s pour",
    "No closed caption content found", "Aucun de sous-titrage trouv�",
    "No content found in track",     "Contenu manquant dans <track>",
    "No controls on automatically played audio or video", "Aucune commande sur l'audio ou la vid�o lue automatiquement",
    "No data cells found in table",  "Aucune cellule de donn�es trouv�e dans le tableau",
    "No descriptions found for",     "Aucune description trouv�e pour",
    "No dt found in list",           "Pas de <dt> trouv� dans la liste ",
    "No form found with",            "Pas de <form> trouv� avec",
    "No headers found inside thead", "Pas de t�tes trouv�es � l'int�rieur de <thead>",
    "No headings found",             "Pas des t�tes qui se trouvent dans la zone de contenu",
    "No label for",                  "Aucun <label> pour ",
    "No label matching id attribute","Aucun <label> correspondant � l'attribut 'id' ",
    "No legend found in fieldset",   "Aucune <legend> retrouv� dans le <fieldset>",
    "No level one heading found",    "Aucun titre de niveau un trouv�",
    "No li found in list",           "Pas de <li> trouv� dans la liste ",
    "No links found",                "Pas des liens qui se trouvent",
    "No matching noembed for embed", "Aucun <noembed> correspondant � <embed>",
    "No table header reference",     "Aucun en-t�te de tableau retrouv�",
    "No tag with id attribute",      "Aucon balise avec l'attribut 'id'",
    "No td, th found inside tfoot",  "Pas de <td>, <th> trouve � l'int�rieur de <tfoot>",
    "Non-decorative image loaded via CSS with", "Image non-d�coratif charg� par CSS avec",
    "Non null title text",           "Non le texte 'title' nuls ",
    "Not all of visible text is included in accessible name", "Tout le texte visible n'est pas inclus dans le nom accessible",
    "not defined within table",      "pas d�fini dans le <table>",
    "not marked up as a <label>",    "pas marqu� comme un <label>",
    "Null alt on an image",          "Utiliser un attribut alt vide pour une image qui est le seul contenu d'un lien",
    "ol, ul must contain only li, script or template tags", "<ol>, <ul> ne doit contenir que des balises <li>, <script> ou <template>",
    "onclick or onkeypress found in tag", "'onclick' ou 'onkeypress' trouv� dans la balise ",
    "Only label for",                "Seule �tiquette pour",
    "Only 1 contact information type token allowed", "Un seul jeton de type d'informations de contact est autoris�",
    "or",                            " ou ",
    "Page contains more than 1 landmark with", "Cette page contient plus d'un 'landmark' avec",
    "Page redirect not allowed",     "Page rediriger pas autoris�",
    "Page refresh not allowed",      "Page raffra�chissement pas autoris�",
    "Previous instance found at",    "Instance pr�c�dente trouv�e � (la ligne:colonne) ",
    "Previous label not explicitly associated to", "�tiquette pr�c�dente pas explicitement associ�e � la ",
    "previously found",                 "trouv� avant",
    "Required testcase not executed",  "Cas de test requis pas ex�cut�",
    "Section grouping must be first token in term", "Le regroupement de sections doit �tre le premier jeton du terme".
    "Self reference in headers",       "r�f�rence auto dans 'headers'",
    "Span language attribute",         "Attribut de langue 'span'",
    "started at line:column",          "a commenc� � (la ligne:colonne) ",
    "summary found in layout table", "<summary> trouv� dans la table de mise en page",
    "Tabindex value greater than zero", "Valeur Tabindex sup�rieure � z�ro",
    "Table found in table header",     "Tableau trouv� dans l'en-t�te du tableau",
    "Table found in table footer",     "Tableau trouv� dans le pied de page du tableau",
    "Table header found in layout table", "En-t�te de table trouv�e dans la table de mise en page",
    "Table found in th",               "Tableau trouv� dans <th>",
    "Table headers",                   "'headers' de tableau",
    "Tag",                             "Balise",
    "Tag contains decorative and non-decorative attributes", "La balise contient des attributs d�coratifs et non d�coratifs",
    "Tag has accessible name but not in the accessible tree", "La balise a un nom accessible mais pas dans l'arborescence accessible",
    "Tag has empty accessible name",   "La balise a un nom accessible vide",
    "Tag not allowed here",            "Balise pas autoris� ici ",
    "Text alternative",                "Alternative textuelle",
    "Text styled to appear like a heading", "Texte de style pour appara�tre comme un titre",
    "Text",                            "Texte",
    "Title same as id for",            "'title' identique � 'id' pour ",
    "Title text greater than 500 characters",    "Texte du title sup�rieure 500 caract�res",
    "Title values do not match for",   "Valeurs 'title' ne correspondent pas pour ",
    "Unable to determine content language, possible languages are", "Impossible de d�terminer la langue du contenu, les langues possibles sont",
    "Unused label, for attribute",     "<label> ne pas utilis�, l'attribut 'for' ",
    "used for decoration",             "utilis� pour la dcoration",
    "Using script to remove focus when focus is received", "Utiliser un script pour enlever le focus lorsque le focus est re�u",
    "Using white space characters to control spacing within a word in tag", "Utiliser des caract�res blancs pour contr�ler l'espacement � l'int�rieur d'un mot dans balise",
    "WAI-ARIA attribute",              "Attribut WAI-ARIA",
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
    Pa11y_Check_Debug($debug);
    HTML_Landmark_Debug($debug);
    XML_TTML_Text_Debug($debug);
    Deque_AXE_Debug($debug);
    TQA_WAI_Aria_Debug($debug);
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

    #
    # Set language for supporting modules
    #
    Set_Pa11y_Check_Language($language);
    Set_Deque_AXE_Language($language);
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

    #
    # Set testcase data for supporting modules
    #
    Set_Pa11y_Check_Testcase_Data($testcase, $data);
    Set_Deque_AXE_Testcase_Data($testcase, $data);
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
    my ($profile, $tqa_checks) = @_;

    my (%local_tqa_checks);
    my ($key, $value);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_HTML_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_tqa_checks = %$tqa_checks;
    $tqa_check_profile_map{$profile} = \%local_tqa_checks;


    #
    # Set testcase data for supporting modules
    #
    Set_Pa11y_Check_Test_Profile($profile, $tqa_checks);
    Set_Deque_AXE_Test_Profile($profile, $tqa_checks);
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
    # Initialize other global variables
    #
    %abbr_acronym_text_title_lang_location = ();
    %abbr_acronym_text_title_lang_map = ();
    %abbr_acronym_title_text_lang_location = ();
    %abbr_acronym_title_text_lang_map = ();
    %accesskey_location    = ();
    %anchor_location       = ();
    $anchor_inside_emphasis = 0;
    %anchor_name           = ();
    %anchor_text_href_map  = ();
    %aria_labelledby_controls_location = ();
    %aria_owns_tag         = ();
    %audio_track_kind_map  = ();
    %css_styles            = ();
    $current_a_arialabel   = "";
    $current_a_href        = "";
    $current_a_title       = "";
    $current_content_lang_code = "";
    $current_end_tag       = "";
    $content_heading_count = 0;
    $current_heading_level = undef;
    $current_landmark      = "";
    $current_lang          = "eng";
    $current_list_level    = -1;
    $current_required_children_roles = undef;
    $current_tag_object    = undef;
    $current_tag_styles    = "";
    $current_text_handler_tag = "";
    $current_video_tag     = undef;
    $doctype_column        = -1;
    $doctype_label         = "";
    $doctype_line          = -1;
    $embed_noembed_count   = 0;
    $emphasis_count        = 0;
    %f32_reported          = ();
    %fieldset_input_count  = ();
    $fieldset_tag_index    = 0;
    undef($first_html_tag_lang);
    $form_count            = 0;
    %form_id_values        = ();
    %form_label_value      = ();
    %form_legend_value     = ();
    %form_title_value      = ();
    $found_content_after_heading = 0;
    $found_frame_tag       = 0;
    $found_h1              = 0;
    %found_legend_tag      = ();
    $found_title_tag       = 0;
    $found_title_tag_in_body = 0;
    $found_valid_meta_refresh = 0;
    %frame_landmark_count  = ();
    %frame_title_location  = ();
    $have_metadata         = 0;
    $have_text_handler     = 0;
    @heading_level_stack   = ();
    %html_tags_allowed_only_once_location = ();
    %id_attribute_values   = ();
    %id_value_references   = ();
    $image_found_inside_anchor = 0;
    $in_form_tag           = 0;
    $in_head_tag           = 0;
    $in_header_tag         = 0;
    $inline_style_count    = 0;
    %input_form_id         = ();
    %input_id_location     = ();
    %input_instance_not_allowed_label = ();
    $inside_anchor         = 0;
    $inside_audio          = 0;
    $inside_frame          = 0;
    $inside_h_tag_set      = 0;
    $inside_label          = 0;
    $inside_video          = 0;
    %label_for_location    = ();
    $landmark_marker       = "";
    %landmark_count        = ();
    @lang_stack            = ($current_lang);
    $last_a_contains_image = 0;
    $last_a_href           = "";
    $last_close_tag        = "";
    $last_heading_text     = "";
    $last_img_title        = "";
    %last_label_attributes = ();
    $last_label_text       = "";
    $last_lang_tag         = "top";
    $last_open_tag         = "";
    %last_option_attributes = ();
    $last_radio_checkbox_name = "";
    $last_tag              = "";
    %legend_text_value     = ();
    @list_item_count       = ();
    $main_content_start    = "";
    @missing_table_headers = ();
    $modified_content      = 0;
    $number_of_writable_inputs = 0;
    %object_has_label      = ();
    $object_nest_level     = 0;
    @param_lists           = ();
    $parent_tag            = "";
    $parent_tag_object     = "";
    $pseudo_header         = "";
    undef($summary_tag_content);
    $table_nesting_index   = -1;
    @table_start_line      = ();
    @table_start_column    = ();
    @table_has_headers     = ();
    @table_header_values   = ();
    @table_header_types    = ();
    @table_is_layout       = ();
    @table_th_td_in_thead_count = ();
    @table_th_td_in_thead_count = ();
    @table_header_locations = ();
    @table_td_count        = ();
    $tag_is_aria_hidden    = 0;
    $tag_is_hidden         = 0;
    $tag_is_visible        = 1;
    @tag_lang_stack        = ("top");
    @tag_order_stack       = ();
    $text_between_tags     = "";
    @text_handler_tag_list = ();
    @text_handler_all_text_list = ();
    @text_handler_tag_text_list = ();
    @text_handler_all_text = ();
    @text_handler_tag_text = ();
    $total_heading_count   = 0;
    %video_track_kind_map  = ();
    $wcag_2_0_h74_reported = 0;
    $wcag_2_0_f70_reported = 0;

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
    $deprecated_attributes = \%deprecated_html4_attributes;
    $deprecated_tags = \%deprecated_html4_tags;
    $implicit_end_tag_end_handler = \%implicit_html4_end_tag_end_handler;
    $implicit_end_tag_start_handler = \%implicit_html4_end_tag_start_handler;
    $valid_rel_values = \%valid_xhtml_rel_values;

    #
    # Check to see if we were told that this document is not
    # valid HTML
    #
    if ( $is_valid_html == 0 ) {
        Record_Result("WCAG_2.0-G134", -1, 0, "",
                      String_Value("Fails validation"));
    }
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
# Parameters: testcase - list of testcase identifiers
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
    my ($testcase_list, $line, $column, $text, $error_string) = @_;

    my ($result_object, $source_line, $new_column, $testcase, $id);
    my ($impact);

    #
    # Check for a possible list of testcase identifiers.  The first
    # identifier that is part of the current profile is the one that
    # the error will be reported against.
    #
    foreach $id (split(/,/, $testcase_list)) {
        if ( defined($$current_tqa_check_profile{$id}) ) {
            $testcase = $id;
            last;
        }
    }

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
        $result_object->xpath(Get_Tag_XPath());
        push (@$results_list_addr, $result_object);
        
        #
        # Add impact if it is not blank.
        #
        $impact = TQA_Testcase_Impact($testcase);
        if ( $impact ne "" ) {
            $result_object->impact($impact);
        }

        #
        # Print error string to stdout
        #
        Print_Error($line, $column, $text, "$testcase : $error_string");
    }
    
    #
    # Return testcase result object
    #
    return($result_object);
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
#             this_tag_hidden - flag to tell if tag content is hidden
#
# Description:
#
#   This function destroys a text handler.
#
#***********************************************************************
sub Destroy_Text_Handler {
    my ($self, $tag, $this_tag_hidden) = @_;
    
    my ($current_tag_text, $current_all_text, $current_text);

    #
    # Destroy text handler
    #
    print "Destroy_Text_Handler for tag $tag, is hidden = $this_tag_hidden\n" if $debug;
    
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
            # Don't add text to parent if this tag is hidden
            #
            elsif ( $this_tag_hidden ) {
                print "Adding text from hidden tag\n" if $debug;
                $current_all_text .= " $current_text";
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
# Name: Is_Interactive_Tag
#
# Parameters: tag - name of HTML tag
#             line - line number
#             column - column number
#             attr - hash table of attributes
#
# Description:
#
#   This function checks to see if this tag is an interactive tag
# that is intended for user interaction.
#
#***********************************************************************
sub Is_Interactive_Tag {
    my ($tag, $line, $column, %attr) = @_;

    my ($is_interactive) = 0;

    #
    # Check for a tag that could be interactive
    #
    print "Is_Interactive_Tag tag = $tag\n" if $debug;
    if ( defined($interactive_tag{$tag}) ) {
        #
        # Tag is an interactive tag
        #
        $is_interactive = 1;

        #
        # If this is an anchor tag, it must have an href attribute
        #
        if ( ($tag eq "a") && (! defined($attr{"href"})) ) {
            $is_interactive = 0;
        }
        #
        # If this is an audio tag, it must have a controls attribute
        #
        elsif ( ($tag eq "audio") && (! defined($attr{"controls"})) ) {
            $is_interactive = 0;
        }
        #
        # If this is an img tag, it must have a usemap attribute
        #
        elsif ( ($tag eq "img") && (! defined($attr{"usemap"})) ) {
            $is_interactive = 0;
        }
        #
        # If this is an input tag, it must not be of type hidden
        #
        elsif ( ($tag eq "input") &&
                defined($attr{"type"}) && ($attr{"type"} eq "hidden") ) {
            $is_interactive = 0;
        }
        #
        # If this is a video tag, it must have a controls attribute
        #
        elsif ( ($tag eq "video") && (! defined($attr{"controls"})) ) {
            $is_interactive = 0;
        }
        #
        # Do we have a tabindex attribute that makes tags not focusable?
        #
        elsif ( defined($attr{"tabindex"}) && ($attr{"tabindex"} < 0) ) {
           $is_interactive = 0;
        }
    }
    #
    # Do we have a tabindex attribute which can make any tag focusable?
    #
    elsif ( defined($attr{"tabindex"}) && ($attr{"tabindex"} >= 0) ) {
        $is_interactive = 1;
    }

    #
    # Check for attributes or conditions that can make an otherwise
    # interactive tag, non-interactive.
    #
    # Check for disabled attribute
    #
    if ( defined($attr{"disabled"}) ) {
        $is_interactive = 0;
    }
    #
    # Check for display:none styling
    #
    elsif ( defined($attr{"style"}) && ($attr{"style"} =~ /display:none/) ) {
        $is_interactive = 0;
    }
    #
    # Check if tag or ancestor is hidden
    #
    elsif ( $tag_is_hidden ) {
        $is_interactive = 0;
    }
    #
    # Check if tag or ancestor has CSS for display:none
    #
    elsif ( ! $tag_is_visible ) {
        $is_interactive = 0;
    }

    #
    # Return interactive indicator
    #
    print "is_interactive = $is_interactive\n" if $debug;
    return($is_interactive);
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
            # Add ACT testcase identifier, the ACT rule only applies
            # if there is an id value
            #
            $tcid .= ",ACT-ARIA_state_property_valid_value";
            foreach $aid (split(/\s+/, $aria_labelledby)) {
                $id_value_references{"$aid:$line:$column"} = "$aid:$line:$column:$tag:$tcid";
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
# Name: Check_For_Alt_or_Text_Alternative_Content
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
#   This function checks for text alternative content.
#
#***********************************************************************
sub Check_For_Alt_or_Text_Alternative_Content {
    my ( $tcid, $tag, $line, $column, $text, %attr ) = @_;

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
    #
    # Do we have an aria-label attribute?
    #
    elsif ( defined($attr{"aria-label"}) ) {
        $alt = $attr{"aria-label"};

        #
        # Remove whitespace and check to see if we have any text.
        # Report error only if tag is visible.
        #
        $alt =~ s/\s*//g;
        if ( $tag_is_visible && ($alt eq "") ) {
            Record_Result($tcid, $line, $column, $text,
                          String_Value("Missing aria-label content for") . "$tag");
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

    my ($title, $frame_line, $frame_column);

    #
    # Found a Frame tag, set flag so we can verify that the doctype
    # class is frameset
    #
    $found_frame_tag = 1;
    $inside_frame = 1;
    %frame_landmark_count = ();

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
            #
            # Have we seen this title before?
            #
            elsif ( defined($frame_title_location{"$title"}) ) {
                ($frame_line, $frame_column) = split(/:/,
                                     $frame_title_location{"$title"});
                Record_Result("WCAG_2.0-H64", $line, $column,
                              $text, String_Value("Duplicate frame title") .
                              " '$title'" .  " " .
                              String_Value("Previous instance found at") .
                              "$frame_line:$frame_column");
            }
            #
            # Save frame location
            #
            else {
                $frame_title_location{"$title"} = "$frame_line:$frame_column";
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
# Name: End_Frame_Tag_Handler
#
# Parameters: self - reference to this parser
#              tag - tag name
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the frame or iframe close tag.
#
#***********************************************************************
sub End_Frame_Tag_Handler {
    my ($self, $tag, $line, $column, $text) = @_;

    #
    # No longer inside a frame.
    #
    print "End of $tag\n" if $debug;
    $inside_frame = 0;
    
    #
    # Check that there are no more than 1 main landmarks in this frame
    #
    if ( defined($frame_landmark_count{"main"}) &&
         ($frame_landmark_count{"main"} > 1) ) {
#        Record_Result("AXE-Landmark_one_main", $line, $column, $text,
#                     String_Value("Frame contains more than 1 landmark with") .
#                      " role=\"main\"");
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
    $inside_tfoot[$table_nesting_index] = 0;
    $table_th_td_in_thead_count[$table_nesting_index] = 0;
    $table_th_td_in_tfoot_count[$table_nesting_index] = 0;
    $table_td_count[$table_nesting_index] = 0;

    #
    # Is this a layout table, role="presentation" or role="none"
    #
    if ( defined($attr{"role"}) &&
         (($attr{"role"} eq "presentation") ||
          ($attr{"role"} eq "none")) ) {
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
    
    #
    # Is this a nested table?
    #
    if ( $table_nesting_index > 0 ) {
        #
        # Are we inside the thead of a parent table?
        #
        if ( $inside_thead[($table_nesting_index - 1)] ) {
            Record_Result("WCAG_2.0-SC1.3.1", $line, $column, $text,
                          String_Value("Table found in table header"));
        }
        #
        # Are we inside the thead of a parent table?
        #
        elsif ( $inside_tfoot[($table_nesting_index - 1)] ) {
            Record_Result("WCAG_2.0-SC1.3.1", $line, $column, $text,
                          String_Value("Table found in table footer"));
        }
        #
        # Are we inside a th tag?
        #
        elsif ( Check_For_Ancestor_Tag("th") ) {
            Record_Result("WCAG_2.0-SC1.3.1", $line, $column, $text,
                          String_Value("Table found in th"));
        }
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
            Record_Result(join(",", @tcids), $line, $column, $text,
                              String_Value("No legend found in fieldset"));
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
                    Record_Result("WCAG_2.0-H43,ACT-Headers_refer_to_same_table",
                                  $h_line, $h_column, $h_text,
                                  String_Value("Table headers") .
                                  " \"$id\" " .
                                  String_Value("not defined within table"));
                }
            }
        }
        
        #
        # Did we find any data cells in the table?
        #
        if ( $table_td_count[$table_nesting_index] == 0 ) {
               Record_Result("WCAG_2.0-H51", $h_line, $h_column, $h_text,
                             String_Value("No data cells found in table"));
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
    # "separator" or "presentation" or "none" ?
    #
    if ( defined($attr{"role"}) &&
         ($attr{"role"} eq "presentation" ||
          $attr{"role"} eq "separator" ||
          $attr{"role"} eq "none") ) {
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
# Name: Body_Tag_Handler
#
# Parameters: self - reference to object
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the body tag.
#
#***********************************************************************
sub Body_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Is there an aria-hidden attribute?
    #
    if ( defined($attr{"aria-hidden"}) && ($attr{"aria-hidden"} eq "true") ) {
        Record_Result("WCAG_2.0-SC4.1.2", $line, $column, $text,
                      String_Value("aria-hidden must not be present on the document body"));
    }
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
    my ($value, $clean_text, $label_is_aria_hidden, $role);
    my ($label_line, $label_column, $label_is_visible, $label_is_hidden);
    my ($aria_describedby);
    my ($found_label) = 0;
    my ($found_fieldset) = 0;

    #
    # Get role for current tag
    #
    if ( defined($current_tag_object) ) {
        $role = $current_tag_object->explicit_role();
        if ( $role eq "" ) {
            $role = $current_tag_object->implicit_role();
        }
    }
    else {
        $role = "";
    }

    #
    # Get possible id attribute
    #
    print "Check_Label_Aria_Id_or_Title for $tag, label_required = $label_required\n" if $debug;
    if ( defined($attr{"id"}) ) {
        $id = $attr{"id"};
        $id =~ s/^\s*//g;
        $id =~ s/\s*$//g;
        print "Have id = \"$id\"\n" if $debug;

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
    # Get possible title attribute
    #
    if ( defined($attr{"title"}) ) {
        $title = $attr{"title"};
        $title =~ s/^\s*//g;
        $title =~ s/\s*$//g;
        print "Have title = \"$title\"\n" if $debug;
    }

    #
    # Get possible aria-describedby attribute
    #
    if ( defined($attr{"aria-describedby"}) ) {
        $aria_describedby = $attr{"aria-describedby"};
        print "Have aria-describedby = \"$aria_describedby\"\n" if $debug;
    }

    #
    # If we are inside a fieldset, it (and it's legend) can
    # act as a partial label (WCAG 2.0 H71).  An explicit label is
    # still required.
    #
    if ( $fieldset_tag_index > 0 ) {
        #
        # Inside a fieldset, the legend can act as a label.
        #
        print "Inside a fieldset, legend can be part of the label\n" if $debug;
        $found_fieldset = 1;

        #
        # Increment count of inputs inside this fieldset
        #
        $fieldset_input_count{$fieldset_tag_index}++;
    }
    
    #
    # Get possible aria-label attribute
    #
    if ( defined($attr{"aria-label"}) ) {
        $value = $attr{"aria-label"};
        print "Have aria-label = \"$value\"\n" if $debug;
        $found_label = 1;
    }
    #
    # Get possible aria-labelledby attribute
    #
    elsif ( defined($attr{"aria-labelledby"}) ) {
        $value = $attr{"aria-labelledby"};
        print "Have aria-labelledby = \"$value\"\n" if $debug;
        $found_label = 1;

        #
        # Have we already used this aria-labelledby value on
        # another input?
        #
        Check_Aria_Labelledby_Interface_Controls($tag, $line, $column,
                                                 $text, $attr{"aria-labelledby"});
    }

    #
    # Check id attribute and corresponding label
    #
    if ( (! $found_label) && defined($id) && ($id ne "") ) {
        $found_label = 1;

        #
        # See if we have a label (we may not have one if it comes
        # after this input).
        #
        if ( defined($label_for_location{$id}) ) {
            ($label_line, $label_column, $label_is_visible,
             $label_is_hidden, $label_is_aria_hidden) = split(/:/, $label_for_location{$id});
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
                #
                # The label my be off screen, but a placeholder may
                # be present for sighted users.  The placeholder
                # is not the label.
                #
                if ( defined($attr{"placeholder"}) && ($attr{"placeholder"} ne "") ) {
                    print "Visable place holder and invisible label\n" if $debug;
                }
                else {
                    Record_Result("WCAG_2.0-H44", $line, $column, "",
                                  String_Value("Label referenced by") .
                                  " 'id=\"$id\"' " .
                                  String_Value("is not visible") . ". <label> " .
                                  String_Value("started at line:column") .
                                  " $label_line:$label_column");
                }
            }
            #
            # Is the input visible and the label aria-hidden ?
            #
            elsif (  $tag_is_visible && $label_is_aria_hidden ) {
                Record_Result("WCAG_2.0-H44", $line, $column, "",
                              String_Value("Label referenced by") .
                              " 'id=\"$id\"' " .
                              String_Value("is inside aria-hidden tag") . ". <label> " .
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
            #  a) we have a title attribute and value
            #
            if ( defined($title) && ($title ne "") ) {
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
            #  a) we have a title attribute and value
            # We record this id reference to make sure we find it
            # before the form ends.
            #
            if ( defined($title) && ($title ne "") ) {
                print "Title attribute to act as label\n" if $debug;
            }
            else {
                $input_id_location{"$id"} = "$line:$column:tag_is_visible:$tag_is_hidden";
            }
        }
    }

    #
    # Is this input nested inside a label ?
    #
    if ( (! $found_label) && $inside_label ) {
        print "Input inside of label\n" if $debug;
        $found_label = 1;
    }
    
    #
    # Do we have only a title as a possible label?
    #
    if ( ! $found_label ) {
        if ( defined($title) && ($title ne "") ) {
#            Record_Result("AXE-Label_title_only", $line, $column, $text,
#                          String_Value("Only label for") . " $tag " .
#                          String_Value("is") . " title=\"$title\"");
        }
        #
        # Do we have only an aria-describedby as a possible label?
        #
        elsif ( defined($aria_describedby) && ($aria_describedby ne "") ) {
#            Record_Result("AXE-Label_title_only", $line, $column, $text,
#                          String_Value("Only label for") . " $tag " .
#                          String_Value("is") . " aria-describedby=\"$aria_describedby\"");
        }
    }

    #
    # Get possible title attribute
    #
    if ( defined($title) ) {
        print "Have title = \"$title\"\n" if $debug;

        #
        # Did we have an id value? and is it the same as the title?
        #
        if ( defined($id) && (lc($title) eq lc($id)) ) {
            Record_Result("WCAG_2.0-H65", $line, $column, $text,
                          String_Value("Title same as id for") . $tag);
        }

        #
        # If we don't have a label yet, do we have a title value
        # to act as the title?
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
    # Catch all case, no id, no aria attributes, no title, so we don't have an explicit label association.
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
# Name: Check_Aria_Labelledby_Interface_Controls
#
# Parameters: tag - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             aria_value - aria-labelledby value
#
# Description:
#
#   This function checks to see if the aria-labelledby value is
# referenced by multiple interface controls (e.g. input).
#
#***********************************************************************
sub Check_Aria_Labelledby_Interface_Controls {
    my ($tag, $line, $column, $text, $aria_value) = @_;

    my ($label_is_visible, $label_is_hidden, $label_is_aria_hidden);
    my ($label_line, $label_column, $label_is_visible, $label_tag);

    #
    # Have we already used this aria-labelledby value on
    # another input?
    #
    $aria_value =~ s/\s//g;
    if ( defined($aria_labelledby_controls_location{"$aria_value"}) ) {
        ($label_tag, $label_line, $label_column) = split(/:/,
                             $aria_labelledby_controls_location{"$aria_value"});
        Record_Result("WCAG_2.0-ARIA16", $line, $column,
                      $text, String_Value("Duplicate aria-labelledby reference on interface controls") .
                      "'aria-labelledby=\"$aria_value\"' " .
                      String_Value("Previous instance found at") .
                      " $label_line:$label_column <$label_tag>");
    }
    #
    # This aria-labelledby has not been referenced before, record the
    # location.
    #
    else {
        $aria_labelledby_controls_location{"$aria_value"} = "$tag:$line:$column";
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
    my ($label_error, $clean_text, $label_line, $label_column, $tcid);
    my ($label_is_hidden, $label_is_aria_hidden, $label_is_visible);
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
        Check_For_Alt_or_Text_Alternative("WCAG_2.0-F65",
                                          $input_tag_type, $line, $column,
                                          $text, %attr);

        #
        # Check for alt text content
        #
        Check_For_Alt_or_Text_Alternative_Content("WCAG_2.0-H36",
                          $input_tag_type, $line,
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
    # Check to see if the input type is required to have a label associated
    # with it.
    #
    elsif ( index($input_types_not_using_label, " $input_type ") == -1 ) {
        #
        # Check for one of a title or label
        #
        print "Input requires a label\n" if $debug;
        if ( index($input_types_requiring_label_before,
                   " $input_type ") != -1 ) {
            #
            # Should expect a label for this input before input.
            #
            $found_label = Check_Label_Aria_Id_or_Title($self, $input_tag_type,
                                                        1, $line, $column,
                                                        $text, %attr);
        }
        elsif ( index($input_types_requiring_label_after,
                   " $input_type ") != -1 ) {
            #
            # Label may appear after this input.  Label check will happen
            # at the end of the HTML page.
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
                    ($label_line, $label_column, $label_is_visible,
                     $label_is_hidden, $label_is_aria_hidden) =
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
        # Did we find a <aria-label> attribute ?
        #
        print "Button requiring a value or title attribute\n" if $debug;
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
            $value = $attr{"value"};
            $value =~ s/\s//g;
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
        #
        # Do we have a title attribute
        #
        elsif ( defined($attr{"title"}) ) {
            #
            # Do we have an actual value ?
            #
            $value = $attr{"title"};
            $value =~ s/\s//g;
            if ( $value eq "" ) {
#                Record_Result("AXE-Input_button_name", $line, $column, $text,
#                              String_Value("Missing title content for") .
#                              " $input_tag_type");
            }
        }
        #
        # If this is a submit or reset button, and ID attribute can be used
        # to provide the text.
        #
        elsif ( (($input_type eq "reset") || ($input_type eq "submit")) &&
                 (defined($attr{"id"}) && ($attr{"id"} ne "")) ) {
            print "Have id on reset or submit button input\n" if $debug;
        }
        #
        # If tag is visible, report error
        #
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
                # Are we inside a fieldset?
                #
                print "Next $input_type of a list, name = " . $attr{"name"} .
                      " last input name = $last_radio_checkbox_name\n" if $debug;
                if ( $tag_is_visible && ($fieldset_tag_index == 0) ) {
                    #
                    # No fieldset for these inputs
                    #
                    Record_Result("WCAG_2.0-H71", $line, $column, $text,
                                  String_Value("Missing fieldset"));
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
#   This function checks for an accesskey attribute. Checks to see that
# the value is unique and valid.
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
            # Have we seen this accesskey value before ?
            #
            if ( defined($accesskey_location{"$accesskey"}) ) {
                Record_Result("WCAG_2.0-F77", $line, $column,
                              $text, String_Value("Duplicate accesskey") .
                              "'$accesskey'" .  " " .
                              String_Value("Previous instance found at") .
                              $accesskey_location{$accesskey});
            }

            #
            # Save accesskey location
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
    my ($label_is_aria_hidden);

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
                ($label_line, $label_column, $label_is_visible,
                 $label_is_hidden, $label_is_aria_hidden) = split(/:/,
                                     $label_for_location{"$label_for"});
                Record_Result("WCAG_2.0-F77", $line, $column,
                              $text, String_Value("Duplicate label for") .
                              "$label_for\"'" .  " " .
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
            $label_for_location{"$label_for"} = "$line:$column:$tag_is_visible:$tag_is_hidden:$tag_is_aria_hidden";
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
            Record_Result("WCAG_2.0-H44,WCAG_2.0-G131", $line, $column,
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
            Record_Result("WCAG_2.0-H71,WCAG_2.0-G131", $line, $column,
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

    my ($clean_text);

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
# Name: End_Pre_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end pre tag.
#
#***********************************************************************
sub End_Pre_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($this_text, $result_object, @results_list);

    #
    # Get all the text found within the p tag
    #
    if ( ! $have_text_handler ) {
        #
        # If we don't have a text handler, it was hijacked by some other
        # tag (e.g. anchor tag).  We only care about simple paragraphs
        # so if there is no handler, we ignore this paragraph.
        #
        print "End pre tag found no text handler at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the pre text as a string
    #
    $this_text = Get_Text_Handler_Content($self, " ");

    #
    # Perform accessibility checks on the pre tag content (e.g. headings, lists,
    # paragraphs, tables)
    #
    @results_list = Text_Check($current_url, "", "WCAG 2.0", \$this_text, $line,
                               $column);

    #
    # Add help URL to result
    #
    foreach $result_object (@results_list) {
        push (@$results_list_addr, $result_object);
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
    # Was there any text in the div ?
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
        print "Check_Headers_Attribute \"$headers\"\n" if $debug;

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
                    print "Parent headers list \"$p_headers\"\n" if $debug;

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
                            Record_Result("WCAG_2.0-H43",
                                          $line, $column, $text,
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
#***********************************************************************
sub Delayed_Headers_Attribute_Check {
    my ($id) = @_;

    my ($header_values, $headers, $table_ref, $list_ref);
    my ($r_ref, $p_id, $location_ref, %h43_reported);
    my ($r_line, $r_column, $r_headers, $r_text, $types_ref);

    #
    # Get list of references to this header
    #
    print "Delayed_Headers_Attribute_Check for id $id\n" if $debug;
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
            print "Referenced headers list \"$r_headers\"\n" if $debug;

            #
            # Check that each id in this headers list is in
            # this referenced tag's header list.
            #
            foreach $p_id (split(/\s+/, $headers)) {
                print "Check for header \"$p_id\" in referenced headers\n" if $debug;
                if ( index(" $r_headers ", " $p_id ") == -1 ) {
                    #
                    # Report error only report once per possible parent id.
                    #
                    if ( ! defined($h43_reported{$p_id}) ) {
                        Record_Result("WCAG_2.0-H43",
                                      $r_line, $r_column, $r_text,
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
                    Record_Result("WCAG_2.0-H88,ACT-Headers_refer_to_same_table",
                                  $line, $column, $text,
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
    my ($complete_headers, $header_location, $header_type, $h_id);

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
        # Are we inside a <tfoot> ?
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

            #
            # Check to see if this tag references it's own id in the
            # list of headers.
            #
            foreach $h_id (split(/\s+/, $complete_headers)) {
                if ( $h_id eq $id ) {
                    Record_Result("WCAG_2.0-H88,ACT-Headers_refer_to_same_table",
                                  $line, $column, $text,
                                  String_Value("Self reference in headers") .
                                  " <th id=\"$id\" headers=\"$id\">");
                    last;
                }
            }
        }

        #
        # Are we in a thead? If so these are header cells
        # not data cells
        #
        if ( $inside_thead[$table_nesting_index] ) {
            print "td acting a th in thead\n" if $debug;
        }
        else {
            #
            # This looks like a data cell
            #
            $table_td_count[$table_nesting_index]++;
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
# Name: Check_Autoplay
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             src - source of audio or video file
#             attr - hash table of attributes
#
# Description:
#
#   This function checks to see if the audio or video source will
# autoplay with no controls to limit it to 3 seconds or less.
#
#***********************************************************************
sub Check_Autoplay {
    my ($line, $column, $text, $src, %attr) = @_;

    my ($autoplay, $controls, $play_time, $start, $stop);

    #
    # Does the source specify a play time limit?
    #  e.g. video.mp4#t=8,10
    #  causes the video to start at 8 seconds and stop at 10.
    #
    print "Check_Autoplay\n" if $debug;
    ($start, $stop) = $src =~ /^.*#.*t=(\d+),(\d+).*$/io;
    if ( defined($start) && defined($stop) ) {
        $play_time = $stop - $start;
    }

    #
    # Do we have autoplay? and is it set to true?
    #
    if ( defined($attr{"autoplay"}) && ($attr{"autoplay"} ne "false") ) {
        $autoplay = 1;
    }
    else {
        $autoplay = 0;
    }

    #
    # Do we have controls
    #
    if ( defined($attr{"controls"}) && ($attr{"controls"} ne "false") ) {
        $controls = 1;
    }
    else {
        $controls = 0;
    }

    #
    # Does the audio play for 3 seconds or less?
    #
    if ( defined($play_time) && ($play_time < 4) ) {
        print "Audio playtime is 3 seconds or less\n" if $debug;
    }
    #
    # Do we have controls?
    #
    elsif ( $controls ) {
        print "Audio has controls\n" if $debug;
    }
    #
    # Is there no autoplay?
    #
    elsif ( ! $autoplay ) {
        print "Audio has no autoplay\n" if $debug;
    }
    #
    # Source automatically plays with no controls
    #
    else {
        Record_Result("ACT-Audio_video_not_automatic", $line, $column,
                      $text, String_Value("No controls on automatically played audio or video"));
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
    # Are we inside a video or audio tag ?
    #
    if ( $inside_video || $inside_audio ) {
        #
        # Do we have a kind attribute ?
        #
        if ( defined($attr{"kind"}) ) {
            $kind = $attr{"kind"};
        }
        else {
            $kind = "subtitles";
        }
        
        #
        # Save the kind of track
        #
        if ( $inside_video ) {
            $video_track_kind_map{$kind} = 1;
        }
        else {
            $audio_track_kind_map{$kind} = 1;
        }

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
# Name: Source_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the source tag.
#
#***********************************************************************
sub Source_Tag_Handler {
    my ($line, $column, $text, %attr) = @_;

    my ($src, $attr_ptr);

    #
    # Do we have a src attribute for the audio source?
    #
    if ( defined($attr{"src"}) ) {
        $src = $attr{"src"};

        #
        # Check for automatic playing of the source. Use the attributes
        # of the parent video tag for autoplay, controls, etc.
        #
        if ( defined($current_video_tag) ) {
            $attr_ptr = $current_video_tag->attr();
            Check_Autoplay($line, $column, $text, $src, %$attr_ptr);
        }
    }
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
    
    my ($src);

    #
    # Set flag to indicate we are inside a audio tag set.
    #
    $inside_audio = 1;
    %audio_track_kind_map = ();
    
    #
    # Do we have a src attribute for the audio source?
    #
    if ( defined($attr{"src"}) ) {
        $src = $attr{"src"};
        
        #
        # Check for automatic playing of the source
        #
        Check_Autoplay($line, $column, $text, $src, %attr);
    }
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
        Record_Result("WCAG_2.0-G158", $line, $column, $text,
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
    
    my ($src);

    #
    # Set flag to indicate we are inside a video tag set.
    #
    $inside_video = 1;
    $current_video_tag = $current_tag_object;
    %video_track_kind_map = ();
    
    #
    # Do we have a src attribute?
    #
    if ( defined($attr{"src"}) ) {
        $src = $attr{"src"};

        #
        # Check for automatic playing of the source.
        #
        Check_Autoplay($line, $column, $text, $src, %attr);
    }
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

    my ($tcid);
    
    #
    # Is this tag visible?
    #
    $tcid = "WCAG_2.0-G87";
    if ( $current_tag_object->is_visible() ) {
        $tcid .= ",ACT-Video_auditory_has_captions";
    }

    #
    # No longer in a <video> .. </video> pair
    #
    print "End video tag, check tracks\n" if $debug;
    $inside_video = 0;
    undef($current_video_tag);
    
    #
    # Are we inside a figure?
    #
    if ( ! $in_figure ) {
        if ( (! defined($video_track_kind_map{"captions"})) &&
             (! defined($video_track_kind_map{"descriptions"})) ) {
            Record_Result($tcid, $line, $column, $text,
                          String_Value("No captions found for") . " <video>");
        }
    }
    #
    # Inside a figure tag. Are we missing captions or description?
    #
    elsif ( (! defined($video_track_kind_map{"captions"})) &&
            (! defined($video_track_kind_map{"descriptions"})) ) {
        $video_in_figure_with_no_caption = 1;
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
    Check_For_Alt_or_Text_Alternative_Content("WCAG_2.0-H24", "<area>",
                                              $line, $column, $text, %attr);
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
    my ($text_alternative) = "";

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
        $text_alternative = $last_image_alt_text;

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
    # Check for title attribute
    #
    if ( defined($attr{"title"}) ) {
        $last_img_title = $attr{"title"};
        $last_img_title = Clean_Text($last_img_title);
    }
    else {
        $last_img_title = "";
    }
    
    #
    # Check for aria-label text alternative
    #
    if ( defined($attr{"aria-label"}) ) {
        $text_alternative .= $attr{"aria-label"};
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
        if ( defined($testcase_data{"WCAG_2.0-F30"}) ||
             defined($testcase_data{"ACT-Image_accessible_name_descriptive"})) {
            $alt = lc($attr{"alt"});
            foreach $invalid_alt (split(/\n/, $testcase_data{"WCAG_2.0-F30"})) {
                #
                # Do we have a match on the invalid alt text ?
                #
                if ( $alt =~ /^$invalid_alt$/i ) {
                    Record_Result("WCAG_2.0-F30,ACT-Image_accessible_name_descriptive",
                                  $line, $column, $text,
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
            Record_Result("WCAG_2.0-F30,ACT-Image_accessible_name_descriptive",
                          $line, $column, $text,
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
        if ( defined($testcase_data{"WCAG_2.0-F30"}) ||
             defined($testcase_data{"ACT-Image_accessible_name_descriptive"}) ) {
            $aria_label = lc($attr{"aria-label"});
            foreach $invalid_alt (split(/\n/, $testcase_data{"WCAG_2.0-F30"})) {
                #
                # Do we have a match on the invalid alt text ?
                #
                if ( $aria_label =~ /^$invalid_alt$/i ) {
                    Record_Result("WCAG_2.0-F30,ACT-Image_accessible_name_descriptive",
                                  $line, $column, $text,
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
    
    #
    # Check for role="presentation" or role="none" and a text alternative
    #
    if ( defined($attr{"role"}) &&
         (($attr{"role"} eq "presentation") ||
          ($attr{"role"} eq "none")) ) {
        if ( $text_alternative ne "" ) {
           Record_Result("WCAG_2.0-F39", $line, $column, $text,
                         String_Value("Text alternative") .
                         " \"$text_alternative\" " .
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
    my ($lang_attr_value, $lang_value, $xml_lang_value);

    #
    # If this is not XHTML 2.0, we must have a 'lang' attribute
    #
    print "HTML_Tag_Handler\n" if $debug;
    if ( ! (($doctype_label =~ /xhtml/i) && ($doctype_version >= 2.0)) ) {
        #
        # Do we have a lang ?
        #
        if ( ! defined($attr{"lang"}) ) {
            #
            # Missing language attribute
            #
            if ( ! $modified_content ) {
                Record_Result("WCAG_2.0-H57,ACT-HTML_page_has_lang", $line, $column, $text,
                              String_Value("Missing html language attribute") .
                              " 'lang'");
            }
        }
        else {
            #
            # Save language code, but strip off any dialect value
            #
            $lang = lc($attr{"lang"});
            $lang_attr_value = $lang;
            $lang =~ s/-.*$//g;
            print "lang=\"$lang_attr_value\"\n" if $debug;
            
            #
            # Is there a language value?
            #
            if ( $lang_attr_value =~ /^\s*$/ ) {
                Record_Result("WCAG_2.0-H57,ACT-HTML_page_has_lang",
                              $line, $column, $text,
                              String_Value("Missing language attribute value") .
                              " lang=\"$lang_attr_value\"");
            }
            #
            # Are we checking the ACT ruleset?
            #
            elsif ( defined($$current_tqa_check_profile{"ACT-HTML_page_lang_valid"}) ) {
                #
                # Check the language portion and ignore any dialect
                #
                if ( ! Language_Valid($lang) ) {
                    Record_Result("ACT-HTML_page_lang_valid",
                                  $line, $column, $text,
                                  String_Value("Invalid language attribute value") .
                                  " lang=\"$lang_attr_value\"");
                }
            }
            #
            # Check full language attribute
            #
            elsif ( ! Language_Valid($lang_attr_value) ) {
                Record_Result("WCAG_2.0-H57,ACT-HTML_page_lang_valid",
                              $line, $column, $text,
                              String_Value("Invalid language attribute value") .
                              " lang=\"$lang_attr_value\"");
            }
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
                Record_Result("WCAG_2.0-H57,ACT-HTML_page_has_lang", $line, $column, $text,
                              String_Value("Missing html language attribute") .
                              " 'xml:lang'");
            }
        }
        else {
            #
            # Save language code, but strip off any dialect value
            #
            $lang = lc($attr{"xml:lang"});
            $lang_attr_value = $lang;
            $lang =~ s/-.*$//g;

            #
            # Is there a language value?
            #
            if ( $lang_attr_value =~ /^\s*$/ ) {
                Record_Result("WCAG_2.0-H57,ACT-HTML_page_has_lang",
                              $line, $column, $text,
                              String_Value("Missing language attribute value") .
                              " lang=\"$lang_attr_value\"");
            }
            #
            # Are we checking the ACT ruleset?
            #
            elsif ( defined($$current_tqa_check_profile{"ACT-HTML_page_lang_valid"}) ) {
                #
                # Check the language portion and ignore any dialect
                #
                if ( ! Language_Valid($lang) ) {
                    Record_Result("ACT-HTML_page_lang_valid",
                                  $line, $column, $text,
                                  String_Value("Invalid language attribute value") .
                                  " xml:lang=\"$lang_attr_value\"");
                }
            }
            #
            # Check full language attribute
            #
            elsif ( ! Language_Valid($lang_attr_value) ) {
                Record_Result("WCAG_2.0-H57,ACT-HTML_page_lang_valid",
                              $line, $column, $text,
                              String_Value("Invalid language attribute value") .
                              " xml:lang=\"$lang_attr_value\"");
            }
        }
    }

    #
    # Do we have both attributes ?
    #
    if ( defined($attr{"lang"}) && defined($attr{"xml:lang"}) ) {
        #
        # Are we checking the ACT ruleset?
        #
        if ( defined($$current_tqa_check_profile{"ACT-HTML_page_lang_xml_lang_match"}) ) {
            #
            # Check the language portion and ignore any dialect
            #
            $lang_value = $attr{"lang"};
            $lang_value =~ s/-.*$//g;
            $xml_lang_value = $attr{"xml:lang"};
            $xml_lang_value =~ s/-.*$//g;
            if ( lc($lang_value) ne lc($xml_lang_value) ) {
                Record_Result("ACT-HTML_page_lang_xml_lang_match", $line, $column, $text,
                              String_Value("Mismatching lang and xml:lang attributes") .
                              String_Value("for tag") . "<html>");
            }
        }
        #
        # Check full language and dialect
        #
        elsif ( lc($attr{"lang"}) ne lc($attr{"xml:lang"}) ) {
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
            Record_Result("WCAG_2.0-H57,ACT-HTML_page_lang_matches_content",
                          $line, $column, $text,
                          String_Value("HTML language attribute") .
                          " '$lang' " .
                          String_Value("does not match content language") .
                          " '$current_content_lang_code'");
        }
    }
    
    #
    # Is this a right to left language?
    #
    if ( defined($right_to_left_languages{$lang}) ) {
        #
        # Do we have a dir attribute to specify the direction of the
        # language (right to left)?
        #
        if ( ! defined($attr{"dir"}) ) {
            Record_Result("WCAG_2.0-H57", $line, $column, $text,
                          String_Value("Missing dir attribute for right to left language") .
                          " lang=\"$lang\"");
        }
        #
        # Is the direction right to left?
        #
        elsif ( $attr{"dir"} ne "rtl" ) {
            Record_Result("WCAG_2.0-H57", $line, $column, $text,
                          String_Value("Invalid direction for right to left language") .
                          " lang=\"$lang\" dir=\"" . $attr{"dir"} . "\"");
        }
    }
    #
    # Must be a left to right language, is the direction set correctly?
    #
    elsif ( defined($attr{"dir"}) && ($attr{"dir"} ne "ltr") ) {
            Record_Result("WCAG_2.0-H57", $line, $column, $text,
                          String_Value("Invalid direction for left to right language") .
                          " lang=\"$lang\" dir=\"" . $attr{"dir"} . "\"");
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

    my ($content, @values, $value, $tcid);

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
    # Is this the first instance encountered (subsequent instances are
    # ignored)
    #
    if ( (! $found_valid_meta_refresh) &&
         defined($attr{"http-equiv"}) && ($attr{"http-equiv"} =~ /refresh/i) ) {
        #
        # WCAG 2.0, check if there is a content attribute with a numeric
        # timeout value.  We don't check both F40 and F41 as the test
        # is the same and would result in 2 messages for the same issue.
        #
        if ( defined($attr{"content"}) ) {
            $content = $attr{"content"};

            #
            # Split content on semi-colon then check each value
            # to see if it contains only digits (and whitespace).
            #
            @values = split(/;/, $content);
            foreach $value (@values) {
                if ( $value =~ /^\s*\d+\s*$/ ) {
                    #
                    # Found timeout value, is it greater than 0 ?
                    # A 0 value is a client side redirect, which is a
                    # WCAG AAA check.
                    #
                    print "Meta refresh with timeout $value\n" if $debug;
                    if ( $value > 0 ) {
                        #
                        # Is the value less than 72000 (20 hours)? The ACT
                        # rules allow for refresh if the timeout is greater
                        # than 20 hours.
                        #
                        if ( $value <= 72000 ) {
                            $tcid = ",ACT-Meta_no_refresh_delay";
                        }
                        else {
                            $tcid = "";
                        }
                        
                        #
                        # Do we have a URL in the content, implying a redirect
                        # rather than a refresh ?
                        #
                        if ( ($content =~ /http/) || ($content =~ /url=/) ) {
                            Record_Result("WCAG_2.0-F40$tcid", $line, $column, $text,
                                  String_Value("Meta refresh with timeout") .
                                          "'$value'");
                        }
                        else {
                            Record_Result("WCAG_2.0-F41$tcid",
                                          $line, $column, $text,
                                    String_Value("Meta refresh with timeout") .
                                          "'$value'");
                        }
                    }

                    #
                    # Set flag to indicate we processed a valid
                    # meta-refresh. Only the first one is checked.
                    #
                    if ( defined($value) ) {
                        $found_valid_meta_refresh = 1;
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
                    Record_Result("WCAG_2.0-SC1.4.4,ACT-Meta_viewport_allows_zoom",
                                   $line, $column, $text,
                                   String_Value("Meta viewport with user-scalable disabled"));
                }
                #
                # Do we have a maximum scaling value ?
                #
                elsif ( $value =~ /maximum-scale/ ) {
                    #
                    # Is the maximum scaling less than 2 ?
                    #
                    $value =~ s/^\s*maximum-scale=//g;
                    print "maximum-scale = $value\n" if $debug;
                    if ( $value < 2.0 ) {
                        Record_Result("WCAG_2.0-SC1.4.4,ACT-Meta_viewport_allows_zoom",
                                      $line, $column, $text,
                                      String_Value("Meta viewport maximum-scale less than") .
                                      " 2");
                    }
                    #
                    # Is the maximum scaling less than 5 ?
                    #
#                    elsif ( $value < 5.0 ) {
#                        Record_Result("AXE-Meta_viewport_large",
#                                      $line, $column, $text,
#                                      String_Value("Meta viewport maximum-scale less than") .
#                                      " 5");
#                    }
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
# Name: Check_Decorative_Non_decorative_Attributes
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks to see if this tag is decorative. It then
# checks to see that the tag is not included in the accessibility
# tree and has a presentatinoal role.
#
#***********************************************************************
sub Check_Decorative_Non_decorative_Attributes {
    my ($tagname, $line, $column, $text, %attr) = @_;

    my ($non_decorative, $decorative);

    #
    # Check for null alt, which means the tag is decorative
    #
    if ( defined($attr{"alt"}) && ($attr{"alt"} eq "") ) {
        print "Decorative tag, alt=\"\"\n" if $debug;
        $decorative = 1;
    }
    #
    # Check for role=none or role=presentation, which means the tag
    # is decorative.
    #
    elsif ( defined($attr{"role"}) &&
            (($attr{"role"} eq "none") || ($attr{"role"} eq "presentation")) ) {
        print "Decorative tag, role=\"" . $attr{"role"} . "\"\n" if $debug;
        $decorative = 1;
    }
    else {
        #
        # A non-decorative tag
        #
        $decorative = 0;
    }
    
    #
    # Do we have any attributes that would cause the tag to have a
    # non-presentational role or be included in the accessibility tree?
    #
    if ( defined($attr{"aria-label"}) && ($attr{"aria-label"} ne "") ) {
        print "Found non-empty aria-label\n" if $debug;
        $non_decorative = 1;
    }
    elsif ( defined($attr{"aria-labelledby"}) && ($attr{"aria-labelledby"} ne "") ) {
        print "Found non-empty aria-labelledby\n" if $debug;
        $non_decorative = 1;
    }
    else {
        #
        # A non-decorative tag
        #
        $non_decorative = 0;
    }

    #
    # Did we find a conflict in decorative attributes and non-decorative
    # attributes?
    #
    if ( $decorative && $non_decorative ) {
        Record_Result("ACT-Element_decorative_not_exposed", $line, $column, $text,
                      String_Value("Tag contains decorative and non-decorative attributes"));
    }
}

#***********************************************************************
#
# Name: Is_Image_Decorative
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks to see if this tag is decorative.
#
#***********************************************************************
sub Is_Image_Decorative {
    my ($tagname, $line, $column, $text, %attr) = @_;

    my ($decorative) = 0;

    #
    # Check for null alt, which means the tag is decorative
    #
    if ( defined($attr{"alt"}) && ($attr{"alt"} eq "") ) {
        print "Decorative tag, alt=\"\"\n" if $debug;
        $decorative = 1;
    }
    
    #
    # Check for role=none or role=presentation, which means the tag
    # is decorative.
    #
    if ( defined($attr{"role"}) &&
            (($attr{"role"} eq "none") || ($attr{"role"} eq "presentation")) ) {
        print "Decorative tag, role=\"" . $attr{"role"} . "\"\n" if $debug;
        $decorative = 1;
    }

    #
    # Do we have any attributes that would cause the tag to have a
    # non-presentational role or be included in the accessibility tree?
    #
    if ( defined($attr{"aria-label"}) && ($attr{"aria-label"} ne "") ) {
        print "Found non-empty aria-label\n" if $debug;
        $decorative = 0;
    }
    elsif ( defined($attr{"aria-labelledby"}) && ($attr{"aria-labelledby"} ne "") ) {
        print "Found non-empty aria-labelledby\n" if $debug;
        $decorative = 0;
    }

    #
    # Return decorative status
    #
    return($decorative);
}

#***********************************************************************
#
# Name: Check_Aria_Controls_Attribute
#
# Parameters: tag - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#    This function checks ARIA attributes of a tag. It checks
# to see an attribute is present and has a value.  If an
# aria-controls attribute is found, it checks the id values.
#
#***********************************************************************
sub Check_Aria_Controls_Attribute {
    my ($tag, $line, $column, $text, %attr) = @_;

    my ($aria_controls, $aid, $tcid, $role);

    #
    # Do we have a aria-controls attribute ?
    #
    if ( defined($attr{"aria-controls"}) ) {
        $aria_controls = $attr{"aria-controls"};
        $aria_controls =~ s/^\s*//g;
        $aria_controls =~ s/\s*$//g;
        print "Have aria-controls = \"$aria_controls\"\n" if $debug;

        #
        # Determine the testcase that is appropriate for the tag
        #
        $tcid = "WCAG_2.0-ARIA1";

        #
        # Do we have content for the aria-controls attribute ?
        #
        if ( $aria_controls eq "" ) {
            #
            # Missing aria-controls value
            #
            if ( $tag_is_visible ) {
                Record_Result($tcid, $line, $column, $text,
                              String_Value("Missing content in") .
                              "'aria-controls='" .
                              String_Value("for tag") . "<$tag>");
            }
        }
        else {
            #
            # Record location of aria-controls references.
            # Add ACT testcase identifier, the ACT rule only applies
            # if there is an id value
            #
            $tcid .= ",ACT-ARIA_state_property_valid_value";
            foreach $aid (split(/\s+/, $aria_controls)) {
                $id_value_references{"$aid:$line:$column"} = "$aid:$line:$column:$tag:$tcid";
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Aria_Describedby_Attribute
#
# Parameters: tag - tag name
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
    my ($tag, $line, $column, $text, %attr) = @_;

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
            # Record location of aria-describedby references.
            # Add ACT testcase identifier, the ACT rule only applies
            # if there is an id value
            #
            $tcid .= ",ACT-ARIA_state_property_valid_value";
            foreach $aid (split(/\s+/, $aria_describedby)) {
                $id_value_references{"$aid:$line:$column"} = "$aid:$line:$column:$tag:$tcid";
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
# Name: Check_Aria_Labelledby_Attribute
#
# Parameters: tag - tag name
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
    my ($tag, $line, $column, $text, %attr) = @_;

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
                    if ( TQA_WAI_Aria_Landmark_Role($role) ) {
                        #
                        # Found landmark role
                        #
                        $tcid = "WCAG_2.0-ARIA13,ACT-ARIA_state_property_valid_value";
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
            # Record location of aria-labelledby references.
            # Add ACT testcase identifier, the ACT rule only applies
            # if there is an id value
            #
            $tcid .= ",ACT-ARIA_state_property_valid_value";
            foreach $aid (split(/\s+/, $aria_labelledby)) {
                print "Record id_value_references $aid:$line:$column:$tag:$tcid\n" if $debug;
                $id_value_references{"$aid:$line:$column"} = "$aid:$line:$column:$tag:$tcid";
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
# Name: Check_Aria_Owns_Attribute
#
# Parameters: tag - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#    This function checks ARIA attributes of a tag. It checks
# to see an attribute is present and has a value.  If an
# aria-owns attribute is found, it records the id value.
#
#***********************************************************************
sub Check_Aria_Owns_Attribute {
    my ($tag, $line, $column, $text, %attr) = @_;

    my ($aria_owns, $aid, $tcid, $tag_object);

    #
    # Do we have a aria-owns attribute ?
    #
    if ( defined($attr{"aria-owns"}) ) {
        $aria_owns = $attr{"aria-owns"};
        $aria_owns =~ s/^\s*//g;
        $aria_owns =~ s/\s*$//g;
        print "Have aria-owns = \"$aria_owns\"\n" if $debug;

        #
        # Determine the testcase that is appropriate for the tag
        #
        $tcid = "WCAG_2.0-ARIA1";

        #
        # Do we have content for the aria-owns attribute ?
        #
        if ( $aria_owns eq "" ) {
            #
            # Missing aria-owns value
            #
            if ( $tag_is_visible ) {
                Record_Result($tcid, $line, $column, $text,
                              String_Value("Missing content in") .
                              "'aria-owns='" .
                              String_Value("for tag") . "<$tag>");
            }
        }
        else {
            #
            # Record location of aria-owns references.
            # Add ACT testcase identifier, the ACT rule only applies
            # if there is an id value
            #
            $tcid .= ",ACT-ARIA_state_property_valid_value";
            foreach $aid (split(/\s+/, $aria_owns)) {
                $id_value_references{"$aid:$line:$column"} = "$aid:$line:$column:$tag:$tcid";

                #
                # Have we already found an aria-owns with this id?
                #
                if ( defined($aria_owns_tag{$aid}) ) {
                    $tag_object = $aria_owns_tag{$aid};
                    Record_Result("WCAG_2.0-F77", $line, $column,
                                  $text, String_Value("Duplicate id") .
                                  "'<$tag aria-owns=\"$aid\">' " .
                                  String_Value("Previous instance found at") .
                                  $tag_object->line_no() . ":" . $tag_object->column_no() .
                                  " <" . $tag_object->tag() . " aria-owns=\"$aid\">");
                }
                else {
                    #
                    # Record tag of aria-owns reference
                    #
                    $aria_owns_tag{$aria_owns} = $current_tag_object;
                }
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
    Check_Rel_Attribute("link", $line, $column, $text, 0, %attr);
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
#   This function handles main tags. It checks if the element is hidden
# and if not, that it is the only main landmark. It also checks that
# the main landmark does not have an illegal ancestor.
#
#***********************************************************************
sub Main_Tag_Handler {
    my ($line, $column, $text, %attr) = @_;
    
    my ($last_main, $last_line, $last_column, $tag, $first_tag, $n, $tag);

    #
    # Is there a hidden attribute on this tag? If so we don't consider
    # it a main content.
    #
    if ( defined($attr{"hidden"}) ) {
        print "Hidden <main>, don't check for duplicate main sections\n" if $debug;
    }
    else {
        #
        # Is this landmark a top level landmark (i.e. not contained within
        # any other landmark)?  Check that the landmark of the parent
        # tag is blank.
        #
        $n = @tag_order_stack;
        if ( $n > 1 ) {
           $tag = $tag_order_stack[$n - 2];
        }
        else {
            undef($tag);
        }
        if ( defined($tag) &&
            (($tag->landmark() ne "") && ($tag->landmark() ne "body")) ) {
            #
            # Main landmark contained within another landmark
            #
            print "Non blank landmark " . $tag->landmark() .
                  " on parent tag " . $tag->tag() . "\n" if $debug;
            Record_Result("WCAG_2.0-SC1.3.1",
                          $line, $column, $text,
                          String_Value("Main landmark nested in") .
                          " \"" . $tag->landmark() . "\"");
        }

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
            
            #
            # Does this main have an invalid ancestor?
            #
            print "Check for illegal ancestor element\n" if $debug;
            $first_tag = 1;
            foreach $tag (reverse @tag_order_stack) {
                #
                # Skip the current tag as it may be a <section> with role=main
                # so is not really an ancestor tag.
                #
                if ( $first_tag ) {
                    $first_tag = 0;
                    next;
                }
                
                #
                # Is this an invalid ancestor tag?
                #
                if ( defined($invalid_main_ancestors{$tag->tag}) ) {
                    print "Illegal ancestor ancestor " . $tag->tag . " found\n" if $debug;
                    Record_Result("WCAG_2.0-SC1.3.1", $line, $column, $text,
                                  String_Value("Main landmark must not be nested in") .
                                  " <" . $tag->tag . ">");
                    last;
                }
            }
        }
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
    $last_img_title = "";
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
        # Is the href a JavaScript function?
        #
#        if ( $href =~ /^javascript:/i ) {
#            Record_Result("AXE-Href_no_hash", $line, $column,
#                          $text, String_Value("Link href contains JavaScript"));
#        }

        #
        # Does the href end in a # symbol (i.e. no anchor name provided)?
        #
#        if ( $href =~ /#$/i ) {
#            Record_Result("AXE-Href_no_hash", $line, $column,
#                          $text, String_Value("Link href ends with #"));
#        }

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
    # Do we have an onclick attribute that activates the line?
    #
#    if ( defined($attr{"onclick"}) &&
#         ($attr{"onclick"} =~ /window\.location\.href/i) ) {
#        Record_Result("AXE-Href_no_hash", $line, $column,
#                      $text, String_Value("Link contains onclick"));
#    }

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

    my ($level, $aria_level);

    #
    # Get heading level number from the tag
    #
    $level = $tagname;
    $level =~ s/^h//g;
    print "Found heading $tagname\n" if $debug;
    $total_heading_count++;
    
    #
    # Is this an h1?
    #
    if ( $level == 1 ) {
        $found_h1 = 1;
    }
    
    #
    # Do we have an aria-level attribute?
    #
    if ( defined($attr{"aria-level"}) ) {
        #
        # Does the aria-level match the heading level?
        #
        $aria_level = $attr{"aria-level"};
        if ( $aria_level != $level ) {
            Record_Result("WCAG_2.0-SC4.1.2", $line, $column, $text,
                          String_Value("Heading level, aria-level mismatch") .
                          " <$tagname aria-level=\"$aria_level\">");
        }

        #
        # Is this a level 1 heading?
        #
        if ( $aria_level == 1 ) {
            $found_h1 = 1;
        }
    }
    
    #
    # Is this a heading hidden from assistive technology?
    #
#    if ( defined($attr{"aria-hidden"}) && ($attr{"aria-hidden"} eq "true") ) {
#        Record_Result("AXE-Empty_heading", $line, $column,
#                      $text, String_Value("Content hidden from assistive technology"));
#    }

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
    # Check that the heading level only increments by 1
    #
#    if ( defined($current_heading_level) && ($current_heading_level < $level) &&
#         ($level != ($current_heading_level + 1) ) ) {
#        Record_Result("AXE-Heading_order", $line, $column, $text,
#                      String_Value("Heading level increased by more than one, expected") .
#                      " <h" . ($current_heading_level + 1) . ">");
#    }

    #
    # Save new heading level
    #
    if ( defined($current_heading_level) ) {
        push(@heading_level_stack, $current_heading_level);
    }
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
    my ($h_count, $last_h);

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
            Record_Result("WCAG_2.0-F43,WCAG_2.0-G130", $line, $column,
                          $text, String_Value("Missing text in") . "<h$current_heading_level>");
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
    # While this heading's level is lower than the previous
    # heading, walk up the heading stack to get to the logical
    # parent heading.
    #
    $h_count = scalar(@heading_level_stack);
    while ( ($h_count > 0) &&
            ($current_heading_level <= $heading_level_stack[($h_count - 1)]) ) {
        print "Remove heading level " . $heading_level_stack[($h_count - 1)] .
              " from heading stack\n" if $debug;
        pop(@heading_level_stack);
        $h_count = scalar(@heading_level_stack);
    }

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
    my ($clean_text);

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
        Record_Result("WCAG_2.0-H27,WCAG_2.0-H53", $line, $column, $text,
                      String_Value("Missing text in") . "<object>");
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
    Check_For_Alt_or_Text_Alternative_Content("WCAG_2.0-H35", "<applet>", $line,
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
# Name: End_Button_Role_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function checks the close tag with role="button". It checks
# for content or some other accessible name.
#
#***********************************************************************
sub End_Button_Role_Handler {
    my ($self, $tagname, $line, $column, $text) = @_;

    my ($this_text, $last_line, $last_column, $clean_text, $start_tag_attr);
    my ($complete_label);

    #
    # Get start tag attributes
    #
    $start_tag_attr = $current_tag_object->attr();

    #
    # Get all the text found within the button plus any title attribute
    #
    if ( ! $have_text_handler ) {
        print "End <$tagname role=button> found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get the button text as a string, remove excess white space
    #
    $clean_text = Clean_Text(Get_Text_Handler_Content($self, " "));
    print "End_Button_Role_Handler text = \"$clean_text\"\n" if $debug;

    #
    # Check for using white space characters to control spacing within a word
    #
    Check_Character_Spacing("<$tagname>", $line, $column, $clean_text);

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
        print "Found text in <$tagname role=button> H91\n" if $debug;
    }
    #
    # Is tag visible ?
    #
    elsif ( $tag_is_visible ) {
        Record_Result("WCAG_2.0-H91,ACT-Button_non_empty_accessible_name", $line, $column,
                      $text, String_Value("Missing text in") . "<$tagname role=\"button\">");
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
    my ($self, $line, $column, $text) = @_;

    my ($explicit_role);

    #
    # Does the start button tag have an explicit role that changes its
    # behaviour? Don't consider roles none or presentation as
    # role changes.
    #
    if ( defined($current_tag_object) ) {
        $explicit_role = $current_tag_object->explicit_role();
    }
    if ( defined($explicit_role) && ($explicit_role ne "") &&
         ($explicit_role ne "none") && ($explicit_role ne "presentation") ) {
    }
    else {
        #
        # Check button role
        #
        End_Button_Role_Handler($self, "button", $line, $column, $text);
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
                Record_Result("WCAG_2.0-H39,WCAG_2.0-H73",
                              $line, $column, $text,
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
    $video_in_figure_with_no_caption = 0;
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
        #  Reference: https://www.w3.org/TR/html5/semantics-embedded-content.html
        #
        # If the image is a descendant of a figure element that has a child
        # figcaption element, and, ignoring the figcaption element and its
        # descendants, the figure element has no Text node descendants other
        # than inter-element white space, and no embedded content descendant
        # other than the img element, then the contents of the first such
        # figcaption element are the caption information.
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
    # Did we find video in this figure that did not have captions?
    #
    if ( $video_in_figure_with_no_caption ) {
        #
        # Was there a figcaption? The figcaption can act as the caption
        # text for the video.
        #
        if ( ($tag_is_visible ) && (! $have_figcaption) ) {
            #
            # No figcaption and captions for video.
            #
            Record_Result("WCAG_2.0-G87", $line, $column, $text,
                          String_Value("No captions found for") . " <video>");
        }
    }

    #
    # End of figure tag
    #
    $in_figure = 0;
    $video_in_figure_with_no_caption = 0;
    $image_in_figure_with_no_alt = 0;
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
# Name: Check_For_Ancestor_Tag
#
# Parameters: tag - name of a tag
#
# Description:
#
#   This function walks up the tag stack to see is a specific
# tag is found.
#
#***********************************************************************
sub Check_For_Ancestor_Tag {
    my ($tag) = @_;

    my ($tag_item, $found_tag);

    #
    # Go up the tag stack to see if we find the specified tag
    #
    print "Check_For_Ancestor_Tag $tag\n" if $debug;
    $found_tag = 0;
    foreach $tag_item (reverse @tag_order_stack) {
        if ( $tag_item->tag eq $tag ) {
            print "Found ancestor tag\n" if $debug;
            $found_tag = 1;
            last;
        }
    }

    #
    # Return status
    #
    return($found_tag);
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
    # Are we inside the <head> section?
    #
    print "Start_Title_Tag_Handler\n" if $debug;
    if ( $in_head_tag ) {
        #
        # We found the page title tag.
        #
        $found_title_tag = 1;
    }
    else {
        #
        # Are we inside an <svg> tag? It is allowed to have a <title> also
        #
        if ( Check_For_Ancestor_Tag("svg") ) {
            print "Title in svg tag\n" if $debug;
        }
        #
        # Are we inside the <body> tag?
        #
        elsif ( Check_For_Ancestor_Tag("body") ) {
            print "Title in body tag\n" if $debug;
            $found_title_tag_in_body = 1;
        }
        #
        # Invlaid title tag
        #
        else {
            Tag_Not_Allowed_Here("title", $line, $column, $text);
        }
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
# Name: Is_Presentation_Tag
#
# Parameters: None
#
# Description:
#
#   This function checks to see if the current tag is a presentation
# tag. It checks for a role attribute with value presentation or
# separator.
#
#***********************************************************************
sub Is_Presentation_Tag {
    my ($attr, $role);
    my ($is_presentation) = 0;
    
    #
    # Get the attributes from the current tag
    #
    if ( defined($current_tag_object) ) {
        $attr = $current_tag_object->attr();
        
        #
        # Do we have a role attribute?
        #
        if ( defined($$attr{"role"}) ) {
            $role = $$attr{"role"};
            print "Is_Presentation_Tag, role=$role\n" if $debug;
            
            #
            # Does the role contain "presentation" or "none" or "separator"?
            #
            if ( $role =~ /presentation/ ) {
                $is_presentation = 1;
                print "Tag contains role=presentation\n" if $debug;
            }
            #
            # Does the role contain "none"?
            #
            elsif ( $role =~ /none/ ) {
                $is_presentation = 1;
                print "Tag contains role=none\n" if $debug;
            }
            #
            # Does the role contain "separator"?
            #
            elsif ( $role =~ /separator/ ) {
                $is_presentation = 1;
                print "Tag contains role=separator\n" if $debug;
            }
        }
    }
    
    #
    # Return presentation indicator
    #
    return($is_presentation);
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
    if ( $tag_is_visible && ($clean_text eq "") &&
         ( ! Is_Presentation_Tag())) {
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

    #
    # Is the parent tag for this an ol or ul tag?
    #
    if ( ($parent_tag ne "ol") && ($parent_tag ne "ul") ) {
        Record_Result("WCAG_2.0-SC1.3.1", $line, $column, $text,
                      String_Value("Tag") . " <li> " .
                      String_Value("must be contained by") . " <ol> " .
                      String_Value("or") . " <ul>");
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
    if ( $tag_is_visible && ($clean_text eq "") &&
         ( ! Is_Presentation_Tag()) ) {
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
    
    my ($last_item, $tag_item, $found_dl);

    #
    # Set flag to indicate we are inside a dd tag
    #
    if ( $current_list_level > -1 ) {
        $inside_dd[$current_list_level] = 1;
        print "Start new dd, level $current_list_level\n" if $debug;
        
        #
        # Do we have a <dt> tag that preceeds this <dd>?
        #
        if ( $dt_tag_found[$current_list_level] ) {
            #
            # Have a <dt>, resent found flag to false for
            # next possible <dt>, <dd> pair.
            #
            $dt_tag_found[$current_list_level] = 0;
        }
        else {
            #
            # No <dt> tag before this <dd>
            #
            Record_Result("WCAG_2.0-SC1.3.1", $line, $column, $text,
                          String_Value("Missing dt tag before dd tag"));
        }
    }
    else {
        #
        # Not in a list
        #
        Tag_Not_Allowed_Here("dd", $line, $column, $text);
    }

    #
    # Is there an ancestor dl tag for this tag? This tag must be
    # contained within a dl or a div, which is contained in a dl.
    # Start at parent tag (2nd last tag item)
    #
    print "Dt_Tag_Handler check for parent div or dl tag\n" if $debug;
    $last_item = @tag_order_stack - 2;
    $found_dl = 0;
    if ( $last_item >= 0 ) {
        #
        # Walk up the tag stack to find a dl tag parent
        #
        while ( (! $found_dl) && ($last_item >= 0) ) {
            #
            # Did we find a dl tag? If so, stop looking
            #
            $tag_item = $tag_order_stack[$last_item];
            if ( $tag_item->tag() eq "dl" ) {
                $found_dl = 1;
                last;
            }
            #
            # Did we find a div? A div may be used to wrap the dd or the
            # dt, dd pair.
            #
            elsif ( $tag_item->tag() eq "div" ) {
                print "Found div as parent of this tag\n" if $debug;
            }
            #
            # Unexpected parent tag. Stop search
            #
            else {
                print "Unexpected tag " . $tag_item->tag() . " as ancestor to <dd>\n" if $debug;
                last;
            }

            $last_item = $last_item - 1;
        }
    }

    #
    # Is there an ancestor dl tag for this tag? This tag must be
    # contained within a dl or a div, which is contained in a dl.
    #
    if ( ! $found_dl ) {
        Record_Result("WCAG_2.0-SC1.3.1", $line, $column, $text,
                      String_Value("Tag") . " <dd> " .
                      String_Value("must be contained by") . " <dl> " .
                      String_Value("or") . " <dl> <div>");
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
    
    my ($last_item, $tag_item, $found_dl);

    #
    # Increment count of <dt> tags in this list
    #
    if ( $current_list_level > -1 ) {
        $list_item_count[$current_list_level]++;
        
        #
        # Do we have a <dt> tag that preceeds this <dt>
        # (i.e. we are missing a <dd> tag)?
        #
        if ( $dt_tag_found[$current_list_level] ) {
            #
            # No <dd> tag between this <dt> and the previous <dt>
            #
            Record_Result("WCAG_2.0-SC1.3.1", $line, $column, $text,
                          String_Value("Missing dd tag between previous dt tag and this dt tag"));
        }
        
        #
        # Set flag to indicate we have a <dt> tag
        #
        $dt_tag_found[$current_list_level] = 1;
    }
    else {
        #
        # Not in a list
        #
        Tag_Not_Allowed_Here("dt", $line, $column, $text);
    }

    #
    # Is there an ancestor dl tag for this tag? This tag must be
    # contained within a dl or a div, which is contained in a dl.
    # Start at parent tag (2nd last tag item)
    #
    print "Dt_Tag_Handler check for parent div or dl tag\n" if $debug;
    $last_item = @tag_order_stack - 2;
    $found_dl = 0;
    if ( $last_item >= 0 ) {
        #
        # Walk up the tag stack to find a dl tag parent
        #
        while ( (! $found_dl) && ($last_item >= 0) ) {
            #
            # Did we find a dl tag? If so, stop looking
            #
            $tag_item = $tag_order_stack[$last_item];
            if ( $tag_item->tag() eq "dl" ) {
                $found_dl = 1;
                last;
            }
            #
            # Did we find a div? A div may be used to wrap the dt or the
            # dt, dd pair.
            #
            elsif ( $tag_item->tag() eq "div" ) {
                print "Found div as parent of this tag\n" if $debug;
            }
            #
            # Unexpected parent tag. Stop search
            #
            else {
                print "Unexpected tag " . $tag_item->tag() . " as ancestor to <dt>\n" if $debug;
                last;
            }

            $last_item = $last_item - 1;
        }
    }

    #
    # Is there an ancestor dl tag for this tag? This tag must be
    # contained within a dl or a div, which is contained in a dl.
    #
    if ( ! $found_dl ) {
        Record_Result("WCAG_2.0-SC1.3.1", $line, $column, $text,
                      String_Value("Tag") . " <dt> " .
                      String_Value("must be contained by") . " <dl> " .
                      String_Value("or") . " <dl> <div>");
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
    if ( $tag_is_visible && ($clean_text eq "") &&
         ( ! Is_Presentation_Tag()) ) {
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
    $dt_tag_found[$current_list_level] = 0;
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
        # Do we have a <dt> tag that preceeds this </dl>
        # (i.e. we are missing a <dd> tag)?
        #
        if ( $dt_tag_found[$current_list_level] ) {
            #
            # No <dd> tag after last <dt> in the list.
            #
            Record_Result("WCAG_2.0-SC1.3.1", $line, $column, $text,
                          String_Value("Missing dd tag after last dt tag in definition list"));
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
            Record_Result("WCAG_2.0-F77,ACT-id_attribute_value_unique", $line, $column,
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

    my ($attribute, $this_attribute, %attribute_list);

    #
    # Check for duplicate attributes
    #
    print "Check_Duplicate_Attributes\n" if $debug;
    if ( defined($$current_tqa_check_profile{"WCAG_2.0-H94"}) ||
         defined($$current_tqa_check_profile{"ACT-Attribute_is_not_duplicate"}) ) {
        #
        # Check each attribute in the list
        #
        foreach $attribute (@$attrseq) {
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
            if ( defined($attribute_list{$attribute}) ) {
                #
                # Have a duplicate attribute
                #
                Record_Result("WCAG_2.0-H94,ACT-Attribute_is_not_duplicate", $line, $column,
                              $text, String_Value("Duplicate attribute") .
                              "'$attribute'" .
                              String_Value("for tag") .
                              "<$tagname>");
                last;
            }
            $attribute_list{$attribute} = $attribute;
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

    my ($lang, $xml_lang, $lang_attr_value);

    #
    # Do we have a lang attribute ?
    #
    print "Check_Lang_Attribute\n" if $debug;
    if ( defined($attr{"lang"}) ) {
        $lang = lc($attr{"lang"});
        $lang_attr_value = $lang;
        $lang =~ s/-.*$//g;

        #
        # Are we checking the ACT ruleset?
        #
        if ( defined($$current_tqa_check_profile{"ACT-Lang_has_valid_language"}) ) {
            #
            # Check the language portion and ignore any dialect
            #
            if ( ! Language_Valid($lang) ) {
                Record_Result("ACT-Lang_has_valid_language",
                              $line, $column, $text,
                              String_Value("Invalid language attribute value") .
                              " lang=\"$lang_attr_value\"");
            }
        }
        #
        # Check full language attribute
        #
        elsif ( ! Language_Valid($lang) ) {
            Record_Result("WCAG_2.0-H58", $line, $column, $text,
                          String_Value("Invalid language attribute value") .
                          " lang=\"$lang_attr_value\"");
        }
    }

    #
    # Do we have a xml:lang attribute ?
    #
    if ( defined($attr{"xml:lang"}) ) {
        $xml_lang = lc($attr{"xml:lang"});
        $lang_attr_value = $xml_lang;
        $xml_lang =~ s/-.*$//g;

        #
        # Are we checking the ACT ruleset?
        #
        if ( defined($$current_tqa_check_profile{"ACT-Lang_has_valid_language"}) ) {
            #
            # Check the language portion and ignore any dialect
            #
            if ( ! Language_Valid($lang) ) {
                Record_Result("ACT-Lang_has_valid_language",
                              $line, $column, $text,
                              String_Value("Invalid language attribute value") .
                              " xml:lang=\"$lang_attr_value\"");
            }
        }
        #
        # Check full language attribute
        #
        elsif ( ! Language_Valid($xml_lang) ) {
            Record_Result("WCAG_2.0-H58", $line, $column, $text,
                          String_Value("Invalid language attribute value") .
                          " xml:lang=\"$lang_attr_value\"");
        }
    }

    #
    # Is this an XHTML 1.0 document ? Check the any lang and xml:lang
    # attributes match.  Don't do this check for the <html> tag, that
    # has already been handled in the HTML_Tag function.
    #
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
    
    #
    # Get final language value
    #
    if ( defined($xml_lang) ) {
        $lang = $xml_lang;
    }
    if ( defined($lang) ) {
        $lang =~ s/\-.*//g;
        $lang = lc($lang);
        
        #
        # Convert language code into a 3 character code.
        #
        $lang = ISO_639_2_Language_Code($lang);
        print "Found language $lang\n" if $debug;

        #
        # Is this a right to left language?
        #
        if ( defined($right_to_left_languages{$lang}) ) {
            #
            # Do we have a dir attribute to specify the direction of the
            # language (right to left)?
            #
            if ( ! defined($attr{"dir"}) ) {
                Record_Result("WCAG_2.0-H58", $line, $column, $text,
                              String_Value("Missing dir attribute for right to left language") .
                              " lang=\"$lang\"");
            }
            #
            # Is the direction right to left?
            #
            elsif ( $attr{"dir"} ne "rtl" ) {
                Record_Result("WCAG_2.0-H58", $line, $column, $text,
                              String_Value("Invalid direction for right to left language") .
                              " lang=\"$lang\" dir=\"" . $attr{"dir"} . "\"");
            }
        }
        #
        # Must be a left to right language, is the direction set correctly?
        #
        elsif ( defined($attr{"dir"}) && ($attr{"dir"} ne "ltr") ) {
                Record_Result("WCAG_2.0-H58", $line, $column, $text,
                              String_Value("Invalid direction for left to right language") .
                              " lang=\"$lang\" dir=\"" . $attr{"dir"} . "\"");
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
    # Check for an aria-expanded attribute
    #
    if ( defined($attr{"aria-expanded"}) && ($attr{"aria-expanded"} eq "false") ) {
        #
        # Set global tag hidden and tag visibility flag
        #
        print "Found attribute 'aria-expanded=\"false\"' on tag\n" if $debug;
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
        $tag_is_aria_hidden = 1;
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
    $current_tag_object->is_aria_hidden($tag_is_aria_hidden);

    #
    # Set global variable for styles associated to the current tag.
    #
    $current_tag_styles = $style_names;
    print "Current tag_is_visible = $tag_is_visible, tag_is_hidden = $tag_is_hidden, tag_is_aria_hidden = $tag_is_aria_hidden for tag $tagname\n" if $debug;
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
# Name: Check_Autocomplete_Control_Group
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             token - autocomplete token
#             control_group - control group for autocomplete token
#             attr - hash table of attributes
#
# Description:
#
#   This function checks the autocomplete term control group to ensure
# that the tag type is appropriate for the autocomplete term value.
#
#***********************************************************************
sub Check_Autocomplete_Control_Group {
    my ($tagname, $line, $column, $text, $token, $control_group, %attr) = @_;

    my ($control_tag, $control_attr, $control_value);
    my ($control_group_details, $control, $match_control);

    #
    # Check that the term is valid for the control grouping.
    #
    print "Check control group $control_group for autocomplete type\n" if $debug;
    if ( defined($autocomplete_control_group_details{$control_group}) ) {
        $control_group_details = $autocomplete_control_group_details{$control_group};
        print "Control group details $control_group_details\n" if $debug;

        #
        # Check each detail item (space separated)
        #
        $match_control = 0;
        foreach $control (split(/\s+/, $control_group_details)) {
            ($control_tag, $control_attr, $control_value) =
                split(/:/, $control);

            #
            # We may not have a control attribute or value
            #
            if ( ! defined($control_attr) ) {
                $control_attr = "";
            }
            if ( ! defined($control_value) ) {
                $control_value = "";
            }

            #
            # Does the control group tag match the current tag?
            #
            print "Check control $control_tag, $control_attr=$control_value\n" if $debug;
            if ( $tagname eq $control_tag ) {
                #
                # Do we have a control attribute?
                #
                if ( $control_attr eq "" ) {
                    #
                    # No attribute condition, found match for
                    # control.
                    #
                    print "Matching tag control with no attribute condition\n" if $debug;
                    $match_control = 1;
                    last;
                }
                #
                # Does this tag have an attribute matching the control condition?
                # Allow for a missing attribute of type.
                #
                elsif ( defined($attr{"$control_attr"}) ) {
                    #
                    # Do we have a control attribute value?
                    #
                    if ( $control_value eq "" ) {
                        #
                        # No attribute value condition, found match for
                        # control.
                        #
                        print "Matching tag control and attribute, with no value condition\n" if $debug;
                        $match_control = 1;
                        last;
                    }
                    # Does the attribute value match the control condition?
                    #
                    elsif ( $attr{"$control_attr"} eq $control_value ) {
                        print "Matching tag control, attribute and value condition\n" if $debug;
                        $match_control = 1;
                        last;
                    }
                }
                #
                # Is the control attribute "type"? If the tag does not have
                # a "type" attribute it defaults to text. Is the control
                # value "text"?
                #
                elsif ( ($control_attr eq "type") &&
                        (! defined($attr{"$control_attr"})) &&
                        ($control_value eq "text") ) {
                     print "No type attribute on tag, default value \"text\" matches control attribute value\n" if $debug;
                    $match_control = 1;
                    last;
                }
            }
        }

        #
        # Did we find a match for the control group conditions?
        #
        if ( ! $match_control ) {
            Record_Result("WCAG_2.1-SC1.3.5,ACT-Autocomplete_valid_value", $line, $column, $text,
                          String_Value("Invalid autocomplete term token") . " \"$token\".\n " .
                          String_Value("Did not match any control group conditions"));
        }
    }
}

#***********************************************************************
#
# Name: Check_Autocomplete_Attribute
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks the autocomplete attribute.  It checks to see if
# the value is valid for the tag and role.
#
#***********************************************************************
sub Check_Autocomplete_Attribute {
    my ($tagname, $line, $column, $text, %attr) = @_;

    my ($autocomplete, $type, $token, $complete_term);
    my ($section_token, $contact_info_token, $phone_type_token);
    my ($control_group);
    
    #
    # Is this tag input, select or textarea?
    #
    if ( ($tagname eq "input") || ($tagname eq "select") ||
         ($tagname eq "textarea") ) {

        #
        # Get type attribute of input, if there is one.
        #
        print "Check_Autocomplete_Attribute\n" if $debug;
        if ( $tagname eq "input" ) {
            if ( defined($attr{"type"}) ) {
                $type = $attr{"type"};
            }
            else {
                #
                # Default type for input
                #
                $type = "text";
            }
        }

        #
        # Get any autocomplete attribute value
        #
        if ( defined($attr{"autocomplete"}) ) {
            $autocomplete = lc($attr{"autocomplete"});
        }

        #
        # Is the tag hidden?
        #
        if ( $tag_is_hidden ) {
            print "Hidden tag\n" if $debug;
        }
        #
        # Is tag input with type hidden, button, submit or reset?
        #
        elsif ( ($tagname eq "input") && defined($type) &&
                ( ($type eq "hidden") || ($type eq "button") ||
                  ($type eq "submit") || ($type eq "reset") ) ) {
            print "Input type = $type\n" if $debug;
        }
        #
        # Is the tag disabled?
        #
        elsif ( defined($attr{"aria-disabled"}) && ($attr{"aria-disabled"} ne "false") ) {
            print "Tag has aria-disabled\n" if $debug;
        }
        #
        # Is the tag not focusable?
        #
        elsif ( defined($attr{"tabindex"}) && ($attr{"tabindex"} < 0) ) {
            print "Tag not focusable, tabindex < 0\n" if $debug;
        }
        #
        # Check for comma or semi-colon separator in autocomplete value.
        #
        elsif ( defined($autocomplete) && ($autocomplete =~ /.*[,;].*/) ) {
            Record_Result("WCAG_2.1-SC1.3.5,ACT-Autocomplete_valid_value", $line, $column, $text,
                          String_Value("Invalid list separator, expecting space character") .
                          String_Value("in tag") . "'<$tagname autocomplete=\"$autocomplete\">'");
        }
        #
        # Do we have an autocomplete value?
        #
        elsif ( defined($autocomplete) && ($autocomplete ne "") ) {
            print "Check for autocomplete on $tagname\n" if $debug;
            #
            # Check each token in the list
            #
            $complete_term = 1;
            $section_token = "";
            $contact_info_token = "";
            $phone_type_token = "";
            foreach $token (split(/\s+/, $autocomplete)) {
                #
                # Do we have a section- group token?
                #
                if ( $token =~ /^section\-/ ) {
                    #
                    # This should be the first token of a new term
                    #
                    if ( ! $complete_term ) {
                        Record_Result("WCAG_2.1-SC1.3.5,ACT-Autocomplete_valid_value", $line, $column, $text,
                                      String_Value("Invalid autocomplete term token") . " \"$token\".\n " .
                                      String_Value("Section grouping must be first token in term"));
                        $complete_term = 1;
                        $section_token = "";
                        $contact_info_token = "";
                        $phone_type_token = "";
                    }
                    else {
                        #
                        # Beginning of a new term
                        #
                        print "Section grouping $token\n" if $debug;
                        $complete_term = 0;
                        $section_token = "$token ";
                    }
                }
                #
                # Do we have a contact information type field
                #
                elsif ( defined($autocomplete_valid_contact_info_field_names{$token}) ) {
                    #
                    # Do we already have a contact information type field?
                    #
                    if ( $contact_info_token ne "" ) {
                        Record_Result("WCAG_2.1-SC1.3.5,ACT-Autocomplete_valid_value", $line, $column, $text,
                                      String_Value("Invalid autocomplete term token") . " \"$token\".\n " .
                                      String_Value("Only 1 contact information type token allowed"));
                        $complete_term = 1;
                        $section_token = "";
                        $contact_info_token = "";
                        $phone_type_token = "";
                    }
                    #
                    # Do we have a phone type token?
                    #
                    elsif ( $phone_type_token ne "" ) {
                        Record_Result("WCAG_2.1-SC1.3.5,ACT-Autocomplete_valid_value", $line, $column, $text,
                                      String_Value("Invalid autocomplete term token") . " \"$token\".\n " .
                                      String_Value("Contact information type token must precede phone type token"));
                        $complete_term = 1;
                        $section_token = "";
                        $contact_info_token = "";
                        $phone_type_token = "";
                    }
                    else {
                        #
                        # Possible beginning of a new term
                        #
                        print "Contact information type field $token\n" if $debug;
                        $complete_term = 0;
                        $contact_info_token = "$token ";
                    }
                }
                #
                # Do we have a autofill field name?
                #
                elsif ( defined($autocomplete_valid_field_names{$token}) ) {
                    #
                    # End of a complete term
                    #
                    print "Valid autocomplete field name $token\n" if $debug;

                    #
                    # Check for telephone type token, these valid fields
                    # cannot be prefixed by a telephone type.
                    #
                    if ( $phone_type_token ne "" ) {
                        Record_Result("WCAG_2.1-SC1.3.5,ACT-Autocomplete_valid_value", $line, $column, $text,
                                      String_Value("Invalid autocomplete term token") . " \"$phone_type_token\" " .
                                      String_Value("cannot be used before token") . " \"$token\"");
                    }
                    else {
                        #
                        # Check that the term is valid for the control grouping.
                        #
                        $control_group = $autocomplete_valid_field_names{$token};
                        Check_Autocomplete_Control_Group($tagname, $line,
                                 $column, $text, $token, $control_group, %attr);

                        #
                        # End of a complete term
                        #
                        print "End of complete term \"$section_token$contact_info_token$token\"\n" if $debug;
                    }
                    $complete_term = 1;
                    $section_token = "";
                    $contact_info_token = "";
                    $phone_type_token = "";
                }
                #
                # Do we have a telephone type prefix field
                #
                elsif ( defined($autocomplete_valid_telephone_prefix_field_names{$token}) ) {
                    #
                    # Do we already have a phone type token?
                    #
                    if ( $phone_type_token ne "" ) {
                        Record_Result("WCAG_2.1-SC1.3.5,ACT-Autocomplete_valid_value", $line, $column, $text,
                                      String_Value("Invalid autocomplete term token") . " \"$token\".\n " .
                                      String_Value("Contact information type token must precede phone type token"));
                        $complete_term = 1;
                        $section_token = "";
                        $contact_info_token = "";
                        $phone_type_token = "";
                    }
                    else {
                        #
                        # Possible beginning of a new term
                        #
                        print "Telephone type prefix field $token\n" if $debug;
                        $complete_term = 0;
                        $phone_type_token = "$token ";
                    }
                }
                #
                # Do we have a telephone type field
                #
                elsif ( defined($autocomplete_valid_telephone_field_names{$token}) ) {
                    #
                    # Check that the term is valid for the control grouping.
                    #
                    print "Valid autocomplete telephone type field name $token\n" if $debug;
                    $control_group = $autocomplete_valid_telephone_field_names{$token};
                    Check_Autocomplete_Control_Group($tagname, $line, $column,
                              $text, $token, $control_group, %attr);

                    #
                    # End of a complete term
                    #
                    print "End of complete term \"$section_token$contact_info_token$phone_type_token$token\"\n" if $debug;
                    $complete_term = 1;
                    $section_token = "";
                    $contact_info_token = "";
                    $phone_type_token = "";
                }
                #
                # Unknown autocomplete token
                #
                else {
                    Record_Result("WCAG_2.1-SC1.3.5,ACT-Autocomplete_valid_value", $line, $column, $text,
                                  String_Value("Invalid autocomplete term token"));
                    $complete_term = 1;
                    $section_token = "";
                    $contact_info_token = "";
                    $phone_type_token = "";
                }
            }
            
            #
            # Did the last token complete an autocomplete term?
            #
            if ( ! $complete_term ) {
                Record_Result("WCAG_2.1-SC1.3.5,ACT-Autocomplete_valid_value", $line, $column, $text,
                              String_Value("Incomplete autocomplete term") .
                              " \"$section_token$contact_info_token$phone_type_token\"");
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Role_Context
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
sub Check_Role_Context {
    my ($tagname, $role_list) = @_;

    my ($context_role, $tag, $found_role, $invalid_parent_role, $tag_role);
    my ($found_required_context_role, $implicit_roles, $explicit_role);
    my ($tag_number);

    #
    # Step up the tag stack looking for a tag with an appropriate
    # role value
    #
    print "Check_Role_Context: Check for roles $role_list\n" if $debug;
    $found_required_context_role = 0;
    $found_role = "";
    $tag_number = 0;
    foreach $tag (reverse @tag_order_stack) {
        #
        # Increment tag counter
        #
        $tag_number++;
        
        #
        # Skip the first tag in the list, it is the current tag
        #
        if ( $tag_number == 1 ) {
            next;
        }

        #
        # Check for an explicit role on the tag item
        #
        $explicit_role = $tag->explicit_role();
        print "Check role value in tag $tag_number # " . $tag->tag() .
              " at " . $tag->line_no() . ":" . $tag->column_no() . "\n" if $debug;
        if ( defined($explicit_role) && ($explicit_role ne "") ) {
            #
            # Does the role match one of the required roles?
            #
            print "Tag's explicit role = $explicit_role\n" if $debug;
            foreach $context_role (split(/\s+/, $role_list)) {
                if ( $explicit_role eq $context_role ) {
                    print "Found required context role $context_role in tag\n" if $debug;
                    $found_required_context_role = 1;
                    $found_role = $context_role;
                    last;
                }
            }

            #
            # If we didn't find the required context role, does the
            # tag's explicit role expected any owned elements. If so
            # then this tag's role is the wrong container role.
            #
            if ( ! $found_required_context_role ) {
               if ( TQA_WAI_Aria_Required_Owned_Elements($explicit_role) ne "" ) {
                   print "Tag's role $explicit_role is parent for " .
                         TQA_WAI_Aria_Required_Owned_Elements($explicit_role) .
                         " roles, not $context_role role\n" if $debug;
                   #last;
               }
               else {
                   print "Tag's role does not have any required owned elements\n" if $debug;
               }
            }
        }

        #
        # Did we find a required context role value?
        #
        if ( $found_required_context_role ) {
            print "Found match for explicit role\n" if $debug;
            last;
        }

        #
        # Check the tag's implicit role list
        #
        $implicit_roles = $tag->implicit_role();
        print "Check tag's implicit roles \"$implicit_roles\"\n" if $debug;
        if ( defined($implicit_roles) && ($implicit_roles ne "") ) {
            #
            # Check all possible implicit roles
            #
            foreach $tag_role (split(/\s+/, $implicit_roles)) {
                #
                # Does the role match one of the required context roles?
                #
                print "Tag's implicit role = $tag_role\n" if $debug;
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
                    print "Found match for implicit role\n" if $debug;
                    last;
                }
            }

            #
            # Did we find the required context role value?
            #
            if ( $found_required_context_role ) {
                print "Exit tag loop\n" if $debug;
                last;
            }

            #
            # If this tag is an ancestor of the original tag, and
            # we didn't find the required context role, check to see if the
            # tag's implicit role expected owned elements. If so
            # then this tag's role is the wrong container role.
            #
            if ( ($tag_number > 0 ) && (! $found_required_context_role) ) {
                #
                # Check all possible implicit roles
                #
                print "Check tag's implicit roles $implicit_roles\n" if $debug;
                $invalid_parent_role = 0;
                foreach $tag_role (split(/\s+/, $implicit_roles)) {
                    #
                    # Does the role match one of the required owned elements?
                    #
                    if ( TQA_WAI_Aria_Required_Owned_Elements($tag_role) ne "" ) {
                        print "Tag's role $tag_role is parent for " .
                              TQA_WAI_Aria_Required_Owned_Elements($tag_role) .
                              " roles, not $context_role role\n" if $debug;
                       $invalid_parent_role = 1;
                       last;
                   }
                   else {
                       print "Tag's role does not have any required owned elements\n" if $debug;
                   }
                }
                
                #
                # Did we find an invalid parent role?
                #
                if ( $invalid_parent_role ) {
                    last;
                }
            }
        }
    }
    
    #
    # Return the matched role value
    #
    print "Found context role \"$found_role\"\n" if $debug;
    return($found_role);
}

#***********************************************************************
#
# Name: Check_Disallowed_Aria_Role_Value
#
# Parameters: tagname - tag name
#             role - role value
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks for disallowed ARIA role values.  The
# disallowed roles may be applicable only if other tag attributes
# or values are present.  The reference for the disallowed
# roles is
#    https://www.w3.org/TR/html-aria/#docconformance
#
#***********************************************************************
sub Check_Disallowed_Aria_Role_Value {
    my ($tagname, $role, $line, $column, $text, %attr) = @_;

    my ($context_role, $context_role_list, $value);
    my ($this_role, $role_list, @disallowed_roles, $context_attr);
    my ($check_role, @list_of_roles, $context_attr_value);

    #
    # Does this tag have disallowed roles?
    #
    print "Check_Disallowed_Aria_Role_Value for tag $tagname with role $role\n" if $debug;
    if ( defined($disallowed_aria_roles{$tagname}) ) {
        $role_list = $disallowed_aria_roles{$tagname};
        $check_role = 0;
        print "Have disallowed roles $role_list\n" if $debug;

        #
        # Get the string list in an array
        #
        @list_of_roles = split(/ /, $role_list);

        #
        # Check the first value in the array for a possible
        # attribute condition (indicated by a colon in the string) on
        # the disallowed role values.
        #
        $value = $list_of_roles[0];
        if ( defined($value) && (index($value, ":") != -1) ) {
            #
            # Get the attribute name and possible value
            #
            ($context_attr, $context_attr_value) = split(/:/, $value);
            print "Have context attribute \"$context_attr\"\n" if $debug;
            shift(@list_of_roles);
            if ( defined($attr{$context_attr}) ) {
                #
                # Have required condition attribute for disallowed
                # role values.  Check for possible attribute value.
                #
                print "Found attribute\n" if $debug;
                if ( defined($context_attr_value) && ($context_attr_value ne "") ) {
                    #
                    # Does the attribute's value match the one
                    # from the disallowed role entry?
                    #
                    print "Check attribute value \"" . $attr{$context_attr} . "\" againsts context value \"$context_attr_value\"\n" if $debug;
                    if ( $attr{$context_attr} eq $context_attr_value ) {
                        $check_role = 1;
                        print "Have role condition attribute and value match\n" if $debug;
                    }
                }
                else {
                    #
                    # No specific value required for the context attribute.
                    #
                    $check_role = 1;
                    print "Have role condition attribute\n" if $debug;
                }
            }
            else {
                print "Attribute not found\n" if $debug;
            }
        }
        else {
            #
            # No conditions on role value check
            #
            $check_role = 1;
        }

        #
        # Do we check the role value?
        #
    }
}

#***********************************************************************
#
# Name: Check_Only_Allowed_Aria_Role_Value
#
# Parameters: tagname - tag name
#             role - role value
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks if there is a limited set of allowed ARIA
# role values.  The allowed roles may be applicable only if other
# tag attributes or values are present.  The reference for the allowed
# roles is
#    https://www.w3.org/TR/html-aria/#docconformance
#
#***********************************************************************
sub Check_Only_Allowed_Aria_Role_Value {
    my ($tagname, $role, $line, $column, $text, %attr) = @_;

    my ($context_role, $context_role_list, $value);
    my ($this_role, $role_list, @disallowed_roles, $context_attr);
    my ($check_role, @list_of_roles, $context_attr_value);
    my ($found_role);

    #
    # Does this tag have a set of allowed roles?
    #
    print "Check_Only_Allowed_Aria_Role_Value for tag $tagname with role $role\n" if $debug;
    if ( defined($allowed_aria_roles{$tagname}) ) {
        $role_list = $allowed_aria_roles{$tagname};
        $check_role = 0;
        print "Have allowed roles $role_list\n" if $debug;

        #
        # Get the string list in an array
        #
        @list_of_roles = split(/ /, $role_list);

        #
        # Check the first value in the array for a possible
        # attribute condition (indicated by a colon in the string) on
        # the allowed role values.
        #
        $value = $list_of_roles[0];
        if ( defined($value) && (index($value, ":") != -1) ) {
            #
            # Get the attribute name and possible value
            #
            ($context_attr, $context_attr_value) = split(/:/, $context_attr);
            print "Have context attribute \"$context_attr\"\n" if $debug;
            shift(@list_of_roles);
            if ( defined($attr{$context_attr}) ) {
                #
                # Have required condition attribute for allowed
                # role values.  Check for possible attribute value.
                #
                if ( defined($context_attr_value) && ($context_attr_value ne "") ) {
                    #
                    # Does the attribute's value match the one
                    # from the allowed role entry?
                    #
                    if ( $attr{$context_attr} eq $context_attr_value ) {
                        $check_role = 1;
                        print "Have role condition attribute and value match\n" if $debug;
                    }
                }
                else {
                    #
                    # No specific value required for the context attribute.
                    #
                    $check_role = 1;
                    print "Have role condition attribute\n" if $debug;
                }
            }
        }
        else {
            #
            # No conditions on role value check
            #
            $check_role = 1;
        }

        #
        # Do we check the role value?
        #
        if ( $check_role ) {
            print "Check allowed roles $role_list\n" if $debug;

            #
            # Is the role list empty? That indicates that NO role is allowed
            # on this tag.
            #
            if ( scalar(@list_of_roles) == 0 ) {
#                Record_Result("AXE-Aria_allowed_role", $line, $column, $text,
#                              String_Value("Invalid ARIA role value") .
#                              " \"$role\"");
            }
            else {
                #
                # Check that the role is in the allowed list.
                #
                $found_role = 0;
                foreach $this_role (@list_of_roles) {
                    if ( $role eq $this_role ) {
                        #
                        # Found a match for the role
                        #
                        $found_role = 1;
                    }
                }

                #
                # If we did not find a match for the role in the allowed list,
                # then this role is invalid.
                #
                if ( ! $found_role ) {
#                    Record_Result("AXE-Aria_allowed_role", $line, $column, $text,
#                                  String_Value("Invalid ARIA role value") .
#                                  " \"$role\"");
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Support_of_Accessible_Name_from_Content
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function checks to see if the tag and/or it's role supports
# accessible name from content functionality.  This function does not
# check that the accessible name matches the content, just that the
# tag supports the feature.  The actual content/name check happens
# after the tag is closed and any referenced labels are found.
#
#***********************************************************************
sub Check_Support_of_Accessible_Name_from_Content {
    my ($tagname, $line, $column, $text) = @_;

    my ($role, $role_item, $is_name_content_role);

    #
    # Does the start tag for this end tag contain a role?
    #
    print "Check_Support_of_Accessible_Name_from_Content $tagname\n" if $debug;
    if ( defined($current_tag_object) ) {
        #
        # Check for explicit role attribute
        #
        $role = $current_tag_object->attr_value("role");

        #
        # If there is no explicit role, get the implicit role
        #
        if ( ! defined($role) ) {
            $role = $current_tag_object->implicit_role();
        }

        #
        # Did we get a role value?
        #
        if ( $role ne "" ) {
            #
            # Does this role support accessible name from content?
            #
            print "Tag has role(s) = $role\n" if $debug;
            $is_name_content_role = 0;
            foreach $role_item (split(/\s+/, $role)) {
                if ( defined($aria_accessible_name_content_match{$role}) ) {
                    print "Tag supports accessible name from content for role $role\n" if $debug;
                    $is_name_content_role = 1;
                    last;
                }
            }
            
            #
            # Did we find a role that supports accessible name from content?
            #
            if ( $is_name_content_role ) {
                $current_tag_object->accessible_name_content(1);
            }
        }
    }
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
# for
#   - allowed or disallowed roles
#   - roles are not applied to inappropriate tags
#   - roles that require additional attributes
#
#***********************************************************************
sub Check_Aria_Role_Attribute {
    my ($tagname, $line, $column, $text, %attr) = @_;

    my ($role, $last_main, $last_line, $last_column);
    my ($context_role, $context_role_list, $tag, $first_tag);
    my ($this_role, $n, $required_roles_parent, %roles_item);
    my ($text_alternative, $text_alternative_id, $invalid_alt);
    my ($classification, $attribute, $role_list);

    #
    # Check for possible role attribute
    #
    print "Check_Aria_Role_Attribute for tag $tagname\n" if $debug;
    if ( defined($attr{"role"}) ) {
        $role = $attr{"role"};
        $role =~ s/^\s*//g;
        $role =~ s/\s*//g;
        print "Role = $role\n" if $debug;
        
        
        #
        # Check for presentational roles conflict
        #
        if ( ($role eq "none") || ($role eq "presentation") ) {
            #
            # Check to see if tag is focusable
            #
            if ( defined($attr{"tabindex"}) && ($attr{"tabindex"} > -1 ) ) {
                print "Presentational roles conflict, $role and tabindex\n" if $debug;
                $role = "complementary";
            }
            #
            # Check for an interactive tag
            #
            elsif ( defined($interactive_tag {$tagname}) ) {
                #
                # Interactive tag retains it's implicit role.
                #
                $role = $current_tag_object->implicit_role();
            }
            else {
                #
                # Check for a ARIA global property attribute
                #
                foreach $attribute (keys(%attr)) {
                    if ( defined($global_aria_properties{$attribute}) ) {
                        $role = "complementary";
                        print "Presentational roles conflict, $role and attribute $attribute\n" if $debug;
                        last;
                    }
                }
            }
        }
        
        #
        # Check for disallowed roles
        #
        Check_Disallowed_Aria_Role_Value($tagname, $role, $line,
                                         $column, $text, %attr);

        #
        # Check for allowed roles only
        #
        Check_Only_Allowed_Aria_Role_Value($tagname, $role, $line,
                                           $column, $text, %attr);

        #
        # Look for the first valid non-abstract role
        #
        foreach $this_role (split(/\s+/, $role)) {
            #
            # Is this an EPUB role ?
            #
            $classification = TQA_WAI_Aria_Role_Classification($this_role);
            if ( $html_is_part_of_epub && ($classification ne "") ) {
                #
                # EPUB specific role.
                #
                print "EPUB specific role $this_role\n" if $debug;
            }
            #
            # Is this not an abstract role?
            #
            elsif ( $classification ne "abstract" ) {
                #
                # Use this role as the role for the tag.
                #
                $role = $this_role;
                print "First non-abstract role is $role\n" if $debug;
                last;
            }
            else {
                $role = $this_role;
            }
        }
        
        #
        # Set the explicit role for this tag
        #
        $current_tag_object->explicit_role($role);
        
        #
        # Check for role="heading" on a tag other than a h tag
        #
        print "Check for heading in role=\"$role\" attribute\n" if $debug;
        if ( ($role eq "heading") && (! ($tagname =~ /^h[0-6]?$/)) ) {

            #
            # Check for a aria-level attribute.
            #
            if ( ! defined($attr{"aria-level"}) ) {
                Record_Result("WCAG_2.0-ARIA12", $line, $column, $text,
                              String_Value("Missing") .
                              " aria-level " . String_Value("attribute") .
                              " " .
                              String_Value("in tag") . "<$tagname role=\"heading\" >");

            }
            #
            # Is the aria-level less than or equal to 6, we should be
            # using a <h> tag.
            #
            elsif ( $attr{"aria-level"} <= 6 ) {
                Record_Result("WCAG_2.0-ARIA12", $line, $column, $text,
                              String_Value("Found") .
                              " <$tagname role=\"heading\" aria-level=\"" .
                              $attr{"aria-level"} .  "\" " .
                              String_Value("expected") .
                              " <h" . $attr{"aria-level"} . ">");
            }
            
            #
            # Check for level 1 heading
            #
            if ( defined($attr{"aria-level"}) && ($attr{"aria-level"} == 1) ) {
                $found_h1 = 1;
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
        # Check for role="img", if we have one there must be a text
        # alternative.
        #
        if ( $role eq "img" ) {
            #
            # Check for alt and make sure it is not blank
            #
            print "Found role=img, checking for text alternative\n" if $debug;
            if ( defined($attr{"alt"}) && ($attr{"alt"} =~ /^\s*$/) ) {
                print "Empty alt attribute\n" if $debug;
            }
            #
            # Check for alt text for a later test for invalid values.
            #
            elsif ( defined($attr{"alt"}) ) {
                $text_alternative = $attr{"alt"};
            }
            #
            # Check for aria-label and make sure it is not blank
            #
            elsif ( defined($attr{"aria-label"}) && ($attr{"aria-label"} =~ /^\s*$/) ) {
                print "Empty aria-label attribute\n" if $debug;
            }
            #
            # Check for alt text for a later test for invalid values.
            #
            elsif ( defined($attr{"aria-label"}) ) {
                $text_alternative = $attr{"aria-label"};
            }
            #
            # Check for aria-labelledby and make sure it is not blank
            #
            elsif ( defined($attr{"aria-labelledby"}) && ($attr{"aria-labelledby"} =~ /^\s*$/) ) {
                print "Empty aria-labelledby attribute\n" if $debug;
            }
            #
            # Check for aria-labelledby text for a later test for a
            # matching ID value.
            #
            elsif ( defined($attr{"aria-labelledby"}) ) {
                $text_alternative_id = $attr{"aria-labelledby"};
            }
            #
            # Check for title and make sure it is not blank
            #
            elsif ( defined($attr{"title"}) && ($attr{"title"} =~ /^\s*$/) ) {
                print "Empty title attribute\n" if $debug;
            }
            #
            # Check for title text for a later test for invalid values.
            #
            elsif ( defined($attr{"title"}) ) {
                $text_alternative = $attr{"title"};
            }
        }

        #
        # Check role for main, it indicates the beginning of the main content
        # area
        #
        if ( $role eq "main" ) {
            #
            # Is there a hidden attribute on this tag? If so we don't consider
            # it a main content.
            #
            if ( defined($attr{"hidden"}) ) {
                print "Hidden role=\"main\", don't check for duplicate main sections\n" if $debug;
            }
            else {
                #
                # Is this landmark a top level landmark (i.e. not contained within
                # any other landmark)?  Check that the landmark of the parent
                # tag is blank.
                #
                $n = @tag_order_stack;
                if ( $n > 1 ) {
                    $tag = $tag_order_stack[$n - 2];
                }
                else {
                    undef($tag);
                }
                if ( defined($tag) &&
                     (($tag->landmark() ne "") && ($tag->landmark() ne "body")) ) {
                    #
                    # Main landmark contained within another landmark
                    #
                    print "Non blank landmark " . $tag->landmark() .
                          " on parent tag " . $tag->tag() . "\n" if $debug;
                    Record_Result("WCAG_2.0-SC1.3.1",
                                  $line, $column, $text,
                                  String_Value("Main landmark nested in") .
                                  " \"" . $tag->landmark() . "\"");
                }

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

                    #
                    # Does this main have an invalid ancestor?
                    #
                    print "Check for illegal ancestor element\n" if $debug;
                    $first_tag = 1;
                    foreach $tag (reverse @tag_order_stack) {
                        #
                        # Skip the current tag as it may be a <section> with role=main
                        # so is not really an ancestor tag.
                        #
                        if ( $first_tag ) {
                            $first_tag = 0;
                            next;
                        }

                        #
                        # Is this an invalid ancestor tag?
                        #
                        if ( defined($invalid_main_ancestors{$tag->tag}) ) {
                            print "Illegal ancestor " . $tag->tag . " found\n" if $debug;
                            Record_Result("WCAG_2.0-SC1.3.1", $line, $column, $text,
                                          String_Value("Main landmark must not be nested in") .
                                          " <" . $tag->tag . ">");
                            last;
                        }
                    }
                }
            }
        }
        
        #
        # Check for any required context roles
        #
        print "Check for any required context roles\n" if $debug;
        $context_role_list = TQA_WAI_Aria_Required_Context_Roles($role);
        if ( $context_role_list ne "" ) {
            print "Role $role requires context roles of $context_role_list\n" if $debug;
            $context_role = Check_Role_Context($tagname, $context_role_list);

            #
            # Did we find a required context role value?
            #
            if ( $context_role eq "" ) {
                Record_Result("WCAG_2.0-SC1.3.1,ACT-ARIA_required_context_role",
                              $line, $column, $text,
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
    elsif ($current_tag_object->implicit_role() ne "" ) {
        $role = $current_tag_object->implicit_role();
        print "Check implicit role $role for this tag\n" if $debug;
        
        #
        # Check for any required context roles
        #
        $context_role_list = TQA_WAI_Aria_Required_Context_Roles($role);
        if ( $context_role_list ne "" ) {
            print "Role $role requires context roles of $context_role_list\n" if $debug;
            $context_role = Check_Role_Context($tagname, $context_role_list);

            #
            # Did we find a required context role value?
            #
            if ( $context_role eq "" ) {
                Record_Result("WCAG_2.0-SC1.3.1,ACT-ARIA_required_context_role", $line, $column, $text,
                              String_Value("Missing required context role for implicit role") .
                              " \"$role\" " .
                              String_Value("expecting one of") .
                              " \"$context_role_list\"");
            }
        }
    }
    
    #
    # Does this tag have an explicit role, if not set role to it's implicit
    # role
    #
    if ( ! defined($role) ) {
        $role = $current_tag_object->implicit_role();
    }
    
    #
    # Add the role value to the parent tag's children role list
    #
    if ( defined($parent_tag_object) ) {
        #
        # If this tag has a role that is not presentation or none, add
        # this child's role to the parent tag's required list.
        #
        if ( ($role ne "") && ($role ne "none") && ($role ne "presentation") ) {
            $parent_tag_object->add_children_role($role);
            print "Add $role to children roles for tag " .
                  $parent_tag_object->tag() . "\n" if $debug;
        }
    }

    #
    # Check the roles of this tag to see if they support
    # accessible name from content.
    #
    Check_Support_of_Accessible_Name_from_Content($tagname, $line, $column,
                                                  $text);
}

#***********************************************************************
#
# Name: Check_Role_Allowed_Aria_Attributes
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks the role of the tag and checks that only
# allowed ARIA attributes are included in the tag.
#
#***********************************************************************
sub Check_Role_Allowed_Aria_Attributes {
    my ($tagname, $line, $column, $text, %attr) = @_;
    
    my ($attribute, $role, $required_attributes, $supported_attributes);
    my (%allowed_attributes);

    #
    # Get the role for this tag
    #
    print "Check_Role_Allowed_Aria_Attributes\n" if $debug;
    if ( defined($current_tag_object) ) {
        $role = $current_tag_object->explicit_role();
        if ( $role eq "" ) {
            $role = $current_tag_object->implicit_role();
        }
    }
    else {
        $role = "";
    }

    #
    # Do we have role specific required aria attributes?
    #
    print "Check for required attributes for role = $role\n" if $debug;
    if ( defined($role_specific_required_aria_properties{$role}) ) {
        $required_attributes = $role_specific_required_aria_properties{$role};
        print "Required attributes = \"$required_attributes\"\n" if $debug;

        #
        # Create a hash table for the required attributes
        #
        foreach $attribute (split(/\s+/, $required_attributes)) {
            $allowed_attributes{$attribute} = 1;
        }
    }

    #
    # Do we have role specific supported aria attributes?
    #
    print "Check for supported attributes for role = $role\n" if $debug;
    if ( defined($role_specific_supported_aria_properties{$role}) ) {
        $supported_attributes = $role_specific_supported_aria_properties{$role};
        print "Supported attributes = \"$supported_attributes\"\n" if $debug;

        #
        # Create a hash table for the required attributes
        #
        foreach $attribute (split(/\s+/, $supported_attributes)) {
            $allowed_attributes{$attribute} = 1;
        }
    }
    
    #
    # Check for aria-* attributes
    #
    foreach $attribute (keys(%attr)) {
        #
        # Is this an aria- attribute
        #
        if ( $attribute =~ /^aria\-/ ) {
            #
            # Is this a global ARIA attribute? which is valid for any
            # tag.
            #
            if ( defined($global_aria_properties{$attribute}) ) {
                print "Global ARIA attribute $attribute\n" if $debug;
            }
            #
            # Is the attribute in the list of allowed attributes for
            # the tag's role?
            #
            elsif ( defined($allowed_attributes{$attribute}) ) {
                print "Required or supported ARIA attribute $attribute for role\n" if $debug;
            }
            #
            # ARIA attribute is not allowed on this tag with this role
            #
            else {
                Record_Result("ACT-ARIA_state_property_permitted",
                              $line, $column, $text,
                              String_Value("ARIA attribute not allowed") .
                              " '$attribute=\"" . $attr{$attribute} . "\"' " .
                              String_Value("for tag") . "<$tagname role=\"$role\">");
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Role_Required_Aria_Attributes
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks the role of the tag and checks that all
# required ARIA attributes are included in the tag.
#
#***********************************************************************
sub Check_Role_Required_Aria_Attributes {
    my ($tagname, $line, $column, $text, %attr) = @_;

    my ($attribute, $role, $required_attributes, %found_attributes);

    #
    # Get the explicit role for this tag
    #
    print "Check_Role_Required_Aria_Attributes\n" if $debug;
    if ( defined($current_tag_object) ) {
        $role = $current_tag_object->explicit_role();
        if ( $role eq "" ) {
            #
            # No explicit role, don't use implicit role as the rule
            # ACT-Element with role attribute has required states and properties
            # applies to explicit roles only.
            #
            #$role = $current_tag_object->implicit_role();
        }
    }
    else {
        $role = "";
    }

    #
    # Do we have role specific required aria attributes?
    #
    print "Check for required attributes for role = $role\n" if $debug;
    if ( defined($role_specific_required_aria_properties{$role}) ) {
        $required_attributes = $role_specific_required_aria_properties{$role};
        
        #
        # Create a hash table for the required attributes
        #
        foreach $attribute (split(/\s+/, $required_attributes)) {
            if ( $attribute ne "" ) {
                $found_attributes{$attribute} = 0;
            }
        }

        #
        # Check for aria-* attributes
        #
        foreach $attribute (keys(%attr)) {
            #
            # Is this an HTML attribute that is equivalent to an ARIA
            # attribute?
            #
            if ( defined($html_aria_attribute_equivalence{$attribute}) ) {
                print "Mapping HTML attribute $attribute to " .
                      $html_aria_attribute_equivalence{$attribute} . "\n" if $debug;
                $attribute = $html_aria_attribute_equivalence{$attribute};
            }
            
            #
            # Is this an aria- attribute
            #
            if ( $attribute =~ /^aria\-/ ) {
                #
                # Is this a required ARIA attribute?
                #
                if ( defined($found_attributes{$attribute}) ) {
                    print "Required ARIA attribute $attribute\n" if $debug;
                    $found_attributes{$attribute} = 1;
                }
            }
        }
        
        #
        # Did we find all the required attributes?
        #
        foreach $attribute (keys(%found_attributes)) {
            if ( ! $found_attributes{$attribute} ) {
                Record_Result("ACT-Role_has_required_properties", $line, $column, $text,
                                  String_Value("Missing required ARIA attribute") .
                                  " '$attribute='" .
                                  String_Value("for tag") . "<$tagname role=\"$role\">");
            }
            #
            # Do we have a non blank value for the attribute?
            #
            elsif ( $attr{$attribute} =~ /^\s*$/ ) {
                Record_Result("ACT-Role_has_required_properties", $line, $column, $text,
                                  String_Value("Missing required ARIA attribute value") .
                                  " '$attribute='" .
                                  String_Value("for tag") . "<$tagname role=\"$role\">");
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Aria_Attributes
#
# Parameters: tagname - tag name
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
    my ($tagname, $line, $column, $text, $attrseq, %attr) = @_;

    my ($value, $tcid, $attribute, $roles_list, $context_role);
    my ($valid_value, $valid_value_set, $is_valid, $message, $tag_role);
    my ($value_part, $valid_part, $all_valid, $this_role);

    #
    # Check role attribute
    #
    print "Check_Aria_Attributes for $tagname\n" if $debug;
    Check_Aria_Role_Attribute($tagname, $line, $column, $text, %attr);
    
    #
    # Get this tag's role
    #
    if ( defined($current_tag_object) ) {
        $tag_role = $current_tag_object->explicit_role();
        if ( $tag_role eq "" ) {
            $tag_role = $current_tag_object->implicit_role();
        }
    }
    else {
        $tag_role = "";
    }

    #
    # Check aria-controls attribute
    #
    Check_Aria_Controls_Attribute($tagname, $line, $column, $text, %attr);

    #
    # Check aria-describedby attribute
    #
    Check_Aria_Describedby_Attribute($tagname, $line, $column, $text, %attr);

    #
    # Check aria-labelledby attribute
    #
    Check_Aria_Labelledby_Attribute($tagname, $line, $column, $text, %attr);

    #
    # Check role for allowed ARIA attributes
    #
    Check_Role_Allowed_Aria_Attributes($tagname, $line, $column, $text, %attr);

    #
    # Check role for required ARIA attributes
    #
    Check_Role_Required_Aria_Attributes($tagname, $line, $column, $text, %attr);

    #
    # Check aria-owns attribute
    #
    Check_Aria_Owns_Attribute($tagname, $line, $column, $text, %attr);
    
    #
    # Check for aria-label attribute
    #
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
    # Does the ARIA attribute have a valid value?
    #
    #  https://auto-wcag.github.io/auto-wcag/rules/SC4-1-2-aria-state-or-property-has-valid-value.html
    #
    print "Check that ARIA attribute or property value is valid\n" if $debug;
    foreach $attribute (keys(%attr)) {
        #
        # Is this a valid aria attribute?  If the attribute name starts
        # with "aria-", it is expected to be an aria attribute.
        #
        print "Check attribute $attribute\n" if $debug;
        if ( ($attribute =~ /^aria\-/) &&
             (! defined($valid_aria_attribute_values{$attribute})) ) {
            #
            # Looks like an aria attribute, but not in the list of
            # valid attribute names
            #
            Record_Result("ACT-ARIA_attribute_defined", $line, $column, $text,
                          String_Value("Invalid WAI-ARIA attribute") .
                          " \"$attribute\"");
        }
        #
        # Do we have a value set for this attribute?
        #
        elsif ( defined($valid_aria_attribute_values{$attribute}) ) {
            #
            # Get the attribute value and the set of possible valid values
            #
            $valid_value_set = $valid_aria_attribute_values{$attribute};
            $value = $attr{$attribute};
            $value =~ s/^\s*//g;
            $value =~ s/\s*$//g;
            $value = lc($value);
            print "Valid attribute value set is $valid_value_set\n" if $debug;
            print "Attribute value is $value\n" if $debug;

            #
            # Check for value classes (e.g. INTEGER) or fixed set
            # of values.
            #
            $is_valid = 0;
            if ( $valid_value_set eq "ID" ) {
                #
                # Check that there are no whitespace characters in the value
                #
                if ( ($value ne "") && (! ($value =~ /\s+/)) ) {
                    print "Found ID class value\n" if $debug;
                    $is_valid = 1;
                }
                $message = String_Value("expecting ID value");
            }
            elsif ( $valid_value_set eq "ID LIST" ) {
                #
                # Check that there are characters in the value
                #
                if ( $value ne "" ) {
                    print "Found ID LIST class value\n" if $debug;
                    $is_valid = 1;
                }
                $message = String_Value("expecting ID value");
            }
            elsif ( $valid_value_set eq "INTEGER" ) {
                #
                # Check for optional negative sign and digits only
                #
                if ( $value =~ /^\-?\d+$/ ) {
                    $is_valid = 1;
                    print "Found INTEGER class value\n" if $debug;
                }
                $message = String_Value("expecting integer value");
            }
            elsif ( $valid_value_set eq "NUMBER" ) {
                #
                # Check for optional negative sign, digits, optional
                # decimal point and optional extra digits only
                #
                if ( $value =~ /^\-?\d+(\.\d+)?$/ ) {
                    $is_valid = 1;
                    print "Found NUMBER class float value\n" if $debug;
                }
                #
                # Check for hexadecimal number
                #
                elsif ( $value =~ /^0x([0-9][a-f])+?$/i ) {
                    $is_valid = 1;
                    print "Found NUMBER class HEX value\n" if $debug;
                }
                $message = String_Value("expecting numerical value");
            }
            elsif ( $valid_value_set eq "STRING" ) {
                #
                # Check for 1 or more non-whitespace characters
                #
                if ( $value ne "" ) {
                    $is_valid = 1;
                    print "Found non whitespace characters in STRING class value\n" if $debug;
                }
                $message = String_Value("expecting a non-blank text value");
            }
            else {
                #
                # A fixed set of possible values. We may have multiple
                # values from this set.
                #
                $all_valid = 1;
                foreach $value_part (split(/ /, $value)) {
                    #
                    # Check for a match on each possible valid value
                    #
                    $valid_part = 0;
                    print "Check value part $value_part\n" if $debug;
                    foreach $valid_value (split(/ /, $valid_value_set)) {
                        #
                        # Does the value match the valid value?
                        #
                        if ( $value_part eq $valid_value ) {
                            $valid_part = 1;
                            print "Found matching value in value list\n" if $debug;
                            last;
                        }
                    }
                    
                    #
                    # Was this partial value valid?
                    #
                    if ( ! $valid_part ) {
                         $all_valid = 0;
                         print "Did not find matching value in value list\n" if $debug;
                         last;
                    }
                }
                
                #
                # Were all parts of the value valid?
                #
                if ( $all_valid ) {
                    $is_valid = 1;
                }
                $message = String_Value("expecting one of") .
                           " \"$valid_value_set\"";
            }

            #
            # Did we not find a valid value?
            #
            if ( ! $is_valid ) {
                #
                # Gety testcase list.
                # The ACT-Rules testcase "ARIA state or property has valid value"
                # is not applicable for null attribute values.
                #
                if ( $value eq "" ) {
                    $tcid = "WCAG_2.0-G192";
                }
                else {
                    $tcid = "WCAG_2.0-G192,ACT-ARIA_state_property_valid_value";
                }

                Record_Result($tcid, $line, $column, $text,
                              String_Value("Invalid value for WAI-ARIA attribute") .
                              " $attribute=\"" . $attr{$attribute} .
                              "\" $message");
            }
        }
    }
    
    #
    # Do we have an ARIA attribute that has some role attribute requirements
    #
    foreach $attribute (keys(%attr)) {
        if ( defined($aria_used_in_roles{$attribute}) ) {
            $roles_list = $aria_used_in_roles{$attribute};
            
            #
            # Does this tag's role match the required role for this
            # ARIA attribute?
            #
            $context_role = "";
            foreach $this_role (split(/\s+/, $roles_list)) {
                if ( $tag_role eq $this_role ) {
                    print "Found required context role $context_role in tag\n" if $debug;
                    $context_role = "$tag_role";
                    last;
                }
            }

            #
            # If the required role was not found in this tag, check
            # context tags.
            #
            if ( $context_role eq "" ) {
                $context_role = Check_Role_Context($tagname, $roles_list);
            }

            #
            # Did we find a required context role value?
            #
            if ( $context_role eq "" ) {
                Record_Result("WCAG_2.0-SC4.1.2", $line, $column, $text,
                              String_Value("Missing required context role for WAI-ARIA attribute") .
                              " \"$attribute\" " .
                              String_Value("expecting one of") .
                              " \"$roles_list\"");
            }
        }
    }

    #
    # Do we have an aria-roledescription attribute without either an
    # explicit or implicit role?
    #
    if ( defined($attr{"aria-roledescription"}) ) {
        $value = $attr{"aria-roledescription"};
        $value =~ s/^\s*//g;
        $value =~ s/\s*$//g;
        
        #
        # If we have a value, check for implicit or explicit role value
        #
        if ( $value ne "" ) {
            #
            # Do we have a role?
            #
            print "Have aria-roledescription = $value\n" if $debug;
            if ( $tag_role  eq "" ) {
                Record_Result("WCAG_2.0-SC4.1.2", $line,
                              $column, $text,
                              String_Value("WAI-ARIA attribute") .
                              " \"aria-roledescription\" " .
                              String_Value("is only allowed on tags with a role"));
            }
        }
    }
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
    # we have styles for this tag
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
    my ($tagname, $line, $column, $text, $attrseq, %attr) = @_;

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
    Check_Aria_Attributes($tagname, $line, $column, $text, $attrseq, %attr);

    #
    # Check autocomplete attribute
    #
    Check_Autocomplete_Attribute($tagname, $line, $column, $text, %attr);

    #
    # Check for accesskey attribute
    #
    Check_Accesskey_Attribute($tagname, $line, $column, $text, %attr);

    #
    # Look for deprecated tag attributes
    #
    Check_Deprecated_Attributes($tagname, $line, $column, $text, %attr);
    
    #
    # Check that decorative tags are not in the accessibility tree, or
    # or have a presentational role.
    #
    Check_Decorative_Non_decorative_Attributes($tagname, $line, $column,
                                               $text, %attr);
    
    #
    # Check for tabindex greater than 0.
    # In most cases this will cause a problem with focus order,
    # it wont match the visual presentation order.
    #
    if ( defined($attr{"tabindex"}) && ($attr{"tabindex"} > 0) ) {
        print "Tag has tabindex greater than zero\n" if $debug;
        Record_Result("WCAG_2.0-F44", $line, $column, $text,
                      String_Value("Tabindex value greater than zero") .
                      " tabindex=\"" . $attr{"tabindex"} . "\"");
    }
}

#***********************************************************************
#
# Name: Get_Tag_XPath
#
# Parameters: none
#
# Description:
#
#   This function returns a string of the tags leading to the current
# tag.
#
#***********************************************************************
sub Get_Tag_XPath {

    my ($tag_item, $tag, $location, $tag_string);

    #
    # Get the tags starting with the top tag
    #
    print "Get_Tag_XPath, tag order stack size = " . scalar(@tag_order_stack) . "\n" if $debug;
    foreach $tag_item (@tag_order_stack) {
        #
        # Get the tag and location
        #
        $tag = $tag_item->tag;
        $location = $tag_item->line_no . ":" . $tag_item->column_no;
        
        #
        # Add separator and tag to the path
        #
        $tag_string .= "/$tag";
    }
    
    #
    # Do we have an end tag?
    #
    if ( $current_end_tag ne "" ) {
        $tag_string .= "/$current_end_tag";
    }
    
    #
    # Return the tag string
    #
    print "Xpath = $tag_string\n" if $debug;
    return($tag_string);
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
            print "Multiple instances of $tagname previously seen at $prev_location\n" if $debug;
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
# Name: Check_Parent_Child_Tag_Relationship
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
#   This function check to see if there are restrictions on the
# parent/child tag nesting relationship.  Is the child tag valid
# for the parent tag.
#
#***********************************************************************
sub Check_Parent_Child_Tag_Relationship {
    my ( $self, $tag, $line, $column, $text, %attr ) = @_;

    my ($child_list, $child_tag, $is_valid);

    #
    # Is the parent tag in the set of tags that have relationship rules.
    #
    if ( defined($parent_child_tags{$parent_tag}) ) {
        #
        # Is the current tag a valid child for this parent?
        #
        print "Check_Parent_Child_Tag_Relationship for $parent_tag/$tag\n" if $debug;
        $is_valid = 0;
        $child_list = $parent_child_tags{$parent_tag};
        foreach $child_tag (split(/,/, $child_list)) {
            if ( $tag eq $child_tag ) {
                #
                # We have a valid child.
                #
                $is_valid = 1;
                last;
            }
        }

        #
        # Is the child invalid?
        #
        if ( ! $is_valid ) {
            print "Invalid parent/child relationship\n" if $debug;

            #
            # Record error based on the parent tag value
            #
            if ( $parent_tag eq "dl" ) {
                Record_Result("WCAG_2.0-SC1.3.1", $line, $column, $text,
                              String_Value("dl must contain only dt, dd, div, script or template tags") .
                              ". " . String_Value("Found tag") . " <$tag>");
            }
            elsif ( ($parent_tag eq "ol") || ($parent_tag eq "ul") ) {
                Record_Result("WCAG_2.0-SC1.3.1", $line, $column, $text,
                              String_Value("ol, ul must contain only li, script or template tags") .
                              ". " . String_Value("Found tag") . " <$tag>");
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Parent_Child_Role_Relationship
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
#   This function check to see if there are restrictions on the
# parent/child role nesting relationship.  Is the child role valid
# for the parent role.
#
#***********************************************************************
sub Check_Parent_Child_Role_Relationship {
    my ( $self, $tag, $line, $column, $text, %attr ) = @_;

    my ($child_role, $found_role, $parent_role, $role_list, $role);
    my ($this_role);

    #
    # Do we have a parent tag?
    #
    if ( defined($current_tag_object) && defined($parent_tag_object) ) {
        #
        # Determine the role for the parent tag. Use explicit role,
        # if there is one, otherwise use the implicit role.
        #
        $parent_role = $parent_tag_object->explicit_role();
        if ( $parent_role eq "" ) {
            $parent_role = $parent_tag_object->implicit_role();
        }
        print "Check_Parent_Child_Role_Relationship: parent tag role = $parent_role\n" if $debug;

        #
        # Determine the role for the child tag. Use explicit role,
        # if there is one, otherwise use the implicit role.
        #
        $child_role = $current_tag_object->explicit_role();
        if ( $child_role eq "" ) {
            $child_role = $current_tag_object->implicit_role();
        }
        print "Child tag role = $child_role\n" if $debug;
        
        #
        # Is the parent tag role defined and not presentational?
        #
        if ( ($parent_role ne "") &&
             ($parent_role ne "none") &&
             ($parent_role ne "presentation") ) {
            #
            # Is the child tag role defined and not presentational?
            #
            if ( ($child_role ne "") &&
                 ($child_role ne "none") &&
                 ($child_role ne "presentation") ) {
                #
                # Get the list of required roles (if any) for the parent
                # tag role.
                #
                $role_list = TQA_WAI_Aria_Required_Owned_Elements($parent_role);
                print "Required owned roles list \"$role_list\"\n" if $debug;

                #
                # Are there any required roles?
                #
                if ( $role_list ne "" ) {
                    #
                    # Does the child role match one of the required owned roles?
                    #
                    $found_role = 0;
                    foreach $role (split(/\s+/, $role_list)) {
                        #
                        # Check each child role in case there are multiple
                        #
                        foreach $this_role (split(/\s+/, $child_role)) {
                            if ( $this_role eq $role ) {
                                print "Found required owned role $role\n" if $debug;
                                $found_role = 1;
                                last;
                            }
                        }
                        
                        #
                        # Did we find a role match? if so exit the loop
                        #
                        if ( $found_role ) {
                            last;
                        }
                    }
                    
                    #
                    # Did not find a match in roles?
                    #
                    if ( ! $found_role ) {
                        Record_Result("ACT-ARIA_required_owned_elements",
                                      $line, $column, $text,
                                      String_Value("Invalid owned element role") .
                                      " \"$child_role\" " .
                                      String_Value("expecting one of") .
                                      " \"$role_list\"");
                    }
                }
            }
        }
    }
    #XXXXXX
}

#***********************************************************************
#
# Name: Check_Landmark
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
#   This function checks landmarks for proper nesting.
#
#***********************************************************************
sub Check_Landmark {
    my ( $self, $tagname, $line, $column, $text, %attr ) = @_;

    my ($last_item, $tag_item, $previous_landmark, $tcid);

    #
    # Get last start tag to get previous landmark value.
    #
    print "Check_Landmark $current_landmark for $tagname\n" if $debug;
    $last_item = @tag_order_stack - 2;
    if ( $last_item >= 0 ) {
        $tag_item = $tag_order_stack[$last_item];

        #
        # Get the previous landmark value
        #
        $previous_landmark = $tag_item->landmark();
        print "Previous landmark $previous_landmark for tag " . $tag_item->tag() . "\n" if $debug;
    }
    else {
        print "Tag order stack is empty\n" if $debug;
        $previous_landmark = "";
    }

    #
    # Is this the landmark different from the parent (i.e. not inherited)?
    #
    if ( $current_landmark ne $previous_landmark ) {
        #
        # Is the current landmark a banner landmark?
        #
        if ( $current_landmark eq "banner" ) {
            $tcid = "AXE-Landmark_banner_is_top_level";
        }
        #
        # Is the current landmark a complementary landmark?
        #
        elsif ( $current_landmark eq "complementary" ) {
            $tcid = "AXE-Landmark_complementary_is_top_level";
        }
        #
        # Is the current landmark a contentinfo landmark?
        #
        elsif ( $current_landmark eq "contentinfo" ) {
            $tcid = "AXE-Landmark_contentinfo_is_top_level";
        }

        #
        # Must not be contained within any other landmark other than body.
        #
        if ( $previous_landmark ne "body" ) {
#            Record_Result($tcid, $line, $column, $text,
#                          String_Value("Landmark") . " $current_landmark " .
#                          String_Value("must not be contained in another landmark") .
#                          ". " . String_Value("Container landmark is") .
#                          " $previous_landmark");
        }
    }
    else {
        #
        # Current and previous landmarks are the same, must be
        # an inherited landmark.
        #
        print "Inherited landmark\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Check_Interactive_Parent
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks to see if this tag has an interactive tag as
# a parent tag.  Interactive tags cannot be nested.
#
#***********************************************************************
sub Check_Interactive_Parent {
    my ($tagname, $line, $column, $text, %attr) = @_;
    
    my ($interactive_tag, $tag_item, $last_item, $parent_tag);

    #
    # Start at parent tag (2nd last tag item)
    #
    print "Check_Interactive_Parent for tag $tagname\n" if $debug;
    $last_item = @tag_order_stack - 2;
    if ( $last_item >= 0 ) {
        #
        # Walk up the tag stack to find an interactive parent
        #
        print "Check tag stack\n" if $debug;
        while ( (! defined($interactive_tag)) && ($last_item >= 0) ) {
            $tag_item = $tag_order_stack[$last_item];
            if ( $tag_item->interactive() ) {
                $interactive_tag = $tag_item;
                last;
            }
            $last_item = $last_item - 1;
        }
    }
    
    #
    # Do we have an interactive parent tag?
    #
    if ( defined($interactive_tag) ) {
        #
        # The parent tag may mask this tag, we won't be able to
        # activate this tag.
        #
        $parent_tag = $interactive_tag->tag();
        print "Found interactive parent tag $parent_tag\n" if $debug;
        if ( ! defined($acceptable_parent_interactive_tag{$parent_tag}) ) {
            Record_Result("WCAG_2.0-SC2.4.3,ACT-Children_not_focusable", $line, $column, $text,
                          String_Value("Interactive tag has an interactive parent tag") .
                          " <$parent_tag> " .
                          String_Value("found at") . $interactive_tag->line_no() .
                          ":" . $interactive_tag->column_no());
        }
    }
    else {
        print "No interactive parent tag fount\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Compute_Implicit_Role
#
# Parameters: tagname - name of tag
#             line - line number
#             length - position in the content stream
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function computes the implicit role for the tag.  Some tags
# have implicit roles based on the tag name.  Some roles depend
# on the tag name and the presence of other attributes on the tag.
#
#***********************************************************************
sub Compute_Implicit_Role {
    my ($tagname, $line, $column, $text, %attr) = @_;

    my ($implicit_role) = "";
    my ($conditions, @condition_list, $condition, $type, $name, $value, $role);

    #
    # Does this tag have an implicit role value?
    #
    print "Compute_Implicit_Role\n" if $debug;
    if ( defined($implicit_aria_roles{$tagname}) ) {
        $implicit_role = $implicit_aria_roles{$tagname};
        print "Initial implicit role is $implicit_role\n" if $debug;
    }

    #
    # Are there any conditions for the implicit role for this
    # tag?
    #
    if ( defined($implicit_aria_role_conditions{$tagname}) ) {
        $conditions = $implicit_aria_role_conditions{$tagname};
        print "Conditions found for implicit role\n" if $debug;

        #
        # Split the conditions on white space to get the list of
        # individual conditions.  Conditions may be for the presence
        # of other attributes on the tag, or for values of
        # other attributes.
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
        @condition_list = split(/\s+/, $conditions);

        #
        # Check each condition until we get a match
        #
        foreach $condition (@condition_list) {
            #
            # Is this condition based on the presence of an attribute?
            #
            if ( $condition =~ /^attr:/ ) {
                #
                # Get the attribute name and role
                #
                ($type, $name, $role) = split(/:/, $condition);

                #
                # Do we have the other attribute?
                #
                if ( defined($attr{$name}) ) {
                    #
                    # Have other attribute, set implicit role
                    #
                    $implicit_role = $role;
                    print "Found conditional attribute $name, implicit role is $role\n" if $debug;
                    last;
                }
            }
            #
            # Is this condition based on the value of an attribute?
            #
            elsif ( $condition =~ /^attrvalue:/ ) {
                #
                # Get the attribute name, value and role
                #
                ($type, $name, $value, $role) = split(/:/, $condition);

                #
                # Do we have the other attribute and does it have
                # the required value?
                #
                if ( defined($attr{$name}) && ($attr{$name} eq $value) ) {
                    #
                    # Have other attribute and value, set implicit role
                    #
                    $implicit_role = $role;
                    print "Found conditional attribute $name with value $value, implicit role is $role\n" if $debug;
                    last;
                }
            }
        }
    }

    #
    # Set the computed implicit role for the tag.
    #
    $current_tag_object->implicit_role($implicit_role);
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
    my ($tag_item, $tag, $location, $last_item, $tag_object, $n);
    my ($new_landmark, $new_landmark_marker, $last_item);
    my (%required_roles);

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
    # Check tag nesting, are there any unclosed tags?
    #
    Check_Tag_Nesting($tagname, $line, $column, $text);

    #
    # Get this tag's parent tag name
    #
    if ( defined($current_tag_object) ) {
        $parent_tag = $current_tag_object->tag();
    }
    else {
        $parent_tag = "";
    }

    #
    # Create a new tag object and clear end tag name
    #
    $parent_tag_object = $current_tag_object;
    $current_tag_object = tqa_tag_object->new($tagname, $line, $column,
                                              \%attr_hash);
    $current_end_tag = "";
    
    #
    # Add this tag to the tag stack
    #
    push(@tag_order_stack, $current_tag_object);
    print "Start_Handler, tag order stack size = " . scalar(@tag_order_stack) . "\n" if $debug;

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
    # Check to see if we have multiple instances of tags that we
    # can have only 1 instance of.
    #
    Check_Multiple_Instances_of_Tag($tagname, $line, $column, $text);

    #
    # Compute the current landmark value.  If the new value
    # differs from the previous value, increment count for the new landmark
    # type.
    #
    ($new_landmark, $new_landmark_marker) = HTML_Landmark($tagname, $line,
                                                          $column, $current_landmark,
                                                          $landmark_marker,
                                                          \@tag_order_stack,
                                                          %attr_hash);
    if ( $new_landmark ne $current_landmark ) {
        #
        # Are we inside a frame?
        #
        if ( $inside_frame ) {
            #
            # Increment landmark type counter.
            #
            if ( ! defined($frame_landmark_count{$new_landmark}) ) {
                $frame_landmark_count{$new_landmark} = 1;
                print "Landmark $new_landmark inside of a frame\n"if $debug;
            }
            else {
                $frame_landmark_count{$new_landmark}++;
                print "Frame landmark count for $new_landmark is " .
                      $frame_landmark_count{$new_landmark} . "\n" if $debug;
            }
        }
        #
        # Not in a frame.
        #
        else {
            #
            # Increment landmark type counter.
            #
            if ( ! defined($landmark_count{$new_landmark}) ) {
                $landmark_count{$new_landmark} = 1;
            }
            else {
                $landmark_count{$new_landmark}++;
                print "Landmark count for $new_landmark is " .
                      $landmark_count{$new_landmark} . "\n" if $debug;
            }
        }
        
        #
        # Save new landmark values
        #
        $current_landmark = $new_landmark;
        $landmark_marker = $new_landmark_marker;
    }
    
    #
    # Compute the implicit role for this tag
    #
    Compute_Implicit_Role($tagname, $line, $column, $text, %attr_hash);
    
    #
    # Set the current landmark and marker for the tag.
    #
    $current_tag_object->landmark($current_landmark);
    $current_tag_object->landmark_marker($landmark_marker);

    #
    # Is this tag interactive?
    #
    $current_tag_object->interactive(Is_Interactive_Tag("$tagname", $line, $column, %attr_hash));

    #
    # Check attributes
    #
    Check_Attributes($tagname, $line, $column, $text, $attrseq,
                     %attr_hash);
                     
    #
    # Check for start of content section
    #
    $content_section_handler->check_start_tag($tagname, $line, $column,
                                              %attr_hash);

    #
    # Check for parent/child tag relationship
    #
    Check_Parent_Child_Tag_Relationship($self, $tagname, $line, $column,
                                        $text, %attr_hash);
                                        
    #
    # Check for parent/child role relationship
    #
    Check_Parent_Child_Role_Relationship($self, $tagname, $line, $column,
                                         $text, %attr_hash);

    #
    # Check landmark nesting
    #
    Check_Landmark($self, $tagname, $line, $column, $text, %attr_hash);
                                        
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
    # Check body tag
    #
    elsif ( $tagname eq "body" ) {
        Body_Tag_Handler($self, $line, $column, $text, %attr_hash);
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
    # Check source tag
    #
    elsif ( $tagname eq "source" ) {
        Source_Tag_Handler( $line, $column, $text, %attr_hash );
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
    # Is this tag interactive, visible and inside an aria-hidden tag?
    #
    if ( $current_tag_object->interactive() && ($tag_is_visible) &&
         $tag_is_aria_hidden) {
        Record_Result("WCAG_2.0-SC4.1.2,ACT-Element_aria_hidden_no_focusable_content",
                      $line, $column, $text,
                      String_Value("Focusable content inside aria-hidden tag"));
    }

    #
    # Is this tag interactive? Check for an interactive parent?
    #
    if ( $current_tag_object->interactive() ) {
        Check_Interactive_Parent($tagname, $line, $column, $text, %attr_hash);
    }
    #
    # Check event handlers
    #
    Check_Event_Handlers( $tagname, $line, $column, $text, %attr_hash );
    
    #
    # Set last tag seen
    #
    $last_tag = $tagname;

    #
    # Is this a tag that has no end tag ? If so we must set the last tag
    # seen value here rather than in the End_Handler function.
    #
    if ( defined ($html_tags_with_no_end_tag{$tagname}) ) {
        #
        # Check to see if this tag has an accessible name.
        #
        Check_Accessible_Name($self, $tagname, $line, $column, $text);
        
        #
        # Since this is a self closing tag, it must be removed from the
        # tag stack (we won't get a close tag)
        #
        $current_tag_object = pop(@tag_order_stack);

        #
        # Restore global tag visibility and hidden status values.
        #
        $last_item = @tag_order_stack - 1;
        if ( $last_item >= 0 ) {
            $tag_item = $tag_order_stack[$last_item];
            $current_tag_styles = $tag_item->styles;
            $tag_is_visible = $tag_item->is_visible;
            $tag_is_hidden = $tag_item->is_hidden;
            $tag_is_aria_hidden = $tag_item->is_aria_hidden;
            $current_landmark = $tag_item->landmark();
            $landmark_marker = $tag_item->landmark_marker();

            #
            # Reset current tag object to be the parent tag
            #
            $current_tag_object = $tag_order_stack[$last_item];
            $tagname = $current_tag_object->tag();

            #
            # Set parent tag object
            #
            $last_item = @tag_order_stack;
            if ( $last_item > 0 ) {
                $parent_tag_object = $tag_order_stack[$last_item - 1];
            }
            else {
                undef($parent_tag_object);
            }
        }
        else {
            $tagname = "";
            $current_tag_styles = "";
            $tag_is_visible = 1;
            $tag_is_hidden = 0;
            $tag_is_aria_hidden = 0;
            $current_landmark = "";
            $landmark_marker = "";
            undef($current_tag_object);
            undef($parent_tag_object);
        }
        print "Restore tag_is_visible = $tag_is_visible for last start tag $tagname\n" if $debug;
        print "Restore tag_is_hidden = $tag_is_hidden for last start tag $tagname\n" if $debug;
        print "Restore tag_is_aria_hidden = $tag_is_aria_hidden for last start tag $tagname\n" if $debug;
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
    
    my ($invalid_text);

    #
    # Is the value of the link text 'here' or 'click here' ?
    #
    print "Check_Click_Here_Link, text = \"$link_text\"\n" if $debug;
    if ( $tag_is_visible ) {
        #
        # Remove leading or trailing whitespace and convert to lower case
        #
        $link_text = lc($link_text);
        $link_text =~ s/^\s*//g;
        $link_text =~ s/\s*$//g;
        $link_text =~ s/\.*$//g;

        #
        # Check the value to see if it is invalid link text.
        #
        if ( defined($testcase_data{"WCAG_2.0-H30"}) ) {
            foreach $invalid_text (split(/\n/, $testcase_data{"WCAG_2.0-H30"})) {
                #
                # Do we have a match on the invalid link text ?
                #
                if ( $link_text =~ /^$invalid_text$/i ) {
                    Record_Result("WCAG_2.0-H30", $line, $column, $text,
                                  String_Value("click here link found"));
                }
            }
        }
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

            Record_Result(join(",", @tc_list), $line, $column,
                          $text, String_Value("Missing text in") .
                          String_Value("link"));
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
        #
        # Check if anchor value is just punctuation
        # Reference:
        #  https://alphagov.github.io/accessibility-tool-audit/tests/links-link-contains-only-a-full-stop.html
        #
        elsif ( ($current_a_href ne "") &&
             ($all_anchor_text =~ /^[\!\@\#\$\%\^\&\*\(\)\-\.]$/ ) ) {
            if ( $tag_is_visible ) {
                Record_Result("WCAG_2.0-H30", $line, $column, $text,
                              String_Value("Anchor text is single character punctuation"));
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
    $last_img_title = "";
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
            Record_Result("WCAG_2.0-F25,ACT-HTML_page_title_non_empty",
                          $line, $column, $text,
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
                Record_Result("WCAG_2.0-F25,ACT-HTML_page_title_descriptive",
                              $line, $column, $text,
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
                        Record_Result("WCAG_2.0-F25,ACT-HTML_page_title_descriptive",
                                      $line, $column, $text,
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

    my ($last_start_tag, $location, $tag_list, $n);
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
        # Set parent tag object
        #
        $n = @tag_order_stack;
        if ( $n > 0 ) {
            $parent_tag_object = $tag_order_stack[$n - 1];
        }
        else {
            undef($parent_tag_object);
        }

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
            $tag_is_aria_hidden = 0;
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
# Name: Check_Required_Children_Roles
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function checks to see if the open tag that matches this close
# tag contained any role value that requires specific children roles.
# Any role child values for this tag are propagated to any parent tag's
# child role list.
#
#***********************************************************************
sub Check_Required_Children_Roles {
    my ($self, $tagname, $line, $column, $text) = @_;

    my (%required_roles, $role, @children_roles, $this_role, $expected_roles);
    my ($required_role, $child_role, $found_role, $found_one_role);
    my ($role_list, $tag_role, $copy_children_roles);

    #
    # Did the open tag have a role that requires specific child roles?
    #
    print "Check_Required_Children_Roles for $tagname\n" if $debug;
    $copy_children_roles = 0;

    #
    # Get possible role from the open tag object
    #
    if ( defined($current_tag_object) ) {
        #
        # Use explicit role
        #
        $tag_role = $current_tag_object->explicit_role();
        print "Open tag  explicit role = $tag_role\n" if $debug;
        
        #
        # Get the list of roles for children tags
        #
        @children_roles = $current_tag_object->children_roles();
        print "Children roles for tag " . join(",", @children_roles) . "\n" if $debug;

        #
        # Do we have a non empty or presentational role?
        #
        if ( ($tag_role ne "") && ($tag_role ne "none") &&
             ($tag_role ne "presentation") ) {
            #
            # Are there any required children roles for this tag's role?
            #
            $role_list = TQA_WAI_Aria_Required_Owned_Elements($tag_role);
            print "Required children roles list \"$role_list\"\n" if $debug;
            
            #
            # Are there any required roles?
            #
            if ( $role_list ne "" ) {
                #
                # Do the child roles match one of the required roles?
                #
                $found_one_role = 0;
                foreach $child_role (@children_roles) {
                    #
                    # Check for matching required role
                    #
                    foreach $role (split(/\s+/, $role_list)) {
                        if ( $child_role eq $role ) {
                            print "Found required owned element $role\n" if $debug;
                            $found_one_role = 1;
                            last;
                        }
                    }
                        
                    #
                    # Did we find one role? If so stop looking for others
                    #
                    if ( $found_one_role ) {
                        last;
                    }
                }

                #
                # Did we find at least 1 required child role?
                #
                if ( ! $found_one_role ) {
                    print "Did not find any required owned elements\n" if $debug;
                    Record_Result("WCAG_2.0-SC1.3.1,ACT-ARIA_required_owned_elements", $line, $column, $text,
                                  String_Value("Missing required owned elements for role") .
                                  " \"$tag_role\" " .
                                  String_Value("expecting one of") .
                                  " \"$role_list\"");
                }

                #
                # Add this tag's role to the children roles for the parent tag
                #
                if ( defined($parent_tag_object) ) {
                    print "Add current tag role $tag_role to parent tag\n" if $debug;
                    $parent_tag_object->add_children_role($tag_role);
                }
            }
            else {
                #
                # Copy children roles list to the parent tag.
                #
                $copy_children_roles = 1;
            }
        }
        #
        # No role or presentational only. Copy children roles list to the parent
        # tag.
        #
        elsif ( defined($parent_tag_object) ) {
            $copy_children_roles = 1;
        }

        #
        # Do we copy children roles to the parent tag?
        #
        if ( $copy_children_roles && defined($parent_tag_object) ) {
            print "Add current tag children roles to parent tag\n" if $debug;

            #
            # Add each child role to the parent tags children roles list
            #
            foreach $child_role (@children_roles) {
                $parent_tag_object->add_children_role($child_role);
            }
        }
    }
}

#***********************************************************************
#
# Name: Is_Role_in_Role_list
#
# Parameters: roles - tag roles
#             role_list - space separated list of roles
#
# Description:
#
#   This function checks to see if any of the tag roles are in the list
# of roles provided.
#
#***********************************************************************
sub Is_Role_in_Role_list {
    my ($roles, $role_list) = @_;
    
    my ($this_role, $found_role);
    
    #
    # Check to see if any of the tag's roles are in the list of
    # roles provided.
    #
    $found_role = 0;
    foreach $this_role(split(/ /, $roles)) {
        if ( index($role_list, " $this_role ") != -1 ) {
            $found_role = 1;
            last;
        }
    }
    
    #
    # Return status
    #
    return($found_role);
}

#***********************************************************************
#
# Name: Is_Form_Role
#
# Parameters: roles - tag roles
#
# Description:
#
#   This function checks to see if any of the tag roles are in the list
# of form element roles.
#
#***********************************************************************
sub Is_Form_Role {
    my ($roles) = @_;

    my ($this_role, $found_role);

    #
    # Check to see if any of the tag's roles are in the list of
    # form element roles.
    #
    $found_role = 0;
    foreach $this_role(split(/ /, $roles)) {
        if ( defined($form_element_role_values{$this_role}) ) {
            $found_role = 1;
            last;
        }
    }

    #
    # Return status
    #
    return($found_role);
}

#***********************************************************************
#
# Name: Get_Accessible_Name
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             role - role of the tag
#
# Description:
#
#   This function gets the accessible name for the current tag.
#  The accessible name computation algorthim is defined in
#    https://www.w3.org/TR/accname-1.1/
# Further, tag specific, details are defined in
#    https://www.w3.org/TR/html-aam-1.0/#accessible-name-and-description-computation
#
#***********************************************************************
sub Get_Accessible_Name {
    my ($self, $tagname, $line, $column, $text, $role) = @_;
    
    my ($aria_label, $aria_labelledby, $content, $attr_list, $type);
    my ($implicit_role);
    my ($accessible_name) = "";

    #
    # Do we have a tag object?
    #
    print "Get_Accessible_Name $tagname, role = $role\n" if $debug;
    if ( ! defined($current_tag_object) ) {
        return($accessible_name);
    }
    
    #
    # Get any aria-label and aria-labelledby attributes
    #
    $aria_label = $current_tag_object->attr_value("aria-label");
    $aria_labelledby = $current_tag_object->attr_value("aria-labelledby");
    
    #
    # Get all other attributes for the tag
    #
    print "Current tag is " . $current_tag_object->tag() . "\n" if $debug;
    $attr_list = $current_tag_object->attr();
    
    #
    # Get the implicit role for this tag. The role provided
    # in the argument list may be either implicit or explicit.
    #
    $implicit_role = $current_tag_object->implicit_role();

    #
    # Is the tag hidden?
    #
    if ( $current_tag_object->is_hidden() ) {
        print "Hidden tag\n" if $debug;
    }

    #
    # Do we have a non empty aria-labelledby attribute?
    #
    if ( defined($aria_labelledby) && ! ($aria_labelledby =~ /^\s*$/) ) {
        print "Have aria-labelledby \"$aria_labelledby\" on tag\n" if $debug;

        #
        # TODO: Get content from tag with corresponding ID values
        #
        $accessible_name = $aria_labelledby;
    }
    #
    # Do we have a non empty aria-label attribute?
    #
    elsif ( defined($aria_label) && ! ($aria_label =~ /^\s*$/) ) {
        #
        # Remove leading or trailing whitespace
        #
        print "Have aria-label \"$aria_label\" on tag\n" if $debug;
        $accessible_name = $aria_label;
    }
    #
    # Is the tag presentational (i.e. role="presentation" or role="none").
    # If it contains an aria-label, this overrides the role.
    #
    elsif ( (($role eq "presentation") || ($role eq "none")) && (! defined($aria_label)) ) {
        print "Presentational tag\n" if $debug;
    }
    #
    # Tag type specific accessible name computation
    #  https://www.w3.org/TR/html-aam-1.0/#accessible-name-and-description-computation
    #
    #
    # Is this an input?
    #
    elsif ( $tagname eq "input" ) {
        #
        # Check the input type
        #
        if ( $current_tag_object->attr_value("type") ne "" ) {
            $type = $current_tag_object->attr_value("type");
        }
        else {
            print "Default type is text\n" if $debug;
            $type = "text";
        }
        print "Have input type=\"$type\"\n" if $debug;
        
        #
        # Is this a text, password, search, tel, email or url type?
        #
        if ( index(" email password search tel text url ", " $type ") != -1 ) {
            #
            # Do we have a non-empty value attribute?
            #
            if ( $current_tag_object->attr_value("value") ne "" ) {
                $accessible_name = $current_tag_object->attr_value("value");
            }
            #
            # Do we have a label?  Check for an id attribute. If there is no
            # corresponding label it will be reported WCAG_2.0-F68.
            #
            elsif ( $current_tag_object->attr_value("id") ne "" ) {
                $accessible_name = $current_tag_object->attr_value("id");
            }
            #
            # Are we inside a label?
            #
            elsif ( $inside_label ) {
                #
                # Use a dummy value for the accessible name. Subsequent checks
                # only look for non empty names.
                #
                $accessible_name = "Inside label";
            }
            #
            # Do we have a title attribute?
            #
            elsif ( defined($$attr_list{"title"}) ) {
                $accessible_name = $$attr_list{"title"};
            }
            #
            # Do we have a placeholder attribute?
            #
            elsif ( defined($$attr_list{"placeholder"}) ) {
                $accessible_name = $$attr_list{"placeholder"};
            }
        }
        #
        # This this a button, submit or reset type?
        #
        elsif ( index(" button reset submit ", " $type ") != -1 ) {
            #
            # Do we have a value attribute?
            #
            if ( defined($$attr_list{"value"}) ) {
                $accessible_name = $$attr_list{"value"};
            }
            
            #
            # Is this a submit input?
            #
            if ( ($type eq "submit") && ($accessible_name eq "") ) {
                $accessible_name = "submit";
            }
            #
            # Is this a reset input?
            #
            elsif ( ($type eq "reset") && ($accessible_name eq "") ) {
                $accessible_name = "reset";
            }
            #
            # Do we have a title attribute?
            #
            elsif ( defined($$attr_list{"title"}) ) {
                $accessible_name = $$attr_list{"title"};
            }
        }
        #
        # This this an image type?
        #
        elsif ( $type eq "image" ) {
            #
            # Do we have an alt attribute?
            #
            if ( defined($$attr_list{"alt"}) ) {
                $accessible_name = $$attr_list{"alt"};
            }
            #
            # Do we have a title attribute?
            #
            elsif ( defined($$attr_list{"title"}) ) {
                $accessible_name = $$attr_list{"title"};
            }
            #
            # Do we have a name attribute? It can't be used for
            # the accessible name, so set it to an empty string.
            #
            elsif ( defined($$attr_list{"name"}) ) {
                $accessible_name = "";
            }
            #
            # Use string "Submit Query"
            #
            else {
                $accessible_name = "Submit Query";
            }
        }
        #
        # Are we inside a label?
        #
        elsif ( $inside_label ) {
            #
            # Use a dummy value for the accessible name. Subsequent checks
            # only look for non empty names.
            #
            $accessible_name = "Inside label";
        }
    }
    #
    # Is this a textarea?
    #
    elsif ( $role eq "textarea" ) {
        #
        # Do we have a non-empty title attribute?
        #
        if ( defined($$attr_list{"title"}) ) {
            $accessible_name = $$attr_list{"title"};
        }
    }
    #
    # Is this a button or output?
    #
    elsif ( ($role eq "button") || ($role eq "fieldset") ) {
        #
        # Get tag content as accessible name
        #
        $content = Clean_Text(Get_Text_Handler_Content($self, " "));
        if ( (! $content =~ /^\s*$/) ) {
            $accessible_name = $content;
        }
        #
        # Do we have a non-empty title attribute?
        #
        elsif ( $current_tag_object->attr_value("title") ne "" ) {
            $accessible_name = $current_tag_object->attr_value("title");
        }
    }
    #
    # Is this a fieldset?
    #
    elsif ( $role eq "fieldset" ) {
        #
        # Get legend as accessible name
        #
        if ( ! ($legend_text_value{$fieldset_tag_index} =~ /^\s*$/) ) {
            $accessible_name = $legend_text_value{$fieldset_tag_index};
        }
        #
        # Do we have a title attribute?
        #
        elsif ( defined($$attr_list{"title"}) ) {
            $accessible_name = $$attr_list{"title"};
        }
    }
    #
    # Is this another form element role?
    #
    elsif ( Is_Form_Role($role) ) {
        #
        # Do we have a label?  Check for an id attribute. If there is no
        # corresponding label it will be reported WCAG_2.0-F68.
        # Check to see if this is a native tag. Test native
        # tag by seeing if the supplied role matched the implicit role.
        #
        print "Form element role\n" if $debug;
        if ( ($current_tag_object->attr_value("id") ne "") &&
             ($role eq $implicit_role) ) {
            $accessible_name = $$attr_list{"id"};
        }
        #
        # Are we inside a label? and is this a native tag. Test native
        # tag by seeing if the supplied role matched the implicit role.
        #
        elsif ( $inside_label && ($role eq $implicit_role) ) {
            $accessible_name = "Inside label";
        }
        #
        #
        # Do we have a non-empty title attribute?
        #
        elsif ( $current_tag_object->attr_value("title") ne "" ) {
            $accessible_name = $current_tag_object->attr_value("title");
        }
    }
    #
    # Is this a figure?
    #
    elsif ( $role eq "figure" ) {
        #
        # Do we have a figcaption?
        #
        if ( $have_figcaption ) {
            $accessible_name = "figcaption";
        }
        #
        # Do we have a non-empty title attribute?
        #
        elsif ( $current_tag_object->attr_value("title") ne "" ) {
            $accessible_name = $current_tag_object->attr_value("title");
        }
    }
    #
    # Is this a heading?
    #
    elsif ( $role eq "heading" ) {
        #
        # Do we have heading content?
        #
        if ( scalar(@text_handler_all_text) > 0 ) {
            $accessible_name = join("", @text_handler_all_text);
            $accessible_name =~ s/^\s+//g;
        }
    }
    #
    # Is this an image?
    #
    elsif ( $role eq "img" ) {
        #
        # Do we have an alt attribute?
        #
        if ( defined($$attr_list{"alt"}) ) {
            $accessible_name = $$attr_list{"alt"};
        }
        #
        # Do we have a title attribute?
        #
        elsif ( defined($$attr_list{"title"}) ) {
            $accessible_name = $$attr_list{"title"};
        }
    }
    #
    # Is this a link?
    #
    elsif ( $role eq "link" ) {
        #
        # Do we have an area tag with an alt attribute?
        #
        if ( ($tagname eq "area") && defined($$attr_list{"alt"}) ) {
            $accessible_name = $$attr_list{"alt"};
        }
        #
        # Do we have link content?
        #
        elsif ( scalar(@text_handler_all_text) > 0 ) {
            $accessible_name = join("", @text_handler_all_text);
            $accessible_name =~ s/^\s+//g;
        }
        
        #
        # Did we get an accessible name?
        #
        if ( $accessible_name eq "" ) {
            #
            # Do we have a title in the last image seen?
            #
            if ( $last_img_title ne "" ) {
                $accessible_name = $last_img_title;
            }
            #
            # Do we have a title attribute?
            #
            elsif ( defined($$attr_list{"title"}) ) {
                $accessible_name = $$attr_list{"title"};
            }
        }
    }
    #
    # Is this a summary?
    #
    elsif ( $role eq "summary" ) {
        #
        # Get tag content as accessible name
        #
        $content = Clean_Text(Get_Text_Handler_Content($self, " "));
        if ( (! $content =~ /^\s*$/) ) {
            $accessible_name = $content;
        }
        #
        # Do we have a non-empty title attribute?
        #
        elsif ( $current_tag_object->attr_value("title") ne "" ) {
            $accessible_name = $$attr_list{"title"};
        }
    }
    #
    # Check for possible accessible name from content
    #
    elsif ( defined($aria_accessible_name_content_match{$role}) ) {
        #
        # Use the content of the tag as the accessible name
        #
        print "Accessible name from content\n" if $debug;
        $content = Clean_Text(Get_Text_Handler_Content($self, " "));
        if ( (! $content =~ /^\s*$/) ) {
            $accessible_name = $content;
        }
    }
    #
    # Check for possible title attribute
    #
    else {
        print "End case, check title attribute\n" if $debug;
        if ( $current_tag_object->attr_value("title") ne "" ) {
            $accessible_name = $$attr_list{"title"};
        }
    }

    #
    # Return the accessible name after trimming leading and trailing
    # whitespace
    #
    $accessible_name =~ s/^\s*//;
    $accessible_name =~ s/\s*$//;
    print "Accessible name is \"$accessible_name\"\n" if $debug;
    return($accessible_name);
}

#***********************************************************************
#
# Name: Check_Accessible_Name_from_Content
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function checks to see if the tag and/or it's role supports
# accessible name from content functionality.  If it does, then the content
# of the tag is checked against the accessible name to ensure the content
# appears in the accessible name.  The accessible name computation is
# defined in https://www.w3.org/TR/accname-1.1/
#
#***********************************************************************
sub Check_Accessible_Name_from_Content {
    my ($self, $tagname, $line, $column, $text) = @_;

    my ($accessible_name, $content, $pos, $role);

    #
    # Does the tag contain a role that supports accessible name from content?
    #
    print "Check_Accessible_Name_from_Content $tagname\n" if $debug;
    if ( defined($current_tag_object) &&
         $current_tag_object->accessible_name_content() ) {
        #
        # Get tag content
        #
        $content = Clean_Text(Get_Text_Handler_Content($self, " "));
        
        #
        # Get the tag's role
        #
        $role = $current_tag_object->explicit_role();
        if ($role eq "" ) {
            $role = $current_tag_object->implicit_role();
        }
        
        #
        # Get the accessible name for the tag
        #
        $accessible_name = Get_Accessible_Name($self, $tagname, $line,
                                               $column, $text, $role);

        #
        # Do we have an accessible name?
        #
        if ( $accessible_name ne "" ) {
            #
            # Is there content for the tag?
            #
            print "Have accessible name \"$accessible_name\" for tag\n" if $debug;
            if ( $content ne "" ) {
                #
                # Convert strings to lower case for comparisons as
                # the match is not case sensitive.
                #
                print "Tag content is \"$content\"\n" if $debug;
                $content = lc($content);
                $accessible_name = lc($accessible_name);

                #
                # Is the tag content at the beginning of the accessible name?
                #
                $pos = index($accessible_name, $content);
                if ( $pos == 0 ) {
                    #
                    # Content found in accessible name at the beginning
                    #
                    print "Tag content is at the beginning of the accessible name\n" if $debug;
                }
                #
                # Is the content in the accessible name, but not at the beginning
                #
                elsif ( $pos > 0 ) {
                    print "Tag content is not at the beginning of the accessible name\n" if $debug;
#                    Record_Result("AXE-Label_content_name_mismatch",
#                                  $line, $column, $text,
#                                  String_Value("Accessible name does not begin with visible text"));
                }
                else {
                    #
                    # Tag content is not in the accessible name, check to see if
                    # the accessible name is in the text (i.e. the accessible
                    # name is a substring of the visable text).
                    #
                    print "Tag content is not in the aria-label\n" if $debug;
                    $pos = index($content, $accessible_name);
                    if ( $pos != -1 ) {
#                        Record_Result("AXE-Label_content_name_mismatch",
#                                      $line, $column, $text,
#                                      String_Value("Not all of visible text is included in accessible name"));
                    }
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Accessible_Name
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - tag attributes
#
# Description:
#
#   This function checks the accessible name for the current tag.
#
#***********************************************************************
sub Check_Accessible_Name {
    my ($self, $tagname, $line, $column, $text, %attr) = @_;
    
    my ($accessible_name, $role, $tcid, $this_role);
    
    #
    # Get the tag's role
    #
    print "Check_Accessible_Name\n" if $debug;
    if ( defined($current_tag_object) ) {
        $role = $current_tag_object->explicit_role();
        if ($role eq "" ) {
            $role = $current_tag_object->implicit_role();
        }
    }
    else {
        $role = "";
    }

    #
    # Get the accessible name for the tag
    #
    $accessible_name = Get_Accessible_Name($self, $tagname, $line,
                                           $column, $text, $role);
                                           
    #
    # Check if the accessible name is blank
    #
    if ( $accessible_name eq "" ) {
        #
        # Check tag role to determine the testcase identifier to report
        # the error under.
        #
        if ( Is_Role_in_Role_list($role,
                                  " checkbox combobox listbox menuitemcheckbox menuitemradio radio searchbox slider spinbutton switch textbox ") ) {
            $tcid = "ACT-Form_field_non_empty_accessible_name";
        }
        #
        # Is this an iframe element?
        #
        elsif ( $tagname eq "iframe" ) {
            $tcid = "ACT-iframe_non_empty_accessible_name";
        }
        #
        # Is this a decorative image?
        #
        elsif ( ($role eq "img") &&
                Is_Image_Decorative($tagname, $line, $column, $text, %attr) ) {
            $tcid = "ACT-Image_non_empty_accessible_name";
        }
        #
        # Is this an image button
        #
        elsif ( ($tagname eq "input") &&
                ($current_tag_object->attr_value("type") eq "image") ) {
            $tcid = "ACT-Image_button_non_empty_accessible_name";
        }
        #
        # Is this a link?
        #
        elsif ( $role eq "link" ){
            $tcid = "ACT-Link_non_empty_accessible_name";
        }
        #
        # Is this a heading?
        #
        elsif ( $role eq "heading" ){
            $tcid = "ACT-Heading_non_empty_accessible_name";
        }
        #
        # Is this a menuitem?
        #
        elsif ( $role eq "menuitem" ){
            $tcid = "ACT-Menuitem_non_empty_accessible_name";
        }
        #
        # Is this an object tag?
        #
        elsif ( $tagname eq "object" ){
            $tcid = "ACT-Object_non_empty_accessible_name";
        }

        #
        # Report error if the tag has no accessible name when one
        # is expected.
        #
        if ( defined($tcid) ) {
            Record_Result($tcid, $line, $column, $text,
                          String_Value("Tag has empty accessible name"));
        }
    }
    else {
        #
        # Non blank accessible name, is the tag not in the accessible tree?
        #
        # Is this an image?
        #
        if ( $role eq "img" ) {
            #
            # Is the image hidden?
            #
            if ( $current_tag_object->attr_value("aria-hidden") eq "true" ) {
                $tcid = "ACT-Image_not_accessible_is_decorative";
            }
            #
            # Is the role none or presentational?
            #
            elsif ( ($current_tag_object->attr_value("role") eq "none") ||
                    ($current_tag_object->attr_value("role") eq "presentation") ) {
                $tcid = "ACT-Image_not_accessible_is_decorative";
            }

            #
            # Report error if the tag has an accessible name when none
            # is expected.
            #
            if ( defined($tcid) ) {
                Record_Result($tcid, $line, $column, $text,
                              String_Value("Tag has accessible name but not in the accessible tree"));
            }
        }
    }
}

#***********************************************************************
#
# Name: Explicit_Role_Checks
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function performs checks on tags that have an explcit
# role set on the corresponding start tag.
#
#***********************************************************************
sub Explicit_Role_Checks {
    my ($self, $tagname, $line, $column, $text) = @_;

    my ($explicit_role);

    #
    # Does the start tag have an explicit role that changes its
    # behaviour? Don't consider roles none or presentation as
    # role changes.
    #
    if ( defined($current_tag_object) ) {
        $explicit_role = $current_tag_object->explicit_role();
    }
    if ( defined($explicit_role) && ($explicit_role ne "") &&
         ($explicit_role ne "none") && ($explicit_role ne "presentation") ) {
         
        #
        # Perform checks based on the explicit role value
        #
        if ( $explicit_role eq "button" ) {
            End_Button_Role_Handler($self, $tagname, $line, $column, $text);
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
    my ($last_item, $tag_item, $this_close_tag_hidden);
    
    #
    # Save current end tag name
    #
    print "End_Handler tag $tagname at $line:$column\n" if $debug;
    $current_end_tag = $tagname;

    #
    # Check end tag order, does this end tag close the last open
    # tag ?
    #
    Check_End_Tag_Order($self, $tagname, $line, $column, $text, @attr);
    
    #
    # Check to see if this tag has an accessible name.
    #
    Check_Accessible_Name($self, $tagname, $line, $column, $text, @attr);
    
    #
    # Check to see if this tag supports accessible name from content for
    # speech input users.
    #
    Check_Accessible_Name_from_Content($self, $tagname, $line, $column, $text);
    
    #
    # Explicit role checks
    #
    Explicit_Role_Checks($self, $tagname, $line, $column, $text);
    
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
    # Check frame tag
    #
    elsif ( $tagname eq "frame" ) {
        End_Frame_Tag_Handler($self, $tagname, $line, $column, $text);
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
    # Check iframe tag
    #
    elsif ( $tagname eq "iframe" ) {
        End_Frame_Tag_Handler($self, $tagname, $line, $column, $text);
    }

    #
    # Check label tag
    #
    elsif ( $tagname eq "label" ) {
        End_Label_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check legend tag
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
    # Check pre tag
    #
    elsif ( $tagname eq "pre" ) {
        End_Pre_Tag_Handler($self, $line, $column, $text);
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
    # Check for required children roles for this tag
    #
    Check_Required_Children_Roles($self, $tagname, $line, $column, $text);
    
    #
    # Determine if the content of this tag is hidden or not
    #
    if ( (! $tag_is_visible) || $tag_is_hidden || $tag_is_aria_hidden ) {
        $this_close_tag_hidden = 1;
    }
    else {
        $this_close_tag_hidden = 0;
    }

    #
    # Restore global tag visibility and hidden status values.
    #
    $last_item = @tag_order_stack - 1;
    if ( $last_item >= 0 ) {
        $tag_item = $tag_order_stack[$last_item];
        $current_tag_styles = $tag_item->styles;
        $tag_is_visible = $tag_item->is_visible;
        $tag_is_hidden = $tag_item->is_hidden;
        $tag_is_aria_hidden = $tag_item->is_aria_hidden;
        $last_start_tag = $tag_item->tag;
        $current_landmark = $tag_item->landmark();
        $landmark_marker = $tag_item->landmark_marker();

        #
        # Reset current tag object to be the parent tag
        #
        $current_tag_object = $tag_order_stack[$last_item];
        
        #
        # Set parent tag object
        #
        $last_item = @tag_order_stack;
        if ( $last_item > 0 ) {
            $parent_tag_object = $tag_order_stack[$last_item - 1];
        }
        else {
            undef($parent_tag_object);
        }

    }
    else {
        $current_tag_styles = "";
        $tag_is_visible = 1;
        $tag_is_hidden = 0;
        $tag_is_aria_hidden = 0;
        $last_start_tag = "";
        $current_landmark = "";
        $landmark_marker = "";
        undef($current_tag_object);
        undef($parent_tag_object);
    }
    print "Restore tag_is_visible = $tag_is_visible for last start tag $last_start_tag\n" if $debug;
    print "Restore tag_is_hidden = $tag_is_hidden for last start tag $last_start_tag\n" if $debug;
    print "Restore tag_is_aria_hidden = $tag_is_aria_hidden for last start tag $last_start_tag\n" if $debug;

    #
    # Destroy the text handler that was used to save the text
    # portion of this tag.
    #
    Destroy_Text_Handler($self, $tagname, $this_close_tag_hidden);
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
    my ($label_is_visible, $label_is_hidden, $input_is_visible);
    my ($input_is_hidden, $label_is_aria_hidden);

    #
    # Check that a label is defined for each one referenced
    #
    print "Check_Missing_And_Extra_Labels_In_Form\n" if $debug;
    foreach $label_id (keys %input_id_location) {
        #
        # Did we find a <label> tag with a matching for= value ?
        #
        ($line, $column, $input_is_visible, $input_is_hidden) =
            split(/:/, $input_id_location{"$label_id"});
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
            ($line, $column, $label_is_visible,
             $label_is_hidden, $label_is_aria_hidden) =
                split(/:/, $label_for_location{"$label_id"});
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
            #
            # Is the input visible and the label aria-hidden ?
            #
            elsif (  $tag_is_visible && $label_is_aria_hidden ) {
                Record_Result("WCAG_2.0-H44", $line, $column, "",
                              String_Value("Label referenced by") .
                              " 'id=\"$label_id\"' " .
                              String_Value("is inside aria-hidden tag") . ". <label> " .
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
# Name: Check_Nonexistant_ID
#
# Parameters: none
#
# Description:
#
#   This function checks to see if there are any ID references that
# do not have a matching ID value (referenced but not defined).
#
#***********************************************************************
sub Check_Nonexistant_ID {

    my ($aria_id, $id, $line, $column, $tag, $tcid);
    my ($id_line, $id_column, $id_is_visible, $id_is_hidden, $id_tag);

    #
    # Are we checking for missing ARIA aria-describedby values ?
    #
    print "Check_Nonexistant_ID\n" if $debug;
    foreach $aria_id (keys %id_value_references) {
        #
        # Did we find a tag with a matching id=value ?
        #
        ($id, $line, $column, $tag, $tcid) = split(/:/, $id_value_references{"$aria_id"});
        print "Check id_value_references $id:$line:$column:$tag:$tcid\n" if $debug;
        if ( ! defined($id_attribute_values{"$id"}) ) {
            #
            # Record error
            #
            Record_Result($tcid, $line, $column, "",
                          String_Value("No tag with id attribute") .
                          "'$id'");
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
    print "Check_Document_Errors\n" if $debug;
    if ( $embed_noembed_count > 0 ) {
        Record_Result("WCAG_2.0-H46", $last_embed_line, $last_embed_col, "",
                      String_Value("No matching noembed for embed"));
    }

    #
    # Are we missing the <title> tag in the document ?
    #
    if ( ! $found_title_tag ) {
        #
        # Are we checking WCAG rules? WCAG requires the title in the
        # <head> section.
        #
        if ( defined($$current_tqa_check_profile{"WCAG_2.0-H25"}) ) {
            Record_Result("WCAG_2.0-H25", -1,  0, "",
                          String_Value("Missing <title> tag"));
        }
        #
        # Are we missing a <title> tag in the <body>. ACT rules
        # accept the <title> in the body tag.
        #
        elsif ( ! $found_title_tag_in_body ) {
            Record_Result("ACT-HTML_page_title_non_empty", -1,  0, "",
                          String_Value("Missing <title> tag"));
        }
    }
    
    #
    # Did we find an h1 tag in the document?
    #
    if ( ! $found_h1 ) {
#        Record_Result("AXE-Page_has_heading_one", -1,  0, "",
#                      String_Value("No level one heading found"));
    }
    
    #
    # Do we have more than 1 main landmark?
    #
    if ( defined($landmark_count{"main"}) && ($landmark_count{"main"} > 1) ) {
#        Record_Result("AXE-Landmark_one_main", -1,  0, "",
#                      String_Value("Page contains more than 1 landmark with") .
#                      " role=\"main\"");
    }

    #
    # Do we have more than 1 banner landmark?
    #
    if ( defined($landmark_count{"banner"}) && ($landmark_count{"banner"} > 1) ) {
#        Record_Result("AXE-Landmark_no_duplicate_banner", -1,  0, "",
#                      String_Value("Page contains more than 1 landmark with") .
#                      " role=\"banner\"");
    }

    #
    # Do we have more than 1 contentinfo landmark?
    #
    if ( defined($landmark_count{"contentinfo"}) && ($landmark_count{"contentinfo"} > 1) ) {
#        Record_Result("AXE-Landmark_no_duplicate_contentinfo", -1,  0, "",
#                      String_Value("Page contains more than 1 landmark with") .
#                      " role=\"contentinfo\"");
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
    # Do we have and references to ID values that do not exist?
    #
    Check_Nonexistant_ID();

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
# Name: Check_Errors_Reported_In_Validation
#
# Parameters: validation_output - output from validation tool
#
# Description:
#
#   This function checks the output from the validation tool for
# errors that were reported.
#
#***********************************************************************
sub Check_Errors_Reported_In_Validation {
    my ($validation_output) = @_;
    
    my ($result_object);

    #
    # Check for duplicate attributes error
    #
    #
    # Check for duplicate attributes.
    # Check validation output for HTML5 and XHTML.
    #
    if ( ($validation_output =~ /Error: Duplicate attribute '[a-z]+'./im) ||
         ($validation_output =~ /duplicate specification of attribute "[a-z]+"/im) ) {
        $result_object = Record_Result("WCAG_2.0-F70,ACT-Attribute_is_not_duplicate", -1, -1, $validation_output,
                                       String_Value("Duplicatge attribute in tag"));

        if ( defined($result_object) ) {
            #
            # Reset the source line value of the testcase error result.
            # The initial setting may have been truncated while in this
            # case we want the entire value.
            #
            $result_object->source_line($validation_output);
        }
    }

    #
    # Check for invalid tag nesting (e.g. unclosed tag, stray
    # end tag, etc.).
    # Check validation output for HTML5 and XHTML.
    #
    if ( ($validation_output =~ /Error: No '[a-z]+' element in scope but a '[a-z]+' end tag seen/im) ||
         ($validation_output =~ /end tag for "[a-z]+" omitted, but OMITTAG NO/im) ) {
        $result_object = Record_Result("WCAG_2.0-H88", -1, -1, $validation_output,
                                       String_Value("Invalid tag nesting"));

        if ( defined($result_object) ) {
            #
            # Reset the source line value of the testcase error result.
            # The initial setting may have been truncated while in this
            # case we want the entire value.
            #
            $result_object->source_line($validation_output);
        }
    }

    #
    # Check for invalid role attribute values.
    #
    if ( $validation_output =~ /Error: Bad value '[a-z\s\-]+' for attribute 'role' on element '[a-z]+'/im ) {
        $result_object = Record_Result("WCAG_2.0-H88,ACT-Role_valid_value", -1, -1, $validation_output,
                                       String_Value("Invalid role value"));

        if ( defined($result_object) ) {
            #
            # Reset the source line value of the testcase error result.
            # The initial setting may have been truncated while in this
            # case we want the entire value.
            #
            $result_object->source_line($validation_output);
        }
    }
    #
    # Check for other invalid attribute values.
    #
    elsif ( $validation_output =~ /Error: Bad value '[a-z\s\-]+' for attribute '[a-z]+' on element '[a-z]+'/im ) {
        $result_object = Record_Result("WCAG_2.0-H88", -1, -1, $validation_output,
                                       String_Value("Invalid attribute value"));

        if ( defined($result_object) ) {
            #
            # Reset the source line value of the testcase error result.
            # The initial setting may have been truncated while in this
            # case we want the entire value.
            #
            $result_object->source_line($validation_output);
        }
    }
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
#             logged_in - flag to indicate if we are logged into an
#               application
#
# Description:
#
#   This function runs a number of technical QA checks on HTML content.
#
#***********************************************************************
sub HTML_Check {
    my ($this_url, $language, $profile, $resp, $content, $links,
        $logged_in) = @_;

    my ($parser, @tqa_results_list, $result_object, $testcase);
    my ($lang_code, $lang, $status, $css_content, %on_page_styles);
    my ($selector, $style, @other_results, $validation_output);

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
        # Get any validation output. Some errors are detected by the
        # validator that may not exist in the content provided here.
        # The mark up may have been adjusted by the browser to eliminate
        # mark up errors.  The mark up validation was run on the raw HTML.
        #
        $validation_output = Validate_Markup_Last_Validation_Output($this_url);
        Check_Errors_Reported_In_Validation($validation_output);
        
        #
        # Are we doing Pa11y checks (https://github.com/pa11y/pa11y) ?
        # Can only be done if we are not logged into an application
        #
        if ( (! $logged_in) && defined($$current_tqa_check_profile{"Pa11y"}) ) {
            print "Run Pa11y checks\n" if $debug;
            @other_results = Pa11y_Check($this_url, $language, $profile, $resp, $content);
            
            foreach $result_object (@other_results) {
                push(@tqa_results_list, $result_object);
            }
        }

        #
        # Are we doing Deque Axe checks (https://github.com/dequelabs/axe-core) ?
        # Can only be done if we are not logged into an application
        #
        if ( (! $logged_in) && defined($$current_tqa_check_profile{"AXE"}) ) {
            print "Run Deque Axe checks\n" if $debug;
            @other_results = Deque_AXE_Check($this_url, $language, $profile, $resp, $content);

            foreach $result_object (@other_results) {
                push(@tqa_results_list, $result_object);
            }
        }

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
            # top language choices were too close.  Don't report an error.
            #
            #Record_Result("WCAG_2.0-H57", -1, -1, "",
            #              String_Value("Unable to determine content language, possible languages are") .
            #              " " . join(", ", TextCat_Too_Close_Languages()));
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
    # Clear the global flag indicating that HTML content is from an EPUB
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

