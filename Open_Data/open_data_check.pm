#***********************************************************************
#
# Name:   open_data_check.pm
#
# $Revision: 2022 $
# $URL: svn://10.36.148.185/WPSS_Tool/Open_Data/Tools/open_data_check.pm $
# $Date: 2021-05-04 08:28:17 -0400 (Tue, 04 May 2021) $
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
#     Open_Data_Check_Content
#     Open_Data_Check_Zip_Content
#     Open_Data_Check_Read_JSON_Description
#     Open_Data_Check_Dataset_Data_Files
#     Open_Data_Check_Dataset_Data_Files_Content
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
use File::Basename;
use DateTime;
use Encode qw(decode encode);
use HTML::Entities;

#
# Use WPSS_Tool program modules
#
use crawler;
use data_file_object;
use language_map;
use open_data_csv;
use open_data_json;
use open_data_marc;
use open_data_testcases;
use open_data_txt;
use open_data_xml;
use readability;
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
                  Open_Data_Check_Content
                  Open_Data_Check_Zip_Content
                  Open_Data_Check_Read_JSON_Description
                  Open_Data_Check_Dataset_Data_Files
                  Open_Data_Check_Dataset_Data_Files_Content
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
my (@content_results_list, $today_date_object);
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
# Required JSON description metadata fields that are optional when
# entered on the registry.gc.ca.
#
my (@required_json_description_metadata) = (
    "result:portal_release_date",
    "resources:date_published",
);

#
# TBS Quality Rating System configuration values
#
my ($maximum_flesch_kincaid) = -1;
my ($tbs_maintainer_email) = "";
my ($tbs_org_name) = "";

#
# Status values
#
my ($check_fail)       = 1;

#
# Mapping of frequency codes to values
#
my (%frequency_label) = (
    "as_needed", "as needed",
    "irregular", "irregular",
    "not_planned", "not planned",
    "P1D", "daily",
    "P0.33W", "two time a week",
    "P0.5W", "three times a week",
    "P1W", "weekly",
    "P2W", "every two weeks",
    "P1M", "monthly",
    "P2M", "every two months",
    "P3M", "quarterly",
    "P4M", "every four months",
    "P6M", "biannually",
    "P1Y", "annually",
    "P2Y", "every two years",
);

#
# Maximum number of days between update for frequency.
# Note: number is padded to allow for approximately 1.5
# intervals between updates.
# Numbers match those in the  TBS open data quality checks
# tool https://github.com/open-data/data
#
my (%frequency_inteval_days) = (
    "P1D",      2,
    "P0.33W",   9,
    "P0.5W",    9,
    "P1W",      9,
    "P2W",     18,
    "P0.5M",   45,
    "P1M",     45,
    "P2M",     75,
    "P3M",    113,
    "P4M",    150,
    "P6M",    225,
    "P1Y",    456,
    "P2Y",    913,
    "P3Y",   1369,
    "P4Y",   2281,
);

#
# String table for error strings.
#
my %string_table_en = (
    "and",                             "and",
    "API URL unavailable",             "API URL unavailable",
    "as found in",                     " as found in ",
    "Character encoding is not UTF-8", "Character encoding is not UTF-8",
    "column",                          "column",
    "Column count mismatch, found",    "Column count mismatch, found",
    "Column heading dictionary id mismatch for column", "Column heading dictionary id mismatch for column",
    "Column heading out of order",     "Column heading out of order",
    "Column headings found in",        "Column headings found in",
    "Column maximum mismatch for column", "Column maximum mismatch for column",
    "Column minimum mismatch for column", "Column minimum mismatch for column",
    "Column sum mismatch for column",  "Column sum mismatch for column",
    "Column type mismatch for column", "Column type mismatch for column",
    "Data array item count",           "Data array item count",
    "Data array item count mismatch, found", "Data array item count mismatch, found",
    "Data array item field count",     "Data array item field count",
    "Data array item field count mismatch, found", "Data array item field count mismatch, found",
    "Dataset not updated within expected number of days for frequency", "Dataset not updated within expected number of days for frequency",
    "Dataset URL unavailable",         "Dataset URL unavailable",
    "days since last update",          "days since last update",
    "Duplicate content checksum",      "Duplicate content checksum",
    "Duplicate resource URL",          "Duplicate resource URL",
    "en",                              "English",
    "expected at column",              "expected at column",
    "exceeds maximum",                 "exceeds maximum",
    "expecting",                       " expecting ",
    "Error in reading ZIP, status =",  "Error in reading ZIP, status =",
    "Fails validation",                "Fails validation",
    "Flesch-Kincaid score for English description", "Flesch-Kincaid score for English description",
    "for",                             "for",
    "for files",                       "for files",
    "for resource",                    "for resource",
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
    "Maintainer email address must not be", "Maintainer email address must not be",
    "Maintainer email address is invalid", "Maintainer email address is invalid",
    "Maintainer email address missing", "Maintainer email address missing",
    "Missing CSV data file format for JSON-CSV format", "Missing CSV data file format for JSON-CSV format",
    "Missing data array item fields",    "Missing data array item fields",
    "Missing dataset description field", "Missing dataset description field",
    "Missing dataset description file types", "Missing dataset description file types",
    "Missing or null dataset metadata field", "Missing or null dataset metadata field",
    "Missing or null dataset resource metadata field", "Missing or null dataset resource metadata field",
    "Missing required language data file", "Missing required language data file",
    "Multiple file types in ZIP",      "Multiple file types in ZIP",
    "No data dictionary in dataset",   "No data dictionary in dataset",
    "No data files in dataset",        "No data files in dataset",
    "No resources of type guide in dataset", "No resources of type 'guide' in dataset",
    "Non blank cell count mismatch for column", "Non blank cell count mismatch for column",
    "Non blank cell count mismatch for JSON-CSV field/CSV column", "Non blank cell count mismatch for JSON-CSV field/CSV column",
    "Not equal to data column count",  "Not equal to data column count",
    "Not equal to data row count",     "Not equal to data row count",
    "Only alternate format data files in dataset", "Only alternate format data files in dataset",
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
    "column",                          "colonne",
    "Column count mismatch, found",    "Incompatibilité du comptage des colonnes, trouvée",
    "Column heading dictionary id mismatch for column", "Incompatibilité d'ID de dictionnaire d'en-tête de colonne pour la colonne",
    "Column heading out of order",     "Titre de colonne dans le désordre",
    "Column headings found in",        "Les en-têtes de colonne trouvés dans",
    "Column maximum mismatch for column", "Les valeurs maximales de colonne ne correspondent pas pour la colonne",
    "Column minimum mismatch for column", "Les valeurs minimales de colonne ne correspondent pas pour la colonne",
    "Column sum mismatch for column",  "Incompatibilité de somme de colonne pour la colonne",
    "Column type mismatch for column", "Incompatibilité du type de colonne pour la colonne",
    "Data array item count",           "Nombre d'éléments du tableau de données",
    "Data array item count mismatch, found", "L'incompatibilité du nombre d'éléments de tableau de données, trouvé",
    "Data array item field count",     "Nombre de champs de l'élément de données",
    "Data array item field count mismatch, found", "Le décalage du nombre de champs de l'élément de tableau de données n'a pas été trouvé",
    "Dataset not updated within expected number of days for frequency", "L'ensemble de données n'a pas été mis à jour dans le nombre de jours prévu pour la fréquence",
    "Dataset URL unavailable",         "URL du jeu de données non disponible",
    "days since last update",          "jours depuis la dernière mise à jour",
    "Duplicate content checksum",      "Somme de contrôle en double",
    "Duplicate resource URL",          "URL de ressources en double",
    "en",                              "anglais",
    "exceeds maximum",                 "dépasse le maximum",
    "expected at column",              "attendu à la colonne",
    "expecting",                       " expectant ",
    "Error in reading ZIP, status =",  "Erreur de lecture fichier ZIP, status =",
    "Fails validation",                "Échoue la validation",
    "Flesch-Kincaid score for English description", "Score Flesch-Kincaid pour la description en anglais",
    "for",                             "pour",
    "for files",                       "pour les fichiers",
    "for resource",                    "pour ressource",
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
    "Maintainer email address must not be", "L'adresse e-mail du responsable ne doit pas être",
    "Maintainer email address is invalid",  "L'adresse e-mail du responsable n'est pas valide",
    "Maintainer email address missing", "L'adresse e-mail du responsable est manquante",
    "Missing CSV data file format for JSON-CSV format", "Le format de fichier de données CSV manquant pour le format JSON-CSV",
    "Missing data array item fields",    "Champs d'élément du tableau de données manquant",
    "Missing dataset description field", "Champ de description de dataset manquant",
    "Missing dataset description file types", "Types de fichiers de description de jeu de données manquants",
    "Missing or null dataset metadata field", "Champ de métadonnées de jeu de données manquant ou nul",
    "Missing or null dataset resource metadata field", "Champ de métadonnées de ressource de jeu de données manquant ou nul",
    "Missing required language data file", "Fichier de données de langue requise manquant",
    "Multiple file types in ZIP",      "Plusieurs types de fichiers dans un fichier ZIP",
    "No data files in dataset",        "Aucun fichier de données dans l'ensemble de données",
    "No data dictionary in dataset",   "Aucun dictionnaire de données dans l'ensemble de données",
    "No resources of type guide in dataset", "Aucune ressource de type 'guide' dans l'ensemble de données" ,
    "Non blank cell count mismatch for column", "Incompatibilité du nombre de cellules non vierges pour la colonne",
    "Non blank cell count mismatch for JSON-CSV field/CSV column", "Incompatibilité non vide de cellules pour JSON-CSV field / CSV column",
    "Not equal to data column count",  "Pas égal au nombre de colonnes de données",
    "Not equal to data row count",     "Pas égal au nombre de lignes de données",
    "Only alternate format data files in dataset", "Seuls les fichiers de données de format alternatif dans l'ensemble de données",
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
    Set_Open_Data_MARC_Language($language);
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
    Set_Open_Data_MARC_Debug($debug);
    Set_Open_Data_TXT_Debug($debug);
    Set_Open_Data_XML_Debug($debug);
    Set_Open_Data_Testcase_Debug($debug);
    Set_Data_File_Object_Debug($debug);
    Set_Readability_Debug($debug)
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
    # Get type and value portions of the data
    #
    ($type, $value) = split(/\s/, $data, 2);
    
    #
    # Is this a URL pattern for supporting files ?
    #
    if ( $testcase eq "OD_VAL" ) {
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
    # Quanity Rating System configuration items
    #
    elsif ( $testcase eq "TBS_QRS_Readable" ) {
        #
        # Maximum Flesch-Kincaid readability score ?
        #
        if ( defined($value) && ($type eq "FLESCH-KINCAID") ) {
            #
            # Save limit
            #
            $maximum_flesch_kincaid = $value;
        }
    }
    #
    # Quanity Rating System configuration items
    #
    elsif ( $testcase eq "TBS_QRS_Connected" ) {
        #
        # TBS organization name
        #
        if ( defined($value) && ($type eq "TBS_ORG_NAME") ) {
            $tbs_org_name = $value;
        }
        #
        # TBS maintainer email address
        #
        elsif ( defined($value) && ($type eq "TBS_MAINTAINER_EMAIL") ) {
            $tbs_maintainer_email = $value;
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
    Set_Open_Data_MARC_Testcase_Data($testcase, $data);
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
    Set_Open_Data_MARC_Test_Profile($profile, $open_data_checks);
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

    my ($mday, $mon, $year);
    
    #
    # Set current hash tables
    #
    $current_open_data_profile = $open_data_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;
    $current_open_data_profile_name = $profile;

    #
    # Initialize flags and counters
    #
    @content_results_list = ();
    
    #
    # Get current time
    #
    ( $mday, $mon, $year ) =
      ( localtime(time) )[ 3, 4, 5 ];

    #
    # Get full year number (not just offset from 1900).
    #
    $year = 1900 + $year;

    #
    # Adjust the month from 0 based (ie. Jan = 0) to 1 based (ie. Jan = 1).
    #
    $mon++;

    #
    # Create a date object for today's date. We use it for date
    # difference computing.
    #
    $today_date_object = DateTime->new(year => $year, month => $mon, day => $mday);

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
# Parameters: testcase - list of testcase identifiers
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
sub Record_Result {
    my ($testcase_list, $line, $column, $text, $error_string) = @_;

    my ($result_object, $id, $testcase);

    #
    # Check for a possible list of testcase identifiers.  The first
    # identifier that is part of the current profile is the one that
    # the error will be reported against.
    #
    foreach $id (split(/,/, $testcase_list)) {
        if ( defined($$current_open_data_profile{$id}) ) {
            $testcase = $id;
            last;
        }
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
# Parameters: testcase - list of testcase identifiers
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
    my ($testcase_list, $line, $column, $text, $error_string) = @_;

    my ($result_object, $id, $testcase);

    #
    # Check for a possible list of testcase identifiers.  The first
    # identifier that is part of the current profile is the one that
    # the error will be reported against.
    #
    foreach $id (split(/,/, $testcase_list)) {
        if ( defined($$current_open_data_profile{$id}) ) {
            $testcase = $id;
            last;
        }
    }
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
            Record_Result("OD_ENC,TBS_QRS_International", 0, -1, "$output",
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
        Record_Result("OD_URL,TBS_QRS_Honest", -1, -1, "",
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
         ($mime_type =~ /application\/csv/) ||
         ($mime_type =~ /text\/csv/) ||
         ($format =~ /^csv$/i) ||
         ($url =~ /\.csv$/i) ) {
        #
        # CSV file type
        #
        $data_file_object = data_file_object->new($url, "CSV");
        $data_file_object->lang($lang);

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
        $data_file_object->lang($lang);

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
    # Is this a MARC file ?
    #
    elsif ( ($mime_type =~ /application\/marc/i) ||
            ($format =~ /^mrc$/i) ||
            ($url =~ /\.mrc$/i) ) {
        #
        # MARC file type
        #
        $data_file_object = data_file_object->new($url, "MARC");
        $data_file_object->lang($lang);
        
        #
        # Check MARC data file
        #
        print "MARC data file\n" if $debug;
        @other_results = Open_Data_MARC_Check_Data($url, $data_file_object,
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
        $data_file_object->lang($lang);

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
        Record_Result("OD_URL,TBS_QRS_Honest", -1, -1, "",
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
        # If the format is other, there is no expected mime-type
        #
        $consistent = 1;
        if ( $format =~ /^other$/i ) {
            $consistent = 1;
        }
        #
        # Check for format and mime-type consistency for CSV files
        #
        elsif ( $format =~ /^csv$/i ) {
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
        # If the format is other, there is no expected mime-type
        #
        if ( $format =~ /^other$/i ) {
            $consistent = 1;
        }
        #
        # Check for mime-type and format consistency for CSV files
        #
        elsif ( ($mime_type =~ /text\/x-comma-separated-values/) ||
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
            Record_Result("OD_URL,TBS_QRS_Honest", -1, -1, "",
                  String_Value("Inconsistent format and mime-type") .
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
            Record_Result("OD_URL,TBS_QRS_Honest", -1, -1, "",
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
            Record_Result("OD_URL,TBS_QRS_Online", -1, -1, "",
                          String_Value("Dataset URL unavailable") .
                          " : " . $resp->status_line);
        }
        else {
            Record_Result("OD_URL,TBS_QRS_Online", -1, -1, "",
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
            Record_Result("OD_URL,TBS_QRS_Online", -1, -1, "",
                          String_Value("Dataset URL unavailable") .
                          " : " . $resp->status_line);
        }
        else {
            Record_Result("OD_URL,TBS_QRS_Online", -1, -1, "",
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
# Name: Check_Data_File_Content
#
# Parameters: url - open data file URL
#
# Description:
#
#   This function checks a data file's content.  It checks that
#     - for CSV files, there is no leading or trailing
#       whitespace in cell content
#
#***********************************************************************
sub Check_Data_File_Content {
    my ($url) = @_;

    my (@results, $data_file_object);

    #
    # Get the data file type (e.g. CSV).
    #
    print "Check_Data_File_Content\n" if $debug;
    if ( defined($data_file_objects{$url}) ) {
        $data_file_object = $data_file_objects{$url};
    }
    else {
        print "Unknown data file URL $url\n" if $debug;
    }

    #
    # Is this a CSV file ?
    #
    if ( defined($data_file_object) && $data_file_object->type() eq "CSV" ) {
        print "CSV data file\n" if $debug;
        @results = Open_Data_CSV_Get_Content_Results($url);
    }
    #
    # Is this a JSON file ?
    #
    elsif ( defined($data_file_object) && $data_file_object->type() eq "JSON" ) {
        print "JSON data file\n" if $debug;
        @results = Open_Data_JSON_Get_Content_Results($url);
    }
    #
    # Is this a MARC file ?
    #
    elsif ( defined($data_file_object) && $data_file_object->type() eq "MARC" ) {
        print "MARC data file\n" if $debug;
        @results = Open_Data_MARC_Get_Content_Results($url);
    }
    #
    # Is this XML ?
    #
    elsif ( defined($data_file_object) && $data_file_object->type() eq "XML" ) {
        print "XML data file\n" if $debug;
        @results = Open_Data_XML_Get_Content_Results($url);
    }
    #
    # Unknown file type
    #
    elsif ( defined($data_file_object) ) {
        print "Unexpected data file type " . $data_file_object->type() . "\n" if $debug;
    }

    #
    # Return results
    #
    return(@results);
}

#***********************************************************************
#
# Name: Open_Data_Check_Content
#
# Parameters: url - open data file URL
#             data_file_type - type of dataset file
#
# Description:
#
#   This function runs a number of Open Data content checks on a Dataset URLs.
#  The checks depend on the data file type.
#    DICTIONARY - a data dictionary file
#    DATA - a data file
#    RESOURCE - a resource file
#    API - a data API
#
#***********************************************************************
sub Open_Data_Check_Content {
    my ($url, $data_file_type) = @_;

    my (@tqa_results_list, $result_object, $tcid);

    #
    # Initialize the test case pass/fail table.
    #
    print "Open_Data_Check_Content: url = $url\n" if $debug;

    #
    # Is this a data file
    #
    if ( $data_file_type =~ /DATA/i ) {
        #
        # Check data content
        #
        @tqa_results_list = Check_Data_File_Content($url);
    }
    
    #
    # Is this a data dictionary file
    #
    elsif ( $data_file_type =~ /DICTIONARY/i ) {
        #
        # Check dictionary content
        #
        @tqa_results_list = Open_Data_XML_Dictionary_Content_Check($url);
    }

    #
    # Add testcase help URL to results
    #
    print "Open_Data_Check_Data_Content results\n" if $debug;
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
# Name: Check_Days_Since_Update
#
# Parameters: frequency - the dataset update frequency
#             date_published - the date the dataset was published
#             date_modified - the date the dataset was modified
#               i.e. updated.
#
# Description:
#
#   This function checks the latest date for the dataset, either the
# date modified, if it has been updated, or date published.  The date
# is checked against the expected maximum number of days between
# updates for the update frequency.
#
#***********************************************************************
sub Check_Days_Since_Update {
    my ($frequency, $date_published, $date_modified) = @_;

    my ($date_value, $freq_label, $date_object, $year, $mon, $day);
    my ($delta_days);

    #
    # Do we have an update frequency?
    #
    print "Check_Days_Since_Update for frequency = $frequency, date published = $date_published, date modified = $date_modified\n" if $debug;
    if ( defined($frequency) ) {
        #
        # Convery the frequency code to a more readable string
        #
        if ( defined($frequency_label{$frequency}) ) {
            $freq_label = $frequency_label{$frequency};
        }
        else {
            print "Error: Unknown frequency value \"$frequency\"\n";
            $freq_label = "unknown";
        }

        #
        # Do we have a maximum number of days between
        # updates for the frequency? Not all frequencies have an interval
        # value (e.g. irregular, not planned, ...)
        #
        if ( defined($frequency_inteval_days{$frequency}) ) {
            #
            # Do we have a date modified? If so use it to see
            # if the update is in line with the frequency value.
            #
            if ( defined($date_modified) && ($date_modified ne "") ) {
                $date_value = $date_modified;
                print "Use date modified value $date_value\n" if $debug;
            }
            #
            # No date modified, use the date published (there
            # may not have been any updates yet).
            #
            elsif ( defined($date_published) && ($date_published ne "") ) {
                $date_value = $date_published;
                print "Use date published value $date_value\n" if $debug;
            }

            #
            # Check to see if we have a date modified and see if
            # it is in line with the update frequency (i.e. an
            # annual frequency should have a date modified less
            # than 1 year ago).
            #
            if ( defined($date_value) ) {
                #
                # Get the year, month and date from the date modified
                #
                ($year, $mon, $day) = $date_value =~ /^(\d+)\-(\d+)\-(\d+)\s+.*$/io;
                $date_object = DateTime->new(year => $year, month => $mon, day => $day);

                #
                # Get the number of days since the update
                #
                $delta_days = $today_date_object->delta_days($date_object)->delta_days;
                print "Days since last modified = $delta_days\n" if $debug;

                #
                # Does the number of days make sense for the frequency?
                #
                if ( $delta_days > $frequency_inteval_days{$frequency} ) {
                    #
                    # Too long between updates.
                    #
                    Record_Result("TBS_QRS_Timely", -1, -1, "",
                                  String_Value("Dataset not updated within expected number of days for frequency") .
                                  " " . $frequency_label{$frequency} .
                                  String_Value("expecting") .
                                  $frequency_inteval_days{$frequency} . " " .
                                  String_Value("days since last update") .
                                  " $delta_days");
                }
                else {
                    print "Dataset updated within update frequency interval\n" if $debug;
                }
            }
            else {
                print "No published or updated date\n" if $debug;
            }
        }
        else {
            print "No defined number of day between updates for frequency\n" if $debug;
        }
    }
    else {
        print "No defined update frequency\n" if $debug;
    }
}

#***********************************************************************
#
# Name: trim
#
# Parameters: string - a string value
#
# Description:
#
#   This function removes leading and trailing whitespace from
# the supplied string.
#
#***********************************************************************
sub trim {
    my ($string) = @_;

    $string =~ s/^\s+|\s+$//g;
    return($string);
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
    my ($pattern, $alternate, %urls, $url_added, $required, $class, $key);
    my ($desc_en, $desc_fr, $translated, %readability_scores);
    my ($flesch_kincaid, $maintainer_email, $organization, $org_name);
    my ($data_file_count, $guide_file_count);
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

        #
        # Check dataset metadata fields.
        #
        if ( ! $have_error ) {
            #
            # Check for required metadata items in the "result" object
            #
            print "Check for required metadata items in the result object\n" if $debug;
            foreach $required (@required_json_description_metadata) {
                ($class, $key) = split(/:/, $required);
                
                #
                # Is this a "result" class of metadata item?
                #
                print "Check class $class name $name\n" if $debug;
                if ( $class eq "result" ) {
                    #
                    # Check for a value for the named item
                    #
                    print "Check for metadata field $key in results object\n" if $debug;
                    if ( (! defined($$result{$key})) ||
                         ($$result{$key} eq "") ) {
                        Record_Result("OD_REG", -1, -1, "",
                                      String_Value("Missing or null dataset metadata field") .
                                      " \"$key\"");
                    }
                    else {
                        print "Found $key = " . $$result{$key} . "\n" if $debug;
                    }
                }
            }
            
            #
            # Check that the date released or modified is within the
            # number of days between updates for the update frequency
            #
            Check_Days_Since_Update($$result{"frequency"},
                                    $$result{"date_published"},
                                    $$result{"date_modified"});
        }
    }
    
    #
    # Get the dataset description
    #
    if ( (! $have_error) && defined($$result{"notes_translated"}) ) {
        print "Get the notes_translated field\n" if $debug;
        $translated = $$result{"notes_translated"};

        #
        # Is this a hash table ?
        #
        $ref_type = ref $translated;
        if ( $ref_type eq "HASH" ) {
            #
            # Get the English and French descriptions
            #
            $desc_en = encode_entities(trim($$translated{"en"}));
            $desc_fr = encode_entities(trim($$translated{"fr"}));
            
            #
            # Check grade reading level of the description
            #
            %readability_scores = Readability_Grade_Text(\$desc_en);
            $flesch_kincaid = $readability_scores{"Flesch-Kincaid"};
            if ( ($flesch_kincaid != -1) ) {
                print "Flesch-Kincaid score is $flesch_kincaid\n" if $debug;
                if  ( $flesch_kincaid > $maximum_flesch_kincaid ) {
                    Record_Result("TBS_QRS_Readable", -1, -1, "",
                                  String_Value("Flesch-Kincaid score for English description") .
                                  " $flesch_kincaid " .
                                  String_Value("exceeds maximum") . " $maximum_flesch_kincaid");
                }
            }
        }
    }
    else {
        print "Missing title_translated item from results object\n" if $debug;
    }

    #
    # Get the maintainer email address
    #
    if ( (! $have_error) && defined($$result{"maintainer_email"}) ) {
        print "Get the maintainer_email field\n" if $debug;
        $maintainer_email = $$result{"maintainer_email"};
        
        #
        # Get the organization name
        #
        $org_name = "";
        if ( defined($$result{"organization"}) ) {
            $organization = $$result{"organization"};

            #
            # Is this a hash table ?
            #
            $ref_type = ref $organization;
            if ( $ref_type eq "HASH" ) {
                #
                # Get the organization name field
                #
                $org_name = $$organization{"name"};
            }
        }
        
        #
        # Is the email address en empty string?
        #
        if ( $maintainer_email =~ /^\s*$/ ) {
            Record_Result("TBS_QRS_Connected", -1, -1, "",
                          String_Value("Maintainer email address missing"));
        }
        #
        # Is the email address syntactally correct (a non exhaustive check)?
        #
        elsif ( $maintainer_email =~ /^([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,})$/ ) {
            #
            # If the organization name is not TBS, the maintainer email must not
            # be TBS.
            #
            if ( $org_name ne $tbs_org_name ) {
                #
                # Check that the maintainer email address is not the TBS
                # open government email address.
                #
                if ( $maintainer_email eq $tbs_maintainer_email ) {
                    Record_Result("TBS_QRS_Connected", -1, -1, "",
                                  String_Value("Maintainer email address must not be") .
                                  " $tbs_maintainer_email");
                }
            }
        }
        #
        # Invalid email address
        #
        else {
            Record_Result("TBS_QRS_Connected", -1, -1, "",
                          String_Value("Maintainer email address is invalid") .
                          " \"$maintainer_email\"");
        }
    }
    else {
        print "Missing maintainer_email item from results object\n" if $debug;
        Record_Result("TBS_QRS_Connected", -1, -1, "",
                      String_Value("Maintainer email address missing"));
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
        $data_file_count = 0;
        $guide_file_count = 0;
        foreach $value (@$resources) {
            $url_added = 0;
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
                     Record_Result("OD_REG", -1, -1, "",
                                   String_Value("Missing dataset description field") .
                                   " \"type\"");
                }
                if ( (! defined($format)) || ($format eq "") ) {
                     Record_Result("OD_REG", -1, -1, "",
                                   String_Value("Missing dataset description field") .
                                   " \"format\"");
                }
                if ( (! defined($url)) || ($url eq "") ) {
                     Record_Result("OD_REG", -1, -1, "",
                                   String_Value("Missing dataset description field") .
                                   " \"url\"");
                }

                #
                # Save dataset URL based on type.
                #
                if ( $type eq "api" ) {
                    $dataset_urls{"API"} .= "$format\t$url\n";
                    $url_added = 1;
                }
                elsif ( $type eq "guide" ) {
                    #
                    # Accept TXT and XML formatted documents. Other formats are
                    # likely to be supporting documents, not data dictionaries.
                    #
                    $guide_file_count++;
                    if ( ($format eq "TXT") || ($format eq "XML") ) {
                        $dataset_urls{"DICTIONARY"} .= "$format\t$url\n";
                        $url_added = 1;
                    }
                    #
                    # Is the format HTML, then assume it is a supporting document
                    #
                    elsif ( $format eq "HTML" ) {
                        $dataset_urls{"RESOURCE"} .= "$format\t$url\n";
                        $url_added = 1;
                    }
                    #
                    # Check for name Data Dictionary or Dictionnaire de données
                    #
                    else {
                        foreach $pattern (@data_dictionary_file_name) {
                            if ( $name eq $pattern ) {
                                $dataset_urls{"DICTIONARY"} .= "$format\t$url\n";
                                $url_added = 1;
                            }
                        }
                    }
                }
                #
                # Check for dataset file (i.e. a data file)
                #
                elsif ( $type eq "dataset" ) {
                    #
                    # Check for possible alternate format data file
                    #
                    $alternate = 0;
                    foreach $pattern (@alternate_data_file_name) {
                        if ( $name =~ /$pattern/ ) {
                            $dataset_urls{"ALTERNATE_DATA"} .= "$format\t$url\n";
                            $alternate = 1;
                            $url_added = 1;
                        }
                    }

                    #
                    # If the file is not an alternate format, it is a primary
                    # formate data file
                    #
                    if ( ! $alternate ) {
                       $dataset_urls{"DATA"} .= "$format\t$url\n";
                       $url_added = 1;
                       $data_file_count++;
                    }
                }
               
                #
                # Check for duplicate URL values
                #
                if ( $url_added ) {
                    if ( defined($urls{$url}) ) {
                        #
                        # URL is a duplicate of a previous URL
                        #
                        Record_Result("TP_PW_OD_DATA", -1, -1, "",
                                      String_Value("Duplicate resource URL") .
                                      " \"$url\"");
                    }
                    else {
                        #
                        # Record URL
                        #
                        $urls{$url} = 1;
                    }
                }

                #
                # Check for required metadata items in the "resources" object
                #
                print "Check for required metadata items in the resources object\n" if $debug;
                foreach $required (@required_json_description_metadata) {
                    ($class, $key) = split(/:/, $required);

                    #
                    # Is this a "resources" class of metadata item?
                    #
                    print "Check class $class name $key\n" if $debug;
                    if ( $class eq "resources" ) {
                        #
                        # Check for a value for the named item
                        #
                        print "Check for metadata field $key in resources object\n" if $debug;
                        if ( (! defined($$value{$key})) ||
                             ($$value{$key} eq "") ) {
                            Record_Result("OD_REG", -1, -1, "",
                                          String_Value("Missing or null dataset resource metadata field") .
                                          " \"$key\" " . String_Value("for resource") .
                                          " \"$name\", $url");
                        }
                        else {
                            print "Found $key = " . $$value{$key} . "\n" if $debug;
                        }
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
                          String_Value("No data dictionary in dataset"));
        }
        #
        # Are there any supporting documentation resources (i.e. of type "guide")
        #
        elsif ( $guide_file_count == 0 ) {
            Record_Result("TBS_QRS_Documented", -1, -1, "",
                          String_Value("No resources of type guide in dataset"));
        }

        #
        # Are there any data files specified in the
        # dataset files?
        #
        if ( $data_file_count == 0 ) {
            #
            # Did we only find alternate format data files?
            #
            if ( defined($dataset_urls{"ALTERNATE_DATA"}) ) {
                Record_Result("TP_PW_OD_DATA,TBS_QRS_Structured", -1, -1, "",
                              String_Value("Only alternate format data files in dataset"));
            }
            else {
                Record_Result("TP_PW_OD_DATA,TBS_QRS_Structured", -1, -1, "",
                              String_Value("No data files in dataset"));
            }
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
    my (%found_langs);

    #
    # Check each entry in the URL language map
    #
    print "Check_Data_File_Languages\n" if $debug;
    foreach $eng_url (sort(keys(%url_lang_map))) {
        #
        # How many language versions of the URL do we have?
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
            $url_lang = URL_Check_GET_Filename_Query_Language($eng_url);

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
                #$url_file_langs{$url_lang} = $eng_url;
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
                    if ( defined($url_file_langs{$url_lang}) ||
                         defined($url_file_langs{$url_lang3}) ) {
                        #
                        # Found a required language
                        #
                        $found_langs{$url_lang} = 1;
                        print "Found required language $url_lang\n" if $debug;
                    }
                }
                
                #
                # Check to see if we found at least 1 required language.
                # If none are found, skip check for required languages.
                # It may be possible that the URLs contain what appears
                # to be a language suffix, but it isn't really
                # a language suffix.
                #
                if ( keys(%found_langs) > 0 ) {
                    foreach $url_lang (@data_file_required_lang) {
                        #
                        # If we don't have this language variant, report it.
                        #
                        print "Check for found language $url_lang\n" if $debug;
                        if ( ! defined(%found_langs{$url_lang}) ) {
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
                                  " \"$lang_string\"");
                        }
                    }
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_CSV_Column_Type_Value
#
# Parameters: exp_column_objects - pointer to list of expected column object
#             column_objects - pointer to list of column object
#             column_count - number of columns
#             exp_url - URL of CSV file for expected columns
#             url - URL of CSV file
#
# Description:
#
#   This function performs checks on CSV data columns to see if the current
# columns match the expected columns for
#   - column data type (e.g. numeric, date, etc.)
#   - numeric and date column min, max and sum
#
#***********************************************************************
sub Check_CSV_Column_Type_Value {
    my ($exp_column_objects, $column_objects, $column_count, $exp_url, $url) = @_;

    my ($i, $col_obj, $expected_col_obj, $value_exp, $value_col);

    #
    # Check the column types (e.g. numeric, text), the number of
    # non-blank cells, min, max and sum values of numeric columns.
    #
    print "Check_CSV_Column_Type_Value\n" if $debug;
    for ($i = 0; $i < $column_count; $i++) {
        #
        # Get the column objects
        #
        $expected_col_obj = $$exp_column_objects[$i];
        $col_obj = $$column_objects[$i];

        #
        # If we did not determine the column content type
        # (e.g. may be all blanks), skip checks.
        #
        print "Column types for column $i, " .
        $col_obj->type() . " and " .
        $expected_col_obj->type() . "\n" if $debug;
        print "Column non-blank cell count for column $i, " .
               $col_obj->non_blank_cell_count() . " and " .
               $expected_col_obj->non_blank_cell_count() . "\n" if $debug;
        if ( ($col_obj->type() eq "") || ($expected_col_obj->type() eq "") ) {
            print "Column data type not determined\n" if $debug;
            next
        }
        #
        # Do the column types match?
        #
        elsif ( $col_obj->type() ne $expected_col_obj->type() ) {
             Record_Result("OD_DATA", -1, ($i + 1), "",
                          String_Value("Column type mismatch for column") .
                          " \"" . $col_obj->heading() . "\" (" . ($i + 1) . ") \n" .
                          String_Value("found") . " " . $col_obj->type() .
                          " " . String_Value("in") . " $url\n" .
                          String_Value("expecting") .
                          $expected_col_obj->type() .
                          String_Value("as found in") . $exp_url);
        }
        #
        # Do the number of non-blank cells match?
        #
        elsif ( $col_obj->non_blank_cell_count() != $expected_col_obj->non_blank_cell_count() ) {
            Record_Result("OD_DATA", -1, ($i + 1), "",
                          String_Value("Non blank cell count mismatch for column") .
                          " \"" . $col_obj->heading() . "\" (" . ($i + 1) . ") \n" .
                          String_Value("found") . " " . $col_obj->non_blank_cell_count() .
                          " " . String_Value("in") . " $url\n" .
                          String_Value("expecting") .
                          $expected_col_obj->non_blank_cell_count() .
                          String_Value("as found in") . $exp_url);
        }

        #
        # Is this a numeric or date (YYYY-MM-DD) column type?
        #
        if ( ($col_obj->type() eq "numeric") ||
             ($col_obj->type() eq "date") ) {
            #
            # Do the column sums match?
            #
            print "Column sum for column $i, " .
                   $col_obj->sum() . " and " .
                   $expected_col_obj->sum() . "\n" if $debug;
            if ( $col_obj->sum() != $expected_col_obj->sum() ) {
                  Record_Result("OD_DATA", -1, ($i + 1), "",
                                String_Value("Column sum mismatch for column") .
                                " \"" . $col_obj->heading() . "\" (" . ($i + 1) . ") \n" .
                                String_Value("found") . " " . $col_obj->sum() .
                                " " . String_Value("in") . " $url\n" .
                                String_Value("expecting") .
                                $expected_col_obj->sum() .
                                String_Value("as found in") . $exp_url);
            }

            #
            # If the column type is date, convert the maximum date
            # into a number
            #
            if ( $col_obj->type() eq "date" ) {
                if ( defined($expected_col_obj->max()) ) {
                    $value_exp = $expected_col_obj->max();
                    $value_exp =~ s/\-//g;
                }
                else {
                     $value_exp = 0;
                }
                if ( defined($col_obj->max()) ) {
                    $value_col = $col_obj->max();
                                $value_col =~ s/\-//g;
                }
                else {
                    $value_col = 0;
                }
            }
            else {
                if ( defined($expected_col_obj->max()) ) {
                    $value_exp = $expected_col_obj->max();
                }
                else {
                    $value_exp = 0;
                }
                if ( defined($col_obj->max()) ) {
                    $value_col = $col_obj->max();
                }
                else {
                    $value_col = 0;
                }
            }

            #
            # Do the column maximum values match?
            #
            print "Column max for column $i, " .
                   $col_obj->max() . " and " .
                   $expected_col_obj->max() . "\n" if $debug;
            if ( $value_col != $value_exp ) {
                  Record_Result("OD_DATA", -1, ($i + 1), "",
                                String_Value("Column maximum mismatch for column") .
                                " \"" . $col_obj->heading() . " (" . ($i + 1) . ") \n" .
                                String_Value("found") . " " . $col_obj->max() .
                                " " . String_Value("in") . " $url\n" .
                                String_Value("expecting") .
                                $expected_col_obj->max() .
                                String_Value("as found in") . $exp_url);
            }

            #
            # If the column type is date, convert the minimum date
            # into a number
            #
            if ( $col_obj->type() eq "date" ) {
                if ( defined($expected_col_obj->min()) ) {
                    $value_exp = $expected_col_obj->min();
                    $value_exp =~ s/\-//g;
                }
                else {
                    $value_exp = 0;
                }
                if ( defined($col_obj->min()) ) {
                    $value_col = $col_obj->min();
                    $value_col =~ s/\-//g;
                }
                else {
                    $value_col = 0;
                }
            }
            else {
                if ( defined($expected_col_obj->min()) ) {
                    $value_exp = $expected_col_obj->min();
                }
                else {
                    $value_exp = 0;
                }
                if ( defined($col_obj->min()) ) {
                    $value_col = $col_obj->min();
                }
                else {
                    $value_col = 0;
                }
            }

            #
            # Do the column minimum values match?
            #
            print "Column min for column $i, " .
                   $col_obj->min() . " and " .
                   $expected_col_obj->min() . "\n" if $debug;
            if ( $value_col != $value_exp ) {
                  Record_Result("OD_DATA", -1, ($i + 1), "",
                                String_Value("Column minimum mismatch for column") .
                                " \"" . $col_obj->heading() . "\" (" . ($i + 1) . ") \n" .
                                String_Value("found") . " " . $col_obj->min() .
                                " " . String_Value("in") . " $url\n" .
                                String_Value("expecting") .
                                $expected_col_obj->min() .
                                String_Value("as found in") . $exp_url);
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_CSV_Column_Heading_Order
#
# Parameters: exp_column_objects - pointer to list of expected column object
#             column_objects - pointer to list of column object
#             column_count - number of columns
#             exp_url - URL of CSV file for expected columns
#             url - URL of CSV file
#             lang - language of the url
#
# Description:
#
#   This function performs checks on CSV data columns heading to see
# if the order of headings match the expected order.
#
#***********************************************************************
sub Check_CSV_Column_Heading_Order {
    my ($exp_column_objects, $column_objects, $column_count,
        $exp_url, $url, $lang) = @_;

    my ($i, $j, $col_obj, $expected_col_obj, $value_exp, $value_col);
    my ($exp_dict_id, $dict_id, $dict_obj, $found_heading_match);

    #
    # Number of columns match, now check the column types
    # (e.g. numeric, text), the number of non-blank cells,
    # the column headings and language.
    #
    print "Check_CSV_Column_Heading_Order\n" if $debug;
    for ($i = 0; $i < $column_count; $i++) {
        #
        # Get the expected column object
        #
        $expected_col_obj = $$exp_column_objects[$i];

        #
        # If the expected column heading is a valid heading
        # get the data dictionary object and id values
        #
        if ( $expected_col_obj->valid_heading() ) {
            $dict_obj = $expected_col_obj->dictionary_object();
            $exp_dict_id = $dict_obj->id();
            print "Expected heading " . $expected_col_obj->heading() . " # " . ($i + 1) .
                  "\n" if $debug;
        }
        else {
            print "Expected heading " . $expected_col_obj->first_data() . " # " . ($i + 1) .
                  " is not a valid heading, check heading label only\n" if $debug;
        }

        #
        # Look for this a heading matching the expected heading in the
        # current file's heading list.
        #
        $found_heading_match = 0;
        for ($j = 0; $j < $column_count; $j++) {
            #
            # Get the column object
            #
            $col_obj = $$column_objects[$j];

            #
            # If current column heading is a valid heading get the
            # data dictionary object and id values
            #
            if ( $col_obj->valid_heading() ) {
                #
                # Is the expected column heading valid? If so this compare
                # heading data dictionary id values for a possible match
                #
                print "Current heading " . $col_obj->heading() . " # " . ($i + 1) .
                      "\n" if $debug;
                if ( $expected_col_obj->valid_heading() ) {
                    #
                    # Get the data dictionary id value for this column heading
                    #
                    $dict_obj = $col_obj->dictionary_object();
                    $dict_id = $dict_obj->id();
                    
                    #
                    # Does the data file have a language? If it doesn't the
                    # data dictionary id values may not be unique for headings.
                    # The data file may contain 2 columns, one for each
                    # language variant for a single data dictionary heading entry.
                    # Compare the heading labels for the order check.
                    #
                    if ( ($lang eq "") ) {
                        if ( $col_obj->heading() eq $expected_col_obj->heading() ) {
                            #
                            # Found expected heading, does the column number match
                            # the expected column number?
                            #
                            if ( $j != $i ) {
                                #
                                # Error, column heading out of order.
                                #
                                Record_Result("OD_DATA", -1, ($j + 1), "",
                                              String_Value("Column heading out of order") .
                                              " \"" . $col_obj->heading() . "\" " .
                                              String_Value("column") . " " . ($j + 1) . " \n" .
                                              " " . String_Value("in") . " $url\n" .
                                              String_Value("expected at column") .
                                              " " . ($i + 1) . " " .
                                              String_Value("as found in") . $exp_url);
                            }

                            #
                            # Stop looking for a heading match
                            #
                            $found_heading_match = 1;
                            last;
                        }
                    }
                    #
                    # Compare id values for a match
                    #
                    elsif ( $exp_dict_id eq $dict_id ) {
                        #
                        # Found expected heading, does the column number match
                        # the expected column number?
                        #
                        if ( $j != $i ) {
                            #
                            # Error, column heading out of order.
                            #
                            Record_Result("OD_DATA", -1, ($j + 1), "",
                                          String_Value("Column heading out of order") .
                                          " \"" . $col_obj->heading() . "\" " .
                                          String_Value("column") . " " . ($j + 1) . " \n" .
                                          " " . String_Value("in") . " $url\n" .
                                          String_Value("expected at column") .
                                          " " . ($i + 1) . " " .
                                          String_Value("as found in") . $exp_url);
                        }


                        #
                        # Stop looking for a heading match
                        #
                        $found_heading_match = 1;
                        last;
                    }
                }
            }
            #
            # Current column heading is not valid (i.e. not in dictionary)
            #
            else {
                print "Current heading " . $col_obj->first_data() . " # " . ($i + 1) .
                      " is not a valid heading, check heading label only\n" if $debug;

                #
                # Is the expected column heading non-valid? If so then compare
                # heading labels for a possible match
                #
                if ( ! $expected_col_obj->valid_heading() ) {
                    #
                    # Compare first row values (assume they are headings) for a match
                    #
                    if ( $expected_col_obj->first_data() eq $col_obj->first_data() ) {
                        #
                        # Found expected heading, does the column number match
                        # the expected column number?
                        #
                        if ( $j != $i ) {
                            #
                            # Error, column heading out of order.
                            #
                            Record_Result("OD_DATA", -1, ($j + 1), "",
                                          String_Value("Column heading out of order") .
                                          " \"" . $col_obj->first_data() . "\" " .
                                          String_Value("column") . " " . ($j + 1) . " \n" .
                                          " " . String_Value("in") . " $url\n" .
                                          String_Value("expected at column") .
                                          " " . ($i + 1) . " " .
                                          String_Value("as found in") . $exp_url);
                        }

                        #
                        # Stop looking for a heading match
                        #
                        $found_heading_match = 1;
                        last;
                    }
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_CSV_Data_File_Rows_Columns
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
sub Check_CSV_Data_File_Rows_Columns {
    my (%url_lang_map) = @_;

    my (@url_list, $list_item, $url, $eng_url);
    my ($lang_count, $lang_item_addr, $lang_data_file_object);
    my ($data_file_object, $rows, $cols, $expected_rows, $expected_cols);
    my ($column_objects, $first_columns_url);
    my ($first_rows, $first_cols, $first_column_objects);
    my ($dict_obj, $expected_dict_obj, $heading_lang, $file_lang);
    my ($expected_cols, $expected_column_objects, $expected_columns_url);

    #
    # Check each entry in the URL language map
    #
    print "Check_CSV_Data_File_Rows_Columns\n" if $debug;
    foreach $eng_url (sort(keys(%url_lang_map))) {
        #
        # How many language versions of the URL do we have?
        #
        print "Checking English URL $eng_url\n" if $debug;
        $lang_item_addr = $url_lang_map{$eng_url};
        $lang_count = @$lang_item_addr;

        #
        # Check all language variants to see if the
        # row and column counts match
        #
        print "Check $lang_count language variants\n" if $debug;
        undef($first_column_objects);
        foreach $url (@$lang_item_addr) {
            #
            # Get the data file object
            #
            if ( ! defined($data_file_objects{$url}) ) {
                print "No data file object\n" if $debug;
                next;
            }

            #
            # See if this is a CSV data file
            #
            $data_file_object = $data_file_objects{$url};
            if ( $data_file_object->type() ne "CSV" ) {
                #
                # Skip non-CSV file
                #
                print "Skip non-CSV file, type is " . $data_file_object->type() .
                      "\n" if $debug;
                last;
            }

            #
            # Do we have expected column/row counts? Use these counts to
            # compare rows and columns across all data files in the dataset.
            #
            if ( ! defined($expected_cols) ) {
                #
                # Get the row & column counts from the URL
                #
                ($expected_rows, $expected_cols) = Open_Data_CSV_Check_Get_Row_Column_Counts($data_file_object);

                #
                # Get the column object list
                #
                $expected_column_objects = Open_Data_CSV_Check_Get_Column_Object_List($data_file_object);

                #
                # Record URL of the file defining the expected values
                #
                $expected_columns_url = $url;
                print "expected_rows = $expected_rows, expected_cols = $expected_cols\n" if $debug;
            }

            #
            # Is this the first data file for this language variant set?
            #
            if ( ! defined($first_column_objects) ) {
                #
                # Get the row & column counts from the English URL
                #
                ($first_rows, $first_cols) = Open_Data_CSV_Check_Get_Row_Column_Counts($data_file_object);

                #
                # Get the column object list
                #
                $first_column_objects = Open_Data_CSV_Check_Get_Column_Object_List($data_file_object);

                #
                # Record URL of the file defining the expected values for this
                # language variant set.
                #
                $first_columns_url = $url;
                print "first_rows = $first_rows, first_cols = $first_cols\n" if $debug;

                #
                # Compare the file's column count against the expected
                # column count.  We only check the first file as other language
                # variants are checked against the first.
                #
                if ( $first_cols != $expected_cols ) {
                    Record_Content_Result("TP_PW_OD_CONT", -1, -1, "",
                                          String_Value("Column count mismatch, found") .
                                          " $first_cols " . String_Value("in") . " $url\n" .
                                          String_Value("expecting") .
                                          $expected_cols . String_Value("as found in") .
                                          $expected_columns_url);
                }
            }

            #
            # Get the row & column counts from the URL
            #
            ($rows, $cols) = Open_Data_CSV_Check_Get_Row_Column_Counts($data_file_object);

            #
            # Get the column object list
            #
            $column_objects = Open_Data_CSV_Check_Get_Column_Object_List($data_file_object);

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
            # Compare this URL's column count to the first file's count
            #
            if ( $cols != $first_cols ) {
                Record_Content_Result("OD_DATA", -1, -1, "",
                                      String_Value("Column count mismatch, found") .
                                      " $cols " . String_Value("in") . " $url\n" .
                                      String_Value("expecting") .
                                      $first_cols . String_Value("as found in") .
                                      $first_columns_url);
            }
            else {
                #
                # Number of columns match, now check the column types
                # (e.g. numeric, text), the number of non-blank cells,
                # column min, max and sums (for numeric columns).
                #
                Check_CSV_Column_Type_Value($first_column_objects,
                                            $column_objects, $cols,
                                            $first_columns_url, $url);

                #
                # Check the column heading order
                #
                Check_CSV_Column_Heading_Order($first_column_objects, $column_objects,
                                               $cols, $first_columns_url, $url,
                                               $data_file_object->lang());
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
    my ($heading_label);

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
        
        #
        # Is this a valid data dictionary heading? If
        # so we use the data dictionary term, if not we use the
        # first data cell value to compare CSV and JSON-CSV headings.
        #
        if ( $csv_heading->valid_heading() ) {
            $heading_label = $csv_heading->heading();
        }
        else {
            $heading_label = $csv_heading->first_data();
        }
        print "Check for heading \"$heading_label\"\n" if $debug;

        #
        # Check the JSON-CSV fields for a matching header.
        # There is no requirement that the order of the
        # JSON-CSV fields match the CSV headings.
        #
        undef($json_field);
        foreach $field (@$fields_list) {
            #
            # Does the field heading match the column label?
            #
            if ( $field->heading() eq $heading_label ) {
                $heading_match{$heading_label} = 1;
                $json_field = $field;
                print "JSON field found matching CSV heading\n" if $debug;
                last;
            }
            #
            # Does the field first value match the column label?
            #
            elsif ( $field->first_data() eq $heading_label ) {
                $heading_match{$heading_label} = 1;
                $json_field = $field;
                print "JSON field value found matching CSV heading\n" if $debug;
                last;
            }
        }

        #
        # Did we find the CSV column in the JSON object
        # field list?
        #
        if ( ! $heading_match{$heading_label} ) {
            $missing_csv_headings .= "\"$heading_label\" ";
            
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
            #
            # Check CSV column data type for blank.  The type may be
            # blank if other conditions (e.g. blank cell percentage) cause
            # the type to be undetermined.  The same check is not performed
            # on the JSON file type.
            #
            if ( $csv_heading->type() ne "" ) {
                Record_Result("OD_DATA", -1, -1, "",
                              String_Value("Type mismatch for JSON-CSV field/CSV column") .
                              " " . $json_field->heading() . "\n" .
                              String_Value("found") . " " . $json_field->type() .
                              " " . String_Value("in") . " $json_url\n" .
                              String_Value("expecting") .
                              $csv_heading->type() .
                              String_Value("as found in") . $csv_url);
            }
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
# Name: Check_JSON_CSV_Data_File_Fields
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
sub Check_JSON_CSV_Data_File_Fields {
    my ($url_list, $dictionary, %url_lang_map) = @_;

    my (@url_list, $list_item, $url, $eng_url, $format, $item);
    my ($lang_count, $lang_item_addr, $lang_data_file_object);
    my ($data_file_object, $items, $fields, $first_items, $first_fields);
    my ($col_obj, $eng_col_obj, $i, $csv_url, %url_map);
    my ($csv_data_file_object, $csv_rows, $json_data, $fields_list);
    my ($csv_columns, $csv_columns_list, %heading_match, $csv_heading);
    my ($json_field, $missing_csv_headings, $content_error);
    my ($first_url);
    
    #
    # Create a hash table of all URLs
    #
    print "Check_JSON_CSV_Data_File_Fields\n" if $debug;
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
        # How many language versions of the URL do we have?
        #
        $lang_item_addr = $url_lang_map{$eng_url};
        $lang_count = @$lang_item_addr;
        
        #
        # Check all language variants to get the first CSV file
        #
        print "Get first CSV file for $eng_url\n" if $debug;
        undef($first_items);
        foreach $url (@$lang_item_addr) {
            #
            # Get the data file object
            #
            print "Checking URL $url\n" if $debug;
            if ( ! defined($data_file_objects{$url}) ) {
                print "No data file object\n" if $debug;
                next;
            }
            $data_file_object = $data_file_objects{$url};

            #
            # Is this a CSV file?
            #
            if ( $data_file_object->type() eq "CSV" ) {
                #
                # Get the data array item and field counts from the English URL
                #
                $first_items = $data_file_object->attribute($row_count_attribute);
                $first_fields = $data_file_object->attribute($column_count_attribute);
                $first_url = $url;
                print "first_items = $first_items, first_fields = $first_fields, first_url = $first_url\n" if $debug;
                last;
            }
        }
        
        #
        # Now check all language variants to see if the
        # data array item and field counts match
        #
        print "Check " . scalar(@$lang_item_addr) . " language variants\n" if $debug;
        foreach $url (@$lang_item_addr) {
            #
            # Get the data file object
            #
            print "Checking URL $url\n" if $debug;
            if ( ! defined($data_file_objects{$url}) ) {
                print "No data file object\n" if $debug;
                next;
            }
            $data_file_object = $data_file_objects{$url};

            #
            # See if this is a JSON-CSV data file
            #
            if ( ($data_file_object->type() eq "JSON") &&
                 ($data_file_object->format() eq "JSON-CSV") ) {
                #
                # Have JSON-CSV data file
                #
                print "Found JSON-CSV data file $url\n" if $debug;
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
            # Get data file details for this URL
            #
            $current_url = $url;
            $items = $data_file_object->attribute($row_count_attribute);
            $fields = $data_file_object->attribute($column_count_attribute);
            $fields_list = $data_file_object->attribute($column_list_attribute);

            #
            # Compare this URL's data array item count to the English
            # URL's data array item count.  All language variants of the
            # data file are expected to have the same number of items.
            #
            print "Compare item count $items against expected count $first_items\n" if $debug;
            if ( defined($first_items) && ($items != $first_items) ) {
                Record_Result("OD_DATA", -1, -1, "",
                              String_Value("Data array item count mismatch, found") .
                              " $items " . String_Value("in") . " $url\n" .
                              String_Value("expecting") .
                              $first_items . String_Value("as found in") .
                              $first_url);
            }

            #
            # Compare this URL's data array item field count to the English
            # URL's data array item field count.  All language variants of the
            # data file are expected to have the same number of fields.
            #
            print "Compare item field count $fields against expected field count $first_fields\n" if $debug;
            if ( defined($first_items) && ($fields != $first_fields) ) {
                Record_Result("OD_DATA", -1, -1, "",
                              String_Value("Data array item field count mismatch, found") .
                              " $fields " . String_Value("in") . " $url\n" .
                              String_Value("expecting") .
                              $first_fields . String_Value("as found in") .
                              $first_url);
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
#   This function performs technical checks on the dataset files as a
# collection.  It checks for
#  - language specific files (e.g. has a language suffix).
#  - the presence of a file for each language.
#  - consistent content in different formats of the same data file
#    (e.g. CSV and JSON).
# - duplicate content in files
#
#***********************************************************************
sub Open_Data_Check_Dataset_Data_Files {
    my ($profile, $url_list, $dictionary) = @_;

    my (@tqa_results_list, @url_list, $list_item, $format, $url, $eng_url);
    my (%url_lang_map, $lang_item_addr, $data_file_object, %file_checksums);
    my ($checksum, $url_lang, $eng_file_query, $url_file_query);
    my ($protocol, $domain, $file_path, $query, $new_url);
    my ($found_eng_or_fra);

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
    $found_eng_or_fra = 0;
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
        # language component).   Also get the language of this URL.
        #
        $eng_url = URL_Check_Get_English_URL($url);
        if ( $eng_url eq "" ) {
            $eng_url = $url;
        }
        $url_lang = URL_Check_GET_URL_Language($url);
        print "URL = $url, language = $url_lang, English URL = $eng_url\n" if $debug;
        
        #
        # Did we find an English or French URL? We only do language variant
        # check if we find an English or French URL. This avoids checking
        # files if thy have what appears to be a language suffix when they
        # actually don't.
        #
        if ( ($url_lang eq "eng") || ($url_lang eq "fra") ) {
            $found_eng_or_fra = 1;
        }
        
        #
        # Get URL components, we only need the file name and query parameters.
        # We don't need the directory portion to detect language variants of
        # a data file.  If the data files are stored on the Open Government
        # Portal, the directory paths won't be the same.
        #
        ($protocol, $domain, $file_path, $query, $new_url) =
            URL_Check_Parse_URL($eng_url);
        
        #
        # Get the file name from the file path then add in the query.
        #
        $eng_file_query = basename($file_path);
        $eng_file_query .= $query;
        print "English file name and query = $eng_file_query\n" if $debug;
        
        #
        # Get URL components, we only need the file name and query parameters.
        # We don't need the directory portion to detect language variants of
        # a data file.  If the data files are stored on the Open Government
        # Portal, the directory paths won't be the same.
        #
        ($protocol, $domain, $file_path, $query, $new_url) =
            URL_Check_Parse_URL($url);
        $url_file_query = basename($file_path);
        $url_file_query .= $query;
        print "URL file name and query = $url_file_query\n" if $debug;
            
        #
        # Save this URL in the url language map if it is not the
        # English URL.  The map is indexed by the English URL.
        #
        if ( ! defined($url_lang_map{$eng_file_query}) ) {
            my (@url_map_list) = ($url);
            $url_lang_map{$eng_file_query} = \@url_map_list;
            print "Create new language map indexed by $eng_file_query\n" if $debug;
            
            #
            # If this URL's language is English, and the English URL does not
            # match this URL (can be the base for mixed case or upper case
            # URL paths), save the URL map list under the real URL as well
            #
            if ( ($url_lang eq "eng") && ($url_file_query ne $eng_file_query) ) {
                print "Cross link language map for $url_file_query also\n" if $debug;
                $url_lang_map{$url_file_query} = \@url_map_list;
            }
        }
        else {
            #
            # Add this URL to the list of URLs
            #
            my ($url_map_list_addr);
            $url_map_list_addr = $url_lang_map{$eng_file_query};
            push(@$url_map_list_addr, $url);
            print "Add to language map indexed by $eng_file_query url $url\n" if $debug;
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
                              " $checksum " . String_Value("for files") .
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
    if ( $found_eng_or_fra ) {
        Check_Data_File_Languages(%url_lang_map);
    }
    
    #
    # Check CSV file content for rows/column matches and other technical checks
    #
    if ( $found_eng_or_fra ) {
        Check_CSV_Data_File_Rows_Columns(%url_lang_map);
    }

    #
    # Check JSON-CSV file content for item/field matches and other content checks
    #
    Check_JSON_CSV_Data_File_Fields($url_list, $dictionary, %url_lang_map);

    #
    # Return results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Open_Data_Check_Dataset_Data_Files_Content
#
# Parameters: none
#
# Description:
#
#   This function runs the list of content errors found.
#
#***********************************************************************
sub Open_Data_Check_Dataset_Data_Files_Content {

    #
    # Return content check results
    #
    return(@content_results_list);
}

#***********************************************************************
#
# Name: Open_Data_Check_Get_Headings_List
#
# Parameters: this_url - a URL
#
# Description:
#
#   This function returns the headings list found in the last file
# analysed.
#
#***********************************************************************
sub Open_Data_Check_Get_Headings_List {
    my ($this_url) = @_;
    
    my ($headings);
    
    #
    # Check for CSV file headings
    #
    $headings = Open_Data_CSV_Check_Get_Headings_List($this_url);
    
    #
    # If there are no headings (not a CSV file), check
    # for JSON-CSV headings.
    #
    if ( $headings eq "" ) {
        $headings = Open_Data_JSON_Check_Get_Headings_List($this_url);
    }
    
    #
    # If there are no headings (not a CSV or JSON-CSV file), check
    # for XML data file headings.
    #
    if ( $headings eq "" ) {
        $headings = Open_Data_XML_Check_Get_Data_Headings_List($this_url);
    }

    #
    # If there are no data file headings (not a CSV, JSON-CSV or
    # XML data file), check for XML Data Dictionary headings.
    #
    if ( $headings eq "" ) {
        $headings = Open_Data_XML_Check_Get_Dictionary_Headings_List($this_url);
    }

    #
    # Return list of headings
    #
    return($headings);
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

