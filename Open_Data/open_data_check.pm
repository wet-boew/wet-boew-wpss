#***********************************************************************
#
# Name:   open_data_check.pm
#
# $Revision: 629 $
# $URL: svn://10.36.148.185/Open_Data/Tools/open_data_check.pm $
# $Date: 2017-12-12 15:02:51 -0500 (Tue, 12 Dec 2017) $
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
#     Open_Data_Check_Zip_Content
#     Open_Data_Check_Read_JSON_Description
#     Open_Data_Check_Dataset_Data_Files
#     Open_Data_Check_Get_Headings_List
#     Open_Data_Check_Get_Row_Column_Counts
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
use Archive::Zip qw(:ERROR_CODES);
use JSON::PP;

#
# Use WPSS_Tool program modules
#
use crawler;
use data_file_object;
use language_map;
use open_data_csv;
use open_data_json;
use open_data_testcases;
use open_data_txt;
use open_data_xml;
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
    @EXPORT  = qw(Set_Open_Data_Check_Language
                  Set_Open_Data_Check_Debug
                  Set_Open_Data_Check_Testcase_Data
                  Set_Open_Data_Check_Test_Profile
                  Open_Data_Check_Testcase_URL
                  Open_Data_Check_Read_URL_Help_File
                  Open_Data_Check
                  Open_Data_Check_Zip_Content
                  Open_Data_Check_Read_JSON_Description
                  Open_Data_Check_Dataset_Data_Files
                  Open_Data_Check_Get_Headings_List
                  Open_Data_Check_Get_Row_Column_Counts
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
my ($current_open_data_profile, $current_url, $results_list_addr);
my ($current_open_data_profile_name);
my (@supporting_doc_url, %expected_row_count, %first_url_count);
my (%expected_column_count);
my (@data_dictionary_file_name, @alternate_data_file_name);
my (@data_file_required_lang, %data_file_objects);

my ($max_error_message_string) = 2048;
my ($max_unzipped_file_size) = 0;

#
# Data file object attribute names (use the same names as used for
# CSV data files as in some cases we compare attributes between CSV
# and JSON data files)
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
    "and",                             "and",
    "API URL unavailable",             "API URL unavailable",
    "as found in",                     " as found in ",
    "Character encoding is not UTF-8", "Character encoding is not UTF-8",
    "Column count mismatch, found",    "Column count mismatch, found",
    "Column headings found in",        "Column headings found in",
    "Column sum mismatch for column",  "Column sum mismatch for column",
    "Column type mismatch for column", "Column type mismatch for column",
    "Data array item count",           "Data array item count",
    "Data array item count mismatch, found", "Data array item count mismatch, found",
    "Data array item field count",     "Data array item field count",
    "Data array item field count mismatch, found", "Data array item field count mismatch, found",
    "Dataset URL unavailable",         "Dataset URL unavailable",
    "Duplicate content checksum",      "Duplicate content checksum",
    "en",                              "English",
    "expecting",                       " expecting ",
    "Error in reading ZIP, status =",  "Error in reading ZIP, status =",
    "Fails validation",                "Fails validation",
    "for",                             "for",
    "found",                           "found",
    "fr",                              "French",
    "have",                            "have",
    "in",                              "in",
    "Inconsistent format and mime-type", "Inconsistent format and mime-type",
    "Invalid dataset description field type", "Invalid dataset description field type",
    "Invalid mime-type for API",       "Invalid mime-type for API",
    "Invalid mime-type for data dictionary", "Invalid mime-type for data dictionary",
    "Invalid mime-type for data file", "Invalid mime-type for data file",
    "Invalid mime-type for description", "Invalid mime-type for description",
    "Language specific dataset file count mismatch, found", "Language specific dataset file count mismatch, found",
    "Missing CSV data file format for JSON-CSV format", "Missing CSV data file format for JSON-CSV format",
    "Missing data array item fields",    "Missing data array item fields",
    "Missing dataset description field", "Missing dataset description field",
    "Missing dataset description file types", "Missing dataset description file types",
    "Missing required language data file", "Missing required language data file",
    "Multiple file types in ZIP",      "Multiple file types in ZIP",
    "Non blank cell count mismatch for column", "Non blank cell count mismatch for column",
    "Non blank cell count mismatch for JSON-CSV field/CSV column", "Non blank cell count mismatch for JSON-CSV field/CSV column",
    "Not equal to data column count",  "Not equal to data column count",
    "Not equal to data row count",     "Not equal to data row count",
    "Row count mismatch, found",       "Row count mismatch, found ",
    "Sum mismatch for numeric JSON-CSV field/CSV column", "Sum mismatch for numeric JSON-CSV field/CSV column",
    "Type mismatch for JSON-CSV field/CSV column", "Type mismatch for JSON-CSV field/CSV column",
    "Uncompressed file size exceeds expected maximum size", "Uncompressed file size exceeds expected maximum size",
);

#
# String table for error strings (French).
#
my %string_table_fr = (
    "and",                             "et",
    "API URL unavailable",             "URL du API disponible",
    "as found in",                     " que l'on trouve dans ",
    "Character encoding is not UTF-8", "L'encodage des caractères ne pas UTF-8",
    "Column count mismatch, found",    "Incompatibilité du comptage des colonnes, trouvée",
    "Column headings found in",        "Les en-têtes de colonne trouvés dans",
    "Column sum mismatch for column",  "Incompatibilité de somme de colonne pour la colonne",
    "Column type mismatch for column", "Incompatibilité du type de colonne pour la colonne",
    "Data array item count",           "Nombre d'éléments du tableau de données",
    "Data array item count mismatch, found", "L'incompatibilité du nombre d'éléments de tableau de données, trouvé",
    "Data array item field count",     "Nombre de champs de l'élément de données",
    "Data array item field count mismatch, found", "Le décalage du nombre de champs de l'élément de tableau de données n'a pas été trouvé",
    "Dataset URL unavailable",         "URL du jeu de données disponible",
    "Duplicate content checksum",      "Somme de contrôle en double",
    "en",                              "anglais",
    "expecting",                       " expectant ",
    "Error in reading ZIP, status =",  "Erreur de lecture fichier ZIP, status =",
    "Fails validation",                "Échoue la validation",
    "for",                             "pour",
    "found",                           "trouver",
    "fr",                              "français",
    "have",                            "avoir",
    "in",                              "dans",
    "Inconsistent format and mime-type", "Les valeurs de format et de type MIME sont incompatibles",
    "Invalid dataset description field type", "Invalide type de champ de description de données",
    "Invalid mime-type for API",       "Invalid type MIME pour API",
    "Invalid mime-type for data dictionary", "Invalid type MIME pour le dictionnaire de donnée",
    "Invalid mime-type for data file", "Invalid type MIME pour le jeu de donnée",
    "Invalid mime-type for description", "Invalid mime-type pour description",
    "Language specific dataset file count mismatch, found", "Décomposition du nombre de fichiers de dataset spécifique au langage trouvé",
    "Missing CSV data file format for JSON-CSV format", "Le format de fichier de données CSV manquant pour le format JSON-CSV",
    "Missing data array item fields",    "Champs d'élément du tableau de données manquant",
    "Missing dataset description field", "Champ de description de dataset manquant",
    "Missing dataset description file types", "Types de fichiers de description de jeu de données manquants",
    "Missing required language data file", "Fichier de données de langue requise manquant",
    "Multiple file types in ZIP",      "Plusieurs types de fichiers dans un fichier ZIP",
    "Non blank cell count mismatch for column", "Incompatibilité du nombre de cellules non vierges pour la colonne",
    "Non blank cell count mismatch for JSON-CSV field/CSV column", "Incompatibilité non vide de cellules pour JSON-CSV field / CSV column",
    "Not equal to data column count",  "Pas égal au nombre de colonnes de données",
    "Not equal to data row count",     "Pas égal au nombre de lignes de données",
    "Row count mismatch, found",       "Incompatibilité du nombre de lignes, trouvée",
    "Sum mismatch for numeric JSON-CSV field/CSV column", "Incompatibilité de somme pour la colonne numériques JSON-CSV / CSV",
    "Type mismatch for JSON-CSV field/CSV column", "Type incompatibilité pour le champ JSON-CSV / colonne CSV",
    "Uncompressed file size exceeds expected maximum size", "La taille du fichier non compressé dépasse la taille maximale prévue",
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
    Set_Data_File_Object_Debug($debug);
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
    
    my ($type, $value);
    
    #
    # Is this a URL pattern for supporting files ?
    #
    if ( $testcase eq "OD_VAL" ) {
        ($type, $value) = split(/\s/, $data, 2);

        #
        # Is this a supporting file URL pattern ?
        #
        if ( defined($value) && ($type eq "SUPPORT_URL") ) {
            #
            # Save pattern in list
            #
            push(@supporting_doc_url, $value);
        }
    }
    #
    # Is this name pattern for data dictionary or alternate format
    # data file?
    #
    if ( $testcase eq "OD_URL" ) {
        ($type, $value) = split(/\s/, $data, 2);

        #
        # An alternate format data file name pattern ?
        #
        if ( defined($value) && ($type eq "ALTERNATE_DATA_NAME") ) {
            #
            # Save pattern in list
            #
            push(@alternate_data_file_name, $value);
        }
        #
        # A data dictionary file name ?
        #
        elsif ( defined($value) && ($type eq "DICTIONARY_NAME") ) {
            #
            # Save name in list
            #
            push(@data_dictionary_file_name, $value);
        }
    }
    #
    # Maximum file size for unzipped files
    #
    elsif ( $testcase eq "TP_PW_OD_DATA" ) {
        ($type, $value) = split(/\s/, $data, 2);

        #
        # Is this a file size limit ?
        #
        if ( defined($value) && ($type eq "MAX_FILE_SIZE") ) {
            #
            # Save limit
            #
            $max_unzipped_file_size = $value;
        }
        #
        # A data file required language ?
        #
        elsif ( defined($value) && ($type eq "REQUIRED_LANG") ) {
            #
            # Save name in list
            #
            push(@data_file_required_lang, $value);
        }
    }
    else {
        #
        # Copy the data into the table
        #
        $testcase_data{$testcase} = $data;
    }

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
# Name: Check_Content_Encoding
#
# Parameters: filename - file containing content
#             data_file_object - a data file object pointer
#
# Description:
#
#   This function checks the character encoding of the URL content.
#
#***********************************************************************
sub Check_Content_Encoding {
    my ($filename, $data_file_object) = @_;

    my ($output, $content);

    #
    # Get some input from the file
    #
    if ( open(FH, $filename) ) {
        $content = <FH>;
        close(FH);

        #
        # Does the string look like UTF-8 ?
        #
        if ( eval { utf8::is_utf8($content); } ) {
            print "Check_Content_Encoding: UTF-8 content\n" if $debug;
            if ( defined($data_file_object) ) {
                $data_file_object->encoding("UTF-8");
            }
        }
        #
        # Try decoding it as UTF-8
        #
        elsif ( ! eval { decode('utf8', $content, Encode::FB_CROAK); 1} ) {
            #
            # Not UTF 8 content
            #
            $output =  eval { decode('utf8', $content, Encode::FB_WARN);};
            Record_Result("OD_ENC", 0, -1, "$output",
                          String_Value("Character encoding is not UTF-8"));
        }
    }
    else {
        print "Error: Check_Content_Encoding failed to open file $filename\n";
    }
}

#***********************************************************************
#
# Name: Check_Encoding
#
# Parameters: resp - HTTP response object
#             data_file_object - a data file object pointer
#             filename - file containing content
#
# Description:
#
#   This function checks the character encoding of the 
# HTTP::Response object and content.
#
#***********************************************************************
sub Check_Encoding {
    my ($resp, $data_file_object, $filename) = @_;

    #
    # Does the HTTP response object indicate the content is UTF-8
    #
    if ( ($resp->header('Content-Type') =~ /charset=UTF-8/i) ||
         ($resp->header('X-Meta-Charset') =~ /UTF-8/i) ) {
        print "Check_Encoding: UTF-8 content\n" if $debug;
        if ( defined($data_file_object) ) {
            $data_file_object->encoding("UTF-8");
        }
    }
}

#***********************************************************************
#
# Name: Check_Dictionary_URL
#
# Parameters: url - open data file URL
#             format - optional content format
#             resp - HTTP::Response object
#             filename - file containing content
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
    my ($url, $format, $resp, $filename, $dictionary) = @_;

    my ($result_object, @other_results, $header, $mime_type, $data_file_object);

    #
    # Data dictionary files are expected to be either XML or TXT
    # format.
    #
    print "Check_Dictionary_URL\n" if $debug;
    if ( defined($resp) &&  $resp->is_success ) {
        $header = $resp->headers;
        $mime_type = $header->content_type;
    }
    elsif ( ! $resp->is_success ) {
        #
        # Don't have a valid dataset URL
        #
        return;
    }
    else {
        #
        # Unknown mime-type
        #
        $mime_type = "";
    }

    #
    # Check for UTF-8 encoding
    #
    Check_Encoding($resp, $data_file_object, $filename);

    #
    # Is this a plain text file ?
    #
    if ( ($mime_type =~ /text\/plain/) ||
         ($format =~ /^txt$/i) ||
         ($url =~ /\.txt$/i) ) {
        #
        # Check plain text data dictionary
        #
        print "TXT data dictionary file\n" if $debug;
        @other_results = Open_Data_TXT_Check_Dictionary($url,
                                                        $current_open_data_profile_name,
                                                        $filename,
                                                        $dictionary);
    }
    #
    # Is this XML ?
    #
    elsif ( ($mime_type =~ /application\/xhtml\+xml/) ||
            ($mime_type =~ /application\/xml/) ||
            ($mime_type =~ /text\/xml/) ||
            ($format =~ /^xml$/i) ||
            ($url =~ /\.xml$/i) ) {
        #
        # Check XML data dictionary
        #
        print "XML data dictionary file\n" if $debug;
        @other_results = Open_Data_XML_Check_Dictionary($url,
                                                        $current_open_data_profile_name,
                                                        $filename,
                                                        $dictionary);
    }
    else {
        #
        # Unexpected mime-type for a dictionary.
        #
        Record_Result("OD_URL", -1, -1, "",
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

#***********************************************************************
#
# Name: Check_Resource_URL
#
# Parameters: url - open data file URL
#             format - optional content format
#             resp - HTTP::Response object
#             content - content pointer
#             dictionary - address of a hash table for data dictionary
#             checksum - file content checksum
#
# Description:
#
#   This function is a place holder for possible resource file checks.
#
#***********************************************************************
sub Check_Resource_URL {
    my ($url, $format, $resp, $content, $dictionary, $checksum) = @_;

    my ($header, $mime_type, $data_file_object);

    #
    # Get the mime-type of the resource file
    #
    print "Check_Resource_URL\n" if $debug;
    if ( defined($resp) &&  $resp->is_success ) {
        $header = $resp->headers;
        $mime_type = $header->content_type;
    }
    elsif ( ! $resp->is_success ) {
        #
        # Don't have a valid dataset URL
        #
        return;
    }
    else {
        #
        # Unknown mime-type
        #
        $mime_type = "";
    }

    #
    # Check for UTF-8 encoding
    #
    if ( ($mime_type =~ /text\/html/) ||
         ($format =~ /^html$/i) ||
         ($url =~ /\.html$/i) ||
         ($mime_type =~ /text\/plain/) ||
         ($format =~ /^txt$/i) ||
         ($url =~ /\.txt$/i) ||
         ($mime_type =~ /application\/xhtml\+xml/) ||
         ($mime_type =~ /application\/xml/) ||
         ($mime_type =~ /text\/xml/) ||
         ($format =~ /^xml$/i) ||
         ($url =~ /\.xml$/i) ) {
        Check_Encoding($resp, $data_file_object, $content);
        
        #
        # If we didn't get an encoding in the HTTP::Response object, check
        # the content.
        #
        if ( defined($data_file_object) && ($data_file_object->encoding() eq "") ) {
            Check_Content_Encoding($content, $data_file_object);
        }
    }
}

#***********************************************************************
#
# Name: Check_Data_File_URL
#
# Parameters: url - open data file URL
#             format - optional content format
#             resp - HTTP::Response object
#             filename - file containing content
#             dictionary - address of a hash table for data dictionary
#             checksum - file content checksum
#
# Description:
#
#   This function checks a data file.  It checks that 
#     - the content type is CSV, JSON or XML
#     - Some content specific checks
#
#***********************************************************************
sub Check_Data_File_URL {
    my ($url, $format, $resp, $filename, $dictionary, $checksum) = @_;

    my ($result_object, @other_results, $header, $mime_type, $base);
    my ($data_file_object, $lang);

    #
    # Data files are expected to be either XML or CSV
    # format.
    #
    print "Check_Data_File_URL\n" if $debug;
    if ( defined($resp) &&  $resp->is_success ) {
        $header = $resp->headers;
        $mime_type = $header->content_type;
    }
    elsif ( ! $resp->is_success ) {
        #
        # Don't have a valid dataset URL
        #
        return;
    }
    else {
        #
        # Unknown mime-type
        #
        $mime_type = "";
    }
    
    #
    # Get the language of the URL
    #
    $lang = URL_Check_GET_URL_Language($url);

    #
    # Is this a file name?
    #
    if ( ! -f "$filename" ) {
        print STDERR "Error: Path is not a file in Check_Data_File_URL\n";
        print STDERR " --> $filename\n";
        exit(1);
    }

    #
    # Is this a CSV file ?
    #
    if ( ($mime_type =~ /text\/x-comma-separated-values/) ||
         ($mime_type =~ /text\/csv/) ||
         ($format =~ /^csv$/i) ||
         ($url =~ /\.csv$/i) ) {
        #
        # CSV file type
        #
        $data_file_object = data_file_object->new($url, "CSV");

        #
        # Check for UTF-8 encoding
        #
        print "CSV data file\n" if $debug;
        Check_Encoding($resp, $data_file_object, $filename);

        #
        # Check CSV data file
        #
        @other_results = Open_Data_CSV_Check_Data($url, $data_file_object,
                                                  $current_open_data_profile_name,
                                                  $filename,
                                                  $dictionary);

    }
    #
    # Is this a JSON file ?
    #
    elsif ( ($mime_type =~ /application\/json/i) ||
            ($format =~ /^json$/i) ||
            ($url =~ /\.json$/i) ) {
        #
        # JSON file type
        #
        $data_file_object = data_file_object->new($url, "JSON");

        #
        # Check for UTF-8 encoding
        #
        Check_Encoding($resp, $data_file_object, $filename);

        #
        # Check JSON data file
        #
        print "JSON data file\n" if $debug;
        @other_results = Open_Data_JSON_Check_Data($url, $data_file_object,
                                                   $current_open_data_profile_name,
                                                   $filename,
                                                   $dictionary);
    }
    #
    # Is this XML ?
    #
    elsif ( ($mime_type =~ /application\/xhtml\+xml/) ||
            ($mime_type =~ /application\/xml/) ||
            ($mime_type =~ /text\/xml/) ||
            ($format =~ /^xml$/i) ||
            ($url =~ /\.xml$/i) ) {
        #
        # XML file type
        #
        $data_file_object = data_file_object->new($url, "XML");

        #
        # Check for UTF-8 encoding
        #
        Check_Encoding($resp, $data_file_object, $filename);

        #
        # Check XML data file
        #
        print "XML data file\n" if $debug;
        @other_results = Open_Data_XML_Check_Data($url,
                                                  $current_open_data_profile_name,
                                                  $filename,
                                                  $dictionary);
    }
    else {
        #
        # Unexpected mime-type for a data file.  If the mime type
        # is for a ZIP file, use the type from the file suffix to
        # report the error.
        #
        if ( ($mime_type =~ /application\/zip/) ) {
            ($base, $mime_type) = $url =~ /(.*)\.(.*)$/; 
        }
        Record_Result("OD_URL", -1, -1, "",
                      String_Value("Invalid mime-type for data file") .
                      " \"" . $mime_type . "\"");
    }

    #
    # Did we create a data file object ?
    #
    if ( defined($data_file_object) ) {
        #
        # Set data file object attributes and save it in a
        # table.
        #
        $data_file_object->lang($lang);
        $data_file_object->checksum($checksum);
        $data_file_objects{$url} = $data_file_object;
    }

    #
    # Add results from data file check into the complete results list.
    #
    foreach $result_object (@other_results) {
        push(@$results_list_addr, $result_object);
    }
}

#***********************************************************************
#
# Name: Check_Format_and_Mime_Type_File_Suffix
#
# Parameters: url - open data file URL
#             format - optional content format
#             resp - HTTP::Response object
#
# Description:
#
#   This function checks to see that if a format is specified
# that the mime-type is appropriate for the format.  The format
# is taken from the JSON description object for the dataset file.
# The mime-type is taken from the HTTP::Response object.
# Other checks (e.g. dictionary, data) look at either the format or
# mime-type or file suffix to determine the type of processing.  This
# function checks for consistency between the format, mime-type and
# file suffix.
#
#***********************************************************************
sub Check_Format_and_Mime_Type_File_Suffix {
    my ($url, $format, $resp, $filename, $dictionary) = @_;
    
    my ($result_object, $header, $mime_type, $consistent, $suffix);

    #
    # Get mime-type, if there is one.
    #
    print "Check_Format_and_Mime_Type_File_Suffix, format = $format\n" if $debug;
    if ( defined($resp) &&  $resp->is_success ) {
        $header = $resp->headers;
        $mime_type = $header->content_type;
    }
    else {
        #
        # Unknown mime-type
        #
        $mime_type = "";
    }
    print "Mime-type = $mime_type\n" if $debug;
    
    #
    # Get file suffix, if there is one
    #
    $suffix = $url;
    $suffix =~ s/^.*\.//g;

    #
    # Do we have a format and a mime-type ?
    #
    if ( ($format ne "") && ($mime_type ne "") ) {
        #
        # Check for format and mime-type consistency for CSV files
        #
        $consistent = 1;
        if ( $format =~ /^csv$/i ) {
            if ( ($mime_type =~ /text\/x-comma-separated-values/) ||
                 ($mime_type =~ /text\/csv/) ||
                 ($url =~ /\.csv$/i) ) {
                $consistent = 1;
            }
            else {
                $consistent = 0;
            }
        }
        #
        # Check for format and mime-type consistency for TXT files
        #
        elsif ( $format =~ /^txt$/i ) {
            if ( ($mime_type =~ /text\/plain/) ||
                 ($url =~ /\.txt$/i) ) {
                $consistent = 1;
            }
            else {
                $consistent = 0;
            }
        }
        #
        # Check for format and mime-type consistency for XML files
        #
        elsif ( $format =~ /^xml$/i ) {
            if ( ($mime_type =~ /application\/xhtml\+xml/) ||
                 ($mime_type =~ /application\/xml/) ||
                 ($mime_type =~ /text\/xml/) ||
                 ($url =~ /\.xml$/i) ) {
                $consistent = 1;
            }
            else {
                $consistent = 0;
            }
        }

        #
        # Check for mime-type and format consistency for CSV files
        #
        if ( ($mime_type =~ /text\/x-comma-separated-values/) ||
             ($mime_type =~ /text\/csv/) ||
             ($url =~ /\.csv$/i) ) {
            if ( $format =~ /^csv$/i ) {
                $consistent = 1;
            }
            else {
                $consistent = 0;
            }
        }
        #
        # Check for mime-type and format consistency for TXT files
        #
        elsif ( ($mime_type =~ /text\/plain/) ||
                ($url =~ /\.txt$/i) ) {
            if ( $format =~ /^txt$/i ) {
                $consistent = 1;
            }
            else {
                $consistent = 0;
            }
        }
        #
        # Check for mime-type and format consistency for XML files
        #
        elsif ( ($mime_type =~ /application\/xhtml\+xml/) ||
                ($mime_type =~ /application\/xml/) ||
                ($mime_type =~ /text\/xml/) ||
                ($url =~ /\.xml$/i) ) {
            if ( $format =~ /^xml$/i ) {
                $consistent = 1;
            }
            else {
                $consistent = 0;
            }
        }

        #
        # Did we find an inconsistency ?
        #
        if ( ! $consistent ) {
            print "Format, mime-type are inconsistent\n" if $debug;
            Record_Result("OD_URL", -1, -1, "",
                  String_Value("Inconsistent format, mime-type file suffix") .
                               " format = \"$format\"" .
                               " mime-type = \"$mime_type\"" .
                               " suffix = \"$suffix\"");
        }
    }
}

#***********************************************************************
#
# Name: Check_API_URL
#
# Parameters: url - open data API URL
#             resp - HTTP::Response object
#             filename - API content file
#
# Description:
#
#   This function checks an API URL.  It checks that 
#     - the content type is XML or JSON
#     - the content contains valid markup
#
#***********************************************************************
sub Check_API_URL {
    my ($url, $resp, $filename) = @_;

    my ($result_object, @other_results, $header, $mime_type, $data_file_object);

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
            #
            # JSON file type
            #
            $data_file_object = data_file_object->new($url, "JSON");
            $data_file_objects{$url} = $data_file_object;

            #
            # Check for UTF-8 encoding
            #
            Check_Encoding($resp, $data_file_object, $filename);

            #
            # Check JSON API
            #
            print "JSON API URL\n" if $debug;
            @other_results = Open_Data_JSON_Check_API($url, $data_file_object,
                                               $current_open_data_profile_name,
                                                      $filename);
        }
        #
        # Is this XML ?
        #
        elsif ( ($mime_type =~ /application\/xhtml\+xml/) ||
                ($mime_type =~ /application\/xml/) ||
                ($mime_type =~ /text\/xml/) ) {
            #
            # XML file type
            #
            $data_file_object = data_file_object->new($url, "XML");
            $data_file_objects{$url} = $data_file_object;

            #
            # Check for UTF-8 encoding
            #
            Check_Encoding($resp, $data_file_object, $filename);

            #
            # Check XML API
            #
            print "XML API URL\n" if $debug;
            @other_results = Open_Data_XML_Check_API($url,
                                                     $current_open_data_profile_name,
                                                     $filename);
        }
        else {
            #
            # Unexpected mime-type for API
            #
            Record_Result("OD_URL", -1, -1, "",
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
# Name: Is_Supporting_File
#
# Parameters: url - open data file URL
#             resp - HTTP::Response object
#
# Description:
#
#   This function checks to see if the supplied URL is a supporting
# file.  The URL is checked to see if it contains any of the supporting
# file URL patterns.
#
#***********************************************************************
sub Is_Supporting_File {
    my ($url, $resp) = @_;

    my ($found, $header, $mime_type, $pattern);

    #
    # Check URL for a match on supporting file names.
    #
    print "Is_Supporting_File\n" if $debug;
    $found = 0;
    foreach $pattern (@supporting_doc_url) {
        if ( $url =~ /$pattern/i ) {
            print "Found supporting file pattern \"$pattern\"\n" if $debug;
            $found = 1;
            last;
        }
    }

    #
    # If the URL does not match the support file pattern, check
    # the content.
    #
    if ( ! $found ) {
        #
        # Do we have any content ?
        #
        if ( defined($resp) &&  $resp->is_success ) {
            $header = $resp->headers;
            $mime_type = $header->content_type;

            #
            # If the mime-type is HTML, get the <title>
            #
        }
    }

    #
    # Check to see if the URL was found.
    #
    if ( (! defined($resp)) || ( ! $resp->is_success ) ) {
        #
        # Failed to get url
        #
        if ( defined($resp) ) {
            Record_Result("OD_URL", -1, -1, "",
                          String_Value("Dataset URL unavailable") .
                          " : " . $resp->status_line);
        }
        else {
            Record_Result("OD_URL", -1, -1, "",
                          String_Value("Dataset URL unavailable"));
        }
    }

    #
    # Return is-supporting-file status
    #
    return($found);
}

#***********************************************************************
#
# Name: Open_Data_Check
#
# Parameters: url - open data file URL
#             format - optional content format
#             profile - testcase profile
#             data_file_type - type of dataset file
#             resp - HTTP::Response object
#             filename - file containing content
#             dictionary - address of a hash table for data dictionary
#             checksum - file content checksum
#
# Description:
#
#   This function runs a number of Open Data checks on a Dataset URLs.
#  The checks depend on the data file type.
#    DICTIONARY - a data dictionary file
#    DATA - a data file
#    RESOURCE - a resource file
#    API - a data API
#
#***********************************************************************
sub Open_Data_Check {
    my ($url, $format, $profile, $data_file_type, $resp, $filename,
        $dictionary, $checksum) = @_;

    my (@tqa_results_list, $result_object, @other_results, $tcid, $file_size);
    my ($header, $mime_type);

    #
    # Do we have a valid profile ?
    #
    print "Open_Data_Check: profile = $profile, url = $url\n" if $debug;
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
    # Do we have a file to check or is the dataset file a broken link?
    #
    if ( (! defined($resp)) || (! $resp->is_success) ) {
        print "Broken link to dataset file\n" if $debug;
        if ( defined($resp) ) {
            Record_Result("OD_URL", -1, -1, "",
                          String_Value("Dataset URL unavailable") .
                          " : " . $resp->status_line);
        }
        else {
            Record_Result("OD_URL", -1, -1, "",
                          String_Value("Dataset URL unavailable"));
        }
        return(@tqa_results_list);
    }

    #
    # Check file size
    #
    if ( $filename ne "" ) {
        #
        # If this is part of a ZIP file, the size check is skipped as the
        # file is already compressed.
        #
        $header = $resp->headers;
        $mime_type = $header->content_type;
        if ( ($mime_type =~ /application\/zip/) ||
             ($url =~ /\.zip:.+$/i) ) {
            print "Skip size check, content is already compressed\n" if $debug;
        }
        #
        # Do we have a maximum file size limit?
        #
        elsif ( $max_unzipped_file_size == 0 ) {
            print "Skip size check, no maximum file size limit set\n" if $debug;
        }
        else {
            #
            # Get the size of the file
            #
            $file_size = -s "$filename";
            print "File size = $file_size\n" if $debug;
            
            #
            # Is the size greater than the expected maximum ?
            #
            if ( $file_size > $max_unzipped_file_size ) {
                Record_Result("TP_PW_OD_DATA", -1, -1, "",
                              String_Value("Uncompressed file size exceeds expected maximum size") .
                              " $file_size > $max_unzipped_file_size");
            }
        }
    }
    
    #
    # Is this a supporting file URL ?
    #
    if ( Is_Supporting_File($url, $resp) ) {
        #
        # Supporting file, no further checks required.
        #
        print "Supporting file URL\n" if $debug;
    }

    #
    # Is this a data dictionary file
    #
    elsif ( $data_file_type =~ /DICTIONARY/i ) {
        #
        # Check dictionary content
        #
        Check_Dictionary_URL($url, $format, $resp, $filename, $dictionary);
    }

    #
    # Is this an alternate format data file
    #
    elsif ( $data_file_type =~ /ALTERNATE_DATA/i ) {
        #
        # No additional checks are necessary
        #
        print "Alternate format data file\n" if $debug;
    }

    #
    # Is this a data file
    #
    elsif ( $data_file_type =~ /DATA/i ) {
        #
        # Check data content
        #
        Check_Data_File_URL($url, $format, $resp, $filename, $dictionary,
                            $checksum);
    }

    #
    # Is this a resource file
    #
    elsif ( $data_file_type =~ /RESOURCE/i ) {
        #
        # Check resource content
        #
        Check_Resource_URL($url, $format, $resp, $filename, $dictionary,
                           $checksum);
    }

    #
    # Is this a API URL
    #
    elsif ( $data_file_type =~ /API/i ) {
        #
        # Check API content
        #
        Check_API_URL($url, $resp, $filename);
    }
    
    #
    # Check format, mime-type and file suffix for consistency
    #
    Check_Format_and_Mime_Type_File_Suffix($url, $format, $resp);

    #
    # Add testcase help URL to results
    #
    print "Open_Data_Check results\n" if $debug;
    foreach $result_object (@tqa_results_list) {
        $tcid = $result_object->testcase();
        if ( defined(Open_Data_Check_Testcase_URL($tcid)) ) {
            $result_object->help_url(Open_Data_Check_Testcase_URL($tcid));
        }

        #
        # Print testcase information
        #
        if ( $debug ) {
            print "Testcase: $tcid\n";
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
# Name: Open_Data_Check_Zip_Content
#
# Parameters: url - open data file URL
#             profile - testcase profile
#             data_file_type - type of dataset file
#             resp - HTTP::Response object
#
# Description:
#
#   This function checks a ZIP file containing a number of open
# data files.  It checks to see that the ZIP archive is well formed,
# it then checks that all the files in the ZIP are the same type.
# It returns a reference to a Archive::Zip object as well as testcase
# results array.
#
#***********************************************************************
sub Open_Data_Check_Zip_Content {
    my ($url, $profile, $data_file_type, $resp) = @_;

    my (@tqa_results_list, $zip, $zip_file_name, $zip_status, $result_object);
    my (@members, $member_name, %file_types, $base, $suffix, $tcid);

    #
    # Do we have a valid profile ?
    #
    print "Open_Data_Check_Zip_Content: profile = $profile\n" if $debug;
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
    # Read the ZIP file content into the Archive:Zip object
    #
    print "Read ZIP file into Archive::Zip object\n" if $debug;
    $zip_file_name = $resp->header("WPSS-Content-File");
    $zip = Archive::Zip->new();
    $zip_status = $zip->read($zip_file_name);

    #
    # Did we read the ZIP successfully ?
    #
    if ( $zip_status != AZ_OK ) {
        print "Error reading archive, status = $zip_status\n" if $debug;
        undef($zip);
        Record_Result("OD_VAL", -1, -1, "",
                      String_Value("Error in reading ZIP, status =")
                       . " $zip_status");
    }
    else {
        #
        # Check that all members of the archive have the same file
        # type.
        #
        @members = $zip->memberNames();
        print "Zip members = \n" . join("\n", @members) . "\n" if $debug;
        foreach $member_name (@members) {
            #
            # Get file base and suffix
            #
            ($base, $suffix) = $member_name =~ /(.*)\.(.*)$/;
            if ( ! defined($suffix) ) {
                $suffix = "Unknown";
            }
            $file_types{$suffix} = 1;
        }

        #
        # Did we get more than 1 suffix ?
        #
        if ( keys(%file_types) > 1 ) {
            Record_Result("TP_PW_OD_DATA", -1, -1, "",
                          String_Value("Multiple file types in ZIP") . 
                          " \"" . join(", ", keys(%file_types)) . "\"");
        }
    }

    #
    # Add testcase help URL to results
    #
    print "Open_Data_Check_Zip_Content results\n" if $debug;
    foreach $result_object (@tqa_results_list) {
        $tcid = $result_object->testcase();
        if ( defined(Open_Data_Check_Testcase_URL($tcid)) ) {
            $result_object->help_url(Open_Data_Check_Testcase_URL($tcid));
        }

        #
        # Print testcase information
        #
        if ( $debug ) {
            print "Testcase: $tcid\n";
            print "  URL   = " . $result_object->url . "\n";
            print "  message  = " . $result_object->message . "\n";
            print "  source line  = " . $result_object->source_line . "\n";
        }
    }

    #
    # Return Archie:Zip object as list of testcase results
    #
    return($zip, @tqa_results_list);
}

#***********************************************************************
#
# Name: Check_Open_Data_Description_URL
#
# Parameters: url - URL of the dataset file
#             resp - HTTP::Response object
#             filename - JSON content file
#
#
# Description:
#
#   This function checks to see if the dataset URL is available
# and is encoded using UTF-8.
#
#***********************************************************************
sub Check_Open_Data_Description_URL {
    my ($url, $resp, $filename) = @_;

    my ($message, $data_file_object);

    #
    # Check unsuccessful GET operation
    #
    print "Check_Open_Data_Description_URL\n" if $debug;
    if ( ! defined($resp) || (! $resp->is_success) ) {
        #
        # Failed to get url
        #
        $message = String_Value("Dataset URL unavailable");
        if ( defined($resp) ) {
            $message .= " : " . $resp->status_line;
        }
        Record_Result("OD_URL", -1, -1, "", $message);
    }
    else {
        #
        # Check for UTF-8 encoding
        #
        Check_Encoding($resp, $data_file_object, $filename);
    }
}

#***********************************************************************
#
# Name: Read_JSON_Open_Data_Description
#
# Parameters: resp - HTTP::Response object
#             filename - JSON content file
#
#
# Description:
#
#   This function reads the open data JSON description object and
# extracts the dataset URLs.  It returns a hash table with the dataset
# URLs and dataset file types.
#
#***********************************************************************
sub Read_JSON_Open_Data_Description {
    my ($resp, $filename) = @_;

    my (%dataset_urls) = ();
    my ($ref, $result, $resources, $value, $url, $type, $name);
    my ($eval_output, $i, $ref_type, $format, $content, $line);
    my ($pattern, $alternate);
    my ($have_error) = 0;

    #
    # Open the JSON file
    #
    print "Read_JSON_Open_Data_Description, decode JSON content\n" if $debug;
    open(FH, $filename) ||
        die "Error: Read_JSON_Open_Data_Description failed to open file $filename\n";

    #
    # Read the JSON content
    #
    binmode FH;
    $content = "";
    while ( $line = <FH> ) {
        $content .= $line;
    }
    close(FH);
    
    #
    # Parse the content.
    #
    $eval_output = eval { $ref = decode_json($content); 1 } ;

    #
    # Did the parse fail ?
    #
    if ( ! $eval_output ) {
        print "JSON parse failed => $eval_output\n" if $debug;
        $eval_output =~ s/ at \S* line \d*$//g;
        Record_Result("OD_VAL", -1, 0, "$eval_output",
                      String_Value("Fails validation"));
        $have_error = 1;
    }

    #
    # Get the "result" field of the JSON object
    #
    if ( (! $have_error) && (! defined($$ref{"result"})) ) {
        #
        # Missing "result" field
        #
        Record_Result("OD_VAL", -1, -1, "",
                      String_Value("Missing dataset description field") .
                      " \"result\"");
        $have_error = 1;
    }
    else {
        print "Get the result field\n" if $debug;
        $result = $$ref{"result"};

        #
        # Is this a hash table ?
        #
        $ref_type = ref $result;
        if ( $ref_type ne "HASH" ) {
            Record_Result("OD_VAL", -1, -1, "",
                          String_Value("Invalid dataset description field type") .
                          " \"$ref_type\" " . String_Value("for") .
                          " \"result\"");
            $have_error = 1;
        }
    }

    #
    # Get the "resources" field from the result table
    #
    if ( (! $have_error) && (! defined($$result{"resources"})) ) {
        #
        # Missing "resources" field
        #
        Record_Result("OD_VAL", -1, -1, "",
                      String_Value("Missing dataset description field") .
                      " \"resources\"");
        $have_error = 1;
    }
    else {
        print "Get the resources field\n" if $debug;
        $resources = $$result{"resources"};

        #
        # Is this an array?
        #
        $ref_type = ref $resources;
        if ( $ref_type ne "ARRAY" ) {
            Record_Result("OD_VAL", -1, -1, "",
                          String_Value("Invalid dataset description field type") .
                          " \"$ref_type\" " . String_Value("for") .
                          " \"resources\"");
            $have_error = 1;
        }
    }

    #
    # Get the dataset file details
    #
    if ( ! $have_error ) {
        #
        # Get dataset files
        #
        $i = 1;
        print "Get dataset URLs\n" if $debug;
        foreach $value (@$resources) {
           if ( ref $value eq "HASH" ) {
               $type = $$value{"resource_type"};
               $format = $$value{"format"};
               $name = $$value{"name"};
               $url = $$value{"url"};
               print "Dataset URL # $i, type = $type, format = $format, url = $url\n" if $debug;
               $i++;
               
               #
               # Do we have a type, format and URL ?
               #
               if ( (! defined($type)) || ($type eq "") ) {
                    Record_Result("OD_VAL", -1, -1, "",
                                  String_Value("Missing dataset description field") .
                                  " \"type\"");
               }
               if ( (! defined($format)) || ($format eq "") ) {
                    Record_Result("OD_VAL", -1, -1, "",
                                  String_Value("Missing dataset description field") .
                                  " \"format\"");
               }
               if ( (! defined($url)) || ($url eq "") ) {
                    Record_Result("OD_VAL", -1, -1, "",
                                  String_Value("Missing dataset description field") .
                                  " \"url\"");
               }

               #
               # Save dataset URL based on type.
               #
               if ( $type eq "api" ) {
                   $dataset_urls{"API"} .= "$format\t$url\n";
               }
               elsif ( ($type eq "doc") || ($type eq "guide") ) {
                   #
                   # Accept TXT and XML formatted documents. Other formats are
                   # likely to be supporting documents, not data dictionaries.
                   #
                   if ( ($format eq "TXT") || ($format eq "XML") ) {
                       $dataset_urls{"DICTIONARY"} .= "$format\t$url\n";
                   }
                   #
                   # Is the format HTML, then assume it is a supporting document
                   #
                   elsif ( $format eq "HTML" ) {
                       $dataset_urls{"RESOURCE"} .= "$format\t$url\n";
                   }
                   #
                   # Check for name Data Dictionary or Dictionnaire de données
                   #
                   else {
                       foreach $pattern (@data_dictionary_file_name) {
                           if ( $name eq $pattern ) {
                               $dataset_urls{"DICTIONARY"} .= "$format\t$url\n";
                           }
                       }
                   }
               }
               elsif ( ($type eq "file") || ($type eq "dataset") ) {
                   #
                   # Check for possible alternate format data file
                   #
                   $alternate = 0;
                   foreach $pattern (@alternate_data_file_name) {
                       if ( $name =~ /$pattern/ ) {
                           $dataset_urls{"ALTERNATE_DATA"} .= "$format\t$url\n";
                           $alternate = 1;
                       }
                   }

                   #
                   # If the file is not an alternate format, it is a primary
                   # formate data file
                   #
                   if ( ! $alternate ) {
                      $dataset_urls{"DATA"} .= "$format\t$url\n";
                   }
               }
           }
        }
        
        #
        # Are there any data dictionaries specified in the
        # dataset files?
        #
        if ( ! defined($dataset_urls{"DICTIONARY"}) ) {
            Record_Result("TP_PW_OD_DATA", -1, -1, "",
                          String_Value("Missing dataset description file types") .
                          " \"Data Dictionary\"");
        }

        #
        # Are there any data files specified in the
        # dataset files?
        #
        if ( ! defined($dataset_urls{"DATA"}) ) {
            Record_Result("TP_PW_OD_DATA", -1, -1, "",
                          String_Value("Missing dataset description file types") .
                          " \"Dataset\"");
        }
    }

    #
    # Return hash table
    #
    return(\%dataset_urls);
}

#***********************************************************************
#
# Name: Open_Data_Check_Read_JSON_Description
#
# Parameters: url - open data JSON description URL
#             profile - testcase profile
#             resp - HTTP::Response object
#             filename - JSON content file
#             dataset_urls - address of hash table
#
# Description:
#
#   This function reads the JSON dataset description information from
# the supplied content.  It extracts the set of dataset URLs and
# creates a hash table of dataset URLs and their types (e.g. DATA,
# DICTIONARY, RESOURCE, API).  This function returns a testcase
# results list and updates a supplied hash table with dataset URLs
# and dataset file types.
#
#***********************************************************************
sub Open_Data_Check_Read_JSON_Description {
    my ($url, $profile, $resp, $filename, $dataset_urls) = @_;

    my (@tqa_results_list, $result_object, @other_results, $header);
    my ($mime_type);

    #
    # Do we have a valid profile ?
    #
    print "Open_Data_Check_Read_JSON_Description: profile = $profile\n" if $debug;
    if ( ! defined($open_data_profile_map{$profile}) ) {
        print "Unknown Open Data testcase profile passed $profile\n" if $debug;
        return(@tqa_results_list);
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
    # Do we have a file to check or is the dataset file a broken link?
    #
    if ( (! defined($resp)) || (! $resp->is_success) ) {
        print "Broken link to dataset file\n" if $debug;
        if ( defined($resp) ) {
            Record_Result("OD_URL", -1, -1, "",
                          String_Value("Dataset URL unavailable") .
                          " : " . $resp->status_line);
        }
        else {
            Record_Result("OD_URL", -1, -1, "",
                          String_Value("Dataset URL unavailable"));
        }
        return(@tqa_results_list);
    }

    #
    # Check that the URL is valid and has proper encoding
    #
    Check_Open_Data_Description_URL($url, $resp);

    #
    # Is the mime-type JSON ?
    #
    if ( defined($resp) &&  $resp->is_success ) {
        $header = $resp->headers;
        $mime_type = $header->content_type;

        #
        # Is the content type json ?
        #
        if ( $mime_type =~ /application\/json/i ) {
            $$dataset_urls = Read_JSON_Open_Data_Description($resp, $filename);
        }
        else {
            #
            # Unexpected mime-type for description URL
            #
            print "Invalid mime-type for description URL \"$mime_type\"\n" if $debug;
            Record_Result("OD_URL", -1, -1, "",
                          String_Value("Invalid mime-type for description")
                           . " \"" . $mime_type . "\"");
        }
    }

    #
    # Return testcase results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Check_Data_File_Languages
#
# Parameters: url_lang_map - hash table of data file URLs
#
# Description:
#
#   This function performs checks data files to see if there
# are language specific variants (e.g. English and French).  It
# checks to see that all required languages are present.
#
#***********************************************************************
sub Check_Data_File_Languages {
    my (%url_lang_map) = @_;

    my (@url_list, $list_item, $url, $eng_url);
    my ($expected_lang_count, $lang_count, $lang_item_addr);
    my (%url_file_langs, $url_lang, $url_lang3, $lang_string);

    #
    # Check each entry in the URL language map
    #
    print "Check_Data_File_Languages\n" if $debug;
    foreach $eng_url (sort(keys(%url_lang_map))) {
        #
        # How mang language versions of the URL do we have?
        #
        $lang_item_addr = $url_lang_map{$eng_url};
        $lang_count = @$lang_item_addr;
        $current_url = $eng_url;

        #
        # Do we have an expected language count? If it is not
        # defined, use this (the first) URL's count as the expected
        # count.
        #
        if ( ! defined($expected_lang_count) ) {
            $expected_lang_count = $lang_count;
        }
        #
        # Does the language count match the expected language count?
        #
        elsif ( $lang_count != $expected_lang_count ) {
            Record_Result("OD_URL", -1, -1, "",
                          String_Value("Language specific dataset file count mismatch, found") .
                          " $lang_count " .
                          String_Value("expecting") .
                          "$expected_lang_count\n" .
                          String_Value("have") . " " .
                          join(", ", @$lang_item_addr));
        }

        #
        # If we have more than 0 language variants, check for required languages.
        #
        if ( $lang_count > 0 ) {
            #
            # Get the language of the language map key.
            #
            $url_lang = URL_Check_GET_URL_Language($eng_url);

            #
            # If we got a language, check the languages for all versions
            #
            if ( $url_lang ne "" ) {
                #
                # Get the languages for all versions of the data file
                #
                print "Check required URL languages\n" if $debug;
                print "Have " . scalar(@$lang_item_addr) . " language variants\n" if $debug;
                %url_file_langs = ();
                $url_file_langs{$url_lang} = $eng_url;
                foreach $url (@$lang_item_addr) {
                    $url_lang = URL_Check_GET_URL_Language($url);
                    print "Got URL language $url_lang for $url\n" if $debug;
                    $url_file_langs{$url_lang} = $url;
                }

                #
                # Check for the required versions
                #
                foreach $url_lang (@data_file_required_lang) {
                    #
                    # Check for URL matching either 2 character language
                    # code or 3 character code.
                    #
                    $url_lang3 = ISO_639_2_Language_Code($url_lang);
                    if ( (! defined($url_file_langs{$url_lang})) &&
                         (! defined($url_file_langs{$url_lang3}))  ) {
                        #
                        # Convert language code into a string
                        #
                        if ( defined($$string_table{$url_lang}) ) {
                            $lang_string = $$string_table{$url_lang};
                        }
                        else {
                            $lang_string = $url_lang;
                        }
                        Record_Result("TP_PW_OD_DATA", -1, -1, "",
                              String_Value("Missing required language data file") .
                              " \"$lang_string\" " . String_Value("have") .
                              " $eng_url");
                    }
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_CSV_Data_File_Content
#
# Parameters: url_lang_map - hash table of data file URLs
#
# Description:
#
#   This function performs checks on CSV data files to see if there
# are language specific variants (e.g. English and French).  For each
# language variant of the CSV file, it checks the content
#   if row count is the same
#   if the column count is the same
#   if the column types (e.g. numeric, text) are the same
#   for numeric columns, if the sum of the content is the same
#
#***********************************************************************
sub Check_CSV_Data_File_Content {
    my (%url_lang_map) = @_;

    my (@url_list, $list_item, $url, $eng_url);
    my ($lang_count, $lang_item_addr, $lang_data_file_object);
    my ($data_file_object, $rows, $cols, $eng_rows, $eng_cols);
    my ($column_objects, $eng_column_objects);
    my ($col_obj, $eng_col_obj, $i);

    #
    # Check each entry in the URL language map
    #
    print "Check_CSV_Data_File_Content\n" if $debug;
    foreach $eng_url (sort(keys(%url_lang_map))) {
        #
        # Get the data file object
        #
        print "Checking English URL $eng_url\n" if $debug;
        if ( ! defined($data_file_objects{$eng_url}) ) {
            print "No data file object\n" if $debug;
            next;
        }

        #
        # See if this is a CSV data file
        #
        $data_file_object = $data_file_objects{$eng_url};
        if ( $data_file_object->type() ne "CSV" ) {
            #
            # Skip non-CSV file
            #
            print "Skip non-CSV file, type is " . $data_file_object->type() .
                  "\n" if $debug;
            next;
        }

        #
        # How many language versions of the URL do we have?
        #
        $lang_item_addr = $url_lang_map{$eng_url};
        $lang_count = @$lang_item_addr;
        
        #
        # Do we have more than 1 language?
        #
        if ( $lang_count < 2 ) {
            print "Skip check, only have $lang_count language versions\n" if $debug;
            next;
        }

        #
        # Get the row & column counts from the English URL
        #
        ($eng_rows, $eng_cols) = Open_Data_CSV_Check_Get_Row_Column_Counts($data_file_object);
        
        #
        # Get the column object list
        #
        $eng_column_objects = Open_Data_CSV_Check_Get_Column_Object_List($data_file_object);

        #
        # Now check all other language variants to see if the
        # row and column counts match
        #
        print "Check " . scalar(@$lang_item_addr) . " language variants\n" if $debug;
        foreach $url (@$lang_item_addr) {
            #
            # Get data file object for this URL
            #
            print "Check language variant $url\n" if $debug;
            $current_url = $url;
            if ( ! defined($data_file_objects{$url}) ) {
                next;
            }
            $lang_data_file_object = $data_file_objects{$url};
            ($rows, $cols) = Open_Data_CSV_Check_Get_Row_Column_Counts($lang_data_file_object);

            #
            # Get the column object list
            #
            $column_objects = Open_Data_CSV_Check_Get_Column_Object_List($lang_data_file_object);

            #
            # Compare this URL's row count to the English
            # URL's row count
            #
            # Skip row count check, the non-blank cell count check is a
            # better indicator of possible data errors.  Some data files
            # may include a name cell and fiscal year data cells. The
            # name may change in 1 language and not the other resulting
            # in more rows in one file.
            #
#            if ( $rows != $eng_rows ) {
#                Record_Result("OD_DATA", -1, -1, "",
#                              String_Value("Row count mismatch, found") .
#                              "$rows " . String_Value("in") . " $url\n" .
#                              String_Value("expecting") .
#                              $eng_rows . String_Value("as found in") .
#                              $eng_url);
#            }

            #
            # Compare this URL's column count to the English
            # URL's column count
            #
            if ( $cols != $eng_cols ) {
                Record_Result("OD_DATA", -1, -1, "",
                              String_Value("Column count mismatch, found") .
                              "$cols " . String_Value("in") . " $url\n" .
                              String_Value("expecting") .
                              $eng_cols . String_Value("as found in") .
                              $eng_url);
            }
            else {
                #
                # Number of columns match, now check the column types
                # (e.g. numeric, text) and number of non-blank cells.
                #
                for ($i = 0; $i < $cols; $i++) {
                    #
                    # Get the column objects
                    #
                    $eng_col_obj = $$eng_column_objects[$i];
                    $col_obj = $$column_objects[$i];
                    
                    #
                    # Do the column types match?
                    #
                    print "Column types for column $i, " .
                           $col_obj->type() . " and " .
                           $eng_col_obj->type() . "\n" if $debug;
                    if ( $col_obj->type() ne $eng_col_obj->type() ) {
                         Record_Result("OD_DATA", -1, -1, "",
                                      String_Value("Column type mismatch for column") .
                                      " " . $col_obj->heading() . " (" . ($i + 1) . ") \n" .
                                      String_Value("found") . " " . $col_obj->type() .
                                      " " . String_Value("in") . " $url\n" .
                                      String_Value("expecting") .
                                      $eng_col_obj->type() .
                                      String_Value("as found in") . $eng_url);
                    }
                    else {
                        #
                        # Do the number of non-blank cells match?
                        #
                        print "Column non-blank cell count for column $i, " .
                               $col_obj->non_blank_cell_count() . " and " .
                               $eng_col_obj->non_blank_cell_count() . "\n" if $debug;
                        if ( $col_obj->non_blank_cell_count() != $eng_col_obj->non_blank_cell_count() ) {
                            Record_Result("OD_DATA", -1, -1, "",
                                          String_Value("Non blank cell count mismatch for column") .
                                          " " . $col_obj->heading() . " (" . ($i + 1) . ") \n" .
                                          String_Value("found") . " " . $col_obj->non_blank_cell_count() .
                                          " " . String_Value("in") . " $url\n" .
                                          String_Value("expecting") .
                                          $eng_col_obj->non_blank_cell_count() .
                                          String_Value("as found in") . $eng_url);
                        }
                    }
                    
                    #
                    # Is this a numeric column type?
                    #
                    if ( $col_obj->type() eq "numeric" ) {
                        #
                        # Do the column sums match?
                        #
                        print "Column sum for column $i, " .
                               $col_obj->sum() . " and " .
                               $eng_col_obj->sum() . "\n" if $debug;
                        if ( $col_obj->sum() != $eng_col_obj->sum() ) {
                              Record_Result("OD_DATA", -1, -1, "",
                                            String_Value("Column sum mismatch for column") .
                                            " " . $col_obj->heading() . " (" . ($i + 1) . ") \n" .
                                            String_Value("found") . " " . $col_obj->sum() .
                                            " " . String_Value("in") . " $url\n" .
                                            String_Value("expecting") .
                                            $eng_col_obj->sum() .
                                            String_Value("as found in") . $eng_url);
                        }
                    }
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Compare_CSV_JSON_CSV_Data_File_Content
#
# Parameters: json_url - URL of JSON-CSV data file
#             csv_url - URL of CSV data file
#             dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function compares the attributes of a CSV file to a JSON-CSV.
# It checks that:
#  - the number of rows in the CSV matches the number of items in the JSON-CSV
#  - the number of JSON-CSV leaf nodes matches the CSV column count
#  - the JSON-CSV leaf node field names match the CSV column headings
#  - the type of data (e.g. numeric) for JSON-CSV fields matches the
#    type for the corresponding CSV column
#  - the sum of numeric field values for JSON-CSV fields matches the
#    sum for the corresponding CSV column
#  - the number of non-blank field values for JSON-CSV fields matches the
#    number of non-blank cells for the corresponding CSV column
#
#***********************************************************************
sub Compare_CSV_JSON_CSV_Data_File_Content {
    my ($json_url, $csv_url, $dictionary) = @_;

    my ($csv_data_file_object, $csv_rows, $csv_columns, $csv_columns_list);
    my ($content_error, $json_data_file_object, $items, $fields);
    my ($fields_list, $missing_csv_headings, $csv_heading, $json_field);
    my (%heading_match, $field, @other_results, $result_object, $json_data);

    #
    # Get the row/column(field) attributes for the JSON-CSV data file
    #
    print "Compare_CSV_JSON_CSV_Data_File_Content\n" if $debug;
    $json_data_file_object = $data_file_objects{$json_url};
    $items = $json_data_file_object->attribute($row_count_attribute);
    $fields = $json_data_file_object->attribute($column_count_attribute);
    $fields_list = $json_data_file_object->attribute($column_list_attribute);

    #
    # Get the row/column attributes for the CSV data file
    #
    $csv_data_file_object = $data_file_objects{$csv_url};
    $csv_rows = $csv_data_file_object->attribute($row_count_attribute);
    $csv_columns = $csv_data_file_object->attribute($column_count_attribute);
    $csv_columns_list = $csv_data_file_object->attribute($column_list_attribute);
    $content_error = 0;

    #
    # Decrement the CSV rows as we expect there to be a
    # header row.  The JSON-CSV file does not contain
    # a header row.
    #
    $csv_rows--;

    #
    # Compare CSV row count and JSON object item count
    #
    print "JSON-CSV items $items, CSV data rows $csv_rows\n" if $debug;
    if ( $items != $csv_rows ) {
        Record_Result("OD_DATA", -1, -1, "",
                      String_Value("Data array item count") .
                      " $items " . String_Value("in") .
                      " JSON-CSV $json_url\n" .
                      String_Value("Not equal to data row count") .
                      " $csv_rows " . String_Value("in") .
                      " CSV $csv_url");
        $content_error = 1;
    }

    #
    # Compare the CSV column count and the JSON object
    # item field count
    #
    print "JSON-CSV item fields $fields, CSV data columns $csv_columns\n" if $debug;
    if ( $fields != $csv_columns ) {
        Record_Result("OD_DATA", -1, -1, "",
                      String_Value("Data array item field count") .
                      " $fields " . String_Value("in") .
                      " JSON-CSV $json_url\n" .
                      String_Value("Not equal to data column count") .
                      " $csv_columns " . String_Value("in") .
                      " CSV $csv_url");
        $content_error = 1;
    }

    #
    # Check the CSV column headers against the leaf nodes of
    # the JSON-CSV.  The leaf nodes are expected to match the
    # column headers.
    #
    $missing_csv_headings = "";
    print "Check JSON-CSV field names against CSV column headings\n" if $debug;
    foreach $csv_heading (@$csv_columns_list) {
        #
        # Initialize matching flag
        #
        $heading_match{$csv_heading->heading()} = 0;
        print "Check for heading \"" . $csv_heading->heading() . "\"\n" if $debug;

        #
        # Check the JSON-CSV fields for a matching header.
        # There is no requirement that the order of the
        # JSON-CSV fields match the CSV headings.
        #
        undef($json_field);
        foreach $field (@$fields_list) {
            if ( $field->heading() eq $csv_heading->heading() ) {
                $heading_match{$csv_heading->heading()} = 1;
                $json_field = $field;
                print "JSON field found matching CSV heading\n" if $debug;
                last;
            }
        }

        #
        # Did we find the CSV column in the JSON object
        # field list?
        #
        if ( ! $heading_match{$csv_heading->heading()} ) {
            $missing_csv_headings .= "\"" . $csv_heading->heading() . "\" ";
            
            #
            # Skip subsequent column/field checks as we don't have a match
            #
            print "No CSV column/JSON-CSV field match, skip content checks\n" if $debug;
            next;
        }
        
        #
        # Compare column data type to JSON-CSV field type
        #
        print "Compare JSON-CSV field type " . $json_field->type() .
              " to CSV column type " . $csv_heading->type() . "\n" if $debug;
        if ( $json_field->type() ne $csv_heading->type() ) {
            Record_Result("OD_DATA", -1, -1, "",
                          String_Value("Type mismatch for JSON-CSV field/CSV column") .
                          " " . $json_field->heading() . "\n" .
                          String_Value("found") . " " . $json_field->type() .
                          " " . String_Value("in") . " $json_url\n" .
                          String_Value("expecting") .
                          $csv_heading->type() .
                          String_Value("as found in") . $csv_url);
        }
        else {
            #
            # Compare non-blank CSV column cell count to non-blank
            # JSON-CSV field count
            #
            print "Compare non-blank JSON-CSV field count " . $json_field->non_blank_cell_count() .
                  " to non-blank CSV cell count " . $csv_heading->non_blank_cell_count() . "\n" if $debug;
            if ( $json_field->non_blank_cell_count() != $csv_heading->non_blank_cell_count() ) {
                Record_Result("OD_DATA", -1, -1, "",
                              String_Value("Non blank cell count mismatch for JSON-CSV field/CSV column") .
                              " " . $json_field->heading() . "\n" .
                              String_Value("found") . " " . $json_field->non_blank_cell_count() .
                              " " . String_Value("in") . " $json_url\n" .
                              String_Value("expecting") .
                              $csv_heading->non_blank_cell_count() .
                              String_Value("as found in") . $csv_url);
            }

            #
            # Compare numeric CSV column sum to JSON-CSV field sum
            #
            if ( $json_field->type() eq "numeric" ) {
                print "Compare numeric JSON-CSV field sum " . $json_field->sum() .
                      " to numeric CSV cell sum " . $csv_heading->sum() . "\n" if $debug;
                if ( $json_field->sum() != $csv_heading->sum() ) {
                    Record_Result("OD_DATA", -1, -1, "",
                                  String_Value("Sum mismatch for numeric JSON-CSV field/CSV column") .
                                  " " . $json_field->heading() . "\n" .
                                  String_Value("found") . " " . $json_field->sum() .
                                  " " . String_Value("in") . " $json_url\n" .
                                  String_Value("expecting") .
                                  $csv_heading->sum() .
                                  String_Value("as found in") . $csv_url);
                }
            }
        }
    }

    #
    # Did we detect any missing CSV column headings?
    #
    if ( $missing_csv_headings ne "" ) {
        Record_Result("OD_DATA", -1, -1, "",
                      String_Value("Missing data array item fields") .
                      " $missing_csv_headings " . String_Value("in") .
                      " JSON-CSV $json_url\n" .
                      String_Value("Column headings found in") .
                      " CSV $csv_url");
        $content_error = 1;
    }

    #
    # Check the content of the JSON and CSV versions of
    # the data files. The JSON-CSV data array content is expected
    # to match the CSV content (i.e. rows in the same order).
    #
    if ( ! $content_error ) {
        #
        # Read the JSON content
        #
        $json_data = Open_Data_JSON_Read_Data($json_url);
        
        #
        # Compare the JSON data and the CSV data
        #
        @other_results = Open_Data_CSV_Compare_JSON_CSV($json_data, $json_url,
                                                        $csv_url,
                                                        $current_open_data_profile_name,
                                                        $dictionary);
        
        #
        # Merge the JSON-CSV and CSV data comparison results with
        # the main testcase results.
        #
        foreach $result_object (@other_results) {
            push (@$results_list_addr, $result_object);
        }
    }
}
#***********************************************************************
#
# Name: Check_JSON_CSV_Data_File_Content
#
# Parameters: url_list - address of list of urls
#             dictionary - address of a hash table for data dictionary
#             url_lang_map - hash table of data file URLs
#
# Description:
#
#   This function performs checks on JSON-CSV data files to see if there
# are language specific variants (e.g. English and French).  For each
# language variant of the CSV file, it checks the content
#   if the data array item count is the same
#   if the data array item field count is the same
# It also checks to see there is a CSV format for each JSON-CSV file
# (CSV is the primary formay, JSON-CSV is an alternate).  If both
# a CSV and JSON-CSV exist, it checks to see if the number of
# rows in the CSV matches the number of items in the JSON-CSV
# data array.
#
#***********************************************************************
sub Check_JSON_CSV_Data_File_Content {
    my ($url_list, $dictionary, %url_lang_map) = @_;

    my (@url_list, $list_item, $url, $eng_url, $format, $item);
    my ($lang_count, $lang_item_addr, $lang_data_file_object);
    my ($data_file_object, $items, $fields, $eng_items, $eng_fields);
    my ($col_obj, $eng_col_obj, $i, $csv_url, %url_map);
    my ($csv_data_file_object, $csv_rows, $json_data, $fields_list);
    my ($csv_columns, $csv_columns_list, %heading_match, $csv_heading);
    my ($json_field, $missing_csv_headings, $content_error);
    
    #
    # Create a hash table of all URLs
    #
    print "Check_JSON_CSV_Data_File_Content\n" if $debug;
    foreach $item (@$url_list) {
        #
        # The URL may include a format specifier (e.g. CSV)
        #
        ($format, $url) = split(/\t/, $item);
        if ( ! defined($url) ) {
            $url = $item;
        }

        #
        # Remove any trailing newline
        #
        $url =~ s/[\n\r]$//g;
        print "Add \"$url\" to url map\n" if $debug;
        $url_map{$url} = 1;
    }

    #
    # Check each entry in the URL language map
    #
    foreach $eng_url (sort(keys(%url_lang_map))) {
        #
        # Get the data file object
        #
        print "Checking English URL $eng_url\n" if $debug;
        if ( ! defined($data_file_objects{$eng_url}) ) {
            print "No data file object\n" if $debug;
            next;
        }

        #
        # See if this is a JSON-CSV data file
        #
        $data_file_object = $data_file_objects{$eng_url};
        if ( ($data_file_object->type() eq "JSON") &&
             ($data_file_object->format() eq "JSON-CSV") ) {
            #
            # Have JSON-CSV data file
            #
            print "Found JSON-CSV data file $eng_url\n" if $debug;
        }
        else {
            #
            # Skip non-JSON-CSV file
            #
            print "Skip non-JSON-CSV file, type is " . $data_file_object->type() .
                  " format is " . $data_file_object->format() ."\n" if $debug;
            next;
        }

        #
        # How many language versions of the URL do we have?
        #
        $lang_item_addr = $url_lang_map{$eng_url};
        $lang_count = @$lang_item_addr;

        #
        # Get the data array item and field counts from the English URL
        #
        $eng_items = $data_file_object->attribute($row_count_attribute);
        $eng_fields = $data_file_object->attribute($column_count_attribute);

        #
        # Now check all other language variants to see if the
        # data array item and field counts match
        #
        print "Check " . scalar(@$lang_item_addr) . " language variants\n" if $debug;
        foreach $url (@$lang_item_addr) {
            #
            # Get data file object for this URL
            #
            $current_url = $url;
            print "Check language variant $url\n" if $debug;
            if ( ! defined($data_file_objects{$url}) ) {
                next;
            }
            $lang_data_file_object = $data_file_objects{$url};
            $items = $lang_data_file_object->attribute($row_count_attribute);
            $fields = $lang_data_file_object->attribute($column_count_attribute);
            $fields_list = $lang_data_file_object->attribute($column_list_attribute);

            #
            # Compare this URL's data array item count to the English
            # URL's data array item count.  All language variants of the
            # data file are expected to have the same number of items.
            #
            print "Compare item count $items against expected count $eng_items\n" if $debug;
            if ( $items != $eng_items ) {
                Record_Result("OD_DATA", -1, -1, "",
                              String_Value("Data array item count mismatch, found") .
                              " $items " . String_Value("in") . " $url\n" .
                              String_Value("expecting") .
                              $eng_items . String_Value("as found in") .
                              $eng_url);
            }

            #
            # Compare this URL's data array item field count to the English
            # URL's data array item field count.  All language variants of the
            # data file are expected to have the same number of fields.
            #
            print "Compare item field count $fields against expected field count $eng_fields\n" if $debug;
            if ( $fields != $eng_fields ) {
                Record_Result("OD_DATA", -1, -1, "",
                              String_Value("Data array item field count mismatch, found") .
                              " $fields " . String_Value("in") . " $url\n" .
                              String_Value("expecting") .
                              $eng_fields . String_Value("as found in") .
                              $eng_url);
            }

            #
            # Do we have a CSV equivalent for this JSON-CSV ?
            #
            $csv_url = $url;
            $csv_url =~ s/\.json$/.csv/;
            print "Check for CSV url \"$csv_url\"\n" if $debug;
            if ( defined($url_map{$csv_url}) ) {
                #
                # Does the row count for the CSV match the data array count
                # for the JSON-CSV file?.  The CSV and the JSON-CSV are
                # expected to contain the same data, therefore the data row
                # count should match the item count.
                #
                print "Have CSV file for this JSON-CSV file\n" if $debug;
                if ( defined($data_file_objects{$csv_url}) ) {
                    Compare_CSV_JSON_CSV_Data_File_Content($url, $csv_url, $dictionary);
                }
            }
            else {
                #
                # Missing CSV version of data file
                #
                print "Missing CSV version of file\n" if $debug;
                Record_Result("TP_PW_OD_DATA", -1, -1, "",
                              String_Value("Missing CSV data file format for JSON-CSV format") .
                              " $url\n" . String_Value("expecting") . "$csv_url");
            }
        }
    }
}

#***********************************************************************
#
# Name: Open_Data_Check_Dataset_Data_Files
#
# Parameters: profile - testcase profile
#             url_list - address of list of urls
#             dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function performs checks on the dataset files as a
# collection.  It checks for
#  - language specific files (e.g. has a language suffix).
#  - the presence of a file for each language.
#  - consistent content in different formats of the same data file
#    (e.g. CSV and JSON).
#
#***********************************************************************
sub Open_Data_Check_Dataset_Data_Files {
    my ($profile, $url_list, $dictionary) = @_;

    my (@tqa_results_list, @url_list, $list_item, $format, $url, $eng_url);
    my (%url_lang_map, $lang_item_addr, $data_file_object, %file_checksums);
    my ($checksum);

    #
    # Do we have a valid profile ?
    #
    print "Open_Data_Check_Dataset_Data_Files profile = $profile\n" if $debug;
    if ( ! defined($open_data_profile_map{$profile}) ) {
        print "Unknown Open Data testcase profile passed $profile\n" if $debug;
        return(@tqa_results_list);
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

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
    # Process the list of URLs
    #
    foreach $list_item (@$url_list) {
        #
        # The URL may include a format specifier (e.g. CSV)
        #
        ($format, $url) = split(/\t/, $list_item);
        if ( ! defined($url) ) {
            $url = $list_item;
        }
        $url =~ s/[\s\n\r]*$//g;
        $url =~ s/^[\s\n\r]*//g;
        
        #
        # Skip empty item
        #
        if ( $url =~ /^$/ ) {
            next;
        }
            
        #
        # Get English version of this URL (assuming it has a
        # language component).
        #
        $eng_url = URL_Check_Get_English_URL($url);
        if ( $eng_url eq "" ) {
            $eng_url = $url;
        }
        print "URL = $url, English URL = $eng_url\n" if $debug;
            
        #
        # Save this URL in the url language map if it is not the
        # English URL.  The map is indexed by the English URL.
        #
        if ( ! defined($url_lang_map{$eng_url}) ) {
            my (@url_map_list) = ($url);
            $url_lang_map{$eng_url} = \@url_map_list;
            print "Create new language map indexed by $eng_url\n" if $debug;
        }
        else {
            #
            # Add this URL to the list of URLs
            #
            my ($url_map_list_addr);
            $url_map_list_addr = $url_lang_map{$eng_url};
            push(@$url_map_list_addr, $url);
            print "Add to language map indexed by $eng_url url $url\n" if $debug;
        }
        
        #
        # Get the data file object, if we have one
        #
        if ( defined($data_file_objects{$url}) ) {
            $data_file_object = $data_file_objects{$url};
            
            #
            # Get the checksum and see if we have already seen a file with
            # this checksum
            #
            $checksum = $data_file_object->checksum();
            if ( ($checksum ne "") && defined($file_checksums{$checksum}) ) {
                Record_Result("OD_DATA", -1, -1, "",
                              String_Value("Duplicate content checksum") .
                              " $checksum " . String_Value("in") .
                              "\n    $url\n" . String_Value("and") . " " .
                              $file_checksums{$checksum});
            }
            elsif ( $checksum ne "" ) {
                $file_checksums{$checksum} = $url;
                print "Save checksum $checksum for url $url\n" if $debug;
            }
            else {
                print "No checksum for url $url\n" if $debug;
            }
        }
        else {
            print "No data_file_object for url $url\n" if $debug;
        }
    }
    
    #
    # Check for matching language counts and required languages
    #
    Check_Data_File_Languages(%url_lang_map);
    
    #
    # Check CSV file content for rows/column matches and other content checks
    #
    Check_CSV_Data_File_Content(%url_lang_map);

    #
    # Check JSON-CSV file content for item/field matches and other content checks
    #
    Check_JSON_CSV_Data_File_Content($url_list, $dictionary, %url_lang_map);

    #
    # Return results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Open_Data_Check_Get_Headings_List
#
# Parameters: this_url - a URL
#
# Description:
#
#   This function returns the headings list found in the last CSV file
# analysed.
#
#***********************************************************************
sub Open_Data_Check_Get_Headings_List {
    my ($this_url) = @_;

    return(Open_Data_CSV_Check_Get_Headings_List($this_url));
}

#***********************************************************************
#
# Name: Open_Data_Check_Get_Row_Column_Counts
#
# Parameters: this_url - a URL
#
# Description:
#
#   This function returns the number of rows and columns
# found in the last CSV file analysed.
#
#***********************************************************************
sub Open_Data_Check_Get_Row_Column_Counts {
    my ($this_url) = @_;
    
    my ($data_file_object, $rows, $columns);
    
    #
    # Get data file object for this URL
    #
    if ( defined($data_file_objects{$this_url}) ) {
        $data_file_object = $data_file_objects{$this_url};
        ($rows, $columns) = Open_Data_CSV_Check_Get_Row_Column_Counts($data_file_object);
    }
        
    #
    # Return the row and column counts
    #
    return($rows, $columns);
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

