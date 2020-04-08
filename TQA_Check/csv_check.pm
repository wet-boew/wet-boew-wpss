#***********************************************************************
#
# Name:   csv_check.pm
#
# $Revision: 7636 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/TQA_Check/Tools/csv_check.pm $
# $Date: 2016-07-22 06:54:19 -0400 (Fri, 22 Jul 2016) $
#
# Description:
#
#   This file contains routines that parse CSV files and check for
# a number of acceessibility (WCAG) check points.
#
# Public functions:
#     Set_CSV_Check_Language
#     Set_CSV_Check_Debug
#     Set_CSV_Check_Testcase_Data
#     Set_CSV_Check_Test_Profile
#     Set_CSV_Check_Valid_Markup
#     CSV_Check
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

package csv_check;

use strict;
use URI::URL;
use File::Basename;
use Text::CSV;
use File::Temp qw/ tempfile tempdir /;

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
    @EXPORT  = qw(Set_CSV_Check_Language
                  Set_CSV_Check_Debug
                  Set_CSV_Check_Testcase_Data
                  Set_CSV_Check_Test_Profile
                  Set_CSV_Check_Valid_Markup
                  CSV_Check
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
my (%csv_check_profile_map, $current_csv_check_profile, $current_url);

my ($is_valid_markup) = -1;
my ($max_error_message_string)= 2048;

#
# Status values
#
my ($csv_check_pass)       = 0;
my ($csv_check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Parse error in line",           "Parse error in line",
    "Inconsistent number of fields, found", "Inconsistent number of fields, found ",
    "expecting",                      "expecting",
    );

my %string_table_fr = (
    "Parse error in line",           "Parse error en ligne",
    "Inconsistent number of fields, found", "Numéro incohérente des champs, a constaté ",
    "expecting",                      "expectant",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_CSV_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_CSV_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_CSV_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_CSV_Check_Language {
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
# Name: Set_CSV_Check_Testcase_Data
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
sub Set_CSV_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_CSV_Check_Test_Profile
#
# Parameters: profile - CSV check test profile
#             csv_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by CSV testcase name.
#
#***********************************************************************
sub Set_CSV_Check_Test_Profile {
    my ($profile, $csv_checks) = @_;

    my (%local_csv_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_CSV_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_csv_checks = %$csv_checks;
    $csv_check_profile_map{$profile} = \%local_csv_checks;
}

#***********************************************************************
#
# Name: Set_CSV_Check_Valid_Markup
#
# Parameters: valid_markup - flag
#
# Description:
#
#   This function copies the passed flag into the global
# variable is_valid_markup.  The possible values are
#    1 - valid markup
#    0 - not valid markup
#   -1 - unknown validity.
# This value is used when assessing WCAG technique G134
#
#***********************************************************************
sub Set_CSV_Check_Valid_Markup {
    my ($valid_markup) = @_;

    #
    # Copy the data into global variable
    #
    if ( defined($valid_markup) ) {
        $is_valid_markup = $valid_markup;
    }
    else {
        $is_valid_markup = -1;
    }
    print "Set_CSV_Check_Valid_Markup, validity = $is_valid_markup\n" if $debug;
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
    $current_csv_check_profile = $csv_check_profile_map{$profile};
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
    # Is this testcase included in the profile
    #
    if ( defined($testcase) && defined($$current_csv_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $csv_check_fail,
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
# Name: CSV_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             content - CSV content pointer
#
# Description:
#
#   This function runs a number of accessibility checks on CSV content.
#
#***********************************************************************
sub CSV_Check {
    my ($this_url, $language, $profile, $content) = @_;

    my ($parser, $url, @tqa_results_list, $result_object, $testcase);
    my ($line, @fields, $line_no, $status, $found_fields, $field_count);
    my ($csv_file, $csv_file_name, $rows);

    #
    # Do we have a valid profile ?
    #
    print "CSV_Check: Checking URL $this_url, lanugage = $language, profile = $profile\n" if $debug;
    if ( ! defined($csv_check_profile_map{$profile}) ) {
        print "CSV_Check: Unknown CSV testcase profile passed $profile\n";
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
        # Doesn't look like a URL.  Could be just a block of CSV
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
        print "No content passed to CSV_Check\n" if $debug;
        return(@tqa_results_list);
    }
    else {
        #
        # Create a temporary file for the CSV content.
        #
        print "Create temporary CSV file\n" if $debug;
        ($csv_file, $csv_file_name) = tempfile("WPSS_TOOL_TCSV_XXXXXXXXXX",
                                               SUFFIX => '.csv',
                                               TMPDIR => 1);
        if ( ! defined($csv_file) ) {
            print "Error: Failed to create temporary file in CSV_Check\n";
            return(@tqa_results_list);
        }
        binmode $csv_file;
        print $csv_file $$content;
        close($csv_file);

        #
        # Open the temporary file for reading.
        #
        open($csv_file, "$csv_file_name") ||
            die "CSV_Check: Failed to open $csv_file_name for reading\n";

        #
        # Create a document parser
        #
        $parser = Text::CSV->new ({ binary => 1, eol => $/ });

        #
        # Parse each line/record of the content
        #
        $line_no = 1;
        while ( $rows = $parser->getline($csv_file) ) {
            #
            # Increment record/line number
            #
            $line_no++;
        }

        #
        # Did we get to the end of file or did we encounter a parsing error
        #
        if ( ! $parser->eof() ) {
            $line = $parser->error_input();
            #$message = $parser->error_diag();
            print "CSV file error at line $line_no, line = \"$line\"\n" if $debug;
            Record_Result("WCAG_2.0-G134", $line_no, 0, $line,
                          String_Value("Parse error in line"));
        }
        close($csv_file);
        unlink($csv_file_name);
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "CSV_Check results\n";
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

