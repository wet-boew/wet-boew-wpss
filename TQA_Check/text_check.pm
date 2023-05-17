#***********************************************************************
#
# Name:   text_check.pm
#
# $Revision: 2532 $
# $URL: svn://10.36.148.185/WPSS_Tool/TQA_Check/Tools/text_check.pm $
# $Date: 2023-05-10 14:10:23 -0400 (Wed, 10 May 2023) $
#
# Description:
#
#   This file contains routines that parses text blocks and check for
# a number of acceessibility (WCAG) check points.
#
# Public functions:
#     Set_Text_Check_Language
#     Set_Text_Check_Debug
#     Set_Text_Check_Testcase_Data
#     Set_Text_Check_Test_Profile
#     Text_Check
#
# Terms and Conditions of Use
#
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is
# distributed under the MIT License.
#
# MIT License
#
# Copyright (c) 2023 Government of Canada
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

package text_check;

use strict;

#
# Use WPSS_Tool program modules
#
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
    @EXPORT  = qw(Set_Text_Check_Language
                  Set_Text_Check_Debug
                  Set_Text_Check_Testcase_Data
                  Set_Text_Check_Test_Profile
                  Text_Check
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
my (%text_check_profile_map, $current_text_check_profile, $current_url);
my ($last_table_end);

my ($is_valid_markup) = -1;
my ($max_error_message_string)= 2048;

#
# Status values
#
my ($text_check_pass)       = 0;
my ($text_check_fail)       = 1;

#
# String table for error strings.
#
#
# String table for error strings.
#
my %string_table_en = (
    "after",                                  "after",
    "at line number",                         "at line number",
    "Expected a heading after 2 blank lines", "Expected a heading after 2 blank lines",
    "expecting",                              "expecting",
    "found",                                  "found",
    "Found an ordered list item in an unordered list", "Lists must not be nested, found an ordered list item in an unordered list",
    "Found an unordered list item in an ordered list", "Lists must not be nested, found an unordered list item in an ordered list",
    "Graphics character table found",         "Graphics character table found",
    "Heading must be a single line",          "Heading must be a single line",
    "Heading with no following content",      "Heading with no following content",
    "Inconsistent list item prefix",          "Lists must not be nested, inconsistent list item prefix",
    "List item value",                        "List item value",
    "More than 1 blank line between list items", "More than 1 blank line between list items",
    "No blank line between list items",       "No blank line between list items",
    "No content found between headings",      "No content found between headings",
    "Ordered list items not in sequential order", "Ordered list items not in sequential order",
    "Whitespace aligned table found",         "Whitespace aligned table found",
    );

my %string_table_fr = (
    "after",                                  "après",
    "at line number",                         "au numéro de ligne",
    "Expected a heading after 2 blank lines", "Attendu un en-tête après 2 lignes vides",
    "expecting",                              "expectant",
    "found",                                  "trouver",
    "Found an ordered list item in an unordered list", "Les listes ne doivent pas être imbriquées, trouver un élément de liste ordonnée dans une liste non ordonnée",
    "Found an unordered list item in an ordered list", "Les listes ne doivent pas être imbriquées, trouver un élément de liste non ordonnée dans une liste ordonnée",
    "Graphics character table found",         "Table de caractères graphiques trouvée",
    "Heading must be a single line",          "Le titre doit être une seule ligne",
    "Heading with no following content",      "Titre sans contenu suivant",
    "Inconsistent list item prefix",          "Les listes ne doivent pas être imbriquées, préfixe d'élément de liste incohérent",
    "List item value",                        "Valeur de l'élément de liste",
    "More than 1 blank line between list items", "Plus d'une ligne vide entre les éléments de la liste",
    "No blank line between list items",       "Pas de ligne vide entre les éléments de la liste",
    "No content found between headings",      "Aucun contenu trouvé entre les titres",
    "Ordered list items not in sequential order", "Les éléments de la liste ordonnée ne sont pas dans l'ordre séquentiel",
    "Whitespace aligned table found",         "Tableau aligné avec des espaces trouvés",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_Text_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Text_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_Text_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Text_Check_Language {
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
# Name: Set_Text_Check_Testcase_Data
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
sub Set_Text_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_Text_Check_Test_Profile
#
# Parameters: profile - XML check test profile
#             text_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by XML testcase name.
#
#***********************************************************************
sub Set_Text_Check_Test_Profile {
    my ($profile, $text_checks) = @_;

    my (%local_text_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Text_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_text_checks = %$text_checks;
    $text_check_profile_map{$profile} = \%local_text_checks;
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - XML check test profile
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
    $current_text_check_profile = $text_check_profile_map{$profile};
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
    my ( $testcase, $line, $column, $text, $error_string ) = @_;

    my ($result_object, $impact);

    #
    # Do we have a maximum number of errors to report and have we reached it?
    #
    if ( ($TQA_Result_Object_Maximum_Errors > 0) &&
         (@$results_list_addr >= $TQA_Result_Object_Maximum_Errors) ) {
        print "Skip reporting errors, maximum reached\n" if $debug;
        return;
    }

    #
    # Is this testcase included in the profile
    #
    if ( defined($testcase) && defined($$current_text_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $text_check_fail,
                                                TQA_Testcase_Description($testcase),
                                                $line, $column, $text,
                                                $error_string, $current_url);
        $result_object->testcase_groups(TQA_Testcase_Groups($testcase));
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
}

#***********************************************************************
#
# Name: Parse_Space_Aligned_Table
#
# Parameters: line - the current line from the content
#             array_index - index into the array of content lines
#             lines_addr - pointer to array of content lines
#
# Description:
#
#   This function reads the content for a possible whitespace aligned
# table (i.e. using multiple whitespace to align table cells)
#
#***********************************************************************
sub Parse_Space_Aligned_Table {
    my ($line, $array_index, $lines_addr) = @_;

    my ($pos, $text, $spacer, $remaining_text, %table, $row_addr, $row_count);
    my ($line_length, $j, $i);
    my ($end_of_table) = 0;
    my ($table_found) = 0;

    #
    # Does this potential table start just after a previous one (e.g. there
    # may be a blank line between the tables, so it may be just 1 table).
    #
    if ( defined($last_table_end) && ($i <= ($last_table_end + 2)) ) {
        print "Possible continuation of space aligned table starting at line $i\n" if $debug;
    }
    else {
        print "Possible space aligned table starting at line $i\n" if $debug;
        $last_table_end = $line;
    }

    #
    # Loop until end of file or we exit the loop at the end of the table
    #
    $row_count = 0;
    $i = $array_index;
    while ( defined($line) && (! $end_of_table) ) {
        chomp($line);
        $line_length = length($line);

        #
        # If this is a blank line, skip it.
        #
        if ( $line =~ /^\s*$/ ) {
            $i++;
            $line = $$lines_addr[$i];
            next;
        }

        #
        # Are there any multiple whitespace characters between non whitespace
        # characters? If not this is not a table row
        #
        if ( ! ($line =~ /\S\s\s+\S/) ) {
            $end_of_table = 1;
            $i++;
            print "End of table at content \"$line\"\n" if $debug;
            last;
        }

        #
        # Remove any leading whitespace
        #
        $line =~ s/^\s+//g;

        #
        # Assume each line is a new row, we don't look for multiline cells
        #
        undef($row_addr);

        #
        # Get all occurances of text between multiple whitespace characters.
        # Stop when the line only contains whitespace.
        #
        while ( ! ($line =~ /^\s*$/) ) {
            #
            # Get text before next multiple whitespace
            #
            ($text, $spacer, $remaining_text) = $line =~ /^(.*?)(\s\s+)(.*)$/;
            if ( $spacer =~ /^\s\s+/ ) {
                #
                # Get the position of the non-whitespace character that
                # follows the whitesace (i.e. get the position in the
                # line after the pattern).
                #
                $pos = $line_length - length($text) - length($spacer) - length($remaining_text);
                print "Non-whitespace character at position $pos\n" if $debug;
                print "   text = \"$text\"\n" if $debug;

                #
                # Found what may be a table cell. If we don't have a row yet
                # increment the row count. Save the cell location.
                #
                if ( ! defined($row_addr) ) {
                    my (@row);
                    $row_addr = \@row;
                    $row_count++;
                    $table{$row_count} = $row_addr;
                }
                push(@$row_addr, $pos);

                #
                # Remove the leading whitespace before the next possible table
                # cell.
                #
                $line =~ s/^\s+//g;
            }
            #
            # No multiple whitespace spacer
            #
            else {
                #
                # Check for text before end of line
                #
                ($text, $spacer) = $line =~ /^(.*?)(\s*)$/;
                if ( $text ne "" ) {
                    $pos = $line_length - length($text);
                    print "Non-whitespace character at position $pos\n" if $debug;
                    print "   text = \"$text\"\n" if $debug;
                    push(@$row_addr, $pos);
                }
            }

            #
            # Reset the line to be the text after the cell we just saw.
            #
            $line = $remaining_text;
        }

        #
        # Get the next line from the lines array
        #
        $i++;
        $line = $$lines_addr[$i];
    }

    #
    # Print table details
    #
    if ( ($row_count > 1) ) {
        $last_table_end = $i - 1;
        $table_found = 1;
        if ( $debug) {
            print "Potential space aligned table ending at line " . ($i - 1) . " contains $row_count rows\n";
            for ($j = 1; $j <= $row_count; $j++) {
                $row_addr = $table{$j};
                print "Row # $j Cells " . scalar(@$row_addr) . " positions " . join(",", @$row_addr) . "\n";
            }
        }
    }
    
    #
    # If we found a table return the current lines array index,
    # otherwise return the index that was initially provided.
    #
    if ( $table_found ) {
        $array_index = $i - 1;
    }
    return($array_index, $table_found);
}

#***********************************************************************
#
# Name: Parse_Graphics_Character_Table
#
# Parameters: line - the current line from the content
#             i - index into the array of content lines
#             lines_addr - pointer to array of content lines
#
# Description:
#
#   This function reads the content for a possible graphics character
# formatted table (i.e. using underscore and pipe for cell borders)
#
#***********************************************************************
sub Parse_Graphics_Character_Table {
    my ($line, $i, $lines_addr) = @_;

    my ($pos, $text, $spacer, $remaining_text, %table, $row_addr, $cell_count);
    my ($line_length, $j);
    my ($end_of_table) = 0;
    my ($row_count) = 0;
    my ($table_found) = 0;

    #
    # Get the line after the table start.
    #
    $i++;
    $line = $$lines_addr[$i];

    #
    # Loop until end of the content array or at the end of the table
    #
    print "Possible graphic character table starting at line $i\n" if $debug;
    $row_count = 0;
    while ( defined($line) && ( ! $end_of_table) ) {
        chomp($line);
        $line_length = length($line);

        #
        # If this is a blank line the table is finished.
        #
        if ( $line =~ /^\s*$/ ) {
            $end_of_table = 1;
            $i++;
            last;
        }

        #
        # Is there a pipe symbol followed by multiple underscores? This is either
        # a row seperator or the end of the table. Check for atleast
        # 2 table cells.
        #
        if ( $line =~ /^\s*(\|_{5,})+/ ) {
            print "Row seperator at line $i, text \"$line\"\n" if $debug;
            $i++;
            $line = $$lines_addr[$i];
            undef($row_addr);
            next;
        }

        #
        # If there is no pipe symbol, this is not a table row
        #
        if ( ! ($line =~ /^\s*\|/) ) {
            $end_of_table = 1;
            print "End of table at line $i, text \"$line\"\n" if $debug;
            last;
        }

        #
        # Remove any leading whitespace
        #
        $line =~ s/^\s+//g;

        #
        # Get all occurances of text between pipe characters.
        # Stop when the line only contains whitespace.
        #
        while ( ! ($line =~ /^\s*$/) ) {
            #
            # Get text before next cell marker
            #
            ($text, $remaining_text) = $line =~ /^\|\s+([^\|]*?)\s+(\|.*)$/;
            if ( defined($text) ) {
                #
                # Get the position of the non-whitespace character that
                # follows the whitesace (i.e. get the position in the
                # line after the pattern).
                #
                $pos = $line_length - length($text) - length($spacer) - length($remaining_text);

                #
                # Found what may be a table cell. If we don't have a row yet
                # increment the row count. Save the cell location.
                #
                if ( ! defined($row_addr) ) {
                    my (@row);
                    $row_addr = \@row;
                    $row_count++;
                    $cell_count = 0;
                    $table{$row_count} = $row_addr;
                }
                push(@$row_addr, $pos);
                $cell_count++;
                print "Table cell at line " . ($i - 1) . " column $pos\n" if $debug;
                print "Table row $row_count, cell $cell_count value \"$text\"\n" if $debug;
                print "   text = \"$text\"\n" if $debug;

                #
                # Remove the leading whitespace before the next possible table
                # cell.
                #
                $line =~ s/^\s+//g;
            }

            #
            # Reset the line to be the text after the cell we just saw.
            #
            $line = $remaining_text;
        }

        #
        # Get the next line from the file
        #
        $i++;
        $line = $$lines_addr[$i];
    }

    #
    # Print out table details
    #
    if ( ($row_count > 1) ) {
        $table_found = 1;
        if ( $debug) {
            print "Potential graphic character table ending at line " . ($i - 1) . " contains $row_count rows\n";
            for ($j = 1; $j <= $row_count; $j++) {
                $row_addr = $table{$j};
                print "Row # $j Cells " . scalar(@$row_addr) . " positions " . join(",", @$row_addr) . "\n";
            }
        }
    }

    #
    # Return the index of the last line of the table.
    #
    return(($i - 1), $table_found);
}

#***********************************************************************
#
# Name: Roman_to_Decimal
#
# Parameters: roman_number - a roman number string
#
# Description:
#
#   This function converts a roman number string into decimal
#
#***********************************************************************
sub Roman_to_Decimal {
    my ($roman_number) = @_;

    my ($last, $total, $digit, $val);
    
    #
    # Table of roman letter conversions
    #
    my (%roman_digits) = (
        I => 1,
        V => 5,
        X => 10,
        L => 50,
        C => 100,
        D => 500,
        M => 1000,
    );

    #
    # Initialize the total and last values
    #
    $last  = 0;
    $total = 0;
    
    #
    # Process each roman digit from left to right
    #
    foreach $digit (split('', $roman_number)) {
        #
        # Get the decimal value for this roman digit.
        #
        $val = $roman_digits{uc($digit)};
        print "Roman $digit = $val\n" if $debug;
        
        #
        # If the last digit was the same or greater, add this digit's
        # value to the total (e.g. VI = 5 + 1)
        #
        if ( $val <= $last ) {
            $total += $last;
        } else {
            #
            # This digit is greater than the last so we subtract the
            # last value (e.g. IV = 5 - 1)
            $total -= $last;
        }
        $last = $val;
    }
    
    #
    # Add the final digits value and return the total.
    #
    $total += $last;
    return($total);
}

#***********************************************************************
#
# Name: Sequential_Roman_Numbers
#
# Parameters: first_number - a roman number string
#             second_number - a roman number string
#
# Description:
#
#   This function compare 2 roman numeral strings to see if they are
# sequential. This function only handles roman numbers up to XXXVIII (38).
#
#***********************************************************************
sub Sequential_Roman_Numbers {
    my ($first_number, $second_number) = @_;

    my ($first_decimal, $second_decimal);
    
    #
    # Convert the 2 roman numbers to decimal
    #
    $first_decimal = Roman_to_Decimal($first_number);
    $second_decimal = Roman_to_Decimal($second_number);
    print "Sequential_Roman_Numbers $first_number = $first_decimal, $second_number = $second_decimal\n" if $debug;

    #
    # Is the second number 1 more than the first?
    #
    if ( $second_decimal == ($first_decimal + 1) ) {
        return(1);
    }
    else {
        return(0);
    }
}

#***********************************************************************
#
# Name: Text_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             content - text content pointer
#             content_line - parent content line number
#             content_column - parent content column number
#
# Description:
#
#   This function runs a number of accessibility checks on text content. If
# the content is part of a complex document (e.g. a multi-line cell in a CSV
# file) the content_line and content_column arguments specify the location
# of content part.
#
#***********************************************************************
sub Text_Check {
    my ($this_url, $language, $profile, $content, $content_line,
        $content_column) = @_;

    my (@tqa_results_list, $result_object, @lines);
    my ($single_line, $i, $in_list, $list_item_prefix, $list_item_count);
    my ($item_prefix, $blank_line_count, $in_list_item, $list_item);
    my ($last_list_item, $list_type, $in_paragraph, $last_line);
    my ($expect_heading, $item_label, $last_item_label, $line, $col);
    my ($table_found, $start_table_line, $expected_list_item_prefix);
    my ($last_text_object) = "";

    #
    # Do we have a valid profile ?
    #
    print "Text_Check: Checking URL $this_url, lanugage = $language, profile = $profile\n" if $debug;
    if ( ! defined($text_check_profile_map{$profile}) ) {
        print "Text_Check: Unknown XML testcase profile passed $profile\n";
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
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Did we get any content ?
    #
    if ( length($$content) == 0 ) {
        print "No content passed to Text_Check\n" if $debug;
        return(@tqa_results_list);
    }

    #
    # Split the content into lines
    #
    @lines = split("\n", $$content);
    
    #
    # Make sure there is a blank line at the end of the content so we
    # can detect the last content itel (heading, paragraph, list).
    #
    push(@lines, "");

    #
    # Parse the text lines looking for headings, paragraphs,
    # lists or tables.
    #
    $in_list = 0;
    $in_list_item = 0;
    $list_item_prefix = "";
    $list_item_count = 0;
    $blank_line_count = 0;
    $list_item = "";
    $last_list_item = "";
    $list_type = "";
    $in_paragraph = 0;
    $expect_heading = 0;
    for ($i = 0; $i < @lines; $i++) {
        #
        # Get this line
        #
        $single_line = $lines[$i];
        print "Line # $i \"$single_line\"\n" if $debug;
        print "Blank line count $blank_line_count\n" if $debug;
        print "Last text object $last_text_object\n" if $debug;
        print "In list $in_list\n" if $debug;


        #
        # Are we expecting a heading?
        #
        if ( $expect_heading && !($single_line =~ /^\s*$/) ) {
            #
            # Are we at the end of the content?
            #
            if ( ! defined($lines[($i + 1)]) ) {
                #
                # Heading at end of content
                #
                $expect_heading = 0;
                $blank_line_count = 0;
                $last_text_object = "heading";
                print "Found heading at the end of the content\n" if $debug;
                last;
            }
            #
            # Is the next line a blank line (i.e. end of the heading)?
            #
            elsif ( $lines[($i + 1)] =~ /^[\s\n\r]*$/ ) {
                #
                # Was the last content we saw a heading?
                # Missing content after last heading.
                #
                print "Found heading as next line is blank\n" if $debug;
                if (  $last_text_object eq "heading" ) {
                    if ( defined($content_column) ) {
                        $line = $content_line;
                        $col = $content_column;
                    }
                    else {
                        $line = $i + 1;
                        $col = "";
                    }
                    Record_Result("WCAG_2.0-T3", $line, $col, $single_line,
                                  String_Value("No content found between headings") . " " .
                                  String_Value("at line number") .
                                  " " . ($i + 1));
                }
                
                #
                # Clear heading flag
                #
                $expect_heading = 0;
                $blank_line_count = 0;
                $last_text_object = "heading";

                #
                # Exit the loop
                #
                next;
            }
            #
            # The next line is not blank, we have a multi-line heading?
            #
            else {
                print "Expecting a single line heading, found multiple lines\n" if $debug;
                if ( defined($content_column) ) {
                    $line = $content_line;
                    $col = $content_column;
                }
                else {
                    $line = $i;
                    $col = "";
                }
                Record_Result("WCAG_2.0-T3", $line, $col, $single_line,
                              String_Value("Heading must be a single line") .
                              ", " . String_Value("found") .
                              " \n\"$last_line\n$single_line\"\n" .
                              String_Value("at line number") .
                              " " . ($i + 1));

                #
                # Clear heading flag
                #
                $expect_heading = 0;
                $blank_line_count = 0;
                $last_text_object = "paragraph";

                #
                # Don't restart the loop, check the line for other possible
                # text objects (e.g. lists, tables).
                #
            }
        }
        
        #
        # Is this a blank line?
        #
        if ( $single_line =~ /^\s*$/ ) {
            #
            # Increment blank line count.  Clear in list item and in
            # paragraph flags.
            #
            $blank_line_count++;
            $in_list_item = 0;
            $in_paragraph = 0;

            #
            # If the blank line count is 2, we should expect a heading
            #
            if ( $blank_line_count == 2 ) {
                #
                # Have we seen any text content yet? We don't count
                # blank line at the beginning of the content.
                #
                if ( $last_text_object ne "" ) {
                    $expect_heading = 1;
                    $in_list = 0;
                    $list_type = "";
                    $list_item_count = 0;
                    $item_prefix = "";
                    $expected_list_item_prefix = "";
                    print "Expect a heading after 2 blank lines\n" if $debug;
                }
            }

            #
            # Clear the last line of text
            #
            $last_line = "";
            next;
        }
        #
        # Is this an unordered list item? (i.e. starts with a dash,
        # asterisk or bullet followed by whitespace).
        #
        elsif ( $single_line =~ /^\s*([\-\*])\s+[^\s]+.*$/ ) {
            #
            # Get the list item prefix character
            #
            ($item_prefix) = $single_line =~ /^\s*([\-\*])\s+[^\s]+.*$/io;

            #
            # Found an unordered list item, do we already have a list? and
            # is it ordered?
            #
            print "Found unordered list item\n" if $debug;
            if ( ($list_type ne "") && ($list_type eq "ordered") ) {
                #
                # Lists cannot be nested.
                #
                print "Found an unordered list item in an ordered list\n" if $debug;
                if ( defined($content_column) ) {
                    $line = $content_line;
                    $col = $content_column;
                }
                else {
                    $line = $i;
                    $col = "";
                }
                Record_Result("WCAG_2.0-T2", $line, $col, $single_line,
                              String_Value("Found an unordered list item in an ordered list") .
                              " " . String_Value("at line number") .
                              " " . ($i + 1));

                #
                # Stop any further checks on this content, we don't want
                # multiple errors reported.
                #
                $last_text_object = "list item";
                $blank_line_count = 0;
                next;
            }
            #
            # If we don't have a list type, set it to unordered and save the
            # expected list item prefix character.
            #
            elsif ( $list_type eq "" ) {
                $list_type = "unordered";
                $expected_list_item_prefix = $item_prefix;
            }

            #
            # Do we have a blank line between list items? If the list
            # is the first item in the content, we ignore the blank line
            # checks.
            #
            if ( ($blank_line_count == 0) && ($last_text_object ne "") ) {
                print "No blank line between list items\n" if $debug;
                if ( defined($content_column) ) {
                    $line = $content_line;
                    $col = $content_column;
                }
                else {
                    $line = $i;
                    $col = "";
                }
                Record_Result("WCAG_2.0-T2", $line, $col, $single_line,
                              String_Value("No blank line between list items") .
                              " " . String_Value("at line number") .
                              " " . ($i + 1));
            }
            elsif ( ($blank_line_count == 2) && ($last_text_object ne "") ) {
                #
                # Only check if blank line count is 2.  If it is more than
                # 2, we would report an error for each blank line.
                #
                print "Have $blank_line_count blank lines between list items\n" if $debug;
                if ( defined($content_column) ) {
                    $line = $content_line;
                    $col = $content_column;
                }
                else {
                    $line = $i;
                    $col = "";
                }
                Record_Result("WCAG_2.0-T2", $line, $col, $single_line,
                              String_Value("More than 1 blank line between list items") .
                              " " . String_Value("at line number") .
                              " " . ($i + 1));
            }

            #
            # Check this this list item's prefix matches the expected value
            #
            if ( ($expected_list_item_prefix ne "") && ($item_prefix ne $expected_list_item_prefix) ) {
                print "Inconsistent list item prefix, found $item_prefix, expecting $expected_list_item_prefix\n" if $debug;
                if ( defined($content_column) ) {
                    $line = $content_line;
                    $col = $content_column;
                }
                else {
                    $line = $i;
                    $col = "";
                }
                Record_Result("WCAG_2.0-T2", $line, $col, $single_line,
                              String_Value("Inconsistent list item prefix") . " " .
                              String_Value("found") . " \"$item_prefix\" " .
                              String_Value("expecting") . " \"$expected_list_item_prefix\" " .
                              String_Value("at line number") .
                              " " . ($i + 1));
            }

            #
            # Found a list item.
            #
            $last_text_object = "list item";

            #
            # We are in a list and list item.  Increment list item count and
            # reset blank line count.
            #
            $in_list = 1;
            $list_item_count++;
            $blank_line_count = 0;
            $in_list_item = 1;

            #
            # Set the last item content
            #
            if ( $list_item_count == 1 ) {
                $last_list_item = "";
            }
            else {
                $last_list_item = $list_item;
            }
        }
        #
        # Is this an ordered list item? (i.e. starts with a number,
        # letter or roman numeral).
        #
        # Note: The roman numberal list test is limited to I to XXXIX
        #       (1 to 39 items) to make the pattern easier.
        #
        elsif ( ($single_line =~ /^\s*(\d+[\.\)])\s+[^\s]+.*$/) ||
                ($single_line =~ /^\s*([A-Z][\.\)])\s+[^\s]+.*$/i) ||
                ($single_line =~ /^\s*([ivx]+[\.\)])\s+[^\s]+.*$/i) ) {
            #
            # Get the list item label value
            #
            ($item_label) = $single_line =~ /^\s*([^\.\)]+)[\.\)]\s+.*$/io;

            #
            # Get the list item prefix characters. Try numbered list first
            #
            $item_prefix = "";
            if ( $single_line =~ /^\s*(\d+[\.\)])\s+[^\s]+.*$/ ) {
                $item_prefix = "digits";
            }
            #
            # Try roman numeral list.
            #
            elsif ( $single_line =~ /^\s*([ivx]+[\.\)])\s+[^\s]+.*$/ ) {
                $item_prefix = "roman";
            }
            #
            # Try lettered list.
            #
            elsif ( $single_line =~ /^\s*([A-Z][\.\)])\s+[^\s]+.*$/ ) {
                $item_prefix = "letters";
            }

            #
            # If this is a new list, set the expected item prefix type
            #
            if ( $list_item_count == 0 ) {
                #
                # Check to see if the item prefix is 1 or A or I (i.e. first
                # value in the list prefix type). If it isn't, don't assume
                # this is a list (could be a numbered heading).
                #
                if ( ($item_label == 1) || (uc($item_label) eq "I" ) ||
                     (uc($item_label) eq "A") ) {
                    $expected_list_item_prefix = $item_prefix;
                }
            }

            #
            # Found an ordered list item, do we already have a list? and
            # is it unordered?
            #
            print "Found ordered list item\n" if $debug;
            if ( ($list_type ne "") && ($list_type eq "unordered") ) {
                #
                # Lists cannot be nested.
                #
                print "Found an ordered list item in an unordered list\n" if $debug;
                if ( defined($content_column) ) {
                    $line = $content_line;
                    $col = $content_column;
                }
                else {
                    $line = $i;
                    $col = "";
                }
                Record_Result("WCAG_2.0-T2", $line, $col, $single_line,
                              String_Value("Found an ordered list item in an unordered list") .
                              " " . String_Value("at line number") .
                              " " . ($i + 1));

                #
                # Clear the item label to avoid errors with inconsistent ordering
                #
                $item_label = "";
            }
            elsif ( $list_type eq "" ) {
                $list_type = "ordered";
            }

            #
            # Check this this list item's prefix matches the expected value
            #
            if ( ($expected_list_item_prefix ne "") && ($item_prefix ne $expected_list_item_prefix) ) {
                print "Inconsistent list item prefix, found $item_prefix, expecting $expected_list_item_prefix\n" if $debug;
                if ( defined($content_column) ) {
                    $line = $content_line;
                    $col = $content_column;
                }
                else {
                    $line = $i;
                    $col = "";
                }
                Record_Result("WCAG_2.0-T2", $line, $col, $single_line,
                              String_Value("Inconsistent list item prefix") . " " .
                              String_Value("found") . " \"$item_prefix\" " .
                              String_Value("expecting") . " \"$expected_list_item_prefix\" " .
                              String_Value("at line number") .
                              " " . ($i + 1) . ". " .
                              String_Value("List item value") . " \"$single_line\"");
            }
            #
            # Is this item label greater than the previous label value
            #
            elsif ( $list_item_count > 0 ) {
                #
                # Check numeric list label
                #
                if ( ($item_label ne "") && ($last_item_label ne "") &&
                     ($item_prefix eq "digits") &&
                     ($item_label != ($last_item_label + 1)) ) {
                    print "List item label is not sequential\n" if $debug;
                    if ( defined($content_column) ) {
                        $line = $content_line;
                        $col = $content_column;
                    }
                    else {
                        $line = $i;
                        $col = "";
                    }
                    Record_Result("WCAG_2.0-T2", $line, $col, $single_line,
                                  String_Value("Ordered list items not in sequential order") .  " " .
                                  String_Value("found") . " \"$item_label\" " .
                                  String_Value("after") . " \"$last_item_label\" " .
                                  " " . String_Value("at line number") .
                                  " " . ($i + 1));
                }
                #
                # Check lettered list label
                #
                elsif ( ($item_label ne "") && ($last_item_label ne "") &&
                        ($item_prefix eq "letters") &&
                        (ord(uc($item_label)) != (ord(uc($last_item_label)) + 1)) ) {
                    print "List item label is not sequential\n" if $debug;
                    if ( defined($content_column) ) {
                        $line = $content_line;
                        $col = $content_column;
                    }
                    else {
                        $line = $i;
                        $col = "";
                    }
                    Record_Result("WCAG_2.0-T2", $line, $col, $single_line,
                                  String_Value("Ordered list items not in sequential order") . " " .
                                  String_Value("found") . " \"$item_label\" " .
                                  String_Value("after") . " \"$last_item_label\" " .
                                  " " . String_Value("at line number") .
                                  " " . ($i + 1));
                }
                #
                # Check roman numeral list label.
                # TODO
                #
                elsif ( ($item_label ne "") && ($last_item_label ne "") &&
                        ($item_prefix eq "roman") &&
                        (! Sequential_Roman_Numbers($last_item_label, $item_label)) ) {
                    print "List item label is not sequential\n" if $debug;
                    if ( defined($content_column) ) {
                        $line = $content_line;
                        $col = $content_column;
                    }
                    else {
                        $line = $i;
                        $col = "";
                    }
                    Record_Result("WCAG_2.0-T2", $line, $col, $single_line,
                                  String_Value("Ordered list items not in sequential order") . " " .
                                  String_Value("found") . " \"$item_label\" " .
                                  String_Value("after") . " \"$last_item_label\" " .
                                  " " . String_Value("at line number") .
                                  " " . ($i + 1));
                }
            }

            #
            # Do we have a blank line between list items? If the list
            # is the first item in the content, we ignore the blank line
            # checks.
            #
            if ( ($blank_line_count == 0) && ($last_text_object ne "") ) {
                print "No blank line between list items\n" if $debug;
                if ( defined($content_column) ) {
                    $line = $content_line;
                    $col = $content_column;
                }
                else {
                    $line = $i;
                    $col = "";
                }
                Record_Result("WCAG_2.0-T2", $line, $col, $single_line,
                              String_Value("No blank line between list items") .
                              " " . String_Value("at line number") .
                              " " . ($i + 1) . ". " .
                              String_Value("List item value") . " \"$single_line\"");
            }
            elsif ( ($blank_line_count == 2) && ($last_text_object ne "") ) {
                #
                # Only check if blank line count is 2.  If it is more than
                # 2, we would report an error for each blank line.
                #
                print "Have $blank_line_count blank lines between list items\n" if $debug;
                if ( defined($content_column) ) {
                    $line = $content_line;
                    $col = $content_column;
                }
                else {
                    $line = $i;
                    $col = "";
                }
                Record_Result("WCAG_2.0-T2", $line, $col, $single_line,
                              String_Value("More than 1 blank line between list items") .
                              " " . String_Value("at line number") .
                              " " . ($i + 1) . ". " .
                              String_Value("List item value") . " \"$single_line\"");
            }

            #
            # Found a list item.
            #
            $last_text_object = "list item";

            #
            # We are in a list and list item.  Increment list item count and
            # reset blank line count.
            #
            $in_list = 1;
            $list_item_count++;
            $blank_line_count = 0;
            $in_list_item = 1;
            $expect_heading = 0;
            if ( $item_label ne "" ) {
                $last_item_label = $item_label;
            }

            #
            # Set the last item content
            #
            if ( $list_item_count == 1 ) {
                $last_list_item = "";
            }
            else {
                $last_list_item = $list_item;
            }
        }
        #
        # Are there any graphic characters that may be the leadin to a table?
        # Table header line is composed of underscores. Look for a minimum
        # of 5 underscores together.
        #
        elsif ( $single_line =~ /^\s*_{5,}\s*/ ) {
            #
            # Multiple underscores, see if this is the beginning of
            # a table.
            #
            $start_table_line = $i;
            ($i, $table_found) = Parse_Graphics_Character_Table($single_line, $i, \@lines);

            #
            # Did we find a table?
            #
            if ( $table_found ) {
                if ( defined($content_column) ) {
                    $line = $content_line;
                    $col = $content_column;
                }
                else {
                    $line = $i;
                    $col = "";
                }
                Record_Result("WCAG_2.0-F34", $line, $col, $single_line,
                              String_Value("Graphics character table found") .
                              " " . String_Value("at line number") .
                              " " . ($start_table_line + 1));
                print "Graphics character table found between lines $start_table_line and $i\n" if $debug;

                #
                # Found a table.
                #
                $last_text_object = "table";
            }
        }
        #
        # Are there any multiple whitespace characters between non whitespace
        # characters? This could be the beginning of a table using spacing alignment
        #
        elsif ( $single_line =~ /\S\s\s+\S/ ) {
            #
            # Multiple whitespace gaps, see if this is the beginning of
            # a table.
            #
            $start_table_line = $i;
            ($i, $table_found) = Parse_Space_Aligned_Table($single_line, $i, \@lines);

            #
            # Did we find a table?
            #
            if ( $table_found ) {
                if ( defined($content_column) ) {
                    $line = $content_line;
                    $col = $content_column;
                }
                else {
                    $line = $i;
                    $col = "";
                }
                Record_Result("WCAG_2.0-F34", $line, $col, $single_line,,
                              String_Value("Whitespace aligned table found") .
                              " " . String_Value("at line number") .
                              " " . ($start_table_line + 1));
                print "Space aligned table found between lines $start_table_line and $i\n" if $debug;

                #
                # Found a table.
                #
                $last_text_object = "table";
            }
            else {
                #
                # Not a table, assume it is a paragraph.
                # Save this line of text and clean the blank line count
                #
                $in_paragraph = 1;
                $last_text_object = "paragraph";
                $last_line = $single_line;
                $blank_line_count = 0;
                print "Found paragraph\n" if $debug;
            }
        }
        #
        # If we are in a list, we don't expect a non-list item paragraph
        #
        elsif ( $in_list_item ) {
            print "Found list item text\n" if $debug;
            $list_item .= "\n$single_line";
            next;
        }
        #
        # A text line.
        #
        else {
            #
            # Are we inside of a list ?
            #
            if ( $in_list ) {
                #
                # Not in a list item, but in a list.  The list has ended,
                # this text may be the beginning of a paragraph.
                #
                $in_list = 0;
                $list_type = "";
                $last_item_label = "";
                $expected_list_item_prefix = "";
                print "End of list encountered\n" if $debug;
            }

            #
            # Save this line of text and clean the blank line count
            #
            $in_paragraph = 1;
            $last_text_object = "paragraph";
            $last_line = $single_line;
            $blank_line_count = 0;
            print "Found paragraph\n" if $debug;
        }
    }
    
    #
    # Finished the content, was the last item found a heading?
    #
    if ( $last_text_object eq "heading" ) {
        #
        # A heading cannot be the last object, it must be a paragraph, list
        # or table.
        #
        print "Heading found at end of content\n" if $debug;
        if ( defined($content_column) ) {
            $line = $content_line;
            $col = $content_column;
        }
        else {
            $line = $i;
            $col = "";
        }
        Record_Result("WCAG_2.0-T3", $line, $col, $single_line,
                      String_Value("Heading with no following content") . " " .
                      String_Value("at line number") .
                      " " . ($i + 1));
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "Text_Check results\n";
        foreach $result_object (@tqa_results_list) {
            print "Testcase: " . $result_object->testcase;
            print "  status   = " . $result_object->status . "\n";
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
# Mainline
#
#***********************************************************************

#
# Return true to indicate we loaded successfully
#
return 1;

