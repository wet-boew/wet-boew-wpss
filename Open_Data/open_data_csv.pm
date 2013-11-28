#***********************************************************************
#
# Name:   open_data_csv.pm
#
# $Revision$
# $URL$
# $Date$
#
# Description:
#
#   This file contains routines that parse CSV files and check for
# a number of open data check points.
#
# Public functions:
#     Set_Open_Data_CSV_Language
#     Set_Open_Data_CSV_Debug
#     Set_Open_Data_CSV_Testcase_Data
#     Set_Open_Data_CSV_Test_Profile
#     Open_Data_CSV_Check_Data
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

package open_data_csv;

use strict;
use URI::URL;
use File::Basename;
use Text::CSV;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Set_Open_Data_CSV_Language
                  Set_Open_Data_CSV_Debug
                  Set_Open_Data_CSV_Testcase_Data
                  Set_Open_Data_CSV_Test_Profile
                  Open_Data_CSV_Check_Data
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

my ($max_error_message_string)= 2048;

#
# Status values
#
my ($check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Parse error in line",           "Parse error in line",
    "Inconsistent number of fields, found", "Inconsistent number of fields, found ",
    "expecting",                     "expecting",
    "No content in file",            "No content in file",
    "Missing header row terms",      "Missing header row terms",
    );

my %string_table_fr = (
    "Parse error in line",           "Parse error en ligne",
    "Inconsistent number of fields, found", "Numéro incohérente des champs, a constaté ",
    "expecting",                     "expectant",
    "No content in file",            "Aucun contenu dans fichier",
    "Missing header row terms",      "Manquant termes de lignes d'en-tête",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_Open_Data_CSV_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Open_Data_CSV_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_Open_Data_CSV_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Open_Data_CSV_Language {
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
# Name: Set_Open_Data_CSV_Testcase_Data
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
sub Set_Open_Data_CSV_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_Open_Data_CSV_Test_Profile
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
sub Set_Open_Data_CSV_Test_Profile {
    my ($profile, $testcase_names) = @_;

    my (%local_testcase_names);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Open_Data_CSV_Test_Profile, profile = $profile\n" if $debug;
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
# Name: Check_First_Data_Row
#
# Parameters: dictionary - address of a hash table for data dictionary
#             fields - list of field values
#
# Description:
#
#   This function checks the fields from the first row of SV file.
# It checks to see if the values match the terms found in the data
# dictionary.  If there is a match on 25% of the fields, a check is
# made to ensure all fields match data dictionary terms.
#
#***********************************************************************
sub Check_First_Data_Row {
    my ($dictionary, @fields) = @_;

    my ($count, $term, $field, @unmatched_fields);
    
    #
    # Do we have any dictionary terms ?
    #
    if ( keys(%$dictionary) == 0 ) {
        print "No terms to check for first row of CSV file\n" if $debug;
        return();
    }
    
    #
    # Count the number of terms found in the fields
    #
    print "Check for terms in first row of CSV file\n" if $debug;
    $count = 0;
    #
    # Check each field for a matching term
    #
    foreach $field (@fields) {
        if ( defined($$dictionary{$field}) ) {
            print "Found term/field match for $term\n" if $debug;
            $count++;
        }
        else {
            #
            # An unmatched field, save it for possible use later
            #
            push (@unmatched_fields, $field);
        }
    }
    
    #
    # Did we find a matching term for each field ?
    #
    if ( $count == @fields ) {
        print "All fields match a term\n" if $debug;
        return();
    }
    #
    # Did we match no terms, we may not have a heading row in this
    # CSV file
    #
    elsif ( $count == 0 ) {
        print "Fields do not match any terms, assume no heading row\n" if $debug;
        return();
    }
    #
    # Didn't we get a match on atleast 25% of the fields ? If so we expect
    # all the fields to match.
    #
    elsif ( $count >= (@fields / 4) ) {
        print "Found atleast 25% match on fields and terms\n" if $debug;
        Record_Result("OD_3", 1, 0, "",
                      String_Value("Missing header row terms") .
                      " \"" . join(", ", @unmatched_fields) . "\"");
    }
    else {
        #
        # Found a matching term for all fields
        #
        print "Found a matching term for all fields\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Open_Data_CSV_Check_Data
#
# Parameters: this_url - a URL
#             profile - testcase profile
#             content - CSV content
#             dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function runs a number of open data checks on CSV data file content.
#
#***********************************************************************
sub Open_Data_CSV_Check_Data {
    my ($this_url, $profile, $content, $dictionary) = @_;

    my ($parser, $url, @tqa_results_list, $result_object, $testcase);
    my ($line, @fields, $line_no, $status, $found_fields, $field_count);
    my ($csv_file, $csv_file_name, $rows, $message);

    #
    # Do we have a valid profile ?
    #
    print "Open_Data_CSV_Check_Data: Checking URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($open_data_profile_map{$profile}) ) {
        print "Open_Data_CSV_Check_Data: Unknown CSV testcase profile passed $profile\n";
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
    if ( length($content) == 0 ) {
        print "No content passed to Open_Data_CSV_Check_Data\n" if $debug;
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
        # Create a temporary file for the PDF content.
        #
        $csv_file_name = "csv_text$$.csv";
        unlink($csv_file_name);
        print "Create temporary CSV file $csv_file_name\n" if $debug;
        open($csv_file, ">$csv_file_name") ||
            die "Open_Data_CSV_Check_Data: Failed to open $csv_file_name for writing\n";
        binmode $csv_file;
        print $csv_file $content;
        close($csv_file);
        open($csv_file, "$csv_file_name") ||
            die "Open_Data_CSV_Check_Data: Failed to open $csv_file_name for reading\n";

        #
        # Create a document parser
        #
        $parser = Text::CSV->new ({ binary => 1, eol => $/ });

        #
        # Parse each line/record of the content
        #
        $line_no = 0;
        while ( $rows = $parser->getline($csv_file) ) {
            #
            # Increment record/line number
            #
            $line_no++;

            #
            # Get the set of fields from the parsed line/record
            #
            @fields = @$rows;

            #
            # Is this the first row ? If so check for a possible heading
            # row (i.e. the field values are the dictionary terms)
            #
            if ( $line_no == 1 ) {
                Check_First_Data_Row($dictionary, @fields);
            }

            #
            # Do we have the number of expected fields ?
            #
            if ( ! defined($field_count) ) {
                $field_count = @fields;
                print "Expected fields count = $field_count\n" if $debug;
            }
            #
            # Does the field count match the expected number of fields ?
            #
            elsif ( $field_count != @fields ) {
                $found_fields = @fields;
                Record_Result("OD_3", $line_no, 0, "$line",
                      String_Value("Inconsistent number of fields, found") .
                       " $found_fields " . String_Value("expecting") .
                       " $field_count");
            }
        }

        #
        # Did we get to the end of file or did we encounter a parsing error
        #
        if ( ! $parser->eof() ) {
            $line = $parser->error_input();
            $message = $parser->error_diag();
            print "CSV file error at line $line_no, line = \"$line\"\n" if $debug;
            print "parser->error_diag = \"$message\"\n" if $debug;
            Record_Result("OD_3", $line_no, 0, $line,
                          String_Value("Parse error in line"));
        }
        close($csv_file);
        unlink($csv_file_name);

        #
        # Did we find any rows in the CSV content ?
        #
        if ( $line_no == 0 ) {
            Record_Result("OD_3", -1, 0, "",
                          String_Value("No content in file"));
        }
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "Open_Data_CSV_Check_Data results\n";
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

