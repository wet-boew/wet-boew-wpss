#***********************************************************************
#
# Name: tqa_wai_aria.pm
#
# $Revision: 1856 $
# $URL: svn://10.36.148.185/WPSS_Tool/TQA_Check/Tools/tqa_wai_aria.pm $
# $Date: 2020-09-15 07:07:00 -0400 (Tue, 15 Sep 2020) $
#
# Description:
#
#   This file defines functions to handle WAI Aria role values
# and relationships.
#
# Public functions:
#     TQA_WAI_Aria_Debug
#     TQA_WAI_Aria_Landmark_Role
#     TQA_WAI_Aria_Required_Context_Roles
#     TQA_WAI_Aria_Required_Owned_Elements
#     TQA_WAI_Aria_Role_Classification
#
# Terms and Conditions of Use
#
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is
# distributed under the MIT License.
#
# MIT License
#
# Copyright (c) 2020 Government of Canada
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

#
# Check for module to share data structures between threads
#
my $have_threads = eval 'use threads; 1';
if ( $have_threads ) {
    $have_threads = eval 'use threads::shared; 1';
}
use strict;
use warnings;
use URI::URL;
use File::Basename;
use XML::Parser;

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;

#
# WAI Aria taxonomy file location
#
my ($WAI_ARIA_TAXONOMY) = "lib/aria-1.rdf";


#
# Required owned elements for WAI-ARIA role values
#   https://www.w3.org/TR/wai-aria-1.1/
# Key is a role and the value is a space seperated list of owned elements.
#
# The values are role:scope tag resources for the owl:Class
# tags in the aria-1.rdf file.
#
my (%aria_required_owned_elements);

#
# Required context (i.e. parent) roles for WAI-ARIA role values
#   https://www.w3.org/TR/wai-aria-1.1/
# Key is a role and the value is a space seperated list of context roles.
#
# The values are role:mustContain tag resources for the owl:Class
# tags in the aria-1.rdf file.
#
my (%aria_required_context_roles);

#
# Supported aria properties for WAI-ARIA roles
#   https://www.w3.org/TR/html-aria/#allowed-aria-roles-states-and-properties
# Key is role name and the value is a space seperated list of properties.
#
# The values are role:supportedState tag resources for the owl:Class
# tags in the aria-1.rdf file.
#
my (%aria_supported_properties);

#
# Required aria properties for WAI-ARIA roles
#   https://www.w3.org/TR/html-aria/#allowed-aria-roles-states-and-properties
# Key is role name and the value is a space seperated list of properties.
#
# The values are role:requiredState tag resources for the owl:Class
# tags in the aria-1.rdf file.
#
my (%aria_required_properties);

#
# WAI-ARIA landmark role values
#  https://www.w3.org/TR/wai-aria-1.1/#landmark_roles
#
# The values are the rdf:ID values of owl:Class tags that contain
# rdfs:subClassOf tags with resource values of "#landmark"
# in the aria-1.rdf file.
#
my (%landmark_role);

#
# Variables shared between threads
#
my ($read_aria_taxonomy) = 0;
if ( $have_threads ) {
    share(\$read_aria_taxonomy);
    share(\%aria_required_owned_elements);
    share(\%aria_required_context_roles);
    share(\%aria_required_properties);
    share(\%landmark_role);
}

#
# List of valid WAI-ARIA role values and their classification
#
#  https://www.w3.org/WAI/PF/aria/roles#abstract_roles
#
my (%aria_role_classification) = (
    #
    # Abstract Roles
    #
    # Abstract roles are used for the ontology. Authors MUST NOT use
    # abstract roles in content.
    #
    "command",     "abstract",
    "composite",   "abstract",
    "input",       "abstract",
    "landmark",    "abstract",
    "range",       "abstract",
    "roletype",    "abstract",
    "section",     "abstract",
    "sectionhead", "abstract",
    "select",      "abstract",
    "structure",   "abstract",
    "widget",      "abstract",
    "window",      "abstract",

    #
    # Widget Roles
    #
    # The following roles act as standalone user interface widgets
    # or as part of larger, composite widgets.
    #
    "alert",            "widget",
    "alertdialog",      "widget",
    "button",           "widget",
    "checkbox",         "widget",
    "dialog",           "widget",
    "gridcell",         "widget",
    "link",             "widget",
    "log",              "widget",
    "marquee",          "widget",
    "menuitem",         "widget",
    "menuitemcheckbox", "widget",
    "menuitemradio",    "widget",
    "option",           "widget",
    "progressbar",      "widget",
    "radio",            "widget",
    "scrollbar",        "widget",
    "slider",           "widget",
    "spinbutton",       "widget",
    "status",           "widget",
    "tab",              "widget",
    "tabpanel",         "widget",
    "textbox",          "widget",
    "timer",            "widget",
    "tooltip",          "widget",
    "treeitem",         "widget",

    #
    # The following roles act as composite user interface widgets.
    # These roles typically act as containers that manage other,
    # contained widgets.
    #
    "combobox",   "composite",
    "grid",       "composite",
    "listbox",    "composite",
    "menu",       "composite",
    "menubar",    "composite",
    "radiogroup", "composite",
    "tablist",    "composite",
    "tree",       "composite",
    "treegrid",   "composite",

    #
    #  Document Structure
    #
    # The following roles describe structures that organize content
    # in a page. Document structures are not usually interactive.
    #
    "article",      "document",
    "columnheader", "document",
    "definition",   "document",
    "directory",    "document",
    "document",     "document",
    "group",        "document",
    "heading",      "document",
    "img",          "document",
    "list",         "document",
    "listitem",     "document",
    "math",         "document",
    "none",         "document",
    "note",         "document",
    "presentation", "document",
    "region",       "document",
    "row",          "document",
    "rowgroup",     "document",
    "rowheader",    "document",
    "separator",    "document",
    "toolbar",      "document",

    #
    # Landmark Roles
    #
    # The following roles are regions of the page intended as navigational
    # landmarks. All of these roles inherit from the landmark base type and,
    # with the exception of application, all are imported from the
    # Role Attribute [ROLE]. The roles are included here in order to
    # make them clearly part of the WAI-ARIA Role taxonomy.
    #
    "application",   "landmark",
    "banner",        "landmark",
    "complementary", "landmark",
    "contentinfo",   "landmark",
    "form",          "landmark",
    "main",          "landmark",
    "navigation",    "landmark",
    "search",        "landmark",

    #
    # EPUB Roles from
    #   EPUB and WAI-ARIA structural semantis mapping
    #   https://idpf.github.io/epub-guides/aria-mapping/
    #
    "cell",                 "epub",
    "definition",           "epub",
    "directory",            "epub",
    "doc-abstract",         "epub",
    "doc-acknowledgments",  "epub",
    "doc-appendix",         "epub",
    "doc-backlink",         "epub",
    "doc-biblioentry",      "epub",
    "doc-bibliography",     "epub",
    "doc-biblioref",        "epub",
    "doc-chapter",          "epub",
    "doc-colophon",         "epub",
    "doc-conclusion",       "epub",
    "doc-cover",            "epub",
    "doc-credit",           "epub",
    "doc-credits",          "epub",
    "doc-dedication",       "epub",
    "doc-endnote",          "epub",
    "doc-endnotes",         "epub",
    "doc-epigraph",         "epub",
    "doc-epilogue",         "epub",
    "doc-errata",           "epub",
    "doc-footnote",         "epub",
    "doc-foreword",         "epub",
    "doc-glossary",         "epub",
    "doc-glossref",         "epub",
    "doc-index",            "epub",
    "doc-introduction",     "epub",
    "doc-noteref",          "epub",
    "doc-notice",           "epub",
    "doc-pagebreak",        "epub",
    "doc-pagelist",         "epub",
    "doc-part",             "epub",
    "doc-preface",          "epub",
    "doc-prologue",         "epub",
    "doc-pullquote",        "epub",
    "doc-qna",              "epub",
    "doc-subtitle",         "epub",
    "doc-tip",              "epub",
    "doc-toc",              "epub",
    "figure",               "epub",
#    "list",                 "epub",  # Already defined
#    "listitem",             "epub",  # Already defined
#    "row",                  "epub",  # Already defined
    "table",                "epub",
    "term",                 "epub",

);


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
# The underscore character (_) represents a literal space in a multi-word
# value (e.g. "hello_there" = "hello there").
#
my (%valid_aria_attribute_values) = (
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
my (%role_specific_aria_properties) = (
    "alert",               " aria-expanded ",
    "alertdialog",         " aria-expanded aria-modal ",
    "application",         " aria-activedescendant aria-expanded ",
    "article",             " aria-expanded ",
    "banner",              " aria-expanded ",
    "button",              " aria-expanded aria-pressed ",
    "checkbox",            " aria-checked aria-readonly ",
    "cell",                " aria-colspan aria-colindex aria-rowindex aria-rowspan ",
    "columnheader",        " aria-sort aria-readonly aria-required aria-selected aria-expanded aria-colspan aria-colindex aria-rowindex aria-rowspan ",
    "combobox",            " aria-controls aria-expanded aria-autocomplete aria-required aria-activedescendant aria-orientation ",
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
    "menuitemcheckbox",    " aria-checked aria-posinset aria-setsize ",
    "menuitemradio",       " aria-checked aria-posinset aria-setsize ",
    "navigation",          " aria-expanded ",
    "none",                "",
    "note",                " aria-expanded ",
    "option",              " aria-checked aria-posinset aria-selected aria-setsize ",
    "presentation",        "",
    "progressbar",         " aria-valuemax aria-valuemin aria-valuenow aria-valuetext ",
    "radio",               " aria-checked aria-posinset aria-selected aria-setsize ",
    "radiogroup",          " aria-required aria-activedescendant aria-expanded aria-orientation ",
    "region",              " aria-expanded ",
    "row",                 " aria-colindex aria-rowindex aria-level aria-selected aria-activedescendant aria-expanded ",
    "rowgroup",            "",
    "rowheader",           " aria-readonly aria-required aria-selected aria-expanded aria-colspan aria-colindex aria-rowindex aria-rowspan ",
    "scrollbar",           " aria-controls aria-orientation aria-valuemax aria-valuemin aria-valuenow aria-expanded aria-valuetext ",
    "search",              " aria-expanded ",
    "searchbox",           " aria-activedescendant aria-autocomplete aria-multiline aria-placeholder aria-readonly aria-required ",
    "separator",           " aria-valuemax aria-valuemin aria-valuenow aria-valuetext aria-orientation ",
    "slider",              " aria-valuemax aria-valuemin aria-valuenow aria-valuetext aria-orientation ",
    "spinbutton",          " aria-valuemax aria-valuemin aria-valuenow aria-valuetext aria-required aria-readonly ",
    "status",              " aria-expanded ",
    "switch",              " aria-checked aria-readonly ",
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

#***********************************************************************
#
# Package: wai_aria_role_object
#
# Parameters: none
#
# Description:
#
#   This object contains the properties of WAI ARIA roles.
#
# Class Methods
#    new - create new object instance
#    id - get/set the survey response id number
#    must_contain - get/set the list of required owned elements
#    required_state - get/set the list of required properties
#    scope - get/set the scope (required context roles)
#    subclass_of - get/set the list of super classes
#    supported_state - get/set the list of supported properties
#
#***********************************************************************

package wai_aria_role_object {

#********************************************************
#
# Name: new
#
# Parameters: id - class id value
#
# Description:
#
#   This function creates a new wai_aria_role_object item and
# initializes it's fields items.
#
#********************************************************
sub new {
    my ($class, $id) = @_;

    my ($self) = {};
    my (@must_contain_elements) = ();
    my (@required_properties) = ();
    my (@scope_roles) = ();
    my (@subclass_of) = ();
    my (@supported_properties) = ();


    #
    # Bless the reference as a tqa_wai_aria_roles class item
    #
    bless $self, $class;

    #
    # Save arguments as object data items and initialize
    # object fields
    #
    print "New TQA WAI Aria role object, class: $id\n" if $debug;
    $self->{"id"} = $id;
    $self->{"must_contain_elements"} = \@must_contain_elements;
    $self->{"required_properties"} = \@required_properties;
    $self->{"scope_roles"} = \@scope_roles;
    $self->{"subclass_of"} = \@subclass_of;
    $self->{"supported_properties"} = \@supported_properties;

    #
    # Return reference to object.
    #
    return($self);
}

#********************************************************
#
# Name: id
#
# Parameters: self - class reference
#             value - content (optional)
#
# Description:
#
#   This function either sets or returns the id
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub id {
    my ($self, $value) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $self->{"id"} = $value;
    }
    else {
        return($self->{"id"});
    }
}

#********************************************************
#
# Name: must_contain
#
# Parameters: self - class reference
#             value - content (optional)
#
# Description:
#
#   This function either sets or returns the must_contain
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub must_contain {
    my ($self, $value) = @_;
    
    my ($list_addr);

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $list_addr = $self->{"must_contain_elements"};
        push(@$list_addr, $value)
    }
    else {
        return($self->{"must_contain_elements"});
    }
}

#********************************************************
#
# Name: required_state
#
# Parameters: self - class reference
#             value - content (optional)
#
# Description:
#
#   This function either adds to or returns the required_state
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub required_state {
    my ($self, $value) = @_;
    
    my ($list_addr);

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $list_addr = $self->{"required_properties"};
        push(@$list_addr, $value)
    }
    else {
        return($self->{"required_properties"});
    }
}

#********************************************************
#
# Name: subclass_of
#
# Parameters: self - class reference
#             value - content (optional)
#
# Description:
#
#   This function either adds to or returns the subclass_of
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub subclass_of {
    my ($self, $value) = @_;

    my ($list_addr);

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $list_addr = $self->{"subclass_of"};
        push(@$list_addr, $value)
    }
    else {
        return($self->{"subclass_of"});
    }
}

#********************************************************
#
# Name: scope
#
# Parameters: self - class reference
#             value - content (optional)
#
# Description:
#
#   This function either adds to or returns the scope
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub scope {
    my ($self, $value) = @_;

    my ($list_addr);

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $list_addr = $self->{"scope_roles"};
        push(@$list_addr, $value)
    }
    else {
        return($self->{"scope_roles"});
    }
}

#********************************************************
#
# Name: supported_state
#
# Parameters: self - class reference
#             value - content (optional)
#
# Description:
#
#   This function either adds to or returns the supported_state
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub supported_state {
    my ($self, $value) = @_;

    my ($list_addr);

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $list_addr = $self->{"supported_properties"};
        push(@$list_addr, $value)
    }
    else {
        return($self->{"supported_properties"});
    }
}

#
# End of package
#
}

#***********************************************************************
#
# Beginning of main package that uses the above package
#
#***********************************************************************
package tqa_wai_aria {

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
use Exporter   ();
use vars qw($VERSION @ISA @EXPORT);

@ISA     = qw(Exporter);
@EXPORT  = qw(TQA_WAI_Aria_Debug
              TQA_WAI_Aria_Landmark_Role
              TQA_WAI_Aria_Required_Context_Roles
              TQA_WAI_Aria_Required_Owned_Elements
              TQA_WAI_Aria_Role_Classification
             );
$VERSION = "1.0";


#***********************************************************************
#
# Object Local variable declarations
#
#***********************************************************************

my ($current_role_object, %aria_role_objects);

#********************************************************
#
# Name: TQA_WAI_Aria_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub TQA_WAI_Aria_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#********************************************************
#
# Name: TQA_WAI_Aria_Landmark_Role
#
# Parameters: role - role value
#
# Description:
#
#   This function returns true if the supplied WAI Aria role
# is a landmark role, otherwise it returns false.
#
#********************************************************
sub TQA_WAI_Aria_Landmark_Role {
    my ($role) = @_;
    
    #
    # Is this a landmark role?
    #
    Load_Aria_Taxonomy();
    print "TQA_WAI_Aria_Landmark_Role $role\n" if $debug;
    return(defined($landmark_role{$role}));
}

#********************************************************
#
# Name: TQA_WAI_Aria_Required_Context_Roles
#
# Parameters: role - role value
#
# Description:
#
#   This function returns a string of the required context
# (i.e. parent) roles for the supplied WAI Aria role. If ther
# are no required context roles, an empty string is returned.
#
#********************************************************
sub TQA_WAI_Aria_Required_Context_Roles {
    my ($role) = @_;
    
    my ($required_roles);

    #
    # Does this role have any required context roles?
    #
    Load_Aria_Taxonomy();
    print "TQA_WAI_Aria_Required_Context_Roles $role\n" if $debug;
    if ( defined($aria_required_context_roles{$role}) ) {
        $required_roles = $aria_required_context_roles{$role};
    }
    else {
        $required_roles = "";
    }

    #
    # Return the required context roles
    #
    print "Required context roles = $required_roles\n" if $debug;
    return($required_roles);
}

#********************************************************
#
# Name: TQA_WAI_Aria_Required_Owned_Elements
#
# Parameters: role - role value
#
# Description:
#
#   This function returns a string of the required owned
# elements for the supplied WAI Aria role. If there are no
# required owned elements, an empty string is returned.
#
#********************************************************
sub TQA_WAI_Aria_Required_Owned_Elements {
    my ($role) = @_;

    my ($required_roles);

    #
    # Does this role have any required owned elements?
    #
    Load_Aria_Taxonomy();
    print "TQA_WAI_Aria_Required_Owned_Elements $role\n" if $debug;
    if ( defined($aria_required_owned_elements{$role}) ) {
        $required_roles = $aria_required_owned_elements{$role};
    }
    else {
        $required_roles = "";
    }

    #
    # Return the required owned elements
    #
    print "Required owned elements = $required_roles\n" if $debug;
    return($required_roles);
}

#********************************************************
#
# Name: TQA_WAI_Aria_Role_Classification
#
# Parameters: role - role value
#
# Description:
#
#   This function returns the classification of the supplied
# WAI Aria role value. If the role is not valid, an empty string
# is returned.
#
#********************************************************
sub TQA_WAI_Aria_Role_Classification {
    my ($role) = @_;

    my ($classification);

    #
    # Is this a valid role?
    #
    print "TQA_WAI_Aria_Role_Classification $role\n" if $debug;
    Load_Aria_Taxonomy();
    if ( defined($aria_role_classification{$role}) ) {
        $classification = $aria_role_classification{$role};
    }
    else {
        $classification = "";
    }

    #
    # Return the classification
    #
    print "Role classification = $classification\n" if $debug;
    return($classification);
}

#***********************************************************************
#
# Name: Start_owl_Class
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start owl:Class tag.
#
#***********************************************************************
sub Start_owl_Class {
    my ($self, %attr) = @_;
    
    my ($role);

    #
    # Check for ID attribute, it is the WAI Aria role
    #
    if ( defined($attr{"rdf:ID"}) && ($attr{"rdf:ID"} ne "") ) {
        $role = $attr{"rdf:ID"};
        
        #
        # Do we already have this role?
        #
        if ( defined($aria_role_objects{$role}) ) {
            $current_role_object = $aria_role_objects{$role};
        }
        else {
            #
            # Create a role object for the details of this role
            #
            $current_role_object = wai_aria_role_object->new($role);
            $aria_role_objects{$role} = $current_role_object;
            print "New ARIA role class $role\n" if $debug;
        }
    }
}

#***********************************************************************
#
# Name: End_owl_Class
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the end owl:Class tag.
#
#***********************************************************************
sub End_owl_Class {
    my ($self) = @_;

    #
    # Clear the current object pointer
    #
    if ( defined($current_role_object) ) {
        print "End ARIA role class " . $current_role_object->id() . "\n" if $debug;
        
        #
        # Dispose of the current role object
        #
        undef($current_role_object);
    }
}

#***********************************************************************
#
# Name: RDFS_Subclass_Of
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start rdfs:subClassOf tag.
#
#***********************************************************************
sub RDFS_Subclass_Of {
    my ($self, %attr) = @_;

    my ($resource);

    #
    # Check for resource attribute
    #
    if ( defined($attr{"rdf:resource"}) && ($attr{"rdf:resource"} ne "") ) {
        $resource = $attr{"rdf:resource"};

        #
        # The resource should be a named anchor in a URL, we just want the
        # anchor portion
        #
        $resource =~ s/^.*#//g;

        #
        # Add resource to the current Aria role object
        #
        if ( defined($current_role_object) ) {
            print "Add subclass $resource to current role\n" if $debug;
            $current_role_object->subclass_of($resource);
        }
    }
}

#***********************************************************************
#
# Name: Role_Must_Contain
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start role:mustContain tag.
#
#***********************************************************************
sub Role_Must_Contain {
    my ($self, %attr) = @_;

    my ($resource);

    #
    # Check for resource attribute
    #
    if ( defined($attr{"rdf:resource"}) && ($attr{"rdf:resource"} ne "") ) {
        $resource = $attr{"rdf:resource"};

        #
        # The resource should be a named anchor in a URL, we just want the
        # anchor portion
        #
        $resource =~ s/^.*#//g;

        #
        # Add resource to the current Aria role object
        #
        if ( defined($current_role_object) ) {
            print "Add required role $resource to current role\n" if $debug;
            $current_role_object->must_contain($resource);
        }
    }
}

#***********************************************************************
#
# Name: Role_Required_State
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start role:requiredState tag.
#
#***********************************************************************
sub Role_Required_State {
    my ($self, %attr) = @_;

    my ($resource);

    #
    # Check for resource attribute
    #
    if ( defined($attr{"rdf:resource"}) && ($attr{"rdf:resource"} ne "") ) {
        $resource = $attr{"rdf:resource"};

        #
        # The resource should be a named anchor in a URL, we just want the
        # anchor portion
        #
        $resource =~ s/^.*#//g;

        #
        # Add resource to the current Aria role object
        #
        if ( defined($current_role_object) ) {
            print "Add required state $resource to current role\n" if $debug;
            $current_role_object->required_state($resource);
        }
    }
}

#***********************************************************************
#
# Name: Role_Scope
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start role:scope tag.
#
#***********************************************************************
sub Role_Scope {
    my ($self, %attr) = @_;

    my ($resource);

    #
    # Check for resource attribute
    #
    if ( defined($attr{"rdf:resource"}) && ($attr{"rdf:resource"} ne "") ) {
        $resource = $attr{"rdf:resource"};
        
        #
        # The resource should be a named anchor in a URL, we just want the
        # anchor portion
        #
        $resource =~ s/^.*#//g;

        #
        # Add resource to the current Aria role object
        #
        if ( defined($current_role_object) ) {
            print "Add scope $resource to current role\n" if $debug;
            $current_role_object->scope($resource);
        }
    }
}

#***********************************************************************
#
# Name: Role_Supported_State
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start role:supportedState tag.
#
#***********************************************************************
sub Role_Supported_State {
    my ($self, %attr) = @_;

    my ($resource);

    #
    # Check for resource attribute
    #
    if ( defined($attr{"rdf:resource"}) && ($attr{"rdf:resource"} ne "") ) {
        $resource = $attr{"rdf:resource"};

        #
        # The resource should be a named anchor in a URL, we just want the
        # anchor portion
        #
        $resource =~ s/^.*#//g;

        #
        # Add resource to the current Aria role object
        #
        if ( defined($current_role_object) ) {
            print "Add supported state $resource to current role\n" if $debug;
            $current_role_object->supported_state($resource);
        }
    }
}

#***********************************************************************
#
# Name: Start_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles the start of XML tags.
#
#***********************************************************************
sub Start_Handler {
    my ($self, $tagname, %attr) = @_;

    #
    # Check tag name
    #
    print "Start_Handler tag $tagname\n" if $debug;
    if ( $tagname eq "owl:cardinality" ) {
        # Ignore this tag
    }
    elsif ( $tagname eq "owl:ObjectProperty" ) {
        # Ignore this tag
    }
    elsif ( $tagname eq "owl:Class" ) {
        Start_owl_Class($self, %attr);
    }
    elsif ( $tagname eq "owl:onProperty" ) {
        # Ignore this tag
    }
    elsif ( $tagname eq "owl:Restriction" ) {
        # Ignore this tag
    }
    elsif ( $tagname eq "rdf:RDF" ) {
        # Ignore this tag
    }
    elsif ( $tagname eq "rdfs:comment" ) {
        # Ignore this tag
    }
    elsif ( $tagname eq "rdfs:domain" ) {
        # Ignore this tag
    }
    elsif ( $tagname eq "rdfs:range" ) {
        # Ignore this tag
    }
    elsif ( $tagname eq "rdfs:seeAlso" ) {
        # Ignore this tag
    }
    elsif ( $tagname eq "rdfs:subClassOf" ) {
        RDFS_Subclass_Of($self, %attr);
    }
    elsif ( $tagname eq "rdfs:subpropertyOf" ) {
        # Ignore this tag
    }
    elsif ( $tagname eq "role:baseConcept" ) {
        # Ignore this tag
    }
    elsif ( $tagname eq "role:mustContain" ) {
        Role_Must_Contain($self, %attr);
    }
    elsif ( $tagname eq "role:nameFrom" ) {
        # Ignore this tag
    }
    elsif ( $tagname eq "role:requiredState" ) {
        Role_Required_State($self, %attr);
    }
    elsif ( $tagname eq "role:scope" ) {
        Role_Scope($self, %attr);
    }
    elsif ( $tagname eq "role:supportedState" ) {
        Role_Supported_State($self, %attr);
    }
    elsif ( $tagname eq "role:nameFrom" ) {
        # Ignore this tag
    }
    else {
        #
        # Unknown tag
        #
        print STDERR "tqa_wai_aria.pm:Load_Aria_Taxonomy: Unknown tag $tagname\n";
    }
}

#***********************************************************************
#
# Name: End_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles end tags.
#
#***********************************************************************
sub End_Handler {
    my ($self, $tagname) = @_;

    #
    # Check tag name
    #
    print "End_Handler tag $tagname\n" if $debug;
    if ( $tagname eq "owl:Class" ) {
        End_owl_Class($self);
    }
}

#***********************************************************************
#
# Name: Load_Aria_Taxonomy
#
# Parameters: none
#
# Description:
#
#   This function reads and parses the ARIA taxonomy RDF file
# to get Aria roles and relationships.
#
#***********************************************************************
sub Load_Aria_Taxonomy {

    my ($parser, $eval_output, $result_object, $FH, $content, $line);
    my ($role_value, $role_object, $list_addr, $value);

    #
    # Have we already read the ARIA taxonomy file?
    #
    if ( $read_aria_taxonomy ) {
        return();
    }

    #
    # Create a document parser
    #
    print "Load_Aria_Taxonomy\n" if $debug;
    $parser = XML::Parser->new;

    #
    # Add handlers for some of the XML tags
    #
    $parser->setHandlers(Start => \&Start_Handler);
    $parser->setHandlers(End => \&End_Handler);

    #
    # Open the ARIA taxonomy RDF file
    #
    if ( ! open($FH, $WAI_ARIA_TAXONOMY) ) {
        print STDERR "Load_Aria_Taxonomy Failed to open file $WAI_ARIA_TAXONOMY\n";
    }
    else {
        #
        # Read the RDF into a local variable
        #
        binmode $FH;
        $content = "";
        while ( $line = <$FH> ) {
            $content .= $line;
        }
        close($FH);

        #
        # Parse the content.
        #
        eval { $parser->parse($content, ErrorContext => 2); 1};
        $eval_output = $@ if $@;

        #
        # Do we have any parsing errors ?
        #
        if ( defined($eval_output) ) {
            print "Parse of Aria taxonomy file complete, output = $eval_output\n" if $debug;
            $eval_output =~ s/\n at .* line \d*$//g;
            $eval_output =~ s/\n at .* line \d* thread \d*\.$//g;
            print STDERR "Parse_Aria_Taxonomy: Failed to parse $WAI_ARIA_TAXONOMY, eval_output = $eval_output\n";
        }
        
        #
        # Copy the details of the roles to tables for quick access
        #
        print "Copy details of the roles to tables for quick access\n" if $debug;
        while ( ($role_value, $role_object) = each %aria_role_objects ) {
            #
            # Required owned for WAI-ARIA role
            #
            print " Role = $role_value\n" if $debug;
            $list_addr = $role_object->must_contain();
            $value = join(" ", @$list_addr);
            print "  aria_required_owned_elements = $value\n" if $debug;
            $aria_required_owned_elements{$role_value} = $value;
        
            #
            # Required context roles for WAI-ARIA role
            #
            $list_addr = $role_object->scope();
            $value = join(" ", @$list_addr);
            print "  aria_required_context_roles = $value\n" if $debug;
            $aria_required_context_roles{$role_value} = $value;

            #
            # Supported aria properties for WAI-ARIA roles
            #
            $list_addr = $role_object->supported_state();
            $value = join(" ", @$list_addr);
            print "  aria_supported_properties = $value\n" if $debug;
            $aria_supported_properties{$role_value} = $value;

            #
            # Required aria properties for WAI-ARIA roles
            #
            $list_addr = $role_object->required_state();
            $value = join(" ", @$list_addr);
            print "  aria_required_properties = $value\n" if $debug;
            $aria_required_properties{$role_value} = $value;

            #
            # WAI-ARIA landmark role values
            #
            $list_addr = $role_object->subclass_of();
            foreach $value (@$list_addr) {
                if ( $value eq "landmark" ) {
                    $landmark_role{$role_value} = 1;
                    print "  landmark role\n" if $debug;
                    last;
                }
            }
        }
    }

    #
    # Set flag to prevent reading the toxonomy file again
    #
    $read_aria_taxonomy = 1;
}

#
# End of package
#
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

