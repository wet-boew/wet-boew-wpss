#***********************************************************************
#
# Name:   open_data_json.pm
#
# $Revision: 7174 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Open_Data/Tools/open_data_json.pm $
# $Date: 2015-06-05 10:51:57 -0400 (Fri, 05 Jun 2015) $
#
# Description:
#
#   This file contains routines that parse JSON APIs and data files to
# check for a number of open data check points.
#
# Public functions:
#     Set_Open_Data_JSON_Language
#     Set_Open_Data_JSON_Debug
#     Set_Open_Data_JSON_Testcase_Data
#     Set_Open_Data_JSON_Test_Profile
#     Open_Data_JSON_Check_API
#     Open_Data_JSON_Check_Data
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

package open_data_json;

use strict;
use URI::URL;
use File::Basename;
use JSON;

#
# Use WPSS_Tool program modules
#
use crawler;
use open_data_testcases;
use tqa_result_object;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Set_Open_Data_JSON_Language
                  Set_Open_Data_JSON_Debug
                  Set_Open_Data_JSON_Testcase_Data
                  Set_Open_Data_JSON_Test_Profile
                  Open_Data_JSON_Check_API
                  Open_Data_JSON_Check_Data
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (@paths, $this_path, $program_dir, $program_name, $paths);
my (%testcase_data, $results_list_addr);
my (%open_data_profile_map, $current_open_data_profile, $current_url);
my ($tag_count, $python_path, $json_schema_validator);

my ($max_error_message_string)= 2048;
my ($runtime_error_reported) = 0;

#
# Status values
#
my ($check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Broken link in Schema",       "Broken link in \"\$Schema\":",
    "Fails validation",            "Fails validation",
    "Invalid URL in Schema",       "Invalid URL in \"\$Schema\":",
    "No content in API",           "No content in API",
    "json_schema_validator failed", "json_schema_validator failed",
    "No content in file",          "No content in file",
    "No Schema found in JSON file", "No Schema found in JSON file",
    "Runtime Error",               "Runtime Error",
    );

my %string_table_fr = (
    "Broken link in Schema",       "Lien brisé dans \"\$Schema\":",
    "Fails validation",            "Échoue la validation",
    "Invalid URL in Schema",       "URL non valide dans \"\$Schema\":",
    "json_schema_validator failed", "json_schema_validator a échoué",
    "No content in API",           "Aucun contenu dans API",
    "No content in file",          "Aucun contenu dans fichier",
    "No Schema found in JSON file", "Non schéma trouvé dans le fichier JSON",
    "Runtime Error",               "Erreur D'Exécution",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_Open_Data_JSON_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Open_Data_JSON_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_Open_Data_JSON_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Open_Data_JSON_Language {
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
# Name: Set_Open_Data_JSON_Testcase_Data
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
sub Set_Open_Data_JSON_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_Open_Data_JSON_Test_Profile
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
sub Set_Open_Data_JSON_Test_Profile {
    my ($profile, $testcase_names) = @_;

    my (%local_testcase_names);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Open_Data_JSON_Test_Profile, profile = $profile\n" if $debug;
    %local_testcase_names = %$testcase_names;
    $open_data_profile_map{$profile} = \%local_testcase_names;
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - open data check test profile
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
# Name: Open_Data_JSON_Check_API
#
# Parameters: this_url - a URL
#             profile - testcase profile
#             filename - JSON content filename
#
# Description:
#
#   This function runs a number of open data checks on JSON API content.
#
#***********************************************************************
sub Open_Data_JSON_Check_API {
    my ( $this_url, $profile, $filename) = @_;

    my (@tqa_results_list, $result_object, $testcase, $eval_output, $ref);
    my ($content, $line);

    #
    # Do we have a valid profile ?
    #
    print "Open_Data_JSON_Check_API: Checking URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($open_data_profile_map{$profile}) ) {
        print "Open_Data_JSON_Check_API: Unknown testcase profile passed $profile\n";
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
        # Doesn't look like a URL.  Could be just a block of JSON
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Open the API content file
    #
    open(FH, "$filename") ||
        die "Open_Data_JSON_Check_API: Failed to open $filename for reading\n";
    binmode FH;

    #
    # Read the content
    #
    $content = "";
    while ( $line = <FH> ) {
        $content .= $line;
    }
    close(FH);
    
    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Did we get any content ?
    #
    if ( length($content) == 0 ) {
        print "No content passed to Open_Data_JSON_Check_API\n" if $debug;
        Record_Result("OD_VAL", -1, 0, "",
                      String_Value("No content in API"));
    }
    else {
        #
        # Parse the content.
        #
        if ( ! eval { $ref = decode_json($content); 1 } ) {
            $eval_output = $@;
            $eval_output =~ s/ at \S* line \d*\.$//g;
            Record_Result("OD_VAL", -1, 0, "",
                          String_Value("Fails validation") . " $eval_output");
        }
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "Open_Data_JSON_Check_API results\n";
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
# Name: Valid_JSON_Against_Schema
#
# Parameters: this_url - a URL
#             json_filename - JSON content file
#             schema_url - URL of JSON schema
#
# Description:
#
#   This function retrieves the JSON schema using the specified URL.
# It them validates the JSON data file against the schema.
#
#***********************************************************************
sub Valid_JSON_Against_Schema {
    my ($this_url, $json_filename, $schema_url) = @_;

    my ($resp_url, $resp, $schema_filename, $output);
    
    #
    # Get the JSON schema file
    #
    print "Valid_JSON_Against_Schema schema URL = $schema_url\n" if $debug;
    ($resp_url, $resp) = Crawler_Get_HTTP_Response($schema_url, "");

    #
    # Is this a valid URI ?
    #
    if ( ! defined($resp) ) {
        Record_Result("OD_VAL", "", "", "",
                      String_Value("Invalid URL in Schema") .
                      " \"$schema_url\"");
    }
    #
    # Is it a broken link ?
    #
    elsif ( ! $resp->is_success ) {
        Record_Result("OD_VAL", "", "", "",
                      String_Value("Broken link in Schema") .
                      " \"$schema_url\"");
    }
    else {
        #
        # Get the schema file name from the HTTP::Response object
        #
        if ( defined($resp->header("WPSS-Content-File")) ) {
            $schema_filename = $resp->header("WPSS-Content-File");
            print "JSON Schema file name = $schema_filename\n" if $debug;
        }
    }
    
    #
    # If we have a schema file, validate the JSON data against the schema
    #
    if ( defined($schema_filename) ) {
        #
        # Run the schema validator
        #
        print "$json_schema_validator \"$schema_filename\" \"$json_filename\"\n" if $debug;
        $output = `$json_schema_validator \"$schema_filename\" \"$json_filename\" 2>\&1`;
        
        #
        # Did the validator pass ?
        #
        if ( $output =~ /Validation Passed/i ) {
            print "Validation passed\n" if $debug;
        }
        elsif ( $output =~ /Schema Error/i ) {
            print "Schema Error\n" if $debug;
            Record_Result("OD_VAL", -1, -1, "",
                          String_Value("json_schema_validator failed") .
                          " \"$output\"");
        }
        elsif ( $output =~ /Validation Error/i ) {
            print "Validation Error\n" if $debug;
            Record_Result("OD_VAL", -1, -1, "",
                          String_Value("json_schema_validator failed") .
                          " \"$output\"");
        }
        else {
            #
            # Runtime error with JSON schema validator
            #
            print "Runtime error, output = \"$output\"\n" if $debug;
            print STDERR "json_schema_validator command failed\n";
            print STDERR "  $json_schema_validator $schema_filename $json_filename\n";
            print STDERR "$output\n";

            #
            # Report runtime error only once
            #
            if ( ! $runtime_error_reported ) {
                Record_Result("OD_VAL", -1, -1, "",
                              String_Value("Runtime Error") .
                              " \"$json_schema_validator $schema_filename $json_filename\"\n" .
                              " \"$output\"");
                $runtime_error_reported = 1;
            }
        }
        
        #
        # Clean up the schema file
        #
        unlink($schema_filename);
    }
}

#***********************************************************************
#
# Name: Open_Data_JSON_Check_Data
#
# Parameters: this_url - a URL
#             profile - testcase profile
#             filename - JSON content file
#             dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function runs a number of open data checks on JSON data file content.
#
#***********************************************************************
sub Open_Data_JSON_Check_Data {
    my ($this_url, $profile, $filename, $dictionary) = @_;
    
    my (@tqa_results_list, $result_object, $testcase, $eval_output, $ref);
    my ($content, $line, $json_file, $schema_url);

    #
    # Do we have a valid profile ?
    #
    print "Open_Data_JSON_Check_Data Checking URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($open_data_profile_map{$profile}) ) {
        print "Open_Data_JSON_Check_Data Unknown testcase profile passed $profile\n";
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
        # Doesn't look like a URL.  Could be just a block of JSON
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Open the JSON file for reading.
    #
    print "Open JSON file $filename\n" if $debug;
    open(FH, "$filename") ||
        die "Open_Data_JSON_Check_Data Failed to open $filename for reading\n";
    binmode FH;

    #
    # Read the content
    #
    $content = "";
    while ( $line = <FH> ) {
        $content .= $line;
    }
    close(FH);

    #
    # Did we get any content ?
    #
    if ( length($content) == 0 ) {
        print "No content passed to Open_Data_JSON_Check_Data\n" if $debug;
        Record_Result("OD_VAL", -1, 0, "", String_Value("No content in file"));
    }
    else {
        #
        # Parse the content.
        #
        print " Content length = " . length($content) . "\n" if $debug;
        if ( ! eval { $ref = decode_json($content); 1 } ) {
            $eval_output = $@;
            $eval_output =~ s/ at \S* line \d*\.$//g;
            Record_Result("OD_VAL", -1, 0, "",
                          String_Value("Fails validation") . " $eval_output");
        }
        else {
            #
            # Check for a $schema name/value object in the JSON data
            #
            if ( (! defined($ref)) ||
                 (! defined($$ref{'$schema'})) ||
                 ($$ref{'$schema'} eq "") ) {
                #
                # No schema specified
                #
                Record_Result("OD_VAL", -1, 0, "",
                      String_Value("No Schema found in JSON file"));
            }
            else {
                #
                # Validate JSON against the schema
                #
                $schema_url = $$ref{'$schema'};
                Valid_JSON_Against_Schema($this_url, $filename, $schema_url);
            }
        }
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "Open_Data_JSON_Check_Data results\n";
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
# Generate path the the JSON schema validator
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $python_path = "$program_dir\\python\\Program Files\\python27\\Lib\\site-packages";
    $json_schema_validator = "set PYTHONPATH=$python_path\&.\\bin\\json_schema_validator.py";
} else {
    #
    # Not Windows.
    #
    $python_path = "$program_dir/python/usr/local/lib/python2.7/dist-packages";
    $json_schema_validator = "export PYTHONPATH=\"$python_path\";python bin/json_schema_validator.py";
}

#
# Return true to indicate we loaded successfully
#
return 1;

