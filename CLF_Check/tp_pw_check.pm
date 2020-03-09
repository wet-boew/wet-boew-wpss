#***********************************************************************
#
# Name:   tp_pw_check.pm
#
# $Revision: 1660 $
# $URL: svn://10.36.148.185/WPSS_Tool/CLF_Check/Tools/tp_pw_check.pm $
# $Date: 2020-01-08 10:08:09 -0500 (Wed, 08 Jan 2020) $
#
# Description:
#
#   This file contains routines that parse HTML files and check for
# a number of Common Look and Feel CLF 2.0 check points.
#
# Public functions:
#     Set_TP_PW_Check_Language
#     Set_TP_PW_Check_Debug
#     Set_TP_PW_Check_Testcase_Data
#     Set_TP_PW_Check_Test_Profile
#     TP_PW_Check_Read_URL_Help_File
#     TP_PW_Check_Testcase_URL
#     TP_PW_Check
#     TP_PW_Check_Links
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

package tp_pw_check;

use strict;
use HTML::Entities;
use URI::URL;
use File::Basename;
use Digest::MD5 qw(md5_hex);
use Encode;
use File::Temp qw/ tempfile tempdir /;

#
# Use WPSS_Tool program modules
#
use clf_check;
use crawler;
use html_landmark;
use testcase_data_object;
use textcat;
use tqa_result_object;
use tqa_tag_object;
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
    @EXPORT  = qw(Set_TP_PW_Check_Language
                  Set_TP_PW_Check_Debug
                  Set_TP_PW_Check_Testcase_Data
                  Set_TP_PW_Check_Test_Profile
                  TP_PW_Check_Read_URL_Help_File
                  TP_PW_Check_Testcase_URL
                  TP_PW_Check
                  TP_PW_Check_Links
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;

my (%clf_check_profile_map, $current_clf_check_profile);
my ($results_list_addr, $content_section_handler);
my ($doctype_line, $doctype_column, $doctype_text, $doctype_label);
my ($doctype_version, $doctype_language, $doctype_class, $found_frame_tag);
my ($current_url, %template_integrity, %template_version, %site_inc_version);
my ($current_heading_level, $have_text_handler, %section_h1_count);
my (%found_template_markers, $current_clf_check_profile_name);
my ($valid_search_actions, $expected_search_inputs);
my ($in_search_form, $in_noscript, @heading_level_stack);
my ($current_anchor_mailto, @tag_order_stack);
my ($current_tag_object, $current_landmark, $landmark_marker);

my ($max_error_message_string) = 2048;

my (%testcase_data_objects);

#
# Status values
#
my ($clf_check_pass)       = 0;
my ($clf_check_fail)       = 1;

#
# Critical template file suffixes
#
my (%critical_template_file_suffix) = (
    "css", 1,
    "gif", 1,
    "html", 1,
    "ico", 1,
    "jpg", 1,
    "js", 1,
    "png", 1,
    "svg", 1,
    "swf", 1,
    "txt", 1,
);

#
# List of HTML tags that do not have an explicit end tag.
#
my (%html_tags_with_no_end_tag) = (
        "area", "area",
        "base", "base",
        "br", "br",
        "col", "col",
        "command", "command",
        "embed", "embed",
        "frame", "frame",
        "hr", "hr",
        "img", "img",
        "input", "input",
        "keygen", "keygen",
        "link", "link",
        "meta", "meta",
        "param", "param",
        "source", "source",
#        "track", "track",
        "wbr", "wbr",
);

#
# String table for error strings.
#
my %string_table_en = (
    "Apache SSI error message found", "Apache SSI error message found",
    "Application template used outside login, have target=_blank when not expected in navigation section",
        "Application template used outside login, have target=_blank when not expected in navigation section ",
    "Checksum failed for template file", "Checksum failed for template file",
    "Did not find web analytics code", "Did not find web analytics code ",
    "Displayed e-mail address",       "Displayed e-mail address",
    "DOCTYPE is not",                 "DOCTYPE is not",
    "does not match mailto",          "does not match 'mailto'",
    "expecting",                      "expecting ",
    "expecting one of",               "expecting one of ",
    "GC footer",                      "Government of Canada footer",
    "GC navigation bar",              "Government of Canada navigation bar",
    "IIS SSI error message found",    "IIS SSI error message found",
    "Invalid search action",          "Invalid search '<form action='",
    "Invalid search input value",     "Invalid search input value",
    "Invalid site includes version",  "Invalid site includes version",
    "Invalid template version",       "Invalid template version",
    "is not equal to last level",     " is not equal to last level ",
    "Link violations found",          "Link violations found, see link check results for details.",
    "Mismatch in site include file directory, found", "Mismatch in site include file directory, found",
    "Mismatch in site include file domain, found", "Mismatch in site include file domain, found",
    "Mismatch in template file directory, found", "Mismatch in template file directory, found",
    "Mismatch in template file domain, found", "Mismatch in template file domain, found",
    "Missing content section markers for", "Missing content section markers for ",
    "Missing web page template marker", "Missing web page template marker",
    "Multiple <h1> tags found in section", "Multiple <h1> tags found in section",
    "New heading level",              "New heading level ",
    "No template supporting files used from", "No template supporting files used from",
    "or more recent",                 "or more recent",
    "Site footer",                    "Site/application footer",
    "Site includes file not found",   "Site includes file not found",
    "Template file not found",        "Template file not found",
    );

#
# String table for error strings (French).
#
my %string_table_fr = (
    "Apache SSI error message found", "Message d'erreur Apache SSI trouvé",
        "Gabarit d'application utilisé en dehors connexion, avoir target = _blank lorsqu'il n'est pas prévu dans la section de navigation",
    "Application template used outside login, have target=_blank when not expected in navigation section",
    "Checksum failed for template file", "Checksum échoué pour le fichier de gabarit",
    "Did not find web analytics code", "Ne trouvez pas le code d'analyse Web ",
    "Displayed e-mail address",       "L'adresse courriel affichée",
    "DOCTYPE is not",                 "DOCTYPE ne pas",
    "does not match mailto",          "ne correspond pas au 'mailto'",
    "expecting",                      "expectant ",
    "expecting one of",               "expectant une de ",
    "GC footer",                      "Pied de page du gouvernement du Canada",
    "GC navigation bar",              "Barre de navigation du gouvernement du Canada",
    "IIS SSI error message found",    "Message d'erreur IIS SSI trouvé",
    "Invalid search action",          "'<form action=' non valide dans la recherche",
    "Invalid search input value",     "Valeur non valide saisie de recherche",
    "Invalid site includes version",  "Version des includes du site non valide",
    "Invalid template version",       "Version du gabarit non valide",
    "is not equal to last level",     " n'est pas égal à au dernier niveau ",
    "Mismatch in template file directory, found", "Erreur de correspondance des répertoire des fichier de gabarit, a trouvé",
    "Mismatch in template file domain, found", "Erreur de correspondance des domaine des fichier de gabarit, a trouvé",
    "Mismatch in site include file directory, found", "Erreur de correspondance des includes du site des fichier de gabarit, a trouvé",
    "Mismatch in site include file domain, found", "Erreur de correspondance des domaine des fichier des includes du site, a trouvé",
    "Missing content section markers for", "Manquantes marqueurs section de contenu pour les ",
    "Missing web page template marker", "Marqueur de gabarit pas trouvé",
    "Multiple <h1> tags found in section", "Plusieurs balises <h1> trouvé dans la section",
    "New heading level",              "Nouveau niveau d'en-tête ",
    "No template supporting files used from", "Pas de fichiers de gabarit de soutien utilisés par",
    "or more recent",                 "ou plus récent",
    "Site footer",                    "Pied de page du site ou de l'application",
    "Site includes file not found",   "Ficher des includes du site pas trouvé",
    "Template file not found",        "Ficher de gabarit pas trouvé",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#
#******************************************************************
#
# String table for testcase help URLs
#
#******************************************************************
#

my (%testcase_url_en, %testcase_url_fr);

#
# Default URLs to English
#
my ($url_table) = \%testcase_url_en;

#
# String tables for testcase ID to testcase descriptions
#
my (%testcase_description_en) = (
"TP_PW_ANALYTICS", "TP_PW_ANALYTICS: PWGSC Web Analytics",
"TP_PW_H",        "TP_PW_H: Heading structure",
"TP_PW_MAILTO",   "TP_PW_MAILTO: Invalid e-mail address in anchor in 'mailto' link",
"TP_PW_SITE",     "TP_PW_SITE: PWGSC site includes integrity",
"TP_PW_SRCH",     "TP_PW_SRCH: PWGSC search",
"TP_PW_SSI",      "TP_PW_SSI: Server side include",
"TP_PW_TECH",     "TP_PW_TECH: Baseline technologies",
"TP_PW_TEMPLATE", "TP_PW_TEMPLATE: Template integrity",
"TP_PW_URL",      "TP_PW_URL: Page addresses",
);

my (%testcase_description_fr) = (
"TP_PW_ANALYTICS", "TP_PW_ANALYTICS: Web Analytiques de TPSGC",
"TP_PW_H",        "TP_PW_H: Structure de l'en-tête",
"TP_PW_MAILTO",   "TP_PW_MAILTO: Adresse électronique invalide dans l'ancrage du lien 'mailto'",
"TP_PW_SITE",     "TP_PW_SITE: L'intégrité des fichier des includes du site",
"TP_PW_SRCH",     "TP_PW_SRCH: Recherche de TPSGC",
"TP_PW_SSI",      "TP_PW_SSI: Server side include",
"TP_PW_TECH",     "TP_PW_TECH: Technologies de base",
"TP_PW_TEMPLATE", "TP_PW_TEMPLATE: L'intégrité des fichier de gabarit",
"TP_PW_URL",      "TP_PW_URL: Adresses de page",
);

#
# Create reverse table, indexed by description
#
my (%reverse_testcase_description_en) = reverse %testcase_description_en;
my (%reverse_testcase_description_fr) = reverse %testcase_description_fr;
my ($reverse_testcase_description_table) = \%reverse_testcase_description_en;

#
# Default messages to English
#
my ($testcase_description_table) = \%testcase_description_en;

#***********************************************************************
#
# Name: Set_TP_PW_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_TP_PW_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;

    #
    # Set debug flag in supporting modules
    #
    Testcase_Data_Object_Debug($debug);
}

#**********************************************************************
#
# Name: Set_TP_PW_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_TP_PW_Check_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_TP_PW_Check_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
        $testcase_description_table = \%testcase_description_fr;
        $reverse_testcase_description_table = \%reverse_testcase_description_fr;
        $url_table = \%testcase_url_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_TP_PW_Check_Language, language = English\n" if $debug;
        $string_table = \%string_table_en;
        $testcase_description_table = \%testcase_description_en;
        $reverse_testcase_description_table = \%reverse_testcase_description_en;
        $url_table = \%testcase_url_en;
    }
}

#**********************************************************************
#
# Name: TP_PW_Check_Read_URL_Help_File
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
sub TP_PW_Check_Read_URL_Help_File {
    my ($filename) = @_;

    my (@fields, $tcid, $lang, $url);

    #
    # Clear out any existing testcase/url information
    #
    %testcase_url_en = ();
    %testcase_url_fr = ();

    #
    # Check to see that the help file exists
    #
    if ( !-f "$filename" ) {
        print "Error: Missing URL help file\n" if $debug;
        print " --> $filename\n" if $debug;
        return;
    }

    #
    # Open configuration file at specified path
    #
    print "TP_PW_Check_Read_URL_Help_File Openning file $filename\n" if $debug;
    if ( ! open(HELP_FILE, "$filename") ) {
        print "Failed to open file\n" if $debug;
        return;
    }

    #
    # Read file looking for testcase, language and URL
    #
    while (<HELP_FILE>) {
        #
        # Ignore comment and blank lines.
        #
        chop;
        if ( /^#/ ) {
            next;
        }
        elsif ( /^$/ ) {
            next;
        }

        #
        # Split the line into fields.
        #
        @fields = split(/\s+/, $_, 3);

        #
        # Did we get 3 fields ?
        #
        if ( @fields == 3 ) {
            $tcid = $fields[0];
            $lang = $fields[1];
            $url  = $fields[2];
            
            #
            # Do we have a testcase to match the ID ?
            #
            if ( defined($testcase_description_en{$tcid}) ) {
                print "Add Testcase/URL mapping $tcid, $lang, $url\n" if $debug;

                #
                # Do we have an English URL ?
                #
                if ( $lang =~ /eng/i ) {
                    $testcase_url_en{$tcid} = $url;
                    $reverse_testcase_description_en{$url} = $tcid;
                }
                #
                # Do we have a French URL ?
                #
                elsif ( $lang =~ /fra/i ) {
                    $testcase_url_fr{$tcid} = $url;
                    $reverse_testcase_description_fr{$url} = $tcid;
                }
                else {
                    print "Unknown language $lang\n" if $debug;
                }
            }
        }
        else {
            print "Line does not contain 3 fields, ignored: \"$_\"\n" if $debug;
        }
    }

    #
    # Close configuration file
    #
    close(HELP_FILE);
}

#**********************************************************************
#
# Name: TP_PW_Check_Testcase_URL
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase URL
# table for the specified key.
#
#**********************************************************************
sub TP_PW_Check_Testcase_URL {
    my ($key) = @_;

    #
    # Do we have a string table entry for this key ?
    #
    print "TP_PW_Check_Testcase_URL, key = $key\n" if $debug;
    if ( defined($$url_table{$key}) ) {
        #
        # return value
        #
        print "value = " . $$url_table{$key} . "\n" if $debug;
        return ($$url_table{$key});
    }
    #
    # Was the testcase description provided rather than the testcase
    # identifier ?
    #
    elsif ( defined($$reverse_testcase_description_table{$key}) ) {
        #
        # return value
        #
        $key = $$reverse_testcase_description_table{$key};
        print "value = " . $$url_table{$key} . "\n" if $debug;
        return ($$url_table{$key});
    }
    else {
        #
        # No string table entry, either we are missing a string or
        # we have a typo in the key name.
        #
        return;
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
# Name: Set_TP_PW_Check_Testcase_Data
#
# Parameters: profile - testcase profile
#             testcase - testcase identifier
#             data - string of data
#
# Description:
#
#   This function copies the passed data into a hash table
# for the specified testcase identifier.
#
#***********************************************************************
sub Set_TP_PW_Check_Testcase_Data {
    my ($profile, $testcase, $data) = @_;

    my ($type, $value, @markers, $object, $array, $hash);
    my ($field1, $field2);

    #
    # Do we have a testcase data object for this profile ?
    #
    if ( defined($testcase_data_objects{$profile}) ) {
        $object = $testcase_data_objects{$profile};
    }
    else {
        #
        # No testcase data object, create one
        #
        $object = testcase_data_object->new;
        $testcase_data_objects{$profile} = $object;
    }
    
    #
    # Do we have TP_PW_TEMPLATE testcase specific data ?
    #
    if ( $testcase eq "TP_PW_TEMPLATE" ) {
        #
        # Get the template data type
        #
        ($type, $value) = split(/\s+/, $data, 2);

        #
        # Do we have a template directory ?
        #
        if ( ($type eq "DIRECTORY") && defined($value) ) {
            if ( ! ($object->has_field("template_directory")) ) {
                $object->add_field("template_directory", "scalar");
                $object->set_scalar_field("template_directory", $value);
            }
        }
        #
        # Do we have template markers ?
        #
        elsif ( ($type eq "MARKERS") && defined($value) ) {
            @markers = split(/\s+/, $value);
            if ( ! ($object->has_field("required_template_markers")) ) {
                $object->add_field("required_template_markers", "hash");
            }
            $hash = $object->get_field("required_template_markers");
            
            #
            # Save marker values
            #
            foreach $value (@markers) {
                $$hash{$value} = 0;
            }
        }
        #
        # Do we have the template repository ?
        #
        elsif ( ($type eq "REPOSITORY") && defined($value) ) {
            if ( ! ($object->has_field("template_repository")) ) {
                $object->add_field("template_repository", "scalar");
                $object->set_scalar_field("template_repository", $value);
            }
        }
        #
        # Do we have a trusted domain ? one that we do not
        # have to perform a checksum on template files ?
        #
        elsif ( ($type eq "TRUSTED") && defined($value) ) {
            if ( ! ($object->has_field("trusted_template_domains")) ) {
                $object->add_field("trusted_template_domains", "hash");
            }
            $hash = $object->get_field("trusted_template_domains");

            #
            # Save trusted domain value
            #
            $$hash{$value} = 1;
        }
    }
    #
    # Do we have TP_PW_SRCH testcase specific data?
    #
    elsif ( $testcase eq "TP_PW_SRCH" ) {
        #
        # Get the search testcase data type
        #
        ($type, $value) = split(/\s+/, $data, 2);

        #
        # Save the possible action value
        #
        if ( ($type eq "ACTION") && defined($value) ) {
            if ( ! ($object->has_field("valid_search_actions")) ) {
                $object->add_field("valid_search_actions", "array");
            }
            $array = $object->get_field("valid_search_actions");
            push(@$array, $value);
        }
        #
        # Save possible input values
        #
        elsif ( ($type eq "INPUT") && defined($value) ) {
            #
            # Split the value portion into name & value
            #
            ($field1, $field2) = split(/\s+/, $value, 2);

            #
            # Do we have name & portion ?
            #
            if ( defined($field2) && ($field2 ne "") ) {
                if ( ! ($object->has_field("expected_search_inputs")) ) {
                    $object->add_field("expected_search_inputs", "hash");
                }

                $hash = $object->get_field("expected_search_inputs");
                $$hash{$field1} = $field2;
            }
        }
    }
    #
    # Do we have TP_PW_ANALYTICS testcase specific data?
    #
    elsif ( $testcase eq "TP_PW_ANALYTICS" ) {
        #
        # Save the possible web analytics value
        #
        if ( ! ($object->has_field("web_analytics_links")) ) {
            $object->add_field("web_analytics_links", "array");
        }
        $array = $object->get_field("web_analytics_links");
        push(@$array, $data);
    }
}

#***********************************************************************
#
# Name: Set_TP_PW_Check_Test_Profile
#
# Parameters: profile - TQA check test profile
#             clf_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by TQA testcase name.
#
#***********************************************************************
sub Set_TP_PW_Check_Test_Profile {
    my ($profile, $clf_checks ) = @_;

    my (%local_clf_checks);
    my ($key, $value, $object);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_TP_PW_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_clf_checks = %$clf_checks;
    $clf_check_profile_map{$profile} = \%local_clf_checks;
    
    #
    # Create a testcase data object for this profile if we don't have one
    #
    if ( ! defined($testcase_data_objects{$profile}) ) {
        $object = testcase_data_object->new;
        $testcase_data_objects{$profile} = $object;
    }
}

#**********************************************************************
#
# Name: Testcase_Description
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase description
# table for the specified key.  If there is no entry in the table an error
# string is returned.
#
#**********************************************************************
sub Testcase_Description {
    my ($key) = @_;

    #
    # Do we have a string table entry for this key ?
    #
    if ( defined($$testcase_description_table{$key}) ) {
        #
        # return value
        #
        return ($$testcase_description_table{$key});
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
# Name: Initialize_Test_Results
#
# Parameters: profile - TQA check test profile
#             local_results_list_addr - address of results list.
#
# Description:
#
#   This function initializes the test case results table.
#
#***********************************************************************
sub Initialize_Test_Results {
    my ($profile, $local_results_list_addr) = @_;
    
    my ($required_template_markers, $object);

    #
    # Get required template markers
    #
    $object = $testcase_data_objects{$profile};
    if ( $object->has_field("required_template_markers") ) {
        $required_template_markers = $object->get_field("required_template_markers");
    }

    #
    # Get the list of valid search actions
    #
    if ( $object->has_field("valid_search_actions") ) {
        $valid_search_actions = $object->get_field("valid_search_actions");
    }

    #
    # Get the set of expected search inputs
    #
    if ( $object->has_field("expected_search_inputs") ) {
        $expected_search_inputs = $object->get_field("expected_search_inputs");
    }

    #
    # Set current hash tables
    #
    $current_clf_check_profile = $clf_check_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;
    
    #
    # Initialize flags and counters
    #
    $current_landmark = "";
    $landmark_marker = "";
    @tag_order_stack = ();
    $current_clf_check_profile_name = $profile;
    $found_frame_tag = 0;
    $current_heading_level = 0;
    undef(@heading_level_stack);
    $have_text_handler = 0;
    %section_h1_count = ();
    $in_search_form = 0;
    $in_noscript = 0;
    if ( defined($required_template_markers) ) {
        %found_template_markers = %$required_template_markers;
    }
    else {
        %found_template_markers = ();
    }
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
    if ( defined($testcase) && defined($$current_clf_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $clf_check_fail,
                                                Testcase_Description($testcase),
                                                $line, $column, $text,
                                                $error_string, $current_url);
        $result_object->landmark($current_landmark);
        $result_object->landmark_marker($landmark_marker);
        push (@$results_list_addr, $result_object);

        #
        # Print error string to stdout
        #
        Print_Error($line, $column, $text, "$testcase : $error_string");
    }
}

#***********************************************************************
#
# Name: Declaration_Handler
#
# Parameters: text - declaration text
#             line - line number
#             column - column number
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the declaration line in an HTML document.
#
#***********************************************************************
sub Declaration_Handler {
    my ( $text, $line, $column ) = @_;

    my ($this_dtd, @dtd_lines, $testcase, $tcid);
    my ($top, $availability, $registration, $organization, $type, $label);
    my ($language, $url);

    #
    # Save declaration location
    #
    $doctype_line          = $line;
    $doctype_column        = $column;
    $doctype_text          = $text;

    #
    # Convert any newline or return characters into whitespace
    #
    $text =~ s/\r/ /g;
    $text =~ s/\n/ /g;

    #
    # Parse the declaration line to get its fields, we only care about the FPI
    # (Formal Public Identifier) field.
    #
    #  <!DOCTYPE root-element PUBLIC "FPI" ["URI"]
    #    [ <!-- internal subset declarations --> ]>
    #
    ($top, $availability, $registration, $organization, $type, $label, $language, $url) =
         $text =~ /^\s*\<!DOCTYPE\s+(\w+)\s+(\w+)\s+"(.)\/\/(\w+)\/\/(\w+)\s+([\w\s\.\d]*)\/\/(\w*)".*>\s*$/io;

    #
    # Did we get an FPI ?
    #
    if ( defined($label) ) {
        #
        # Parse out the language (HTML vs XHTML), the version number
        # and the class (e.g. strict)
        #
        $doctype_label = $label;
        ($doctype_language, $doctype_version, $doctype_class) =
            $doctype_label =~ /^([\w\s]+)\s+(\d+\.\d+)\s*(\w*)\s*.*$/io;
    }
    #
    # No Formal Public Identifier, perhaps this is a HTML 5 document ?
    #
    elsif ( $text =~ /\s*<!DOCTYPE\s+html>\s*/i ) {
        $doctype_label = "HTML";
        $doctype_version = 5.0;
        $doctype_class = "";
    }
    print "DOCTYPE label = $doctype_label, version = $doctype_version, class = $doctype_class\n" if $debug;
}

#***********************************************************************
#
# Name: Check_Baseline_Technologies
#
# Parameters: none
#
# Description:
#
#   This function checks that the appropriate baseline technologie is
# used in the web page.
#
#***********************************************************************
sub Check_Baseline_Technologies {

    my ($tcid);

    print "TP_PW_Check: Check_Baseline_Technologies\n" if $debug;
    
    #
    # Are we checking baseline technologies ?
    #
    if ( defined($$current_clf_check_profile{"TP_PW_TECH"}) ) {
        $tcid = "TP_PW_TECH";

        #
        # Were frames found within this web document ?
        #
        if ( $found_frame_tag ) {
            #
            # Is the doctype HTML 5 ?
            #
            if ( $doctype_label =~ /html/i ) {
                if ( $doctype_version < 5.0 ) {
                    Record_Result($tcid, $doctype_line,
                                  $doctype_column, "$doctype_text",
                                  String_Value("DOCTYPE is not") .
                                  " 'XHTML 1.0 Frameset' " .
                                  String_Value("or more recent"));
                }
            }
            #
            # Is the DOCTYPE a Frameset doctype ?
            #
            elsif ( ! ($doctype_label =~ /frameset/i) ) {
                Record_Result($tcid, $doctype_line,
                              $doctype_column, "$doctype_text",
                              String_Value("DOCTYPE is not") .
                              " 'XHTML 1.0 Frameset' " .
                              String_Value("or more recent"));
            }
        }
        else {
            #
            # Is the doctype XHTML Strict 1.0 or greater ?
            #
            if ( $doctype_label =~ /xhtml/i ) {
                if ( (! $doctype_label =~ /strict/i) && ($doctype_version < 1.0) ) {
                    Record_Result($tcid, $doctype_line, $doctype_column,
                                  "$doctype_text",
                                  String_Value("DOCTYPE is not") .
                                  " 'XHTML 1.0 Strict' " .
                                  String_Value("or more recent"));
                }
            }
            #
            # Is the doctype HTML 5 ?
            #
            elsif ( $doctype_label =~ /html/i ) {
                if ( $doctype_version < 5.0 ) {
                    Record_Result($tcid, $doctype_line, $doctype_column,
                                  "$doctype_text",
                                  String_Value("DOCTYPE is not") .
                                  " 'XHTML 1.0 Strict' " .
                                  String_Value("or more recent"));
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Frame_Tag_Handler
#
# Parameters: tag - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the frame or iframe tag, it looks for
# a title attribute.
#
#***********************************************************************
sub Frame_Tag_Handler {
    my ( $tag, $line, $column, $text, %attr ) = @_;

    my ($tcid, $title);

    #
    # Found a Frame tag, set flag so we can verify that the doctype
    # class is frameset.  We ignore frames inside a <noscript> tag.
    #
    if ( ! $in_noscript ) {
        $found_frame_tag = 1;
    }
}

#***********************************************************************
#
# Name: Check_Heading_Level
#
# Parameters: tagname - heading tag name
#             level - heading level
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function checks heading levels, it checks to see if they appear
# in order (h1, h2, h3, ...).
#
#***********************************************************************
sub Check_Heading_Level {
    my ($tagname, $level, $line, $column, $text) = @_;

    my ($section);

    #
    # Is the heading level a number ?
    #
    if ( ! ($level =~ /^\d+$/) ) {
        print "Non numeric heading level \"$level\"\n" if $debug;
        return;
    }

    #
    # Do we have a previous heading level ?
    #
    if ( $current_heading_level != 0 ) {
        #
        # Check heading number against current level, if it is
        # greater, it must be greater by 1.
        #
        if ( $level > $current_heading_level ) {
            if ( $level != ( $current_heading_level + 1 ) ) {
                #
                # New heading level is not equal to last one plus 1
                #
                Record_Result("TP_PW_H", $line, $column, $text,
                              String_Value("New heading level") . "'$level'" .
                              String_Value("is not equal to last level") .
                              "($current_heading_level) + 1");
            }
        }
    }

    #
    # Is this an H1 or aria-level="1" ?
    #
    if ( $level == 1 ) {
        #
        # Have we already found a <h1> in this content section ?
        #
        $section = $content_section_handler->current_content_section();
        if ( $section ne "" ) {
            if ( ! defined($section_h1_count{$section}) ) {
                $section_h1_count{$section} = 0;
                print "First <h1> tag found at $line:$column\n" if $debug;
            }
            else {
                #
                # Multiple <h1> tags in this section
                #
                print "Another <h1> tag found at $line:$column\n" if $debug;
                Record_Result("TP_PW_H", $line, $column, $text,
                              String_Value("Multiple <h1> tags found in section") . 
                              " $section");
            }

            #
            # Increment <h1> count
            #
            $section_h1_count{$section}++;
        }
    }

    #
    # Save new heading level and line number
    #
    $current_heading_level = $level;
}

#***********************************************************************
#
# Name: Start_H_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - heading tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the h tag, it checks to see if headings
# are created in order (h1, h2, h3, ...).
#
#***********************************************************************
sub Start_H_Tag_Handler {
    my ( $self, $tagname, $line, $column, $text, %attr ) = @_;

    my ($level, $section);

    #
    # Get heading level number from the tag
    #
    $level = $tagname;
    $level =~ s/^h//g;
    print "Found heading $tagname\n" if $debug;

    #
    # Check heading level
    #
    Check_Heading_Level($tagname, $level, $line, $column, $text);
}

#***********************************************************************
#
# Name: Anchor_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles anchor tags.
#
#***********************************************************************
sub Anchor_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($href);

    #
    # Add a text handler to save the text portion of the anchor
    # tag.
    #
    $self->handler( text => [], '@{dtext}' );
    $have_text_handler = 1;

    #
    # Do we have an href attribute
    #
    if ( defined( $attr{"href"} ) ) {
        $href = $attr{"href"};
        $href =~ s/^\s*//g;
        $href =~ s/\s*$//g;
        print "Anchor_Tag_Handler, href = \"$href\"\n" if $debug;

        #
        # Is it a mailto: link ?
        #
        if ( $href =~ /^mailto:/i ) {

            #
            # Save email address portion value in a global variable.
            #
            $href =~ tr/A-Z/a-z/;
            $current_anchor_mailto = $href;
        }
        else {
            $current_anchor_mailto = "";
        }
    }
}
 
#***********************************************************************
#
# Name: Form_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles form tags.
#
#***********************************************************************
sub Form_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($action, $subsection, $valid_action, $possible_action);

    #
    # Are we inside the site banner subsection ?
    #
    $subsection = $content_section_handler->current_content_subsection();
    if ( $subsection eq "SITE_BANNER" ) {
        #
        # Do we have an action attribute
        #
        if ( defined( $attr{"action"} ) ) {

            #
            # We assume we are in the search form.
            #
            $in_search_form = 1;

            #
            # Get the action value, remove any leading or trailing whitespace
            #
            $action = $attr{"action"};
            $action =~ s/^\s*//g;
            $action =~ s/\s*$//g;
            print "Form_Tag_Handler, action = \"$action\"\n" if $debug;

            #
            # Does the action match one of the expected values ?
            #
            if ( defined($valid_search_actions) &&
                 (@$valid_search_actions > 0) ) {
                $valid_action = 0;
                foreach $possible_action (@$valid_search_actions) {
                    if ( $action eq $possible_action ) {
                        $valid_action = 1;
                        last;
                    }
                }

                #
                # Did we find a valid search action value ?
                #
                if ( ! $valid_action ) {
                    Record_Result("TP_PW_SRCH", $line, $column, $text,
                                  String_Value("Invalid search action") .
                                  " '$action' " .
                                  String_Value("expecting one of") .
                                  join(", ", @$valid_search_actions));
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Input_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles input tags.
#
#***********************************************************************
sub Input_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($name, $value);

    #
    # Are we inside the site banner search form ?
    #
    if ( $in_search_form ) {
        #
        # Do we have a name attribute
        #
        if ( defined($attr{"name"}) ) {
            #
            # Get the name value, remove any leading or trailing whitespace
            #
            $name = $attr{"name"};
            $name =~ s/^\s*//g;
            $name =~ s/\s*$//g;
            print "Input_Tag_Handler, name = \"$name\"\n" if $debug;

            #
            # Does the name match one of the expected values ?
            #
            if ( defined($$expected_search_inputs{$name}) ) {
                #
                # Do we have a value attribute ?
                #
                if ( defined($attr{"value"}) ) {
                    $value = $attr{"value"};
                    $value =~ s/^\s*//g;
                    $value =~ s/\s*$//g;
                }
                else {
                    $value = "";
                }

                #
                # Does the value match the expected value ?
                #
                if ( $value ne $$expected_search_inputs{$name} ) {
                    Record_Result("TP_PW_SRCH", $line, $column, $text,
                                  String_Value("Invalid search input value") .
                                  " '$value' " .
                                  String_Value("expecting") .
                                  "\"" . $$expected_search_inputs{$name} . "\"");
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Attributes
#
# Parameters: self - reference to this parser
#             tagname - tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attrseq - reference to an array of attributes
#             attr - hash table of attributes
#
# Description:
#
#   This function checks common attributes for tags.
#
#***********************************************************************
sub Check_Attributes {
    my ($self, $tagname, $line, $column, $text, $attrseq, %attr) = @_;

    my ($level);

    #
    # Do we have a role attribute with the value heading ?
    #
    if ( defined($attr{"role"}) && ($attr{"role"} eq "heading") ) {
        #
        # Do we have a aria-level attribute to set the level of this
        # heading ?
        #
        if ( defined($attr{"aria-level"}) ) {
            $level = $attr{"aria-level"};
            $level =~ s/^\s*//g;
            $level =~ s/s*$//g;

            #
            # Check heading level
            #
            Check_Heading_Level($tagname, $level, $line, $column, $text);
        }
    }
}

#***********************************************************************
#
# Name: Noscript_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the noscript tag.
#
#***********************************************************************
sub Noscript_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Inside noscript, set global flag.
    #
    $in_noscript = 1;
}

#***********************************************************************
#
# Name: Start_Section_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start section tag. It saves the current heading
# level for the parent tag block and resets it to 0 for the section.
#
#***********************************************************************
sub Start_Section_Tag_Handler {
    my ($line, $column, $text, %attr) = @_;

    #
    # Save current heading level in the heading level stack.
    # Reset current heading level to 0 or unknown.
    #
    push(@heading_level_stack, $current_heading_level);
    $current_heading_level = 0;
}

#***********************************************************************
#
# Name: End_Section_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the end section tag. It restores the
# current heading level for the parent tag block.
#
#***********************************************************************
sub End_Section_Tag_Handler {
    my ($line, $column, $text) = @_;

    #
    # Restore current heading level from the heading level stack.
    #
    if ( @heading_level_stack > 0 ) {
        $current_heading_level = pop(@heading_level_stack);
    }
    else {
        #
        # Don't have a current heading level, perhaps there is a mismatch
        # in open and close section tags.  Set current heading level
        # to 0 or unknown.
        #
        $current_heading_level = 0;
    }
}

#***********************************************************************
#
# Name: Start_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             skipped_text - text since the last tag
#             attrseq - reference to an array of attributes
#             attr_hash - hash table of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the start of HTML tags.
#
#***********************************************************************
sub Start_Handler {
    my ($self, $tagname, $line, $column, $text, $skipped_text,
        $attrseq, %attr_hash) = @_;

    my ($id);

    #
    # Create a new tag object
    #
    print "Start_Handler tag $tagname at $line:$column\n" if $debug;
    $current_tag_object = tqa_tag_object->new($tagname, $line, $column,
                                              \%attr_hash);
    push(@tag_order_stack, $current_tag_object);

    #
    # Compute the current landmark and add it to the tag object.
    #
    ($current_landmark, $landmark_marker) = HTML_Landmark($tagname, $line,
                       $column, $current_landmark, $landmark_marker,
                       \@tag_order_stack, %attr_hash);
    $current_tag_object->landmark($current_landmark);
    $current_tag_object->landmark_marker($landmark_marker);

    #
    # Check for start of content section
    #
    $content_section_handler->check_start_tag($tagname, $line, $column,
                                              %attr_hash);

    #
    # Do we have an id attribute ? If so does it match one of the
    # required template markers ?
    #
    if ( defined($attr_hash{"id"}) && ($attr_hash{"id"} ne "") ) {
        $id = $attr_hash{"id"};
        if ( defined($found_template_markers{"$id"}) ) {
            $found_template_markers{"$id"} = 1;
            print "Found template marker $id\n" if $debug;
        }
    }

    #
    # Check tag attributes (e.g. role="heading")
    #
    Check_Attributes($self, $tagname, $line, $column, $text, $attrseq, %attr_hash);

    #
    # Check anchor tags
    #
    $tagname =~ s/\///g;
    if ( $tagname eq "a" ) {
        Anchor_Tag_Handler($self, $line, $column, $text, %attr_hash);
    }

    #
    # Check form tag
    #
    elsif ( $tagname eq "form" ) {
        Form_Tag_Handler($self, $line, $column, $text, %attr_hash);
    }

    #
    # Check frame tag
    #
    elsif ( $tagname eq "frame" ) {
        Frame_Tag_Handler("<frame>", $line, $column, $text, %attr_hash);
    }

    #
    # Check h tag
    #
    elsif ( $tagname =~ /^h[0-9]?$/ ) {
        Start_H_Tag_Handler($self, $tagname, $line, $column, $text,
                            %attr_hash);
    }

    #
    # Check input tag
    #
    elsif ( $tagname eq "input" ) {
        Input_Tag_Handler($self, $line, $column, $text, %attr_hash);
    }

    #
    # Check iframe tag
    #
    elsif ( $tagname eq "iframe" ) {
        Frame_Tag_Handler("<iframe>", $line, $column, $text, %attr_hash);
    }

    #
    # Check noscript tag
    #
    elsif ( $tagname eq "noscript" ) {
        Noscript_Tag_Handler($self, $line, $column, $text, %attr_hash);
    }

    #
    # Check section tag
    #
    elsif ( $tagname eq "section" ) {
        Start_Section_Tag_Handler($self, $line, $column, $text, %attr_hash);
    }

    #
    # Is this a tag that has no end tag ? If so we must set the last tag
    # seen value here rather than in the End_Handler function.
    #
    if ( defined ($html_tags_with_no_end_tag{$tagname}) ) {
        $current_tag_object = pop(@tag_order_stack);
        $current_landmark = $current_tag_object->landmark();
        $landmark_marker = $current_tag_object->landmark_marker();
    }
}

#***********************************************************************
#
# Name: Check_End_Anchor_Mailto
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             mailto_address - the mailto text
#             anchor_text_list - list of anchor text
#
# Description:
#
#   This function checks addresses in links that contain mailto:.
# It checks that the mailto: address matches the display address.
#
#***********************************************************************
sub Check_End_Anchor_Mailto {
    my ( $line, $column, $text, $mailto_address, @anchor_text_list ) = @_;

    my ($anchor_text, $found_match, $one_address, @mailto_address_list);

    #
    # Extract the e-mail address portion
    #
    $mailto_address =~ s/^mailto://;
    $mailto_address =~ s/\?.*//;
    $mailto_address =~ s/\&amp;*/\&/gi;
    #$mailto_address =~ s/\&.*//;
    $mailto_address =~ s/^\s*//g;
    print "Check_End_Anchor_Mailto: address = $mailto_address\n" if $debug;

    #
    # If we don't have a mailto address, don't compare to the anchor text.
    # We may be using the mailto: to create a template mail message
    # with no destination address (e.g. email a friend).
    #
    if ( $mailto_address ne "" ) {
        #
        # Split address on comma, we may have several addresses and as long
        # as one matches the anchor text we accept it.
        #
        @mailto_address_list = split(/,/, $mailto_address);
        $found_match = 0;
        foreach $one_address (@mailto_address_list) {
            #
            # Scan the anchor text looking for a string matching the
            # mailto address
            #
            print "Email address = $one_address\n" if $debug;
            foreach $anchor_text (@anchor_text_list) {
                $anchor_text =~ s/^\s*//g;
                $anchor_text =~ s/\s*$//g;
                $anchor_text =~ tr /A-Z/a-z/;
                print "Anchor text = $anchor_text\n" if $debug;

                #
                # Do we match the text ?
                #
                if ( $anchor_text eq $one_address ) {
                    $found_match = 1;
                    last;
                }
            }

            #
            # Did we find a match on this address ?
            #
            if ( $found_match ) {
                last;
            }
        }

        #
        # Did we find a match for the email address ?
        #
        if ( !$found_match ) {
            Record_Result("TP_PW_MAILTO", $line, $column, $text,
                          String_Value("Displayed e-mail address") .
                          " \"" . join("", @anchor_text_list) . "\" " .
                          String_Value("does not match mailto") .
                          " \"$mailto_address\"");
        }
    }
}

#***********************************************************************
#
# Name: End_Anchor_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end anchor </a> tag.
#
#***********************************************************************
sub End_Anchor_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my (@anchor_text_list);

    #
    # Get all the text & image paths found within the anchor tag
    #
    if ( ! $have_text_handler ) {
        print "End anchor tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }
    @anchor_text_list = @{ $self->handler("text") };

    #
    # Do we have a mail to address ?
    #
    if ( $current_anchor_mailto ne "" ) {
        #
        # Does mailto: value match display value ?
        #
        Check_End_Anchor_Mailto($line, $column, $text, $current_anchor_mailto,
                                @anchor_text_list);
                                
        #
        # Clear the mailto anchor
        #
        $current_anchor_mailto = "";
    }

    #
    # Destroy the text handler that was used to save the text
    # portion of the anchor tag.
    #
    $self->handler( "text", undef );
    $have_text_handler = 0;
}

#***********************************************************************
#
# Name: End_Form_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end form tag.
#
#***********************************************************************
sub End_Form_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    #
    # End of form, we can no longer be inside the search form
    #
    $in_search_form = 0;
}

#***********************************************************************
#
# Name: End_Noscript_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end noscript tag.
#
#***********************************************************************
sub End_Noscript_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    #
    # End of noscript
    #
    $in_noscript = 0;
}

#***********************************************************************
#
# Name: End_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end of HTML tags.
#
#***********************************************************************
sub End_Handler {
    my ( $self, $tagname, $line, $column, $text, @attr ) = @_;

    my (%attr_hash) = @attr;
    my ($popped_tag, $last_item);

    #
    # If this is an end anchor tag, reset current anchor href to empty string
    #
    print "End_Handler tag   $tagname at $line:$column\n" if $debug;
    if ( $tagname eq "a" ) {

        #
        # See if there are any problems with the anchor tag
        #
        End_Anchor_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check form tag
    #
    elsif ( $tagname eq "form" ) {
        End_Form_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check noscript tag
    #
    elsif ( $tagname eq "noscript" ) {
        End_Noscript_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Check section  tag
    #
    elsif ( $tagname eq "noscript" ) {
        End_Section_Tag_Handler($line, $column, $text);
    }

    #
    # Is this the end of a content area ?
    #
    $content_section_handler->check_end_tag($tagname, $line, $column);

    #
    # Pop last tag of the stack
    #
    if ( @tag_order_stack > 0 ) {
        $current_tag_object = pop(@tag_order_stack);
        if ( @tag_order_stack > 0 ) {
            $last_item = @tag_order_stack - 1;
            $current_tag_object = $tag_order_stack[$last_item];
            $current_landmark = $current_tag_object->landmark();
            $landmark_marker = $current_tag_object->landmark_marker();
        }
        else {
            $current_landmark = "";
            $landmark_marker = "";
        }
    }
    else {
        $current_landmark = "";
        $landmark_marker = "";
    }
}

#***********************************************************************
#
# Name: Check_Server_Side_Include_Errors
#
# Parameters: content - page content pointer
#
# Description:
#
#   This function checks for Apache server side include error messages
# in the content.  The message appears as the string
#    "[an error occurred while processing this directive]".
#
#***********************************************************************
sub Check_Server_Side_Include_Errors {
    my ($content) = @_;

    my ($text);

    #
    # Are we checking server side include errors ?
    #
    print "TP_PW_Check: Check_Server_Side_Include_Errors\n" if $debug;
    if ( defined($$current_clf_check_profile{"TP_PW_SSI"}) ) {

        #
        # Get text from HTML markup
        #
        $text = TextCat_Extract_Text_From_HTML($content);

        #
        # Check for Apache server side include error message
        #
        if ( $text =~ /\[an error occurred while processing this directive\]/i ) {
            Record_Result("TP_PW_SSI", -1, 0, "",
                          String_Value("Apache SSI error message found"));
        }

        #
        # Check for IIS server side include error message
        #
        if ( $text =~ /Error processing SSI file/i ) {
            Record_Result("TP_PW_SSI", -1, 0, "",
                          String_Value("IIS SSI error message found"));
        }
    }
}

#***********************************************************************
#
# Name: Check_Template_Markers
#
# Parameters: none
#
# Description:
#
#   This function checks to see that all required template markers
# were found.  If a marker was not found, the page did not use the proper
# web page template.
#
#***********************************************************************
sub Check_Template_Markers {

    my ($id, $missing_marker);

    #
    # Are we checking template markers ?
    #
    print "TP_PW_Check: Check_Template_Markers\n" if $debug;
    if ( defined($$current_clf_check_profile{"TP_PW_TEMPLATE"}) ) {
        #
        # Check for all required markers
        #
        $missing_marker = "";
        foreach $id (keys %found_template_markers) {
            print "Check for marker $id\n" if $debug;
            if ( ! $found_template_markers{$id} ) {
                print "Missing template marker $id\n" if $debug;
                $missing_marker = $id;
                last;
            }
        }

        #
        # Did we miss any template marker ?
        #
        if ( $missing_marker ne "" ) {
            Record_Result("TP_PW_TEMPLATE", -1, 0, "",
                          String_Value("Missing web page template marker") .
                          " \"$missing_marker\"");
        }
    }
}

#***********************************************************************
#
# Name: TP_PW_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             mime_type - mime type of content
#             resp - HTTP::Response object
#             content - content pointer
#
# Description:
#
#   This function runs a number of technical QA checks the content.
#
#***********************************************************************
sub TP_PW_Check {
    my ($this_url, $language, $profile, $mime_type, $resp, $content) = @_;

    my (@tqa_results_list, $parser, $result_object, @other_tqa_results_list);
    my ($tcid, $do_tests);

    #
    # Call the appropriate TQA check function based on the mime type
    #
    print "TP_PW_Check: URL $this_url, mime-type = $mime_type, lanugage = $language, profile = $profile\n" if $debug;

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Are any of the testcases defined in this module 
    # in the testcase profile ?
    #
    $do_tests = 0;
    foreach $tcid (keys(%testcase_description_en)) {
        if ( defined($$current_clf_check_profile{$tcid}) ) {
            $do_tests = 1;
            print "Testcase $tcid found in current testcase profile\n" if $debug;
            last;
        }
    }
    if ( ! $do_tests ) {
        #
        # No tests handled by this module
        #
        print "No tests handled by this module\n" if $debug;
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
        # Doesn't look like a URL.  Could be just a block of HTML
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Did we get any content ?
    #
    if ( length($$content) > 0 ) {
        #
        # Create a document parser
        #
        $parser = HTML::Parser->new;

        #
        # Create a content section object
        #
        $content_section_handler = content_sections->new;

        #
        # Add handlers for some of the HTML tags
        #
        $parser->handler(
            declaration => \&Declaration_Handler,
            "text,line,column"
        );
        $parser->handler(
            start => \&Start_Handler,
            "self,tagname,line,column,text,skipped_text,attrseq,\@attr"
        );
        $parser->handler(
            end => \&End_Handler,
            "self,tagname,line,column,text,\@attr"
        );

        #
        # Parse the content.
        #
        $parser->parse($$content);

        #
        # Check baseline technologies
        #
        Check_Baseline_Technologies();
    }
    else {
        print "No content passed to TP_PW_Check\n" if $debug;
        return(@tqa_results_list);
    }

    #
    # Check for Apache server side include errors. These show up
    # as "[an error occurred while processing this directive]" stings
    # on the web page.
    #
    Check_Server_Side_Include_Errors($content);

    #
    # Check tempplate markers, did we find all the required markers ?
    #
    Check_Template_Markers();
    
    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Checksum
#
# Parameters: content - content to checksum
#
# Description:
#
#    This function calculates the MD5 checksum of the supplied content.
#
#***********************************************************************
sub Checksum {
    my ($content) = @_;

    my ($filename, $checksum, $fh);

    #
    # Write the content to a file
    #
    ($fh, $filename) = tempfile("WPSS_TOOL_TP_PW_XXXXXXXXXX", TMPDIR => 1);
    if ( ! defined($fh) ) {
        print "Error: Failed to create temporary file in Checksum\n";
        return($checksum);
    }
    binmode $fh;
    print $fh $content;
    close($fh);

    #
    # Open the file for reading, read the content and generate checksum
    #
    open(FH, "$filename");
    binmode(FH);
    $checksum = Digest::MD5->new->addfile(*FH)->hexdigest;
    close(FH);
    unlink($filename);

    #
    # Return checksum value.
    #
    print "Calculated checksum = $checksum\n" if $debug;
    return($checksum);
}

#***********************************************************************
#
# Name: Verify_Template_Checksums
#
# Parameters: domain - protocol and domain of server
#             template_directory_parent - template top level directory
#             template_subdirectory - template subdirectory
#             profile - testcase profile
#
# Description:
#
#    This function verifies the checksum of all of the template files
# (images, CSS, JavaScript) to ensure no files have been modified or removed.
# It fetches the manifest file from the specified server and checks all
# files listed in that manifest.
#
#***********************************************************************
sub Verify_Template_Checksums {
    my ($domain, $template_directory_parent, $template_subdirectory,
        $profile) = @_;

    my ($manifest_url, $url, $resp, $line, $checksum, $file_path);
    my ($calculated_checksum, $object, $template_directory);
    my ($trusted_template_domains, @fields, $last_field);
    my ($critical_template_file, $content);

    #
    # Get testcase data object
    $object = $testcase_data_objects{$profile};
    
    #
    # Get hash table of trusted domains
    #
    $trusted_template_domains = $object->get_field("trusted_template_domains");

    #
    # Is this a trusted domain or a local file (domain = file:) ? 
    # if so we don't have to check the file checksums.
    #
    print "Verify_Template_Checksums for domain $domain\n" if $debug;
    if ( ($domain =~ /^file:/i) ||
         (defined($trusted_template_domains) &&
          defined($$trusted_template_domains{$domain})) ) {
        print "Skipping template checksums for domain $domain\n" if $debug;
        return;
    }

    #
    # Get template directory value
    #
    $template_directory = $object->get_field("template_directory");

    #
    # Have we already checked the template files for this domain ?
    #
    if ( ! defined($template_integrity{$domain}) ) {
        #
        # Construct the manifest URL from template subdirectory
        # (this file may not exist prior to WET 3.0.5 & 3.1.1)
        #
        $manifest_url = "$domain/$template_directory_parent$template_directory/$template_subdirectory/manifest.txt";

        #
        # Get the manifest file
        #
        print "Get template manifest file $manifest_url\n" if $debug;
        ($url, $resp) = Crawler_Get_HTTP_Response($manifest_url, "");

        #
        # Did we not get the manifest file ?
        #
        if ( ! defined($resp) || (! $resp->is_success) ) {
            #
            # Get the template manifest information from the template
            # top level directory.
            #
            $manifest_url = "$domain/$template_directory_parent$template_directory/manifest.txt";
            print "Get template manifest file $manifest_url\n" if $debug;
            ($url, $resp) = Crawler_Get_HTTP_Response($manifest_url, "");
        }

        #
        # Did we get the manifest file ?
        #
        if ( defined($resp) && $resp->is_success ) {
            #
            # The content of the manifest is expected to be 
            # <checksum> <file path>
            #
            foreach $line (split(/\n/, Crawler_Decode_Content($resp))) {
                #
                # Get checksum value and file path
                #
                ($checksum, $file_path) = split(/\s+/, $line, 2);
                
                #
                # Is this a critical file? Some template files are
                # not critical (e.g. demo pages), so if they are not
                # found, it is not an error.
                #
                @fields = split(/\./, $file_path);
                $last_field = @fields;
                if ( ($last_field > 0) &&
                     ( ! defined($critical_template_file_suffix{lc($fields[$last_field - 1])})) ) {
                    #
                    # Ignore error on non-critical file
                    #
                    print "Non-critical template file, $file_path\n" if $debug;
                    next;
                }

                #
                # See if we can get the file path from the server.
                # Get all critical files and those with an expected checksum
                # value (i.e. non zero checksum).
                #
                if ( defined($file_path) && ($checksum ne "0") ) {
                    $url = $domain . "/$template_directory_parent$file_path";
                    print "Get template file $url\n" if $debug;
                    ($url, $resp) = Crawler_Get_HTTP_Response($url,"");

                    #
                    # Did we get the file ?
                    #
                    if ( defined($resp) && $resp->is_success ) {
                        #
                        # Calculate checksum of the content unless the
                        # provided checksum is 0 (used to indicate the
                        # file should not be checksumed, e.g. an HTML file)
                        #
                        if ( $checksum ne "0" ) {
                            $content = Crawler_Decode_Content($resp);
                            $calculated_checksum = Checksum($content);
                        }
                        else {
                            $calculated_checksum = "0";
                        }

                        #
                        # Do the checksum values match ?
                        #
                        if ( $calculated_checksum ne $checksum ) {
                            print "Checksum values differ, $checksum != $calculated_checksum\n" if $debug;
                            
                            #
                            # Don't record checksum fails.  Some web server
                            # configurations appear to deliver different content
                            # than what is expected, which results in a
                            # checksum mismatch.
                            #
                            #Record_Result("TP_PW_TEMPLATE", -1, -1, "",
                            #              String_Value("Checksum failed for template file") .
                            #                           " \"$url\" ");
                        }
                    }
                    else {
                        #
                        # Failed to get template file.
                        #
                        Record_Result("TP_PW_TEMPLATE", -1, -1, "",
                                      String_Value("Template file not found") .
                                                      " \"$url\" ");
                    }
                }
            }
        }
        else {
            #
            # Failed to get manifest file
            #
            Record_Result("TP_PW_TEMPLATE", -1, -1, "",
                          String_Value("Template file not found") .
                                          " \"$manifest_url\" ");
        }

        #
        # Completed template integrity check for this domain.
        #
        $template_integrity{$domain} = 1;
    }
}

#***********************************************************************
#
# Name: Verify_Template_Version
#
# Parameters: domain - protocol and domain of server
#             template_directory_parent - template top level directory
#             template_subdirectory - template subdirectory
#             profile - testcase profile
#
# Description:
#
#    This function verifies the version of the template package.  It
# checks that the version on the supplied domain matches the version
# in the template repository.
#
#***********************************************************************
sub Verify_Template_Version {
    my ($domain, $template_directory_parent, $template_subdirectory,
        $profile) = @_;

    my ($version_url, $url, $resp, $line, $file_path);
    my ($local_version, $repository_versions, $version_string, $valid_version);
    my ($object, $template_directory, $template_repository);
    my ($trusted_template_domains);

    #
    # Get testcase data object
    #
    $object = $testcase_data_objects{$profile};

    #
    # Get hash table of trusted domains
    #
    $trusted_template_domains = $object->get_field("trusted_template_domains");

    #
    # Is this a trusted domain or a local file (domain = file:) ? 
    # if so we don't have to check the template version.
    #
    if ( ($domain =~ /^file:/i) ||
         (defined($trusted_template_domains) &&
          defined($$trusted_template_domains{$domain})) ) {
        print "Skipping template version check for domain $domain\n" if $debug;
        return;
    }

    #
    # Get template directory and repository values
    #
    $template_directory = $object->get_field("template_directory");
    $template_repository = $object->get_field("template_repository");

    #
    # Do we have a template repository value ?
    #
    if ( ! defined($template_directory) ) {
        return;
    }

    #
    # Have we already checked the template version for this domain ?
    #
    if ( ! defined($template_version{$domain}) ) {
        #
        # Get the template version information from template subdirectory
        # (this file may not exist prior to WET 3.0.5 & 3.1.1)
        #
        $version_url = "$domain/$template_directory_parent$template_directory/$template_subdirectory/version.txt";
        print "Get template version file $version_url\n" if $debug;
        ($url, $resp) = Crawler_Get_HTTP_Response($version_url, "");

        #
        # Did we not get the version file ?
        #
        if ( ! defined($resp) || (! $resp->is_success) ) {
            #
            # Get the template version information from the template
            # top level directory.
            #
            $version_url = "$domain/$template_directory_parent$template_directory/version.txt";
            print "Get template version file $version_url\n" if $debug;
            ($url, $resp) = Crawler_Get_HTTP_Response($version_url, "");
        }

        #
        # Did we get the version file ?
        #
        if ( defined($resp) && $resp->is_success ) {
            #
            # Get the template version value
            # Strip off any possible trailing CR/LF.
            #
            $local_version = $resp->content;
            chop($local_version);
            $local_version =~ s/\r$//g;
            $local_version =~ s/\n$//g;
            if ( length($local_version) > 100 ) {
                 $local_version = substr($local_version, 0, 100);
                 eval { $local_version =~ s/[^[:ascii:]]+//g; };
            }

            #
            # Get the repository version information.
            #
            $version_url = "$template_repository/valid_versions.txt";
            print "Get repository template valid version file $version_url\n" if $debug;
            ($url, $resp) = Crawler_Get_HTTP_Response($version_url, "");

            #
            # Did we get the version file ?
            #
            if ( defined($resp) && $resp->is_success ) {
                #
                # Get the repository template valid versions
                #
                $repository_versions = $resp->content;

                #
                # Check to see if this site's template version is in the
                # list of valid versions.
                #
                $valid_version = 0;
                foreach $version_string (split(/\n/, $repository_versions)) {
                    if ( $local_version eq $version_string ) {
                        print "Found valid version $version_string\n" if $debug;
                        $valid_version = 1;
                        last;
                   }
                }

                #
                # Did we find a valid version ?
                #
                if ( ! $valid_version ) {
                    print "Invalid template version $local_version, valid versions = $repository_versions\n" if $debug;
                    Record_Result("TP_PW_TEMPLATE", -1, -1, "",
                                  String_Value("Invalid template version") . 
                                  " \"$local_version\" " .
                                  String_Value("expecting one of") .
                                  " \"$repository_versions\"");
                }
            }
        }
        else {
            #
            # Failed to get version file
            #
            Record_Result("TP_PW_TEMPLATE", -1, -1, "",
                          String_Value("Template file not found") .
                                          " \"$version_url\" ");
        }

        #
        # Completed template version check for this domain.
        #
        $template_version{$domain} = 1;
    }
}

#***********************************************************************
#
# Name: Check_Template_Links
#
# Parameters: url - URL
#             link_sets - table of lists of link objects (1 list per
#               document section)
#             profile - testcase profile
#
# Description:
#
#    This function checks all the links to see if any reference the
# template files folder.  It checks that all of the references are to
# the same domain and same template subdirectory (version).
#
#***********************************************************************
sub Check_Template_Links {
    my ($url, $link_sets, $profile) = @_;

    my ($section, $list_addr, $link, $link_url, $protocol, $domain);
    my ($file_path, $query, $template_domain, $template_directory, $object);
    my ($template_link_count) = 0;
    my ($supporting_file_count) = 0;
    my ($template_directory_parent) = "";
    my ($template_subdirectory, $this_template_subdirectory);

    #
    # Get template directory and repository values
    #
    $object = $testcase_data_objects{$profile};
    $template_directory = $object->get_field("template_directory");

    #
    # Are we checking template integrity ?
    #
    if ( ! defined($$current_clf_check_profile{"TP_PW_TEMPLATE"}) ||
         ! defined($template_directory) ) {
        #
        # Skip check.
        #
        return;
    }

    #
    # Check each document section's list of links
    #
    while ( ($section, $list_addr) = each %$link_sets ) {
        print "Check template links in section $section\n" if $debug;

        #
        # Check each link in the section
        #
        foreach $link (@$list_addr) {
            $link_url = $link->abs_url;
            $current_landmark = $link->landmark();
            $landmark_marker = $link->landmark_marker();

            #
            # Break URL into components
            #
            ($protocol, $domain, $file_path, $query) = URL_Check_Parse_URL($link_url);

            #
            # Is this a supporting file (e.g. CSS or JavaScript ?)
            #
            if ( ($file_path =~ /\.css$/i) || ($file_path =~ /\.js$/i) ) {
                $supporting_file_count++;
            }

            #
            # Do we have any template files yet ? If not check for
            # the 'template directory' path anywhere in the file path.
            # The site may be setup with the template directory as a
            # subdirectory rather than at the root level.
            #
            if ( ($template_link_count == 0) && 
                 ($file_path =~ /\/$template_directory\//) ) {
                print "Template directory is not at the root\n" if $debug;
                $template_directory_parent = $file_path;
                $template_directory_parent =~ s/\/$template_directory\/.*/\//;
                print "Template parent directory is $template_directory_parent\n" if $debug;
            }

            #
            # Does the file path start with the template directory ?
            #
            if ( $file_path =~ /^$template_directory_parent$template_directory\// ) {
                print "Found template file reference $link_url\n" if $debug;
                $template_link_count++;

                #
                # Get the template subdirectory, i.e. if the supporting file
                # is under the path
                #   /boew-wet/wet3.0/js/
                # The template parent directory is /boew-wet and the
                # template subdirectory is wet3.0
                #
                $this_template_subdirectory = $file_path;
                $this_template_subdirectory =~ s/^$template_directory_parent$template_directory\///g;
                $this_template_subdirectory =~ s/\/.*$//g;

                #
                # Have we seen a template subdirectory yet ?
                # if not use this one.
                #
                if ( ! defined($template_subdirectory) ) {
                    $template_subdirectory = $this_template_subdirectory;
                }

                #
                # Do we have a domain yet ?
                #
                if ( ! defined($template_domain) ) {
                    #
                    # No domain, use this one as the expected
                    # domain for any other template file references.
                    #
                    $template_domain = "$protocol//$domain";
                }

                #
                # Does the domain of the supporting file match
                # the previous supporting files ?
                #
                if ( $template_domain ne "$protocol//$domain" ) {
                    #
                    # Domain mismatch
                    #
                    print "Domain mismatch in template file references\n" if $debug;
                    Record_Result("TP_PW_TEMPLATE", $link->line_no, 
                                  $link->column_no, $link->source_line,
                       String_Value("Mismatch in template file domain, found") .
                                  " \"$protocol//$domain\" " . 
                                  String_Value("expecting") .
                                  "\"$template_domain\"");
                }

                #
                # Does the subdirectory of the supporting file match
                # the previous supporting files ?
                #
                if ( $this_template_subdirectory ne $template_subdirectory ) {
                    #
                    # Subdirectory mismatch
                    #
                    print "Template subdirectory mismatch in template file references\n" if $debug;
                    Record_Result("TP_PW_TEMPLATE", $link->line_no, 
                                  $link->column_no, $link->source_line,
                       String_Value("Mismatch in template file directory, found") .
                                  " \"$this_template_subdirectory\" " . 
                                  String_Value("expecting") .
                                  "\"$template_subdirectory\"");
                }
            }
        }
    }

    #
    # Did we get a template file domain ?
    #
    if ( defined($template_domain) ) {
        #
        # Verify checksum values of the template files.
        #
        Verify_Template_Checksums($template_domain, $template_directory_parent,
                                  $template_subdirectory, $profile);

        #
        # Verify the template version
        #
        Verify_Template_Version($template_domain, $template_directory_parent,
                                $template_subdirectory, $profile);
    }

    #
    # Did we find any template files ? We should have found several
    # CSS, JavaScript and GIF files.
    #
    if ( ($supporting_file_count > 0 ) && ($template_link_count == 0) ) {
        print "Found $supporting_file_count supporting files and 0 template files\n" if $debug;
        Record_Result("TP_PW_TEMPLATE", -1, -1, "",
                      String_Value("No template supporting files used from") .
                      " $protocol//$domain/$template_directory");
    }

    #
    # Return the path of the template parent directory
    #
    return($template_directory_parent);
}

#***********************************************************************
#
# Name: Check_Site_Includes_Links
#
# Parameters: url - URL
#             link_sets - table of lists of link objects (1 list per
#               document section)
#             profile - testcase profile
#             template_directory_parent - parent directory of the template
#               files
#
# Description:
#
#    This function checks all the links to see if any reference the
# site files folder.  It checks that all of the references are to
# the same domain and same subdirectory (version).
#
#***********************************************************************
sub Check_Site_Includes_Links {
    my ($url, $link_sets, $profile, $template_directory_parent) = @_;

    my ($section, $list_addr, $link, $link_url, $protocol, $domain);
    my ($file_path, $query, $site_inc_domain, $site_inc_directory, $object);
    my ($site_inc_link_count) = 0;
    my ($site_inc_directory_parent) = "";
    my ($site_inc_subdirectory, $this_site_inc_subdirectory);

    #
    # Get site includes directory value
    #
    $object = $testcase_data_objects{$profile};
    $site_inc_directory = $object->get_field("site_inc_directory");

    #
    # Are we checking site includes integrity ?
    #
    if ( ! defined($$current_clf_check_profile{"TP_PW_SITE"}) ||
         ! defined($site_inc_directory) ) {
        #
        # Skip check.
        #
        return;
    }

    #
    # Get the expected domain for the site includes
    #
    ($protocol, $domain, $file_path, $query) = URL_Check_Parse_URL($url);
    $site_inc_domain = "$protocol//$domain";

    #
    # Check each document section's list of links
    #
    while ( ($section, $list_addr) = each %$link_sets ) {
        print "Check site include links in section $section\n" if $debug;

        #
        # Check each link in the section
        #
        foreach $link (@$list_addr) {
            $link_url = $link->abs_url;
            $current_landmark = $link->landmark();
            $landmark_marker = $link->landmark_marker();

            #
            # Break URL into components
            #
            ($protocol, $domain, $file_path, $query) = URL_Check_Parse_URL($link_url);

            #
            # Is this a supporting file (e.g. CSS or JavaScript ?)
            #
            if ( ! ( ($file_path =~ /\.css$/i) || 
                     ($file_path =~ /\.js$/i) ) ) {
                #
                # Not a supporting file, don't check it.
                #
                next;
            }

            #
            # Do we have any site include files yet ? If not check for
            # the 'site includes directory' path anywhere in the file path.
            # The site may be setup with the site includes directory as a
            # subdirectory rather than at the root level.
            #
            if ( ($site_inc_link_count == 0) && 
                 ($file_path =~ /\/$site_inc_directory\//) ) {
                print "Site includes directory is not at the root\n" if $debug;
                $site_inc_directory_parent = $file_path;
                $site_inc_directory_parent =~ s/\/$site_inc_directory\/.*/\//;
                print "Site includes parent directory is $site_inc_directory_parent\n" if $debug;
            }

            #
            # Does the file path start with the site includes directory ?
            #
            if ( $file_path =~ /^$site_inc_directory_parent$site_inc_directory\// ) {
                print "Found site includes file reference $link_url\n" if $debug;
                $site_inc_link_count++;

                #
                # Get the site includes subdirectory, i.e. if the supporting
                # file is under the path
                #   /site/wet3.0/html5/
                # The site includes parent directory is /site and the
                # subdirectory is wet3.0
                #
                $this_site_inc_subdirectory = $file_path;
                $this_site_inc_subdirectory =~ s/^$site_inc_directory_parent$site_inc_directory\///g;
                $this_site_inc_subdirectory =~ s/\/.*$//g;

                #
                # Have we seen a site includes subdirectory yet ?
                # if not use this one.
                #
                if ( ! defined($site_inc_subdirectory) ) {
                    $site_inc_subdirectory = $this_site_inc_subdirectory;
                }

                #
                # Does the domain of the supporting file match
                # the expected domain ?
                #
                if ( "$protocol//$domain" ne $site_inc_domain ) {
                    #
                    # Domain mismatch
                    #
                    print "Domain mismatch in site includes file references\n" if $debug;
                    Record_Result("TP_PW_SITE", $link->line_no, 
                                  $link->column_no, $link->source_line,
                       String_Value("Mismatch in site include file domain, found") .
                                  " \"$protocol//$domain\" " . 
                                  String_Value("expecting") .
                                  "\"$site_inc_domain\"");
                }

                #
                # Does the subdirectory of the supporting file match
                # the previous supporting files ?
                #
                if ( $this_site_inc_subdirectory ne $site_inc_subdirectory ) {
                    #
                    # Subdirectory mismatch
                    #
                    print "Site include subdirectory mismatch in file references\n" if $debug;
                    Record_Result("TP_PW_SITE", $link->line_no, 
                                  $link->column_no, $link->source_line,
                       String_Value("Mismatch in site include file directory, found") .
                                  " \"$this_site_inc_subdirectory\" " . 
                                  String_Value("expecting") .
                                  "\"$site_inc_subdirectory\"");
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_New_Window_Attribute
#
# Parameters: logged_in - flag to indicate if we are logged into an
#               application
#             link - link object
#             section - navigation section
#
# Description:
#
#    This function checks to see if the supplied link opens a new
# window using the target attribute.  It then checks to see if the
# behaviour matches the expected behaviour for the current logged in status.
#
# Returns:
#  0 - link has an error
#  1 - link is ok
#
#***********************************************************************
sub Check_New_Window_Attribute {
    my ($logged_in, $link, $section) = @_;

    my (%attr, $have_new_window);

    #
    # Get attributes of the anchor tag
    #
    %attr = $link->attr;
    $current_landmark = $link->landmark();
    $landmark_marker = $link->landmark_marker();

    #
    # Does the link open in a new window ? i.e. target="_blank"
    #
    if ( defined($attr{"target"}) && ($attr{"target"} =~ /_blank/i) ) {
        print "Have target=\"_blank\"\n" if $debug;
        $have_new_window = 1;
    }
    else {
        print "Do not have target=\"_blank\"\n" if $debug;
        $have_new_window = 0;
    }

    #
    # Is the new window status appropriate for the logged in state ?
    #
    if ( $have_new_window && ( ! $logged_in ) ) {
        #
        # We are not logged in so we should not open navigation in new
        # windows.
        #
        print "Have target=\"_blank\" when not logged in\n" if $debug;
        Record_Result("TP_PW_TEMPLATE", $link->line_no, $link->column_no, 
                      $link->source_line,
                      String_Value("Application template used outside login, have target=_blank when not expected in navigation section") . 
                      " \"$section\"");

        #
        # Return non success
        #
        return(0);
    }

    #
    # Link is ok, return success
    #
    return(1);
}

#***********************************************************************
#
# Name: Check_Application_Template_Navigation
#
# Parameters: url - URL
#             link_sets - table of lists of link objects (1 list per
#               document section)
#             logged_in - flag to indicate if we are logged into an
#               application
#
# Description:
#
# This function checks GC and site navigation for the use of 
# target="_blank" outside a login. This suggests the use of 
# application templates outside the login.
#
#***********************************************************************
sub Check_Application_Template_Navigation {
    my ($url, $link_sets, $logged_in) = @_;

    my ($list_addr, $link, $link_count, $i);

    #
    # Check GC Navigation links
    #
    print "Check_Application_Template_Navigation: check GC Navigation links\n" if $debug;
    if ( defined($$link_sets{"GC_NAV"}) ) {
        $list_addr = $$link_sets{"GC_NAV"};
        $link_count = @$list_addr;

        #
        # Check each link to see that they have the expected
        # "Open in new window" status.
        #
        $i = 0;
        foreach $link (@$list_addr) {
            #
            # Get landmark details
            #
            $current_landmark = $link->landmark();
            $landmark_marker = $link->landmark_marker();

            #
            # Check anchor links only
            #
            $i++;
            if ( $link->link_type eq "a" ) {
                #
                # Exclude the last link as it may be the language link.
                # it may not have the same new window attribute as the
                # rest of the GC navigation links.
                #
                if ( $i < $link_count ) {
                    #
                    # Check for consistent new window attribute
                    #
                    if ( ! Check_New_Window_Attribute($logged_in, $link, 
                                               String_Value("GC navigation bar")) ) {
                        #
                        # Stop after first occurance
                        #
                        return();
                    }
                }
            }
        }
    }

    #
    # Check site footer links
    #
    print "Check site footer links\n" if $debug;
    if ( defined($$link_sets{"SITE_FOOTER"}) ) {
        $list_addr = $$link_sets{"SITE_FOOTER"};

        #
        # Check each link to see that they have the expected
        # "Open in new window" status.
        #
        foreach $link (@$list_addr) {
            #
            # Get landmark details
            #
            $current_landmark = $link->landmark();
            $landmark_marker = $link->landmark_marker();

            #
            # Check anchor links only
            #
            if ( $link->link_type eq "a" ) {
                #
                # Check for consistent new window attribute
                #
                if ( ! Check_New_Window_Attribute($logged_in, $link, 
                                           String_Value("Site footer")) ) {
                    #
                    # Stop after first occurance
                    #
                    return();
                }
            }
        }
    }

    #
    # Check GC footer links
    #
    print "Check GC footer links\n" if $debug;
    if ( defined($$link_sets{"GC_FOOTER"}) ) {
        $list_addr = $$link_sets{"GC_FOOTER"};

        #
        # Check each link to see that they have the expected
        # "Open in new window" status.
        #
        foreach $link (@$list_addr) {
            #
            # Get landmark details
            #
            $current_landmark = $link->landmark();
            $landmark_marker = $link->landmark_marker();

            #
            # Check anchor links only
            #
            if ( $link->link_type eq "a" ) {
                #
                # Check for consistent new window attribute
                #
                if ( ! Check_New_Window_Attribute($logged_in, $link, 
                                           String_Value("GC footer")) ) {
                    #
                    # Stop after first occurance
                    #
                    return();
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Web_Analytics_Link
#
# Parameters: url - URL
#             link_sets - table of lists of link objects (1 list per
#               document section)
#             logged_in - flag to indicate if we are logged into an
#               application
#             profile - testcase profile
#
# Description:
#
# This function checks for the presence of Web Analytics links
# (e.g. link to piwik.php).
#
#***********************************************************************
sub Check_Web_Analytics_Link {
    my ($url, $link_sets, $logged_in, $profile) = @_;

    my ($section, $list_addr, $link, $link_url, $pattern, $analytics_patterns);
    my ($object, $pattern_list);
    my ($found_analytics_link) = 0;

    #
    # Are we logged in ? If so, skip check for analytics link as it is
    # unlikely to be included on web pages behind a login.
    #
    if ( $logged_in ) {
        print "Skip Check_Web_Analytics_Link behind login\n" if $debug;
        return;
    }
    #
    # Get web analytics patterns value
    #
    print "Check_Web_Analytics_Link\n" if $debug;
    $object = $testcase_data_objects{$profile};
    if ( defined($object) ) {
        $analytics_patterns = $object->get_field("web_analytics_links");
        
        #
        # Do we have any patterns ?
        #
        if ( defined($analytics_patterns) ) {
            $pattern_list = join(", ", @$analytics_patterns);
        }
    }
    
    #
    # Do we have any analytics patterns ?
    #
    if ( (! defined($pattern_list)) || ($pattern_list eq "") ) {
        #
        # No web analytics values
        #
        print "No web analytics values defined\n" if $debug;
        return;
    }

    #
    # Check each document section's list of links
    #
    while ( ($section, $list_addr) = each %$link_sets ) {
        print "Check site include links in section $section\n" if $debug;

        #
        # Check each link in the section
        #
        foreach $link (@$list_addr) {
            $link_url = $link->abs_url;
            $current_landmark = $link->landmark();
            $landmark_marker = $link->landmark_marker();

            #
            # Check each possible analytics pattern
            #
            foreach $pattern (@$analytics_patterns) {
                print "Check for pattern \"$pattern\" in \"$link_url\"\n" if $debug;
                if ( index($link_url, $pattern) != -1 ) {
                    print "Found web analytics pattern $pattern\n" if $debug;
                    $found_analytics_link = 1;
                    last;
                }
            }

            #
            # Did we find a pattern match ?
            #
            if ( $found_analytics_link ) {
                last;
            }
        }

        #
        # Did we find a pattern match ?
        #
        if ( $found_analytics_link ) {
            last;
        }
    }

    #
    # Did we not find an analytics link ?
    #
    if ( ! $found_analytics_link ) {
        $current_landmark = "body";
        $landmark_marker = "<body>";
        Record_Result("TP_PW_ANALYTICS", -1, -1, "",
                      String_Value("Did not find web analytics code") .
                                  String_Value("expecting one of") .
                                  join(", ", @$analytics_patterns));
    }
}

#***********************************************************************
#
# Name: TP_PW_Check_Links
#
# Parameters: tqa_results_list - address of hash table results
#             url - URL
#             profile - testcase profile
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#             logged_in - flag to indicate if we are logged into an
#               application
#
# Description:
#
#    This function performs a number of checks on links found within a
# document.  It checks that all template references (e.g. css) are
# made to the same domain.  
#
#***********************************************************************
sub TP_PW_Check_Links {
    my ($tqa_results_list, $url, $profile, $language, $link_sets,
        $logged_in) = @_;

    my ($result_object, @local_tqa_results_list, $list_addr);
    my ($expected_link_list_addr, @empty_list, $tcid, $do_tests);
    my ($template_directory_parent);

    #
    # Do we have a valid profile ?
    #
    print "TP_PW_Check_Links: profile = $profile, language = $language\n" if $debug;
    if ( ! defined($clf_check_profile_map{$profile}) ) {
        print "Unknown testcase profile passed $profile\n" if $debug;
        return;
    }

    #
    # Initialize the test case pass/fail table.
    #
    $current_clf_check_profile = $clf_check_profile_map{$profile};
    $results_list_addr = \@local_tqa_results_list;
    $current_landmark = "";
    $landmark_marker = "";

    #
    # Are any of the testcases defined in this module
    # in the testcase profile ?
    #
    $do_tests = 0;
    foreach $tcid (keys(%testcase_description_en)) {
        if ( defined($$current_clf_check_profile{$tcid}) ) {
            $do_tests = 1;
            print "Testcase $tcid found in current testcase profile\n" if $debug;
            last;
        }
    }
    if ( ! $do_tests ) {
        #
        # No tests handled by this module
        #
        print "No tests handled by this module\n" if $debug;
        return();
    }

    #
    # Save URL in global variable
    #
    if ( ($url =~ /^http/i) || ($url =~ /^file/i) ) {
        $current_url = $url;
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of HTML
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Check for links to the template folder (defined in the testcase
    # data).
    #
    $template_directory_parent = Check_Template_Links($url, $link_sets,
                                                      $profile);

    #
    # Check for links to the site includes folder (defined in the testcase
    # data).
    #
    Check_Site_Includes_Links($url, $link_sets, $profile, 
                              $template_directory_parent);

    #
    # Check GC and site navigation for the use of target="_blank" outside
    # a login. This suggests the use of application templates outside the
    # login.
    #
    Check_Application_Template_Navigation($url, $link_sets, $logged_in);

    #
    # Check for web analytics links.
    #
    Check_Web_Analytics_Link($url, $link_sets, $logged_in, $profile);

    #
    # Add our results to previous results
    #
    foreach $result_object (@local_tqa_results_list) {
        push(@$tqa_results_list, $result_object);
    }
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

