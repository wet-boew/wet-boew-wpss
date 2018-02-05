#***********************************************************************
#
# Name:   epub_html_check.pm
#
# $Revision: 708 $
# $URL: svn://10.36.148.185/TQA_Check/Tools/epub_html_check.pm $
# $Date: 2018-02-02 09:05:18 -0500 (Fri, 02 Feb 2018) $
#
# Description:
#
#   This file contains routines that checks EPUB HTML files.
#
# Public functions:
#     Set_EPUB_HTML_Check_Debug
#     Set_EPUB_HTML_Check_Language
#     Set_EPUB_HTML_Check_Testcase_Data
#     Set_EPUB_HTML_Check_Test_Profile
#     EPUB_HTML_Check
#
# Terms and Conditions of Use
#
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is
# distributed under the MIT License.
#
# MIT License
#
# Copyright (c) 2017 Government of Canada
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

package epub_html_check;

use strict;
use HTML::Parser;
use HTML::Entities;
use File::Basename;

#
# Use WPSS_Tool program modules
#
use language_map;
use tqa_result_object;
use tqa_testcases;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Set_EPUB_HTML_Check_Debug
                  Set_EPUB_HTML_Check_Language
                  Set_EPUB_HTML_Check_Testcase_Data
                  Set_EPUB_HTML_Check_Test_Profile
                  EPUB_HTML_Check
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my ($save_text_between_tags, $saved_text);
my (%testcase_data, $results_list_addr);
my (%epub_check_profile_map, $current_epub_check_profile, $current_url);
my ($first_heading, $page_break_count, @tag_stack, @tag_text_stack);
my ($have_text_handler, @text_handler_tag_list, $current_text_handler_tag);
my ($page_break_tag_index, @tag_stack, @text_handler_text_list);
my (%epub_nav_types, $illustration_count, $inside_landmarks);
my (%landmark_types);

#
# Required landmark type to be found in landmarks section
#
my (%required_landmark_types) = (
    "bodymatter", 1,
    "toc",        1,
);

#
# EPUB and WAI-ARIA structural semantis mapping
#   https://idpf.github.io/epub-guides/aria-mapping/
#
my (%epub_aria_semantic_mapping) = (
    "abstract",         "doc-abstract",
    "acknowledgments",  "doc-acknowledgments",
    "appendix",   	    "doc-appendix",
    "biblioentry",	    "doc-biblioentry",
    "bibliography",	    "doc-bibliography",
    "biblioref",        "doc-biblioref", # draft
    "chapter",          "doc-chapter",
    "colophon",         "doc-colophon",
    "conclusion",       "doc-conclusion",
    "cover",            "doc-cover",
    "credit",           "doc-credit", # draft
    "credits",          "doc-credits", # draft
    "dedication",       "doc-dedication",
    "endnote",          "doc-endnote",
    "endnotes",         "doc-endnotes",
    "epigraph",         "doc-epigraph",
    "epilogue",         "doc-epilogue",
    "errata",           "doc-errata",
    "figure",           "figure",
    "footnote",         "doc-footnote",
    "foreword",         "doc-foreword",
    "glossary",         "doc-glossary",
    "glossterm",        "term",
    "glossdef",         "definition",
    "glossref",         "doc-glossref", # draft
    "index",            "doc-index",
    "introduction",     "doc-introduction",
    "landmarks",        "directory",
    "list",             "list",
    "list-item",        "listitem",
    "noteref",          "doc-noteref",
    "notice",           "doc-notice",
    "pagebreak",        "doc-pagebreak",
    "page-list",        "doc-pagelist",
    "part",             "doc-part",
    "preface",          "doc-preface",
    "prologue",         "doc-prologue",
    "pullquote",        "doc-pullquote", # draft
    "qna",              "doc-qna",
    "referrer",         "doc-backlink", # draft
    "subtitle",         "doc-subtitle",
    "table",            "table",
    "table-row",        "row",
    "table-cell",       "cell",
    "tip",              "doc-tip",
    "toc",              "doc-toc",
    );
my (%aria_epub_semantic_mapping) = reverse %epub_aria_semantic_mapping;

#
# Status values
#
my ($epub_check_pass)       = 0;
my ($epub_check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Content not allowed in page break", "Content not allowed in 'pagebreak'",
    "Duplicate item id",            "Duplicate <item> 'id'",
    "for page break",               "for 'pagebreak'",
    "found",                        "found",
    "Heading level",                "Heading level",
    "Invalid tag used for page break", "Invalid tag used for 'pagebreak'",
    "is greater than first heading","is greater than first heading",
    "matching for",                 "matching for",
    "Missing attribute",            "Missing attribute",
    "Missing content in",           "Missing content in",
    "Missing landmark navigation type", "Missing landmark navigation type",
    "or",                           "or",
);

#
# String table for error strings (French).
#
my %string_table_fr = (
    "Content not allowed in page break", "Contenu non autorisé dans 'pagebreak'",
    "Duplicate item id",            "Doublon <item> 'id' ",
    "for page break",               "pour le 'pagebreak'",
    "found",                        "trouvé",
    "Heading level",                "Niveau d'en-tête",
    "Invalid tag used for page break", "Balise non valide utilisée pour le 'pagebreak'",
    "is greater than first heading","est plus grand que le premier titre",
    "matching for",                 "correspondant à",
    "Missing attribute",            "attribut manquant",
    "Missing content in",           "Contenu manquant dans",
    "Missing landmark navigation type", "Type de navigation landmark manquant",
    "or",                           "ou",
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;


#***********************************************************************
#
# Name: Set_EPUB_HTML_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_EPUB_HTML_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_EPUB_HTML_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_EPUB_HTML_Check_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_EPUB_HTML_Check_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_EPUB_HTML_Check_Language, language = English\n" if $debug;
        $string_table = \%string_table_en;
    }
}

#***********************************************************************
#
# Name: Set_EPUB_HTML_Check_Testcase_Data
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
sub Set_EPUB_HTML_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_EPUB_HTML_Check_Test_Profile
#
# Parameters: profile - EPUB check test profile
#             epub_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by testcase name.
#
#***********************************************************************
sub Set_EPUB_HTML_Check_Test_Profile {
    my ($profile, $epub_checks) = @_;

    my (%local_epub_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_EPUB_HTML_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_epub_checks = %$epub_checks;
    $epub_check_profile_map{$profile} = \%local_epub_checks;
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
    if ( defined($testcase) && defined($$current_epub_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $epub_check_fail,
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
            # We have to create a new text handler top restart the
            # text collection for the previous tag.  We also have to place
            # the saved text back in the handler.
            #
            $saved_text = pop(@text_handler_text_list);
            $self->handler( text => [], '@{dtext}' );
            $have_text_handler = 1;
            print "Push \"$saved_text\" into text handler\n" if $debug;
            push(@{ $self->handler("text")}, $saved_text);

            #
            # Add text from this tag to the previous tag's text handler
            #
            print "Adding \"$current_text\" text to text handler\n" if $debug;
            push(@{ $self->handler("text")}, " $current_text ");
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
    my ($text, $line, $column) = @_;

    my ($this_dtd, @dtd_lines, $testcase);
    my ($top, $availability, $registration, $organization, $type, $label);
    my ($language, $url);
    my ($doctype_label, $doctype_language, $doctype_version, $doctype_class);

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
    }
    print "DOCTYPE label = $doctype_label, version = $doctype_version, class = $doctype_class\n" if $debug;
}

#***********************************************************************
#
# Name: Check_Page_Break_Attributes
#
# Parameters: self - reference to this parser
#             tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             epub_type - epub:type attribute value
#             role - role attribute value
#             attr - hash table of attributes
#
# Description:
#
#   This function checks to see if both EPUB and WAI-ARIA page
# break attributes.
#
#***********************************************************************
sub Check_Page_Break_Attributes {
    my ($self, $tagname, $line, $column, $text, $epub_type, $role, %attr) = @_;

    my ($id, $title);
    
    #
    # Check for epub:type "pagebreak" and role "doc-pagebreak"
    #
    print "Check_Page_Break_Attributes epub:type=$epub_type and role=$role\n" if $debug;
    if ( ($epub_type eq "pagebreak") && ($role eq "doc-pagebreak") ) {
        print "Have epub:type=\"pagebreak\", and role=\"doc-pagebreak\"\n" if $debug;
        #
        # We must have an id and a title/aria-label
        #
        if ( defined($attr{"id"}) ) {
            $id = $attr{"id"};
            print "Have id = \"$id\"\n" if $debug;
            
            #
            # Check for id value
            #
            if ( $id =~ /^\s*$/ ) {
                Record_Result("EPUB-PAGE-001", $line, $column, $text,
                              String_Value("Missing content in") .
                              " 'id' " .
                              String_Value("for page break"));
            }
            else {
                #
                # Check for title attribute
                #
                if ( defined($attr{"title"}) ) {
                    $title = $attr{"title"};
                    print "Have title = \"$title\"\n" if $debug;
                    
                    #
                    # Do we have a value?
                    #
                    if ( $title =~ /^\s*$/ ) {
                        Record_Result("EPUB-PAGE-001", $line, $column, $text,
                                      String_Value("Missing content in") .
                                      " 'title' " .
                                      String_Value("for page break"));
                    }
                }
                #
                # Check for aria-label
                #
                elsif ( defined($attr{"aria-label"}) ) {
                    $title = $attr{"aria-label"};
                    print "Have aria-label = \"$title\"\n" if $debug;

                    #
                    # Do we have a value?
                    #
                    if ( $title =~ /^\s*$/ ) {
                        Record_Result("EPUB-PAGE-001", $line, $column, $text,
                                      String_Value("Missing content in") .
                                      " 'aria-label' " .
                                      String_Value("for page break"));
                    }
                }
                #
                # Missing title or aria-label
                #
                else {
                    Record_Result("EPUB-PAGE-001", $line, $column, $text,
                                  String_Value("Missing attribute") .
                                  " 'title' " . String_Value("or") .
                                  " 'aria-label' " .
                                  String_Value("for page break"));
                }
            }
        }
        else {
            #
            # Missing id attribute for page break
            #
            Record_Result("EPUB-PAGE-001", $line, $column, $text,
                          String_Value("Missing attribute") .
                          " 'id' " .
                          String_Value("for page break"));
        }
    }
    #
    # Check for epub:type "pagebreak" and missing role "doc-pagebreak"
    #
    elsif ( ($epub_type eq "pagebreak") && ($role ne "doc-pagebreak") ) {
        print "Have epub:type=\"pagebreak\", missing role=\"doc-pagebreak\"\n" if $debug;
        Record_Result("EPUB-PAGE-001", $line, $column, $text,
                      String_Value("Missing attribute") .
                      " 'role=\"doc-pagebreak\"' " .
                      String_Value("for page break"));
    }
    #
    # Check for missing epub:type "pagebreak" and role "doc-pagebreak"
    #
    elsif ( ($epub_type ne "pagebreak") && ($role eq "doc-pagebreak") ) {
        print "Missing epub:type=\"pagebreak\", have role=\"doc-pagebreak\"\n" if $debug;
        Record_Result("EPUB-PAGE-001", $line, $column, $text,
                      String_Value("Missing attribute") .
                      " 'epub:type=\"pagebreak\"' " .
                      String_Value("for page break"));
    }
    
    #
    # Check that the tag containing the page break is not an anchor tag
    #
    if ( $tagname eq "a" ) {
        Record_Result("EPUB-PAGE-001", $line, $column, $text,
                      String_Value("Invalid tag used for page break") .
                      " <$tagname>");
    }
    
    #
    # Start a text handler to capture any possible text inside the tag.
    #
    print "Starting text handler to capture text inside page break tag\n" if $debug;
    Start_Text_Handler($self, $tagname);
        
    #
    # Save the position in the tag stack for this open tag.  When
    # we get to the corresponding close tag, we check for possible
    # content in the tag.
    #
    $page_break_tag_index = @tag_stack;

    #
    # Increment page count for this file
    #
    $page_break_count++;
}

#***********************************************************************
#
# Name: Check_Page_Break_Content
#
# Parameters: self - reference to this parser
#             tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks to see if there was any text inside the tag
# that contains page break attributes.
#
#***********************************************************************
sub Check_Page_Break_Content {
    my ($self, $tagname, $line, $column, $text, %attr) = @_;

    my ($content);

    #
    # Check for epub:type "pagebreak" and role "doc-pagebreak"
    #
    print "Check_Page_Break_Content\n" if $debug;
    $content = Get_Text_Handler_Content($self, "");
    if ( $content =~ /^\s*$/ ) {
        print "No content in page break tag\n" if $debug;
    }
    else {
        #
        # Unexpected text in page break tag
        #
        Record_Result("EPUB-PAGE-001", $line, $column, $text,
                      String_Value("Content not allowed in page break") .
                      " " . String_Value("found") .
                      " \"$content\"");
    }
    
    #
    # Destroy the text handler
    #
    Destroy_Text_Handler($self, $tagname);
    $page_break_tag_index = 0;
}

#***********************************************************************
#
# Name: Check_EPUB_ARIA_Attributes
#
# Parameters: tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             epub_type - epub:type attribute value
#             role - role attribute value
#             attr - hash table of attributes
#
# Description:
#
#   This function checks to see if both EPUB and WAI-ARIA attribute
# values are present if there is a mapping for the semantics.
#
#***********************************************************************
sub Check_EPUB_ARIA_Attributes {
    my ($tagname, $line, $column, $text, $epub_type, $role, %attr) = @_;

    #
    # Check for missing role value
    #
    print "Check_EPUB_ARIA_Attributes epub:type=$epub_type and role=$role\n" if $debug;
    if ( $role eq "" ) {
        print "Missing role value\n" if $debug;
        Record_Result("EPUB-SEM-001", $line, $column, $text,
                      String_Value("Missing attribute") .
                      " 'role=\"" . $epub_aria_semantic_mapping{$epub_type} .
                      "\"' " . String_Value("matching for") .
                      " epub:type=\"$epub_type\"");
    }
    #
    # Check for missing epub:type value
    #
    elsif ( $epub_type eq "" ) {
        print "Missing epub:type value\n" if $debug;
        Record_Result("EPUB-SEM-001", $line, $column, $text,
                      String_Value("Missing attribute") .
                      " 'epub:type=\"" . $aria_epub_semantic_mapping{$role} .
                      "\"' " . String_Value("matching for") .
                      " role=\"$role\"");
    }
    #
    # Check that the epub:type and role values are mapped.
    #
    elsif ( $epub_aria_semantic_mapping{$epub_type} ne $role ) {
        #
        # Mismatch in epub:type and role mapping.
        #
        print "epub:type and role values do not match mapping\n" if $debug;
        print "Expecting role " . $epub_aria_semantic_mapping{$epub_type} .
              " for epub:type = $epub_type, found role = $role\n" if $debug;
        Record_Result("EPUB-SEM-001", $line, $column, $text,
                      String_Value("Epub:type, WAI-ARIA role mismatch, found") .
                      " 'epub:type=\"$epub_type\" role=\"$role\" " .
                      String_Value("expecting") .
                      " 'epub:type=\"$epub_type\" role=\"" .
                      $epub_aria_semantic_mapping{$epub_type} . "\"");
    }
    #
    # epub:type and role values match mapping
    #
    else {
        print "epub:type and role values match mapping\n" if $debug;
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
#   This function checks for EPUB and WAI-ARIA attributes on tags.
#
#***********************************************************************
sub Check_Attributes {
    my ($self, $tagname, $line, $column, $text, $attrseq, %attr) = @_;

    my ($epub_type, $role, $id, $title);

    #
    # Check for epub:type attribute.
    #
    print "Check_Attributes\n" if $debug;
    if ( defined($attr{"epub:type"}) ) {
        $epub_type = $attr{"epub:type"};
        print "Found epub:type=\"$epub_type\"\n" if $debug;
    }
    else {
        $epub_type = "";
        print "No epub:type attribute\n" if $debug;
    }

    #
    # Check for role attribute.
    #
    if ( defined($attr{"role"}) ) {
        $role = $attr{"role"};
        print "Found role=\"$role\"\n" if $debug;
    }
    else {
        $role = "";
        print "No role attribute\n" if $debug;
    }

    #
    # Check for page break
    #
    if ( ($epub_type eq "pagebreak") || ($role eq "doc-pagebreak") ) {
        Check_Page_Break_Attributes($self, $tagname, $line, $column, $text,
                                    $epub_type, $role, %attr) ;
    }
    #
    # Check for EPUB type and WAI-ARIA mapping
    #
    elsif ( defined($epub_aria_semantic_mapping{$epub_type}) ||
            defined($aria_epub_semantic_mapping{$role}) ) {
        Check_EPUB_ARIA_Attributes($tagname, $line, $column, $text,
                                   $epub_type, $role, %attr) ;
    }
}

#***********************************************************************
#
# Name: Start_A_Tag_Handler
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
#   This function handles the a (anchor) tag.  If the link is within
# an EPUB landmark section, it records the type of landmark.
#
#***********************************************************************
sub Start_A_Tag_Handler {
    my ($self, $tagname, $line, $column, $text, %attr) = @_;
    
    my ($type);

    #
    # Are we inside a landmarks navigation section?
    #
    if ( $inside_landmarks ) {
        #
        # Do we have an epub:type attribute to specify the landmark type?
        #
        if ( defined($attr{"epub:type"}) && ($attr{"epub:type"} ne "") ) {
            $type = $attr{"epub:type"};
            $landmark_types{$type} = "$line:$column";
        }
    }
}

#***********************************************************************
#
# Name: Start_Figure_Tag_Handler
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
#   This function handles the figure tag, it increments the count of
# illustrations in the file.
#
#***********************************************************************
sub Start_Figure_Tag_Handler {
    my ($self, $tagname, $line, $column, $text, %attr) = @_;

    #
    # Increment illustration count
    #
    $illustration_count++;
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
    my ($self, $tagname, $line, $column, $text, %attr) = @_;

    my ($level);

    #
    # Get heading level number from the tag
    #
    $level = $tagname;
    $level =~ s/^h//g;

    #
    # Have we seen a heading before in this file?
    #
    if ( $first_heading ne "" ) {
        #
        # This heading number must be greater than or equal to the first heading
        #
        if ( $level < $first_heading ) {
            print "New heading level number $level is greater than first heading $first_heading\n" if $debug;
            Record_Result("EPUB-TITLES-002", $line, $column, $text,
                          String_Value("Heading level") .
                          " '<h$level>' " .
                          String_Value("is greater than first heading") .
                          " '<h$first_heading>'");
        }
    }
    else {
        #
        # This is the first heading, save the level
        #
        $first_heading = $level;
        print "First heading level is $level\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Start_Img_Tag_Handler
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
#   This function handles the img tag.  If the image is not decorative,
# it increments the count of illustrations in the file.
#
#***********************************************************************
sub Start_Img_Tag_Handler {
    my ($self, $tagname, $line, $column, $text, %attr) = @_;

    #
    # Check for text alternative.  If we have some, then this is not
    # a decorative image and should be counted as an illustration.
    #
    if ( defined($attr{"alt"}) && ($attr{"alt"} ne "") ) {
        $illustration_count++;
    }
    elsif ( defined($attr{"aria-labelledby"}) ) {
        $illustration_count++;
    }
}

#***********************************************************************
#
# Name: Start_Nav_Tag_Handler
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
#   This function handles the nav tag, it checks to see if there are any
# epub:type or role attributes indicating the nav is a table of content,
# list of pages, a list of illustrations or a list of landmarks.
#
#***********************************************************************
sub Start_Nav_Tag_Handler {
    my ($self, $tagname, $line, $column, $text, %attr) = @_;

    my ($epub_type, $role);

    #
    # Check for epub:type attribute.
    #
    print "Start_Nav_Tag_Handler\n" if $debug;
    if ( defined($attr{"epub:type"}) ) {
        $epub_type = $attr{"epub:type"};
        print "Found epub:type=\"$epub_type\"\n" if $debug;
    }
    else {
        $epub_type = "";
    }

    #
    # Check for role attribute.
    #
    if ( defined($attr{"role"}) ) {
        $role = $attr{"role"};
        print "Found role=\"$role\"\n" if $debug;
    }
    else {
        $role = "";
    }

    #
    # Is this a start of a table of landmarks?
    #
    if ( ($epub_type eq "landmarks") || ($role eq "directory") ) {
        #
        # Found table of landmarks
        #
        print "Found table of landmarks\n" if $debug;
        $epub_nav_types{"landmarks"} = 1;
        $inside_landmarks = 1;
    }
    #
    # Is this a start of a list of illustrations?
    #
    elsif ( $epub_type eq "loi" ) {
        #
        # Found list of illustrations
        #
        print "Found list of illustrations\n" if $debug;
        $epub_nav_types{"loi"} = 1;
    }
    #
    # Is this a start of a list of pages?
    #
    elsif ( ($epub_type eq "page-list") || ($role eq "doc-pagelist") ) {
        #
        # Found list of pages
        #
        print "Found list of pages\n" if $debug;
        $epub_nav_types{"page-list"} = 1;
    }
    #
    # Is this a start of a table of contents?
    #
    elsif ( ($epub_type eq "toc") || ($role eq "doc-toc") ) {
        #
        # Found table of contents
        #
        print "Found table of contents\n" if $debug;
        $epub_nav_types{"toc"} = 1;
    }
}

#***********************************************************************
#
# Name: End_Nav_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end nav </nav> tag.
#
#***********************************************************************
sub End_Nav_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($type);
    
    #
    # Did we finish a landmark navigation section?
    #
    if ( $inside_landmarks ) {
        #
        # Check for required landmark types inside the landmarks
        # section
        #
        print "Check for required landmark types\n" if $debug;
        foreach $type (keys(%required_landmark_types)) {
            if ( ! defined($landmark_types{$type}) ) {
            Record_Result("EPUB-SEM-003", $line, $column, $text,
                          String_Value("Missing landmark navigation type") .
                          " '$type'");
            }
        }
        
        #
        # Clear flag, we are no longer inside a landmarks section
        #
        $inside_landmarks = 0;
    }
}

#***********************************************************************
#
# Name: Start_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             line - line number
#             length - position in the content stream
#             text - text from tag
#             skipped_text - text since the last tag
#             attrseq - reference to an array of attributes
#             attr_list - list of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the start of HTML tags.
#
#***********************************************************************
sub Start_Handler {
    my ($self, $tagname, $line, $column, $text,
        $skipped_text, $attrseq, @attr_list) = @_;

    my (%attr) = @attr_list;
    
    #
    # If this is not a self closing tag, we add it to the tag stack.
    #
    print "Start_Handler tag $tagname at $line:$column\n" if $debug;
    $tagname =~ s/\///g;
    if ( ! defined($attr{"/"}) ) {
        print "Add tag to tag stack\n" if $debug;
        push(@tag_stack, $tagname);
    }

    #
    # Check attributes
    #
    Check_Attributes($self, $tagname, $line, $column, $text, $attrseq, %attr);

    #
    # Check s tag
    #
    if ( $tagname eq "a" ) {
        Start_A_Tag_Handler($self, $tagname, $line, $column, $text, %attr);
    }

    #
    # Check h tag
    #
    elsif ( $tagname =~ /^h[0-9]?$/ ) {
        Start_H_Tag_Handler($self, $tagname, $line, $column, $text, %attr);
    }

    #
    # Check img tag
    #
    elsif ( $tagname eq "img" ) {
        Start_Img_Tag_Handler($self, $tagname, $line, $column, $text, %attr);
    }

    #
    # Check figure tag
    #
    elsif ( $tagname eq "figure" ) {
        Start_Figure_Tag_Handler($self, $tagname, $line, $column, $text, %attr);
    }

    #
    # Check nav tag
    #
    elsif ( $tagname eq "nav" ) {
        Start_Nav_Tag_Handler($self, $tagname, $line, $column, $text, %attr);
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
    my ($last_tag);

    #
    # Does the current tag count match the page break tag count?
    # If so we have to check to see if there was any text inside the tag.
    #
    print "End_Handler tag $tagname at $line:$column\n" if $debug;
    if ( ($page_break_tag_index != 0) && ($page_break_tag_index eq @tag_stack) ) {
        print "Found close tag for page break tag\n" if $debug;
        Check_Page_Break_Content($self, $tagname, $line, $column, $text,
                                 %attr_hash);
    }
    
    #
    # Pop last tag from tag stack
    #
    if ( @tag_stack > 0 ) {
        $last_tag = pop(@tag_stack);
        print "Last open tag $last_tag\n" if $debug;
    }
    
    #
    # Check nav tag
    #
    if ( $tagname eq "nav" ) {
        End_Nav_Tag_Handler($self, $line, $column, $text);
    }
}

#***********************************************************************
#
# Name: EPUB_HTML_Check
#
# Parameters: this_url - a URL
#             language - language of EPUB
#             profile - testcase profile
#             content - HTML content pointer
#             epub_item_object - an object containing details on
#                                the epub file
#
# Description:
#
#   This function runs a number of technical QA checks on HTML content that
# is part of an EPUB document.  These checks are for EPUB Accessibility
# Techniques, the WCAG techniques are handled by the function
# HTML_Check_EPUB_File in the html_check.pm module.
#
#***********************************************************************
sub EPUB_HTML_Check {
    my ($this_url, $language, $profile, $content, $epub_item_object) = @_;

    my ($parser, $eval_output, $value, @tqa_results, @content_lines);
    my (%properties);

    #
    # Check testcase profile
    #
    print "EPUB_HTML_Check: Checking URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($epub_check_profile_map{$profile}) ) {
        print "Unknown EPUB testcase profile passed $profile\n";
        return(@tqa_results);
    }

    #
    # Initialize unit globals.
    #
    $save_text_between_tags = 0;
    $saved_text = "";
    $results_list_addr = \@tqa_results;
    $current_epub_check_profile = $epub_check_profile_map{$profile};

    #
    # Save URL in global variable
    #
    if ( ($this_url =~ /^http/i) || ($this_url =~ /^file/i) ) {
        $current_url = $this_url;
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of content
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Did we get any content ?
    #
    if ( length($$content) > 0 ) {
        #
        # Create a document parser
        #
        $parser = HTML::Parser->new;
        
        #
        # Initialize parser global variables
        #
        $current_text_handler_tag = "";
        %epub_nav_types = ();
        $first_heading = "";
        $have_text_handler = 0;
        $illustration_count = 0;
        $inside_landmarks = 0;
        %landmark_types = ();
        $page_break_count = 0;
        $page_break_tag_index = 0;
        @tag_stack = ();
        @text_handler_tag_list = ();

        #
        # Add handlers for some of the HTML tags
        #
        $parser->handler(
            declaration => \&Declaration_Handler,
            "text,line,column"
        );
        $parser->handler(
            start => \&Start_Handler,
            "self,tagname,line,column,text,skipped_text,attrseq,\@attr"
        );
        $parser->handler(
            end => \&End_Handler,
            "self,tagname,line,column,text,\@attr"
        );

        #
        # Parse the content.
        #
        @content_lines = split(/\n/, $$content);
        eval { $parser->parse($$content); };
        $eval_output = $@ if $@;

        #
        # Did the parsing fail ?
        #
        if ( defined($eval_output) && ($eval_output ne "1") ) {
            $eval_output =~ s/\n at .* line \d*$//g;
            print "Parse of EPUB HTML file failed \"$eval_output\"\n" if $debug;
            Record_Result("WCAG_2.0-G134", -1, 0, "",
                      String_Value("Fails validation") . " \"$eval_output\"");
        }

        #
        # Set the number of pages for this file
        #
        print "Set page count to $page_break_count\n" if $debug;
        $epub_item_object->page_count($page_break_count);
        
        #
        # Set the number of illustrations for this file
        #
        print "Set illustration count to $illustration_count\n" if $debug;
        $epub_item_object->illustration_count($illustration_count);

        #
        # If this file is a navigation file, set the types found in the file
        #
        %properties = $epub_item_object->properties();
        if ( defined($properties{"nav"}) ) {
            print "Set navigation types field in item object\n" if $debug;
            $epub_item_object->nav_types(%epub_nav_types);
        }
    }
    else {
        print "No content passed to EPUB_HTML_Check\n" if $debug;
        return(@tqa_results);
    }

    #
    # Return results array
    #
    return(@tqa_results);
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

