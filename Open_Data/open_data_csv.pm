#***********************************************************************
#
# Name:   open_data_csv.pm
#
# $Revision: 411 $
# $URL: svn://10.36.20.203/Open_Data/Tools/open_data_csv.pm $
# $Date: 2017-07-17 15:58:09 -0400 (Mon, 17 Jul 2017) $
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
#     Open_Data_CSV_Check_Get_Headings_List
#     Open_Data_CSV_Check_Get_Row_Column_Counts
#     Open_Data_CSV_Check_Get_Column_Object_List
#     Open_Data_CSV_Compare_JSON_CSV
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
use IO::Handle;
use File::Temp qw/ tempfile tempdir /;
use HTML::Entities;
use Digest::MD5 qw(md5_hex);
use Encode;

#
# Use WPSS_Tool program modules
#
use crawler;
use csv_column_object;
use csv_parser;
use open_data_testcases;
use open_data_json;
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
    @EXPORT  = qw(Set_Open_Data_CSV_Language
                  Set_Open_Data_CSV_Debug
                  Set_Open_Data_CSV_Testcase_Data
                  Set_Open_Data_CSV_Test_Profile
                  Open_Data_CSV_Check_Data
                  Open_Data_CSV_Check_Get_Headings_List
                  Open_Data_CSV_Check_Get_Row_Column_Counts
                  Open_Data_CSV_Check_Get_Column_Object_List
                  Open_Data_CSV_Compare_JSON_CSV
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
my ($csv_validator, $last_csv_headings_list);

my ($max_error_message_string)= 2048;
my ($runtime_error_reported) = 0;

#
# Data file object attribute names
#
my ($column_count_attribute) = "Column Count";
my ($row_count_attribute) = "Row Count";
my ($column_list_attribute) = "Column List";

#
# Status values
#
my ($check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "and",                           "and",
    "At line number",                "At line number",
    "Column",                        "Column",
    "CSV and JSON-CSV values do not match for column", "CSV and JSON-CSV values do not match for column",
    "csv-validator failed",          "csv-validator failed",
    "Data pattern",                  "Data pattern",
    "Duplicate column header",       "Duplicate column header",
    "Duplicate content in columns",  "Duplicate content in columns",
    "Duplicate row content, first instance at", "Duplicate row content, first instance at row",
    "Empty line as first line of multi-line field", "Empty line as first line of multi-line field",
    "Expected a heading after 2 blank lines", "Expected a heading after 2 blank lines",
    "expecting",                     "expecting",
    "failed for value",              "failed for value",
    "found",                         "found",
    "Found an ordered list item in an unordered list", "Found an ordered list item in an unordered list",
    "Found an unordered list item in an ordered list", "Found an unordered list item in an ordered list",
    "Found at",                      "Found at",
    "Heading must be a single line", "Heading must be a single line",
    "Inconsistent list item prefix, found", "Inconsistent list item prefix, found",
    "Inconsistent number of fields, found", "Inconsistent number of fields, found",
    "List item prefix character found for list of 1 item", "List item prefix character found for list of 1 item",
    "List item value",               "List item value",
    "Missing header row",            "Missing header row",
    "Missing header row terms",      "Missing header row terms",
    "Missing list item prefix character", "Missing list item prefix character",
    "Missing UTF-8 BOM",             "Missing UTF-8 BOM",
    "More than 1 blank line between list items", "More than 1 blank line between list items",
    "No blank line between list items", "No blank line between list items",
    "No content in file",            "No content in file",
    "No content in row",             "No content in row",
    "Parse error in line",           "Parse error in line",
    "row",                           "row",
    "Runtime Error",                 "Runtime Error",
    );

my %string_table_fr = (
    "and",                           "et",
    "At line number",                "Au numéro de ligne",
    "Column",                        "Colonne",
    "CSV and JSON-CSV values do not match for column", "Les valeurs CSV et JSON-CSV ne correspondent pas à la colonne",
    "csv-validator failed",          "csv-validator a échoué",
    "Data pattern",                  "Modèle de données",
    "Duplicate column header",       "En-tête de colonne en double",
    "Duplicate content in columns",  "Dupliquer le contenu dans les colonnes",
    "Empty line as first line of multi-line field", "Ligne vide comme première ligne de champ multi-lignes",
    "Duplicate row content, first instance at", "Dupliquer le contenu en ligne, première instance à ligne",
    "Expected a heading after 2 blank lines", "Attendu un en-tête après 2 lignes vides",
    "expecting",                     "expectant",
    "failed for value",              "a échoué pour la valeur",
    "found",                         "trouver",
    "Found an ordered list item in an unordered list", "Trouver un élément de liste ordonnée dans une liste non ordonnée",
    "Found an unordered list item in an ordered list", "Trouver un élément de liste non ordonnée dans une liste ordonnée",
    "Found at",                      "Trouvé à",
    "Heading must be a single line", "Le titre doit être une seule ligne",
    "Inconsistent list item prefix, found", "Préfixe d'élément de liste incompatible, trouvé",
    "Inconsistent number of fields, found", "Numéro incohérente des champs, a constaté",
    "List item value",               "Valeur de l'élément de liste",
    "List item prefix character found for list of 1 item", "Caractère de préfixe d'élément de liste trouvé pour la liste de 1 élément",
    "Missing header row",            "Manquant lignes d'en-tête",
    "Missing header row terms",      "Manquant termes de lignes d'en-tête",
    "Missing list item prefix character", "Caractère de préfixe d'élément de liste manquant",
    "Missing UTF-8 BOM",             "Manquant UTF-8 BOM",
    "More than 1 blank line between list items", "Plus d'une ligne vide entre les éléments de la liste",
    "No blank line between list items", "Pas de ligne vide entre les éléments de la liste",
    "No content in file",            "Aucun contenu dans fichier",
    "No content in row",             "Aucun contenu dans ligne",
    "Parse error in line",           "Parse error en ligne",
    "row",                           "ligne",
    "Runtime Error",                 "Erreur D'Exécution",
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
    
    #
    # Set debug flag in supporting modules
    #
    CSV_Parser_Debug($debug);
    Set_CSV_Column_Object_Debug($debug);
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

    my ($count, $field, @unmatched_fields, %headers);
    my (@headings) = ();
    
    #
    # Do we have any dictionary terms ?
    #
    if ( keys(%$dictionary) == 0 ) {
        print "No terms to check for first row of CSV file\n" if $debug;
        return(@headings);
    }
    
    #
    # Count the number of terms found in the fields
    #
    print "Check for terms in first row of CSV file\n" if $debug;
    $count = 0;
    foreach $field (@fields) {
        #
        # Don't convert to lower case, terms are case sensitive
        #
        # Check to see if it matches a dictionary entry.
        #
        $field =~ s/^\s*//g;
        $field =~ s/\s*$//g;
        if ( defined($$dictionary{$field}) ) {
            print "Found term/field match for \"$field\"\n" if $debug;
            $count++;
        }
        else {
            #
            # An unmatched field, save it for possible use later
            #
            push (@unmatched_fields, "$field");
            print "No dictionary value for \"$field\"\n" if $debug;
        }
        
        #
        # Do we have a duplicate header ?
        #
        if ( defined($headers{$field}) ) {
            Record_Result("OD_DATA", 1, 0, "",
                          String_Value("Duplicate column header") .
                          " \"$field\". " .
                          String_Value("Found at" . " " .
                          $headers{$field} .
                          String_Value("and") . " $count"));
        }
        else {
            #
            # Save header name
            #
            $headers{$field} = $count;
        }
    }
    
    #
    # Did we find a matching term for each field ?
    #
    if ( $count == @fields ) {
        print "All fields match a term\n" if $debug;
        
        #
        # Create a list of dictionary objects for the headings
        #
        foreach $field (@fields) {
            push(@headings, $$dictionary{$field});
        }
    }
    #
    # Did we get a match on atleast 25% of the fields ? If so we expect
    # all the fields to match.
    #
    elsif ( $count >= (@fields / 4) ) {
        print "Found atleast 25% match on fields and terms\n" if $debug;
        Record_Result("TP_PW_OD_DATA", 1, 0, "",
                      String_Value("Missing header row terms") .
                      " \"" . join(", ", @unmatched_fields) . "\"");
    }
    else {
        #
        # Missing header row, found a match on fewer than 25% of fields
        #
        print "Found a match on fewer than 25% fields\n" if $debug;
        if ( $count == 0 ) {
            Record_Result("TP_PW_OD_DATA", 1, 0, "",
                          String_Value("Missing header row"));
        }
        else {
            Record_Result("TP_PW_OD_DATA", 1, 0, "",
                          String_Value("Missing header row terms") .
                          " \"" . join(", ", @unmatched_fields) . "\"");
        }
    }
    
    #
    # Return list of headings found
    #
    $last_csv_headings_list = join(",", @fields);
    return(@headings);
}

#***********************************************************************
#
# Name: Check_UTF8_BOM
#
# Parameters: csv_file - CSV file object
#
# Description:
#
#   This function reads the passed file object and checks to see
# if a UTF-8 BOM is present.  If one is found, the current reading position
# is set to just after the BOM.  This avoids parsing errors with the
# file.
#
# UTF-8 BOM = $EF $BB $BF
# Byte Order Mark - http://en.wikipedia.org/wiki/Byte_order_mark
#
#***********************************************************************
sub Check_UTF8_BOM {
    my ($csv_file) = @_;
    
    my ($line, $char, $have_bom);
    
    #
    # Get a line of content from the file
    #
    print "Check_UTF8_BOM\n" if $debug;
    $line = $csv_file->getline();

    #
    # Check first character of line for character 65279 (xFEFF)
    #
    print "line = \"$line\"\n" if $debug;
    $char = substr($line, 0, 1);
    if ( ord($char) == 65279 ) {
        #
        # Set reading position at character 3
        #
        print "Skip over BOM xFEFF\n" if $debug;
        seek($csv_file, 3, 0);
        $line = $csv_file->getline();
        print "line = \"$line\"\n" if $debug;
        seek($csv_file, 3, 0);
        $have_bom = 1;
    }
    elsif ( $line =~ s/^\xEF\xBB\xBF// ) {
        #
        # Set reading position at character 3
        #
        print "Skip over BOM xEFBBBF\n" if $debug;
        seek($csv_file, 3, 0);
        $line = $csv_file->getline();
        print "line = \"$line\"\n" if $debug;
        seek($csv_file, 3, 0);
        $have_bom = 1;
    }
    else {
        #
        # Reposition to the beginning of the file
        #
        print "Reset reading position to beginning of the file\n" if $debug;
        seek($csv_file, 0, 0);
        $have_bom = 0;
    }
    
    #
    # Are we missing the BOM ?
    #
    if ( ! $have_bom ) {
        Record_Result("TP_PW_OD_BOM", 1, 0, $line,
                      String_Value("Missing UTF-8 BOM"));
    }
    
    #
    # Return BOM flag
    #
    return($have_bom);
}

#***********************************************************************
#
# Name: Run_CSV_Validator
#
# Parameters: this_url - a URL
#             filename - CSV content file
#             have_bom - flag to indicate if the file contains a
#                        BOM - Byte Order Mark
#             headings - array of dictionary objects
#
# Description:
#
#   This function check the headings to see if there are any data
# conditions.  If there are some, it then runs the csv-validator
# tool to validate the contents of the CSV file.
#
#***********************************************************************
sub Run_CSV_Validator {
    my ($this_url, $filename, $have_bom, @headings) = @_;

    my ($heading, $condition, $csvs_fh, $csvs_filename, $output);
    my ($csv_filename, $csv_fh, $temp_csv_fh, $line);
    my ($have_condition) = 0;
    
    #
    # Do we have headings ?
    #
    if ( @headings > 0 ) {
        print "Run_CSV_Validator\n" if $debug;

        #
        # Construct a csv-validator schema file with the
        # column conditions.
        #
        ($csvs_fh, $csvs_filename) = tempfile("WPSS_TOOL_XXXXXXXXXX",
                                              SUFFIX => '.csvs',
                                              TMPDIR => 1);
        if ( ! defined($csvs_fh) ) {
            print "Error: Failed to create temporary file in Run_CSV_Validator\n";
            print STDERR "Error: Failed to create temporary file in Run_CSV_Validator\n";
            return;
        }
        binmode $csvs_fh, ":utf8";
        print "CSV schema file = $csvs_filename\n" if $debug;
        
        #
        # print version number and number of columns to schema file
        #
        print $csvs_fh "version 1.0\n";
        print $csvs_fh '@totalColumns ' . scalar(@headings) . "\n";
        print "version 1.0\n" if $debug;
        print '@totalColumns ' . scalar(@headings) . "\n" if $debug;

        #
        # Add heading conditions
        #
        foreach $heading (@headings) {
            #
            # Print heading label to the schema file.
            #
            print $csvs_fh "\"" . $heading->term() . "\":";
            print $heading->term() . ":" if $debug;

            #
            # Do we have a heading condition ?
            #
            $condition = $heading->condition();
            if ( $condition ne "" ) {
                #
                # Include condition for this heading
                #
                print $csvs_fh " $condition\n";
                print " $condition\n" if $debug;

                #
                # Set flag to indicate we have at least 1 condition to check
                #
                $have_condition = 1;
            }
            else {
                #
                # No condition for this heading, just include the heading
                # in the schema file without any condition.
                #
                print $csvs_fh "\n";
                print "\n" if $debug;
            }
        }
        
        #
        # Close the schema file
        #
        close($csvs_fh);
        
        #
        # Did we find at least 1 data condition
        #
        if ( $have_condition ) {
            #
            # Do we have a byte order mark in the CSV file ?
            #
            if ( $have_bom ) {
                #
                # Make a copy of the CSV file and strip out any UTF-8 BOM that
                # may be present.  The csv-validator does not handle the BOM and
                # reports problems with the header line.
                #
                print "Have BOM, create temporary CSV file before running csv-validator\n" if $debug;
                ($temp_csv_fh, $csv_filename) = tempfile("WPSS_TOOL_XXXXXXXXXX",
                                                         SUFFIX => '.csv',
                                                         TMPDIR => 1);
                if ( ! defined($temp_csv_fh) ) {
                    print "Error: Failed to create temporary file in Run_CSV_Validator\n";
                    print STDERR "Error: Failed to create temporary file in Run_CSV_Validator\n";
                    unlink($csvs_filename);
                    return;
                }
                binmode $temp_csv_fh, ":utf8";
                print "Temporary CSV file = $csv_filename\n" if $debug;
                
                #
                # Open the original CSV file and skip over the BOM
                #
                open($csv_fh, "$filename");
                binmode $csv_fh, ":utf8";
                seek($csv_fh, 3, 0);
                
                #
                # Copy original CSV content into the temporary CSV file
                #
                print "Copy original CSV file after skipping BOM\n" if $debug;
                while ( $line = $csv_fh->getline() ) {
                    $temp_csv_fh->write($line, length($line));
                }
                close($csv_fh);
                close($temp_csv_fh);
            }
            else {
                $csv_filename = $filename;
            }
            
            #
            # Run the csv-validator
            #
            print "Run $csv_validator\n --> $csv_filename $csvs_filename 2>\&1\n" if $debug;
            $output = `$csv_validator \"$csv_filename\" \"$csvs_filename\" 2>\&1`;
            print "Validator output = $output\n" if $debug;
            
            #
            # Did the validator report any errors ?
            #
            if ( $output =~ /Error:/ ) {
                print "csv-validator failed\n" if $debug;
                Record_Result("OD_DATA", -1, -1, "",
                              String_Value("csv-validator failed") .
                              " \"$output\"");
            }
            elsif ( $output =~ /PASS/ ) {
                #
                # CSV validation passed
                #
                print "csv-validator passed\n" if $debug;
            }
            else {
                #
                # Some error trying to run the validator
                #
                print "csv-validator command failed\n" if $debug;
                print STDERR "csv-validator command failed\n";
                print STDERR "  $csv_validator $csv_filename $csvs_filename\n";
                print STDERR "$output\n";
                
                #
                # Report runtime error only once
                #
                if ( ! $runtime_error_reported ) {
                    Record_Result("OD_DATA", -1, -1, "",
                                  String_Value("Runtime Error") .
                                  " \"$csv_validator $csv_filename $csvs_filename\"\n" .
                                  " \"$output\"");
                    $runtime_error_reported = 1;
                }
            }
        }
        else {
            print "No data conditions, skipping csv-validator\n" if $debug;
        }
        
        #
        # Clean up the temporary schema file and temporary CSV file
        #
        unlink($csvs_filename);
        if ( $have_bom ) {
            unlink($csv_filename);
        }
    }
}

#***********************************************************************
#
# Name: Check_List_Length
#
# Parameters: line - the row from the CSV file
#             line_no - the line number from the CSV file
#             field_number - the field number
#             list_item_count - The coiunt of the number of items in the list
#             list_item - The current list item
#
# Description:
#
#   This function checks the number of list items in the last list. A
# list of 1 item must not include a list item prefix character.
#
#***********************************************************************
sub Check_List_Length {
    my ($line, $line_no, $field_number, $list_item_count, $list_item) = @_;

    #
    # If we had only 1 item in the list, we do not need a list
    # item prefix character.
    #
    if ( $list_item_count == 1 ) {
        print "Unnecessary list item prefix found for list of 1 item\n" if $debug;
        Record_Result("OD_DATA", $line_no, $field_number, $line,
                      String_Value("List item prefix character found for list of 1 item") .
                      " \"$list_item\"");
    }
}

#***********************************************************************
#
# Name: Check_Multi_Line_Field
#
# Parameters: line - the row from the CSV file
#             line_no - the line number from the CSV file
#             field - The entire content of the field
#             field_number - the field number
#             lines - The lines of text in the field
#
# Description:
#
#   This function checks fields the contains multiple lines of text.
# It checks:
#   if the first line is empty or contains only blanks
#   if there are any headings, paragraphs or lists in the text
#
#***********************************************************************
sub Check_Multi_Line_Field {
    my ($line, $line_no, $field, $field_number, @lines) = @_;

    my ($single_line, $i, $in_list, $list_item_prefix, $list_item_count);
    my ($item_prefix, $blank_line_count, $in_list_item, $list_item);
    my ($last_list_item, $list_type, $in_paragraph, $last_line);
    my ($expect_heading);

    #
    # Is the first line an empty line, or consist of
    # white space only?
    #
    print "Check_Multi_Line_Field line $line_no, column $field_number\n" if $debug;
    print "Field contains " . scalar(@lines) . " lines\n" if $debug;
    if ( $lines[0] =~ /^\s*$/ ) {
        #
        # Does the rest of the field contain characters other than
        # white space, newline or carriage return?
        #
        $single_line = $field;
        $single_line =~ s/\s|\n|\r//g;
        if ( $single_line ne "" ) {
            Record_Result("OD_DATA", $line_no, $field_number, $line,
                          String_Value("Empty line as first line of multi-line field") .
                          " #$field_number \"$field\"");
            return;
        }
    }
    
    #
    # Does the text appear to be a list ?
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
        # Get this line from the multi-line field value
        $single_line = $lines[$i];
        print "Line # $i \"$single_line\"\n" if $debug;
        
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
                $expect_heading = 1;
            }
            
            #
            # Clear the last line of text
            #
            $last_line = "";
            next;
        }
        #
        # Is this an unordered list item? (i.e. starts with a dash,
        # asterisk or bullet).
        #
        elsif ( $single_line =~ /^\s*([\-\*])\s+[^\s]+.*$/ ) {
            #
            # Are we expecing a heading (previous 2 lines were blank)
            #
            if ( $expect_heading ) {
                print "Expecting a heading, found a list\n" if $debug;
                Record_Result("OD_DATA", $line_no, $field_number, $line,
                              String_Value("Expected a heading after 2 blank lines") .
                              " " . String_Value("At line number") .
                              " " . ($i + 1) . ". " .
                              String_Value("found") . " \"$single_line\"");

                #
                # Clear heading flag and to to next line
                #
                $expect_heading = 0;
            }
            
            #
            # Found an unordered list, do we already have a list? and
            # is it ordered?
            #
            print "Found unordered list item\n" if $debug;
            if ( ($list_type ne "") && ($list_type eq "ordered") ) {
                print "Found an unordered list item in an ordered list\n" if $debug;
                Record_Result("OD_DATA", $line_no, $field_number, $line,
                              String_Value("Found an unordered list item in an ordered list") .
                              " " . String_Value("At line number") .
                              " " . ($i + 1) . ". " .
                              String_Value("List item value") . " \"$single_line\"");
                next;
            }
            elsif ( $list_type eq "" ) {
                $list_type = "unordered";
            }
            
            #
            # Get the list item prefix character
            #
            ($item_prefix) = $single_line =~ /^\s*([\-\*])\s+[^\s]+.*$/io;
            
            #
            # Are we already inside a list? If so there should be
            # one blank line between list items
            #
            if ( $in_list ) {
                if ( $blank_line_count == 0 ) {
                    print "No blank line between list items\n" if $debug;
                    Record_Result("OD_DATA", $line_no, $field_number, $line,
                                  String_Value("No blank line between list items") .
                                  " " . String_Value("At line number") .
                                  " " . ($i + 1) . ". " .
                                  String_Value("List item value") . " \"$single_line\"");
                }
                elsif ( $blank_line_count == 2 ) {
                    #
                    # Only check if blank line count is 2.  If it is more than
                    # 2, we would report an error for each blank line.
                    #
                    print "Have $blank_line_count blank lines between list items\n" if $debug;
                    Record_Result("OD_DATA", $line_no, $field_number, $line,
                                  String_Value("More than 1 blank line between list items") .
                                  " " . String_Value("At line number") .
                                  " " . ($i + 1) . ". " .
                                  String_Value("List item value") . " \"$single_line\"");
                }
            }

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
                ($single_line =~ /^\s*([A-Z]+[\.\)])\s+[^\s]+.*$/i) ||
                ($single_line =~ /^\s*([ivx]+[\.\)])\s+[^\s]+.*$/i) ) {
            #
            # Are we expecing a heading (previous 2 lines were blank)
            #
            if ( $expect_heading ) {
                print "Expecting a heading, found a list\n" if $debug;
                Record_Result("OD_DATA", $line_no, $field_number, $line,
                              String_Value("Expected a heading after 2 blank lines") .
                              " " . String_Value("At line number") .
                              " " . ($i + 1) . ". " .
                              String_Value("found") . " \"$single_line\"");

                #
                # Clear heading flag and to to next line
                #
                $expect_heading = 0;
            }

            #
            # Found an ordered list, do we already have a list? and
            # is it unordered?
            #
            print "Found ordered list item\n" if $debug;
            if ( ($list_type ne "") && ($list_type eq "unordered") ) {
                print "Found an ordered list item in an unordered list\n" if $debug;
                Record_Result("OD_DATA", $line_no, $field_number, $line,
                              String_Value("Found an ordered list item in an unordered list") .
                              " " . String_Value("At line number") .
                              " " . ($i + 1) . ". " .
                              String_Value("List item value") . " \"$single_line\"");
                next;
            }
            elsif ( $list_type eq "" ) {
                $list_type = "ordered";
            }

            #
            # Get the list item prefix characters. Try numbered list first
            #
            $item_prefix = "";
            if ( $single_line =~ /^\s*(\d+[\.\)])\s+[^\s]+.*$/ ) {
                $item_prefix = "digits";
            }

            #
            # Try lettered list.
            #
            if ( $single_line =~ /^\s*([A-Z]+[\.\)])\s+[^\s]+.*$/ ) {
                $item_prefix = "letters";
            }

            #
            # Try roman numeral list.
            #
            if ( $single_line =~ /^\s*([ivx]+[\.\)])\s+[^\s]+.*$/ ) {
                $item_prefix = "roman";
            }
            print "List item prefix type is $item_prefix\n" if $debug;

            #
            # Are we already inside a list? If so there should be
            # one blank line between list items
            #
            if ( $in_list ) {
                if ( $blank_line_count == 0 ) {
                    print "No blank line between list items\n" if $debug;
                    Record_Result("OD_DATA", $line_no, $field_number, $line,
                                  String_Value("No blank line between list items") .
                                  " " . String_Value("At line number") .
                                  " " . ($i + 1) . ". " .
                                  String_Value("List item value") . " \"$single_line\"");
                }
                elsif ( $blank_line_count == 2 ) {
                    #
                    # Only check if blank line count is 2.  If it is more than
                    # 2, we would report an error for each blank line.
                    #
                    print "Have $blank_line_count blank lines between list items\n" if $debug;
                    Record_Result("OD_DATA", $line_no, $field_number, $line,
                                  String_Value("More than 1 blank line between list items") .
                                  " " . String_Value("At line number") .
                                  " " . ($i + 1) . ". " .
                                  String_Value("List item value") . " \"$single_line\"");
                }
            }

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
        else {
            #
            # If we are in a list item, appeand this text to the list item
            #
            if ( $in_list_item ) {
                $list_item .= "\n$single_line";
                next;
            }
            #
            # Are we inside of a list ?
            #
            elsif ( $in_list ) {
                #
                # Not in a list item, but in a list.  The list has ended,
                # this text may be a heading or the beginning of a paragraph.
                #
                $in_list = 0;
                $list_type = "";
                print "End of list encountered\n" if $debug;
                Check_List_Length($line, $line_no, $field_number,
                                  $list_item_count, $list_item);
            }
            #
            # Was the last line text also? If so we are inside a paragraph
            #
            elsif ( $last_line ne "" ) {
                #
                # Are we expecing a heading (previous 2 lines were blank)
                #
                if ( $expect_heading ) {
                    print "Expecting a heading, found a paragraph\n" if $debug;
                    Record_Result("OD_DATA", $line_no, $field_number, $line,
                                  String_Value("Heading must be a single line") .
                                  ", " . String_Value("found") .
                                  " \n\"$last_line\n$single_line\"\n" .
                                  String_Value("At line number") .
                                  " " . ($i + 1));

                    #
                    # Clear heading flag
                    #
                    $expect_heading = 0;
                }

                #
                # Inside a paragraph
                #
                $in_paragraph = 1;
            }
            else {
                #
                # Not in a list, ignore this line of text.
                #
            }
            
            #
            # Save this line of text and clean the blank line count
            #
            $last_line = $single_line;
            $blank_line_count = 0;
        }
        
        #
        # If this is the first list item, set the list item prefix character
        #
        if ( $in_list_item && ($list_item_count == 1) ) {
            $list_item_prefix = $item_prefix;
            print "Start of list, item prefix is \"$item_prefix\"\n" if $debug;
        }
        #
        # Not first list item, check that this item prefix matches the
        # expected list item prefix.
        #
        elsif ( $in_list_item && ($item_prefix ne $list_item_prefix) ) {
            print "Inconsistent list item prefix at item #$list_item_count, expecting \"$list_item_prefix\" found \"$item_prefix\"\n" if $debug;
            Record_Result("OD_DATA", $line_no, $field_number, $line,
                          String_Value("Inconsistent list item prefix, found") .
                          " \"$item_prefix\" " . String_Value("expecting") .
                          " \"$list_item_prefix\". " .
                          String_Value("At line number") .
                          " " . ($i + 1) . ". " .
                          String_Value("List item value") . " \"$single_line\"");
        }
    }
    
    #
    # Are we still in a list? (list is the only content in the field).
    # Check the number of list items, if we have only 1, we don't
    # need a list item prefix character.
    #
    if ( $in_list ) {
        print "Field only contains a list with $list_item_count items using prefix \"$list_item_prefix\"\n" if $debug;
        
        #
        # If we had only 1 item in the list, we do not need a list
        # item prefix character.
        #
        Check_List_Length($line, $line_no, $field_number,
                          $list_item_count, $list_item);
    }
}

#***********************************************************************
#
# Name: Check_Single_Line_Field
#
# Parameters: line - the row from the CSV file
#             line_no - the line number from the CSV file
#             field - The entire content of the field
#             field_number - the field number
#
# Description:
#
#   This function checks fields the contains single lines of text.
# It checks:
#   if a list item prefix appears on the line
#
#***********************************************************************
sub Check_Single_Line_Field {
    my ($line, $line_no, $field, $field_number) = @_;

    my ($single_line, $i, $in_list, $list_item_prefix, $list_item_count);
    my ($item_prefix, $blank_line_count, $in_list_item, $list_item);
    my ($last_list_item);

    #
    # Is this an unordered list item? (i.e. starts with a dash,
    # asterisk or bullet).
    #
    print "Check_Single_Line_Field line $line_no, column $field_number\n" if $debug;
    if ( $field =~ /^\s*([\-\*])\s+[^\s]+.*$/ ) {
        #
        # Get the list item prefix character
        #
        ($item_prefix) = $field =~ /^\s*([\-\*])\s+[^\s]+.*$/io;
        print "Unnecessary list item prefix found for list of 1 items\n" if $debug;
            Record_Result("OD_DATA", $line_no, $field_number, $line,
                          String_Value("List item prefix character found for list of 1 item") .
                          " \"$field\"");
    }
}

#***********************************************************************
#
# Name: Open_Data_CSV_Check_Data
#
# Parameters: this_url - a URL
#             data_file_object - a data file object pointer
#             profile - testcase profile
#             filename - CSV content file
#             dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function runs a number of open data checks on CSV data file content.
#
#***********************************************************************
sub Open_Data_CSV_Check_Data {
    my ($this_url, $data_file_object, $profile, $filename, $dictionary) = @_;

    my ($parser, $url, @tqa_results_list, $result_object, $testcase);
    my ($line, @fields, $line_no, $status, $found_fields, $field_count);
    my ($csv_file, $csv_file_name, $rows, $message, $content);
    my ($row_content, $eval_output, @headings, $i, $regex, $heading, $data);
    my ($have_bom, %row_checksum, $checksum);
    my (%duplicate_columns, %duplicate_columns_flag, $j, $this_field);
    my ($duplicate_columns_ptr, $duplicate_column_list, $other_heading);
    my (%blank_zero_column_flag, $parse_error_reported, @lines);
    my (@csv_columns, $column_object);

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
    # Save the list of CSV column heading objects for this URL
    #
    $data_file_object->attribute($column_list_attribute, \@csv_columns);

    #
    # Open the CSV file for reading.
    #
    print "Open CSV file $filename\n" if $debug;
    open($csv_file, "$filename") ||
        die "Open_Data_CSV_Check_Data: Failed to open $filename for reading\n";
    binmode $csv_file;

    #
    # Check for UTF-8 BOM (Byte Order Mark) at the top of the
    # file
    #
    $have_bom = Check_UTF8_BOM($csv_file);

    #
    # Create a document parser
    #
    $parser = csv_parser->new();
    if ( ! defined($parser) ) {
        print STDERR "Error: Failed to create CSV parser in Open_Data_CSV_Check_Data\n";
        return(@tqa_results_list);
    }

    #
    # Parse each line/record of the content
    #
    $eval_output = eval { $rows = $parser->getrow($csv_file); 1 };
    $line_no = 0;
    $parse_error_reported = 0;
    while ( $eval_output && defined($rows) ) {
        #
        # Increment record/line number
        #
        $line_no++;
        
        #
        # Get the set of fields from the parsed line/record
        #
        @fields = @$rows;
        print "Line # $line_no, field count " . scalar(@fields) . "\n" if $debug;

        #
        # Did we get an error ?
        #
        if ( ! $parser->status() ) {
            $line = $parser->error_input();
            $message = $parser->error_diag();
            print "CSV file error at line $line_no, line = \"$line\"\n" if $debug;
            print "parser->error_diag = \"$message\"\n" if $debug;
            Record_Result("OD_VAL", $line_no, 0, $line,
                          String_Value("Parse error in line") .
                          " \"$message\"");
            $parse_error_reported = 1;
            last;
        }

        #
        # Check each field to see if it is a multi-line fields with the
        # first line being either empty or containg white space only.
        # If the first line is white space, some spreadsheet programs
        # (e.g. Excel) may display the cell as being empty, leading the
        # user to believe there is no content in the cell.
        #
        $line = join(",",@fields);
        $field_count = @fields;
        for ($i = 0; $i < $field_count; $i++) {
            #
            # Split the field value on newline
            #
            @lines = split(/\n/, $fields[$i]);
            #print "Field # $i, value = \"" . $fields[$i] . "\"\n" if $debug;

            #
            # Do we have exactly 1 line in this field?
            #
            if ( @lines == 1 ) {
                #
                # Perform single-line field content checks
                #
                Check_Single_Line_Field($line, $line_no, $fields[$i],
                                        ($i + 1));
            }
            #
            # Do we have more than 1 line in this field?
            #
            elsif ( @lines > 1 ) {
                #
                # Perform multi-line field content checks
                #
                Check_Multi_Line_Field($line, $line_no, $fields[$i],
                                       ($i + 1), @lines);
            }
        }

        #
        # Is this the first row ? If so check for a possible heading
        # row (i.e. the field values are the dictionary terms)
        #
        if ( $line_no == 1 ) {
            @headings = Check_First_Data_Row($dictionary, @fields);

            #
            # Set the number of expected fields
            #
            print "Expected fields count = $field_count\n" if $debug;
            $data_file_object->attribute($column_count_attribute, $field_count);

            
            #
            # Initialize the blank/zero column flag. This is used to track
            # whether or not the column contains any non-blank/non-zero data.
            # Create csv_column objects to track the column content type,
            # and the number of non blank cells.
            #
            for ($i = 0; $i < $field_count; $i++) {
                $blank_zero_column_flag{$i} = 1;
                
                #
                # Do we have a column heading?
                #
                if ( defined($headings[$i]) ) {
                    $heading = $headings[$i];
                    $heading = $heading->term;
                }
                else {
                    $heading = "Column " . ($i + 1);
                }
                
                #
                # Create a column object
                #
                $column_object = csv_column_object->new($heading);
                push(@csv_columns, $column_object);
            }
            
            #
            # If we did find a heading row, skip to the next (data) row
            #
            if ( @headings > 0 ) {
                print "Have headings\n" if $debug;
                $eval_output = eval { $rows = $parser->getrow($csv_file); 1 };
                next;
            }
        }

        #
        # Check for a blank row, remove whitespace from content string.
        #
        $row_content = join("", @fields);
        $row_content =~ s/\s|\n|\r//g;
        if ( $row_content eq "" ) {
            Record_Result("OD_DATA", $line_no, 0, "$line",
                          String_Value("No content in row"));

            #
            # Get next line from the CSV file
            #
            $eval_output = eval { $rows = $parser->getrow($csv_file); 1 };
            next;
        }
        #
        # Does the field count match the expected number of fields ?
        #
        elsif ( $field_count != @fields ) {
            $found_fields = @fields;
            Record_Result("OD_DATA", $line_no, 0, "$line",
                          String_Value("Inconsistent number of fields, found") .
                          " $found_fields " . String_Value("expecting") .
                          " $field_count");
            if ( $debug ) {
               print "Field values are\n";
               $field_count = 0;
               foreach (@fields) {
                   $field_count++;
                   print " Field $field_count \"$_\"\n";
               }
            }

            #
            # Get next line from the CSV file
            #
            $eval_output = eval { $rows = $parser->getrow($csv_file); 1 };
            next;
        }
        #
        # Check data quality, content type and blank cells.
        # We don't do the checks for the first row in case it
        # is a heading row (and we have no data dictionary, so we
        # are unable to detect it as a heading row).
        #
        elsif ( $line_no > 1 ) {
            for ($i = 0; $i < $field_count; $i++) {
                #
                # Get the data value and the column object.
                #
                $data = $fields[$i];
                $column_object = $csv_columns[$i];
                
                #
                # Does this appear to be numeric data (integer)?
                #
                if ( $data =~ /^\s*\-?\d+\s*$/ ) {
                    if ( $column_object->type() eq "" ) {
                        $column_object->type("numeric");
                    }

                    #
                    # Add the current value to the column sum.
                    #
                    if ( $column_object->type() eq "numeric" ) {
                        $column_object->sum($data);
                    }
                }
                #
                # Does this appear to be numeric data (float)?
                #
                elsif ( $data =~ /^\s*\-?\d*\.\d+\s*$/ ) {
                    if ( $column_object->type() eq "" ) {
                        $column_object->type("numeric");
                    }

                    #
                    # Add the current value to the column sum.
                    #
                    if ( $column_object->type() eq "numeric" ) {
                        $column_object->sum($data);
                    }
                }
                #
                # Blank field, skip it.
                #
                elsif ( $data =~ /^[\s\n\r]*$/ ) {
                }
                #
                # Text field
                #
                else {
                    $column_object->increment_non_blank_cell_count();
                    $column_object->type("text");
                }
                print "Column data = \"$data\", type = " . $column_object->type() .
                      "\n" if $debug;
                
                #
                # If the cell is not blank, increment the non-blank count
                #
                if ( ! ($data =~ /^[\s\n\r]*$/) ) {
                    $column_object->increment_non_blank_cell_count();
                }

                #
                # Do we have a heading object for this field?
                #
                if ( defined($headings[$i]) ) {
                    $heading = $headings[$i];
                    $regex = $heading->regex();
                }
                else {
                    $regex = "";
                }
                
                #
                # Do we have a regular expression pattern for this heading ?
                #
                if ( $regex ne "" ) {
                    print "Check against regular expression $regex\n" if $debug;
                    if ( ! ($data =~ qr/$regex/) ) {
                        #
                        # Regular expression pattern fails
                        #
                        print "Regular expression failed for column $i, regex = $regex, data = $data\n" if $debug;
                        Record_Result("OD_DATA", $line_no, ($i + 1), "$line",
                                      String_Value("Data pattern") .
                                      " \"$regex\" " .
                                      String_Value("failed for value") .
                                      " \"$data\" " .
                                      String_Value("Column") . " \"" .
                                      $heading->term() . "\" (#" . ($i + 1) . ")");
                    }
                }
            }
        }
            
        #
        # Generate a checksum of the row content.
        #
        $checksum = md5_hex(encode_utf8(join("", @fields)));

        #
        # Have we seen this checksum before ? If so we have a duplicate
        # row of content.
        #
        print "Check for duplicate row, checksum = $checksum\n" if $debug;
        if ( defined($row_checksum{$checksum}) ) {
            Record_Result("OD_DATA", $line_no, 0, "$line",
                          String_Value("Duplicate row content, first instance at") .
                          " " . $row_checksum{$checksum});
        }
        else {
            #
            # Record this checksum and row number
            #
            $row_checksum{$checksum} = $line_no;
        }

        #
        # Check data cells for duplicate data.
        #
        # If we do not have any recognized headings (i.e. didn't hava a data
        # dictionary to check against) and this is row 1 of the CSV, we skip
        # checking for duplicate column content.  This row may be a heading row
        # and not a data row.  The heading row may not have duplicate column
        # values, but the subsequent data rows may have duplicates.  If we
        # include the possible heading row in the check we may miss the
        # duplicate data columns.
        #
        if ( ($line_no == 1) && (@headings == 0) ) {
            print "Skip field duplicates check for row 1 with no headings\n" if $debug;
        }
        else {
            print "Check for field duplicates\n" if $debug;
            for ($i = 0; $i < @fields; $i++) {
                #
                # Do we have any non-blank/non-zero data in this field ?
                # If so reset the blank column flag
                #
                if ( ($fields[$i] ne "") && ($fields[$i] ne "0") ) {
                    $blank_zero_column_flag{$i} = 0;
                }

                #
                # Do we have a value for the duplicate columns flag ?
                # If we don't, or it is true, we have not ruled out the
                # possibility that this column is a duplicate.
                #
                if ( (! defined($duplicate_columns_flag{$i})) ||
                     $duplicate_columns_flag{$i} ) {
                    #
                    # Get the current field value and a pointer to the
                    # hash table of which columns were previously found
                    # to be duplicates
                    #
                    print "Check for duplicates in row $line_no, column $i\n" if $debug;
                    $this_field = $fields[$i];
                    $duplicate_columns_ptr = $duplicate_columns{$i};

                    #
                    # Check this field against all other fields that come
                    # after it in the row (no need to check earlier fields as
                    # they would have checked against this field).
                    #
                    # Clear the duplicate column flag before the loop.  If a
                    # duplicate is found, the flag is reset.  If no duplicate
                    # is found we will not have to check this column again for
                    # any subsequent rows of data.
                    #
                    $duplicate_columns_flag{$i} = 0;
                    for ($j = $i + 1; $j < @fields; $j++) {
                        #
                        # Do we have a list of columns that are duplicates (from
                        # checks of previous rows)? If so, don't check the columns
                        # that previously were not duplicates (we have to have
                        # duplicate values for columns in every row).
                        #
                        print "Check for duplicates in row $line_no, column $i and $j\n" if $debug;
                        if ( (! defined($duplicate_columns_ptr)) ||
                             (defined($$duplicate_columns_ptr{$j})) ) {
                            #
                            # Do field values match ?
                            #
                            if ( $this_field eq $fields[$j] ) {
                                #
                                # Duplicate content in fields $i and $j
                                # Add this column number to the set of duplicate
                                # columns and set the duplicate columns flag for the
                                # main column being checked.
                                #
                                print "Duplicate content fields $i and $j\n" if $debug;
                                if ( ! defined($duplicate_columns_ptr) ) {
                                    my (%columns);
                                    $duplicate_columns_ptr = \%columns;
                                    $duplicate_columns{$i} = $duplicate_columns_ptr;
                                }
                                $$duplicate_columns_ptr{$j} = $j;
                                $duplicate_columns_flag{$i} = 1;
                            }
                        }
                    }
                }
            }
        }

        #
        # Get next line from the CSV file
        #
        $eval_output = eval { $rows = $parser->getrow($csv_file); 1 };
    }

    #
    # Did we get a runtime error ?
    #
    if ( (! $eval_output) && (! $parse_error_reported) ) {
        print STDERR "parser->getrow fail, eval_output = \"$@\"\n";
        print "parser->getrow fail, eval_output = \"$@\"\n" if $debug;
        Record_Result("OD_VAL", $line_no, 0, $line,
                      String_Value("Parse error in line") .
                      " \"$@\"");
    }
    #
    # Did we get an error on the last line ?
    #
    elsif ( defined($parser) && (! $parser->eof()) && (! $parser->status()) &&
            (! $parse_error_reported) ) {
        $line = $parser->error_input();
        $message = $parser->error_diag();
        print "CSV file error at end of CSV at line $line_no, line = \"$line\"\n" if $debug;
        print "parser->error_diag = \"$message\"\n" if $debug;
        Record_Result("OD_VAL", $line_no, 0, $line,
                      String_Value("Parse error in line") .
                      " \"$message\"");
    }
    #
    # Did we find any rows in the CSV content ?
    #
    elsif ( $line_no == 0 ) {
        Record_Result("OD_VAL", -1, 0, "", String_Value("No content in file"));
    }
    close($csv_file);
    
    #
    # Save the row count
    #
    $data_file_object->attribute($row_count_attribute, $line_no);
    
    #
    # Check columns for duplicates, only if we have at least 10 rows of data
    #
    if ( $line_no > 9 ) {
        undef $heading;
        for ($i = 0; $i < @fields; $i++) {
            #
            # Get heading, if we have defined headings.
            #
            if ( @headings > 0 ) {
                $heading = $headings[$i];
            }
            
            #
            # Does the column contain any non-blank/non-zero content ?
            # (the assumption is that a column could be blank and we don't
            # want to report duplicate columns if the columns are blank).
            #
            if ( defined($blank_zero_column_flag{$i}) && $blank_zero_column_flag{$i} ) {
                #
                # Skip this field for duplicates reporting
                #
                next;
            }

            #
            # Do we have a value for the duplicate columns flag and
            # is it true ?
            #
            if ( defined($duplicate_columns_flag{$i}) &&
                 $duplicate_columns_flag{$i} ) {
                #
                # This column has other columns with duplicate
                # content.
                #
                $duplicate_columns_ptr = $duplicate_columns{$i};
                
                #
                # Get column headings, if we have defined headings.
                #
                if ( @headings > 0 ) {
                    $duplicate_column_list = "\"" . $heading->term() .
                                             "\" (#" . ($i + 1) . ")";
                    $duplicate_column_list = join(", ", keys(%$duplicate_columns_ptr));
                    foreach $j (keys(%$duplicate_columns_ptr)) {
                        $other_heading = $headings[$j];
                        $duplicate_column_list .= ", \"" . $other_heading->term() .
                                                  "\" (#" . ($j + 1) . ")";
                    }
                }
                else {
                    #
                    # Just include column numbers in the message
                    #
                    $duplicate_column_list = "" . ($i + 1);
                    foreach $j (keys(%$duplicate_columns_ptr)) {
                        $duplicate_column_list .= ", " . ($j + 1);
                    }
                }
                print "Duplicate columns $duplicate_column_list\n" if $debug;
                Record_Result("OD_DATA", -1, $i + 1, "$line",
                              String_Value("Duplicate content in columns") .
                              " $duplicate_column_list");
            }
        }
    }
    
    #
    # Check data conditions for data columns
    #
    Run_CSV_Validator($this_url, $filename, $have_bom, @headings);
    
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
# Name: Open_Data_CSV_Check_Get_Headings_List
#
# Parameters: this_url - a URL
#
# Description:
#
#   This function returns the headings list found in the last CSV file
# analysed.
#
#***********************************************************************
sub Open_Data_CSV_Check_Get_Headings_List {
    my ($this_url) = @_;

    #
    # Check that the last URL process matches the one requested
    #
    if ( $this_url eq $current_url ) {
        print "Open_Data_CSV_Check_Get_Headings_List url = $this_url, headings list = $last_csv_headings_list\n" if $debug;
        return($last_csv_headings_list);
    }
    else {
        return("");
    }
}

#***********************************************************************
#
# Name: Open_Data_CSV_Check_Get_Row_Column_Counts
#
# Parameters: data_file_object - a data_file_object pointer
#
# Description:
#
#   This function returns the number of rows and columns
# found in a CSV file.
#
#***********************************************************************
sub Open_Data_CSV_Check_Get_Row_Column_Counts {
    my ($data_file_object) = @_;

    my ($rows, $columns) = (0, 0);

    #
    # Get the row and column coiunt attributes
    #
    $columns = $data_file_object->attribute($column_count_attribute);
    $rows = $data_file_object->attribute($row_count_attribute);
    return($rows, $columns);
}

#***********************************************************************
#
# Name: Open_Data_CSV_Check_Get_Column_Object_List
#
# Parameters: data_file_object - a data_file_object pointer
#
# Description:
#
#   This function returns the list of column objects for the specified
# data file object.
#
#***********************************************************************
sub Open_Data_CSV_Check_Get_Column_Object_List {
    my ($data_file_object) = @_;

    my ($column_list);

    #
    # Get the column list attribute
    #
    $column_list = $data_file_object->attribute($column_list_attribute);
    return($column_list);
}

#***********************************************************************
#
# Name: Open_Data_CSV_Compare_JSON_CSV
#
# Parameters: json_data - pointer to JSON-CSV data structure
#             json_url - URL of JSON-CSV data file
#             csv_url - URL of CSV data file
#             profile - testcase profile
#
# Description:
#
#   This function reads the CSV file and compares the data values
# in the CSV fields to the values in the JSON-CSV data structure.
# CSV and JSON-CSV versions of a data file are expected to have the
# same values.  The order of rows from the CSV file and the
# order of data array elements in the JSON-CSV are expected to match.
#
#***********************************************************************
sub Open_Data_CSV_Compare_JSON_CSV {
    my ($json_data, $json_url, $csv_url, $profile) = @_;
    
    my (@tqa_results_list, $resp_url, $resp, $filename, $csv_file);
    my ($have_bom, $parser, $eval_output, $rows, $line_no);
    my (@headings, $heading, $csv_value, $json_value, $data);
    my ($data_array_item, %json_csv_values, $i);
    
    #
    # Do we have a valid profile ?
    #
    print "Open_Data_CSV_Compare_JSON_CSV: Checking\nCSV URL $csv_url\nJSON-CSV URL $json_url\nprofile = $profile\n" if $debug;
    if ( ! defined($open_data_profile_map{$profile}) ) {
        print "Open_Data_CSV_Compare_JSON_CSV: Unknown CSV testcase profile passed $profile\n";
        return(@tqa_results_list);
    }

    #
    # Save URL in global variable
    #
    if ( ($json_url =~ /^http/i) || ($json_url =~ /^file/i) ) {
        $current_url = $json_url;
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
    # Get the JSON data file.
    #
    print "Open_Data_CSV_Compare_JSON_CSV: Get CSV URL $csv_url\n" if $debug;
    ($resp_url, $resp) = Crawler_Get_HTTP_Response($csv_url, "");

    #
    # Did we get the URL?
    #
    if ( defined($resp) && ($resp->is_success) ) {
        #
        # Get the name of the file contaning the content
        #
        $filename = $resp->header("WPSS-Content-File");
    }
    else {
        print "Error trying to get URL\n" if $debug;
        return(@tqa_results_list);
    }
    
    #
    # Open the CSV file for reading.
    #
    print "Open CSV file $filename\n" if $debug;
    open($csv_file, "$filename") ||
        die "Open_Data_CSV_Compare_JSON_CSV: Failed to open $filename for reading\n";
    binmode $csv_file;

    #
    # Check for UTF-8 BOM (Byte Order Mark) at the top of the
    # file
    #
    $have_bom = Check_UTF8_BOM($csv_file);

    #
    # Create a document parser
    #
    $parser = csv_parser->new();
    if ( ! defined($parser) ) {
        print STDERR "Error: Failed to create CSV parser in Open_Data_CSV_Compare_JSON_CSV\n";
        unlink($filename);
        return(@tqa_results_list);
    }
    
    #
    # Get the address of the data array from the JSON-CSV structure
    #
    print "Get address of data array from JSON-CSV\n" if $debug;
    $data = $$json_data{'data'};

    #
    # Parse each line/record of the content
    #
    $eval_output = eval { $rows = $parser->getrow($csv_file); 1 };
    $line_no = 0;
    while ( $eval_output && defined($rows) ) {
        #
        # Increment record/line number
        #
        $line_no++;
        
        #
        # Is this the first row? It is expected to be a header row.
        # Get the heading labels.
        #
        if ( $line_no == 1 ) {
            @headings = @$rows;
        }
        #
        # This is a data row.
        #
        else {
            #
            # Get the JSON-CSV data array item and the leaf nodes of the
            # item. The array is indexed starting at 0, and there is no
            # "heading" row, so we must reduce the CSV line number by 2 to
            # get the data array item.
            #
            print "Check CSV data row $line_no againstJSON-CSV array item " .
                  ($line_no - 2) . "\n" if $debug;
            $data_array_item = $$data[($line_no - 2)];
            %json_csv_values = Open_Data_JSON_Get_JSON_CSV_Leaf_Nodes($data_array_item,
                                                         "data", ($line_no - 2),
                                                         0);

            #
            # Check each CSV cell value in this row against the
            # corresponding JSON-CSV data array item
            #
            for ($i = 0; $i < @headings; $i++) {
                $csv_value = $$rows[$i];
                $heading = $headings[$i];
                
                #
                # Get the json_csv value.  We don't have to worry about a
                # missing field as that would have been checked in either the
                # open_data_json.pm module or the open_data_check.pm module.
                #
                if ( defined($json_csv_values{$heading}) ) {
                    #
                    # Do the values match?
                    #
                    if ( $csv_value ne $json_csv_values{$heading} ) {
                        print "Error: CSV and JSON-CSV values do not match\n" if $debug;
                        Record_Result("OD_DATA", $line_no, ($i + 1), "",
                                      String_Value("CSV and JSON-CSV values do not match for column") .
                                      " \"$heading\" (# " . ($i + 1) . ")\n" .
                                      " CSV      = \"" . $csv_value . "\"\n" .
                                      " JSON-CSV = \"" . $json_csv_values{$heading} . "\"\n" .
                                      " CSV URL = $csv_url\n JSON-CSV URL = $json_url" );
                    }
                }
            }
        }

        #
        # Get next line from the CSV file
        #
        $eval_output = eval { $rows = $parser->getrow($csv_file); 1 };
    }
    
    #
    # Return the list of testcase results
    #
    unlink($filename);
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
# Generate path the the csv-validator
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $csv_validator = ".\\bin\\csv-validator\\bin\\validate.bat";
} else {
    #
    # Not Windows.
    #
    $csv_validator = "$program_dir/bin/csv-validator/bin/validate";
}

#
# Return true to indicate we loaded successfully
#
return 1;

