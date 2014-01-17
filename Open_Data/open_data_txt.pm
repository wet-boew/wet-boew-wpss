#***********************************************************************
#
# Name:   open_data_txt.pm
#
# $Revision: 6526 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Open_Data/Tools/open_data_txt.pm $
# $Date: 2014-01-06 11:29:39 -0500 (Mon, 06 Jan 2014) $
#
# Description:
#
#   This file contains routines that parse TXT files and check for
# a number of open data check points.
#
# Public functions:
#     Set_Open_Data_TXT_Language
#     Set_Open_Data_TXT_Debug
#     Set_Open_Data_TXT_Testcase_Data
#     Set_Open_Data_TXT_Test_Profile
#     Open_Data_TXT_Check_Dictionary
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

package open_data_txt;

use strict;
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
    @EXPORT  = qw(Set_Open_Data_TXT_Language
                  Set_Open_Data_TXT_Debug
                  Set_Open_Data_TXT_Testcase_Data
                  Set_Open_Data_TXT_Test_Profile
                  Open_Data_TXT_Check_Dictionary
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
my ($tag_count);

my ($max_error_message_string)= 2048;

#
# Status values
#
my ($check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Fails validation",              "Fails validation",
    "No terms in found data dictionary", "No terms found in data dictionary",
    "No content in file",            "No content in file",
    "Multiple lines found in term",  "Multiple lines found in term",
    "Duplicate term",                "Duplicate term",
    "Previous instance found at",    "Previous instance found at line ",
    "Multiple blank lines after term", "Multiple blank lines after term",
    "Expect at least 2 blank lines after definition", "Expect at least 2 blank lines after definition",
    "Extra term in dictionary",      "Extra term in dictionary",
    "Term missing from dictionary",  "Term missing from dictionary",
    "No definition for term",        "No definition for term",
    "No terms found in dictionary",  "No terms found in dictionary",
    );

my %string_table_fr = (
    "Fails validation",              "Échoue la validation",
    "No terms found in data dictionary", "Pas de termes trouvés dans dictionnaire de données",
    "No content in file",            "Aucun contenu dans fichier",
    "Multiple lines found in term",  "Plusieurs lignes trouvées dans le terme",
    "Duplicate term",                "Doublon term",
    "Previous instance found at",    "Instance précédente trouvée à la ligne ",
    "Multiple blank lines after term", "Plusieurs lignes vides aprés terme",
    "Expect at least 2 blank lines after definition", "Attendez au moins 2 lignes vides aprés définition",
    "Extra term in dictionary",      "Terme supplémentaire dans dictionnaire",
    "Term missing from dictionary",  "Terme manquant de dictionnaire",
    "No definition for term",        "Aucune définition pour terme",
    "No terms found in dictionary",  "Pas de termes trouvés dans le dictionnaire",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_Open_Data_TXT_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Open_Data_TXT_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_Open_Data_TXT_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Open_Data_TXT_Language {
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
# Name: Set_Open_Data_TXT_Testcase_Data
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
sub Set_Open_Data_TXT_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_Open_Data_TXT_Test_Profile
#
# Parameters: profile - CSV check test profile
#             testcase_names - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by CSV testcase name.
#
#***********************************************************************
sub Set_Open_Data_TXT_Test_Profile {
    my ($profile, $testcase_names) = @_;

    my (%local_testcase_names);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Open_Data_TXT_Test_Profile, profile = $profile\n" if $debug;
    %local_testcase_names = %$testcase_names;
    $open_data_profile_map{$profile} = \%local_testcase_names;
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - CSV check test profile
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
    $current_open_data_profile = $open_data_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;
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
# Name: Parse_Text_Dictionary
#
# Parameters: content - text content
#             dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function parses a block of text that is expected to be a
# data dictionary.  The terms and definitions are expected to follow
# the WCAG 2.0 T3 text heading technique.
#
#  Term
#     <blank line>
#  Definition
#    <definition lines>...
#    <blank line>
#    <blank line>
#
#***********************************************************************
sub Parse_Text_Dictionary {
    my ($content, $dictionary) = @_;

    my ($in_term, $found_term, $in_definition, $line, $term);
    my ($line_no, $blank_line_count, $current_text);
    my (%terms_and_definitions, %term_location, $have_dictionary);

    #
    # Initialize flags and counters
    #
    print "Parse_Text_Dictionary\n" if $debug;
    $in_term = 0;
    $in_definition = 0;
    $line_no = 0;
    $current_text = "";

    #
    # Do we already have a dictionary of terms ? (this could be the first
    # call to this routine).
    #
    if ( keys(%$dictionary) > 0 ) {
        $have_dictionary = 1;
    }
    else {
        $have_dictionary = 0;
    }

    #
    # Initialize blank line count to 2, this way if the text starts with 
    # a term line, we wont skip it because it is not preceeded by 2
    # blank lines.
    #
    $blank_line_count = 2;

    #
    # Split the content on newline
    #
    foreach $line (split(/\n/, $content)) {
        $line_no++;

        #
        # Remove leading and trailing white space
        #
        $line =~ s/^\s*//g;
        $line =~ s/\s+$//g;

        #
        # Is this a blank line ?
        #
        if ( $line =~ /^$/ ) {
            #
            # Increment blank line counter
            #
            $blank_line_count++;
            print "Have blank line $blank_line_count\n" if $debug;

            #
            # Are we inside a term ? This blank line would be the end of the
            # term.
            #
            if ( $in_term ) {
                #
                # We have found a term.
                #
                $in_term = 0;
                $found_term = 1;
                $term = $current_text;
                print "Found term $term on line $line_no\n" if $debug;

                #
                # Have we seen this term before ?
                #
                if ( defined($terms_and_definitions{$term}) ) {
                    Record_Result("OD_TXT_1", $line_no, 0, "$current_text",
                                  String_Value("Duplicate term") . 
                                  " \"$term\" " .
                                  String_Value("Previous instance found at") .
                                  $term_location{$term});
                }
                #
                # Is this term in the dictionary of expected terms ?
                #
                elsif ( $have_dictionary && (! defined($$dictionary{$term})) ) {
                    #
                    # Extra term in this data dictionary that does not exist
                    # in the previously defined dictionary
                    #
                    Record_Result("OD_TXT_1", $line_no, 0, "$current_text",
                                  String_Value("Extra term in dictionary") . 
                                  " \"$term\"");

                    #
                    # Add this term to the dictionary as we may encounter
                    # it when checking data files.
                    #
                    $$dictionary{$term} = $term;
                }
                else {
                    #
                    # Save term location in case we get duplicates.
                    #
                    $term_location{$term} = $line_no - 1;
                }

                #
                # Clear current text to allow for definition
                #
                $current_text = "";
            }
            #
            # Are we inside a definition ? This blank line would end the
            # definition.
            #
            elsif ( $in_definition ) {
                #
                # We have found a definition.
                #
                $in_definition = 0;
                print "Found definition $current_text on line $line_no\n" if $debug;

                #
                # Save term and definition
                #
                print "Add term $term to dictionary\n" if $debug;
                $terms_and_definitions{$term} = $current_text;

                #
                # Clear current term and definitions.
                #
                $term = "";
                $current_text = "";
            }
            #
            # Not in a term nor in a definition, did we last see a term
            # and not encountered a definition for several lines ?
            #
            elsif ( $found_term && ($blank_line_count > 1) ) {
                #
                # Several blank lines after a term and no definition found.
                #
                print "Several blank lines after term with no definition\n" if $debug;
                Record_Result("OD_TXT_1", $line_no, 0, "",
                              String_Value("Multiple blank lines after term"));

                #
                # Skip this term
                #
                $found_term = 0;
            }
        }
        #
        # A non-blank line
        #
        else {
            #
            # Are we inside a term ? This would be an error, terms are
            # expected to contain only 1 line of text.
            #
            print "Non blank line, in_term = $in_term, in_definition = $in_definition\n" if $debug;
            if ( $in_term ) {
                print "Blank line expected after term at line $line_no\n" if $debug;
                Record_Result("OD_TXT_1", $line_no, 0, "$line",
                              String_Value("Multiple lines found in term"));

                #
                # Try to skip ahead to the next term.
                #
                $in_term = 0;
            }
            #
            # Are we inside a definition ? This line would be a continuation
            # of the definition text.
            #
            elsif ( $in_definition ) {
                print "Next line of definition text\n" if $debug;
                $current_text .= "\n$line";
            }
            #
            # Not in a term nor a definition.  Is this the start of a
            # definition ? (i.e. found a term before this).
            #
            elsif ( $found_term ) {
                #
                # Start of a definition
                #
                print "Start definition at $line_no\n" if $debug;
                $in_definition = 1;
                $current_text = $line;
                $found_term = 0;
            }
            #
            # Not the start of a definition, must be the start of a term
            #
            else {
                print "Start term at $line_no\n" if $debug;
                $in_term = 1;
                $current_text = $line;

                #
                # Have we had at least 2 blank lines since the last
                # definition ?
                #
                if ( $blank_line_count < 2 ) {
                    Record_Result("OD_TXT_1", $line_no, 0, "$line",
                                  String_Value("Expect at least 2 blank lines after definition"));
                }
            }

            #
            # Clear blank line counter
            #
            $blank_line_count = 0;
        }
    }

    #
    # End of the content.  We may have ended on a definition with no
    # newline.  If this is the case, add it to the dictionary.
    #
    print "End of content at $line_no\n" if $debug;
    if ( $in_definition ) {
        #
        # We have found a definition.
        #
        $in_definition = 0;
        print "Found definition $current_text at end of content on line $line_no\n" if $debug;

        #
        # Save term and definition
        #
        print "Add term $term to dictionary\n" if $debug;
        $terms_and_definitions{$term} = $current_text;
    }
    #
    # We may have ended on a term without a definition
    #
    elsif ( $in_term ) {
        print "Found term at end of content with no definition\n" if $debug;
        Record_Result("OD_TXT_1", $line_no, 0, "",
                      String_Value("No definition for term") .
                      " \"$current_text\"");
    }

    #
    # If we did not already have a dictionary, use the one we just found
    #
    if ( ! $have_dictionary ) {
        print "Use current dictionary as expected dictionary\n" if $debug;
        %$dictionary = %terms_and_definitions;
    }
    #
    # Look for terms in the expected dictionary that are missing from the
    # one we just parsed.
    #
    else {
        #
        # Did we find any terms in this data dictionary ?
        #
        if ( keys(%terms_and_definitions) == 0 ) {
            Record_Result("OD_3", -1, 0, "",
                          String_Value("No terms found in dictionary") . 
                          " \"$term\"");
        }
        else {
            #
            # Check for missing terms.
            #
            foreach $term (keys(%$dictionary)) {
                if ( ! defined($terms_and_definitions{$term}) ) {
                    #
                    # Missing term.
                    #
                    Record_Result("OD_TXT_1", -1, 0, "",
                                 String_Value("Term missing from dictionary") . 
                                  " \"$term\"");
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Open_Data_TXT_Check_Dictionary
#
# Parameters: this_url - a URL
#             profile - testcase profile
#             content - text content
#             dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function runs a number of open data checks on TXT data file content.
#
#***********************************************************************
sub Open_Data_TXT_Check_Dictionary {
    my ( $this_url, $profile, $content, $dictionary ) = @_;

    my ($parser, $url, @tqa_results_list, $result_object, $testcase);

    #
    # Do we have a valid profile ?
    #
    print "Open_Data_TXT_Check_Dictionary: Checking URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($open_data_profile_map{$profile}) ) {
        print "Open_Data_TXT_Check_Dictionary: Unknown testcase profile passed $profile\n";
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
        # Doesn't look like a URL.  Could be just a block of text
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
    if ( length($content) == 0 ) {
        print "No content passed to Open_Data_TXT_Check_Dictionary\n" if $debug;
        Record_Result("OD_3", -1, 0, "",
                      String_Value("No content in file"));
    }
    else {
        #
        # Remove BOM from UTF-8 content ($EF $BB $BF)
        #  Byte Order Mark - http://en.wikipedia.org/wiki/Byte_order_mark
        #
        $content =~ s/^\xEF\xBB\xBF//;

        #
        # Parse the text looking for terms and definitions.
        # Make sure there is a blank line at the end of the content.
        #
        Parse_Text_Dictionary("$content\n", $dictionary);
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "Open_Data_TXT_Check_Dictionary results\n";
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
    my (@package_list) = ("tqa_result_object", "open_data_testcases");

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

