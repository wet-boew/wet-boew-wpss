#***********************************************************************
#
# Name:   marc_check.pm
#
# $Revision: 893 $
# $URL: svn://10.36.148.185/TQA_Check/Tools/marc_check.pm $
# $Date: 2018-07-09 11:05:32 -0400 (Mon, 09 Jul 2018) $
#
# Description:
#
#   This file contains routines that parse MARC files and check for
# a number of acceessibility (WCAG) check points.
#
# Public functions:
#     Set_MARC_Check_Language
#     Set_MARC_Check_Debug
#     Set_MARC_Check_Valid_Markup
#     Set_MARC_Check_Testcase_Data
#     Set_MARC_Check_Test_Profile
#     MARC_Check
#
# Terms and Conditions of Use
#
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is
# distributed under the MIT License.
#
# MIT License
#
# Copyright (c) 2018 Government of Canada
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

package marc_check;

use strict;
use URI::URL;
use File::Basename;

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
    @EXPORT  = qw(Set_MARC_Check_Language
                  Set_MARC_Check_Debug
                  Set_MARC_Check_Valid_Markup
                  Set_MARC_Check_Testcase_Data
                  Set_MARC_Check_Test_Profile
                  MARC_Check
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
my (%marc_check_profile_map, $current_marc_check_profile, $current_url);

my ($is_valid_markup) = -1;
my ($max_error_message_string)= 2048;

#
# Status values
#
my ($marc_check_pass)       = 0;
my ($marc_check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Fails validation",           "Fails validation, see validation results for details.",
    );

my %string_table_fr = (
    "Fails validation",           "Échoue la validation, voir les résultats de validation pour plus de détails.",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_MARC_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_MARC_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_MARC_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_MARC_Check_Language {
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

#***********************************************************************
#
# Name: Set_MARC_Check_Valid_Markup
#
# Parameters: valid_marc - flag
#
# Description:
#
#   This function copies the passed flag into the global
# variable is_valid_xtml.  The possible values are
#    1 - valid MARC
#    0 - not valid MARC
#   -1 - unknown validity.
# This value is used when assessing WCAG 2.0-G134
#
#***********************************************************************
sub Set_MARC_Check_Valid_Markup {
    my ($valid_marc) = @_;

    #
    # Copy the data into global variable
    #
    if ( defined($valid_marc) ) {
        $is_valid_markup = $valid_marc;
    }
    else {
        $is_valid_markup = -1;
    }
    print "Set_MARC_Check_Valid_Markup, validity = $is_valid_markup\n" if $debug;
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
# Name: Set_MARC_Check_Testcase_Data
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
sub Set_MARC_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_MARC_Check_Test_Profile
#
# Parameters: profile - XML check test profile
#             marc_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by XML testcase name.
#
#***********************************************************************
sub Set_MARC_Check_Test_Profile {
    my ($profile, $marc_checks) = @_;

    my (%local_marc_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_MARC_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_marc_checks = %$marc_checks;
    $marc_check_profile_map{$profile} = \%local_marc_checks;
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
    $current_marc_check_profile = $marc_check_profile_map{$profile};
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

    my ($result_object);

    #
    # Is this testcase included in the profile
    #
    if ( defined($testcase) && defined($$current_marc_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $marc_check_fail,
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
# Name: MARC_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             content - MARC content pointer
#
# Description:
#
#   This function runs a number of technical QA checks on MARC content.
#
#***********************************************************************
sub MARC_Check {
    my ($this_url, $language, $profile, $content) = @_;

    my (@tqa_results_list, $result_object);

    #
    # Do we have a valid profile ?
    #
    print "MARC_Check: Checking URL $this_url, lanugage = $language, profile = $profile\n" if $debug;
    if ( ! defined($marc_check_profile_map{$profile}) ) {
        print "MARC_Check: Unknown MARC testcase profile passed $profile\n";
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
        # Doesn't look like a URL.  Could be just a block of MARC
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Check to see if we were told that this document is not
    # valid MARC
    #
    if ( $is_valid_markup == 0 ) {
        Record_Result("WCAG_2.0-G134", -1, 0, "",
                      String_Value("Fails validation"));
    }

    #
    # Did we get any content ?
    #
    if ( length($$content) == 0 ) {
        print "No content passed to MARC_Check\n" if $debug;
        return(@tqa_results_list);
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "MARC_Check results\n";
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

