#***********************************************************************
#
# Name:   open_data_csv.pm
#
# $Revision: 1773 $
# $URL: svn://10.36.148.185/WPSS_Tool/Open_Data/Tools/open_data_csv.pm $
# $Date: 2020-04-07 10:19:19 -0400 (Tue, 07 Apr 2020) $
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
#     Open_Data_CSV_Get_Content_Results
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
use url_check;

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
                  Open_Data_CSV_Get_Content_Results
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (%testcase_data, $results_list_addr, @content_results_list);
my (@paths, $this_path, $program_dir, $program_name, $paths);
my (%open_data_profile_map, $current_open_data_profile, $current_url);
my ($csv_validator, $last_csv_headings_list);
my ($leading_trailing_whitespace_count, $dollar_symbol_found);
my ($thousands_separator_found, $thousands_separator_count);
my ($dollar_symbol_count);

my ($max_error_message_string)= 2048;
my ($runtime_error_reported) = 0;

#
# Data file object attribute names
#
my ($column_count_attribute) = "Column Count";
my ($row_count_attribute) = "Row Count";
my ($column_list_attribute) = "Column List";

#
# Minimum percentage to report inconsistent column data type errors.
#
my ($min_consistent_type_percent) = 2.0;

#
# Minimum percentage of non blank cells used to determine column
# data type.
#
my ($min_non_blank_cell_percentage) = 10.0;

#
# Set of ASCII characters that are non-printable. Table is indexed
# by the decimal ASCII code value.
#
my (%non_printable_ascii) = (
    "9",  "Horizontal tab",
    "10", "Line feed",
    "11", "Vertical tab",
    "12", "Form feed",
    "13", "Carriage return",
    "129", "",
    "141", "",
    "143", "",
    "144", "",
    "157", "",
    "160", "Non-breaking space",
    "173", "Soft hyphen",
);

#
# Status values
#
my ($check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "All cells in column",           "All cells in column",
    "and",                           "and",
    "at line number",                "at line number",
    "Blank column header",           "Blank column header",
    "Cannot access URL",             "Cannot access URL",
    "Column",                        "Column",
    "CSV and JSON-CSV values do not match for column", "CSV and JSON-CSV values do not match for column",
    "csv-validator failed",          "csv-validator failed",
    "Currency value found",          "Currency value found",
    "Data pattern",                  "Data pattern",
    "Duplicate column header",       "Duplicate column header",
    "Duplicate content in columns",  "Duplicate content in columns",
    "Duplicate row content, first instance at", "Duplicate row content, first instance at row",
    "Empty line as first line of multi-line field", "Empty line as first line of multi-line field",
    "Expected a heading after 2 blank lines", "Expected a heading after 2 blank lines",
    "expecting",                     "expecting",
    "expecting values to be of type", "expecting values to be of type",
    "failed for value",              "failed for value",
    "Field length",                  "Field length",
    "field value",                   "field value",
    "First instance at",             "First instance at row",
    "found",                         "found",
    "Found an ordered list item in an unordered list", "Found an ordered list item in an unordered list",
    "Found an unordered list item in an ordered list", "Found an unordered list item in an ordered list",
    "Found at",                      "Found at",
    "Found at row",                  "Found at row",
    "have identical content",        "have identical content",
    "Heading must be a single line", "Heading must be a single line",
    "Inconsistent data type in column", "Inconsistent data type in column",
    "Inconsistent field values for column", "Inconsistent field values for column",
    "Inconsistent field values for related columns", "Inconsistent field values for related columns",
    "Inconsistent list item prefix, found", "Inconsistent list item prefix, found",
    "Inconsistent number of fields, found", "Inconsistent number of fields, found",
    "instances of currency values",  "instances of currency values",
    "instances of leading or trailing whitespace characters in field values", "instances of leading or trailing whitespace characters in field values",
    "instances of thousands separator values", "instances of thousands separator values",
    "Invalid URL found",             "Invalid URL found",
    "Leading or trailing whitespace characters in field value", "Leading or trailing whitespace characters in field value",
    "Leading or trailing whitespace characters in heading", "Leading or trailing whitespace characters in heading",
    "List item prefix character found for list of 1 item", "List item prefix character found for list of 1 item",
    "List item value",               "List item value",
    "Long numeric value may be truncated", "Long numeric value may be truncated",
    "Long text value may be truncated", "Long text value may be truncated.",
    "Missing header row or terms",   "Missing header row or terms",
    "Missing header row terms",      "Missing header row terms",
    "Missing list item prefix character", "Missing list item prefix character",
    "Missing UTF-8 BOM",             "Missing UTF-8 BOM",
    "More than 1 blank line between list items", "More than 1 blank line between list items",
    "Newline, return, formfeed or tab characters in heading", "Newline, return, formfeed or tab characters in heading",
    "No blank line between list items", "No blank line between list items",
    "No content in file",            "No content in file",
    "No content in row",             "No content in row",
    "Parse error in line",           "Parse error in line",
    "Possible Excel formula as field value", "Possible Excel formula as field value",
    "row",                           "row",
    "Runtime Error",                 "Runtime Error",
    "Scientific notation value found", "Scientific notation value found",
    "Thousands separator value found", "Thousands separator value found",
    "Total of",                      "Total of",
    "value",                         "value",
    "values of type",                "values of type",
    );

my %string_table_fr = (
    "All cells in column",           "Toutes les cellules dans la colonne",
    "and",                           "et",
    "at line number",                "au numéro de ligne",
    "Blank column header",           "En-tête de colonne vide",
    "Cannot access URL",             "Impossible d'accéder à l'URL",
    "Column",                        "Colonne",
    "CSV and JSON-CSV values do not match for column", "Les valeurs CSV et JSON-CSV ne correspondent pas à la colonne",
    "csv-validator failed",          "csv-validator a échoué",
    "Currency value found",          "Valeur monétaire trouvée",
    "Data pattern",                  "Modèle de données",
    "Duplicate column header",       "En-tête de colonne en double",
    "Duplicate content in columns",  "Dupliquer le contenu dans les colonnes",
    "Duplicate row content, first instance at", "Dupliquer le contenu en ligne, première instance à ligne",
    "Empty line as first line of multi-line field", "Ligne vide comme première ligne de champ multi-lignes",
    "Expected a heading after 2 blank lines", "Attendu un en-tête après 2 lignes vides",
    "expecting",                     "expectant",
    "expecting values to be of type", "ettendant que les valeurs soient de type",
    "failed for value",              "a échoué pour la valeur",
    "Field length",                  "Longueur du champ",
    "field value",                   "valeurs de champ",
    "First instance at",             "Première instance à la rangée",
    "found",                         "trouver",
    "Found an ordered list item in an unordered list", "Trouver un élément de liste ordonnée dans une liste non ordonnée",
    "Found an unordered list item in an ordered list", "Trouver un élément de liste non ordonnée dans une liste ordonnée",
    "Found at",                      "Trouvé à",
    "Found at row",                  "Trouvé à la rangée",
    "have identical content",        "avoir un contenu identique",
    "Heading must be a single line", "Le titre doit être une seule ligne",
    "Inconsistent data type in column", "Type de données incohérent dans la colonne",
    "Inconsistent field values for column", "Valeurs de champ incohérentes pour la colonne",
    "Inconsistent field values for related columns", "Valeurs de champ incohérentes pour les colonnes associées",
    "Inconsistent list item prefix, found", "Préfixe d'élément de liste incompatible, trouvé",
    "Inconsistent number of fields, found", "Numéro incohérente des champs, a constaté",
    "instances of currency values",  "instances de valeurs monétaires",
    "instances of leading or trailing whitespace characters in field values", "occurrences de caractères espaces avant ou arrière dans les valeurs de champ",
    "instances of thousands separator values", "instances de milliers séparateurs",
    "Invalid URL found",             "URL invalide trouvée",
    "Leading or trailing whitespace characters in field value", "Caractères d'espacement avant ou arrière dans la valeur du champ",
    "Leading or trailing whitespace characters in heading", "Caractères blancs avancés ou arrivant dans le titre",
    "List item value",               "Valeur de l'élément de liste",
    "List item prefix character found for list of 1 item", "Caractère de préfixe d'élément de liste trouvé pour la liste de 1 élément",
    "Long numeric value may be truncated", "La valeur numérique longue peut être tronquée",
    "Long text value may be truncated", "La longueur du texte peut être tronquée.",
    "Missing header row or terms",   "Ligne ou termes d'en-tête manquants",
    "Missing header row terms",      "Manquant termes de lignes d'en-tête",
    "Missing list item prefix character", "Caractère de préfixe d'élément de liste manquant",
    "Missing UTF-8 BOM",             "Manquant UTF-8 BOM",
    "More than 1 blank line between list items", "Plus d'une ligne vide entre les éléments de la liste",
    "Newline, return, formfeed or tab characters in heading", "Caractères de nouvelle ligne, de retour, de saut de page ou de tabulation dans l'en-tête",
    "No blank line between list items", "Pas de ligne vide entre les éléments de la liste",
    "No content in file",            "Aucun contenu dans fichier",
    "No content in row",             "Aucun contenu dans ligne",
    "Parse error in line",           "Parse error en ligne",
    "Possible Excel formula as field value", "Formule Excel possible en tant que valeur de champ",
    "row",                           "ligne",
    "Runtime Error",                 "Erreur D'Exécution",
    "Scientific notation value found", "Valeur de notation scientifique trouvée",
    "Thousands separator value found", "Valeur de séparateur en milliers trouvée",
    "Total of",                      "Total de",
    "value",                         "valeur",
    "values of type",                "valeurs de type",
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
    
    my ($type, $value);

    #
    # Is this data for the minimum percentage for checking data type
    # consistency ?
    #
    if ( $testcase eq "TP_PW_OD_CONT" ) {
        ($type, $value) = split(/\s/, $data, 2);

        #
        # Is this a minimum percentage ?
        #
        if ( defined($value) && ($type eq "DATA_TYPE_CONSISTENCY_PERCENT") ) {
            $min_consistent_type_percent = $value;
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
    @content_results_list = ();
    $leading_trailing_whitespace_count = 0;
    $dollar_symbol_found = 0;
    $dollar_symbol_count = 0;
    $thousands_separator_found = 0;
    $thousands_separator_count = 0;
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
# Name: Record_Content_Result
#
# Parameters: testcase - testcase identifier
#             line - line number
#             column - column number
#             text - text from tag
#             error_string - error string
#
# Description:
#
#   This function records the testcase result and stores it in the
# list of content errors.
#
#***********************************************************************
sub Record_Content_Result {
    my ( $testcase, $line, $column, $text, $error_string ) = @_;

    my ($result_object);

    #
    # Do we have a maximum number of errors to report and have we reached it?
    #
    if ( ($TQA_Result_Object_Maximum_Errors > 0) &&
         (@content_results_list >= $TQA_Result_Object_Maximum_Errors) ) {
        print "Skip reporting errors, maximum reached\n" if $debug;
        return;
    }

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
        push (@content_results_list, $result_object);

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
#             report_errors - flag to control reporting of heading errors
#             fields - list of field values
#
# Description:
#
#   This function checks the fields from the first row of SV file.
# It checks to see if the values match the terms found in the data
# dictionary.  If there is a match on 25% of the fields, a check is
# made to ensure all fields match data dictionary terms.
#
# The report_errors option controls the reporting of heading errors (e.g.
# duplicate headings). This may be suppressed if only heading objects
# are required.
#
#***********************************************************************
sub Check_First_Data_Row {
    my ($dictionary, $report_errors, @fields) = @_;

    my ($count, $field, @unmatched_fields, %headers, $field_num);
    my ($non_dict_term, $dictionary_object);
    my (@headings) = ();
    
    #
    # Do we have any dictionary terms ?
    #
    if ( keys(%$dictionary) == 0 ) {
        print "No dictionary terms to check for first row of CSV file\n" if $debug;
    }
    
    #
    # Count the number of terms found in the fields
    #
    print "Check for terms in first row of CSV file\n" if $debug;
    $count = 0;
    $field_num = 0;
    foreach $field (@fields) {
        #
        # Don't convert to lower case, terms are case sensitive.
        # Don't remove any leading or trailing whitespace.
        #
#        $field =~ s/^\s*//g;
#        $field =~ s/\s*$//g;

        #
        # Check to see if it matches a dictionary entry.
        #
        $field_num++;
        if ( defined($$dictionary{$field}) ) {
            print "Found term/field match for \"$field\"\n" if $debug;
            $count++;

            #
            # Do we have a duplicate header ?
            #
            if ( defined($headers{$field}) ) {
                if ( $report_errors ) {
                    Record_Result("OD_DATA", 1, $field_num, "",
                                  String_Value("Duplicate column header") .
                                  " \"$field\". " .
                                  String_Value("Found at") . " # " .
                                  $headers{$field} . " " .
                                  String_Value("and") . " # $field_num");
                }
            }
            else {
                #
                # Save header name
                #
                $headers{$field} = $field_num;
            }
        }
        #
        # Is the heading blank?
        #
        elsif ( $field =~ /^\s*$/ ) {
            if ( $report_errors ) {
                Record_Result("TP_PW_OD_DATA", 1, $field_num, "",
                              String_Value("Blank column header"));
            }
        }
        else {
            #
            # An unmatched field, save it for possible use later
            #
            push (@unmatched_fields, "$field");
            print "No dictionary value for column # $field_num value \"$field\"\n" if $debug;
        }
    }
    
    #
    # Did we find a matching term for each field ?
    #
    if ( $count == @fields ) {
        print "All fields match a term\n" if $debug;
    }
    #
    # Did we get a match on atleast 25% of the fields ? If so we expect
    # all the fields to match.
    #
    elsif ( $count >= (@fields / 4) ) {
        print "Found atleast 25% match on fields and terms\n" if $debug;
        if ( $report_errors ) {
            Record_Result("TP_PW_OD_DATA", 1, 0, "",
                          String_Value("Missing header row terms") .
                          " \"" . join(", ", @unmatched_fields) . "\"");
        }
    }
    else {
        #
        # Missing header row or no data dictionary terms defined
        #
        print "Found a match on fewer than 25% fields\n" if $debug;
        if ( $report_errors ) {
            #
            # Report error if we have a data dictionary but no terms matched
            # the field values.
            #
            if ( keys(%$dictionary) != 0 ) {
                Record_Result("TP_PW_OD_DATA", 1, 0, "",
                              String_Value("Missing header row or terms") .
                              " \"" . join(", ", @unmatched_fields) . "\"");
            }
        }
    }

    #
    # Create a list of dictionary objects for the headings.
    # Create temporary objects for headings that were not found
    # in the dictionary.
    #
    foreach $field (@fields) {
        if ( defined($$dictionary{$field}) ) {
            $dictionary_object = $$dictionary{$field};
            push(@headings, $dictionary_object);
            print "Add dictionary object to headings list for $field\n" if $debug;
            $dictionary_object->get_consistent_data_headings();
        }
        else {
            #
            # Create a new dictionary object and set it's in_dictionary
            # attribute to false.
            #
            $non_dict_term = open_data_dictionary_object->new();
            $non_dict_term->term($field);
            $non_dict_term->in_dictionary(0);
            push(@headings, $non_dict_term);
            print "Create temporary dictionary object for heading $field\n" if $debug;
        }
    }

    #
    # Check for leading or trailing whitespace in header row values.
    # Check for newline, return, formfeed or tab in heading values.
    #
    $count = 0;
    if ( $report_errors ) {
        foreach $field (@fields) {
            $count++;

            #
            # Check for newline, return, formfeed or tab
            #
            if ( ($field =~ /[\f\n\r\t]/) ) {
                $field =~ s/[\f\n\r\t]/*/g;
                Record_Result("TP_PW_OD_DATA", 1, $count, "",
                              String_Value("Newline, return, formfeed or tab characters in heading") .
                              " #$count \"$field\"");
            }
            #
            # Check for leading or trailing whitespace
            #
            elsif ( ($field =~ /^\s+/) || ($field =~ /\s+$/) ) {
                Record_Result("TP_PW_OD_DATA", 1, $count, "",
                              String_Value("Leading or trailing whitespace characters in heading") .
                              " #$count \"$field\"");
            }
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
        ($csvs_fh, $csvs_filename) = tempfile("WPSS_TOOL_OD_CSV_XXXXXXXXXX",
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
                ($temp_csv_fh, $csv_filename) = tempfile("WPSS_TOOL_OD_CSV_XXXXXXXXXX",
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
    my ($expect_heading, $item_label, $last_item_label);

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
            print "Blank line count $blank_line_count\n" if $debug;
            
            #
            # Were we expecting a heading? and was the previous line
            # non-blank? If so we have found our heading.
            #
            if ( $expect_heading && ($last_line ne "") ) {
                print "End of heading\n" if $debug;
                $expect_heading = 0;
            }
            #
            # If the blank line count is 2, we should expect a heading
            #
            elsif ( $blank_line_count == 2 ) {
                $expect_heading = 1;
                $in_list = 0;
                $list_type = "";
                $list_item_count = 0;
                $item_prefix = "";
                print "Expect a heading, end of any open list\n" if $debug;
            }
            
            #
            # Clear the last line of text
            #
            $last_line = "";
            next;
        }
        #
        # If we are in a list item, appeand this text to the list item
        #
        elsif ( $in_list_item ) {
            $list_item .= "\n$single_line";
            next;
        }
        #
        # Is this an unordered list item? (i.e. starts with a dash,
        # asterisk or bullet).
        #
        elsif ( $single_line =~ /^\s*([\-\*])\s+[^\s]+.*$/ ) {
            #
            # Get the list item label value
            #
            ($item_label) = $single_line =~ /^\s*([^\.\)]+)[\.\)]\s+.*$/io;

            #
            # Are we expecing a heading (previous 2 lines were blank)
            #
            if ( $expect_heading ) {
                print "Expecting a heading, found a list\n" if $debug;
                Record_Result("OD_DATA", $line_no, $field_number, $line,
                              String_Value("Expected a heading after 2 blank lines") .
                              " " . String_Value("at line number") .
                              " " . ($i + 1) . ". " .
                              String_Value("found") . " \"$single_line\"");

                #
                # Clear heading flag and go to next line
                #
                $expect_heading = 0;
            }
            
            #
            # Found an unordered list item, do we already have a list? and
            # is it ordered?
            #
            print "Found unordered list item\n" if $debug;
            if ( ($list_type ne "") && ($list_type eq "ordered") ) {
                print "Found an unordered list item in an ordered list\n" if $debug;
                Record_Result("OD_DATA", $line_no, $field_number, $line,
                              String_Value("Found an unordered list item in an ordered list") .
                              " " . String_Value("at line number") .
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
                                  " " . String_Value("at line number") .
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
                                  " " . String_Value("at line number") .
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
                ($single_line =~ /^\s*([A-Z][\.\)])\s+[^\s]+.*$/i) ||
                ($single_line =~ /^\s*([ivx]+[\.\)])\s+[^\s]+.*$/i) ) {
            #
            # Get the list item label value
            #
            ($item_label) = $single_line =~ /^\s*([^\.\)]+)[\.\)]\s+.*$/io;
            
            #
            # If this is a new list, get the expected label type
            #
            if ( $list_item_count == 0 ) {
                #
                # Get the list item prefix characters. Try numbered list first
                #
                $item_prefix = "";
                if ( $single_line =~ /^\s*(\d+[\.\)])\s+[^\s]+.*$/ ) {
                    #
                    # This a new list, the label should be 1
                    #
                    if ( $item_label == 1 ) {
                        $item_prefix = "digits";
                    }
                    else {
                        print "Number isn't 1 at beginning of list, assume this is not a list\n" if $debug;
                    }
                }
                #
                # Try roman numeral list.
                #
                elsif ( $single_line =~ /^\s*([ivx]+[\.\)])\s+[^\s]+.*$/ ) {
                    #
                    # This a new list, the label should be i
                    #
                    if ( uc($item_label) eq "I" ) {
                        $item_prefix = "roman";
                    }
                    else {
                        print "Number isn't i (roman 1) at beginning of list, assume this is not a list\n" if $debug;
                    }
                }
                #
                # Try lettered list.
                #
                elsif ( $single_line =~ /^\s*([A-Z][\.\)])\s+[^\s]+.*$/ ) {
                    #
                    # This a new list, the label should be A
                    #
                    if ( uc($item_label) eq "A" ) {
                        $item_prefix = "letters";
                    }
                    else {
                        print "Letter isn't A at beginning of list, assume this is not a list\n" if $debug;
                    }
                }
                print "List item prefix type is $item_prefix\n" if $debug;
            }

            #
            # Are we expecing a heading (previous 2 lines were blank)
            #
            if ( $expect_heading ) {
                #
                # If we detected the beginning of a list, report error.
                # If we did not detect the beginning of a list. assume
                # this is a heading that looks like a list item.
                #
                if ( $item_prefix ne "" ) {
                    print "Expecting a heading, found a list\n" if $debug;
                    Record_Result("OD_DATA", $line_no, $field_number, $line,
                                  String_Value("Expected a heading after 2 blank lines") .
                                  " " . String_Value("at line number") .
                                  " " . ($i + 1) . ". " .
                                  String_Value("found") . " \"$single_line\"");
                }
                
                #
                # Clear heading flag and go to next line
                #
                $expect_heading = 0;
                next;
            }

            #
            # Found an ordered list item, do we already have a list? and
            # is it unordered?
            #
            print "Found ordered list item\n" if $debug;
            if ( ($list_type ne "") && ($list_type eq "unordered") ) {
                print "Found an ordered list item in an unordered list\n" if $debug;
                Record_Result("OD_DATA", $line_no, $field_number, $line,
                              String_Value("Found an ordered list item in an unordered list") .
                              " " . String_Value("at line number") .
                              " " . ($i + 1) . ". " .
                              String_Value("List item value") . " \"$single_line\"");
                next;
            }
            elsif ( $list_type eq "" ) {
                $list_type = "ordered";
            }
            
            #
            # Is this item label greater than the previous label value
            #
            if ( $list_item_count > 1 ) {
                #
                # Check numeric list label
                #
                if ( ($item_prefix eq "digits") &&
                     ($item_label <= $last_item_label) ) {
                }
                #
                # Check lettered label
                #
                elsif ( ($item_prefix eq "letters") &&
                        (ord(uc($item_label)) <= ord(uc($last_item_label))) ) {
                }
            }

            #
            # Are we already inside a list? If so there should be
            # one blank line between list items
            #
            if ( $in_list ) {
                if ( $blank_line_count == 0 ) {
                    print "No blank line between list items\n" if $debug;
                    Record_Result("OD_DATA", $line_no, $field_number, $line,
                                  String_Value("No blank line between list items") .
                                  " " . String_Value("at line number") .
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
                                  " " . String_Value("at line number") .
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
            $last_item_label = $item_label;
            $expect_heading = 0;

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
            # Are we inside of a list ?
            #
            if ( $in_list ) {
                #
                # Not in a list item, but in a list.  The list has ended,
                # this text may be a heading or the beginning of a paragraph.
                #
                $in_list = 0;
                $list_type = "";
                $last_item_label = "";
                print "End of list encountered\n" if $debug;
            }
            #
            # Was the last line text also? If so we are inside a paragraph
            #
            elsif ( $last_line ne "" ) {
                #
                # Are we expecting a heading (previous 2 lines were blank)
                #
                if ( $expect_heading ) {
                    print "Expecting a heading, found a paragraph\n" if $debug;
                    Record_Result("OD_DATA", $line_no, $field_number, $line,
                                  String_Value("Heading must be a single line") .
                                  ", " . String_Value("found") .
                                  " \n\"$last_line\n$single_line\"\n" .
                                  String_Value("at line number") .
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
                          String_Value("at line number") .
                          " " . ($i + 1) . ". " .
                          String_Value("List item value") . " \"$single_line\"");
        }
    }
}

#***********************************************************************
#
# Name: Convert_Nonprintable_to_Hex
#
# Parameters: data - a string
#
# Description:
#
#   This function scans the supplied string and converts nonprintable
# characters (e.g. some character codes greater than 127) into hex codes
#
#***********************************************************************
sub Convert_Nonprintable_to_Hex {
    my ($data) = @_;
    
    my ($hex_str, $j, $ch, $hex_ch);
    
    #
    # Convert non-printable characters into their hex
    # code values so differences are visable.
    #
    $hex_str = "";
    foreach ($j = 0; $j < length($data); $j++) {
        $ch = substr($data, $j, 1);
        
        #
        # Is this character non-printable?
        #
        if ( defined($non_printable_ascii{ord($ch)}) ) {
            $hex_ch = sprintf("{0x%X}", ord($ch));
            $hex_str .= $hex_ch;
        }
        else {
            $hex_str .= $ch;
        }
    }
    
    #
    # Return the string
    #
    return($hex_str);
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
    my ($line, @fields, $line_no, $status, $field_count, $match);
    my ($csv_file, $csv_file_name, $rows, $message, $content, $data1, $data2);
    my ($row_content, $eval_output, @headings, $i, $regex, $heading, $data);
    my ($have_bom, %row_checksum, $checksum, $headings_count);
    my (%duplicate_columns, %duplicate_columns_flag, $j, $this_field);
    my ($duplicate_columns_ptr, $duplicate_column_list, $other_heading);
    my (%blank_zero_column_flag, $parse_error_reported, @lines);
    my (@csv_columns, $column_object, @previous_row, @identical_cell_content);
    my ($value_type_ptr, $value_type, $type_count, $this_type_count);
    my ($computed_value_type, $non_blank_line_count, $url_filename);
    my ($table_addr, $other_line_no, $type_line, $value_type_row_ptr);
    my ($type_value, $data_type, $value, $line, $column_label);
    my ($valid_heading, $lc_value, %headings_to_columns);
    my (@consistent_data_headings, $other_heading, $other_column, $other_data);
    my ($first_data, $first_other_data, $first_line, $resp_url, $resp);

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
        print "Check for multi-line cell content\n" if $debug;
        $line = join(",",@fields);
        $field_count = @fields;
        for ($i = 0; $i < $field_count; $i++) {
            #
            # Split the field value on newline
            #
            @lines = split(/\n/, $fields[$i]);
            #print "Field # $i, value = \"" . $fields[$i] . "\"\n" if $debug;

            #
            # Do we have more than 1 line in this field?
            #
            if ( @lines > 1 ) {
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
            print "Row #1, check for headings\n" if $debug;
            @headings = Check_First_Data_Row($dictionary, 1, @fields);

            #
            # Set the number of expected fields
            #
            print "Expected fields count = $field_count\n" if $debug;
            $data_file_object->attribute($column_count_attribute, $field_count);
            $headings_count = $field_count;
            
            #
            # Initialize the blank/zero column flag. This is used to track
            # whether or not the column contains any non-blank/non-zero data.
            # Create csv_column objects to track the column content type,
            # and the number of non blank cells.
            #
            for ($i = 0; $i < $field_count; $i++) {
                $blank_zero_column_flag{$i} = 1;
                $heading = $fields[$i];

                #
                # Are we missing a column heading?
                #
                if ( ! defined($$dictionary{$heading}) ) {
                    $heading = "Column " . ($i + 1);
                    $valid_heading = 0;
                }
                else {
                    $valid_heading = 1;
                }
                
                #
                # Create a column object
                #
                $column_object = csv_column_object->new($heading);
                $column_object->valid_heading($valid_heading);
                
                #
                # Create mapping of headings to column numbers
                #
                $headings_to_columns{$heading} = $i;

                #
                # If this is not a valid data dictionary heading,
                # record the value for the first data cell.  We
                # may not have a data dictionary to check headings
                # against, but we may still want to check CSV vs JSON-CSV
                # headings.
                #
                if ( ! $valid_heading ) {
                    $column_object->first_data($fields[$i]);
                }
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
        elsif ( $field_count != $headings_count ) {
            Record_Result("OD_DATA", $line_no, 0, "$line",
                          String_Value("Inconsistent number of fields, found") .
                          " $field_count " . String_Value("expecting") .
                          " $headings_count");
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
                # Do we have a heading object for this field?
                #
                if ( defined($headings[$i]) ) {
                    $heading = $headings[$i];
                    $regex = $heading->regex();
                    $column_label = $heading->term();
                    print "Have data dictionary heading \"$column_label\"\n" if $debug;
                }
                else {
                    undef($heading);
                    $regex = "";
                    $column_label = $column_object->first_data();
                }

                #
                # Is this the 2nd row in the CSV? If so set the
                # identical cell content flag and save the cell content
                #
                if ( $line_no == 2 ) {
                    $previous_row[$i] = $data;
                    $identical_cell_content[$i] = 1;
                }
                #
                # Has the cell content been identical for all previous rows?
                #
                elsif ( $identical_cell_content[$i] ) {
                    #
                    # Check to see if the content of this row's cell differs
                    # from the previous row. If it does not clear the
                    # identical cell content flag.
                    #
                    if ( $previous_row[$i] ne $data ) {
                        $identical_cell_content[$i] = 0;
                    }
                }

                #
                # Does this appear to be numeric data (integer or float)?
                #
                if ( ($data =~ /^\s*\-?\d+\s*$/) ||
                     ($data =~ /^\s*\-?\d*\.\d+\s*$/) ) {
                    $value_type = "numeric";
                    if ( $column_object->type() eq "" ) {
                        $column_object->type("numeric");
                    }

                    #
                    # Update sum, max and min values for column
                    #
                    if ( $column_object->type() eq "numeric" ) {
                        #
                        # Add the current value to the column sum.
                        #
                        $column_object->sum($data);

                        #
                        # Do we have a max value?
                        #
                        if ( ! defined($column_object->max()) ) {
                            $column_object->max($data);
                        }
                        #
                        # Is this value larger than the current maximum?
                        #
                        elsif ( $data > $column_object->max() ) {
                            $column_object->max($data);
                        }

                        #
                        # Do we have a min value?
                        #
                        if ( ! defined($column_object->min()) ) {
                            $column_object->min($data);
                        }
                        #
                        # Is this value smaller than the current minimum?
                        #
                        elsif ( $data < $column_object->min() ) {
                            $column_object->min($data);
                        }
                    }

                    #
                    # Increment the count of values
                    #
                    $column_object->increment_data_type_count($value_type, $data,
                                                              $line_no);
                }
                #
                # Does this appear to be date (YYYY-MM-DD)?
                #
                elsif ( $data =~ /^\s*\d\d\d\d\-\d\d\-\d\d\s*$/ ) {
                    $value_type = "date";
                    if ( $column_object->type() eq "" ) {
                        $column_object->type("date");
                    }

                    #
                    # Update sum, max and min values for column
                    #
                    if ( $column_object->type() eq "date" ) {
                        #
                        # Add the current value to the column sum.
                        #
                        $data1 = $data;
                        $data1 =~ s/\-//g;
                        $column_object->sum($data1);

                        #
                        # Do we have a max value?
                        #
                        if ( ! defined($column_object->max()) ) {
                            $column_object->max($data);
                        }
                        #
                        # Is this value larger than the current maximum?
                        #
                        else {
                            $data2 = $column_object->max();
                            $data2 =~ s/\-//g;
                            
                            if ( $data1 > $data2 ) {
                                $column_object->max($data);
                            }
                        }

                        #
                        # Do we have a min value?
                        #
                        if ( ! defined($column_object->min()) ) {
                            $column_object->min($data);
                        }
                        #
                        # Is this value smaller than the current minimum?
                        #
                        else {
                            $data2 = $column_object->min();
                            $data2 =~ s/\-//g;

                            if ( $data1 < $data2 ) {
                                $column_object->min($data);
                            }
                        }
                    }

                    #
                    # Increment the count of values
                    #
                    $column_object->increment_data_type_count($value_type, $data,
                                                              $line_no);
                }
                #
                # Does this appear to be a URL value (http or https)?
                #
                elsif ( URL_Check_Is_URL($data) ) {
                    $value_type = "url";
                    if ( $column_object->type() eq "" ) {
                        $column_object->type("url");
                    }
                    
                    #
                    # Are we checking content errors?
                    # If not, skip trying to get the URL.
                    #
                    # Skip URL checking since it can be time consuming
                    # for data files with a large number of URLs (e.g. contract
                    # history).
                    #
#                    if ( defined($$current_open_data_profile{"TP_PW_OD_CONT"}) ) {
                    if ( 0 ) {
                        #
                        # Check that the URL can be reached
                        #
                        print "Check URL $data\n" if $debug;
                        ($resp_url, $resp) = Crawler_Get_HTTP_Response($data, "");

                        #
                        # Was the URL valid?
                        #
                        if ( ! defined($resp) ) {
                            Record_Content_Result("TP_PW_OD_CONT", $line_no,
                                              ($i + 1), "$line",
                                              String_Value("Invalid URL found") .
                                              " \"$data\"");
                        }
                        #
                        # Did we fail to get the URL?
                        #
                        elsif ( ! $resp->is_success ) {
                            print "Error trying to get URL, error  = " .
                                  $resp->status_line . "\n" if $debug;
                             Record_Content_Result("TP_PW_OD_CONT", $line_no,
                                                  ($i + 1), "$line",
                                                  String_Value("Cannot access URL") .
                                                  " \"$data\"\n" . $resp->status_line);
                        }
                        #
                        # Got URL, clean up content file
                        #
                        else {
                            $url_filename = $resp->header("WPSS-Content-File");
                            if ( defined($url_filename) && ($url_filename ne "") ) {
                                unlink($url_filename);
                            }
                        }
                    }

                    #
                    # Increment the count of values
                    #
                    $column_object->increment_data_type_count($value_type, $data,
                                                              $line_no);
                }
                #
                # Blank field, skip it.
                #
                elsif ( $data =~ /^[\s\n\r]*$/ ) {
                    $value_type = "blank";
                }
                #
                # No recognized format, assume this is a text field
                #
                else {
                    $value_type = "text";
                    $column_object->type("text");

                    #
                    # Increment the count of values
                    #
                    $column_object->increment_data_type_count($value_type, $data,
                                                              $line_no);

                    #
                    # Check for possible currency value with leading or
                    # trailing dollar symbol.
                    #
                    if ( ($data =~ /^\$\s*\d+(\.\d+)$/) ||
                         ($data =~ /^\d+(\.\d+)\s*\$$/) ) {
                        #
                        # Have we already reported a currency value?
                        # Only report the first instance to avoid a, possibly,
                        # large number of errors.
                        #
                        print "Found currency value\n" if $debug;
                        if ( $dollar_symbol_found == 0 ) {
                            Record_Content_Result("TP_PW_OD_CONT", $line_no, ($i + 1), "$line",
                                                  String_Value("Currency value found") .
                                                  " \"$data\" " .
                                                  String_Value("Column") .
                                                  " \"$column_label\" (#" . ($i + 1) . ")");
                        }
                        $dollar_symbol_count++;
                    }

                    #
                    # Check for possible comma or space characters in numbers.
                    # This could be separators for thousands, millions, etc.
                    # e.g. 1,000 or 1 000.
                    #
                    if ( ($data =~ /^(\$){0,1}\s*\d+([, ]\d\d\d)+(\.\d+)*$/) ||
                         ($data =~ /^\d+([, ]\d\d\d)+(\.\d+)*\s*(\$){0,1}$/) ) {
                        #
                        # Have we already reported a thousands separator value?
                        # Only report the first instance to avoid a, possibly,
                        # large number of errors.
                        #
                        print "Found thousands separator value\n" if $debug;
                        if ( $thousands_separator_found == 0) {
                            Record_Content_Result("TP_PW_OD_CONT", $line_no, ($i + 1), "$line",
                                                  String_Value("Thousands separator value found") .
                                                  " \"$data\" " .
                                                  String_Value("Column") .
                                                  " \"$column_label\" (#" . ($i + 1) . ")");
                        }
                        $thousands_separator_count++;
                    }
                    
                    #
                    # Check for possible scientific notation value
                    # (e.g. 1.3e-005).
                    #
                    if ( $data =~ /^\d(\.\d+)?e(\-)?\d+$/ ) {
                        Record_Content_Result("TP_PW_OD_CONT", $line_no, ($i + 1), "$line",
                                              String_Value("Scientific notation value found") .
                                              " \"$data\" " .
                                              String_Value("Column") .
                                              " \"$column_label\" (#" . ($i + 1) . ")");
                    }
                }
                print "Column data = \"$data\", type = " . $column_object->type() . "\n" if $debug;
                
                #
                # If the cell is not blank, increment the non-blank count
                #
                if ( ! ($data =~ /^[\s\n\r]*$/) ) {
                    $column_object->increment_non_blank_cell_count();
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
                                      String_Value("Column") .
                                      " \"$column_label\" (#" . ($i + 1) . ")");
                    }
                }
                
                #
                # If this is a numeric value, check that the number of digits
                # does not exceed 255. The value may be truncated by
                # spreadsheet tools (e.g. Excel).
                #
                if ( ($value_type eq "numeric") && (length($data) > 255) ) {
                    Record_Content_Result("TP_PW_OD_CONT", $line_no, ($i + 1), "$line",
                                          String_Value("Long numeric value may be truncated") .
                                          " \"$data\" " .
                                          String_Value("Column") .
                                          " \"$column_label\" (#" . ($i + 1) . ")");
                }
                #
                # Check for leading - (minus sign) or + (plus sign) followed
                # by just digits or decimal point. This is not an Excel formula.
                #
                elsif ( $data =~ /^[+\-][\d\.]+$/i ) {
                    print "Ignore positive or negative number, not a formula\n" if $debug;
                }
                #
                # Check for leading =, - or + character followed by a letter
                # or parenthesis (ignore digits).  This may be interpreted by
                # Excel as a formula (e.g. =SUM(A1:F1)).
                #
                elsif ( $data =~ /^[=+\-][A-Z\d\(]+.*/i ) {
                    Record_Content_Result("TP_PW_OD_CONT", $line_no, ($i + 1), "$line",
                                          String_Value("Possible Excel formula as field value") .
                                          " \"$data\" " .
                                          String_Value("Column") .
                                          " \"$column_label\" (#" . ($i + 1) . ")");
                }
                #
                # Check for leading space followed by =, - or + character
                # followed by a letter, digit or parenthesis.  This is a
                # work around to prevent Excel from interpreting the value as
                # a formula (e.g. =SUM(A1:F1)). This is a valid case for
                # a single leading space character that should not be reported
                # as an error in the next check.
                #
                elsif ( $data =~ /^\s[=+\-][A-Z\d\(].*/i ) {
                    print "Ignore single leading whitespace in field that may be interpreted as a formula\n" if $debug;
                }
                #
                # Check for leading or trailing whitespace in the value.
                # This whitespace is unnecessary and should not be in
                # the value.
                #
                elsif ( ($data =~ /^\s+/) || ($data =~ /\s+$/) ) {
                    #
                    # Only record the first instance of the error as there
                    # may be many instances in the data.
                    #
                    if ( $leading_trailing_whitespace_count == 0 ) {
                        Record_Content_Result("TP_PW_OD_CONT", $line_no, ($i + 1), "$line",
                                              String_Value("Leading or trailing whitespace characters in field value") .
                                              " \"$data\" " .
                                              String_Value("Column") .
                                              " \"$column_label\" (#" . ($i + 1) . ")");
                    }
                    $leading_trailing_whitespace_count++;
                }

                #
                # Check for possible inconsistencies in the spacing,
                # punctuation or capitalization of text values.
                #
                if ( $value_type eq "text" ) {
                    #
                    # Check that the number of characters does not exceed
                    # 32767. The value may be truncated by spreadsheet
                    # tools (e.g. Excel).
                    #
                    if ( length($data) > 32767 ) {
                        Record_Content_Result("TP_PW_OD_CONT", $line_no, ($i + 1), "$line",
                                              String_Value("Long text value may be truncated") .
                                              " " . String_Value("Field length") .
                                              " " . length($data) . " " .
                                              String_Value("Column") .
                                              " \"$column_label\" (#" . ($i + 1) . ")");
                    }

                    #
                    # Remove leading/trailing whitespace as those are
                    # already reported and we want to avoid multiple
                    # errors for the same problem.
                    #
                    $data =~ s/^\s+//;
                    $data =~ s/\s+$//;

                    #
                    # Check consistency of this data in the column.
                    #
                    print "Check for inconsistent field values\n" if $debug;
                    ($match, $data1, $other_line_no) =
                           $column_object->check_consistent_value($data, $line_no);

                    #
                    # Did the values not match?
                    #
                    if ( ! $match ) {
                        Record_Content_Result("TP_PW_OD_CONT_CONSISTENCY", $line_no, ($i + 1), "$line",
                                              String_Value("Inconsistent field values for column") .
                                              " \"$column_label\" (#" . ($i + 1) . ")\n " .
                                              String_Value("found") . " \"" .
                                              Convert_Nonprintable_to_Hex($data) . "\"\n " .
                                              String_Value("expecting") . " \"" .
                                              Convert_Nonprintable_to_Hex($data1) . "\"\n " .
                                              String_Value("Found at row") . " $other_line_no");
                    }
                }
                
                #
                # Does this column have consistency requirements with other
                # columns (specified by consistent_data_heading tags in the
                # data dictionary).
                #
                if ( defined($heading) ) {
                    #
                    # Do we have headings that require consistent data values
                    # across rows?
                    #
                    @consistent_data_headings = $heading->get_consistent_data_headings();
                    if ( @consistent_data_headings > 0 ) {
                        print "Rows must have consistent data for headings \"" .
                              join(", ", @consistent_data_headings) . "\"\n" if $debug;

                        #
                        # Check to see if we have any of the consistent data
                        # headings.
                        #
                        foreach $other_heading (@consistent_data_headings) {
                            if ( defined($headings_to_columns{$other_heading}) ) {
                                $other_column = $headings_to_columns{$other_heading};
                                print "Have heading \"$other_heading\" in column $other_column\n" if $debug;
                                $other_data = $fields[$other_column];
                                
                                #
                                # Check consistency of this data and the other
                                # column's data.
                                #
                                print "Check for inconsistent multi-column field values\n" if $debug;
                                ($match, $first_data, $first_other_data, $first_line) =
                                     $column_object->check_consistent_multi_cell_value($data, $line_no, $other_heading, $other_data);

                                #
                                # Did the values not match?
                                #
                                if ( ! $match ) {
                                    Record_Content_Result("TP_PW_OD_CONT_COL_CONSISTENCY", $line_no, ($i + 1), "$line",
                                              String_Value("Inconsistent field values for related columns") .
                                              " \"$column_label\" (#" . ($i + 1) . ") " .
                                              String_Value("and") .
                                              " \"$other_heading\" (#" . ($other_column + 1) . ")\n " .
                                              String_Value("found") . " \"" .
                                              Convert_Nonprintable_to_Hex($data) . "\" " .
                                              String_Value("and") . " \"" .
                                              Convert_Nonprintable_to_Hex($other_data) . "\"\n " .
                                              String_Value("expecting") . " \"" .
                                              Convert_Nonprintable_to_Hex($first_data) . "\" " .
                                              String_Value("and") . " \"" .
                                              Convert_Nonprintable_to_Hex($first_other_data) . "\"\n " .
                                              String_Value("Found at row") . " $other_line_no");
                                }
                            }
                        }
                    }
                    else {
                        print "No consistent data headings defined\n" if $debug;
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
            Record_Content_Result("TP_PW_OD_CONT_DUP", $line_no, 0, "$line",
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
                if ( ($fields[$i] ne "") &&  ! ($fields[$i] =~ /^0(\.0+)?$/) ) {
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
    #
    # Perform some content checks
    #
    else {
        #
        # Check the percentage of blank cells in columns.  If the
        # percentage is very high, change the data value type to
        # unknown.
        #
        print "Check for high percentage of blank cells in columns\n" if $debug;
        for ($i = 0; $i < $field_count; $i++) {
            $column_object = $csv_columns[$i];
            if ( ! defined($column_object) ) {
                next;
            }
            $non_blank_line_count = $column_object->non_blank_cell_count();
            
            if ( ($non_blank_line_count * 100.0 / $line_no) < $min_non_blank_cell_percentage ) {
                print "Non blank cell count below acceptable percentage\n" if $debug;
                $column_object->type("");
            }
        }

        #
        # Check for identical content in all cells in each column.
        # Only check this if we have at least 10 rows of data
        #
        if ( $line_no > 9 ) {
            print "Check for identical content in columns\n" if $debug;
            for ($i = 0; $i < $field_count; $i++) {
                $column_object = $csv_columns[$i];
                if ( $identical_cell_content[$i] ) {
                    print "Column $i has identical content in all cells\n" if $debug;
                    
                    #
                    # Check for blank content or 0 or 0.0... content.  We
                    # allow columns of those values.
                    #
                    if ( ($previous_row[$i] =~ /^[\s\n\r]*$/) ||
                         ($previous_row[$i] =~ /^0(\.0+)?$/) ) {
                        print "Ignore blank or 0 column\n" if $debug;
                        next;
                    }
                    
                    #
                    # Get heading label
                    #
                    $heading = $headings[$i];
                    if ( defined($heading) ) {
                        $message = $heading->term();
                    }
                    elsif ( defined($column_object) ) {
                        $message = $column_object->first_data();
                    }
                    else {
                        $message = "";
                    }
                    
                    #
                    # Record error
                    #
                    Record_Content_Result("TP_PW_OD_CONT_DUP", -1, ($i + 1), "",
                                          String_Value("All cells in column") .
                                          " \"$message\" (#" . ($i + 1) . ") " .
                                          String_Value("have identical content") .
                                          " \"" . $previous_row[$i] . "\"");
                }
            }
        }

        #
        # Check that the content in a column is of a consistent type (e.g.
        # numeric, text, date, etc.).
        # Only check this if we have at least 100 rows of data
        #
        if ( $line_no > 99 ) {
            print "Check for content consistency in columns\n" if $debug;
            for ($i = 0; $i < $field_count; $i++) {
                #
                # Do we have a column object?
                #
                $column_object = $csv_columns[$i];
                if ( ! defined($column_object) ) {
                    next;
                }

                #
                # Get heading label
                #
                $heading = $headings[$i];
                if ( defined($heading) ) {
                    $message = $heading->term();
                    $regex = $heading->regex();
                }
                else {
                    $message = $column_object->first_data();
                    $regex = "";
                }

                #
                # Does this heading have content regular expression? If so
                # we don't check content consistency, the regular
                # expression should catch anomolies.
                #
                if ( $regex ne "" ) {
                    print "Column has content regular expression, skip consistency check\n" if $debug;
                    next;
                }
                
                #
                # Get the number of non blank lines. Use this for
                # checking the number of cells of a particular type.
                # Blank cells could match any type.
                #
                $non_blank_line_count = $column_object->non_blank_cell_count();
                
                #
                # Do we still have over 99 data items?
                #
                if ( $non_blank_line_count < 100 ) {
                    print "Skip data type consistency check for column $i, fewer than 99 values\n" if $debug;
                    next;
                }
                
                #
                # Determine the column type based on the most frequent
                # data value type. The initial type was determined from
                # type of the first row.
                #
                $computed_value_type = $column_object->type();
                ($type_count, $value, $line) = $column_object->get_data_type_details($computed_value_type);
                foreach $value_type ($column_object->get_data_types_list()) {
                    ($this_type_count, $value, $line) = $column_object->get_data_type_details($value_type);
                    if ( $this_type_count > $type_count ) {
                        $computed_value_type = $value_type;
                        $type_count = $this_type_count;
                    }
                }

                #
                # Check each data type to see if there are any significant
                # inconsistencies. Report a problem if a data type is less
                # than minimum percentage of all values.
                #
                foreach $value_type ($column_object->get_data_types_list()) {
                    #
                    # Is this value type less than 1% of all values?
                    #
                    ($type_count, $value, $line) = $column_object->get_data_type_details($value_type);
                    print "Value count for column $i type $value_type is $type_count\n" if $debug;
                    if ( ($type_count * 100.0 / $non_blank_line_count) < $min_consistent_type_percent ) {
                        #
                        # Record error
                        #
                        Record_Content_Result("TP_PW_OD_CONT_CONSISTENCY", -1, ($i + 1), "",
                                              String_Value("Inconsistent data type in column") .
                                              " \"$message\" (#" . ($i + 1) . ") " .
                                              String_Value("found") . " $type_count " .
                                              String_Value("values of type") .
                                              " $value_type " .
                                              String_Value("expecting values to be of type") .
                                              " $computed_value_type. " .
                                              String_Value("First instance at") .
                                              " $line, " .
                                              String_Value("field value") .
                                              " \"$value\"");
                    }
                }
            }
        }
    }
    
    #
    # Close the CSV file
    #
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
                # Skip this column for duplicates reporting
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
                Record_Content_Result("TP_PW_OD_CONT_DUP", -1, $i + 1, "",
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
    # Print out some details for this data file
    #
    if ( $debug ) {
        print "CSV details for $this_url\n";
        print "Data rows $line_no, columns $headings_count\n";
        for ($i = 1; $i < $headings_count; $i++) {
            $column_object = $csv_columns[$i];
            print "Column " . ($i + 1) . " heading " . $column_object->heading .
                  " type " . $column_object->type . " Non-blank cell count " .
                  $column_object->non_blank_cell_count . "\n";
        }
    }
    
    #
    # Did we find more than 1 instance of leading or trailing whitespace in
    # field values?
    #
    if ( $leading_trailing_whitespace_count > 1 ) {
        Record_Content_Result("TP_PW_OD_CONT", -1, -1, "",
                              String_Value("Total of") . " $leading_trailing_whitespace_count " .
                              String_Value("instances of leading or trailing whitespace characters in field values"));
    }
    
    #
    # Did we find more than 1 instance of currency values?
    #
    if ( $dollar_symbol_count > 1 ) {
        Record_Content_Result("TP_PW_OD_CONT", -1, -1, "",
                              String_Value("Total of") . " $dollar_symbol_count " .
                              String_Value("instances of currency values"));
    }

    #
    # Did we find more than 1 instance of thousands separator values?
    #
    if ( $thousands_separator_count > 1 ) {
        Record_Content_Result("TP_PW_OD_CONT", -1, -1, "",
                              String_Value("Total of") . " $thousands_separator_count " .
                              String_Value("instances of thousands separator values"));
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
#             dictionary - address of a hash table for data dictionary
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
    my ($json_data, $json_url, $csv_url, $profile, $dictionary) = @_;
    
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
            #
            # Get headings from the first row. Don't report errors
            # with heading values as this would already have been done
            # when the CSV file was initially validated.
            #
            @headings = Check_First_Data_Row($dictionary, 0, @$rows);
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
            print "Check CSV data row $line_no against JSON-CSV array item " .
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
# Name: Open_Data_CSV_Get_Content_Results
#
# Parameters: this_url - a URL
#
# Description:
#
#   This function runs the list of content errors found.
#
#***********************************************************************
sub Open_Data_CSV_Get_Content_Results {
    my ($this_url) = @_;

    my (@empty_list);

    #
    # Does this URL match the last one analysed by the
    # Open_Data_CSV_Check_Data function?
    #
    print "Open_Data_CSV_Get_Content_Results url = $this_url\n" if $debug;
    if ( $current_url eq $this_url ) {
        return(@content_results_list);
    }
    else {
        return(@empty_list);
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

