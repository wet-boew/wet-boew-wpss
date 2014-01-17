#***********************************************************************
#
# Name:   open_data_check.pm
#
# $Revision: 6496 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Open_Data/Tools/open_data_check.pm $
# $Date: 2013-12-03 12:50:58 -0500 (Tue, 03 Dec 2013) $
#
# Description:
#
#   This file contains routines that check for a number of 
# open data check points.
#
# Public functions:
#     Set_Open_Data_Check_Language
#     Set_Open_Data_Check_Debug
#     Set_Open_Data_Check_Testcase_Data
#     Set_Open_Data_Check_Test_Profile
#     Open_Data_Check_Testcase_URL
#     Open_Data_Check_Read_URL_Help_File
#     Open_Data_Check
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

package open_data_check;

use strict;
use Encode;
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
    @EXPORT  = qw(Set_Open_Data_Check_Language
                  Set_Open_Data_Check_Debug
                  Set_Open_Data_Check_Testcase_Data
                  Set_Open_Data_Check_Test_Profile
                  Open_Data_Check_Testcase_URL
                  Open_Data_Check_Read_URL_Help_File
                  Open_Data_Check
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (%testcase_data, %open_data_profile_map);
my (@paths, $this_path, $program_dir, $program_name, $paths);

my ($current_open_data_profile, $current_url, $results_list_addr);
my ($current_open_data_profile_name);

my ($max_error_message_string) = 2048;

#
# Status values
#
my ($check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Character encoding is not UTF-8", "Character encoding is not UTF-8",
    "Invalid mime-type for data dictionary", "Invalid mime-type for data dictionary",
    "Invalid mime-type for data file", "Invalid mime-type for data file",
    "Invalid mime-type for API",       "Invalid mime-type for API",
    "Dataset URL unavailable",         "Dataset URL unavailable",
    "API URL unavailable",             "API URL unavailable",
);

#
# String table for error strings (French).
#
my %string_table_fr = (
    "Character encoding is not UTF-8", "L'encodage des caractères ne pas UTF-8",
    "Invalid mime-type for data dictionary", "Invalid type MIME pour le dictionnaire de donnée",
    "Invalid mime-type for data file", "Invalid type MIME pour le jeu de donnée",
    "Invalid mime-type for API",       "Invalid type MIME pour API",
    "Dataset URL unavailable",         "URL du jeu de données disponible",
    "API URL unavailable",             "URL du API disponible",
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#**********************************************************************
#
# Name: Set_Open_Data_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Open_Data_Check_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_Open_Data_Check_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_Open_Data_Check_Language, language = English\n" if $debug;
        $string_table = \%string_table_en;
    }

    #
    # Set language in supporting modules
    #
    Set_Open_Data_CSV_Language($language);
    Set_Open_Data_JSON_Language($language);
    Set_Open_Data_TXT_Language($language);
    Set_Open_Data_XML_Language($language);
}

#***********************************************************************
#
# Name: Set_Open_Data_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Open_Data_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;

    #
    # Set debug flag in supporting modules
    #
    Set_Open_Data_CSV_Debug($debug);
    Set_Open_Data_JSON_Debug($debug);
    Set_Open_Data_TXT_Debug($debug);
    Set_Open_Data_XML_Debug($debug);
    Set_Open_Data_Testcase_Debug($debug);
}

#**********************************************************************
#
# Name: Open_Data_Check_Testcase_URL
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase URL
# table for the specified key.
#
#**********************************************************************
sub Open_Data_Check_Testcase_URL {
    my ($key) = @_;

    return(Open_Data_Testcase_URL($key));
}

#**********************************************************************
#
# Name: Open_Data_Check_Read_URL_Help_File
#
# Parameters: filename - path to help file
#
# Description:
#
#   This function reads a testcase help file.  The file contains
# a list of testcases and the URL of a help page or standard that
# relates to the testcase.  A language field allows for English & French
# URLs for the testcase.
#
#**********************************************************************
sub Open_Data_Check_Read_URL_Help_File {
    my ($filename) = @_;

    #
    # Read in Open Data checks URL help
    #
    Open_Data_Testcase_Read_URL_Help_File($filename);
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
# Name: Set_Open_Data_Check_Testcase_Data
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
sub Set_Open_Data_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Set testcase data in supporting modules
    #
    Set_Open_Data_CSV_Testcase_Data($testcase, $data);
    Set_Open_Data_JSON_Testcase_Data($testcase, $data);
    Set_Open_Data_TXT_Testcase_Data($testcase, $data);
    Set_Open_Data_XML_Testcase_Data($testcase, $data);
}

#***********************************************************************
#
# Name: Set_Open_Data_Check_Test_Profile
#
# Parameters: profile - check test profile
#             open_data_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by testcase name.
#
#***********************************************************************
sub Set_Open_Data_Check_Test_Profile {
    my ($profile, $open_data_checks ) = @_;

    my (%local_open_data_checks);
    my ($key, $value);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Open_Data_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_open_data_checks = %$open_data_checks;
    $open_data_profile_map{$profile} = \%local_open_data_checks;

    #
    # Set testcase profile in supporting modules
    #
    Set_Open_Data_CSV_Test_Profile($profile, $open_data_checks);
    Set_Open_Data_JSON_Test_Profile($profile, $open_data_checks);
    Set_Open_Data_TXT_Test_Profile($profile, $open_data_checks);
    Set_Open_Data_XML_Test_Profile($profile, $open_data_checks);
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - test profile
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
    $current_open_data_profile_name = $profile;

    #
    # Initialize flags and counters
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
# Name: Check_Encoding
#
# Parameters: resp - HTTP response object
#             tcid - testcase identifier
#
# Description:
#
#   This function checks the character encoding of the URL content.
#
#***********************************************************************
sub Check_Encoding {
    my ($resp, $tcid) = @_;

    my ($content, $output);

    #
    # Do we have a HTTP::Response object ?
    #
    if ( defined($resp) ) {
        #
        # Does the HTTP response object indicate the content is UTF-8
        #
        if ( ($resp->header('Content-Type') =~ /charset=UTF-8/i) ||
             ($resp->header('X-Meta-Charset') =~ /UTF-8/i) ) {
            print "UTF-8 content\n" if $debug;
        }
        #
        # Does the string look like UTF-8 ?
        #
        elsif ( eval { utf8::is_utf8($content); } ) {
                print "UTF-8 content\n" if $debug;
        }
        else {
            #
            # Nothing in the header to indicate UTF-8, try
            # decoding it as UTF-8
            #
            $content = $resp->decoded_content(charset => 'none');
            if ( ! eval { decode('utf8', $content, Encode::FB_CROAK); 1} ) {
                #
                # Not UTF 8 content
                #
                $output =  eval { decode('utf8', $content, Encode::FB_WARN);};
                Record_Result($tcid, 0, -1, "$output",
                              String_Value("Character encoding is not UTF-8"));
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Open_Data_URL
#
# Parameters: url - URL of the dataset file
#             resp - HTTP::Response object
#       
#
# Description:
#
#   This function checks to see if the dataset URL is available
# and is encoded using UTF-8.
#
#***********************************************************************
sub Check_Open_Data_URL {
    my ($url, $resp) = @_;

    my ($message);

    #
    # Check unsuccessful GET operation
    #
    if ( ! defined($resp) || (! $resp->is_success) ) {
        #
        # Failed to get url
        #
        $message = String_Value("Dataset URL unavailable");
        if ( defined($resp) ) {
            $message .= " : " . $resp->status_line;
        }
        Record_Result("OD_1", -1, -1, "", $message);
    }
    else {
        #
        # Check for UTF-8 encoding
        #
        Check_Encoding($resp, "OD_2");
    }
}

#***********************************************************************
#
# Name: Check_Open_Data_API_URL
#
# Parameters: url - URL of the API
#             resp - HTTP::Response object
#       
#
# Description:
#
#   This function checks to see if the API URL is available
# and is encoded using UTF-8.
#
#***********************************************************************
sub Check_Open_Data_API_URL {
    my ($url, $resp) = @_;

    my ($message);

    #
    # Check unsuccessful GET operation
    #
    if ( ! defined($resp) || (! $resp->is_success) ) {
        #
        # Failed to get url
        #
        $message = String_Value("API URL unavailable");
        if ( defined($resp) ) {
            $message .= " : " . $resp->status_line;
        }
        Record_Result("OD_API_1", -1, -1, "", $message);
    }
    else {
        #
        # Check for UTF-8 encoding
        #
        Check_Encoding($resp, "OD_API_2");
    }
}

#***********************************************************************
#
# Name: Check_Dictionary_URL
#
# Parameters: url - open data file URL
#             resp - HTTP::Response object
#             dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function checks a data dictionary file.  It checks that 
#     - the content type is XML or TXT
#     - Some content specific checks
#
#***********************************************************************
sub Check_Dictionary_URL {
    my ($url, $resp, $dictionary) = @_;

    my ($result_object, @other_results, $content, $header, $mime_type);

    #
    # Data dictionary files are expected to be either XML or TXT
    # format.
    #
    print "Check_Dictionary_URL\n" if $debug;
    if ( defined($resp) &&  $resp->is_success ) {
        $header = $resp->headers;
        $mime_type = $header->content_type;

        #
        # Is this a plain text file ?
        #
        if ( $mime_type =~ /text\/plain/ ) {
            print "TXT data dictionary file\n" if $debug;
            @other_results = Open_Data_TXT_Check_Dictionary($url,
                                               $current_open_data_profile_name,
                                                            $resp->content,
                                                            $dictionary);
        }
        #
        # Is this XML ?
        #
        elsif ( ($mime_type =~ /application\/xhtml\+xml/) ||
                ($mime_type =~ /application\/xml/) ||
                ($mime_type =~ /text\/xml/) ||
                ($url =~ /\.xml$/i) ) {
            print "XML data dictionary file\n" if $debug;
            @other_results = Open_Data_XML_Check_Dictionary($url,
                                               $current_open_data_profile_name,
                                                            $resp->content,
                                                            $dictionary);
        }
        else {
            #
            # Unexpected mime-type for a dictionary
            #
            Record_Result("OD_3", -1, -1, "",
                          String_Value("Invalid mime-type for data dictionary")
                           . " \"" . $mime_type . "\"");
        }

        #
        # Add results from data dictionary check into the complete
        # results list.
        #
        foreach $result_object (@other_results) {
            push(@$results_list_addr, $result_object);
        }
    }
}

#***********************************************************************
#
# Name: Check_Resource_URL
#
# Parameters: url - open data file URL
#             resp - HTTP::Response object
#             dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function is a place holder for possible resource file checks.
#
#***********************************************************************
sub Check_Resource_URL {
    my ($url, $resp, $dictionary) = @_;

    print "Check_Resource_URL\n" if $debug;
}

#***********************************************************************
#
# Name: Check_Data_File_URL
#
# Parameters: url - open data file URL
#             resp - HTTP::Response object
#             dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function checks a data file.  It checks that 
#     - the content type is XML or CSV
#     - Some content specific checks
#
#***********************************************************************
sub Check_Data_File_URL {
    my ($url, $resp, $dictionary) = @_;

    my ($result_object, @other_results, $content, $header, $mime_type);

    #
    # Data files are expected to be either XML or CSV
    # format.
    #
    print "Check_Data_File_URL\n" if $debug;
    if ( defined($resp) &&  $resp->is_success ) {
        $header = $resp->headers;
        $mime_type = $header->content_type;

        #
        # Is this a CSV file ?
        #
        if ( ($mime_type =~ /text\/x-comma-separated-values/) ||
                ($mime_type =~ /text\/csv/) ||
                ($url =~ /\.csv$/i) ) {
            print "CSV data file\n" if $debug;
            @other_results = Open_Data_CSV_Check_Data($url,
                                               $current_open_data_profile_name,
                                                      $resp->content,
                                                      $dictionary);
        }
        #
        # Is this XML ?
        #
        elsif ( ($mime_type =~ /application\/xhtml\+xml/) ||
                ($mime_type =~ /application\/xml/) ||
                ($mime_type =~ /text\/xml/) ||
                ($url =~ /\.xml$/i) ) {
            print "XML data file\n" if $debug;
            @other_results = Open_Data_XML_Check_Data($url,
                                               $current_open_data_profile_name,
                                                      $resp->content,
                                                      $dictionary);
        }
        else {
            #
            # Unexpected mime-type for a dictionary
            #
            Record_Result("OD_3", -1, -1, "", 
                          String_Value("Invalid mime-type for data file") .
            " \"" . $mime_type . "\"");
        }
    }

    #
    # Add results from data dictionary check into the complete results list.
    #
    foreach $result_object (@other_results) {
        push(@$results_list_addr, $result_object);
    }
}

#***********************************************************************
#
# Name: Check_API_URL
#
# Parameters: url - open data API URL
#             resp - HTTP::Response object
#
# Description:
#
#   This function checks an API URL.  It checks that 
#     - the content type is XML or JSON
#     - the content contains valid markup
#
#***********************************************************************
sub Check_API_URL {
    my ($url, $resp) = @_;

    my ($result_object, @other_results, $content, $header, $mime_type);

    #
    # Data dictionary files are expected to be either XML or TXT
    # format.
    #
    print "Check_API_URL\n" if $debug;
    if ( defined($resp) &&  $resp->is_success ) {
        $header = $resp->headers;
        $mime_type = $header->content_type;

        #
        # Is the content type json ?
        #
        if ( $mime_type =~ /application\/json/i ) {
            print "JSON API URL\n" if $debug;
            @other_results = Open_Data_JSON_Check_API($url,
                                               $current_open_data_profile_name,
                                                            $resp->content);
        }
        #
        # Is this XML ?
        #
        elsif ( ($mime_type =~ /application\/xhtml\+xml/) ||
                ($mime_type =~ /application\/xml/) ||
                ($mime_type =~ /text\/xml/) ) {
            print "XML API URL\n" if $debug;
            @other_results = Open_Data_XML_Check_API($url,
                                               $current_open_data_profile_name,
                                                            $resp->content);
        }
        else {
            #
            # Unexpected mime-type for API
            #
            Record_Result("OD_API_3", -1, -1, "",
                          String_Value("Invalid mime-type for API")
                           . " \"" . $mime_type . "\"");
        }

        #
        # Add results from API check into the complete
        # results list.
        #
        foreach $result_object (@other_results) {
            push(@$results_list_addr, $result_object);
        }
    }
}

#***********************************************************************
#
# Name: Open_Data_Check
#
# Parameters: url - open data file URL
#             profile - testcase profile
#             data_file_type - type of dataset file
#             resp - HTTP::Response object
#             dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function runs a number of Open Data checks on a Dataset URLs.
#  The checks depend on the data file type.
#    DICTIONARY - a data dictionary file
#    DATA - a data file
#    RESOURCE - a resource file
#
#***********************************************************************
sub Open_Data_Check {
    my ( $url, $profile, $data_file_type, $resp, $dictionary ) = @_;

    my (@tqa_results_list, $result_object, @other_results);

    #
    # Do we have a valid profile ?
    #
    print "Open_Data_Check: profile = $profile\n" if $debug;
    if ( ! defined($open_data_profile_map{$profile}) ) {
        print "Unknown Open Data testcase profile passed $profile\n" if $debug;
        return;
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);
    $current_url = $url;

    #
    # Are any of the testcases defined in this module
    # in the testcase profile ?
    #
    if ( keys(%$current_open_data_profile) == 0 ) {
        #
        # No tests handled by this module
        #
        print "No tests handled by this module\n" if $debug;
        return(@tqa_results_list);
    }

    #
    # Is this a data dictionary file
    #
    if ( $data_file_type =~ /DICTIONARY/i ) {
        #
        # Check that the URL is valid and has proper encoding
        #
        Check_Open_Data_URL($url, $resp);

        #
        # Check dictionary content
        #
        Check_Dictionary_URL($url, $resp, $dictionary);
    }

    #
    # Is this a data file
    #
    elsif ( $data_file_type =~ /DATA/i ) {
        #
        # Check that the URL is valid and has proper encoding
        #
        Check_Open_Data_URL($url, $resp);

        #
        # Check data content
        #
        Check_Data_File_URL($url, $resp, $dictionary);
    }

    #
    # Is this a resource file
    #
    elsif ( $data_file_type =~ /RESOURCE/i ) {
        #
        # Check that the URL is valid and has proper encoding
        #
        Check_Open_Data_URL($url, $resp);

        #
        # Check resource content
        #
        Check_Resource_URL($url, $resp, $dictionary);
    }

    #
    # Is this a API URL
    #
    elsif ( $data_file_type =~ /API/i ) {
        #
        # Check that the URL is valid and has proper encoding
        #
        Check_Open_Data_API_URL($url, $resp);

        #
        # Check API content
        #
        Check_API_URL($url, $resp);
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "Open_Data_Check results\n";
        foreach $result_object (@tqa_results_list) {
            print "Testcase: " . $result_object->testcase;
            print "  URL   = " . $result_object->url . "\n";
            print "  message  = " . $result_object->message . "\n";
            print "  source line  = " . $result_object->source_line . "\n";
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
    my (@package_list) = ("tqa_result_object", "open_data_csv",
                          "open_data_txt", "open_data_xml",
                          "open_data_json",
                          "open_data_testcases", "crawler");

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

