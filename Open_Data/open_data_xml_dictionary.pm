#***********************************************************************
#
# Name:   open_data_xml_dictionary.pm
#
# $Revision: 7623 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Open_Data/Tools/open_data_xml_dictionary.pm $
# $Date: 2016-07-13 03:34:36 -0400 (Wed, 13 Jul 2016) $
#
# Description:
#
#   This file contains routines that parse XML data dictionary files
# and check for a number of open data check points.
#
# Public functions:
#     Set_Open_Data_XML_Dictionary_Language
#     Set_Open_Data_XML_Dictionary_Debug
#     Set_Open_Data_XML_Dictionary_Testcase_Data
#     Set_Open_Data_XML_Dictionary_Test_Profile
#     Open_Data_XML_Dictionary_Check_Dictionary
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

package open_data_xml_dictionary;

use strict;
use URI::URL;
use File::Basename;
use XML::Parser;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Set_Open_Data_XML_Dictionary_Language
                  Set_Open_Data_XML_Dictionary_Debug
                  Set_Open_Data_XML_Dictionary_Testcase_Data
                  Set_Open_Data_XML_Dictionary_Test_Profile
                  Open_Data_XML_Dictionary_Check_Dictionary
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (%testcase_data, $results_list_addr);
my (@paths, $this_path, $program_dir, $program_name, $paths);
my (%open_data_profile_map, $current_open_data_profile, $current_url);
my ($tag_count, $save_text_between_tags, $saved_text, $heading_count);
my ($current_dictionary, %term_location, @required_description_languages);
my (%expected_description_languages, %found_description_languages);
my (%definitions_and_terms, $pattern_count, $dd_version, $heading_id);
my ($dictionary_object, %found_label_languages, $current_label_language);
my (%url_status, $current_lang, %definitions_and_terms_headings);
my ($url_status_count) = 0;
my ($max_url_status_count) = 100;

my ($max_error_message_string)= 2048;

#
# Status values
#
my ($check_fail)       = 1;
my ($missing_heading_id) = "*** MISSING HEADING ID ***";

#
# String table for error strings.
#
my %string_table_en = (
    "Broken link in",              "Broken link in",
    "Date",                        "Date ",
    "Date value",                  "Date value ",
    "does not match",              "does not match",
    "Duplicate description",       "Duplicate <description>",
    "Duplicate label",             "Duplicate <label>",
    "Encoding is not UTF-8, found", "Encoding is not UTF-8, found",
    "error",                       "error",
    "Expecting a URL in",          "Expecting a URL in",
    "Fails validation",            "Fails validation",
    "for",                         "for",
    "found",                       "found",
    "found for",                   "found for",
    "found in",                    "found in",
    "found outside of",            "found outside of",
    "in",                          "in",
    "in heading",                  " in <heading id=\"",
    "Invalid",                     "Invalid",
    "Invalid content",             "Invalid content: ",
    "Invalid data pattern",        "Invalid data pattern",
    "Invalid frequency value",     "Invalid <frequency> value",
    "Invalid mime-type for json url", "Invalid mime-type for JSON url",
    "Invalid PWGSC XML data dictionary", "Invalid PWGSC XML data dictionary",
    "label not found in",          "<label> not found in",
    "Missing beginning of line character", "Missing beginning of line character '^'",
    "Missing description for expected language", "Missing <description> for expected language",
    "Missing description for required language", "Missing <description> for required language",
    "Missing end of string character", "Missing end of string character '\$'",
    "Missing text in",             "Missing text in",
    "Missing xml:lang in",         "Missing xml:lang in",
    "Missing",                     "Missing",
    "Missing title for required language", "Missing <title> for required language",
    "Missing url for required language", "Missing <url> for required language",
    "Month",                       "Month ",
    "Multiple",                    "Multiple",
    "Multiple label tags in heading", "Multiple <label> tags in <heading>",
    "No content in file",          "No content in file",
    "No",                          "No",
    "No terms in found data dictionary", "No terms found in data dictionary",
    "not found in",                "not found in",
    "not in YYYY-MM-DD format",    " not in YYYY-MM-DD format",
    "out of range 1-12",           " out of range 1-12",
    "out of range 1-31",           " out of range 1-31",
    "out of range 1900-2100",      " out of range 1900-2100",
    "Previous instance found at",  "Previous instance found at line ",
    "tags found in",               "tags found in",
    "Year",                        "Year ",
    );

my %string_table_fr = (
    "Broken link in",              "Lien brisé dans",
    "Date",                        "Date ",
    "Date value",                  "Valeur à la date ",
    "does not match",              "ne correspond pas à",
    "Duplicate description",       "Doublon <description>",
    "Duplicate label",             "Doublon <label>",
    "Encoding is not UTF-8, found", "Encoding ne pas UTF-8, trouvé",
    "error",                       "erreur",
    "Expecting a URL in",          "Attendre un URL dans",
    "Fails validation",            "Échoue la validation",
    "for",                         "pour",
    "found",                       "trouvé",
    "found for",                   "trouvé pour",
    "found in",                    "trouvé dans",
    "found outside of",            "trouvent à l'extirieur de",
    "in",                          "dans",
    "in heading",                  " dans <heading id=\"",
    "Invalid",                     "Non valide",
    "Invalid content",             "Contenu non valide: ",
    "Invalid data pattern",        "Modèle de données non valides",
    "Invalid frequency value",     "<frequency> non valide",
    "Invalid mime-type for json url", "Invalid mime-type pour JSON url",
    "Invalid PWGSC XML data dictionary", "TPSGC dictionnaire de donnies XML non valide",
    "label not found in",          "<label> pas trouvé dans",
    "Missing beginning of line character", "Début de caractère de ligne manquant '^'",
    "Missing description for expected language", "<description> manquante pour la langue attendue",
    "Missing description for required language", "<description> manquante pour la langue requise",
    "Missing end of string character", "Caractère de fin de chaîne manquante '\$'",
    "Missing text in",             "Manquant texte dans",
    "Missing xml:lang in",         "Manquant xml:lang dans",
    "Missing",                     "Manquant",
    "Missing title for required language", "<title> manquante pour la langue requise",
    "Missing url for required language", "<url> manquante pour la langue requise",
    "Month",                       "Mois ",
    "Multiple",                    "Plusieurs",
    "Multiple label tags in heading", "Plusieurs balises <label> dans <heading>",
    "No content in file",          "Aucun contenu dans fichier",
    "No",                          "Aucun",
    "No terms found in data dictionary", "Pas de termes trouvés dans dictionnaire de données",
    "not found in",                "pas trouvé dans",
    "not in YYYY-MM-DD format",    " pas au format AAAA-MM-DD",
    "out of range 1-12",           " hors de portée 1-12",
    "out of range 1-31",           " hors de portée 1-31",
    "out of range 1900-2100",      " hors de portée 1900-2000",
    "Previous instance found at",  "Instance précédente trouvée à la ligne ",
    "tags found in",               "balises trouvées dans",
    "Year",                        "Année ",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_Open_Data_XML_Dictionary_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Open_Data_XML_Dictionary_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_Open_Data_XML_Dictionary_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Open_Data_XML_Dictionary_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
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
# Name: Set_Open_Data_XML_Dictionary_Testcase_Data
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
sub Set_Open_Data_XML_Dictionary_Testcase_Data {
    my ($testcase, $data) = @_;

    my ($type, $value);

    #
    # Is this data for required languages for descriptions ?
    #
    if ( $testcase eq "TP_PW_OD_XML_1" ) {
        ($type, $value) = split(/\s/, $data, 2);

        #
        # Is this a required language ?
        #
        if ( defined($value) && ($type eq "REQUIRED_LANG") ) {
            #
            # Save language
            #
            push(@required_description_languages, $value);
        }
    }
    else {
        #
        # Copy the data into the table
        #
        $testcase_data{$testcase} = $data;
    }
}

#***********************************************************************
#
# Name: Set_Open_Data_XML_Dictionary_Test_Profile
#
# Parameters: profile - open data check test profile
#             testcase_names - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by open data testcase name.
#
#***********************************************************************
sub Set_Open_Data_XML_Dictionary_Test_Profile {
    my ($profile, $testcase_names) = @_;

    my (%local_testcase_names);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Open_Data_XML_Dictionary_Test_Profile, profile = $profile\n" if $debug;
    %local_testcase_names = %$testcase_names;
    $open_data_profile_map{$profile} = \%local_testcase_names;
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - open data check test profile
#             local_results_list_addr - address of results list.
#             dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function initializes the test case results table and
# other global variables.
#
#***********************************************************************
sub Initialize_Test_Results {
    my ($profile, $local_results_list_addr, $dictionary) = @_;

    #
    # Set current hash tables
    #
    $current_open_data_profile = $open_data_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;

    #
    # Initialize variables
    #
    $current_dictionary = $dictionary;
    $current_label_language = "";
    %definitions_and_terms = ();
    %definitions_and_terms_headings = ();
    %expected_description_languages = ();
    %found_description_languages = ();
    $heading_count = 0;
    $heading_id = "";
    $pattern_count = 0;
    $save_text_between_tags = 0;
    $saved_text = "";
    $tag_count = 0;
    %term_location = ();
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
    my ( $testcase, $line, $column,, $text, $error_string ) = @_;

    my ($result_object);

    #
    # Is this testcase included in the profile
    #
    if ( defined($testcase) && defined($$current_open_data_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $check_fail,
                                                Open_Data_Testcase_Description($testcase),
                                                $line, $column, $text,
                                                $error_string, $current_url);
        push (@$results_list_addr, $result_object);

        #
        # Print error string to stdout
        #
        Print_Error($line, $column, $text, "$testcase : $error_string");
    }
}

#***********************************************************************
#
# Name: Start_Text_Handler
#
# Parameters: none
#
# Description:
#
#   This function starts a text handler. It initializes global
# variables for text capture.
#
#***********************************************************************
sub Start_Text_Handler {

    #
    # Enable text capture and initialize captured string
    #
    $save_text_between_tags = 1;
    $saved_text = "";
}

#***********************************************************************
#
# Name: Char_Handler
#
# Parameters: self - reference to this parser
#             string - text
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles text content between tags.
#
#***********************************************************************
sub Char_Handler {
    my ($self, $string) = @_;

    #
    # Are we saving text ?
    #
    if ( $save_text_between_tags ) {
        $saved_text .= $string;
    }
}

#***********************************************************************
#
# Name: Check_URL
#
# Parameters: self - reference to this parser
#             url - url to check
#             tag - current tag
#
# Description:
#
#   This function checks that the URL supplied is:
#  a valid URL
#  not a broken link
#
#***********************************************************************
sub Check_URL {
    my ($self, $url, $tag) = @_;
    
    my ($resp_url, $resp, $i, $u, $filename);
    
    #
    # Does the URL appear to be a well formed URL string ?
    #
    print "Check_URL, url = $url\n" if $debug;
    if ( URL_Check_Is_URL($url) ) {
        #
        # Have we seen this URL before ?
        #
        if ( ! defined($url_status{$url}) ) {
            #
            # Get the URL
            #
            ($resp_url, $resp) = Crawler_Get_HTTP_Response($url, "");
            
            #
            # We don't need to keep the actual contents, so if the contents
            # was saved in a local file, remove the local file.
            #
            $filename = $resp->header("WPSS-Content-File");

            #
            # Remove URL content file
            #
            if ( defined($filename) && ($filename ne "") ) {
                print "Remove content file $filename\n" if $debug;
                unlink($filename);
            }

            #
            # Have we filled up the URL status table ?
            #
            if ( $url_status_count > $max_url_status_count ) {
                print "Remove some entries from the url_status table\n" if $debug;
                $i = 0;
                foreach $u (keys(%url_status)) {
                    delete $url_status{$u};
                    $url_status_count--;
                    $i++;

                    #
                    # Have we removed enough URLs ?
                    #
                    if ( $i > 10 ) {
                        last;
                    }
                }
            }

            #
            # Increment URL status counter and save the HTTP::Response object
            #
            $url_status_count++;
            print "Save URL in url_status table, count = $url_status_count\n" if $debug;
            $url_status{$url} = $resp;

            #
            # If the response URL is not the same as the original URL,
            # save the HTTP::Response object under that URL also.
            #
            if ( $resp_url ne $url ) {
                $url_status_count++;
                print "Save rewritten URL $resp_url in url_status table, count = $url_status_count\n" if $debug;
                $url_status{$resp_url} = $resp;
            }
        }
        else {
            #
            # Get saved HTTP::Response object
            #
            $resp = $url_status{$url};
        }
        
        #
        # Is this a valid URI ?
        #
        if ( ! defined($resp) ) {
            Record_Result("TP_PW_OD_XML_1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Expecting a URL in") . " $tag " .
                          String_Value("found") . " \"$url\"");
        }
        #
        # Is it a broken link ?
        #
        elsif ( ! $resp->is_success ) {
            Record_Result("TP_PW_OD_XML_1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Broken link in") . " $tag " .
                          " URL = \"$url\"");
        }
    }
    else {
        #
        # Not a valid URL string
        #
        $url_status{$url} = $resp;
        Record_Result("TP_PW_OD_XML_1", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("Expecting a URL in") . " $tag " .
                      String_Value("found") . " \"$url\"");
    }
    
    #
    # Return HTTP::Response object
    #
    return($url_status{$url});
}

#***********************************************************************
#
# Name: Start_Data_Condition_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start data_condition tag.
#
#***********************************************************************
sub Start_Data_Condition_Tag_Handler {
    my ($self, %attr) = @_;

    #
    # Start a text handler to get the data_condition
    #
    Start_Text_Handler();
}

#***********************************************************************
#
# Name: End_Data_Condition_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the end data_condition tag.
#
#***********************************************************************
sub End_Data_Condition_Tag_Handler {
    my ($self) = @_;

    #
    # Do we have a text handler ?
    #
    if ( $save_text_between_tags ) {
        #
        # Remove newlines and leading whitespace
        #
        $saved_text =~ s/\r\n|\r|\n/ /g;
        $saved_text =~ s/^\s*//g;
        $saved_text =~ s/\s*$//g;

        #
        # Do we have a value ?
        #
        if ( $saved_text eq "" ) {
            Record_Result("TP_PW_OD_XML_1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Missing text in") . " <data_condition>");
        }
        else {
            #
            # Save the condition in the current dictionary object
            #
            if ( defined($dictionary_object) ) {
                print "Save data condition \"$saved_text\" in dictionary object\n" if $debug;
                $dictionary_object->condition($saved_text);
            }
        }
    }

    #
    # End any text handler
    #
    $save_text_between_tags = 0;
}

#***********************************************************************
#
# Name: Start_Data_Dictionary_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start data_dictionary tag which is used to
# identify PWGSC XML data dictionary files.
#
#***********************************************************************
sub Start_Data_Dictionary_Tag_Handler {
    my ($self, %attr) = @_;

    #
    # This tag applies to PWGSC defined XML data dictionaries only.
    # Check that this is the first tag and that it has a dd_version attribute.
    #
    if ( ($tag_count == 1 ) && defined($attr{"dd_version"}) ) {
        #
        # We have a PWGSC dictionary
        #
        $dd_version = $attr{"dd_version"};
        print "Found PWGSC Data Dictionary\n" if $debug;
    }
    
    #
    # Initialize dataset and heading counters
    #
    $heading_count = 0;
}

#***********************************************************************
#
# Name: End_Data_Dictionary_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the end PWGSC data_dictionary tag.
#
#***********************************************************************
sub End_Data_Dictionary_Tag_Handler {
    my ($self) = @_;

    #
    # Did we find any headers (terms) ?
    #
    if ( $heading_count == 0 ) {
        Record_Result("TP_PW_OD_XML_1", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("No") . " <heading> " .
                      String_Value("found in") . " <data_dictionary>");
    }
}

#***********************************************************************
#
# Name: Start_Data_Pattern_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start data_pattern tag.
#
#***********************************************************************
sub Start_Data_Pattern_Tag_Handler {
    my ($self, %attr) = @_;

    #
    # Increment the pattern count
    #
    $pattern_count++;

    #
    # Do we have multiple patterns within the heading ?
    #
    if ( $pattern_count > 1 ) {
        Record_Result("TP_PW_OD_XML_1", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("Multiple data_pattern tags in heading") .
                      " <heading id=\"$heading_id\">");
    }

    #
    # Start a text handler to get the heading
    #
    Start_Text_Handler();
}

#***********************************************************************
#
# Name: End_Data_Pattern_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the end data_pattern tag.
#
#***********************************************************************
sub End_Data_Pattern_Tag_Handler {
    my ($self) = @_;

    my ($eval_output, $error);
    
    #
    # Do we have a text handler ?
    #
    if ( $save_text_between_tags ) {
        #
        # Remove newlines and leading whitespace
        #
        $saved_text =~ s/\r\n|\r|\n/ /g;
        $saved_text =~ s/^\s*//g;
        $saved_text =~ s/\s*$//g;
        #$saved_text = lc($saved_text);

        #
        # Do we have a pattern ?
        #
        if ( $saved_text ne "" ) {
            print "Data pattern = \"$saved_text\"\n" if $debug;
            
            #
            # Is this a valid regular expression ?
            #
            $eval_output = eval { qr/$saved_text/ };
            if ( $@ ) {
                #
                # Remove perl module name and location from the error message
                #
                $error = $@;
                $error =~ s/<-- HERE \$\/ at .*/<-- HERE \//;
                Record_Result("TP_PW_OD_XML_1", $self->current_line,
                              $self->current_column, $self->original_string,
                              String_Value("Invalid data pattern") .
                              " \"$saved_text\" " . String_Value("error") .
                              " \"$error\"");
            }
            #
            # Do we have a beginning of line character ?
            #
            elsif ( substr($saved_text, 0, 1) ne '^' ) {
                Record_Result("TP_PW_OD_XML_1", $self->current_line,
                              $self->current_column, $self->original_string,
                              String_Value("Invalid data pattern") .
                              " \"$saved_text\". " .
                              String_Value("Missing beginning of line character"));
            }
            #
            # Do we have an end of string character ?
            #
            elsif ( substr($saved_text, -1, 1) ne '$' ) {
                Record_Result("TP_PW_OD_XML_1", $self->current_line,
                              $self->current_column, $self->original_string,
                              String_Value("Invalid data pattern") .
                              " \"$saved_text\". " .
                              String_Value("Missing end of string character"));
            }
            else {
                #
                # Save the pattern in the current dictionary object
                #
                if ( defined($dictionary_object) ) {
                    print "Save data pattern regex in dictionary object\n" if $debug;
                    $dictionary_object->regex($saved_text);
                }
            }
        }
        else {
            Record_Result("TP_PW_OD_XML_1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Missing text in") . " <data_pattern> ");
        }
    }

    #
    # End any text handler
    #
    $save_text_between_tags = 0;
}

#***********************************************************************
#
# Name: Start_Data_Type_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start data_type tag.
#
#***********************************************************************
sub Start_Data_Type_Tag_Handler {
    my ($self, %attr) = @_;

    #
    # Start a text handler to get the data_type
    #
    Start_Text_Handler();
}

#***********************************************************************
#
# Name: End_Data_Type_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the end data_type tag.
#
#***********************************************************************
sub End_Data_Type_Tag_Handler {
    my ($self) = @_;

    my ($resp);
    
    #
    # Do we have a text handler ?
    #
    if ( $save_text_between_tags ) {
        #
        # Remove newlines and leading whitespace
        #
        $saved_text =~ s/\r\n|\r|\n/ /g;
        $saved_text =~ s/^\s*//g;
        $saved_text =~ s/\s*$//g;

        #
        # Do we have a value ? It should be a URL
        #
        if ( $saved_text ne "" ) {
            #
            # Check that is this a valid URL
            #
            $resp = Check_URL($self, $saved_text, "<data_type>");
        }
        else {
            #
            # Missing value
            #
            Record_Result("TP_PW_OD_XML_1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Missing text in") . " <data_type>");
        }
    }

    #
    # End any text handler
    #
    $save_text_between_tags = 0;
}

#***********************************************************************
#
# Name: Start_Description_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start description tag.
#
#***********************************************************************
sub Start_Description_Tag_Handler {
    my ($self, %attr) = @_;

    my ($expected_languages);
    
    #
    # Check for language attribute
    #
    if ( defined($attr{"xml:lang"}) ) {
        $current_lang = $attr{"xml:lang"};
        print "Start description for language $current_lang\n" if $debug;

        #
        # If this is the first heading we need to record the expected language
        # values to check subsequent headers.
        #
        if ( $heading_count == 1 ) {
            $expected_description_languages{$current_lang} = 1;
        }

        #
        # Have we already seen a description for this language ?
        #
        if ( defined($found_description_languages{$current_lang}) ) {
            Record_Result("TP_PW_OD_XML_1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Multiple") .
                          " <description xml:lang=\"$current_lang\"> " .
                          String_Value("found for") .
                          " <heading id=\"$heading_id\">");
        }
        #
        # Is this a language that is not expected ? (i.e. a language
        # that did not appear in the first heading).
        #
        elsif ( ! defined($expected_description_languages{$current_lang}) ) {
            $expected_languages = join(", ", keys(%expected_description_languages));
            Record_Result("TP_PW_OD_XML_1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Invalid") .
                          " <description xml:lang=\"$current_lang\" " .
                          String_Value("found for") .
                          " <heading id=\"$heading_id\">");
        }
        #
        # Record language found
        #
        else {
            $found_description_languages{$current_lang} = 1;
        }
    }
    else {
        #
        # Missing language attribute
        #
        Record_Result("TP_PW_OD_XML_1", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("Missing xml:lang in") . " <description>");
    }

    #
    # Start a text handler to get the description
    #
    Start_Text_Handler();
}

#***********************************************************************
#
# Name: End_Description_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the end description tag.
#
#***********************************************************************
sub End_Description_Tag_Handler {
    my ($self) = @_;
    
    my ($lang_table_ptr, %lang_table, $heading_table_ptr, %heading_table);

    #
    # Do we have a text handler ?
    #
    if ( $save_text_between_tags ) {
        #
        # Remove newlines and leading whitespace
        #
        $saved_text =~ s/\r\n|\r|\n/ /g;
        $saved_text =~ s/^\s*//g;
        $saved_text =~ s/\s*$//g;

        #
        # Do we have a description ?
        #
        if ( $saved_text ne "" ) {
            print "Description = \"$saved_text\"\n" if $debug;
        }
        else {
            Record_Result("TP_PW_OD_XML_1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Missing text in") . " <description>");
        }

        #
        # Do we have a table for this language ?
        #
        if ( ! defined($definitions_and_terms{$current_lang}) ) {
            $definitions_and_terms{$current_lang} = \%lang_table;
            $definitions_and_terms_headings{$current_lang} = \%heading_table;
        }
        
        #
        # Have we seen this description before ?
        #
        $lang_table_ptr = $definitions_and_terms{$current_lang};
        $heading_table_ptr = $definitions_and_terms_headings{$current_lang};
        $saved_text = lc($saved_text);
        if ( defined($$lang_table_ptr{$saved_text}) ) {
            Record_Result("TP_PW_OD_XML_1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Duplicate description") .
                          " \"$saved_text\" " .
                          String_Value("Previous instance found at") .
                          $$lang_table_ptr{$saved_text} .
                          String_Value("in heading") .
                          $$heading_table_ptr{$saved_text} . "\">");
        }
        else {
            #
            # Save this definition
            #
            $$lang_table_ptr{$saved_text} = $self->current_line . ":" .
                                            $self->current_column;
            $$heading_table_ptr{$saved_text} = $heading_id;
        }
    }

    #
    # End any text handler
    #
    $save_text_between_tags = 0;
}

#***********************************************************************
#
# Name: Start_Heading_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start heading tag.
#
#***********************************************************************
sub Start_Heading_Tag_Handler {
    my ($self, %attr) = @_;

    #
    # Increment the heading count
    #
    $heading_count++;
    
    #
    # Set counters and other variables for this heading
    #
    $pattern_count = 0;
    %found_description_languages = ();
    %found_label_languages = ();
    
    #
    # Get the id attribute
    #
    if ( defined($attr{"id"}) ) {
        $heading_id = $attr{"id"};
        $heading_id =~ s/^\s*//g;
        $heading_id =~ s/\s*$//g;

        #
        # Do we have a value for the heading id ?
        #
        if ( $heading_id eq "" ) {
            Record_Result("TP_PW_OD_XML_1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Missing text in") . " <heading id=\"\">");
            $heading_id = $missing_heading_id;
        }
    }
    else {
        Record_Result("TP_PW_OD_XML_1", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("Missing") . " \"id\" " .
                      String_Value("in") . " <heading>");
        $heading_id = $missing_heading_id;
    }
    
    #
    # Create dictionary object
    #
    if ( ! defined($$current_dictionary{$heading_id}) ) {
        $dictionary_object = open_data_dictionary_object->new($heading_id);
    }
}

#***********************************************************************
#
# Name: End_Heading_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the end heading tag.
#
#***********************************************************************
sub End_Heading_Tag_Handler {
    my ($self) = @_;
    
    my ($new_dictionary_object, $lang, $label);
    
    #
    # Did we find a description in the heading ?
    #
    if ( scalar(keys(%found_description_languages)) == 0 ) {
        Record_Result("TP_PW_OD_XML_1", $self->current_line,
                      $self->current_column, $self->original_string,
                      "<description> " . String_Value("not found in") .
                      " <heading id=\"$heading_id\">");
    }

    #
    # Did we find all of the required description languages ?
    #
    foreach $lang (@required_description_languages) {
        if ( ! defined($found_description_languages{$lang}) ) {
            Record_Result("TP_PW_OD_XML_1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Missing description for required language") .
                          " xml:lang=\"$lang\" " . String_Value("in") .
                          " <heading id=\"$heading_id\">");
        }
    }

    #
    # Did we find the expected number of descriptions in the heading ?
    # There may be more expected than required descriptions.
    # The expected languages are determined from the first heading.
    #
    foreach $lang (keys(%expected_description_languages)) {
        if ( ! defined($found_description_languages{$lang}) ) {
            Record_Result("TP_PW_OD_XML_1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Missing description for expected language") .
                          " xml:lang=\"$lang\" " . String_Value("in") .
                          " <heading id=\"$heading_id\">");
        }
    }

    #
    # Did we find a label in the heading ?
    #
    if ( scalar(keys(%found_label_languages)) > 0 ) {
        #
        # Make a copy of the current dictionary object under all
        # labels that apply to this heading.
        #
        foreach $lang (keys(%found_label_languages)) {
            $label = $found_label_languages{$lang};
            print "Save dictionary object for label $label\n" if $debug;
            $new_dictionary_object = open_data_dictionary_object->new($label);
            $new_dictionary_object->regex($dictionary_object->regex());
            $new_dictionary_object->condition($dictionary_object->condition());
            $$current_dictionary{$label} = $new_dictionary_object;
        }
    }
    else {
        Record_Result("TP_PW_OD_XML_1", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("label not found in") . " <heading id=\"\">");
    }
    
    #
    # Set current dictionary object to null
    #
    undef($dictionary_object);
}

#***********************************************************************
#
# Name: Start_Headings_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start headings tag.
#
#***********************************************************************
sub Start_Headings_Tag_Handler {
    my ($self, %attr) = @_;

    #
    # Set headings count to 0
    #
    $heading_count = 0;
}

#***********************************************************************
#
# Name: End_Headings_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the end headings tag.
#
#***********************************************************************
sub End_Headings_Tag_Handler {
    my ($self) = @_;

    #
    # Did we find any heading tags in the headings ?
    #
    print "End headings tag, contains $heading_count heading tags\n" if $debug;
    if ( $heading_count == 0 ) {
        Record_Result("TP_PW_OD_XML_1", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("No") . " <heading> " .
                      String_Value("found in") . " <headings>");
    }
}

#***********************************************************************
#
# Name: Start_Label_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start label tag.
#
#***********************************************************************
sub Start_Label_Tag_Handler {
    my ($self, %attr) = @_;

    #
    # Check for language attribute
    #
    if ( defined($attr{"xml:lang"}) ) {
        $current_label_language = $attr{"xml:lang"};
        print "Start label for language $current_label_language\n" if $debug;
    }
    else {
        #
        # No language, use unknown
        #
        $current_label_language = "unknown";
        print "No defined language for label\n" if $debug;
    }

    #
    # Have we already seen a label for this language ?
    #
    if ( defined($found_label_languages{$current_label_language}) ) {
        print "Duplicate label language $current_label_language\n" if $debug;
        #
        # Was a language specified ?
        #
        if ( $current_label_language ne "unknown" ) {
            Record_Result("TP_PW_OD_XML_1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Multiple") .
                          " <label xml:lang=\"$current_label_language\"> " .
                          String_Value("found for") .
                          " <heading id=\"$heading_id\">");
        }
        else {
            Record_Result("TP_PW_OD_XML_1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Multiple") .
                          " <label> " .
                          String_Value("found for") .
                          " <heading id=\"$heading_id\">");
        }
    }
    else {
        #
        # Record language found
        #
        $found_label_languages{$current_label_language} = 1;
    }

    #
    # Start a text handler to get the heading
    #
    Start_Text_Handler();
}

#***********************************************************************
#
# Name: End_Label_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the end label tag.
#
#***********************************************************************
sub End_Label_Tag_Handler {
    my ($self) = @_;

    #
    # Do we have a text handler ?
    #
    if ( $save_text_between_tags ) {
        #
        # Remove newlines and leading whitespace
        #
        $saved_text =~ s/\r\n|\r|\n/ /g;
        $saved_text =~ s/^\s*//g;
        $saved_text =~ s/\s*$//g;

        #
        # Do we have a heading ?
        #
        if ( $saved_text ne "" ) {
            print "Label = \"$saved_text\"\n" if $debug;

            #
            # Have we already seen this term/heading ?
            #
            if ( defined($term_location{$saved_text}) ) {
                Record_Result("TP_PW_OD_XML_1", $self->current_line,
                              $self->current_column, $self->original_string,
                              String_Value("Duplicate label") .
                              " \"$saved_text\" " .
                              String_Value("Previous instance found at") .
                              $term_location{$saved_text});
            }
            else {
                #
                # Save term and location
                #
                $found_label_languages{$current_label_language} = $saved_text;
                $term_location{$saved_text} = $self->current_line . ":" .
                                              $self->current_column;
            }
        }
        else {
            Record_Result("TP_PW_OD_XML_1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Missing text in") . " <label>");
        }
    }

    #
    # End any text handler
    #
    $save_text_between_tags = 0;
}

#***********************************************************************
#
# Name: Start_Related_Resource_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start related_resource tag.
#
#***********************************************************************
sub Start_Related_Resource_Tag_Handler {
    my ($self, %attr) = @_;

    #
    # Start a text handler to get the related_resource
    #
    Start_Text_Handler();
}

#***********************************************************************
#
# Name: End_Related_Resource_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the end related_resource tag.
#
#***********************************************************************
sub End_Related_Resource_Tag_Handler {
    my ($self) = @_;

    my ($resp);

    #
    # Do we have a text handler ?
    #
    if ( $save_text_between_tags ) {
        #
        # Remove newlines and leading whitespace
        #
        $saved_text =~ s/\r\n|\r|\n/ /g;
        $saved_text =~ s/^\s*//g;
        $saved_text =~ s/\s*$//g;

        #
        # Do we have a value ? It should be a URL
        #
        if ( $saved_text ne "" ) {
            #
            # Check that is this a valid URL
            #
            $resp = Check_URL($self, $saved_text, "<related_resource>");
        }
        else {
            #
            # Missing value
            #
            Record_Result("TP_PW_OD_XML_1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Missing text in") . " <related_resource>");
        }
    }

    #
    # End any text handler
    #
    $save_text_between_tags = 0;
}

#***********************************************************************
#
# Name: Dictionary_Start_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles the start of XML tags for dictionary file.
#
#***********************************************************************
sub Dictionary_Start_Handler {
    my ($self, $tagname, %attr) = @_;

    my ($key, $value);

    #
    # Check tags.
    #
    print "Dictionary_Start_Handler tag $tagname\n" if $debug;
    $tag_count++;

    #
    # Check for data_condition tag.
    #
    if ( $tagname eq "data_condition" ) {
        Start_Data_Condition_Tag_Handler($self, %attr);
    }
    #
    # Check for PWGSC data_dictionary tag.
    #
    elsif ( $tagname eq "data_dictionary" ) {
        Start_Data_Dictionary_Tag_Handler($self, %attr);
    }
    #
    # Check for data_pattern tag.
    #
    elsif ( $tagname eq "data_pattern" ) {
        Start_Data_Pattern_Tag_Handler($self, %attr);
    }
    #
    # Check for data_type tag.
    #
    elsif ( $tagname eq "data_type" ) {
        Start_Data_Type_Tag_Handler($self, %attr);
    }
    #
    # Check for description tag.
    #
    elsif ( $tagname eq "description" ) {
        Start_Description_Tag_Handler($self, %attr);
    }
    #
    # Check for heading tag
    #
    elsif ( $tagname eq "heading" ) {
        Start_Heading_Tag_Handler($self, %attr);
    }
    #
    # Check for headings tag
    #
    elsif ( $tagname eq "headings" ) {
        Start_Headings_Tag_Handler($self, %attr);
    }
    #
    # Check for label tag
    #
    elsif ( $tagname eq "label" ) {
        Start_Label_Tag_Handler($self, %attr);
    }
    #
    # Check for related_resource tag
    #
    elsif ( $tagname eq "related_resource" ) {
        Start_Related_Resource_Tag_Handler($self, %attr);
    }
}

#***********************************************************************
#
# Name: Dictionary_End_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles end tags for dictionary files.
#
#***********************************************************************
sub Dictionary_End_Handler {
    my ($self, $tagname) = @_;

    #
    # Check tag
    #
    print "Dictionary_End_Handler tag $tagname\n" if $debug;

    #
    # Check for data_condition tag.
    #
    if ( $tagname eq "data_condition" ) {
        End_Data_Condition_Tag_Handler($self);
    }
    #
    # Check for PWGSC data_dictionary tag.
    #
    elsif ( $tagname eq "data_dictionary" ) {
        End_Data_Dictionary_Tag_Handler($self);
    }
    #
    # Check for data_pattern tag.
    #
    elsif ( $tagname eq "data_pattern" ) {
        End_Data_Pattern_Tag_Handler($self);
    }
    #
    # Check for data_type tag.
    #
    elsif ( $tagname eq "data_type" ) {
        End_Data_Type_Tag_Handler($self);
    }
    #
    # Check for description tag.
    #
    elsif ( $tagname eq "description" ) {
        End_Description_Tag_Handler($self);
    }
    #
    # Check for heading tag
    #
    elsif ( $tagname eq "heading" ) {
        End_Heading_Tag_Handler($self);
    }
    #
    # Check for headings tag
    #
    elsif ( $tagname eq "headings" ) {
        End_Headings_Tag_Handler($self);
    }
    #
    # Check for label tag
    #
    elsif ( $tagname eq "label" ) {
        End_Label_Tag_Handler($self);
    }
    #
    # Check for related_resource tag
    #
    elsif ( $tagname eq "related_resource" ) {
        End_Related_Resource_Tag_Handler($self);
    }
}

#***********************************************************************
#
# Name: Open_Data_XML_Dictionary_Check_Dictionary
#
# Parameters: this_url - a URL
#             profile - testcase profile
#             filename - XML content file
#             dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function runs a number of open data checks on XML data file content.
#
#***********************************************************************
sub Open_Data_XML_Dictionary_Check_Dictionary {
    my ($this_url, $profile, $filename, $dictionary) = @_;

    my ($parser, $url, @tqa_results_list, $result_object, $testcase);
    my ($eval_output);

    #
    # Do we have a valid profile ?
    #
    print "Open_Data_XML_Check_Dictionary: Checking URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($open_data_profile_map{$profile}) ) {
        print "Open_Data_XML_Check_Dictionary: Unknown testcase profile passed $profile\n";
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
        # Doesn't look like a URL.  Could be just a block of XML
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Initialize the test case pass/fail table and other global variables
    #
    Initialize_Test_Results($profile, \@tqa_results_list, $dictionary);

    #
    # Create a document parser
    #
    $parser = XML::Parser->new;

    #
    # Add handlers for some of the XML tags
    #
    $parser->setHandlers(Start => \&Dictionary_Start_Handler);
    $parser->setHandlers(End => \&Dictionary_End_Handler);
    $parser->setHandlers(Char => \&Char_Handler);

    #
    # Parse the content.
    #
    $eval_output = eval { $parser->parsefile($filename); 1 } ;

    #
    # Did the parse fail ?
    #
    if ( ! $eval_output ) {
        $eval_output = $@;
        $eval_output =~ s/ at [\w:\/\.]*Parser.pm line \d*.*$//g;
        Record_Result("OD_3", -1, 0, "$eval_output",
                      String_Value("Fails validation"));
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "Open_Data_XML_Check_Dictionary results\n";
        foreach $result_object (@tqa_results_list) {
            print "Testcase: " . $result_object->testcase;
            print "  message  = " . $result_object->message . "\n";
        }
    }

    #
    # Return list of results
    #
    return(@tqa_results_list);
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
    my (@package_list) = ("crawler", "open_data_dictionary_object",
                          "open_data_testcases", "tqa_result_object",
                          "url_check");

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

