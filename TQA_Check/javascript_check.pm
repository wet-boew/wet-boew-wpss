#***********************************************************************
#
# Name:   javascript_check.pm
#
# $Revision: 6782 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/TQA_Check/Tools/javascript_check.pm $
# $Date: 2014-10-02 09:51:19 -0400 (Thu, 02 Oct 2014) $
#
# Description:
#
#   This file contains routines that parse JavaScript files and check for
# a number of technical quality assurance check points.
#
# Public functions:
#     Set_JavaScript_Check_Language
#     Set_JavaScript_Check_Debug
#     Set_JavaScript_Check_Testcase_Data
#     Set_JavaScript_Check_Test_Profile
#     Set_JavaScript_Check_Valid_Markup
#     JavaScript_Check
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

package javascript_check;

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
    @EXPORT  = qw(Set_JavaScript_Check_Language
                  Set_JavaScript_Check_Debug
                  Set_JavaScript_Check_Testcase_Data
                  Set_JavaScript_Check_Test_Profile
                  Set_JavaScript_Check_Valid_Markup
                  JavaScript_Check
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (%testcase_data, @content_lines);
my ($results_list_addr);
my (@paths, $this_path, $program_dir, $program_name, $paths);

my (%javascript_check_profile_map, $current_javascript_check_profile,
    $current_url);

my ($is_valid_markup) = -1;

my ($max_error_message_string)= 2048;

#
# Status values
#
my ($javascript_check_pass)       = 0;
my ($javascript_check_fail)       = 1;

#
# List of content creation functions that should not be used
#
my (@illegal_document_creation_functions) = (
#    "document.write", # Used in piwik web analytics
    "innerHTML",
    "outerHTML",
    "innerText",
    "outerText");

#
# String table for error strings.
#
my %string_table_en = (
    "Fails validation",              "Fails validation, see validation results for details.",
    "Required testcase not executed","Required testcase not executed",
    "Invalid DOM function called",   "Invalid DOM function called ",
    );

my %string_table_fr = (
    "Fails validation",              "Échoue la validation, voir les résultats de validation pour plus de détails.",
    "Required testcase not executed","Cas de test requis pas exécuté",
    "Invalid DOM function called",   "Appel d'une fonction DOM invalide ",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_JavaScript_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_JavaScript_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_JavaScript_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_JavaScript_Check_Language {
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
# Name: Set_JavaScript_Check_Testcase_Data
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
sub Set_JavaScript_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_JavaScript_Check_Test_Profile
#
# Parameters: profile - JavaScript check test profile
#             javascript_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by JavaScript testcase name.
#
#***********************************************************************
sub Set_JavaScript_Check_Test_Profile {
    my ($profile, $javascript_checks ) = @_;

    my (%local_javascript_checks);
    my ($key, $value);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_JavaScript_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_javascript_checks = %$javascript_checks;
    $javascript_check_profile_map{$profile} = \%local_javascript_checks;
}

#***********************************************************************
#
# Name: Set_JavaScript_Check_Valid_Markup
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
sub Set_JavaScript_Check_Valid_Markup {
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
    print "Set_JavaScript_Check_Valid_Markup, validity = $is_valid_markup\n" if $debug;
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - JavaScript check test profile
#             local_results_list_addr - address of results list.
#
# Description:
#
#   This function initializes the test case results table.
#
#***********************************************************************
sub Initialize_Test_Results {
    my ($profile, $local_results_list_addr) = @_;

    my ($test_case, $tcid);

    #
    # Set current hash tables
    #
    $current_javascript_check_profile = $javascript_check_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;

#
#***********************************************************************
#
# Do not report validation failures of supporting files (CSS, JavaScript)
# as WCAG 2.0 failures.  Failures apply only to the validity of the
# HTML markup.
#
#***********************************************************************
#
#    #
#    # Check to see if we were told that this document is not
#    # valid JavaScript
#    #
#    if ( $is_valid_markup == 0 ) {
#        Record_Result("WCAG_2.0-G134", -1, 0, "",
#                      String_Value("Fails validation"));
#    }

    #
    # Initialize other global variables
    #
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
        print "$line:$column $error_string\n";
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
    if ( defined($testcase) && defined($$current_javascript_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $javascript_check_fail, 
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
# Name: Check_Illegal_Function_Calls
#
# Parameters: line_no - line number
#             line - content line
#
# Description:
#
#   This function checks the content line for any illegal content
# creation functions.
#
#***********************************************************************
sub Check_Illegal_Function_Calls {
    my ($line_no, $line) = @_;

    my ($function, $tcid);
    
    #
    # Check illegal content functions
    #
    foreach $function (@illegal_document_creation_functions) {
        if ( $line =~ /$function\s*=/i ) {
            #
            # Check testcase profile
            #
            if ( defined($$current_javascript_check_profile{"WCAG_2.0-SCR21"}) ) {
                $tcid = "WCAG_2.0-SCR21";

                #
                # Use of improper DOM update function
                #
                Record_Result($tcid, $line_no, -1, "",
                              String_Value("Invalid DOM function called") .
                              "\"$function\"");
            }
        }
    }
}

#***********************************************************************
#
# Name: Parse_JavaScript_Content
#
# Parameters: content_ptr - JavaScript content pointer
#
# Description:
#
#   This function parses the JavaScript content and checks for errors.
#
#***********************************************************************
sub Parse_JavaScript_Content {
    my ($content_ptr) = @_;

    my ($line_no, $line, $content);

    #
    # Remove any comments from the JavaScript content
    #
    $content = $$content_ptr;
    $content =~ s/\s+i\/\/.*$//gs;

    #
    # Split content on new-line
    #
    @content_lines = split(/\n/, $content);

    #
    # Scan each source line
    #
    $line_no = 0;
    foreach $line (@content_lines) {
        $line_no++;

        #
        # Check for functions used to update the DOM
        #
        Check_Illegal_Function_Calls($line_no, $line);
    }
}

#***********************************************************************
#
# Name: JavaScript_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             content - JavaScript content pointer
#
# Description:
#
#   This function runs a number of technical QA checks JavaScript content.
#
#***********************************************************************
sub JavaScript_Check {
    my ($this_url, $language, $profile, $content) = @_;

    my (@urls, $url);
    my (@tqa_results_list, $result_object, $testcase);

    #
    # Do we have a valid profile ?
    #
    print "JavaScript_Check: Checking URL $this_url, lanugage = $language, profile = $profile\n" if $debug;
    if ( ! defined($javascript_check_profile_map{$profile}) ) {
        print "JavaScript_Check: Unknown JavaScript testcase profile passed $profile\n";
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
        # Doesn't look like a URL.  Could be just a block of JavaScript
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
        # Parse the content and check for errors
        #
        Parse_JavaScript_Content($content);
    }
    else {
        print "No content passed to JavaScript_Check\n" if $debug;
        return(@tqa_results_list);
    }

    #
    # Reset valid markup flag to unknown before we are called again
    #
    $is_valid_markup = -1;

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "JavaScript_Check results\n";
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
    my (@package_list) = ("image_details", "css_extract_links",
                          "tqa_result_object", "tqa_testcases");

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

