#***********************************************************************
#
# Name:   clf20_check.pm
#
# $Revision: 6738 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/CLF_Check/Tools/clf20_check.pm $
# $Date: 2014-07-25 14:53:18 -0400 (Fri, 25 Jul 2014) $
#
# Description:
#
#   This file contains routines that parse HTML files and check for
# a number of Common Look and Feel CLF 2.0 check points.
#
# Public functions:
#     Set_CLF20_Check_Language
#     Set_CLF20_Check_Debug
#     Set_CLF20_Check_Testcase_Data
#     Set_CLF20_Check_Test_Profile
#     CLF20_Check_Read_URL_Help_File
#     CLF20_Check_Testcase_URL
#     CLF20_Check_Other_Tool_Results
#     CLF20_Check
#     CLF20_Check_Links
#     CLF20_Check_Archive_Check
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

package clf20_check;

use strict;
use HTML::Entities;
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
    @EXPORT  = qw(Set_CLF20_Check_Language
                  Set_CLF20_Check_Debug
                  Set_CLF20_Check_Testcase_Data
                  Set_CLF20_Check_Test_Profile
                  CLF20_Check_Read_URL_Help_File
                  CLF20_Check_Testcase_URL
                  CLF20_Check_Other_Tool_Results
                  CLF20_Check
                  CLF20_Check_Links
                  CLF20_Check_Archive_Check
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (%testcase_data);
my (@paths, $this_path, $program_dir, $program_name, $paths);

my (%clf_check_profile_map, $current_clf_check_profile);
my ($results_list_addr, $content_section_handler);
my ($doctype_line, $doctype_column, $doctype_text, $doctype_label);
my ($doctype_version, $doctype_language, $doctype_class, $found_frame_tag);
my (%content_subsection_found, %other_tool_results, $current_url);
my ($current_heading_level, $have_text_handler, %section_h1_count);

my ($max_error_message_string) = 2048;

#
# Common menu bar item 1 options
#
my (@common_menu_item_1_eng) = ("Fran\&ccedil;ais", "Avertissement");
my (@common_menu_item_1_fra) = ("English", "Notice");
my (%common_menu_item_1) = (
    "eng", \@common_menu_item_1_eng,
    "fra", \@common_menu_item_1_fra
);

#
# Common menu bar items 2 through 5.
# The first item (language switch) is handled separately.
# The last item is skipped as the text changes between Internet, GC Intranet
# and Intranet.
#
my (@common_menu_items_2_5_eng) = ("", "Home", "Contact Us", "Help", "Search");
my (@common_menu_items_2_5_fra) = ("", "Accueil", "Contactez-nous", "Aide",
                                   "Recherche");
my (@common_menu_items_2_5_dut) = ("", "Startpagina", "Contact", "Help", "Zeoken");
my (@common_menu_items_2_5_ita) = ("", "Home", "Contatti", "Aiuto", "Ricerca");
my (@common_menu_items_2_5_por) = ("", "P&aacute;gina Inicia", "Fale conosco", "Ajuda", "Busca");
my (@common_menu_items_2_5_spa) = ("", "P&aacute;gina principal ", "Cont&aacute;ctenos", "Ayuda", "B&uacute;squeda");
my (%common_menu_items_2_5) = (
    "eng", \@common_menu_items_2_5_eng,
    "fra", \@common_menu_items_2_5_fra,
    "dut", \@common_menu_items_2_5_dut,
    "ita", \@common_menu_items_2_5_ita,
    "por", \@common_menu_items_2_5_por,
    "spa", \@common_menu_items_2_5_spa,
);

#
# Proactive disclosure link anchor text (in left hand menu)
#
my (%proactive_disclosure_anchor) = (
    "dut", "Pro-actieve bekendmaking",
    "eng", "Proactive Disclosure",
    "fra", "Divulgation proactive",
    "ita", "Divulgazione proattiva",
    "por", "Divulga&ccedil;&atilde;o proativa",
    "spa", "Divulgaci&oacute;n proactiva",
);

#
# Top of page link anchor text (in footer)
#
my (%top_of_page_anchor) = (
    "dut", "Bovenaan pagina",
    "eng", "Top of Page",
    "fra", "Haut de la page",
    "ita", "Inizio pagina",
    "por", "Topo da p&aacute;gina",
    "spa", "Arriba",
);

#
# Important notices link anchor text (in footer)
#
my (%important_notices_anchor) = (
    "dut", "Belangrijke mededelingen",
    "eng", "Important Notices",
    "fra", "Avis importants",
    "ita", "Avvisi importanti",
    "por", "Avisos Importantes",
    "spa", "Avisos Importantes",
);

#
# Status values
#
my ($clf_check_pass)       = 0;
my ($clf_check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "at line:column",                 " at (line:column) ",
    "Found",                          "Found",
    "previously found",               "previously found",
    "in",                             " in ",
    "Navigation link",                "Navigation link ",
    "out of order, should precede",   " out of order, should precede ",
    "must be last link",              " must be the last link in the left navigation",
    "in URL",                         " in URL ",
    "Missing content section markers for", "Missing content section markers for ",
    "links in common menu bar",       "links in common menu bar",
    "Missing footer link",            "Missing footer link",
    "Invalid anchor text",            "Invalid anchor text ",
    "for common menu bar item #",     " for common menu bar item # ",
    "expecting",                      " expecting ",
    "DOCTYPE is not",                 "DOCTYPE is not",
    "or more recent",                 "or more recent",
    "Link violations found",          "Link violations found, see link check results for details.",
    "New heading level",             "New heading level ",
    "is not equal to last level",    " is not equal to last level ",
    "Displayed e-mail address does not match mailto",  "Displayed e-mail address does not match 'mailto'",
    "Multiple <h1> tags found in section", "Multiple <h1> tags found in section",
    );

#
# String table for error strings (French).
#
my %string_table_fr = (
    "at line:column",                 " à (la ligne:colonne) ",
    "Found",                          "trouvé",
    "previously found",               "trouvé avant",
    "in",                             " dans ",
    "Navigation link",                "Lien de navigation ",
    "out of order, should precede",   " de l'ordre, doit précéder ",
    "must be last link",              " doivent être dernier lien dans le menu de gauche",
    "in URL",                         " dans URL ",
    "Missing content section markers for", "Manquantes marqueurs section de contenu pour les ",
    "links in common menu bar",       "liens dans la barre de menu commune",
    "Missing footer link",            "Manquantes lien dans pieds de page",
    "Invalid anchor text",            "Invalide le texte d'ancre ",
    "for common menu bar item #",     " pour l'élément barre de menu commune # ",
    "expecting",                      " expectant ",
    "DOCTYPE is not",                 "DOCTYPE ne pas",
    "or more recent",                 "ou plus récent",
    "Link violations found",          "Violations Lien trouvé, voir les résultats vérifier le lien pour plus de détails.",
    "New heading level",              "Nouveau niveau d'en-tête ",
    "is not equal to last level",    " n'est pas égal à au dernier niveau ",
    "Displayed e-mail address does not match mailto", "L'adresse courriel affichée ne correspond pas au 'mailto'",
    "Multiple <h1> tags found in section", "Plusieurs balises <h1> trouvé dans la section",
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
"TBS_P1_R2", "TBS Part 1, R2: Page addresses",
"TBS_P2_R1_2.2", "TBS Part 2, R1 2.2: Colour Contrast",
"TBS_P2_R1_11.2", "TBS Part 2, R1 11.2: Deprecated elements",
"TBS_P2_R1_13.1", "TBS Part 2, R1 13.1: Link Targets",
"TBS_P2_R2", "TBS Part 2, R2: Baseline technologies",
"TBS_P3_R2.4", "TBS Part 3, R2.4: Heading structure",
"TBS_P3_R5", "TBS Part 3, R5: Common menu bar",
"TBS_P3_R10", "TBS Part 3, R10: Proactive Disclosure",
"TBS_P3_R13.3", "TBS Part 3, R13.3: Top of page link",
"TBS_P3_R13.4", "TBS Part 3, R13.4: Important Notices link",

#
# PWGSC Checkpoints
#
"TP_PW_ARCHIVE",   "TP_PW_ARCHIVE: Archived Web page notice",
"CLF2.0_TEMPLATE", "TEMPLATE: Missing template section marker",
"MAILTO_ANCHOR",   "MAILTO: Invalid e-mail address in anchor in 'mailto' link",
);

my (%testcase_description_fr) = (
"TBS_P1_R2", "SCT Partie 1, E2: Adresses de page",
"TBS_P2_R1_2.2", "SCT Partie 2, E1 2.2: Contraste des couleurs",
"TBS_P2_R1_11.2", "SCT Partie 2, E1 11.2: Éléments proscrits",
"TBS_P2_R1_13.1", "SCT Partie 2, E1 13.1: Cibles de lien",
"TBS_P2_R2", "SCT Partie 2, E1: Technologies de base",
"TBS_P3_R2.4", "SCT Partie 3, E2.4: Structure de l'en-tête",
"TBS_P3_R5", "SCT Partie 3, E5: Barre de menu commune",
"TBS_P3_R10", "SCT Partie 3, E10: Divulgation Proactive",
"TBS_P3_R13.3", "SCT Partie 3, E13.3: Lien Haut de la page",
"TBS_P3_R13.4", "SCT Partie 3, E13.4: Lien Avis importants",

#
# PWGSC Checkpoints
#
"TP_PW_ARCHIVE",   "TP_PW_ARCHIVE: Avis de page Web archivie",
"CLF2.0_TEMPLATE", "TEMPLATE: TEMPLATE",
"MAILTO_ANCHOR",   "MAILTO: Adresse électronique invalide dans l'ancrage du lien 'mailto'",
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
# Name: Set_CLF20_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_CLF20_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_CLF20_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_CLF20_Check_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_CLF20_Check_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
        $testcase_description_table = \%testcase_description_fr;
        $reverse_testcase_description_table = \%reverse_testcase_description_fr;
        $url_table = \%testcase_url_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_CLF20_Check_Language, language = English\n" if $debug;
        $string_table = \%string_table_en;
        $testcase_description_table = \%testcase_description_en;
        $reverse_testcase_description_table = \%reverse_testcase_description_en;
        $url_table = \%testcase_url_en;
    }
}

#**********************************************************************
#
# Name: CLF20_Check_Read_URL_Help_File
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
sub CLF20_Check_Read_URL_Help_File {
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
    print "CLF20_Check_Read_URL_Help_File Openning file $filename\n" if $debug;
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
# Name: CLF20_Check_Testcase_URL
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase URL
# table for the specified key.
#
#**********************************************************************
sub CLF20_Check_Testcase_URL {
    my ($key) = @_;

    #
    # Do we have a string table entry for this key ?
    #
    print "CLF20_Check_Testcase_URL, key = $key\n" if $debug;
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
# Name: Set_CLF20_Check_Testcase_Data
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
sub Set_CLF20_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_CLF20_Check_Test_Profile
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
sub Set_CLF20_Check_Test_Profile {
    my ($profile, $clf_checks ) = @_;

    my (%local_clf_checks);
    my ($key, $value);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_CLF20_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_clf_checks = %$clf_checks;
    $clf_check_profile_map{$profile} = \%local_clf_checks;
}

#***********************************************************************
#
# Name: CLF20_Check_Other_Tool_Results
#
# Parameters: tool_results - hash table of tool & results
#
# Description:
#
#   This function copies the tool/results hash table into a global
# variable.  The key is a tool name (e.g. "link check") and the
# value is a pass (0) or fail (1).
#
#***********************************************************************
sub CLF20_Check_Other_Tool_Results {
    my (%tool_results) = @_;

    #
    # Copy value to global variable
    #
    %other_tool_results = %tool_results;
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

    #
    # Set current hash tables
    #
    $current_clf_check_profile = $clf_check_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;
    
    #
    # Initialize flags and counters
    #
    $found_frame_tag = 0;
    $current_heading_level = 0;
    $have_text_handler = 0;
    %section_h1_count = ();
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

    print "CLF20_Check: Check_Baseline_Technologies\n" if $debug;
    
    #
    # Are we checking baseline technologies ?
    #
    if ( defined($$current_clf_check_profile{"TBS_P2_R2"}) ) {
        $tcid = "TBS_P2_R2";

        #
        # Were frames found within this web document ?
        #
        if ( $found_frame_tag ) {
            #
            # Is the DOCTYPE a Frameset doctype ?
            #
            if ( ! ($doctype_label =~ /frameset/i) ) {
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
    # class is frameset
    #
    $found_frame_tag = 1;
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
#             level - heading level
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
                Record_Result("TBS_P3_R2.4", $line, $column, $text,
                              String_Value("New heading level") . "'$level'" .
                              String_Value("is not equal to last level") .
                              "($current_heading_level) + 1");
            }
        }
    }

    #
    # Is this an H1 ?
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
                Record_Result("TBS_P3_R2.4", $line, $column, $text,
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
        #
        # Save the href value in a global variable.  We may need it when
        # processing the end of the anchor tag.
        #
        $href = $attr{"href"};
        $href =~ s/^\s*//g;
        $href =~ s/\s*$//g;
        print "Anchor_Tag_Handler, href = \"$href\"\n" if $debug;

        #
        # Is it a mailto: link ?
        #
        if ( $href =~ /^mailto:/i ) {

            #
            # Save email address portion
            #
            $href =~ tr/A-Z/a-z/;
            push( @{ $self->handler("text") }, $href );
        }
    }
}

#***********************************************************************
#
# Name: Start_Handler
#
# Parameters: self - reference to this parser
#             language - url language
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             skipped_text - text since the last tag
#             attrseq - reference to an array of attributes
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the start of HTML tags.
#
#***********************************************************************
sub Start_Handler {
    my ( $self, $language, $tagname, $line, $column, $text, $skipped_text,
         $attrseq, @attr ) = @_;

    my (%attr_hash) = @attr;

    #
    # Check for start of content section
    #
    $content_section_handler->check_start_tag($tagname, $line, $column,
                                              %attr_hash);

    #
    # See which content subsection we are in
    #
    if ( $content_section_handler->current_content_subsection() ne "" ) {
        $content_subsection_found{$content_section_handler->current_content_subsection()} = 1;
    }

    #
    # Check anchor tags
    #
    $tagname =~ s/\///g;
    if ( $tagname eq "a" ) {
        Anchor_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check frame tag
    #
    elsif ( $tagname eq "frame" ) {
        Frame_Tag_Handler( "<frame>", $line, $column, $text, %attr_hash );
    }

    #
    # Check iframe tag
    #
    elsif ( $tagname eq "iframe" ) {
        Frame_Tag_Handler( "<iframe>", $line, $column, $text, %attr_hash );
    }

    #
    # Check h tag
    #
    elsif ( $tagname =~ /^h[0-9]?$/ ) {
        Start_H_Tag_Handler( $self, $tagname, $line, $column, $text,
                            %attr_hash );
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
    $mailto_address =~ s/\&amp;.*//i;
    $mailto_address =~ s/\&.*//;
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
            Record_Result("MAILTO_ANCHOR", $line, $column, $text,
                          String_Value("Displayed e-mail address does not match mailto"));
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

    my ($this_text, @anchor_text_list);

    #
    # Get all the text & image paths found within the anchor tag
    #
    if ( ! $have_text_handler ) {
        print "End anchor tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }
    @anchor_text_list = @{ $self->handler("text") };

    #
    # Loop through the text items
    #
    foreach $this_text (@anchor_text_list) {

        #
        # Do we have a mailto ?
        #
        if ( $this_text =~ /^mailto:/ ) {

            #
            # Does mailto: value match display value ?
            #
            Check_End_Anchor_Mailto($line, $column, $text, $this_text,
                                    @anchor_text_list);
        }
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
    # Is this the end of a content area ?
    #
    $content_section_handler->check_end_tag($tagname, $line, $column);
}

#***********************************************************************
#
# Name: Check_Document_Errors
#
# Parameters: none
#
# Description:
#
#   This function checks test cases that act on the document as a whole.
#
#***********************************************************************
sub Check_Document_Errors {

    my ($name, @required_content_subsections, $tcid);
    my ($all_content_sections_found) = 1;
    my ($missing_content_sections) = "";

    #
    # Determine the testcase ID
    #
    print "CLF20_Check: Check_Document_Errors\n" if $debug;
    if ( defined($$current_clf_check_profile{"CLF2.0_TEMPLATE"}) ) {
        $tcid = "CLF2.0_TEMPLATE";
    }

    #
    # Get list of content sections
    #
    if ( defined($testcase_data{$tcid}) ) {
        @required_content_subsections = split(/\s+/, $testcase_data{$tcid});
        print "Required content sections for testcase $tcid are " .
              join(", ", @required_content_subsections) . "\n" if $debug;
    }
    else {
        print "No required content sections for testcase $tcid\n" if $debug;
    }
    
    #
    # Check for missing content subsections, we use this to determine if
    # the proper HTML template was used.
    #
    foreach $name (@required_content_subsections) {
        if ( ! $content_subsection_found{$name} ) {
            $all_content_sections_found = 0;
            $missing_content_sections .= "$name ";
        }
    }
    if ( ! $all_content_sections_found ) {
        Record_Result($tcid, -1, 0, "",
                      String_Value("Missing content section markers for") .
                      $missing_content_sections);
    }
}

#***********************************************************************
#
# Name: Check_Other_Tool_Results
#
# Parameters: none
#
# Description:
#
#   This function checks the other_tool_results hash table to see
# if the results of other tools (e.g. link check) should be recorded
# as TQA failures.
#
#***********************************************************************
sub Check_Other_Tool_Results {

    my (@tqa_results_list, $result_object, $tcid, $orig_results_list_addr);

    #
    # Save address of our results list
    #
    $orig_results_list_addr = $results_list_addr;
    $results_list_addr = \@tqa_results_list;

    #
    # Do we have link check failures ?
    #
    if ( defined($other_tool_results{"link check"}) &&
         ($other_tool_results{"link check"} == 1) ) {

        #
        # Are we checking links ?
        #
        if ( defined($$current_clf_check_profile{"TBS_P2_R1_13.1"}) ) {
            $tcid = "TBS_P2_R1_13.1";

            Record_Result($tcid, -1, -1, "",
                          String_Value("Link violations found"));
        }
    }

    #
    # Restore original results list address
    #
    $results_list_addr = $orig_results_list_addr;

    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: CLF20_Check
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
sub CLF20_Check {
    my ( $this_url, $language, $profile, $mime_type, $resp, $content ) = @_;

    my (@tqa_results_list, $parser, $result_object, @other_tqa_results_list);
    my ($tcid, $do_tests);

    #
    # Call the appropriate TQA check function based on the mime type
    #
    print "CLF20_Check: URL $this_url, mime-type = $mime_type, lanugage = $language, profile = $profile\n" if $debug;

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
            "self,\"$language\",tagname,line,column,text,skipped_text,attrseq,\@attr"
        );
        $parser->handler(
            end => \&End_Handler,
            "self,tagname,line,column,text,\@attr"
        );

        #
        # Parse the content.
        #
        $parser->parse($$content);
    }
    else {
        print "No content passed to CLF20_Check\n" if $debug;
        return(@tqa_results_list);
    }

    #
    # Check baseline technologies
    #
    Check_Baseline_Technologies();
    
    #
    # Check for errors that are detected one we analyse the entire document.
    #
    Check_Document_Errors();

    #
    # Check the Other Tool Results hash table to see if
    # results from other tools should be recorded as TQA failures.
    #
    @other_tqa_results_list = Check_Other_Tool_Results();

    #
    # Add results from Other Tool Results check into those from
    # the previous check to get resuilts for the entire document.
    #
    foreach $result_object (@other_tqa_results_list) {
        push(@tqa_results_list, $result_object);
    }

    #
    # Clear other tool results values so we don't
    # carry them over from this document to the next.
    #
    %other_tool_results = ();

    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Trim_Whitespace
#
# Parameters: string
#
# Description:
#
#   This function removes leading and trailing whitespace from a string.
# It also collapses multiple whitespace sequences into a single
# white space.
#
#***********************************************************************
sub Trim_Whitespace {
    my ($string) = @_;

    #
    # Remove leading & trailing whitespace
    #
    $string =~ s/^\s*//g;
    $string =~ s/\s*$//g;
    $string =~ s/\r*$//g;
    $string =~ s/\n*$//g;

    #
    # Compress whitespace
    #
    $string =~ s/\s+/ /g;

    #
    # Return trimmed string.
    #
    return($string);
}

#***********************************************************************
#
# Name: Check_Left_Navigation_Links
#
# Parameters: url - URL
#             language - URL language
#             list_addr - list of link objects
#
# Description:
#
#    This function checks the left hand navigation links.
#
#***********************************************************************
sub Check_Left_Navigation_Links {
    my ($url, $language, $list_addr) = @_;

    my ($link, $link_count, $tcid, $link_no);

    #
    # Do we have a language for this URL ?
    #
    if ( $language eq "" ) {
        return;
    }

    #
    # Check for possible "Proactive Disclosure"/"Divulgation proactive"
    # link, it must be the last link in the list if it exists.
    #
    print "Check_Left_Navigation_Links\n" if $debug;
    $tcid = "TBS_P3_R10";
    if ( defined($$current_clf_check_profile{$tcid})  &&
         defined($proactive_disclosure_anchor{$language}) ) {
        #
        # Get number of links in navigation
        #
        $link_count = @$list_addr;
        print "Have $link_count links, looking for \"" . $proactive_disclosure_anchor{$language} . "\"\n" if $debug;

        #
        # Scan the links looking for possible proactive discloseure link.
        #
        $link_no = 1;
        foreach $link (@$list_addr) {
            print "Check link \"" . $link->anchor . "\"\n" if $debug;
            if ( encode_entities($link->anchor) eq 
                 $proactive_disclosure_anchor{$language} ) {
                #
                # Got proactive disclosure, is this the last link ?
                #
                if ( $link_no < $link_count ) {
                    Record_Result($tcid, $link->line_no, $link->column_no,
                              $link->source_line, 
                              $proactive_disclosure_anchor{$language} . 
                              String_Value("must be last link"));
                }
            }

            #
            # Increment link number
            #
            $link_no++;
        }
    }    
}

#***********************************************************************
#
# Name: Check_Common_Menu_Bar_Links
#
# Parameters: url - URL
#             language - URL language
#             list_addr - list of link objects
#
# Description:
#
#    This function checks the common menu bar navigation links.
#
#***********************************************************************
sub Check_Common_Menu_Bar_Links {
    my ($url, $language, $list_addr) = @_;

    my ($link, $link_count, $tcid, $link_no, @links, $expected_anchor_text);
    my ($anchor_text, $valid_anchor, $possible_anchor_text);
    my ($possible_anchor_text_list) = "";

    #
    # Check that the common menu bar links appear with the correct
    # anchor text and in the correct order.
    #
    $tcid = "TBS_P3_R5";
    if ( defined($$current_clf_check_profile{$tcid}) ) {
        #
        # Get number of links in navigation
        #
        print "Check_Common_Menu_Bar_Links language = $language\n" if $debug;
        $link_count = @$list_addr;
        
        #
        # Did we find at least 6 links ? (should only be 6 unless there are
        # non standard items 
        # [e.g. http://btb.termiumplus.gc.ca/tpv2alpha/alpha-eng.html?lang=eng ]
        #
        if ( $link_count < 6 ) {
            Record_Result($tcid, -1, -1, "",
                          String_Value("Found") . " $link_count " .
                          String_Value("links in common menu bar"));
        }
        else {
            #
            # Do we have menu items for this language?
            #
            if ( ! defined($common_menu_item_1{$language}) ) {
                return;
            }

            #
            # Check value of the anchor text for the first item.  This
            # is handles separately as there are several possible values.
            #
            @links = @$list_addr;
            $link = $links[0];
            $anchor_text = decode_entities($link->anchor);
            $anchor_text = encode_entities($anchor_text);
            $expected_anchor_text = $common_menu_item_1{$language};
            $valid_anchor = 0;
            print "Check link # 0, have $anchor_text\n" if $debug;
            foreach $possible_anchor_text (@$expected_anchor_text) {
                print "Check against $possible_anchor_text\n" if $debug;
                if ( Trim_Whitespace($anchor_text) eq $possible_anchor_text ) {
                    $valid_anchor = 1;
                    last;
                }
                $possible_anchor_text_list .= " \"$possible_anchor_text\"";
            }

            #
            # Did we find a match on one of the possible values ?
            #
            if ( ! $valid_anchor ) {
                Record_Result($tcid, $link->line_no, $link->column_no,
                              $link->source_line,
                              String_Value("Invalid anchor text") .
                              "'" . $link->anchor . "'" .
                              String_Value("for common menu bar item #") .
                              1 . String_Value("expecting") .
                              "'" . $possible_anchor_text_list . "'");
            }

            #
            # Check values of the anchor text for items 2 through 5
            # (6th item is skipped as the value changes by network scope).
            #
            $expected_anchor_text = $common_menu_items_2_5{$language};
            for ($link_no = 1; $link_no < 5; $link_no++) {
                $link = $links[$link_no];
                print "Check link # $link_no, have " . $link->anchor .
                      " expecting " . $$expected_anchor_text[$link_no] . "\n" if $debug;

                #
                # Does the anchor text match what is expected ?
                #
                if ( encode_entities(Trim_Whitespace($link->anchor)) ne 
                     $$expected_anchor_text[$link_no] ) {
                    Record_Result($tcid, $link->line_no, $link->column_no,
                                  $link->source_line,
                                  String_Value("Invalid anchor text") .
                                  "'" . $link->anchor . "'" .
                                  String_Value("for common menu bar item #") .
                                  ($link_no + 1) . String_Value("expecting") .
                                  "'" . $$expected_anchor_text[$link_no] . "'");
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Footer_Links
#
# Parameters: url - URL
#             language - URL language
#             list_addr - list of link objects
#
# Description:
#
#    This function checks the footer links.
#
#***********************************************************************
sub Check_Footer_Links {
    my ($url, $language, $list_addr) = @_;

    my ($link, $top_of_page_link, $top_of_page_text, $important_notices_text);
    my ($found_top_of_page) = 0;
    my ($found_important_notices) = 0;
    my ($anchor_text);

    #
    # Do we have footer links defined for this language?
    #
    if ( ! defined($top_of_page_anchor{$language}) ) {
        return;
    }
    $top_of_page_text = $top_of_page_anchor{$language};
    $important_notices_text = $important_notices_anchor{$language};

    #
    # Check values of the anchor text.
    #
    foreach $link (@$list_addr) {
        #
        # Strip off any newline, leading or trailing white space
        #
        $anchor_text = Trim_Whitespace($link->anchor);
        $anchor_text = encode_entities($anchor_text);

        #
        # Is this "Top of Page"
        #
        print "Footer link $anchor_text\n" if $debug;
        if ( $anchor_text eq $top_of_page_text ) {
            $found_top_of_page = 1;
        }
        #
        # Is this a "Top of Page" link with extra text (e.g. alt text on
        # image) ?
        #
        elsif ( $anchor_text =~ /$top_of_page_text/i ) {
            $top_of_page_link = $link;
        }
        #
        # Is this "Important Notices ?
        #
        elsif ( $anchor_text eq $important_notices_text ) {
            $found_important_notices = 1;
        }
    }

    #
    # Did we find the Top of Page ?
    #
    if ( ! $found_top_of_page ) {
        #
        # Did we find a link that is "Top of Page" link with extra text
        # (e.g. alt text on image) ?
        #
        if ( defined($top_of_page_link) ) {
            Record_Result("TBS_P3_R13.3", -1, -1, "",
                          String_Value("Missing footer link") .
                          " '" . $top_of_page_anchor{$language} . "'. " .
                          String_Value("Found") . " '" .
                          $top_of_page_link->anchor . "' " .
                          String_Value("at line:column") .
                          $top_of_page_link->line_no . ":" .
                          $top_of_page_link->column_no);
        }
        else {
            Record_Result("TBS_P3_R13.3", -1, -1, "",
                          String_Value("Missing footer link") .
                          " '" . $top_of_page_anchor{$language} . "'");
        }
    }

    #
    # Did we find the Important Notices ?
    #
    if ( ! $found_important_notices ) {
        Record_Result("TBS_P3_R13.4", -1, -1, "",
                      String_Value("Missing footer link") .
                      " '" . $important_notices_anchor{$language} . "'");
    }
}

#***********************************************************************
#
# Name: CLF20_Check_Links
#
# Parameters: tqa_results_list - address of hash table results
#             url - URL
#             profile - testcase profile
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function performs a number of checks on links found within a
# document.  Checks are performed on the common menu bar, left
# navigation and footer.
#
#***********************************************************************
sub CLF20_Check_Links {
    my ($tqa_results_list, $url, $profile, $language, $link_sets) = @_;

    my ($result_object, @local_tqa_results_list, $list_addr);
    my ($tcid, $do_tests, @local_archive_tqa_results_list);

    #
    # Do we have a valid profile ?
    #
    print "CLF20_Check_Links: profile = $profile, language = $language\n" if $debug;
    if ( ! defined($clf_check_profile_map{$profile}) ) {
        print "Unknown TQA testcase profile passed $profile\n" if $debug;
        return;
    }

    #
    # Initialize the test case pass/fail table.
    #
    $current_clf_check_profile = $clf_check_profile_map{$profile};
    $results_list_addr = \@local_tqa_results_list;

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
    # Check common menu bar links
    #
    if ( defined($$link_sets{"COMMON_MENU"}) ) {
        $list_addr = $$link_sets{"COMMON_MENU"};
        Check_Common_Menu_Bar_Links($url, $language, $list_addr);
    }
    else {
        print "No COMMON_MENU links\n" if $debug;
    }

    #
    # Check left hand page navigation
    #
    if ( defined($$link_sets{"LEFT_NAV"}) ) {
        $list_addr = $$link_sets{"LEFT_NAV"};
        Check_Left_Navigation_Links($url, $language, $list_addr);
    }
    else {
        print "No LEFT_NAV links\n" if $debug;
    }

    #
    # Check footer links
    #
    if ( defined($$link_sets{"FOOTER"}) ) {
        $list_addr = $$link_sets{"FOOTER"};
        Check_Footer_Links($url, $language, $list_addr);
    }
    else {
        print "No FOOTER links\n" if $debug;
    }

    #
    # Add our results to previous results
    #
    foreach $result_object (@local_tqa_results_list) {
        push(@$tqa_results_list, $result_object);
    }

    #
    # Check Archived links
    #
    if ( defined($$current_clf_check_profile{"TP_PW_ARCHIVE"}) ) {
        @local_archive_tqa_results_list = CLF_Archive_Check_Links($url,
                                              $profile, "TP_PW_ARCHIVE",
                                              Testcase_Description("TP_PW_ARCHIVE"),
                                              $link_sets);
    }

    #
    # Add our results to previous results
    #
    foreach $result_object (@local_archive_tqa_results_list) {
        push(@$tqa_results_list, $result_object);
    }
}

#***********************************************************************
#
# Name: CLF20_Check_Archive_Check
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
#   This function runs a number of technical QA checks on content that
# is marked as archived on the web.
#
#***********************************************************************
sub CLF20_Check_Archive_Check {
    my ( $this_url, $language, $profile, $mime_type, $resp, $content ) = @_;

    my (@tqa_results_list, $result_object, $message);

    #
    # Initialize the test case pass/fail table.
    #
    print "CLF20_Check_Archive_Check URL $this_url, mime-type = $mime_type, lanugage = $language, profile = $profile\n" if $debug;
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Are we doing archived on the web checking ?
    #
    if ( defined($$current_clf_check_profile{"TP_PW_ARCHIVE"}) ) {
        #
        # Check for archived on the web markers
        #
        $message = CLF_Archive_Archive_Check($profile, $this_url, $content);

        #
        # Did we get messages (implying the check failed) ?
        #
        if ( $message ne "" ) {
            Record_Result("TP_PW_ARCHIVE", -1, -1, "", $message);
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
    my (@package_list) = ("tqa_result_object", "clf_check", "clf_archive");

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

