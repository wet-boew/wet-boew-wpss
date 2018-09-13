#***********************************************************************
#
# Name:   tqa_check.pm
#
# $Revision: 895 $
# $URL: svn://10.36.148.185/TQA_Check/Tools/tqa_check.pm $
# $Date: 2018-07-09 11:06:56 -0400 (Mon, 09 Jul 2018) $
#
# Description:
#
#   This file contains routines that parse HTML files and check for
# a number of technical quality assurance check points.
#
# Public functions:
#     Get_TQA_Check_Testcase_Description
#     Set_TQA_Check_Language
#     Set_TQA_Check_Debug
#     Set_TQA_Check_Testcase_Data
#     Set_TQA_Check_Test_Profile
#     Set_TQA_Check_Valid_Markup
#     TQA_Check
#     TQA_Check_Links
#     TQA_Check_Images
#     TQA_Check_Add_To_Image_List
#     TQA_Check_Compliance_Score
#     TQA_Check_Profile_Types
#     TQA_Check_Set_Exemption_Markers
#     TQA_Check_Exempt
#     TQA_Check_Need_Validation
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

package tqa_check;

use strict;
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
use csv_check;
use epub_check;
use html_check;
use javascript_check;
use javascript_validate;
use link_checker;
use link_object;
use marc_check;
use metadata;
use metadata_result_object;
use pdf_check;
use tqa_result_object;
use tqa_testcases;
use url_check;
use xml_check;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Get_TQA_Check_Testcase_Description
                  Set_TQA_Check_Language
                  Set_TQA_Check_Debug
                  Set_TQA_Check_Testcase_Data
                  Set_TQA_Check_Test_Profile
                  Set_TQA_Check_Valid_Markup
                  TQA_Check
                  TQA_Check_Links
                  TQA_Check_Images
                  TQA_Check_Add_To_Image_List
                  TQA_Check_Compliance_Score
                  TQA_Check_Profile_Types
                  TQA_Check_Set_Exemption_Markers
                  TQA_Check_Exempt
                  TQA_Check_Need_Validation
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (%testcase_data, $current_url);

my (%tqa_check_profile_map, $current_tqa_check_profile);
my ($results_list_addr);
my (%tqa_testcase_profile_types, %exemption_markers);
my ($have_exemption_markers) = 0;

my ($max_error_message_string) = 2048;
my ($MAX_IMAGE_COUNT) = 10000;

#
# Status values
#
my ($tqa_check_pass)       = 0;
my ($tqa_check_fail)       = 1;

my ($current_landmark, $landmark_marker);

#
# String table for error strings.
#
my %string_table_en = (
    "Alt text missing from non-decorative image", "Alt text missing from non-decorative image. ",
    "Alt text",                       "Alt text",
    "Alt values do not match for link to", "Alt values do not match for link to ",
    "Anchor values do not match for link to", "Anchor values do not match for link to",
    "at line:column",                 " at (line:column) ",
    "Found",                          "Found",
    "HTTP header redirect not allowed", "HTTP header redirect not allowed",
    "HTTP header refresh not allowed",  "HTTP header refresh not allowed",
    "Image first found in URL",       "Image first found in URL ",
    "Image URL in decorative list",   "Image URL found in decorative image list",
    "Image URL in non-decorative list", "Image URL found in non-decorative image list",
    "in decorative image",            "in decorative image. ",
    "in non-decorative image",        "in non-decorative image",
    "in URL",                         " in URL ",
    "in",                             " in ",
    "Invalid role text value",        "Invalid 'role' text value",
    "Missing alt attribute in decorative image", "Missing alt attribute in decorative image. ",
    "Navigation link",                "Navigation link ",
    "Non null alt text",              "Non null 'alt' text",
    "Non null text alternative",      "Non null text alternative",
    "Non null",                       "Non null",
    "Non-decorative image loaded via CSS", "Non-decorative image loaded via CSS. ",
    "out of order, should precede",   " out of order, should precede ",
    "previously found",               "previously found",
    "Title values do not match for link to", "Title values do not match for link to",
    );


#
# String table for error strings (French).
#
my %string_table_fr = (
    "Alt text",                       "Alt texte",
    "Alt values do not match for link to", "Valeurs 'alt' ne correspondent pas pour le lien vers",
    "Anchor text is a URL",           "Texte d'ancrage est une URL",
    "Anchor values do not match for link to", "Valeurs d'ancrage ne correspondent pas pour le lien vers",
    "at line:column",                 " à (la ligne:colonne) ",
    "Found",                          "trouvé",
    "HTTP header redirect not allowed", "En-têtes HTTP rediriger pas autorisé",
    "HTTP header refresh not allowed",  "En-têtes HTTP raffranchissement pas autorisé",
    "Image first found in URL",       "Image d'abord trouvé dans les URL ",
    "Image URL in decorative list",   "URL de l'image son trouvé dans la liste des images décoratives.",
    "Image URL in non-decorative list", "URL de l'image son trouvé dans la liste des images non décoratives.",
    "in decorative image",            "dans l'image décoratives. ",
    "in non-decorative image",        "dans l'image non-décoratives.",
    "in URL",                         " dans URL ",
    "in",                             " dans ",
    "Invalid role text value",        "Valeur de texte 'role' est invalide",
    "Missing alt attribute in decorative image", "Attribut alt manquant dans l'image décoratives. ",
    "Navigation link",                "Lien de navigation ",
    "Non null alt text",              "Non le texte 'alt' nuls",
    "Non null text alternative",      "Non nulle texte alternatif",
    "Non null",                       "Non nuls",
    "Non-decorative image loaded via CSS", "Non-décorative image chargée via CSS. ",
    "out of order, should precede",   " de l'ordre, doit précéder ",
    "previously found",               "trouvé avant",
    "Title values do not match for link to", "Valeurs 'title' ne correspondent pas pour le lien vers",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_TQA_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_TQA_Check_Debug {
    my ($this_debug) = @_;

    #
    # Set other debug flags
    #
    Set_CSS_Check_Debug($this_debug);
    Set_EPUB_Check_Debug($this_debug);
    Set_JavaScript_Check_Debug($this_debug);
    PDF_Check_Debug($this_debug);
    TQA_Testcase_Debug($this_debug);
    Set_HTML_Check_Debug($this_debug);
    Set_MARC_Check_Debug($this_debug);
    Set_XML_Check_Debug($this_debug);
    Set_CSV_Check_Debug($this_debug);

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Get_TQA_Check_Testcase_Description
#
# Parameters: language
#
# Description:
#
#   This function returns the mapping of testcase identifiers to testcase
# description for the language specified.
#
#***********************************************************************
sub Get_TQA_Check_Testcase_Description {
    my ($language) = @_;

    #
    # Return descriptions table
    #
    return(TQA_Testcase_All_Descriptions($language));
}

#**********************************************************************
#
# Name: Set_TQA_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_TQA_Check_Language {
    my ($language) = @_;

    #
    # Set CSS and JavaScript TQA Language
    #
    Set_CSS_Check_Language($language);
    Set_EPUB_Check_Language($language);
    Set_JavaScript_Check_Language($language);
    Set_PDF_Check_Language($language);
    Set_HTML_Check_Language($language);
    Set_MARC_Check_Language($language);
    TQA_Testcase_Language($language);
    Set_XML_Check_Language($language);
    Set_CSV_Check_Language($language);

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_TQA_Check_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_TQA_Check_Language, language = English\n" if $debug;
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
# Name: Set_TQA_Check_Testcase_Data
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
sub Set_TQA_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Set CSS and JavaScript Check test case data
    #
    Set_CSS_Check_Testcase_Data($testcase, $data);
    Set_EPUB_Check_Testcase_Data($testcase, $data);
    Set_JavaScript_Check_Testcase_Data($testcase, $data);
    Set_PDF_Check_Testcase_Data($testcase, $data);
    Set_HTML_Check_Testcase_Data($testcase, $data);
    Set_MARC_Check_Testcase_Data($testcase, $data);
    Set_XML_Check_Testcase_Data($testcase, $data);
    Set_CSV_Check_Testcase_Data($testcase, $data);

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_TQA_Check_Test_Profile
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
sub Set_TQA_Check_Test_Profile {
    my ($profile, $tqa_checks ) = @_;

    my (%local_tqa_checks);
    my ($key, $value);

    #
    # Set CSS and JavaScript Check test case profiles
    #
    Set_CSS_Check_Test_Profile($profile, $tqa_checks);
    Set_EPUB_Check_Test_Profile($profile, $tqa_checks);
    Set_JavaScript_Check_Test_Profile($profile, $tqa_checks);
    Set_PDF_Check_Test_Profile($profile, $tqa_checks);
    Set_HTML_Check_Test_Profile($profile, $tqa_checks);
    Set_MARC_Check_Test_Profile($profile, $tqa_checks);
    Set_XML_Check_Test_Profile($profile, $tqa_checks);
    Set_CSV_Check_Test_Profile($profile, $tqa_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_TQA_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_tqa_checks = %$tqa_checks;
    $tqa_check_profile_map{$profile} = \%local_tqa_checks;
}

#***********************************************************************
#
# Name: Set_TQA_Check_Valid_Markup
#
# Parameters: this_url - URL,
#             valid_html - hash table of content type & mark up validity
#
# Description:
#
#   This function copies the passed flags into the global
# variable or passes the value onto to supporting modules.
# The hash table contains a mime-type and validity flag with one
# of the following possible values
#    1 - valid mark up
#    0 - not valid mark up
#   -1 - unknown validity.
#
#***********************************************************************
sub Set_TQA_Check_Valid_Markup {
    my ($this_url, %valid_html) = @_;

    my ($mime_type, $validity);

    #
    # Clear existing validity flags
    #
    Set_HTML_Check_Valid_Markup(1);
    Set_EPUB_Check_Valid_Markup(1);
    Set_CSS_Check_Valid_Markup(1);
    Set_JavaScript_Check_Valid_Markup(1);
    Set_MARC_Check_Valid_Markup(1);
    Set_XML_Check_Valid_Markup(1);

    #
    # Check each mime type
    #
    while ( ($mime_type, $validity) = each %valid_html ) {
        #
        # Check mime type
        #
        if ( $mime_type =~ "text\/css" ) {
            Set_CSS_Check_Valid_Markup($validity);
        }
        elsif ( ($mime_type =~ /application\/epub\+zip/) ||
                ($this_url =~ /\.epub$/i) ) {
            Set_EPUB_Check_Valid_Markup($validity);
        }
        elsif ( $mime_type =~ "text\/html" ) {
            Set_HTML_Check_Valid_Markup($validity);
        }
        elsif ( ($mime_type =~ "application\/x-javascript") ||
                ($mime_type =~ "text\/javascript") ||
                ($this_url =~ /\.js$/i) ) {
            Set_JavaScript_Check_Valid_Markup($validity);
        }
        elsif ( $mime_type =~ "application\/marc" ) {
            Set_MARC_Check_Valid_Markup($validity);
        }
        elsif ( ($mime_type =~ /application\/atom\+xml/) ||
                ($mime_type =~ /application\/rss\+xml/) ||
                ($mime_type =~ /application\/ttml\+xml/) ||
                ($mime_type =~ /application\/xhtml\+xml/) ||
                ($mime_type =~ /text\/xml/) ||
                ($this_url =~ /\.xml$/i) ) {
            Set_XML_Check_Valid_Markup($validity);
        }
    }
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

    #
    # Set current hash tables
    #
    $current_tqa_check_profile = $tqa_check_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;
    $current_landmark = "";
    $landmark_marker = "";
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
    if ( defined($testcase) && defined($$current_tqa_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $tqa_check_fail,
                                                TQA_Testcase_Description($testcase),
                                                $line, $column, $text,
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
# Name: Check_HTTP_Response
#
# Parameters: url - URL of document
#             resp - HTTP::Response object
#
# Description:
#
#   This function checks for errors related to the HTTP::Respoonse object.
#
#***********************************************************************
sub Check_HTTP_Response {
    my ($url, $resp) = @_;

    my ($refresh, $header, @values, $value);

    #
    # Do we have a response object (wont have one if we are doing direct HTML
    # input).
    #
    if ( defined($resp) ) {
        #
        # Is there a refresh field in the header ?
        #
        $header = $resp->headers;
        if ( defined($header->header("Refresh")) ) {
            $refresh = $header->header("Refresh");
            print "HTTP Response, header Refresh = $refresh\n" if $debug;

            #
            # Split content on semi-colon then check each value
            # to see if it contains only digits (and whitespace).
            #
            @values = split(/;/, $refresh);
            foreach $value (@values) {
                if ( $value =~ /\s*\d+\s*/ ) {
                    #
                    # Found timeout value, is it greater than 0 ?
                    # A 0 value is a instanteous redirect, which is a
                    # WCAG AAA check.
                    #
                    print "HTTP header redirect with timeout $value\n" if $debug;
                    if ( $value > 0 ) {
                        #
                        # Is there any refresh content ?
                        #
                        if ( $refresh =~ /url/i ) {
                            Record_Result("WCAG_2.0-F58", -1, -1, "",
                                          String_Value("HTTP header redirect not allowed"));
                        }
                        else {
                            Record_Result("WCAG_2.0-F58", -1, -1, "",
                                          String_Value("HTTP header refresh not allowed"));
                        }
                    }
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Other_Tool_Results
#
# Parameters: none
#
# Description:
#
#   This function checks the other_tool_results hash table to see
# if the results of other tools (e.g. link check) should be recorded
# as TQA failures.
#
#***********************************************************************
sub Check_Other_Tool_Results {

    my (@tqa_results_list);

    #
    # This is a place holder function and does nothing.

    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: TQA_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             mime_type - mime type of content
#             resp - HTTP::Response object
#             content - content pointer
#             links - address of a list of link objects
#
# Description:
#
#   This function runs a number of technical QA checks the content.
#
#***********************************************************************
sub TQA_Check {
    my ($this_url, $language, $profile, $mime_type, $resp, 
        $content, $links) = @_;

    my ($extracted_content, @tqa_results_list, $do_tests, $tcid);
    my (@other_tqa_results_list, $result_object, $fault_count);

    #
    # Call the appropriate TQA check function based on the mime type
    #
    print "TQA_Check: URL $this_url, mime-type = $mime_type, lanugage = $language, profile = $profile\n" if $debug;

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Are any of the testcases defined in this testcase profile ?
    #
    $do_tests = 0;
    if ( keys(%$current_tqa_check_profile) == 0 ) {
        #
        # No tests handled by this module
        #
        print "No tests handled by this module\n" if $debug;
        return(@tqa_results_list);
    }

    #
    # Is it CSS content?
    #
    if ( $mime_type =~ /text\/css/ ) {
        @tqa_results_list = CSS_Check($this_url, $language, $profile,
                                      $content);
    }
    #
    # Is it EPUB content?
    #
    if ( ($mime_type =~ /text\/epub\+zip/) ||
         ($this_url =~ /\.epub$/) ) {
        @tqa_results_list = EPUB_Check($this_url, $language, $profile,
                                      $content);
    }
    #
    # Is it HTML content?
    #
    elsif ( $mime_type =~ /text\/html/ ) {
        @tqa_results_list = HTML_Check($this_url, $language, $profile,
                                       $resp, $content, $links);
        $fault_count = @tqa_results_list;
        print "HTML faults detected = $fault_count\n" if $debug;

        #
        # Extract any inline CSS from the HTML and check that code.
        #
        print "Check for inline CSS\n" if $debug;
        $extracted_content = CSS_Validate_Extract_CSS_From_HTML($this_url,
                                                                $content);
        if ( length($extracted_content) > 0 ) {
            print "CSS_Check on URL\n  --> $this_url\n" if $debug;
            @other_tqa_results_list = CSS_Check($this_url, $language, $profile,
                                                \$extracted_content);
            $fault_count = @other_tqa_results_list;
            print "CSS faults detected = $fault_count\n" if $debug;

            #
            # Add results from CSS check into those from the HTML check
            # to get resuilts for the entire document.
            #
            foreach $result_object (@other_tqa_results_list) {
                push(@tqa_results_list, $result_object);
            }
        }

        #
        # Extract any inline JavaScript from the HTML and check that code.
        #
        print "Check for inline JavaScript\n" if $debug;
        $extracted_content = JavaScript_Validate_Extract_JavaScript_From_HTML($this_url, $content);
        if ( length($extracted_content) > 0 ) {
            print "JavaScript on URL\n  --> $this_url\n" if $debug;
            @other_tqa_results_list = JavaScript_Check($this_url, $language,
                                                       $profile,
                                                       \$extracted_content);
            $fault_count = @other_tqa_results_list;
            print "JavaScript faults detected = $fault_count\n" if $debug;

            #
            # Merge results from JavaScript check into those from the
            # HTML check to get resuilts for the entire document.
            #
            foreach $result_object (@other_tqa_results_list) {
                push(@tqa_results_list, $result_object);
            }
        }
    }
    #
    # Is it JavaScript content?
    #
    elsif ( ($mime_type =~ /application\/x-javascript/) ||
            ($mime_type =~ /text\/javascript/) ) {
        @tqa_results_list = JavaScript_Check($this_url, $language, $profile,
                                             $content);
    }
    #
    # Is it MARC content?
    #
    elsif ( ($mime_type =~ /application\/marc/) ||
            ($this_url =~ /\.mrc$/i) ) {
        @tqa_results_list = MARC_Check($this_url, $language, $profile,
                                      $content);
    }
    #
    # Is it PDF content?
    #
    elsif ( $mime_type =~ /application\/pdf/ ) {
        @tqa_results_list = PDF_Check($this_url, $language, $profile,
                                      $content);
    }
    #
    # Is it XML content?
    #
    elsif ( ($mime_type =~ /application\/xhtml\+xml/) ||
            ($mime_type =~ /application\/atom\+xml/) ||
            ($mime_type =~ /application\/rss\+xml/) ||
            ($mime_type =~ /text\/xml/) ||
            ($this_url =~ /\.xml$/i) ) {
        @tqa_results_list = XML_Check($this_url, $language, $profile,
                                      $content);
    }
    #
    # Is it CSV content?
    #
    elsif ( ($mime_type =~ /text\/x-comma-separated-values/) ||
            ($mime_type =~ /text\/csv/) ||
            ($this_url =~ /\.csv$/i) ) {
        @tqa_results_list = CSV_Check($this_url, $language, $profile,
                                      $content);
    }

#    #
#    # Check the Other Tool Results hash table to see if
#    # results from other tools should be recorded as TQA failures.
#    #
#    @other_tqa_results_list = Check_Other_Tool_Results();
#
#    #
#    # Add results from Other Tool Results check into those from
#    # the previous check to get resuilts for the entire document.
#    #
#    foreach $result_object (@other_tqa_results_list) {
#        push(@tqa_results_list, $result_object);
#    }

    #
    # Check for errors using the HTTP::Response object
    #
    Check_HTTP_Response($this_url, $resp);

    #
    # Add help URL to result
    #
    foreach $result_object (@tqa_results_list) {
        $tcid = $result_object->testcase();
        if ( defined(TQA_Testcase_URL($tcid)) ) {
            $result_object->help_url(TQA_Testcase_URL($tcid));
        }
    }

    #
    # Return list of results
    #
    $fault_count = @tqa_results_list;
    print "Total faults detected = $fault_count\n" if $debug;
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Prepare_String_For_Comparison
#
# Parameters: string
#
# Description:
#
#   This function prepares a string for comparison.  It
#  a) replaces newline or return with a space
#  b) removes leading and trailing whitespace.
#  c) it collapses multiple whitespace sequences into a single space
#  d) removes non-ASCII characters
#  e) converts to lowercase
#
#***********************************************************************
sub Prepare_String_For_Comparison {
    my ($string) = @_;

    #
    # Encode any special characters
    #
    $string = decode_entities($string);
    $string = encode_entities($string);

    #
    # Remove newline, return and &nbsp;
    #
    $string =~ s/[\n\r]//g;
    $string =~ s/\&nbsp;//g;

    #
    # Remove all other whitespace
    #
    $string =~ s/\s//g;

    #
    # Remove non ascii characters
    #
    $string =~ s/[^[:ascii:]]+//g;

    #
    # Return lowercase version of string.
    #
    return(lc($string));
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
# Name: Is_Substring
#
# Parameters: string1 - a string
#             string2 - a string
#
# Description:
#
#   This function checks to see if either string is a substring
# of the other. 
#
#***********************************************************************
sub Is_Substring {
    my ($string1, $string2) = @_;

    my ($substring) = 0;

    #
    # Is one string a substring of the other (check only if
    # both strings are not empty)
    #
    if ( ($string1 ne "") && ($string2 ne "") ) {
        #
        # is the first string value a substring of the second
        # value (one value has additional content).
        #
        if ( index($string2, $string1) > -1 ) {
            print "First string is a substring of second string\n" if $debug;
            $substring = 1;
        }
        elsif ( index($string1, $string2) > -1 ) {
            print "Second string is a substring of first string\n" if $debug;
            $substring = 1;
        }
    }

    #
    # Return substring status
    #
    return($substring);
}

#***********************************************************************
#
# Name: Check_Link_Anchor_Alt_Title_Check
#
# Parameters: url - URL
#             profile - testcase profile
#             links - list of link objects
#
# Description:
#
#   This function checks the anchor, alt and text text of the supplied
# links.  If the same URL is used in the same language context with a 
# different anchor, title or alt text value an error is reported.
#
#***********************************************************************
sub Check_Link_Anchor_Alt_Title_Check {
    my ($url, $profile, @links) = @_;

    my ($link, $string1, $string2, %g197_reported);
    my ($lang, $anchor, $title, $alt, $link_url, $referer_url);
    my ($url_link_object_table, $previous_link, $different);
    my ($difference, $line_no, $column_no, $link_type);
    my ($url_lang_link_object_table, %lang_url_link_object_table);
    my ($in_list, $list_heading, $ignored_link_text, $ignore_link);

    #
    # Are we checking labels, names and text alternatives ?
    #
    if ( defined($$current_tqa_check_profile{"WCAG_2.0-G197"}) ) {
        #
        # Loop through the links
        #
        foreach $link (@links) {
            #
            # Get link details
            #
            $lang = $link->lang;
            $anchor = $link->anchor;
            $title = $link->title;
            $alt = $link->alt;
            $link_url = $link->abs_url;
            $referer_url = $link->referer_url;
            $line_no = $link->line_no;
            $column_no = $link->column_no;
            $link_type = $link->link_type;
            $in_list = $link->in_list;
            $list_heading = $link->list_heading;
            $current_landmark = $link->landmark();
            $landmark_marker = $link->landmark_marker();
            print "Check link anchor = \"$anchor\", lang = $lang, alt = \"$alt\" url = $link_url at $line_no:$column_no\n" if $debug;

            #
            # Is this a <input type="image" ? If so we skip it as any alt
            # or title attribute belong to the input not the image.
            #
            if ( $link_type eq "input" ) {
                print "Skip input type=image\n" if $debug;
                next;
            }
            
            #
            # If this is an anchor where the href is JavaScript, we skip it
            #
            if ( ($link_type eq "a") && ($link_url =~ /^\s*javascript\s*:/i) ) {
                print "Skip JavaScript link\n" if $debug;
                next;
            }

            #
            # If this is an on page id reference and the href value is "#",
            # we skip it.  JavaScript may be being used to control
            # the behaviour.
            #
            if ( ($link_type eq "a") &&
                 ($link->on_page_id_reference) &&
                 ($link->href eq "#") ) {
                print "Skip on page link to #\n" if $debug;
                next;
            }

            #
            # Is this an image link inside an anchor ? If so the
            # same image may be used for multiple links, each with
            # different alt text as the links serve different
            # purposes (e.g. using a calendar image to open
            # a calendar widget in a form).
            #
            if ( ($link_type eq "img") && $link->in_anchor ) {
                print "Skip image inside anchor\n" if $debug;
                next;
            }

            #
            # Does the link text match any of those we should ignore
            # (e.g. Next, Previous)
            #
            if ( defined($testcase_data{"WCAG_2.0-G197"}) ) {
                $ignore_link = 0;
                foreach $ignored_link_text (split(/\n/, $testcase_data{"WCAG_2.0-G197"})) {
                    #if ( lc($ignored_link_text) eq lc(Clean_Text($anchor)) ) {
                    if ( index(lc(Clean_Text($anchor)), lc($ignored_link_text)) != -1 ) {
                        print "Ignore link text \'$ignored_link_text\' found in \'$anchor\'\n" if $debug;
                        $ignore_link = 1;
                        last;
                    }
                }

                #
                # Do we ignore this link ?
                #
                if ( $ignore_link ) {
                    next;
                }
            }

            #
            # Get the URL table for this language ?
            #
            if ( ! defined($lang_url_link_object_table{$lang}) ) {
                my (%local_url_link_object_table);
                print "Create table for language $lang\n" if $debug;
                $lang_url_link_object_table{$lang} = \%local_url_link_object_table;
            }
            $url_lang_link_object_table = $lang_url_link_object_table{$lang};
            
            #
            # Get the link type table for this language
            #
            if ( ! defined($$url_lang_link_object_table{$link_type}) ) {
                my (%local_url_link_object_table);
                print "Create table for link type $link_type\n" if $debug;
                $$url_lang_link_object_table{$link_type} = \%local_url_link_object_table;
            }
            $url_link_object_table = $$url_lang_link_object_table{$link_type};

            #
            # Have we seen this URL before under the same heading structure ?
            #
            if ( defined($$url_link_object_table{$list_heading . $link_url}) ) {
                print "Previously seen URL $link_url under heading $list_heading for language $lang, link type $link_type\n" if $debug;
                $previous_link = $$url_link_object_table{$list_heading . $link_url};
                
                #
                # Is the anchor text different ?
                #
                $different = 0;
                print "Check new anchor text \"$anchor\" vs \"" .
                      $previous_link->anchor . "\"\n" if $debug;
                $string1 = Prepare_String_For_Comparison($previous_link->anchor);
                $string2 = Prepare_String_For_Comparison($anchor);

                #
                # Are the strings different ?
                #
                if ( $string1 ne $string2 ) {
                    #
                    # Is one string a substring of the other ?
                    #
                    if ( ! Is_Substring($string1, $string2) ) {
                        $different = 1;
                        $difference =
                          String_Value("Anchor values do not match for link to")
                          . " $link_url\n" .
                          String_Value("Found") . " \"$anchor\" " .
                          String_Value("previously found") . " \"" .
                          $previous_link->anchor . "\"";
                    }
                }

                #
                # Is the title attribute different ?
                #
                if ( ! $different ) {
                    print "Check new title text \"$title\" vs \"" .
                          $previous_link->title . "\"\n" if $debug;
                    $string1 = Prepare_String_For_Comparison($previous_link->title);
                    $string2 = Prepare_String_For_Comparison($title);
                    if ( $string1 ne $string2 ) {
                        #
                        # Is one string a substring of the other ?
                        #
                        if ( ! Is_Substring($string1, $string2) ) {
                            $different = 1;
                            $difference =
                              String_Value("Title values do not match for link to")
                              . " $link_url\n" .
                              String_Value("Found") . " \"$title\" " .
                              String_Value("previously found") . " \"" .
                              $previous_link->title . "\"";
                        }
                    }
                }

                #
                # Is the alt attribute different ?
                #
                if ( ! $different ) {
                    print "Check new alt text \"$alt\" vs \"" .
                          $previous_link->alt . "\"\n" if $debug;
                    $string1 = Prepare_String_For_Comparison($previous_link->alt);
                    $string2 = Prepare_String_For_Comparison($alt);
                    if ( $string1 ne $string2 ) {
                        #
                        # Is one string a substring of the other ?
                        #
                        if ( ! Is_Substring($string1, $string2) ) {
                            $different = 1;
                            $difference =
                              String_Value("Alt values do not match for link to")
                              . " $link_url\n" .
                              String_Value("Found") . " \"$alt\" " .
                              String_Value("previously found") . " \"" .
                              $previous_link->alt . "\"";
                        }
                    }
                }
                
                #
                # Did we detect a difference in the anchor, title or alt ?
                #
                if ( $different ) {
                    print "Link difference detected\n" if $debug;

                    #
                    # If the referer URL is different for these links
                    # (may be the case if the links are from the site
                    # navigation), add the URL to the message.
                    #
                    if ( $referer_url ne $previous_link->referer_url ) {
                        $difference .= String_Value("in URL") .
                                       $previous_link->referer_url;
                    }

                    #
                    # Record testcase result, prevent double reporting if the
                    # link appears multiple times in the list.
                    #
                    if ( ! defined($g197_reported{"$line_no:$column_no:$link_url"}) ) {
                        Record_Result("WCAG_2.0-G197", $line_no, $column_no, "",
                              $difference . String_Value("at line:column") .
                              $previous_link->line_no . ":" .
                              $previous_link->column_no);
                        $g197_reported{"$line_no:$column_no:$link_url"} = 1;
                    }
                }
            }
            else {
                #
                # Add URL to the table
                #
                print "Add URL $link_url under heading $list_heading to table for language $lang, link type $link_type\n" if $debug;
                $$url_link_object_table{$list_heading . $link_url} = $link;
            }
        }
    }
}

#***********************************************************************
#
# Name: Add_Navigation_Links
#
# Parameters: language - URL language
#             section - document section
#             links - list of link objects
#             site_navigation_links - hash table of navigation links
#
# Description:
#
#    This function adds the list of links to the navigation link set.
#
#***********************************************************************
sub Add_Navigation_Links {
    my ($language, $section, $links, $site_navigation_links) = @_;

    my (%navigation_link_anchors, $link, $order, @duplicate_anchors, $anchor);
    my (@navigation_links);

    #
    # No navigation links for this language, use the
    # supplied links as the starting set.
    #
    print "Add_Navigation_Links language = $language\n" if $debug;
    $$site_navigation_links{$language} = \%navigation_link_anchors;
    $$site_navigation_links{"$section navigation links $language"} = \@navigation_links;
    $order = 1;
    foreach $link (@$links) {
        #
        # Does this link have anchor text ?
        #
        if ( $link->anchor ne "" ) {
            #
            # If we don't already have this anchor in the
            # list, add it.
            #
            if ( ! defined($navigation_link_anchors{$link->anchor}) ) {
                print "Add navigation link \"" .  $link->anchor . 
                      "\" order $order\n" if $debug;
                $navigation_link_anchors{$link->anchor} = $order;
                $order++;
                push(@navigation_links, $link);
            }
            else {
                #
                # Duplicate anchor, don't add it, keep track of it
                # for now, we will remove duplicates from the list
                # after.  Duplicates are problematic since we wouldn't
                # know which instance to match.
                #
                print "Duplicate anchor \"" .  $link->anchor . 
                      "\" previous order " .
                      $navigation_link_anchors{$link->anchor} . "\n" if $debug;
                push(@duplicate_anchors, $link->anchor);
            }
        }
        else {
            print "Ignore link with no anchor text\n" if $debug;
        }
    }

    #
    # Remove any duplicate anchors from the navigation link set.
    #
    foreach $anchor (@duplicate_anchors) {
        if ( defined($navigation_link_anchors{$anchor}) ) {
            delete $navigation_link_anchors{$anchor};
        }
    }
}

#***********************************************************************
#
# Name: Check_Navigation_Links
#
# Parameters: language - URL language
#             section - document section
#             links - list of link objects
#             site_navigation_links - hash table of navigation links
#
# Description:
#
#    This function checks the list of links against the navigation link set.
#
#***********************************************************************
sub Check_Navigation_Links {
    my ($language, $section, $links, $site_navigation_links) = @_;

    my ($link, $last_order, $new_order, $anchor, $navigation_links);
    my ($last_link_anchor);

    #
    # Check each link in the list provided.  Check that the link order
    # always increases for links found in the site navigation link
    # set.
    #
    print "Check_Navigation_Links language = $language\n" if $debug;
    $navigation_links = $$site_navigation_links{$language};
    $last_order = 0;
    $last_link_anchor = "";
    foreach $link (@$links) {
        #
        # Does this link exist in the site navigation links set ?
        #
        $anchor = $link->anchor;
        print "Check navigation link $anchor\n" if $debug;
        if ( ($anchor ne "") && (defined($$navigation_links{$anchor})) ) {
            #
            # Get new link order and see that it is greater than the 
            # previous site navigation link order.
            # list, add it.
            #
            $new_order = $$navigation_links{$anchor};
            if ( $new_order < $last_order ) {
                #
                # Navigation links out of order
                #
                print "Navigation link $anchor ($new_order) out of order, last link was $last_link_anchor ($last_order)\n" if $debug;
                $current_landmark = $link->landmark();
                $landmark_marker = $link->landmark_marker();
                Record_Result("WCAG_2.0-F66", $link->line_no, $link->column_no,
                              $link->source_line,
                              String_Value("Navigation link") . "\"$anchor\"" .
                              String_Value("out of order, should precede") .
                              "\"$last_link_anchor\"");
            }

            #
            # Update last navigation link order
            #
            $last_order = $new_order;
            $last_link_anchor = $anchor;
            print "Last site navigation link order $last_order\n" if $debug;
        }
    }
}

#***********************************************************************
#
# Name: Check_Site_Navigation_Links
#
# Parameters: url - URL
#             language - URL language
#             section - document section
#             links - list of link objects
#             site_navigation_links - hash table of navigation links
#
# Description:
#
#    This function checks to see if the supplied links follow the
# same relative order as site navigation links.
#
#***********************************************************************
sub Check_Site_Navigation_Links {
    my ($url, $language, $section, $links, $site_navigation_links) = @_;

    #
    # Are any links provided ?
    #
    if ( @$links == 0 ) {
        print "No links provided\n" if $debug;
        return;
    }

    #
    # Are we checking for consistent navigation ?
    #
    print "Check_Site_Navigation_Links for $url\n" if $debug;
    if ( defined($$current_tqa_check_profile{"WCAG_2.0-F66"}) ) {
        #
        # Do we have any navigation links for this language ?
        #
        if ( defined($$site_navigation_links{$language}) ) {
            Check_Navigation_Links($language, $section, $links,
                                   $site_navigation_links);
        }
        else {
            #
            # No navigation links for this language, use the
            # supplied links as the starting set.
            #
            Add_Navigation_Links($language, $section, $links,
                                 $site_navigation_links);
        }
    }
    else {
        print "Not checking navigation links\n" if $debug;
    }
}

#***********************************************************************
#
# Name: TQA_Check_Links
#
# Parameters: tqa_results_list - address of hash table results
#             url - URL
#             profile - testcase profile
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#             site_navigation_links - hash table of navigation links
#
# Description:
#
#    This function performs a number of checks on links found within a
# document.  These checks include seeing if the supplied links follow the
# same relative order as site navigation links, and whether they have
# consistent labels.
#
#***********************************************************************
sub TQA_Check_Links {
    my ($tqa_results_list, $url, $profile, $language, $link_sets,
        $site_navigation_links) = @_;

    my ($result_object, @local_tqa_results_list, $nav_link_addr);
    my ($link, $list_addr, $section, @navigation_links, @content_sections);

    #
    # Do we have a valid profile ?
    #
    print "TQA_Check_Links: profile = $profile, language = $language\n" if $debug;
    if ( ! defined($tqa_check_profile_map{$profile}) ) {
        print "Unknown TQA testcase profile passed $profile\n" if $debug;
        return;
    }

    #
    # Initialize the test case pass/fail table.
    #
    $current_tqa_check_profile = $tqa_check_profile_map{$profile};
    $results_list_addr = \@local_tqa_results_list;
    $current_landmark = "";
    $landmark_marker = "";

    #
    # Save URL in global variable
    #
    if ( ($url =~ /^http/i) || ($url =~ /^file/i) ) {
        $current_url = $url;
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of HTML
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Check for consistent site navigation in each of the navigation
    # sections.
    #
    print "Check for consistent site navigation\n" if $debug;
    foreach $section (Content_Subsection_Names("NAVIGATION")) {
        if ( defined($$link_sets{$section}) ) {
            $list_addr = $$link_sets{$section};

            #
            # Do we have a a table for this navigation section ?
            #
            if ( ! defined($$site_navigation_links{$section}) ) {
                my (%section_site_navigation_links);
                $$site_navigation_links{$section} = \%section_site_navigation_links;
            }
            $nav_link_addr = $$site_navigation_links{$section};

            #
            # Check navigation links
            #
            print "Check navigation links for section $section\n" if $debug;
            Check_Site_Navigation_Links($url, $language, $section, $list_addr,
                                        $nav_link_addr);
        }
    }

    #
    # Check each set of navigation links for consistent labeling.
    # The check is performed using the site's navigation page set
    # as well as this page's links to catch changes in labeling
    # for navigation links throughout the site.
    #
    print "Check for consistent site navigation labeling\n" if $debug;
    foreach $section (Content_Subsection_Names("NAVIGATION")) {
        #
        # Do we have any links in this section ?
        #
        if ( defined($$link_sets{$section}) ) {
            #
            # Do we have any links from the site navigation set ?
            #
            @navigation_links = ();
            if ( defined($$site_navigation_links{$section}) ) {
                $list_addr = $$site_navigation_links{$section};
                if ( defined($$list_addr{"$section navigation links $language"}) ) {
                    $list_addr = $$list_addr{"$section navigation links $language"};
                    @navigation_links = @$list_addr;
                }
            }

            #
            # Add links from this section to the list from the
            # site navigation.  This way if there are site navigation
            # links they appear first in the list.
            #
            $list_addr = $$link_sets{$section};
            @navigation_links = (@navigation_links, @$list_addr);

            #
            # Check for consistent labelling in navigation section links.
            #
            print "Check link anchor, alt, title for section $section\n" if $debug;
            Check_Link_Anchor_Alt_Title_Check($url, $profile,
                                              @navigation_links);
        }
    }

    #
    # Check for consistent labelling in content section links.
    #
    print "Check for consistent content link labeling\n" if $debug;
    @content_sections = Content_Subsection_Names("CONTENT");
    push(@content_sections, "BODY");
    foreach $section (@content_sections) {
        if ( defined($$link_sets{$section}) ) {
            $list_addr = $$link_sets{$section};
            print "Check link anchor, alt, title for section $section\n" if $debug;
            Check_Link_Anchor_Alt_Title_Check($url, $profile, @$list_addr);
        }
    }

    #
    # Add our results to previous results
    #
    foreach $result_object (@local_tqa_results_list) {
        push(@$tqa_results_list, $result_object);
    }
}

#***********************************************************************
#
# Name: Check_Decorative_Image
#
# Parameters: link - link object of image
#             decorative_images - address of hash table of decorative images
#             non_decorative_images - address of hash table of 
#                non decorative images
#
# Description:
#
#    This function checks a decorative image to see that it does not appear
# in the non decorative image list. It also checks that the image has an
# alt attribute.
#
#***********************************************************************
sub Check_Decorative_Image {
    my ($link, $decorative_images, $non_decorative_images) = @_;
        
    my ($message, $href, $other_image, %attr, $text_alternative);
    my ($protocol, $domain, $file_path, $query, $new_url);

    #
    # Get URL of image, both with and without the protocol & domain
    # portion.  Image URLs from a configuration file do not include
    # a protocol or domain, just the file path portion.
    #
    $href = $link->abs_url;
    print "Check_Decorative_Image, href = $href\n" if $debug;
    ($protocol, $domain, $file_path, $query, $new_url) = 
        URL_Check_Parse_URL($href);
    $file_path = "/$file_path";

    #
    # Check to see if this image's URL appears in the non-decorative
    # image list
    #
    if ( defined($$non_decorative_images{$href}) ) {
        $other_image = $$non_decorative_images{$href};
        print "Image in non decortive list, href = $href\n" if $debug;
    } elsif  ( defined($$non_decorative_images{$file_path}) ) {
        $other_image = $$non_decorative_images{$file_path};
        print "Image in non decortive list, file_path = $file_path\n" if $debug;
    }

    #
    # Get text alternative
    #
    %attr = $link->attr();
    if ( $link->alt ne "" ) {
        $text_alternative = $link->alt;
    }
    elsif ( defined($attr{"aria-label"}) ) {
        $text_alternative = $attr{"aria-label"};
    }
    elsif ( defined($attr{"aria-labelledby"}) ) {
        $text_alternative = $attr{"aria-labelledby"};
    }
    elsif ( defined($attr{"aria-describedby"}) ) {
        $text_alternative = $attr{"aria-describedby"};
    }
    elsif ( defined($attr{"title"}) ) {
        $text_alternative = $attr{"title"};
    }

    #
    # Check for null (empty) text alternative.
    #
    print "Check decorative image alt text \"" . $link->alt . "\"\n" if $debug;
    if ( $text_alternative ne "" ) {
        #
        # Non-null text alternative, it may be 1 or more spaces but it is not null
        # e.g. "  " versus "".
        #
        Record_Result("WCAG_2.0-F39", $link->line_no, $link->column_no,
                      $link->source_line, 
                      String_Value("Non null alt text") .
                      " \"$text_alternative\"" .
                      String_Value("in decorative image"));
    }

    #
    # Check for null (empty) aria-label text.
    #
    print "Check decorative image aria-label\n" if $debug;
    %attr = $link->attr();
    if ( defined($attr{"aria-label"}) && ($attr{"aria-label"} ne "") ) {
        #
        # Non-null aria-label text
        #
        Record_Result("WCAG_2.0-F39", $link->line_no, $link->column_no,
                      $link->source_line,
                      String_Value("Non null") . " 'aria-label=\"" .
                      $attr{"aria-label"} . "\"' " .
                      String_Value("in decorative image"));
    }

    #
    # Check for null (empty) aria-labelledby text.
    #
    print "Check decorative image aria-labelledby\n" if $debug;
    if ( defined($attr{"aria-labelledby"}) && ($attr{"aria-labelledby"} ne "") ) {
        #
        # Non-null aria-labelledby text
        #
        Record_Result("WCAG_2.0-F39", $link->line_no, $link->column_no,
                      $link->source_line,
                      String_Value("Non null") . " 'aria-labelledby=\"" .
                      $attr{"aria-labelledby"} . "\"' " .
                      String_Value("in decorative image"));
    }

    #
    # Check for null (empty) aria-describedby text.
    #
    print "Check decorative image aria-describedby\n" if $debug;
    if ( defined($attr{"aria-describedby"}) && ($attr{"aria-describedby"} ne "") ) {
        #
        # Non-null aria-describedby text
        #
        Record_Result("WCAG_2.0-F39", $link->line_no, $link->column_no,
                      $link->source_line,
                      String_Value("Non null") . " 'aria-describedby=\"" .
                      $attr{"aria-describedby"} . "\"' " .
                      String_Value("in decorative image"));
    }

    #
    # Check for null (empty) title text.
    #
    print "Check decorative image title\n" if $debug;
    if ( defined($attr{"title"}) && ($attr{"title"} ne "") ) {
        #
        # Non-null title text
        #
        Record_Result("WCAG_2.0-F39", $link->line_no, $link->column_no,
                      $link->source_line,
                      String_Value("Non null") . " 'title=\"" .
                      $attr{"title"} . "\"' " .
                      String_Value("in decorative image"));
    }

    #
    # Check that if a role attribute is specified, it has the value "presentation".
    #
    print "Check decorative image role\n" if $debug;
    if ( defined($attr{"role"}) && ($attr{"role"} ne "presentation") ) {
        #
        # Invalid role value
        #
        Record_Result("WCAG_2.0-F38", $link->line_no, $link->column_no,
                      $link->source_line,
                      String_Value("Invalid role text value") . " 'role=\"" .
                      $attr{"role"} . "\"' " .
                      String_Value("in decorative image"));
    }

    #
    # This decorative image should not appear in the non-decorative
    # list.
    #
    print "Check_Decorative_Image href = $href\n" if $debug;
    if ( defined($other_image) ) {
        #
        # Image in non decorative list found in decorative context 
        # (i.e. no alt or loaded via CSS).
        #
        print "Non-decorative $href image found in decorative context\n" if $debug;

        #
        # Was this image loaded via CSS url function ?
        #
        if ( $link->link_type eq "url" ) {
            print "Non-decorative image loaded via CSS " . $link->referer_url .
                   "\n" if $debug;
            #
            # Create error message
            #
            $message = String_Value("Non-decorative image loaded via CSS");

            #
            # Add URL if image was in the non-decorative image list.
            #
            if ( $other_image->referer_url eq "LIST" ) {
                $message .= String_Value("Image URL in non-decorative list");
            }
            else {
                #
                # URL was not provided in a list, it must have been
                # 'learned'. Provide URL when image was first found.
                #
                $message .= String_Value("Image first found in URL") .
                            $other_image->referer_url;
            }

            #
            # Record result
            #
            Record_Result("WCAG_2.0-F3", $link->line_no, $link->column_no,
                          $link->source_line, $message);
        } else {
            #
            # Create error message
            #
            $message = String_Value("Alt text missing from non-decorative image");

            #
            # Add URL if image was in the non-decorative image list.
            #
            if ( $other_image->referer_url eq "LIST" ) {
                $message .= String_Value("Image URL in non-decorative list");
            }
            else {
                #
                # URL was not provided in a list, it must have been
                # 'learned'. Provide URL when image was first found.
                #
                $message .= String_Value("Image first found in URL") .
                            $other_image->referer_url;
            }

            #
            # Record result.
            #
            Record_Result("WCAG_2.0-F39", $link->line_no, $link->column_no,
                          $link->source_line, $message);
        }
    }
    #
    # If this image is not already in the decorative list,
    # add it.
    #
    elsif ( (! defined($$decorative_images{$href})) && 
            (! defined($$decorative_images{$file_path})) ) {
        #
        # Add image to list
        #
        print "Add decorative $href image to list\n" if $debug;
        if ( keys(%$decorative_images) < $MAX_IMAGE_COUNT ) {
            $$decorative_images{$href} = $link;
        }
    }

    #
    # Check to see if this image's URL appears in the decorative
    # image list
    #
    if ( defined($$decorative_images{$href}) ) {
        $other_image = $$decorative_images{$href};
    } elsif  ( defined($$decorative_images{$file_path}) ) {
        $other_image = $$decorative_images{$file_path};
    }
    else {
        undef $other_image;
    }

    #
    # Is the image in the decorative image list loaded via an
    # <img> tag (i.e. not loaded via CSS) ?
    #
    if ( defined($other_image) && ($link->link_type eq "img") ) {
        #
        # Check to see there is an alt attribute (not just alt="").
        # If there is no empty alt, assistive technology won't
        # know it is a decorative image.
        #
        if ( ! $link->has_alt ) {
            #
            # Compose error message
            #
            print "Missing alt attribute on decorative image\n" if $debug;
            $message = String_Value("Missing alt attribute in decorative image");

            #
            # Add URL if image was in the decorative image list.
            #
            if ( $other_image->referer_url eq "LIST" ) {
                $message .= String_Value("Image URL in decorative list");
            }
            else {
                #
                # URL was not provided in a list, it must have been
                # 'learned'. Provide URL when image was first found.
                #
                $message .= String_Value("Image first found in URL") .
                            $other_image->referer_url;
            }

            #
            # Record result
            #
            Record_Result("WCAG_2.0-F38", $link->line_no, $link->column_no,
                          $link->source_line, $message);
        }
    }
}

#***********************************************************************
#
# Name: Check_Non_Decorative_Image
#
# Parameters: link - link object of image
#             decorative_images - address of hash table of decorative images
#             non_decorative_images - address of hash table of non decorative
#               images
#
# Description:
#
#    This function checks a non decorative image to see that it does
# not appear in the decorative image list.
#
#***********************************************************************
sub Check_Non_Decorative_Image {
    my ($link, $decorative_images, $non_decorative_images) = @_;

    my ($message, $href, $other_image, %attr, $text_alternative);
    my ($protocol, $domain, $file_path, $query, $new_url);

    #
    # Get URL of image, both with and without the protocol & domain
    # portion.  Image URLs from a configuration file do not include
    # a protocol or domain, just the file path portion.
    #
    $href = $link->abs_url;
    ($protocol, $domain, $file_path, $query, $new_url) =
        URL_Check_Parse_URL($href);
    $file_path = "/$file_path";

    #
    # Check to see if this image's URL appears in the non-decorative
    # image list
    #
    if ( defined($$decorative_images{$href}) ) {
        $other_image = $$decorative_images{$href};
    } elsif  ( defined($$decorative_images{$file_path}) ) {
        $other_image = $$decorative_images{$file_path};
    }

    #
    # Non decorative image should not appear in the decorative
    # list.
    #
    print "Check_Non_Decorative_Image href = $href\n" if $debug;
    if ( defined($other_image) ) {
        #
        # Decorative image instance found in as non-decorative
        #
        print "Decorative $href image found as non-decorative\n" if $debug;
        
        #
        # Get text alternative
        #
        %attr = $link->attr();
        if ( ! ($link->alt =~ /^\s*$/) ) {
            $text_alternative = $link->alt;
        }
        elsif ( defined($attr{"aria-label"}) ) {
            $text_alternative = $attr{"aria-label"};
        }
        elsif ( defined($attr{"aria-labelledby"}) ) {
            $text_alternative = $attr{"aria-labelledby"};
        }
        elsif ( defined($attr{"aria-describedby"}) ) {
            $text_alternative = $attr{"aria-describedby"};
        }
        elsif ( defined($attr{"title"}) ) {
            $text_alternative = $attr{"title"};
        }

        #
        # Create error message
        #
        $message = String_Value("Non null text alternative") .
                                " \"$text_alternative\" " .
                                String_Value("in decorative image");

        #
        # Add URL if image was in the decorative image list.
        #
        if ( $other_image->referer_url eq "LIST" ) {
            $message .= String_Value("Image URL in decorative list");
        }
        else {
            #
            # URL was not provided in a list, it must have been
            # 'learned'. Provide URL when image was first found.
            #
            $message .= String_Value("Image first found in URL") .
                        $other_image->referer_url;
        }

        #
        # Record result.
        #
        Record_Result("WCAG_2.0-F39", $link->line_no, $link->column_no,
                      $link->source_line, $message);
    }
    #
    # If this image is not already in the non-decorative list,
    # add it.
    #
    elsif ( (! defined($$non_decorative_images{$href})) &&
            (! defined($$non_decorative_images{$file_path})) ) {
        #
        # Add image to list
        #
        print "Add non-decorative $href image to list\n" if $debug;
        if ( keys(%$non_decorative_images) < $MAX_IMAGE_COUNT ) {
            $$non_decorative_images{$href} = $link;
        }
    }
    
    #
    # Check that if a role attribute is specified, it has the value "presentation".
    #
    print "Check non-decorative image role\n" if $debug;
    %attr = $link->attr();
    if ( defined($attr{"role"}) && ($attr{"role"} eq "presentation") ) {
        #
        # Invalid role value
        #
        Record_Result("WCAG_2.0-F38", $link->line_no, $link->column_no,
                      $link->source_line,
                      String_Value("Invalid role text value") . " 'role=\"" .
                      $attr{"role"} . "\"' " . String_Value("in non-decorative image"));
    }
}

#***********************************************************************
#
# Name: TQA_Check_Images
#
# Parameters: tqa_results_list - address of hash table results
#             url - URL
#             profile - testcase profile
#             links - address of list of link objects
#             decorative_images - address of hash table of decorative images
#             non_decorative_images - address of hash table of non decorative
#               images
#
# Description:
#
#    This function performs a number of checks on images found within a
# document.  It checks to see if images are used consistently with
# respect to being decorative or non-directorive.
#
#***********************************************************************
sub TQA_Check_Images {
    my ($tqa_results_list, $url, $profile, $links,
        $decorative_images, $non_decorative_images) = @_;

    my ($result_object, @local_tqa_results_list, $link);
    my ($is_decorative, $is_image, $href, $other_image);
    my ($message, $resp, %attr, $tcid);

    #
    # Do we have a valid profile ?
    #
    print "TQA_Check_Images: profile = $profile\n" if $debug;
    if ( ! defined($tqa_check_profile_map{$profile}) ) {
        print "Unknown TQA testcase profile passed $profile\n" if $debug;
        return;
    }

    #
    # Initialize the test case pass/fail table.
    #
    $current_tqa_check_profile = $tqa_check_profile_map{$profile};
    $results_list_addr = \@local_tqa_results_list;
    $current_landmark = "";
    $landmark_marker = "";

    #
    # Save URL in global variable
    #
    if ( ($url =~ /^http/i) || ($url =~ /^file/i) ) {
        $current_url = $url;
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of HTML
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Loop through the link object array looking for image links
    #
    foreach $link (@$links) {
        $is_image = 0;
        
        #
        # Is this link from a url function (CSS) and its mime-type an image ?
        #
        print "Type = " . $link->link_type . " mime-type = " . $link->mime_type . "\n" if $debug;
        if ( $link->link_type eq "url") {
            #
            # Are we missing a mime-type ? and do we have a valid link ?
            #
            if ( (! defined($link->mime_type)) &&
                 (! defined($link->link_status)) ) {
                #
                # Get link status
                #
                ($link, $resp) = Link_Checker_Get_Link_Status($url, $link);
            }
            
            #
            # Do we have a mime type and is it an image ?
            #
            if ( defined($link->mime_type) &&
                ($link->mime_type =~ /^image/i) ) {
                #
                # This is a decorative image
                #
                $is_decorative = 1;
                $is_image = 1;
                print "Decorative image loaded through CSS\n" if $debug;
            }
        }
        #
        # Is this link from an <img> tag (HTML) and its mime-type an image ?
        #
        elsif ( $link->link_type eq "img" ) {
            #
            # Are we missing a mime-type ? and do we have a valid link ?
            #
            if ( (! defined($link->mime_type)) &&
                 (! defined($link->link_status)) ) {
                #
                # Get link status
                #
                ($link, $resp) = Link_Checker_Get_Link_Status($url, $link);
            }

            #
            # Do we have a mime type and is it an image ?
            #
            if ( defined($link->mime_type) &&
                ($link->mime_type =~ /^image/i) ) {
                #
                # If the image has no alt, aria-label, aria-labelledby,
                # aria-describedby or title attribue it is
                # decorative, otherwise it is non decorative
                #
                %attr = $link->attr();
                if ( ! ($link->alt =~ /^\s*$/) ) {
                    $is_decorative = 0;
                    print "Non-Decorative image with alt text\n" if $debug;
                }
                elsif ( defined($attr{"aria-label"}) &&
                        ($attr{"aria-label"} ne "") ) {
                    $is_decorative = 0;
                    print "Non-Decorative image with aria-label\n" if $debug;
                }
                elsif ( defined($attr{"aria-labelledby"}) &&
                        ($attr{"aria-labelledby"} ne "") ) {
                    $is_decorative = 0;
                    print "Non-Decorative image with aria-labelledby\n" if $debug;
                }
                elsif ( defined($attr{"aria-describedby"}) &&
                        ($attr{"aria-describedby"} ne "") ) {
                    $is_decorative = 0;
                    print "Non-Decorative image with aria-describedby\n" if $debug;
                }
                elsif ( defined($attr{"title"}) &&
                        ($attr{"title"} ne "") ) {
                    $is_decorative = 0;
                    print "Non-Decorative image with title\n" if $debug;
                }
                else {
                    $is_decorative = 1;
                    print "Decorative image\n" if $debug;
                }
                $is_image = 1;
            }
        }

        #
        # Is this an image ?
        #
        if ( $is_image ) {
            #
            # Is this image is a decorative image ?
            #
            if ( $is_decorative ) {
                Check_Decorative_Image($link, $decorative_images,
                                       $non_decorative_images);
            }
            #
            # Must be non decorative image
            #
            else {
                Check_Non_Decorative_Image($link, $decorative_images,
                                           $non_decorative_images);
            }
        }
    }

    #
    # Add our results to previous results
    #
    foreach $result_object (@local_tqa_results_list) {
        #
        # Add help URL to result
        #
        $tcid = $result_object->testcase();
        if ( defined(TQA_Testcase_URL($tcid)) ) {
            $result_object->help_url(TQA_Testcase_URL($tcid));
        }

        #
        # Add result object to list provided in the
        # function call.
        #
        push(@$tqa_results_list, $result_object);
    }
}

#***********************************************************************
#
# Name: TQA_Check_Add_To_Image_List
#
# Parameters: image_list_hash - address of hash table of images
#             image_list - list of image URLs
#
# Description:
#
#    This function adds the URLs from the image list to the image
# list hash table.  The image URLs are added in such as way that
# they are recognised as URLs from a configuration list rather than
# images learned from analysing documents.
#
#***********************************************************************
sub TQA_Check_Add_To_Image_List {
    my ($image_list_hash, @image_list) = @_;

    my ($link_object, $image);

    #
    # Add images to list
    #
    print "TQA_Check_Add_To_Image_List\n" if $debug;
    foreach $image (@image_list) {
        #
        # Create new link object for this image and set the referer URL
        # to LIST to indicate this image came from tool configuration.
        #
        print "Add image $image to list\n" if $debug;
        $link_object = link_object->new($image, $image, "", "img", "",
                                        -1, -1, "");
        $link_object->referer_url("LIST");

        #
        # Add link object to hash table
        #
        $$image_list_hash{$image} = $link_object;
    }
}

#***********************************************************************
#
# Name: TQA_Check_Compliance_Score
#
# Parameters: profile - testcase profile
#             results_list - list of resultobjects
#
# Description:
#
#    This function computes a compliance score, the percentage of test
# case groups that do not have failures.  It also returns the total number
# of faults found and a table of fault counts by test group.
#
#***********************************************************************
sub TQA_Check_Compliance_Score {
    my ($profile, @results_list) = @_;
    
    my ($score, %faults_by_group, $testgroups, $group);
    my (@testcase_group_list, $result, $group_count, $profile_type);
    my ($faults) = 0;
    my ($groups_with_faults) = 0;

    #
    # Do we have a valid profile ?
    #
    print "TQA_Check_Compliance_Score profile = $profile\n" if $debug;
    if ( ! defined($tqa_check_profile_map{$profile}) ) {
        print "Unknown TQA testcase profile passed $profile\n" if $debug;
        return;
    }

    #
    # Does this profile have a profile type ?
    #
    if ( ! defined($tqa_testcase_profile_types{$profile}) ) {
        print "No profile type for profile $profile\n" if $debug;
        return;
    }
    else {
        #
        # Do we have a testcase group count for this profile type ?
        #
        $profile_type = $tqa_testcase_profile_types{$profile};
        if ( TQA_Testcase_Group_Count($profile_type) eq "" ) {
            print "No testcase groups for profile type $profile_type\n" if $debug;
            return;
        }
    }
    $group_count = TQA_Testcase_Group_Count($profile_type);

    #
    # Do we have any results ?
    #
    if ( @results_list > 0 ) {
        foreach $result (@results_list) {
            #
            # Increment total fault count.
            #
            $faults++;

            #
            # Get list of testcase groups
            #
            print "Testcase " . $result->testcase . " groups " .
                  $result->testcase_groups . "\n" if $debug;
            $testgroups = $result->testcase_groups;
            $testgroups =~ s/\s//g;
            @testcase_group_list = split(/,/, $testgroups);
            
            #
            # Increment counts for each group
            #
            foreach $group (@testcase_group_list) {
                if ( defined($faults_by_group{$group}) ) {
                    $faults_by_group{$group}++;
                }
                else {
                    $faults_by_group{$group} = 1;
                    $groups_with_faults++;
                }
            }
        }
        
        #
        # Compliance score is
        #
        #  total number of groups - groups with faults
        #  --------------------------------------------  * 100%
        #                total number of groups
        #
        print "Compliance score = ($group_count - $groups_with_faults) / $group_count * 100\n" if $debug;
        $score = int(($group_count - $groups_with_faults) / $group_count * 100);
    }
    else {
        #
        # No faults, compliance score is 100%
        #
        $score = 100;
    }
    
    #
    # Return score, faults and fault table.
    #
    print "Score = $score, faults = $faults\n" if $debug;
    return($score, $faults, %faults_by_group);
}

#***********************************************************************
#
# Name: TQA_Check_Profile_Types
#
# Parameters: %local_profile_types - type of testcase profiles
#
# Description:
#
#    This function saves the profile/profile-type table in a
# global variable.
#
#***********************************************************************
sub TQA_Check_Profile_Types {
    my (%local_profile_types) = @_;

    #
    # Save profile values in global variable
    #
    %tqa_testcase_profile_types = %local_profile_types;
}

#***********************************************************************
#
# Name: TQA_Check_Set_Exemption_Markers
#
# Parameters: marker_type - marker type
#             data - string of data
#
# Description:
#
#   This function copies the passed data into a hash table
# for the specified exemption marker type.  Valid marker types
# include:
#    metadata
#
#***********************************************************************
sub TQA_Check_Set_Exemption_Markers {
    my ($marker_type, $data) = @_;

    #
    # Do we already have a marker type value ? if so append
    # this new data to it with a new line separator.
    #
    if ( defined($exemption_markers{$marker_type}) ) {
        $exemption_markers{$marker_type} .= "\n$data";
    }
    else {
        if ( defined($data) ) {
            $exemption_markers{$marker_type} = $data;
        }
        else {
            $exemption_markers{$marker_type} = "";
        }
    }
    $have_exemption_markers = 1;
}

#***********************************************************************
#
# Name: Check_Metadata_Expression
#
# Parameters: tag - Metadata tag
#             expression - expression test
#             metadata_object - metadata result object
#
# Description:
#
#   This function checks the metadata item content against the supplied
# expression.  The result of the expession is returned.
#
#***********************************************************************
sub Check_Metadata_Expression {
    my ($tag, $expression, $metadata_object) = @_;
    
    my ($type, $operator, $value, $orig_value, $content);
    my ($result) = 0;

    #
    # Parse out the components of the expression
    #
    ($type, $operator, $value) = split(/\s+/, $expression, 3);
    print "Check_Metadata_Expression type = $type, operator = $operator value = $value\n" if $debug;

    #
    # If we have a value we have a valid expression
    #
    if ( defined($value) ) {
        #
        # Get metadata content
        #
        $content = $metadata_object->content;
        print "Metadata content = $content\n" if $debug;
        
        #
        # Check the type, we may have to modify the content
        #
        if ( $type =~ /^date$/i ) {
            #
            # Strip out - and space separators from date values
            #
            $content =~ s/[-\s]//g;
            $orig_value = $value;
            $value =~ s/[-\s]//g;
            
            #
            # Check the operator
            #
            if ( $operator eq ">" ) {
                #
                # Is content greater (or newer) than the value ?
                #
                print "Compare $content > $value\n" if $debug;
                if ( $content > $value ) {
                    $result = 1;
                }
                else {
                    $result = 0;
                }
            }
            elsif ( $operator eq "<" ) {
                #
                # Is content less (or older) than the value ?
                #
                print "Compare $content < $value\n" if $debug;
                if ( $content < $value ) {
                    $result = 1;
                }
                else {
                    $result = 0;
                }
            }
        }
    }

    #
    # Return results
    #
    print "Result = $result\n" if $debug;
    return($result);
}

#***********************************************************************
#
# Name: Check_HTML_Exempt
#
# Parameters: url - URL
#             is_archived - flag to inticate if content is
#                           marked "Archived on the Web"
#             content - content pointer
#
# Description:
#
#    This function checks to see if the URL is exempt from TQA checking.
# A document may be except if it is archived and published before a
# particular date.
#
#***********************************************************************
sub Check_HTML_Exempt {
    my ($url, $is_archived, $content) = @_;

    my (%metadata, $metadata_check, $tag, $expression);
    my ($is_exempt) = 0;

    #
    # If document is not archived, it cannot be exempt.
    #
    print "Check_HTML_Exempt $url\n" if $debug;
    if ( ! $is_archived ) {
        print "Not archived\n" if $debug;
        return(0);
    }

    #
    # Do we have some metadata expressions to check ?
    #
    if ( defined($exemption_markers{"metadata"}) &&
         ($exemption_markers{"metadata"} ne "") ) {
        #
        # Get metadata from the document
        #
        print "Have Metadata exemption markers\n" if $debug;
        %metadata = Extract_Metadata($url, $content);

        #
        # Split markers on new line as there may be several checks
        #
        foreach $metadata_check (split(/\n/, $exemption_markers{"metadata"})) {
            #
            # Split check on the first space to get the tag name, type and the expression
            #
            ($tag, $expression) = split(/\s+/, $metadata_check, 2);

            #
            # Do we have a metadata item for this tag ?
            #
            if ( defined($metadata{$tag}) ) {
                #
                # Compute expression against the metadata value
                #
                print "Check tag $tag against expression $expression\n" if $debug;
                if ( Check_Metadata_Expression($tag, $expression, $metadata{$tag}) ) {
                    $is_exempt = 1;
                    last;
                }
            }
            else {
                print "Document does not contain metadata tag $tag\n" if $debug;
            }
        }
    }

    #
    # Return exemption status
    #
    print "Exemption = $is_exempt\n" if $debug;
    return($is_exempt);
}

#***********************************************************************
#
# Name: Check_PDF_Exempt
#
# Parameters: url - URL
#             is_archived - flag to inticate if content is
#                           marked "Archived on the Web"
#             content - content pointer
#             url_list - address of a table of URLs
#
# Description:
#
#    This function checks to see if the URL is exempt from TQA checking.
# A PDF document may be except if there is an HTML equivalent document.
#
#***********************************************************************
sub Check_PDF_Exempt {
    my ($url, $is_archived, $content, $url_list) = @_;

    my ($pattern, $html_url);
    my ($is_exempt) = 0;

    #
    # Convert PDF URL into an HTML url by replacing the
    # .pdf suffix with .html
    #
    print "Check_PDF_Exempt $url\n" if $debug;
    $html_url = $url;
    $html_url =~ s/\.pdf$/.html/i;

    #
    # Do we have an HTML URL in the table ?
    #
    print "Check for HTML URL = $html_url\n" if $debug;
    if ( defined($$url_list{$html_url}) ) {
        print "Found HTML version of PDF file at $html_url\n" if $debug;
        $is_exempt = 1;
    }
    #
    # Do we have an exemption marker for PDF documents ?
    #
    elsif ( defined($exemption_markers{"PDF"}) ) {
        #
        # HTML document was not in the same directory as the PDF.
        # See if there are other paths that PDF documents
        # can be found in.
        #
        foreach $pattern (split(/\n/, $exemption_markers{"PDF"})) {
            #
            # Construct HTML url from PDF url
            #
            $html_url = $url;
            $html_url =~ s/\.pdf$/.html/i;

            #
            # Remove the $pattern directory
            #
            $html_url =~ s/\/$pattern\//\//g;

            #
            # Do we have an HTML URL in the table ?
            #
            print "Check for HTML URL = $html_url\n" if $debug;
            if ( defined($$url_list{$html_url}) ) {
                print "Found HTML version of PDF file at $html_url\n" if $debug;
                $is_exempt = 1;
                last;
            }
        }
    }

    #
    # Return exemption status
    #
    print "Exemption = $is_exempt\n" if $debug;
    return($is_exempt);
}

#***********************************************************************
#
# Name: TQA_Check_Exempt
#
# Parameters: url - URL
#             mime_type - mime-type of content
#             is_archived - flag to inticate if content is
#                           marked "Archived on the Web"
#             content - content pointer
#             url_list - address of a table of URLs
#
# Description:
#
#    This function checks to see if the URL is exempt from TQA checking.
# A document may be except if it is
#  a) archived and published before a particular date
#  b) is a PDF document and there exist and HTML version of the document
#
#***********************************************************************
sub TQA_Check_Exempt {
    my ($url, $mime_type, $is_archived, $content, $url_list) = @_;

    my ($is_exempt) = 0;

    #
    # Do we have any exemption markers
    #
    print "TQA_Check_Exempt $url\n" if $debug;
    if ( ! $have_exemption_markers ) {
        print "No exemption markers\n" if $debug;
        return(0);
    }

    #
    # Is it HTML content?
    #
    if ( $mime_type =~ /text\/html/ ) {
        $is_exempt = Check_HTML_Exempt($url, $is_archived, $content);
    }
    #
    # Do we have application/pdf mime type ?
    #
    elsif ( $mime_type =~ /application\/pdf/ ) {
        $is_exempt = Check_PDF_Exempt($url, $is_archived, $content, $url_list);
    }

    #
    # Return exemption status
    #
    print "Exemption = $is_exempt\n" if $debug;
    return($is_exempt);
}

#***********************************************************************
#
# Name: TQA_Check_Need_Validation
#
# Parameters: profile - testcase profile
#
# Description:
#
#   This function checks to see if markup validation results
# are needed for the accessibility testcase profile specified.
#
#***********************************************************************
sub TQA_Check_Need_Validation {
    my ($profile) = @_;

    my ($tqa_check_profile);
    my ($need_validation) = 0;

    #
    # Is this a valid profile ?
    #
    print "TQA_Check_Need_Validation: profile = $profile\n" if $debug;
    if ( defined($tqa_check_profile_map{$profile}) ) {
        #
        # Does the profile include the testcase id related to markup
        # validation ?
        #
        $tqa_check_profile = $tqa_check_profile_map{$profile};
        if ( defined($$tqa_check_profile{"WCAG_2.0-G134"}) ) {
            $need_validation = 1;
        }
    }
    else {
        print "Invalid testcase profile \"$profile\" passed to TQA_Check_Need_Validation\n";
    }

    #
    # Return flag indicating whether or not validation is required
    #
    return($need_validation);
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

