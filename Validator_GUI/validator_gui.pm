#***********************************************************************
#
# Name: validator_gui.pm
#
# $Revision: 7627 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Validator_GUI/Tools/validator_gui.pm $
# $Date: 2016-07-15 08:23:18 -0400 (Fri, 15 Jul 2016) $
#
# Description:
#
#   This file contains routines that implement a Windows GUI for the validator
# tools.  It implements the main dialog, error dialog and results windows.
#
# Public functions:
#     Validator_GUI_Add_Results_Tab
#     Validator_GUI_Display_Content
#     Validator_GUI_Login
#     Validator_GUI_Set_Results_File_Suffixes
#     Validator_GUI_Set_Results_Save_Callback
#     Validator_GUI_Setup
#     Validator_GUI_Start
#     Validator_GUI_Clear_Results
#     Validator_GUI_Update_Results
#     Validator_GUI_Print_TQA_Result
#     Validator_GUI_Print_URL_Compliance_Score
#     Validator_GUI_Print_Scan_Compliance_Score
#     Validator_GUI_Print_URL_Fault_Count
#     Validator_GUI_Print_Scan_Fault_Count
#     Validator_GUI_Print_HTML_Feature
#     Validator_GUI_Print_URL
#     Validator_GUI_Print_URL_Error
#     Validator_GUI_Print_Error
#     Validator_GUI_Start_URL
#     Validator_GUI_End_URL
#     Validator_GUI_Start_Analysis
#     Validator_GUI_End_Analysis
#     Validator_GUI_401_Login
#     Validator_GUI_Debug
#     Validator_GUI_Report_Option_Labels
#     Validator_GUI_Report_Option_Testcase_Groups
#     Validator_GUI_Open_Data_Setup
#     Validator_GUI_Runtime_Error_Callback
#     Validator_GUI_Remove_Temporary_Files
#
# Exported functions - these are required by the Win32::GUI package
# and should not be used by anyone else.
#     Validator_GUI_Browser_Terminate
#     Validator_GUI_Continue_Terminate
#     Validator_GUI_Error_Terminate
#     Validator_GUI_Login_Terminate
#     Validator_GUI_401_Authorization_Terminate
#     Validator_GUI_Main_Resize
#     Validator_GUI_Main_Terminate
#     Validator_GUI_Results_Terminate
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

package validator_gui;

my $have_threads = eval 'use threads; 1';
if ( $have_threads ) {
    $have_threads = eval 'use threads::shared; 1';
}

use strict;
use warnings;

use Encode;
use File::Temp();
use File::Basename;
use File::Copy;
use Win32::GUI();
use File::Temp qw/ tempfile tempdir /;
use Text::CSV;
#use Win32::GUI::AxWindow();
#
# Cannot do a 'use' here as there is a bug with threads and the
# Mechanize module.  A 'require' is performed when we actually create
# an instance of the object.
#
#use Win32::IE::Mechanize;


#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Validator_GUI_Add_Results_Tab
                  Validator_GUI_Display_Content
                  Validator_GUI_Login
                  Validator_GUI_Set_Results_File_Suffixes
                  Validator_GUI_Set_Results_Save_Callback
                  Validator_GUI_Setup
                  Validator_GUI_Start
                  Validator_GUI_Clear_Results
                  Validator_GUI_Update_Results
                  Validator_GUI_Print_TQA_Result
                  Validator_GUI_Print_URL_Compliance_Score
                  Validator_GUI_Print_Scan_Compliance_Score
                  Validator_GUI_Print_URL_Fault_Count
                  Validator_GUI_Print_Scan_Fault_Count
                  Validator_GUI_Print_HTML_Feature
                  Validator_GUI_Print_URL
                  Validator_GUI_Print_URL_Error
                  Validator_GUI_Print_Error
                  Validator_GUI_Start_URL
                  Validator_GUI_End_URL
                  Validator_GUI_Start_Analysis
                  Validator_GUI_End_Analysis
                  Validator_GUI_401_Login
                  Validator_GUI_Debug
                  Validator_GUI_Report_Option_Labels
                  Validator_GUI_Report_Option_Testcase_Groups
                  Validator_GUI_Open_Data_Setup
                  Validator_GUI_Runtime_Error_Callback
                  Validator_GUI_Remove_Temporary_Files

                  Validator_GUI_Browser_Terminate
                  Validator_GUI_Continue_Terminate
                  Validator_GUI_Error_Terminate
                  Validator_GUI_Login_Terminate
                  Validator_GUI_401_Authorization_Terminate
                  Validator_GUI_Main_Resize
                  Validator_GUI_Main_Terminate
                  Validator_GUI_Results_Terminate
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths, $tmp);
my ($dos_window, $error_window, $login_window, $save_content);
my ($content_callback, $site_crawl_callback, $open_data_callback, $stop_on_errors);
my (@login_form_field_list, $login_window_open, %login_form_values );
my ($authorization_401_window, $show_browser_window);
my ($continue_window, $continue_window_open, $continue_window_save_content);
my ($site_config_tabid, $html_input_tabid, $url_list_tabid, $open_data_tabid);
my ($report_fails_only, $main_window_tab_count, $results_window_tab_count);
my (%results_window_tab_labels, $config_tabid, %option_combobox_map);
my (%results_file_suffixes, $main_window_menu, $url_list_callback);
my ($site_login_logout_config_tabid, $version, %login_credentials);
my ($results_save_callback, %report_options_labels, $ie, $browser_close_window);
my ($browser_close_window_open, %report_options_field_names);
my (%report_options_config_options, %url_401_user, %url_401_password);
my ($process_pdf, $runtime_error_callback, $enable_generated_markup);
my ($testcase_profile_groups_label, $testcase_profile_groups_names);
my ($testcase_profile_groups_values, %report_options_values);
my ($testcase_profile_groups_config_option);

my ($csv_results_fh, $csv_results_file_name, $csv_object);
my (@csv_results_fields) = ("type", "url", "testcase", "description", "line_no",
                            "column_no", "page_no","source_line","message",
                            "help_url");
if ( $have_threads ) {
    share(\$csv_results_file_name);
}

my ($xml_output_mode) = 0;
my ($xml_tab_label) = "";

#
# Variables shared between threads
#
my $main_window;
my $results_window;

my ($debug) = 0;
my ($child_thread);

my (%site_configuration_fields) = (
    "sitedire", "",
    "siteentrye", "",
    "sitedirf", "",
    "siteentryf", "",
    "loginpagee", "",
    "logoutpagee", "",
    "loginpagef", "",
    "logoutpagef", "",
    "loginformname", "",
    "crawllimit", "",
    "crawl_depth", "",
    "logininterstitialcount", "",
    "logoutinterstitialcount", "",
    "logoutinterstitialcount", "",
    "httpproxy", "",
    "process_pdf", "",
   );

my ($language) = "eng";
my ($default_crawllimit) = 100;
my ($default_crawl_depth) = 0;

#
# Label width for site configuration window
#
my ($site_label_width_en) = 110;
my ($site_label_width_fr) = 240;
my ($site_label_width);

#
# String table for UI strings.
#
my %string_table_en = (
    "2 spaces",            "  ",
    "4 spaces",            "    ",
    "API URLs",            "API URLs",
    "Authorization required for",    "Authorization required for",
    "Authorization Required",    "Authorization Required",
    "Average faults per page",  "Average faults per page: ",
    "Browser Window",      "Browser Window",
    "Browser",             "Browser",
    "Check Site",          "Check Site",
    "Check URL List",      "Check URL List",
    "Check",               "Check",
    "Close Browser",       "Close Browser",
    "Close",               "Close",
    "Column",              "Column: ",
    "Compliance score",    "Compliance score: ",
    "Configuration",       "Configuration",
    "Continue",            "Continue",
    "Crawl Depth",         "Crawl Depth",
    "Crawl Limit",         "Crawl Limit",
    "Data Files",          "Data Files",
    "Description URL",     "Description URL",
    "Dictionary Files",    "Dictionary Files",
    "Direct HTML Input",   "Direct HTML Input",
    "Disable content capture", "Disable content capture",
    "Disable generated markup", "Disable generated markup",
    "Disable PDF checking",  "Disable PDF checking",
    "Enable content capture", "Enable content capture",
    "Enable generated markup",     "Enable generated markup",
    "Enable PDF checking",   "Enable PDF checking",
    "English directory",   "English directory",
    "English entry page",  "English entry page",
    "English login page",  "English login page",
    "English logout page", "English logout page",
    "Example",             "Example",
    "Exit",                "Exit",
    "Failed to save content",    "Failed to save content in ",
    "File",                "File",
    "first form",          "(if left blank the first form on the login page is used)",
    "French directory",    "French directory",
    "French entry page",   "French entry page",
    "French login page",   "French login page",
    "French logout page",  "French logout page",
    "Help",                "Help",
    "Hide Browser",        "Hide Browser",
    "if blank use English", "(if left blank the English value is used)",
    "Line",                "Line: ",
    "Load Config",         "Load Config",
    "Load from File",      "Load from File",
    "Load Open Data Config", "Load Open Data Config",
    "Load Site Config",    "Load Site Config",
    "Login form name",     "Login form name",
    "Login interstitial page count", "Number of interstitial pages after login page",
    "Login page count",    "Login page count",
    "Login",               "Login",
    "Login/Logout fields", "Login/Logout fields, leave blank if site does not require a login.",
    "Login/Logout",        "Login/Logout",
    "Logout interstitial page count", "Number of interstitial pages after logout page",
    "Logout page count",   "Logout page count",
    "Main Window Title",   "Web and Open Data Validator",
    "No URLs supplied",    "No URLs supplied",
    "Number of faults",    "Number of faults: ",
    "number of faults",    "number of faults: ",
    "Ok",                  "Ok",
    "Open Data",           "Open Data",
    "Options",             "Options",
    "Overall compliance score", "Overall compliance score: ",
    "Page",                "Page: ",
    "Password",            "Password",
    "Press Continue",      "Press Continue to resume or Save Content to save the HTML content",
    "Press Ok to close browser", "Press Ok to close browser",
    "Proxy address to use", "Proxy address to use (leave blank if proxy is not needed)",
    "Proxy",               "Proxy",
    "referrer",            "referrer",
    "Report Fails and Passes",     "Report Fails and Passes",
    "Report Fails Only",   "Report Fails Only",
    "Reset",               "Reset",
    "Resource Files",      "Resource Files",
    "Results Window Title", "Results Window",
    "Save As",             "Save As",
    "Save Config",         "Save Config",
    "Save Content",        "Save Content",
    "Save Open Data Config", "Save Open Data Config",
    "Save Site Config",    "Save Site Config",
    "Show Browser",        "Show Browser",
    "Site Details",        "Site Details",
    "Source line",         "Source line:\n",
    "Stop Crawl",          "Stop Crawl",
    "Testcase",            "Testcase: ",
    "Text Output",         "Text Output",
    "The maximum crawl depth",    "The maximum crawl depth (0 = unlimited)",
    "The maximum number of URLs",    "The maximum number of URLs to crawl from the site (0 = unlimited)",
    "Total fault count",   "Total fault count: ",
    "URL List",            "URL List",
    "User Name",           "User Name",
    "Version",             "Version ",
    "XML Output",          "XML Output",
);

my %string_table_fr = (
    "2 spaces",                 "  ",
    "4 spaces",                 "    ",
    "API URLs",                 "API URLs",
    "Authorization required for", "Autorisation requise pour ",
    "Authorization Required",   "Autorisation requise",
    "Average faults per page",  "Nombre moyen de pannes par page: ",
    "Browser Window",           "Fenêtre du navigateur",
    "Browser",                  "Navigateur",
    "Check Site",               "Vérifier le site",
    "Check URL List",           "Vérifier la liste d'adresses URL",
    "Check",                    "Vérifier",
    "Close Browser",            "Fermer Navigateur",
    "Close",                    "Fermer",
    "Column",                   "Colonne : ",
    "Compliance score",         "Score de conformité: ",
    "Configuration",            "Configuration",
    "Continue",                 "Continuer",
    "Crawl Depth",              "Profondeur D'Exploration",
    "Crawl Limit",              "Limite de l'exploration",
    "Data Files",               "Les fichers de données",
    "Description URL",          "Description URL",
    "Dictionary Files",         "Fichiers de dictionnaire",
    "Direct HTML Input",        "Entrée de données direct HTML",
    "Disable content capture",  "Désactiver la capture du contenu",
    "Disable generated markup", "Désactiver généré de balisage",
    "Disable PDF checking",     "Désactiver la vérification PDF",
    "Enable content capture",   "Activer la capture de contenu",
    "Enable generated markup",  "Permettre aux produits de balisage",
    "Enable PDF checking",      "Activer PDF vérification",
    "English directory",        "Répertoire anglais",
    "English entry page",       "Page d'entrée anglaise",
    "English login page",       "Page anglaise d'ouverture de session",
    "English logout page",      "Page anglaise fermeture de session",
    "Example",                  "Exemple",
    "Exit",                     "Sortie",
    "Failed to save content",   "Impossible d'enregistrer le contenu",
    "File",                     "Fichier",
    "first form",               "(si laissé en blanc, le premier formulaire sur la page d'ouverture de session est utilisé)",
    "French directory",         "Répertoire français",
    "French entry page",        "Page d'entrée française",
    "French login page",        "Page française d'ouverture de session",
    "French logout page",       "Page française fermeture de session",
    "Help",                     "Aide",
    "Hide Browser",             "Masquer le navigateur",
    "if blank use English",     "(si laissé en blanc, l'anglais est utilisé)",
    "Line",                     "la ligne : ",
    "Load Config",              "Charger Configuration",
    "Load from File",           "Charger à partir du fichier",
    "Load Open Data Config",    "Charger Configuration de Données Ouvertes",
    "Load Site Config",         "Charger la configuration du site",
    "Login form name",          "Page d'ouverture de session - Nom du formulaire",
    "Login interstitial page count", "nombre de pages interstitielles d'ouverture de session",
    "Login page count",         "nombre de pages d'ouverture de session",
    "Login",                    "Ouverture de session",
    "Login/Logout fields",      "Champs Ouverture de session/Fermeture de session, laissé en blanc si le site n'a pas besoin d'overture de session.",
    "Login/Logout",             "Ouverture de session/Fermeture de session",
    "Logout interstitial page count", "nombre de pages interstitielles de fermeture de session",
    "Logout page count",        "nombre de pages de fermeture de session",
    "Main Window Title",        "Validateur web et données ouvertes",
    "No URLs supplied",         "Aucune de URL fournie",
    "Number of faults",         "Nombre de pannes: ",
    "number of faults",         "nombre de pannes: ",
    "Ok",                       "O.K.",
    "Open Data",                "Données Ouvertes",
    "Options",                  "Options",
    "Overall compliance score", "Score de conformité totale: ",
    "Page",                     "Page : ",
    "Password",                 "Mot de passe",
    "Press Continue",           "Appuyez sur Continuer pour reprendre ou sur Enregistrer le contenu pour enregistrer le contenu HTML",
    "Press Ok to close browser", "Appuyez sur OK pour fermer navigateur",
    "Proxy address to use",     "Adresse proxy à utiliser",
    "Proxy",                    "Proxy",
    "referrer",                 "recommandataire",
    "Report Fails and Passes",  "Rapporter les échecs et les succès",
    "Report Fails Only",        "Rapporter les échecs seulement",
    "Reset",                    "Effacer",
    "Resource Files",           "Fichiers de ressources",
    "Results Window Title",     "Fenêtre de résultats",
    "Save As",                  "Enregistrer sous",
    "Save Config",              "Sauver Configuration",
    "Save Content",             "Sauvegarder le contenu",
    "Save Open Data Config",    "Sauver Configuration de Données Ouvertes",
    "Save Site Config",         "Enregistrer la configuration du site",
    "Show Browser",             "Afficher le navigateur",
    "Site Details",             "Détails du site",
    "Source line",              "Ligne de la source :\n",
    "Stop Crawl",               "Arrêter l'exploration",
    "Testcase",                 "Cas de test : ",
    "Text Output",              "format de sortie du texte",
    "The maximum crawl depth",  "La profondeur d'exploration maximale (0 = illimité)",
    "The maximum number of URLs", "Le nombre maximal d'adresses URL (0 = illimité)",
    "Total fault count",        "Nombre total de pannes: ",
    "URL List",                 "Liste d'adresses URL",
    "User Name",                "Nom d'utilisateur",
    "Version",                  "Version ",
    "XML Output",               "format de sortie XML",
);

my ($string_table) = \%string_table_en;

my (@package_list) = ("tqa_result_object", "validator_xml", "crawler");

#
#***********************************************************************
# Configuration items
#***********************************************************************
#

#
# Maximum number of characters for direct HTML input and URL list
#
my ($GUI_DIRECT_HTML_SIZE) = 100000;
my ($GUI_URL_LIST_SIZE) = 100000;

#***********************************************************************
#
# Name: Validator_GUI_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Validator_GUI_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: Validator_GUI_Remove_Temporary_Files
#
# Parameters: none
#
# Description:
#
#   This function removes any temporary files that may have been
# created by this module.
#
#***********************************************************************
sub Validator_GUI_Remove_Temporary_Files {

    #
    # Do we have a CSV results file ?
    #
    if ( defined($csv_results_file_name) ) {
        #
        # Do we have an open results file ?
        #
        if ( defined($csv_results_fh) ) {
            close($csv_results_fh);
        }
        unlink($csv_results_file_name);
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
# Name: Validator_GUI_Set_Results_File_Suffixes
#
# Parameters: local_file_suffix_map - file suffix map
#
# Description:
#
#   This function copies the results file suffix map into a
# package global variable.
#
#***********************************************************************
sub Validator_GUI_Set_Results_File_Suffixes {
    my (%local_file_suffix_map) = @_;
    
    #
    # Copy into package global variable
    #
    %results_file_suffixes = %local_file_suffix_map;
}

#***********************************************************************
#
# Name: Validator_GUI_Add_Results_Tab
#
# Parameters: tab_label - label for tab
#
# Description:
#
#   This function adds a tab to the results window.
#
#***********************************************************************
sub Validator_GUI_Add_Results_Tab {
    my ($tab_label) = @_;

    my ($tabid, $name);
    my ($current_pos) = 20;

    #
    # Add title to the tab and increment tab count
    #
    print "Add results tab $tab_label\n" if $debug;
    $results_window->ResultTabs->InsertItem(
        -text   => "$tab_label",
    );
    $results_window_tab_count++;

    #
    # If this is the first tab, save it's label to be used for XML
    # output (in XML mode).
    #
    if ( $results_window_tab_count == 1 ) {
        $xml_tab_label = $tab_label;
    }

    #
    # Set 2 digit tab identifier
    #
    $tabid = sprintf("_%02d", $results_window_tab_count);

    #
    # Record the tab identifier and tab label
    #
    $results_window_tab_labels{$tab_label} = $tabid;

    #
    # Add scrolling text field for results
    #
    $name = "results$tabid";
    $results_window->ResultTabs->AddTextfield(
        -name => $name,
        -pos => [10,$current_pos],
        -size => [760,420],
        -multiline => 1,
        -hscroll   => 1,
        -vscroll   => 1,
        -autohscroll => 1,
        -autovscroll => 1,
        -keepselection => 1,
        -wantreturn => 1,
    );

    #
    # Set text field size to max
    #
    $results_window->ResultTabs->$name->MaxLength(0);
}

#***********************************************************************
#
# Name: Validator_GUI_Clear_Results
#
# Parameters: tab_label - label of tab to clear
# Description:
#
#   This function clears the content from the named tab.
#
#***********************************************************************
sub Validator_GUI_Clear_Results {
    my ($tab_label) = @_;

    my ($tabid, $name);

    #
    # Get tab that matches this label
    #
    print "Validator_GUI_Clear_Results tab = $tab_label\n" if $debug;
    if ( ! defined($results_window_tab_labels{$tab_label}) ) {
        print "Error: Unknown tab $tab_label\n" if $debug;
        return;
    }
    $tabid = $results_window_tab_labels{$tab_label};
    $name = "results$tabid";

    #
    # Clear the text area
    #
    $results_window->ResultTabs->$name->Text("");

    #
    # Update the results page
    #
    Win32::GUI::DoEvents();
}

#***********************************************************************
#
# Name: Update_Results_Tab
#
# Parameters: tab_label - label of tab to update
#             text - new text for results
#
# Description:
#
#   This function updates the text in the results page.  The new text is
# appended to the existing text in the tab.
#
#***********************************************************************
sub Update_Results_Tab {
    my ($tab_label, $text) = @_;

    my ($tabid, $name);

    #
    # Get tab that matches this label
    #
    print "Update_Results_Tab tab = $tab_label, text = $text\n" if $debug;
    if ( ! defined($results_window_tab_labels{$tab_label}) ) {
        print "Error: Unknown tab $tab_label\n" if $debug;
        return;
    }
    $tabid = $results_window_tab_labels{$tab_label};
    $name = "results$tabid";

    #
    # If there are any newlines in the contents, replace them with
    # a carriage return & newline.
    #
    $text =~ s/\n/\r\n/g;
    eval {$text = encode("iso-8859-1", $text); };
    $results_window->ResultTabs->$name->Append($text . "\r\n");

    #
    # Update the results page
    #
    Win32::GUI::DoEvents();
}

#***********************************************************************
#
# Name: Validator_GUI_Update_Results
#
# Parameters: tab_label - label of tab to update
#             text - new text for results
#
# Description:
#
#   This function updates the text in the results page.  The new text is
# appended to the existing text in the tab.
#
#***********************************************************************
sub Validator_GUI_Update_Results {
    my ($tab_label, $text) = @_;

    #
    # Are we not in XML output mode ?
    #
    if ( ! $xml_output_mode ) {
        #
        # Print text to results tab
        #
        Update_Results_Tab($tab_label, $text);
    }
}

#***********************************************************************
#
# Name: Print_TQA_Result_to_CSV
#
# Parameters: tab_label - label of tab to update
#             result_object - tqa_result_object item
#
# Description:
#
#   This function prints the attributes of the tqa_results_object item
# to the CSV results file.
#
#***********************************************************************
sub Print_TQA_Result_to_CSV {
    my ($tab_label, $result_object) = @_;
    
    my (@fields, $status);

    #
    # Do we have a CSV file yet ?
    #
    if ( ! defined($csv_results_file_name) ) {
        #
        # Create temporary CSV file for testcase results
        #
        ($csv_results_fh, $csv_results_file_name) = tempfile("WPSS_TOOL_XXXXXXXXXX",
                                                             SUFFIX => '.csv',
                                                             TMPDIR => 1);
        if ( ! defined($csv_results_fh) ) {
            print "Error: Failed to create temporary file in Print_TQA_Result_to_CSV\n";
            return;
        }
        binmode $csv_results_fh, ":utf8";
        print "Temporary testcase results CSV file $csv_results_file_name\n" if $debug;
        
        #
        # Create CSV object
        #
        $csv_object = Text::CSV->new ( { binary => 1, eol => $/ } );
        $csv_object->print($csv_results_fh, \@csv_results_fields);
    }
    
    #
    # Save fields of the result object in the CSV file
    #
    @fields = ($tab_label, $result_object->url, $result_object->testcase,
               $result_object->description, $result_object->line_no,
               $result_object->column_no, $result_object->page_no,
               $result_object->source_line);

    #
    # Add message field. Limit text to 10K characters
    #
    push(@fields, substr($result_object->message, 0, 10240));

    #
    # Add help URL field
    #
    push(@fields, $result_object->help_url);

    #
    # Write fields to the CSV file.
    #
    if ( defined($csv_object) ) {
        $status = $csv_object->print($csv_results_fh, \@fields);
        if ( ! $status ) {
            print "Error in CSV print, status = $status, " .
                  $csv_object->error_diag() . ", tab = $tab_label " .
                  $result_object->testcase . ", " . $result_object->url . "\n";
        }
    }
}

#***********************************************************************
#
# Name: Validator_GUI_Print_TQA_Result
#
# Parameters: tab_label - label of tab to update
#             result_object - tqa_result_object item
#
# Description:
#
#   This function prints the attributes of the tqa_results_object item
# to the specified output tab.
#
#***********************************************************************
sub Validator_GUI_Print_TQA_Result {
    my ($tab_label, $result_object) = @_;

    my ($output_line, $message, $source_line);

    #
    # Do we want XML output ?
    #
    print "Validator_GUI_Print_TQA_Result tab = $tab_label\n" if $debug;
    if ( $xml_output_mode ) {
        $output_line = Validator_XML_TQA_Result($tab_label, $result_object);
        Update_Results_Tab($tab_label, $output_line);
    }
    else {
        #
        # Print testcase description
        #
        $output_line = String_Value("2 spaces") .
                       String_Value("Testcase") .  " " .
                       $result_object->description;
        Update_Results_Tab($tab_label, $output_line);

        #
        # Print location, if there is one
        #
        if ( $result_object->line_no != -1 ) {
            $output_line = sprintf(String_Value("4 spaces") .
                                   String_Value("Line") .
                                   "%3d " . String_Value("Column") .
                                   "%3d", $result_object->line_no,
                                   $result_object->column_no);
            Update_Results_Tab($tab_label, $output_line);
        }
        #
        # Print page number, if there is one
        #
        elsif ( $result_object->page_no > 0 ) {
            $output_line = sprintf(String_Value("4 spaces") .
                                   String_Value("Page") .
                                   "%3d ", $result_object->page_no);
            Update_Results_Tab($tab_label, $output_line);
        }

        #
        # Print error message
        #
        $message = $result_object->message;
        if ( $message ne "" ) {
            Update_Results_Tab($tab_label,
                               String_Value("4 spaces") . $message);
        }

        #
        # Print source line
        #
        $source_line = $result_object->source_line;
        if ( $source_line ne "" ) {
            Update_Results_Tab($tab_label, String_Value("4 spaces") .
                               String_Value("Source line") .
                               $source_line);
        }

        #
        # Place blank line after error
        #
        Update_Results_Tab($tab_label, "");
        
        #
        # Output the TQA result to the CSV results file
        #
        Print_TQA_Result_to_CSV($tab_label, $result_object);
    }
}

#***********************************************************************
#
# Name: Validator_GUI_Print_URL_Compliance_Score
#
# Parameters: tab_label - label of tab to update
#             score - compliance score value
#             faults - number of faults
#             url - URL
#
# Description:
#
#   This function prints the compliance score for a URL to the specified
# output tab.
#
#***********************************************************************
sub Validator_GUI_Print_URL_Compliance_Score {
    my ($tab_label, $score, $faults, $url) = @_;

    my ($output_line);

    #
    # Do we want XML output ?
    #
    print "Validator_GUI_Print_URL_Compliance_Score tab = $tab_label\n" if $debug;
    if ( $xml_output_mode ) {
        $output_line = Validator_XML_URL_Compliance_Score($score, $faults,
                                                          $url);
        Update_Results_Tab($tab_label, $output_line);
    }
    else {
        #
        # Print compliance score and fault count.
        #
        Update_Results_Tab($tab_label, "    " .
                           String_Value("Compliance score") .
                           "$score %, " .
                           String_Value("number of faults") .
                           "$faults");
        Update_Results_Tab($tab_label, "");
    }
}

#***********************************************************************
#
# Name: Validator_GUI_Print_Scan_Compliance_Score
#
# Parameters: tab_label - label of tab to update
#             score - compliance score value
#             faults - number of faults
#
# Description:
#
#   This function prints the compliance score for a scan to the specified
# output tab.
#
#***********************************************************************
sub Validator_GUI_Print_Scan_Compliance_Score {
    my ($tab_label, $score, $faults) = @_;

    my ($output_line);

    #
    # Do we want XML output ?
    #
    print "Validator_GUI_Print_Scan_Compliance_Score tab = $tab_label\n" if $debug;
    if ( $xml_output_mode ) {
        $output_line = Validator_XML_Scan_Compliance_Score($score, $faults);
        Update_Results_Tab($tab_label, $output_line);
    }
    else {
        #
        # Print compliance score and fault count.
        #
        Update_Results_Tab($tab_label, "    " .
                           String_Value("Overall compliance score") .
                           "$score %, " .
                           String_Value("Average faults per page") .
                           "$faults");
        Update_Results_Tab($tab_label, "");
    }
}

#***********************************************************************
#
# Name: Validator_GUI_Print_URL_Fault_Count
#
# Parameters: tab_label - label of tab to update
#             faults - number of faults
#             url - URL
#
# Description:
#
#   This function prints the fault count for a URL to the specified
# output tab.
#
#***********************************************************************
sub Validator_GUI_Print_URL_Fault_Count {
    my ($tab_label, $faults, $url) = @_;

    my ($output_line);

    #
    # Do we want XML output ?
    #
    print "Validator_GUI_Print_URL_Fault_Count tab = $tab_label\n" if $debug;
    if ( $xml_output_mode ) {
        $output_line = Validator_XML_URL_Fault_Count($faults, $url);
        Update_Results_Tab($tab_label, $output_line);
    }
}

#***********************************************************************
#
# Name: Validator_GUI_Print_Scan_Fault_Count
#
# Parameters: tab_label - label of tab to update
#             faults - total fault count value
#             faults_per_page - number of faults per page
#
# Description:
#
#   This function prints the fault count for a scan to the specified
# output tab.
#
#***********************************************************************
sub Validator_GUI_Print_Scan_Fault_Count {
    my ($tab_label, $faults, $faults_per_page) = @_;

    my ($output_line);

    #
    # Do we want XML output ?
    #
    print "Validator_GUI_Print_Scan_Fault_Count tab = $tab_label\n" if $debug;
    if ( $xml_output_mode ) {
        $output_line = Validator_XML_Scan_Fault_Count($faults, $faults_per_page);
        Update_Results_Tab($tab_label, $output_line);
    }
    else {
        #
        # Print fault count and fault count.
        #
        Update_Results_Tab($tab_label, "    " .
                           String_Value("Total fault count") .
                           "$faults, " .
                           String_Value("Average faults per page") .
                           "$faults_per_page");
        Update_Results_Tab($tab_label, "");
    }
}

#***********************************************************************
#
# Name: Validator_GUI_Print_HTML_Feature
#
# Parameters: tab_label - label of tab to update
#             feature - feature label
#             count - feature instance count
#             url - URL
#
# Description:
#
#   This function prints a HTML feature item to the specified
# output tab.
#
#***********************************************************************
sub Validator_GUI_Print_HTML_Feature {
    my ($tab_label, $feature, $count, $url) = @_;

    my ($output_line);

    #
    # Are we in XML mode ?
    #
    if ( $xml_output_mode ) {
        $output_line = Validator_XML_HTML_Feature($feature, $count, $url);
        Update_Results_Tab($tab_label, $output_line);
    }
    else {
        #
        # Print feature count and URL.  The feature label would have
        # been printed by a seperate call to Validator_GUI_Update_Results
        #
        print "Validator_GUI_Print_HTML_Feature tab = $tab_label\n" if $debug;
        Update_Results_Tab($tab_label, "$count $url");
    }
}

#***********************************************************************
#
# Name: Validator_GUI_Print_URL
#
# Parameters: tab_label - label of tab to update
#             url - URL
#             count - count of URL
#
# Description:
#
#   This function prints a URL to the specified output tab.
#
#***********************************************************************
sub Validator_GUI_Print_URL {
    my ($tab_label, $url, $count) = @_;

    #
    # Don't print URL if we are in XML mode, the URL would have already
    # been included in the XML output via the Validator_GUI_Start_URL
    # function.
    #
    if ( ! $xml_output_mode ) {
        #
        # Print URL to file.
        #
        Update_Results_Tab($tab_label, "$count:  $url");
    }
}

#***********************************************************************
#
# Name: Validator_GUI_Print_URL_Error
#
# Parameters: tab_label - label of tab to update
#             url - URL
#             count - URL number
#             error - error message
#
# Description:
#
#   This function prints a URL error message to the specified output tab.
#
#***********************************************************************
sub Validator_GUI_Print_URL_Error {
    my ($tab_label, $url, $count, $error) = @_;

    #
    # Print URL to file.
    #
    Update_Results_Tab($tab_label, "$count:  $url");
    Update_Results_Tab($tab_label, String_Value("2 spaces") . $error);
    Update_Results_Tab($tab_label, "");
}

#***********************************************************************
#
# Name: Validator_GUI_Print_Error
#
# Parameters: tab_label - label of tab to update
#             error - error message
#
# Description:
#
#   This function prints an error message to the specified output tab.
#
#***********************************************************************
sub Validator_GUI_Print_Error {
    my ($tab_label, $error) = @_;

    #
    # Print error to file.
    #
    Update_Results_Tab($tab_label, String_Value("2 spaces") . $error);
    Update_Results_Tab($tab_label, "");
}

#***********************************************************************
#
# Name: Validator_GUI_Start_URL
#
# Parameters: tab_label - label of tab to update
#             url - URL
#             referrer - referrer URL
#             supporting_file - flag to indicate if URL is supporting
#             count - count of URL
#
# Description:
#
#   This function prints a URL to the specified output tab.
#
#***********************************************************************
sub Validator_GUI_Start_URL {
    my ($tab_label, $url, $referrer, $supporting_file, $count) = @_;

    my ($url_line);

    #
    # Do we want XML output ?
    #
    if ( $xml_output_mode ) {
        $url_line = Validator_XML_Start_URL($url, $referrer,
                                            $supporting_file, $count);
        Update_Results_Tab($tab_label, $url_line);
    }
    else {
        #
        # Print URL.
        #
        print "Validator_GUI_Start_URL tab = $tab_label\n" if $debug;
        $url_line = "$count:  $url      (" .  String_Value("referrer") . 
                    " $referrer)";

        Update_Results_Tab($tab_label, $url_line);
    }
}

#***********************************************************************
#
# Name: Validator_GUI_End_URL
#
# Parameters: tab_label - label of tab to update
#             url - URL
#             referrer - referrer URL
#             supporting_file - flag to indicate if URL is supporting
#             count - count of URL
#
# Description:
#
#   This function ends the print of a URL to the specified output tab.
#
#***********************************************************************
sub Validator_GUI_End_URL {
    my ($tab_label, $url, $referrer, $supporting_file, $count) = @_;

    my ($output_line);

    #
    # Do we want XML output ?
    #
    if ( $xml_output_mode ) {
        $output_line = Validator_XML_End_URL($url, $referrer,
                                             $supporting_file, $count);
        Update_Results_Tab($tab_label, $output_line);
    }
}

#***********************************************************************
#
# Name: Validator_GUI_Start_Analysis
#
# Parameters: tab_label - label of tab to update
#             date - time/date
#             message - message
#
# Description:
#
#   This function prints the analysis start message to the 
# specified output tab.
#
#***********************************************************************
sub Validator_GUI_Start_Analysis {
    my ($tab_label, $date, $message) = @_;

    my ($output_line);

    #
    # Do we want XML output ?
    #
    if ( $xml_output_mode ) {
        #
        # Write start analysis message to first tab only (to avoid
        # multiple start messages).
        #
        if ( $tab_label eq $xml_tab_label ) {
            $output_line = Validator_XML_Start_Analysis($date, $message);
            Update_Results_Tab($tab_label, $output_line);
        }
    }
    else {
        #
        # Print URL.
        #
        print "Validator_GUI_Start_Analysis tab = $tab_label\n" if $debug;
        Update_Results_Tab($tab_label, "$message$date\n\n");
    }
}

#***********************************************************************
#
# Name: Validator_GUI_End_Analysis
#
# Parameters: tab_label - label of tab to update
#             date - time/date
#             message - message
#
# Description:
#
#   This function prints the analysis end message to the
# specified output tab.
#
#***********************************************************************
sub Validator_GUI_End_Analysis {
    my ($tab_label, $date, $message) = @_;

    my ($output_line);

    #
    # Do we want XML output ?
    #
    if ( $xml_output_mode ) {
        #
        # Write start analysis message to first tab only (to avoid
        # multiple start messages).
        #
        if ( $tab_label eq $xml_tab_label ) {
            $output_line = Validator_XML_End_Analysis($date, $message);
            Update_Results_Tab($tab_label, $output_line);
        }
    }
    else {
        #
        # Print message
        #
        print "Validator_GUI_End_Analysis tab = $tab_label\n" if $debug;
        Update_Results_Tab($tab_label, "$message$date\n\n");
    }
}

#***********************************************************************
#
# Name: Validator_GUI_Error_Terminate
#
# Parameters: none
#
# Description:
#
#   This function handles closing the error message window. It simply
# hides the window.
#
#***********************************************************************
sub Validator_GUI_Error_Terminate {
        $error_window->Hide();
        return 0;
}

#***********************************************************************
#
# Name: GUI_Error_Close_Click
#
# Parameters: none
#
# Description:
#
#   This function handles a click on the Close button in the Error
# dialog. It simply hides the window.
#
#***********************************************************************
sub GUI_Error_Close_Click {
        $error_window->Hide();
        return 0;
}

#***********************************************************************
#
# Name: Error_Message_Popup
#
# Parameters: message - text string
#
# Description:
#
#   This function creates a popup window with an error message.
#
#***********************************************************************
sub Error_Message_Popup {
  my ($message) = @_;

    #
    # Create error window.
    #
    $error_window = Win32::GUI::DialogBox->new(
            -name => 'Validator_GUI_Error',
            -text => 'Error',
            -width => 200,
            -height => 100,
            -helpbutton => 0,
    );

    #
    # Add message as a label
    #
    $error_window->AddLabel(
        -name => 'error_message',
        -text => $message
    );

    #
    # Add a 'close' button to close the dialog
    #
    $error_window->AddButton(
            -name    => 'GUI_Error_Close',
            -text    => String_Value("Close"),
            -pos => [10,30],
            -onClick => \&GUI_Error_Close_Click,
    );

    #
    # Show the window
    #
    $error_window->Show();
}

#***********************************************************************
#
# Name: Validator_GUI_Results_Terminate
#
# Parameters: none
#
# Description:
#
#   This function handles closing the results dialog.  It hides
# the window and kills off any child process.
#
#***********************************************************************
sub Validator_GUI_Results_Terminate {
    print "Results window terminate\n" if $debug;
    Results_Close();
    return 0;
}

#***********************************************************************
#
# Name: Results_Close
#
# Parameters: none
#
# Description:
#
#   This function handles closing the results dialog.  It hides
# the window and kills off any child process.
#
#***********************************************************************
sub Results_Close {

    #
    # Hide results window
    #
    print "Close Results window\n" if $debug;
    $results_window->Hide();

    #
    #  Kill any child thread.
    #
    Kill_Child_Thread(); 

    return 0;
}

#***********************************************************************
#
# Name: Get_Report_Options
#
# Parameters: none
#
# Description:
#
#   This function gets the current values of the reporting options.
#
#***********************************************************************
sub Get_Report_Options {
    my (%report_options, $option_label, $combobox_name);

    #
    # Get value for each configuration option item
    #
    while ( ($option_label, $combobox_name) = each %option_combobox_map ) {
        $report_options{$option_label} = $main_window->ConfigTabs->$combobox_name->Text();
        print "Config Option $option_label = " .
              $report_options{$option_label} . "\n" if $debug;
    }
    $report_options{"report_passes_only"} = 0;

    #
    # Return configuration values
    #
    return(%report_options);
}

#***********************************************************************
#
# Name: GUI_Do_HTML_Click
#
# Parameters: none
#
# Description:
#
#   This function handles the GUI_Do_HTML button from the main window.
#
#***********************************************************************
sub GUI_Do_HTML_Click {
    my ($content, %report_options, $name, $tabid);

    #
    # Get content
    #
    $name = "direct_html_input$html_input_tabid";
    $content = $main_window->ConfigTabs->$name->Text();
    print "GUI_Do_HTML_Click content = $content\n" if $debug;

    #
    # Do we have a URL ?
    #
    if ( $content eq "" ) {
        #
        # Missing content
        #
        Error_Message_Popup("No content supplied");
    }
    else {
        #
        # Show the results window and clear any text.
        #
        foreach $tabid (values %results_window_tab_labels) {
            $name = "results$tabid";
            $results_window->ResultTabs->$name->Text("");
        }

        #
        # Get any report options
        #
        %report_options = Get_Report_Options();

        #
        # Copy menu options into report options hash table
        #
        $report_options{"report_fails_only"} = $report_fails_only;
        $report_options{"save_content"} = $save_content;
        $report_options{"process_pdf"} = $process_pdf;
        $report_options{"enable_generated_markup"} = 0;

        #
        # Show the results window.
        #
        Results_Window_Tabstrip_Click();
        $results_window->Show();
        $results_window->BringWindowToTop();
        Win32::GUI::DoEvents();

        #
        # Call the content callback function
        #
        if ( defined($content_callback) ) {
            &$content_callback($content, %report_options);
        }
        else {
            print "Error: Missing content callback function in GUI_Do_HTML_Click\n";
            exit(1);
        }
    }

    return 0;
}

#***********************************************************************
#
# Name: Close_Browser_Window
#
# Parameters: none
#
# Description:
#
#   This function closes the browser window if it is open.  Before
# closing the window it presents a dialog informing the user it is
# about to close.
#
#***********************************************************************
sub Close_Browser_Window {

    #
    # Do we have a browser window open ?
    #
    if ( defined($ie) ) {
        #
        # Create a dialog window to inform user the browser window
        # will close.
        #
        $browser_close_window = Create_Browser_Close_Window();
        $browser_close_window_open = 1;

        #
        # Loop until the dialog window is closed
        #
        while ( $browser_close_window_open ) {
            Win32::GUI::DoEvents();
            sleep(1);
        }

        #
        # Close browser window
        #
        print "Close IE\n" if $debug;
        $ie->close();
        undef $ie;
    }
}

#***********************************************************************
#
# Name: Run_URL_List_Callback
#
# Parameters: url_list - list of URLs
#             report_options - a hash table of report option values
#
# Description:
#
#   This function gets the value for the named field.
#
#***********************************************************************
sub Run_URL_List_Callback {
    my ($url_list, %report_options) = @_;

    my ($eval_output);

    #
    # Add a signal handler to exit a thread.
    #
    $SIG{'KILL'} = sub { 
                           #
                           # Close browser window if we had it open
                           #
                           if ( defined($ie) ) {
                               print "Close IE\n" if $debug;
                               $ie->close();
                               undef $ie;
                           }

                           #
                           # Exit the thread
                           #
                           threads->exit();
                      };

    #
    # Create IE window
    #
    Create_Browser_Window();

    #
    # Call the URL list callback function
    #
    print "Child: Call url_list_callback\n" if $debug;
    $eval_output = eval { &$url_list_callback($url_list, %report_options); 1 };
    if ( ! $eval_output ) {
        print STDERR "url_list_callback fail, eval_output = \"$@\"\n";
        print "url_list_callback fail, eval_output = \"$@\"\n" if $debug;

        #
        # Report run time error to parent thread
        #
        if ( defined($runtime_error_callback) ) {
            &$runtime_error_callback($@);
       }
    }
    print "Child: Return from url_list_callback\n" if $debug;

    #
    # Close results CSV file
    #
    if ( defined($csv_results_fh) ) {
        close($csv_results_fh);
    }

    #
    # Close browser window if we had it open
    #
    Close_Browser_Window();
}

#***********************************************************************
#
# Name: GUI_Do_URL_List_Click
#
# Parameters: none
#
# Description:
#
#   This function handles the GUI_Do_URL_List button from the main window.
#
#***********************************************************************
sub GUI_Do_URL_List_Click {
    my ($url_list, %report_options, $name, $tabid);

    #
    # Get content
    #
    $name = "url_list$url_list_tabid";
    $url_list = $main_window->ConfigTabs->$name->Text();
    print "GUI_Do_URL_List_Click url_list = $url_list\n" if $debug;

    #
    # Do we have a URL list ?
    #
    if ( $url_list eq "" ) {
        #
        # Missing content
        #
        Error_Message_Popup("No URLs supplied");
    }
    else {
        #
        # Show the results window and clear any text.
        #
        foreach $tabid (values %results_window_tab_labels) {
            $name = "results$tabid";
            $results_window->ResultTabs->$name->Text("");
        }

        #
        # Get any report options
        #
        %report_options = Get_Report_Options();

        #
        # Copy menu options into report options hash table
        #
        $report_options{"report_fails_only"} = $report_fails_only;
        $report_options{"save_content"} = $save_content;
        $report_options{"process_pdf"} = $process_pdf;
        $report_options{"enable_generated_markup"} = $enable_generated_markup;

        #
        # Show the results window.
        #
        Results_Window_Tabstrip_Click();
        $results_window->Show();
        $results_window->BringWindowToTop();
        Win32::GUI::DoEvents();

        #
        # Call the url list callback function
        #
        if ( defined($url_list_callback) ) {
            #
            # Create a new thread to handle the URL list.  This leaves
            # the main thread free to respond to GUI events.
            #
            print "Child: Call url_list_callback\n" if $debug;
            $child_thread = threads->create(\&Run_URL_List_Callback,$url_list,
                                            %report_options);

            #
            # Detach the thread so it can run freely
            #
            print "Detach url list thread\n" if $debug;
            $child_thread->detach();
        }
        else {
            print "Error: Missing url list callback function in GUI_Do_URL_List_Click\n";
            exit(1);
        }
    }

    return 0;
}

#***********************************************************************
#
# Name: Get_Field_Value
#
# Parameters: fieldname
#
# Description:
#
#   This function gets the value for the named field.
#
#***********************************************************************
sub Get_Field_Value {
    my ($tab_strip, $field_name) = @_;

    my ($value);

    #
    # Get the field value from the form field and remove leading or trailing
    # whitespace.
    #
    $value = $tab_strip->$field_name->Text();
    if ( defined($value) ) {
        $value =~ s/\s+$//g;
        $value =~ s/\/$//g;
    }
    else {
        $value = "";
    }

    #
    # Return the value
    #
    return($value);

}

#***********************************************************************
#
# Name: Run_Site_Crawl
#
# Parameters: crawl_details - hash table of crawl details
#
# Description:
#
#   This function calls the client's crawl site callback function.
#
#***********************************************************************
sub Run_Site_Crawl {
    my (%crawl_details) = @_;

    my ($eval_output);

    #
    # Add a signal handler to exit a thread.
    #
    $SIG{'KILL'} = sub {
                           #
                           # Close browser window if we had it open
                           #
                           if ( defined($ie) ) {
                               print "Close IE\n" if $debug;
                               $ie->close();
                               undef $ie;
                           }

                           #
                           # Exit the thread
                           #
                           threads->exit();
                      };


    #
    # Create IE window
    #
    Create_Browser_Window();

    #
    # Child, call the site crawl callback function
    #
    print "Child: Call site_crawl_callback\n" if $debug;
    $eval_output = eval { &$site_crawl_callback(%crawl_details); 1 };
    if ( ! $eval_output ) {
        print STDERR "site_crawl_callback fail, eval_output = \"$@\"\n";
        print "site_crawl_callback fail, eval_output = \"$@\"\n" if $debug;

        #
        # Report run time error to parent thread
        #
        if ( defined($runtime_error_callback) ) {
            &$runtime_error_callback($@);
       }
    }
    print "Child: Return from site_crawl_callback\n" if $debug;
    
    #
    # Close results CSV file
    #
    if ( defined($csv_results_fh) ) {
        close($csv_results_fh);
    }

    #
    # Close browser window if we had it open
    #
    Close_Browser_Window();
}

#***********************************************************************
#
# Name: Validator_GUI_DoSite_Click
#
# Parameters: none
#
# Description:
#
#   This function handles the Validator_GUI_DoSite button from the main window.
# It checks that all site details are specified then proceeds with 
# running the validation tool and returns the results in the results
# window.
#
#***********************************************************************
sub Validator_GUI_DoSite_Click {
    my ($key, $value, %report_options, $name, $tabid);
    my (%crawl_details, $fieldname);

    #
    # Get the site details from the form fields and remove leading or trailing
    # whitespace.
    #
    foreach $fieldname (keys %site_configuration_fields) {
        $crawl_details{$fieldname} = Get_Field_Value($main_window->ConfigTabs,
                                                     $site_configuration_fields{$fieldname});
        print "Field $fieldname, value = " . $crawl_details{$fieldname} . "\n" if $debug;
    }

    #
    # See if the French values have been specified, if not use
    # the English values.
    #
    if ( $crawl_details{"sitedirf"} eq "" ) {
        $crawl_details{"sitedirf"} = $crawl_details{"sitedire"};
    }
    if ( $crawl_details{"siteentryf"} eq "" ) {
        $crawl_details{"siteentryf"} = $crawl_details{"siteentrye"};
    }

    #
    # If we don't have a crawl limit, use default
    #
    if ( $crawl_details{"crawllimit"} eq "" ) {
        $crawl_details{"crawllimit"} = $default_crawllimit;
    }

    #
    # If we don't have a crawl depth, use default
    #
    if ( $crawl_details{"crawl_depth"} eq "" ) {
        $crawl_details{"crawl_depth"} = $default_crawl_depth;
    }

    #
    # Interstitial page count defaults
    #
    if ( $crawl_details{"logininterstitialcount"} eq "" ) {
        $crawl_details{"logininterstitialcount"} = 0;
    }
    if ( $crawl_details{"logoutinterstitialcount"} eq "" ) {
        $crawl_details{"logoutinterstitialcount"} = 0;
    }

    #
    # Get any report options
    #
    %report_options = Get_Report_Options();
    
    #
    # Copy report options into the crawl details hash table
    #
    while ( ($key, $value) = each %report_options ) {
        $crawl_details{$key} = $value;
    }
    
    #
    # Copy menu options into crawl details hash table
    #
    $crawl_details{"report_fails_only"} = $report_fails_only;
    $crawl_details{"save_content"} = $save_content;
    $crawl_details{"process_pdf"} = $process_pdf;
    $crawl_details{"enable_generated_markup"} = $enable_generated_markup;

    #
    # Show the results window and clear any text.
    #
    foreach $tabid (values %results_window_tab_labels) {
        $name = "results$tabid";
        $results_window->ResultTabs->$name->Text("");
    }
    Results_Window_Tabstrip_Click();
    $results_window->Show();
    $results_window->BringWindowToTop();
    Win32::GUI::DoEvents();

    #
    # Call the site crawl callback function
    #
    if ( defined($site_crawl_callback) ) {
        #
        # Create a new thread to handle the site crawl.  This leaves
        # the main thread free to respond to GUI events.
        #
        print "Child: Call site_crawl_callback\n" if $debug;
        $child_thread = threads->create(\&Run_Site_Crawl,%crawl_details);

        #
        # Detach the thread so it can run freely
        #
        print "Detach crawler thread\n" if $debug;
        $child_thread->detach();
    }
    else {
        print "Error: Missing site crawl callback function in Validator_GUI_DoSite_Click\n";
        exit(1);
    }

    print "Return from Validator_GUI_DoSite_Click\n" if $debug;
    return 0;
}

#***********************************************************************
#
# Name: Kill_Child_Thread
#
# Parameters: none
#
# Description:
#
#   This function kills of any child thread that may be running.
#
#***********************************************************************
sub Kill_Child_Thread {
    my ($p);

    #
    # Kill child thread if we have one.
    #
    if ( defined($child_thread) ) {
        print "Kill_Child_Thread\n" if $debug;
        $child_thread->kill('KILL');
    }
}

#***********************************************************************
#
# Name: Stop_Site_Crawl
#
# Parameters: none
#
# Description:
#
#   This function stops any site crawl by killing any crawl thread
# that is running.  It also adds a note to each of the results panes
# to state the analysis was aborted.
#
#***********************************************************************
sub Stop_Site_Crawl {
    my ($tab_label);

    #
    # Are we running a crawl ?
    #
    if ( defined($child_thread) ) {
        #
        # Abort the crawler
        #
        Crawler_Abort_Crawl(1);
    }
    return 0;
}

#***********************************************************************
#
# Name: Validator_GUI_Main_Terminate
#
# Parameters: none
#
# Description:
#
#   This function handles closing of the main message window. It exits
# the Win32::GUI::Dialog call.
#
#***********************************************************************
sub Validator_GUI_Main_Terminate {
        #
        # Clean up and exit the main window
        #
        print "Main window terminate\n" if $debug;
        Main_Exit();

	return -1;
}

#***********************************************************************
#
# Name: Save_Tab_Results_To_File
#
# Parameters: tab - name of results tab
#
# Description:
#
#   This function saves the text in the named tab to a file.  The
# name of the file is derived from the tab name.
#
#***********************************************************************
sub Save_Tab_Results_To_File {
    my ($tab, $suffix, $filename) = @_;

    my ($tabid, $name, $text, $results_file);

    #
    # Get tabid corresponding to the results tab
    #
    if ( ! defined($results_window_tab_labels{$tab}) ) {
        print "Error: Unknown tab $tab\n";
        exit(1);
    }
    $tabid = $results_window_tab_labels{$tab};
    $name = "results$tabid";

    #
    # Get result text and convert return-newline into a
    # simple newline.
    #
    $text = $results_window->ResultTabs->$name->Text();
    $text =~ s/\r\n/\n/mg;

    #
    # Construct output file name
    #
    if ( $xml_output_mode ) {
        $results_file = $filename . ".xml";
    }
    else {
        $results_file = $filename . "_$suffix.txt";
    }

    #
    # Save text in file
    #
    if ( open(FILE, ">$results_file") ) {
        binmode FILE;
        print(FILE $text);
        close(FILE);
    }
    else {
        Error_Message_Popup("Failed to save results in $results_file");
    }
}

#***********************************************************************
#
# Name: Results_Save_As
#
# Parameters: self - reference to results dialog
#
# Description:
#
#   This function saves results text file.
#
#***********************************************************************
sub Results_Save_As {
    my ($self) = @_;

    my ($filename, $text, $tab, $suffix, $results_file, $name, $tabid);
    my ($output_suffix);

    #
    # Are we in XML mode ?
    #
    if ( $xml_output_mode ) {
        $output_suffix = "xml";
    }
    else {
        $output_suffix = "txt";
    }

    #
    # Get name of file to save results in
    #
    $filename = Win32::GUI::GetSaveFileName(
                   -owner  => $main_window,
                   -title  => String_Value("Save As"),
                   -directory => "$program_dir\\results",
                   -file   => "",
                   -filter => [
                       'Text file (*.txt)' => '*.txt',
                       'XML file (*.xml)' => '*.xml',
                       'All files' => '*.*',
                    ],
                   -defaultextension => $output_suffix,
                   -createprompt => 1,
                   );

    #
    # Was a file name specified ?
    #
    if ( defined($filename) ) {
        #
        # It is possible that the user selected an existing results file.
        # We have to strip of the results suffix to get the base file name.
        #
        $filename =~ s/\.txt$//;
        $filename =~ s/\.xml$//;
        while ( ($tab, $suffix) = each %results_file_suffixes ) {
            $filename =~ s/_$suffix$//;
        }

        #
        # Are we in XML mode, in this case we only save the xml content,
        # not the other tabs.
        #
        if ( $xml_output_mode ) {
            Save_Tab_Results_To_File($xml_tab_label, "xml", $filename);
        }
        else {
            #
            # Get text from each results tab
            #
            while ( ($tab, $suffix) = each %results_file_suffixes ) {
                Save_Tab_Results_To_File($tab, $suffix, $filename);
            }
            
            #
            # Save CSV results
            #
            if ( defined($csv_results_file_name) ) {
                print "Copy results CSV\n" if $debug;
                copy($csv_results_file_name, $filename . "_rslt.csv");
                unlink($csv_results_file_name);
                undef($csv_results_file_name);
            }

            #
            # Call results save callback function (except in XML mode)
            #
            if ( defined($results_save_callback) ) {
                print "Call Results_Save_As callback function\n" if $debug;
                &$results_save_callback($filename);
            }
        }
    }
}

#***********************************************************************
#
# Name: Results_Window_Tabstrip_Click
#
# Parameters: none
#
# Description:
#
#   This function handles a click in the results window's tabstrip.  It
# displays the items in the selected tab.
#
#***********************************************************************
sub Results_Window_Tabstrip_Click {

    my ($current_tab, $key, $ref, $tabid);

    #
    # Get the selected tab
    #
    $current_tab = $results_window->ResultTabs->SelectedItem();

    #
    # Get all of the attributes of all the widgets in the results tab
    #
    foreach $key (keys %{$results_window->ResultTabs}) {
       #
       # Skip these items - what reresultss should be just widgets.
       #
       next if (grep(/^${key}$/,qw(-handle -name -type)));

       #
       # Get the widget reference
       #
       $ref = $results_window->ResultTabs->{$key};

       #
       # Check for key accel, for an unknown reason it cannot be included
       # in the above grep.
       #
       if ( $key eq "-accel" ) {
           next;
       }

       #
       # Strip off number from end of -name - use as tabid.
       # A better way would be to define something like "-tabid => .."
       # But this does not carry over after the widget is defined.
       #
       $tabid = substr($ref->{-name},-2);
       if ( ($tabid =~ /\d\d/) && ($current_tab == $tabid) ) {
          $ref->Show();
       }
       else {
          $ref->Hide();
       }
    }
}

#***********************************************************************
#
# Name: Create_Results_Window
#
# Parameters: none
#
# Description:
#
#   This function creates the results window.
#
#***********************************************************************
sub Create_Results_Window {

    my ($results_window, $current_pos, $menu, $h, $w, $tab);

    #
    # Setup dialog menu.
    #
    $menu = Win32::GUI::MakeMenu(
    "&" . String_Value("File") => "File",
    " > " . String_Value("Save As")  => { -name => "SaveAs", -onClick => \&Results_Save_As },
    " > " . String_Value("Close") => { -name => "Close",   -onClick => \&Results_Close },

    "&" . String_Value("Options")   => "Options",
    " > &" . String_Value("Stop Crawl")   => { -name => "StopCrawl",
                                -onClick => \&Stop_Site_Crawl }
    );

    #
    # Create results window.
    #
    print "Create results window\n" if $debug;
    $results_window = Win32::GUI::DialogBox->new(
            -name => 'Validator_GUI_Results',
            -text => String_Value("Results Window Title"),
            -menu => $menu,
            -width => 800,
            -height => 500,
            -resizable => 0,
            -helpbutton => 0,
    );

    #
    # Add a TabStrip to the window.
    #
    $results_window->AddTabStrip (
        -name   => "ResultTabs",
        -panel  => "Tab",
        -width  => 775,
        -height => 450,
        -onClick => \&Results_Window_Tabstrip_Click
    );
    $current_pos += 450;
    $results_window_tab_count = -1;

    #
    # Return results dialog handle
    #
    return($results_window);
}

#***********************************************************************
#
# Name: Validator_GUI_401_Authorization_Terminate
#
# Parameters: none
#
# Description:
#
#   This function handles closing the authorization message window. 
# It simply hides the window.
#
#***********************************************************************
sub Validator_GUI_401_Authorization_Terminate {
    print "Validator_GUI_401_Authorization_Terminate\n" if $debug;

    if ( defined($authorization_401_window) ) {
        $authorization_401_window->Hide();
        $login_window_open = 0;
    }
    return 0;
}

#***********************************************************************
#
# Name: GUI_Close_Browser_OK_Button_Click
#
# Parameters: url - page URL
#             content - page content
#
# Description:
#
#   This function handles the click of the Ok button in the close
# browser dialog.
#
#***********************************************************************
sub GUI_Close_Browser_OK_Button_Click {
    #
    # Hide the window
    #
    $browser_close_window->Hide();
    $browser_close_window_open = 0;
    return 0;
}

#***********************************************************************
#
# Name: Create_Browser_Close_Window
#
# Parameters: none
#
# Description:
#
#   This function creates a window to inform the user that the browser
# window is about to be closed.
#
#***********************************************************************
sub Create_Browser_Close_Window {
    my ($url, $realm) = @_;

    my ($current_pos, $window);

    #
    # Create message window.
    #
    print "Create browser close window\n" if $debug;
    $window = Win32::GUI::DialogBox->new(
            -name => 'Validator_GUI_Close_Browser',
            -text => String_Value("Close Browser"),
            -pos => [100, 100],
            -width => 300,
            -height => 100,
            -helpbutton => 0,
    );
    $current_pos = 10;

    #
    # Add Continue text
    #
    $current_pos = 10;
    $window->AddLabel(
        -text => String_Value("Press Ok to close browser"),
        -pos => [10,$current_pos],
    );
    $current_pos += 25;

    #
    # Add button
    #
    $window->AddButton(
            -name    => 'Validator_GUI_Close_Browser_OK_Button',
            -text    => String_Value("Ok"),
            -ok      => 1,
            -pos => [10,$current_pos],
            -tabstop => 1,
            -onClick => \&GUI_Close_Browser_OK_Button_Click,
    );

    #
    # Show the dialog
    #
    $window->Show();
    return($window);
}

#***********************************************************************
#
# Name: GUI_401_OK_Button_Click
#
# Parameters: none
#
# Description:
#
#   This function handles a click on the OK button in the 401
# authorization dialog.
#
#***********************************************************************
sub GUI_401_OK_Button_Click {

    #
    # Hide the window
    #
    print "GUI_401_OK_Button_Click\n" if $debug;

    if ( defined($authorization_401_window) ) {
        $authorization_401_window->Hide();
        $login_window_open = 0;
    }
    return 0;
}

#***********************************************************************
#
# Name: Create_401_Authorization_Window
#
# Parameters: url - url that resulted in 401 error
#             realm - message for 401 dialog
#
# Description:
#
#   This function creates a window to handle login for web server
# protected content.
#
#***********************************************************************
sub Create_401_Authorization_Window {
    my ($url, $realm) = @_;

    my ($current_pos, $login_window, $msg_len, $prompt);

    #
    # Get the size of the URL so we know how big to make the window.
    #
    $msg_len = length($url);
    
    #
    # If the realm string is longer than the URL, take that length
    #
    if ( length($realm) > $msg_len ) {
        $msg_len = length($realm);
    }

    #
    # Create Authorization window.
    #
    print "Create login window\n" if $debug;
    $login_window = Win32::GUI::DialogBox->new(
            -name => 'Validator_GUI_401_Authorization',
            -text => String_Value("Authorization Required"),
            -pos => [100, 100],
            -width => 100 + 6 * $msg_len,
            -height => 200,
            -helpbutton => 0,
    );
    $current_pos = 10;

    #
    # Add label for authorization
    #
    $prompt = String_Value("Authorization required for");
    $login_window->AddLabel(
        -text => $prompt,
        -pos => [10, $current_pos],
    );
    $current_pos += 25;

    #
    # Add label for URL
    #
    $login_window->AddLabel(
        -text => "URL : $url",
        -pos => [30, $current_pos],
    );
    $current_pos += 25;

    #
    # Add label for realm
    #
    $login_window->AddLabel(
        -text => "Realm : $realm",
        -pos => [30, $current_pos],
    );
    $current_pos += 25;

    #
    # Add User field
    #
    $prompt = String_Value("User Name");
    $login_window->AddTextfield(
        -name => "User",
        -prompt => [ $prompt, 100 ],
        -pos => [10, $current_pos],
        -size => [100,20],
        -align => 'left',
        -tabstop => 1,
    );
    $current_pos += 25;

    #
    # Add Password field
    #
    $prompt = String_Value("Password");
    $login_window->AddTextfield(
        -name => "Password",
        -prompt => [ $prompt, 100 ],
        -pos => [10, $current_pos],
        -size => [100,20],
        -align => 'left',
        -tabstop => 1,
        -password => 1,
    );
    $current_pos += 25;

    #
    # Add button for login
    #
    $login_window->AddButton(
            -name    => 'Validator_GUI_401_OK_Button',
            -text    => String_Value("Ok"),
            -ok      => 1,
            -pos => [10,$current_pos],
            -tabstop => 1,
            -onClick => \&GUI_401_OK_Button_Click,
    );

    #
    # Show the login dialog
    #
    $login_window->Show();
    return($login_window);
}

#***********************************************************************
#
# Name: Validator_GUI_401_Login
#
# Parameters: url - url that resulted in 401 error
#             realm - message for 401 dialog
#
# Description:
#
#   This function gets the credentials in order to access protected
# documents. These are documents protected by server authentication.
#
#***********************************************************************
sub Validator_GUI_401_Login {
    my ($url, $realm) = @_;

    my ($user, $password);

    #
    # Do we already have credentials (e.g. through configuration) ?
    #
    if ( defined($url_401_user{$url}) && defined($url_401_password{$url}) ) {
        print "Use 401 credentials from profile configuration\n" if $debug;
        $user = $url_401_user{$url};
        $password = $url_401_password{$url};
    }
    else {
        #
        # Create a dialog window for the authorization fields
        #
        $authorization_401_window = Create_401_Authorization_Window($url,
                                                                    $realm);
        $login_window_open = 1;

        #
        # Loop until the dialog window is closed
        #
        while ( $login_window_open ) {
            Win32::GUI::DoEvents();
            sleep(1);
        }

        #
        # Get user name & password and trim off leading & trailing white space
        #
        $user = $authorization_401_window->User->Text();
        if ( ! defined($user) || $user eq "" ) {
            #
            # If user is undefined or blank, set it to unknown.
            # This avoids a problem with the GUI which will prematurely exit
            # if there is no user set.  There is no obvious reason why the
            # GUI should exit in this case, but it does.
            #
            $user = "unknown";
        }
        $password = $authorization_401_window->Password->Text();
        if ( ! defined($password) ) {
            $password = "";
        }
        $user =~ s/^\s+//g;
        $user =~ s/\s+$//g;
        $password =~ s/^\s+//g;
        $user =~ s/\s+$//g;
    }

    #
    # Return login values
    #
    return($user, $password);
}

#***********************************************************************
#
# Name: Validator_GUI_Login_Terminate
#
# Parameters: none
#
# Description:
#
#   This function handles closing the login message window. It simply
# hides the window.
#
#***********************************************************************
sub Validator_GUI_Login_Terminate {
        print "Validator_GUI_Login_Terminate\n" if $debug;
        $login_window->Hide();
        $login_window_open = 0;
        return 0;
}

#***********************************************************************
#
# Name: Login_Form_Login_Click
#
# Parameters: none
#
# Description:
#
#   This function handles a click on the Login button in the login
# form window. It collects the form values and calls the login 
# callback function.
#
#***********************************************************************
sub Login_Form_Login_Click {

    my ($field_name);

    #
    # Get the form field values
    #
    print "Login_Form_Login_Click\n" if $debug;
    foreach $field_name (@login_form_field_list) {
        print "Get value for field $field_name\n" if $debug;
        $login_form_values{$field_name} = $login_window->$field_name->Text();
    }

    #
    # Hide the window
    #
    $login_window->Hide();
    $login_window_open = 0;
    return 0;
}

#***********************************************************************
#
# Name: Create_Login_Form_Window
#
# Parameters: field_list - table of fields and field type
#
# Description:
#
#   This function creates a window to handle site logins.
#
#***********************************************************************
sub Create_Login_Form_Window {
    my (%field_list) = @_;

    my ($current_pos, $field_name, $max_len, $field_type, $password);

    #
    # Save the set of login field names
    #
    @login_form_field_list = keys %field_list;

    #
    # Get length of longest field name
    #
    $max_len = 1;
    while ( ($field_name, $field_type) = each %field_list ) {
        if ( length($field_name) > $max_len ) {
            $max_len = length($field_name);
        }
    }

    #
    # Create Login window.
    #
    print "Create login window\n" if $debug;
    $login_window = Win32::GUI::DialogBox->new(
            -name => 'Validator_GUI_Login',
            -text => String_Value("Login"),
            -pos => [100, 100],
            -width => 200 + ($max_len * 8),
            -height => 75 + (@login_form_field_list * 25),
            -helpbutton => 0,
    );

    #
    # Add fields
    #
    $current_pos = 10;
    while ( ($field_name, $field_type) = each %field_list ) {
        #
        # Is this field a password ?
        #
        if ( $field_type eq "password" ) {
            $password = 1;
        }
        else {
            $password = 0;
        }

        #
        # Add text field for login form field
        #
        print "Add field $field_name\n" if $debug;
        $login_window->AddTextfield(
            -name => $field_name,
            -prompt => [ "$field_name", ($max_len * 8) ],
            -pos => [10,$current_pos],
            -size => [100,20],
            -align => 'left',
            -tabstop => 1,
            -password => $password,
        );
        $current_pos += 25;
    }

    #
    # Add button for login
    #
    $login_window->AddButton(
            -name    => 'Validator_GUI_Login',
            -text => String_Value("Login"),
            -ok      => 1,
            -pos => [10,$current_pos],
            -tabstop => 1,
            -onClick => \&Login_Form_Login_Click,
    );


    #
    # Show the login dialog
    #
    $login_window->Show();
}

#***********************************************************************
#
# Name: Validator_GUI_Login
#
# Parameters: login_fields - table of fields and field type
#
# Description:
#
#   This function gets the credentials to performs a login.  It creates
# a dialog to get values for the login form, then waits for the user
# response.  It returns a hash table of furm field and value.
#
#***********************************************************************
sub Validator_GUI_Login {
    my (%login_fields) = @_;

    my ($field_name);

    #
    # Initialize login form values table
    #
    %login_form_values = ();
    foreach $field_name (keys %login_fields) {
        $login_form_values{$field_name} = "";
    }
    
    #
    # Do we already have login credentials from a profile
    # file ?
    #
    if ( keys(%login_credentials) > 0 ) {
        foreach $field_name (keys %login_fields) {
            if ( defined($login_credentials{$field_name}) ) {
                $login_form_values{$field_name} = $login_credentials{$field_name};
            }
        }

        #
        # Return login form values
        #
        return(%login_form_values);
    }
    
    #
    # Create a dialog window for the login form fields
    #
    Create_Login_Form_Window(%login_fields);
    $login_window_open = 1;

    #
    # Loop until the dialog window is closed
    #
    while ( $login_window_open ) {
        Win32::GUI::DoEvents();
        sleep(1);
    }

    #
    # Return login form values
    #
    return(%login_form_values);
}

#***********************************************************************
#
# Name: Main_Exit
#
# Parameters: none
#
# Description:
#
#   This function handles exiting the main dialog.  It exits
# the Win32::GUI::Dialog call.
#
#***********************************************************************
sub Main_Exit {
    #
    # Kill any child thread we may have
    #
    Kill_Child_Thread();

    #
    # Release the IE window that is being used for the browser.
    #
    print "Exit main window\n" if $debug;
    Close_Browser_Window();

    #
    # Return -1 to signal the termination of the GUI
    #
    return -1;
}

#***********************************************************************
#
# Name: Add_Text_Field_And_Example_Text
#
# Parameters: tab_strip - TabStrip handle
#             tabid - tab identifier
#             name - name of text field
#             prompt - text field prompt
#             example - example text
#             current_pos - current dialog position
#
# Description:
#
#   This function adds a label, text field and example text to a tab.
#
#***********************************************************************
sub Add_Text_Field_And_Example_Text {
    my ($tab_strip, $tabid, $name, $prompt, $example, $current_pos, 
        $label_width) = @_;

    #
    # Save config tab field name
    #
    $site_configuration_fields{$name} = $name . $tabid;
    
    #
    # Add text label
    #
    $tab_strip->AddLabel(
        -name => "Label_" . $name . $tabid,
        -text => "$prompt",
        -pos => [10,$current_pos],
    );

    #
    # Add text field
    #
    $tab_strip->AddTextfield(
        -name => $name . $tabid,
        -pos => [$label_width,$current_pos],
        -size => [500,20],
        -align => 'left',
        -tabstop => 1,
    );
    $current_pos += 25;

    #
    # Add example text
    #
    $tab_strip->AddLabel(
        -name => "Example_" . $name . $tabid,
        -text => "$example",
        -pos => [$label_width,$current_pos],
    );
    $current_pos += 25;

    #
    # Return updated position
    #
    return($current_pos);
}

#***********************************************************************
#
# Name: Add_Direct_Input_Fields
#
# Parameters: main_window - window handle
#             tab_count - count of number of tabs in tab strip
#
# Description:
#
#   This function adds a tab for direct HTML input, to the main window.
#
#***********************************************************************
sub Add_Direct_Input_Fields {
    my ($main_window, $tab_count) = @_;

    my ($current_pos) = 30;
    my ($tabid, $name, $h, $w, $text_field_name);

    #
    # Add title to the tab and increment tab count
    #
    $main_window->ConfigTabs->InsertItem(
        -text   => String_Value("Direct HTML Input"),
    );
    $tab_count++;

    #
    # Set tab identifier
    #
    $tabid = sprintf("_%02d", $tab_count);
    $html_input_tabid = $tabid;

    #
    # Get the height and width of the tab page.
    #
    $w = $main_window->ConfigTabs->Width - 20;
    $h = $main_window->ConfigTabs->Height - 20;

    #
    # Add scrolling text field for URL list
    #
    $text_field_name = "direct_html_input$tabid";
    $main_window->ConfigTabs->AddTextfield(
        -name => $text_field_name,
        -pos => [5,$current_pos],
        -size => [$w - 40,$h - 80],
        -multiline => 1,
        -hscroll   => 1,
        -vscroll   => 1,
        -autohscroll => 1,
        -autovscroll => 1,
        -keepselection => 1,
        -wantreturn => 1,
    );
    $current_pos += ($h - 80) + 10;
    
    #
    # Set maximum size for text area
    #
    $main_window->ConfigTabs->$text_field_name->SetLimitText($GUI_DIRECT_HTML_SIZE);

    #
    # Add button to reset HTML text
    #
    $name = "GUI_Reset_HTML$tabid";
    $main_window->ConfigTabs->AddButton(
          -name   => $name,
          -text   => String_Value("Reset"),
          -width  => 40,
          -height => 20,
          -pos => [20, $current_pos],
          -tabstop => 1,
          -onClick => sub {
                            $main_window->ConfigTabs->$text_field_name->Text("");
                          }
    );

    #
    # Add button to check HTML content
    #
    $name = "GUI_Do_HTML$tabid";
    $main_window->ConfigTabs->AddButton(
	    -name   => $name,
	    -text   => String_Value("Check"),
	    -width  => 110,
	    -height => 20,
          -pos => [($w - 150), $current_pos],
          -tabstop => 1,
          -onClick => \&GUI_Do_HTML_Click
    );

    #
    # Return tab count
    #
    return($tab_count);
}

#***********************************************************************
#
# Name: Validate_Option_Value
#
# Parameters: option_name - name of report option
#             option_value - value of option field
#
# Description:
#
#   This function validates the value of a particular option against
# the set of valid values.  It returns the language appropriate value
# for the option (e.g. translates it from the supplied value into
# the value for the current language of the tool).
#
#***********************************************************************
sub Validate_Option_Value {
    my ($option_name, $option_value) = @_;

    my ($name, $value, $possible_values);
    my ($valid_value) = 0;

    #
    # Get the valid values for this report option type
    #
    if ( defined($report_options_values{$option_name}) ) {
        $possible_values = $report_options_values{$option_name};

        #
        # Convert the current value into the language appropriate
        # value
        #
        if ( defined($$possible_values{$option_value}) ) {
            print "Replace option value $option_value with " .
                  $$possible_values{$option_value} . " in $option_name\n" if $debug;
            $option_value = $$possible_values{$option_value};
            $valid_value = 1;
        }
        else {
            print "No language specific value for $option_value in $option_name\n" if $debug;
        }
    }
    else {
        print "No report_options_values entry for $option_name\n" if $debug;
    }

    #
    # Return validated value
    #
    return($valid_value, $option_value);
}

#***********************************************************************
#
# Name: GUI_Do_Load_URL_List_from_File_Click
#
# Parameters: self - reference to main dialog
#
# Description:
#
#   This function reads a URL list from a file.
#
#***********************************************************************
sub GUI_Do_Load_URL_List_from_File_Click {
    my ($self) = @_;

    my ($filename, $line, $url_list, $name, $field_name, $value, $type, $url);
    my ($valid_value, $got_group_profile);

    #
    # Get name of file to read configuration from
    #
    $filename = Win32::GUI::GetOpenFileName(
                   -owner  => $main_window,
                   -title  => "Load URL List",
                   -directory => "$program_dir\\profiles",
                   -file   => "",
                   -filter => [
                       'Text file (*.txt)' => '*.txt',
                       'All files' => '*.*',
                    ],
                   -defaultextension => "txt",
                   );

    #
    # Was a file name specified ?
    #
    if ( defined($filename) ) {

        #
        # Empty the HTTP 401 credentials set
        #
        %url_401_user = ();
        %url_401_password = ();
        $got_group_profile = 0;

        #
        # Initialize group profile to custom
        #
        Select_Custom_Testcase_Profile_Group();

        #
        # Open the URL list file
        #
        if ( open(FILE, "$filename") ) {
            #
            # Read all lines from the file
            #
            $url_list = "";
            while ( <FILE> ) {
                chop;
                if ( /^#/ ) {
                    #
                    # Comment line
                    #
                    $url_list .= "\r\n" . $_;
                    next;
                }
                elsif ( /^$/ ) {
                    next;
                }

                #
                # Split line into 2 parts, configuration parameter, value
                #
                ($field_name, $value) = split(/\s+/, $_, 2);

                #
                # Is this line a configuration option line ?
                #
                if ( defined($site_configuration_fields{$field_name}) ) {
                    #
                    # Load value into main dialog
                    #
                    $name = $site_configuration_fields{$field_name};
                    print "Set configuration item $name to $value\n" if $debug;
                    $main_window->ConfigTabs->$name->Text("$value");
                }
                elsif ( defined($report_options_field_names{$field_name}) ) {
                    #
                    # Load value into main dialog
                    #
                    $name = $report_options_field_names{$field_name};
                    ($valid_value, $value) = Validate_Option_Value($field_name, $value);
                    if ( $valid_value ) {
                        print "Set configuration selector $name to $value\n" if $debug;
                        $main_window->ConfigTabs->$name->SelectString("$value");

                        #
                        # Is this a group profile option ?
                        #
                        if ( $field_name eq $testcase_profile_groups_config_option ) {
                            $got_group_profile = 1;
                        }
                    }
                }
                #
                # Have HTTP 401 credentials
                #
                 elsif ( $field_name eq "HTTP_401" ) {
                    ($field_name, $url, $type, $value) = split(/\s+/, $line);

                    #
                    # Is this a username or password ?
                    #
                    if ( defined($value) && ($type eq "user") ) {
                        $url_401_user{$url} = $value;
                    }
                    elsif ( defined($value) && ($type eq "password") ) {
                        $url_401_password{$url} = $value;
                    }
                }
                elsif ( $field_name eq "output_file" ) {
                    #
                    # Skip over the output file setting, it is used in
                    # command line mode.
                    #
                }
                #
                # Have generated source flag ?
                #
                elsif ( $field_name eq "enable_generated_markup" ) {
                    ($field_name, $value) = split(/\s+/, $line, 2);
                    $enable_generated_markup = $value;
                }
                else {
                    #
                    # Must be a URL, add it to the list
                    #
                    $url_list .= "\r\n" . $_;
                }
            }
            close(FILE);

            #
            # Did we find a group profile value ?
            #
            if ( $got_group_profile ) {
                #
                # Update all the other testcase profile options
                #
                Select_Testcase_Profile_Group();
            }

            #
            # Set URL list in main window
            #
            $name = "url_list$url_list_tabid";
            $main_window->ConfigTabs->$name->Text("$url_list"); 

            #
            # Update the results page
            #
            Win32::GUI::DoEvents();
        }
        else {
            Error_Message_Popup("Failed to open site configuration file $filename");
        }
    }
}

#***********************************************************************
#
# Name: Add_URL_List_Input_Fields
#
# Parameters: main_window - window handle
#             tab_count - count of number of tabs in tab strip
#
# Description:
#
#   This function adds a tab for entering a list of URLs, to the main window.
#
#***********************************************************************
sub Add_URL_List_Input_Fields {
    my ($main_window, $tab_count) = @_;

    my ($current_pos) = 30;
    my ($tabid, $name, $h, $w, $text_field_name);

    #
    # Add title to the tab and increment tab count
    #
    $main_window->ConfigTabs->InsertItem(
        -text   => String_Value("URL List"),
    );
    $tab_count++;

    #
    # Set tab identifier
    #
    $tabid = sprintf("_%02d", $tab_count);
    $url_list_tabid = $tabid;

    #
    # Get the height and width of the tab page.
    #
    $w = $main_window->ConfigTabs->Width - 20;
    $h = $main_window->ConfigTabs->Height - 20;

    #
    # Add scrolling text field for URL list
    #
    $text_field_name = "url_list$tabid";
    $main_window->ConfigTabs->AddTextfield(
        -name => $text_field_name,
        -pos => [5,$current_pos],
        -size => [$w - 40,$h - 80],
        -multiline => 1,
        -hscroll   => 1,
        -vscroll   => 1,
        -autohscroll => 1,
        -autovscroll => 1,
        -keepselection => 1,
        -wantreturn => 1,
    );
    $current_pos += ($h - 80) + 10;

    #
    # Set maximum size for text area
    #
    $main_window->ConfigTabs->$text_field_name->SetLimitText($GUI_URL_LIST_SIZE);

    #
    # Add button to read URL list from a file
    #
    $name = "GUI_Load_URL_List$tabid";
    $main_window->ConfigTabs->AddButton(
	  -name   => $name,
	  -text   => String_Value("Load from File"),
	  -width  => 130,
	  -height => 20,
          -pos => [20, $current_pos],
          -tabstop => 1,
          -onClick => \&GUI_Do_Load_URL_List_from_File_Click
    );

    #
    # Add button to reset URL list
    #
    $name = "GUI_Reset_URL_List$tabid";
    $main_window->ConfigTabs->AddButton(
	  -name   => $name,
	  -text   => String_Value("Reset"),
	  -width  => 40,
	  -height => 20,
          -pos => [($w / 2), $current_pos],
          -tabstop => 1,
          -onClick => sub {
                            $main_window->ConfigTabs->$text_field_name->Text("");
                          }
    );

    #
    # Add button to check URL list
    #
    $name = "GUI_Do_URL_List$tabid";
    $main_window->ConfigTabs->AddButton(
	  -name   => $name,
	  -text   => String_Value("Check URL List"),
	  -width  => 130,
	  -height => 20,
          -pos => [($w - 150), $current_pos],
          -tabstop => 1,
          -onClick => \&GUI_Do_URL_List_Click
    );

    #
    # Return tab count
    #
    return($tab_count);
}

#***********************************************************************
#
# Name: Add_Config_Fields
#
# Parameters: main_window - window handle
#             tab_count - count of number of tabs in tab strip
#             report_options - table of report options
#
# Description:
#
#   This function adds a tab for configuration options then adds the configuration
# options.
#
#***********************************************************************
sub Add_Config_Fields {
    my ($main_window, $tab_count, %report_options) = @_;

    my ($current_pos) = 50;
    my ($tabid, $name, $h, $w, $num_options, $option_label);
    my ($option_list_addr, $x_pos);

    #
    # Add title to the tab and increment tab count
    #
    $main_window->ConfigTabs->InsertItem(
        -text   => String_Value("Configuration"),
    );
    $tab_count++;

    #
    # Set tab identifier
    #
    $tabid = sprintf("_%02d", $tab_count);
    $config_tabid = $tabid;

    #
    # Get the height and width of the tab page.
    #
    $w = $main_window->ConfigTabs->Width - 20;
    $h = $main_window->ConfigTabs->Height - 20;

    #
    # Add selector for this configuration option
    #
    if ( defined($testcase_profile_groups_label) ) {
        Add_Report_Option_Testcase_Profile_Group_Selector($main_window->ConfigTabs,
                                       $tabid, $current_pos,
                                       $testcase_profile_groups_label,
                                       $testcase_profile_groups_names);
                                       
        #
        # Start testcase selectors to the right of the
        # testcase profile group selector.
        #
        $x_pos = 300;
    }
    else {
        #
        # Start testcase selectors to the left of the tab.
        #
        $x_pos = 50;
    }

    #
    # Add selector for each option. Present options in alphabetical order
    #
    foreach $option_label (sort(keys %report_options)) {
        #
        # Add selector for this configuration option
        #
        $option_list_addr = $report_options{$option_label};
        $current_pos = Add_Report_Option_Selector($main_window->ConfigTabs,
                                   $tabid, $current_pos, $x_pos,
                                   $option_label, $option_list_addr);
    }
    
    #
    # Return tab count
    #
    return($tab_count);
}

#***********************************************************************
#
# Name: Add_Site_Crawl_Fields
#
# Parameters: main_window - window handle
#             tab_count - current tab count in tab strip
#
# Description:
#
#   This function adds the site crawl fields to the main window.
#
#***********************************************************************
sub Add_Site_Crawl_Fields {
    my ($main_window, $tab_count) = @_;

    my ($current_pos) = 50;
    my ($tabid, $name, $h, $w);

    #
    # Add title to the tab and increment the tab count
    #
    print "Add site crawl fields to main window\n" if $debug;
    $main_window->ConfigTabs->InsertItem(
        -text   => String_Value("Site Details"),
    );
    $tab_count++;

    #
    # Set tabid
    #
    $tabid = sprintf("_%02d", $tab_count);
    $site_config_tabid = $tabid;

    #
    # Get the height and width of the tab page.
    #
    $w = $main_window->ConfigTabs->Width - 20;
    $h = $main_window->ConfigTabs->Height - 20;

    #
    # Add text field for English site directory
    #
    $current_pos = Add_Text_Field_And_Example_Text($main_window->ConfigTabs, 
                          $tabid, "sitedire", 
                          String_Value("English directory"),
                          String_Value("Example") .
                           " 'http://www.tpsgc-pwgsc.gc.ca/comm'",
                          $current_pos, $site_label_width);

    #
    # Add text field for English entry page
    #
    $current_pos = Add_Text_Field_And_Example_Text($main_window->ConfigTabs,
                          $tabid, "siteentrye", 
                          String_Value("English entry page"),
                          String_Value("Example") . 
                            " 'index-eng.html'",
                          $current_pos, $site_label_width);

    #
    # Add text field for French site directory
    #
    $current_pos = Add_Text_Field_And_Example_Text($main_window->ConfigTabs,
                          $tabid, "sitedirf", 
                          String_Value("French directory"),
                          String_Value("Example") . 
                            " 'http://www.tpsgc-pwgsc.gc.ca/comm' " .
                            String_Value("if blank use English"),
                          $current_pos, $site_label_width);

    #
    # Add text field for French entry page
    #
    $current_pos = Add_Text_Field_And_Example_Text($main_window->ConfigTabs,
                          $tabid, "siteentryf", 
                          String_Value("French entry page"),
                          String_Value("Example") .
                            " 'index-fra.html' " .
                            String_Value("if blank use English"),
                          $current_pos, $site_label_width);

    #
    # Add field for crawl limit
    #
    $current_pos = Add_Text_Field_And_Example_Text($main_window->ConfigTabs,
                          $tabid, "crawllimit",
                          String_Value("Crawl Limit"),
                          String_Value("The maximum number of URLs"),
                          $current_pos, $site_label_width);

    #
    # Set default crawl limit
    #
    $name = "crawllimit$site_config_tabid"; 
    $main_window->ConfigTabs->$name->Text("$default_crawllimit");

    #
    # Add field for crawl depth
    #
    $current_pos = Add_Text_Field_And_Example_Text($main_window->ConfigTabs,
                          $tabid, "crawl_depth",
                          String_Value("Crawl Depth"),
                          String_Value("The maximum crawl depth"),
                          $current_pos, $site_label_width);

    #
    # Set default crawl limit
    #
    $name = "crawl_depth$site_config_tabid";
    $main_window->ConfigTabs->$name->Text("$default_crawl_depth");

    #
    # Add field for http proxy
    #
    $current_pos = Add_Text_Field_And_Example_Text($main_window->ConfigTabs,
                          $tabid, "httpproxy",
                          String_Value("Proxy"),
                          String_Value("Proxy address to use"),
                          $current_pos, $site_label_width);

    #
    # Add button to check an entire site.
    #
    $name = "Validator_GUI_DoSite$tabid";
    $main_window->ConfigTabs->AddButton(
          -name   => $name,
          -text   => String_Value("Check Site"),
          -width  => 110,
          -height => 20,
          -pos => [($w - 110) / 2, $current_pos],
          -tabstop => 1,
          -onClick => \&Validator_GUI_DoSite_Click
    );

    #
    # Return tab count
    #
    return($tab_count);
}

#***********************************************************************
#
# Name: Add_Site_Login_Logout_Fields
#
# Parameters: main_window - window handle
#             tab_count - current tab count in tab strip
#
# Description:
#
#   This function adds the site login/logout fields to the main window.
#
#***********************************************************************
sub Add_Site_Login_Logout_Fields {
    my ($main_window, $tab_count) = @_;

    my ($current_pos) = 30;
    my ($tabid, $name, $h, $w);

    #
    # Add title to the tab and increment the tab count
    #
    print "Add site login & logout fields to main window\n" if $debug;
    $main_window->ConfigTabs->InsertItem(
        -text   => String_Value("Login/Logout"),
    );
    $tab_count++;

    #
    # Set tabid
    #
    $tabid = sprintf("_%02d", $tab_count);
    $site_login_logout_config_tabid = $tabid;

    #
    # Get the height and width of the tab page.
    #
    $w = $main_window->ConfigTabs->Width - 20;
    $h = $main_window->ConfigTabs->Height - 20;

    #
    # Add label for login/logout fields
    #
    $current_pos += 15;
    $name = "Login_Label$tabid";
    $main_window->ConfigTabs->AddLabel(
        -name => $name,
        -text => String_Value("Login/Logout fields"),
        -pos => [25,$current_pos],
    );
    $current_pos += 25;

    #
    # Add text field for English Login page
    #
    $current_pos = Add_Text_Field_And_Example_Text($main_window->ConfigTabs,
                          $tabid, "loginpagee",
                          String_Value("English login page"),
                          String_Value("Example") . " 'login-eng.cfm'",
                          $current_pos, $site_label_width);

    #
    # Add text field for English logout page
    #
    $current_pos = Add_Text_Field_And_Example_Text($main_window->ConfigTabs,
                          $tabid, "logoutpagee",
                          String_Value("English logout page"),
                          String_Value("Example") . " 'logout-eng.cfm'",
                          $current_pos, $site_label_width);

    #
    # Add text field for French Login page
    #
    $current_pos = Add_Text_Field_And_Example_Text($main_window->ConfigTabs,
                          $tabid, "loginpagef",
                          String_Value("French login page"),
                          String_Value("Example") .
                            " 'login-fra.cfm' " .
                            String_Value("if blank use English"),
                          $current_pos, $site_label_width);

    #
    # Add text field for French logout page
    #
    $current_pos = Add_Text_Field_And_Example_Text($main_window->ConfigTabs,
                          $tabid, "logoutpagef",
                          String_Value("French logout page"),
                          String_Value("Example") .
                            " 'logout-fra.cfm' " .
                            String_Value("if blank use English"),
                          $current_pos, $site_label_width);

    #
    # Add text field for login form name
    #
    $current_pos = Add_Text_Field_And_Example_Text($main_window->ConfigTabs,
                          $tabid, "loginformname",
                          String_Value("Login form name"),
                          String_Value("Example") .
                            " 'LoginForm' " .
                            String_Value("first form"),
                          $current_pos, $site_label_width);

    #
    # Add text field for number of interstitial pages after login
    #
    $current_pos = Add_Text_Field_And_Example_Text($main_window->ConfigTabs,
                          $tabid, "logininterstitialcount",
                          String_Value("Login page count"),
                          String_Value("Login interstitial page count"),
                          $current_pos, $site_label_width);

    #
    # Add text field for number of interstitial pages after logout
    #
    $current_pos = Add_Text_Field_And_Example_Text($main_window->ConfigTabs,
                          $tabid, "logoutinterstitialcount",
                          String_Value("Logout page count"),
                          String_Value("Logout interstitial page count"),
                          $current_pos, $site_label_width);

    #
    # Return tab count
    #
    return($tab_count);
}

#***********************************************************************
#
# Name: Add_Report_Option_Selector
#
# Parameters: tab_strip - TabStrip handle
#             tabid - tab identifier
#             current_pos - current position in the window
#             x_pos - horizontal positioning
#             report_options - report options table
#
# Description:
#
#   This function adds additional report options to the main window.
#
#***********************************************************************
sub Add_Report_Option_Selector {
    my ($tab_strip, $tabid, $current_pos, $x_pos, $option_label,
        $option_list_addr) = @_;

    my ($num_options, $name, $config_option);

    #
    # Create combobox name and store it in a hash table
    # so we can associate the user defined label with the combobox name
    # when we return selected values.  Since the user defined label can have
    # white space in it, convert spaces into underscores
    #
    $name = "Combobox_" . $option_label . $tabid;
    $name =~ s/\s+/_/g;
    $name =~ s/\*/_/g;
    $option_combobox_map{$option_label} = $name;
    $num_options = @$option_list_addr;

    $tab_strip->AddCombobox(
        -name         => $name,
        -dropdownlist => 1,
        -pos          => [$x_pos, $current_pos],
        -height       => 20 * $num_options + 20,
        -width        => 200,
        -tabstop      => 1,
        -onChange     => \&Select_Custom_Testcase_Profile_Group,
    );
    $tab_strip->$name->Add(@$option_list_addr);
    $tab_strip->$name->SetCurSel(0);

    #
    # Save field name
    #
    if ( defined($report_options_config_options{$option_label}) ) {
        $config_option = $report_options_config_options{$option_label};
        $report_options_field_names{$config_option} = $name;
        print "Add configuration type $config_option fieldname $name to report_options_field_names\n" if $debug;
    }

    #
    # Add label
    #
    $name = "Label_" . $option_label . $tabid;
    $name =~ s/\s+/_/g;
    $name =~ s/\*/_/g;

    $tab_strip->AddLabel(
        -name => $name,
        -text => $option_label,
        -pos => [$x_pos + 205,$current_pos],
    );
    $current_pos += 50;

    #
    # Return current window position
    #
    return($current_pos);
}

#***********************************************************************
#
# Name: Select_Testcase_Profile_Group
#
# Parameters: self - reference to main dialog
#
# Description:
#
#   This function runs when a testcase profile group is selected.
#
#***********************************************************************
sub Select_Testcase_Profile_Group {
    my ($self) = @_;
    
    my ($name, $group_name, $value, $profiles, $selector);
    my ($valid_value, $custom_value);
    
    #
    # Get the testcase profile group name
    #
    $name = $option_combobox_map{$testcase_profile_groups_label};
    $group_name = $main_window->ConfigTabs->$name->Text();
    print "Select_Testcase_Profile_Group, name = $group_name\n" if $debug;
    
    #
    # Is the testcase profile group the "Custom" group ?
    # If so, we don't update the testcase profile values, we leave them
    # the way the user set them.
    #
    ($valid_value, $custom_value) = Validate_Option_Value($testcase_profile_groups_config_option, "Custom");
    if ( $valid_value && ($group_name eq $custom_value) ) {
        print "Don't set testcase profile values, custom group used\n" if $debug;
        return;
    }

    #
    # Set the testcase profile values for the individual checks
    # to the values for this profile group.
    #
    $profiles = $$testcase_profile_groups_values{$group_name};
    while ( ($name, $value) = each %$profiles ) {
        #
        # Get the selector name
        #
        $selector = $report_options_field_names{$name};

        #
        # Get the valid values for this testcase profile type
        #
        ($valid_value, $value) = Validate_Option_Value($name, $value);
        if ( $valid_value ) {
            print "Select testcase profile $name, selector $selector to $value\n" if $debug;
            $main_window->ConfigTabs->$selector->SelectString("$value");
        }

        #
        # Update the configuration tab
        #
        Win32::GUI::DoEvents();
    }
}

#***********************************************************************
#
# Name: Select_Custom_Testcase_Profile_Group
#
# Parameters: self - reference to main dialog
#
# Description:
#
#   This function runs when a testcase profile is selected. It sets the
# testcase profile group to the "Custom" value.
#
#***********************************************************************
sub Select_Custom_Testcase_Profile_Group {
    my ($self) = @_;

    my ($name, $valid_value, $value);

    #
    # Initialize group profile to custom
    #
    print "Select_Custom_Testcase_Profile_Group\n" if $debug;
    if ( defined($testcase_profile_groups_config_option) ) {
        $name = $report_options_field_names{$testcase_profile_groups_config_option};
        ($valid_value, $value) = Validate_Option_Value($testcase_profile_groups_config_option,
                                      "Custom");
        if ( $valid_value ) {
            print "Set configuration selector $name to $value\n" if $debug;
            $main_window->ConfigTabs->$name->SelectString("$value");

            #
            # Update the configuration tab
            #
            Win32::GUI::DoEvents();
        }
    }
}

#***********************************************************************
#
# Name: Add_Report_Option_Testcase_Profile_Group_Selector
#
# Parameters: tab_strip - TabStrip handle
#             tabid - tab identifier
#             current_pos - current position in the window
#             option_label - label
#             option_list_addr - pointer to a list of values
#
# Description:
#
#   This function adds the testcase profile group options to the main window.
#
#***********************************************************************
sub Add_Report_Option_Testcase_Profile_Group_Selector {
    my ($tab_strip, $tabid, $current_pos, $option_label,
        $option_list_addr) = @_;

    my ($num_options, $name, $config_option, %option_values, $key, $value);

    #
    # Add label for testcase profile groups
    #
    $name = "Label_" . $option_label . $tabid;
    $name =~ s/\s+/_/g;
    $name =~ s/\*/_/g;

    $tab_strip->AddLabel(
        -name => $name,
        -text => $option_label,
        -pos => [50,$current_pos],
    );
    $current_pos += 50;
    
    #
    # Create combobox name and store it in a hash table
    # so we can associate the user defined label with the combobox name
    # when we return selected values.  Since the user defined label can have
    # white space in it, convert spaces into underscores
    #
    print "Add_Report_Option_Testcase_Profile_Group_Selector\n" if $debug;
    $name = "Combobox_" . $option_label . $tabid;
    $name =~ s/\s+/_/g;
    $name =~ s/\*/_/g;
    $option_combobox_map{$option_label} = $name;
    
    #
    # Get number of options in the list
    #
    $num_options = scalar(@$option_list_addr);

    #
    # Add the combobox for testcase profile groups
    #
    $tab_strip->AddCombobox(
        -name         => $name,
        -dropdownlist => 1,
        -pos          => [50,$current_pos],
        -height       => 20 * $num_options + 20,
        -width        => 200,
        -tabstop      => 1,
        -onChange     => \&Select_Testcase_Profile_Group,
    );
    $tab_strip->$name->Add(@$option_list_addr);
    $tab_strip->$name->SetCurSel(0);

    #
    # Save field name
    #
    if ( defined($report_options_config_options{$option_label}) ) {
        $config_option = $report_options_config_options{$option_label};
        $report_options_field_names{$config_option} = $name;
        print "Add configuration type $config_option fieldname $name to report_options_field_names\n" if $debug;
    }

    #
    # Return current window position
    #
    return($current_pos);
}

#***********************************************************************
#
# Name: Load_Site_Config
#
# Parameters: self - reference to main dialog
#
# Description:
#
#   This function reads site configuration parameters from a file.
#
#***********************************************************************
sub Load_Site_Config {
    my ($self) = @_;

    my ($filename, $line, $field_name, $value, $name, $type, $url);
    my ($valid_value, $got_group_profile);

    #
    # Get name of file to read configuration from
    #
    $filename = Win32::GUI::GetOpenFileName(
                   -owner  => $main_window,
                   -title  => String_Value("Load Config"),
                   -directory => "$program_dir\\profiles",
                   -file   => "",
                   -filter => [
                       'Text file (*.txt)' => '*.txt',
                       'All files' => '*.*',
                    ],
                   -defaultextension => "txt",
                   );

    #
    # Was a file name specified ?
    #
    if ( defined($filename) ) {
        #
        # Empty the HTTP 401 credentials set
        #
        %url_401_user = ();
        %url_401_password = ();
        
        #
        # Initialize group profile to custom
        #
        Select_Custom_Testcase_Profile_Group();
        $got_group_profile = 0;

        #
        # Open the configuration file
        #
        if ( open(FILE, "$filename") ) {
            #
            # Read all lines from the file looking for the configuration
            # parameters
            #
            while ( $line = <FILE> ) {
                chomp($line);

                #
                # Ignore blank and comment lines
                #
                if ( $line =~ /^$/ ) {
                    next;
                }
                elsif ( $line =~ /^\s+#/ ) {
                    next;
                }

                #
                # Split line into 2 parts, configuration parameter, value
                #
                ($field_name, $value) = split(/\s+/, $line, 2);

                #
                # Do we have a value ?
                #
                if ( ! defined($value) ) {
                    next;
                }

                #
                # Check configuration field name
                #
                if ( defined($site_configuration_fields{$field_name}) ) {
                    #
                    # Load value into main dialog
                    #
                    $name = $site_configuration_fields{$field_name};
                    print "Set configuration item $name to $value\n" if $debug;
                    $main_window->ConfigTabs->$name->Text("$value"); 

                    #
                    # Update the configuration
                    #
                    Win32::GUI::DoEvents();
                }
                #
                # Do we have report option values ?
                #
                elsif ( defined($report_options_field_names{$field_name}) ) {
                    #
                    # Load value into main dialog configuration tab
                    #
                    $name = $report_options_field_names{$field_name};
                    ($valid_value, $value) = Validate_Option_Value($field_name, $value);
                    if ( $valid_value ) {
                        print "Set configuration selector $name to $value\n" if $debug;
                        $main_window->ConfigTabs->$name->SelectString("$value");

                        #
                        # Is this a group profile option ?
                        #
                        if ( $field_name eq $testcase_profile_groups_config_option ) {
                            $got_group_profile = 1;
                        }
                    }

                    #
                    # Update the configuration
                    #
                    Win32::GUI::DoEvents();
                }
                #
                # Have HTTP 401 credentials ?
                #
                elsif ( $field_name eq "HTTP_401" ) {
                    ($field_name, $url, $type, $value) = split(/\s+/, $line);

                    #
                    # Is this a username or password ?
                    #
                    if ( defined($value) && ($type eq "user") ) {
                        $url_401_user{$url} = $value;
                    }
                    elsif ( defined($value) && ($type eq "password") ) {
                        $url_401_password{$url} = $value;
                    }
                }
                #
                # Have login credentials ?
                #
                elsif ( $field_name eq "login" ) {
                    ($field_name, $type, $value) = split(/\s+/, $line, 3);
                    $login_credentials{$type} = $value;
                }
                #
                # Have generated source flag ?
                #
                elsif ( $field_name eq "enable_generated_markup" ) {
                    ($field_name, $value) = split(/\s+/, $line, 2);
                    $enable_generated_markup = $value;
                }
            }
            close(FILE);
            
            #
            # Did we find a group profile value ?
            #
            if ( $got_group_profile ) {
                #
                # Update all the other testcase profile options
                #
                Select_Testcase_Profile_Group();
            }
        }
        else {
            Error_Message_Popup("Failed to open site configuration file $filename");
        }
    }
}

#***********************************************************************
#
# Name: Save_Site_Config
#
# Parameters: self - reference to main dialog
#
# Description:
#
#   This function saves site configuration parameters into a file.
#
#***********************************************************************
sub Save_Site_Config {
    my ($self) = @_;

    my ($filename, $line, $field_name, $value, $tab_field_name);
    my ($url, $user, $password, $valid_value, $custom_value);
    my ($save_all_options);

    #
    # Get name of file to save configuration in
    #
    $filename = Win32::GUI::GetSaveFileName(
                   -owner  => $main_window,
                   -title  => String_Value("Save Config"),
                   -directory => "$program_dir\\profiles",
                   -file   => "",
                   -filter => [
                       'Text file (*.txt)' => '*.txt',
                       'All files' => '*.*',
                    ],
                   -defaultextension => "txt",
                   -createprompt => 1,
                   );

    #
    # Was a file name specified ?
    #
    if ( defined($filename) ) {
        #
        # Open the configuration file
        #
        if ( open(FILE, "> $filename") ) {
            #
            # Save each configuration value
            #
            foreach $field_name (sort keys %site_configuration_fields) {
                $tab_field_name = $site_configuration_fields{$field_name};
                $value = $main_window->ConfigTabs->$tab_field_name->Text();
                print FILE "$field_name $value\n";
            }
            
            #
            # Check for group profile option
            #
            $save_all_options = 1;
            if ( defined($report_options_field_names{$testcase_profile_groups_config_option}) ) {
                ($valid_value, $custom_value) = Validate_Option_Value($testcase_profile_groups_config_option, "Custom");
                $tab_field_name = $report_options_field_names{$testcase_profile_groups_config_option};
                $value = $main_window->ConfigTabs->$tab_field_name->Text();
                if ( $valid_value && ($value ne $custom_value) ) {
                    print FILE "$testcase_profile_groups_config_option $value\n";
                    $save_all_options = 0;
                }
            }

            #
            # Save all report options
            #
            if ( $save_all_options ) {
                foreach $field_name (sort keys %report_options_field_names) {
                    $tab_field_name = $report_options_field_names{$field_name};
                    $value = $main_window->ConfigTabs->$tab_field_name->Text();
                    print FILE "$field_name $value\n";
                }
            }

            #
            # Save generated source flag
            #
            if ( ! $enable_generated_markup ) {
                print FILE "enable_generated_markup $enable_generated_markup\n";
            }

            #
            # Save username/password settings
            #
            foreach $url (sort keys %url_401_user) {
                $user = $url_401_user{$url};
                $password = $url_401_password{$url};
                print FILE "HTTP_401 $url user $user\n";
                print FILE "HTTP_401 $url password $password\n";
            }
            close(FILE);
        }
        else {
            Error_Message_Popup("Failed to create site configuration file $filename");
        }
    }
}

#***********************************************************************
#
# Name: Validator_GUI_Main_Resize
#
# Parameters: none
#
# Description:
#
#   This function handles the resizing of the main window.
#
#***********************************************************************
sub Validator_GUI_Main_Resize {
    my ($h, $w);

    #
    # Get size of tab page.
    #
    $w = $main_window->ConfigTabs->Width;
    $h = $main_window->ConfigTabs->Height;

    #
    # Position tab strip and set its size.
    #
    $main_window->ConfigTabs->Move(10, 10);
    $main_window->ConfigTabs->Resize($w - 20, $h - 20);
}

#***********************************************************************
#
# Name: Main_Window_Tabstrip_Click
#
# Parameters: none
#
# Description:
#
#   This function handles a click in the main window's tabstrip.  It
# displays the items in the selected tab.
#
#***********************************************************************
sub Main_Window_Tabstrip_Click {

    my ($current_tab, $key, $ref, $tabid);

    #
    # Get the selected tab
    #
    $current_tab = $main_window->ConfigTabs->SelectedItem();

    #
    # Get all of the attributest of all the widgets in the config tab
    #
    foreach $key (keys %{$main_window->ConfigTabs}) {
       #
       # Skip these items - what remains should be just widgets.
       #
       next if (grep(/^${key}$/,qw(-handle -name -type)));

       #
       # Get the widget reference
       #
       $ref = $main_window->ConfigTabs->{$key};

       #
       # Check for key accel, for an unknow reason it cannot be included
       # in the above grep.
       #
       if ( $key eq "-accel" ) {
           next;
       }

       #
       # Strip off number from end of -name - use as tabid.
       # A better way would be to define something like "-tabid => .."
       # But this does not carry over after the widget is defined.
       #
       if ( defined($ref->{-name}) && $ref->{-name} ne "" ) {
           $tabid = substr($ref->{-name},-2);
           if ( ($tabid =~ /\d\d/) && ($current_tab == $tabid) ) {
              print "Main_Window_Tabstrip_Click, Show->" . $ref->{-name} . "\n" if $debug;
              $ref->Show();
           }
           else {
              print "Main_Window_Tabstrip_Click, Hide->" . $ref->{-name} . "\n" if $debug;
              $ref->Hide();
           }
       }
       else {
           print "Unknown element\n";
       }
    }
}

#***********************************************************************
#
# Name: Create_Main_Window
#
# Parameters: report_options - report options table
#
# Description:
#
#   This function creates the main dialog window.
#
#***********************************************************************
sub Create_Main_Window {
    my (%report_options) = @_;

    my ($current_pos, $group_start, $main_window);

    #
    # Setup dialog menu.
    #
    $main_window_menu = Win32::GUI::MakeMenu(
    "&" . String_Value("File") => "File",
    " > " . String_Value("Load Site Config") =>
            { 
                 -name => "LoadSiteConfig",
                 -onClick => \&Load_Site_Config
            },

    " > " . String_Value("Save Site Config") =>
            { 
                 -name => "SaveSiteConfig",
                 -onClick => \&Save_Site_Config 
            },

    " > " . String_Value("Exit") => 
            { 
                 -name => "Exit",
                 -onClick => \&Main_Exit 
            },

 "&" . String_Value("Options")=> "Options",
    " > " . String_Value("Show Browser")  => 
            {
                 -name => "ShowBrowser",
                 -onClick => sub { 
                                   if ( $show_browser_window ) {
                                       #
                                       # Turn off browser window
                                       #
                                       $show_browser_window = 0;
                                       $main_window_menu->{ShowBrowser}->Change(-text => String_Value("Show Browser"));
                                   }
                                   else {
                                       #
                                       # Turn on browser window
                                       #
                                       $show_browser_window = 1;
                                       $main_window_menu->{ShowBrowser}->Change(-text => String_Value("Hide Browser"));
                                   }
                                 }
            },

    " > " . String_Value("Report Fails and Passes")  =>
            { 
                 -name => "ReportFailsOnly",
                 -onClick => sub { 
                                   if ( $report_fails_only ) {
                                       #
                                       # Turn on reporting passes and fails
                                       #
                                       $report_fails_only = 0;
                                       $main_window_menu->{ReportFailsOnly}->Change(-text => String_Value("Report Fails Only"));
                                   }
                                   else {
                                       #
                                       # Turn off reporting passes and fails
                                       #
                                       $report_fails_only = 1;
                                       $main_window_menu->{ReportFailsOnly}->Change(-text => String_Value("Report Fails and Passes"));
                                   }
                                  }
            },
    " > " . String_Value("XML Output")  =>
            { 
                 -name => "XMLOutput", 
                 -onClick => sub { 
                                   $xml_output_mode = 1; 
                                   $main_window_menu->{TextOutput}->Enabled(1);
                                   $main_window_menu->{XMLOutput}->Enabled(0);
                                  }
            },

    " > " . String_Value("Text Output")  => 
            { 
                 -name => "TextOutput", 
                 -onClick => sub { 
                                   $xml_output_mode = 0;
                                   $main_window_menu->{TextOutput}->Enabled(0);
                                   $main_window_menu->{XMLOutput}->Enabled(1);
                                  }
            },

    " > " . String_Value("Enable content capture")  =>
            { 
                 -name => "SaveContentOn", 
                 -onClick => sub {
                                   if ( $save_content ) {
                                       #
                                       # Turn off content saving
                                       #
                                       $save_content = 0;
                                       $main_window_menu->{SaveContentOn}->Change(-text => String_Value("Enable content capture"));
                                   }
                                   else {
                                       #
                                       # Turn on content saving
                                       #
                                       $save_content = 1;
                                       $main_window_menu->{SaveContentOn}->Change(-text => String_Value("Disable content capture"));
                                   }
                                  }
            },

    " > " . String_Value("Disable PDF checking")  =>
            { 
                 -name => "ProcessPDF",
                 -onClick => sub { 
                                   if ( $process_pdf ) {
                                       #
                                       # Turn off PDF file processing
                                       #
                                       $process_pdf = 0;
                                       $main_window_menu->{ProcessPDF}->Change(-text => String_Value("Enable PDF checking"));
                                   }
                                   else {
                                       #
                                       # Turn on PDF file processing
                                       #
                                       $process_pdf = 1;
                                       $main_window_menu->{ProcessPDF}->Change(-text => String_Value("Disable PDF checking"));
                                   }
                                  }
            },

    " > " . String_Value("Disable generated markup")  =>
            {
                 -name => "UseGeneratedMarkup",
                 -onClick => sub {
                                   if ( $enable_generated_markup ) {
                                       #
                                       # Turn off the use of generated markup
                                       # for HTML web pages.
                                       #
                                       $enable_generated_markup = 0;
                                       $main_window_menu->{UseGeneratedMarkup}->Change(-text => String_Value("Enable generated markup"));
                                   }
                                   else {
                                       #
                                       # Turn on the use of generated markup
                                       # for HTML web pages.
                                       #
                                       $enable_generated_markup = 1;
                                       $main_window_menu->{UseGeneratedMarkup}->Change(-text => String_Value("Disable generated markup"));
                                   }
                                  }
            },

    #
    # Help menu
    # 
    "&" . String_Value("Help") => "Help",
    " > " . String_Value("Version") . $version => 
            {
              -name => "Help", -enabled => 1
            },
    );

    #
    # Create main window
    #
    print "Create main window\n" if $debug;
    $main_window = new Win32::GUI::Window(
	    -name => 'Validator_GUI_Main',
	    -text => String_Value("Main Window Title"),
          -menu => $main_window_menu,
          -width => 800,
          -height => 800,
          -dialogui => 1,
          -resizable => 0,
          -maximizebox => 0,
          -minimizebox => 0,
    );
    $current_pos = 10;

    #
    # Add a TabStrip to the window.
    #
    print "Create main window tabstrip\n" if $debug;
    $main_window->AddTabStrip (
        -name   => "ConfigTabs",
        -panel  => "Tab",
        -width  => 775,
        -height => 750,
        -onClick => \&Main_Window_Tabstrip_Click
    );
    $current_pos += 600;
    $main_window_tab_count = -1;

    #
    # Add site crawling fields to tab
    #
    $main_window_tab_count = Add_Site_Crawl_Fields($main_window, 
                                                   $main_window_tab_count);

    #
    # Add site login/logout fields to tab
    #
    $main_window_tab_count = Add_Site_Login_Logout_Fields($main_window,
                                                   $main_window_tab_count);

    #
    # Add tab for direct HTML input
    #
    $main_window_tab_count = Add_Direct_Input_Fields($main_window, 
                                                     $main_window_tab_count);

    #
    # Add tab for a list of URLs
    #
    $main_window_tab_count = Add_URL_List_Input_Fields($main_window,
                                                       $main_window_tab_count);

    #
    # Add tab for configuration options if we have any
    #
    if ( keys(%report_options) > 0 ) {
        $main_window_tab_count = Add_Config_Fields($main_window, 
                                                   $main_window_tab_count, 
                                                   %report_options);
    }

    #
    # Initialize program options
    #
    $show_browser_window = 0;
    $stop_on_errors = 0;
    $report_fails_only = 1;
    $save_content = 0;
    $process_pdf = 1;
    $enable_generated_markup = 1;

    #
    # Return window handle
    #
    return($main_window);
}

#***********************************************************************
#
# Name: Display_Content_In_Browser
#
# Parameters: url - page URL
#             content - content pointer
#
# Description:
#
#   This function instructs the browser window to present the
# content.  The content is modified to include a <base tag to
# resolve any relative links within the content (e.g. images).
# We do not simply navigate to the URL as this may be behind
# a login and the browser window has not authenticated with the site.
#
#***********************************************************************
sub Display_Content_In_Browser {
    my ( $url, $content) = @_;

    my ($html_file, @lines, $n, $file_url);

    #
    # Do we have an IE object ?
    #
    if ( defined($ie) ) {
        #
        # Get temporary file for content
        #
        $html_file = File::Temp->new(SUFFIX => ".html");
        binmode $html_file;
        print "Temporary file name = $html_file\n" if $debug;

        #
        # Split the content on the <head tag
        #
        @lines = split(/<head/i, $$content, 2);
        $n = @lines;
        if ( $n > 1 ) {
             #
             # Print content before <head then print <head
             #
             print $html_file $lines[0];
             print $html_file "<head";

             #
             # Insert <base after the first tag close
             #
             $lines[1] =~ s/>/>\n<base href="$url" \/>\n/;

             #
             # Print the rest of the content
             #
             print $html_file $lines[1];
        }
        else {
             #
             # No <head, just print the content
             #
             print $html_file $lines[0];
        }

        #
        # Close the file
        #
        close($html_file);

        #
        # Open the file in the browser window
        #
        $file_url = "file:///" . $html_file;
        print "Display $file_url in browser\n" if $debug;
        eval {$ie->get($file_url);};

        #
        # Remove the temporary file
        #
        unlink($html_file);
    }
    else {
        print "IE object not defined\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Validator_GUI_Display_Content
#
# Parameters: url - page URL
#             content - content pointer
#
# Description:
#
#   This function instructs the browser window to present the
# content.  The content is modified to include a <base tag to
# resolve any relative links within the content (e.g. images).
# We do not simply navigate to the URL as this may be behind
# a login and the browser window has not authenticated with the site.
#
#***********************************************************************
sub Validator_GUI_Display_Content {
    my ( $url, $content) = @_;

    #
    # Is the browser window being shown ?
    #
    if ( $show_browser_window ) {
        Display_Content_In_Browser($url, $content);
    }
}

#***********************************************************************
#
# Name: Validator_GUI_Continue_Terminate
#
# Parameters: none
#
# Description:
#
#   This function handles closing the continue dialog. It simply
# hides the window.
#
#***********************************************************************
sub Validator_GUI_Continue_Terminate {
        print "Validator_GUI_Continue_Terminate\n" if $debug;
        $continue_window->Hide();
        $continue_window_open = 0;
        return 0;
}

#***********************************************************************
#
# Name: Validator_GUI_Continue_Click
#
# Parameters: none
#
# Description:
#
#   This function handles a click on the Continue button in the continue
# dialog.
#
#***********************************************************************
sub Validator_GUI_Continue_Click {
    #
    # Hide the window
    #
    $continue_window->Hide();
    $continue_window_open = 0;
    return 0;
}

#***********************************************************************
#
# Name: Save_Content_To_File
#
# Parameters: url - page URL
#             content - page content
#             error_message - error message
#
# Description:
#
#   This function saves results text file.
#
#***********************************************************************
sub Save_Content_To_File {
    my ( $url, $content, $error_message) = @_;

    my ($filename);

    #
    # Get name of file to save content in
    #
    $filename = Win32::GUI::GetSaveFileName(
                   #-owner  => $browser_window,
                   -title  => String_Value("Save As"),
                   -directory => "$program_dir\\results",
                   -file   => "",
                   -filter => [
                       'HTML file (*.htm)' => '*.htm',
                       'All files' => '*.*',
                    ],
                   -defaultextension => "htm",
                   -createprompt => 1,
                   );
    Win32::GUI::DoEvents();

    #
    # Was a file name specified ?
    #
    if ( defined($filename) ) {
        #
        # Save content in file
        #
        if ( open(FILE, ">$filename") ) {
            #
            # Add URL as a comment
            #
            print(FILE "<!-- HTML Content for URL $url -->\n");
            print(FILE "<!-- Error messages:\n$error_message \n-->\n\n");
            print(FILE $content);
            close(FILE);
        }
        else {
            Error_Message_Popup(String_Value("Failed to save content") .
                                $filename);
        }
    }
}

#***********************************************************************
#
# Name: Validator_GUI_Save_Content_Click
#
# Parameters: url - page URL
#             content - page content
#
# Description:
#
#   This function saves the URL content in a text file.
#
#***********************************************************************
sub Validator_GUI_Save_Content_Click {
    #
    # Hide the window
    #
    $continue_window->Hide();
    $continue_window_open = 0;
    $continue_window_save_content = 1;
    return 0;
}

#***********************************************************************
#
# Name: Create_Continue_Dialog
#
# Parameters: none
#
# Description:
#
#   This function creates a dialog with a continue button.
#
#***********************************************************************
sub Create_Continue_Dialog {
    my ($current_pos);

    #
    # Create Continue window.
    #
    print "Create continue window\n" if $debug;
    $continue_window = Win32::GUI::DialogBox->new(
            -name => 'Validator_GUI_Continue',
            -text => String_Value("Continue"),
            -pos => [400, 400],
            -width => 400,
            -height => 100,
            -helpbutton => 0,
    );

    #
    # Add Continue text
    #
    $current_pos = 10;
    $continue_window->AddLabel(
        -text => String_Value("Press Continue"),
        -pos => [10,$current_pos],
    );
    $current_pos += 25;

    #
    # Add button for continue
    #
    $continue_window->AddButton(
            -name    => 'Validator_GUI_Continue',
            -text    => String_Value("Continue"),
            -ok      => 1,
            -pos => [10,$current_pos],
            -tabstop => 1,
            -onClick => \&Validator_GUI_Continue_Click,
    );

    #
    # Add button for Save Content
    #
    $continue_window->AddButton(
            -name    => 'Validator_GUI_Save_Content',
            -text    => String_Value("Save Content"),
            -ok      => 1,
            -pos => [100,$current_pos],
            -tabstop => 1,
            -onClick => \&Validator_GUI_Save_Content_Click,
    );

    #
    # Show the continue dialog
    #
    $continue_window->Show();
}

#***********************************************************************
#
# Name: Validator_GUI_Browser_Terminate
#
# Parameters: none
#
# Description:
#
#   This function handles closing the browser window. It simply
# hides the window.
#
#***********************************************************************
sub Validator_GUI_Browser_Terminate {

    #
    # Close the IE window
    #
    Close_Browser_Window();
    return 0;
}

#***********************************************************************
#
# Name: Create_Browser_Window
#
# Parameters: none
#
# Description:
#
#   This function creates a browser window to display web pages.
#
#***********************************************************************
sub Create_Browser_Window {

    #
    # Create a Mechanize object to handle interactions with IE
    #
    if ( $show_browser_window ) {
        #
        # Have to do 'require' here is avoid a bug with threads and the
        # Mechanize module.
        #
        require Win32::IE::Mechanize;
        print "Create Win32::IE::Mechanize object\n" if $debug;
        $ie = Win32::IE::Mechanize->new( visible => 1 );

        #
        # Turn off warnings
        #
        if ( defined($ie) ) {
            $ie->quiet(1);
        }
    }
}

#***********************************************************************
#
# Name: Validator_GUI_Setup
#
# Parameters: lang - the language of the display
#             single_url_callback - call back function
#             site_crawl_callback - call back function
#             url_list_callback - call back function
#             report_options - a table of report options
#
# Description:
#
#   This function creates a GUI for a validation tool.  It creates
# the main dialog and presents it to the end user.
#
#   The callback functions are called when one of the GUI validation
# buttons are selected. The callback can be used by clients to run
# the validation on either an entire site or pasted content.
#
# The content callback prototype is
#  callback($content, %report_options)
#    where content is the content to process
#          report_options - a hash table of report option values
#
# The site crawl callback prototype is
#  callback($site_dir_e, $site_dir_f, $site_entry_e, $site_entry_f,
#           $loginpagee, $logoutpagee, $loginpagef, $logoutpagef,
#           $report_fails_only, $save_content, %report_options)
#    where site_dir_e - English site domain & directory
#          site_dir_f - French site domain & directory
#          site_entry_e - English entry page
#          site_entry_f - French entry page
#          loginpagee - English login page
#          logoutpagee - English logout page
#          loginpagef - French login page
#          logoutpagef - French logout page
#          report_fails_only - report fails only
#          save_content - save web site content
#          report_options - a hash table of report option values
#
# The URL list callback prototype is
#  callback($url_list, $report_fails_only, %report_options)
#    where url_list is the list of urls to process
#          report_fails_only - report fails only
#          report_options - a hash table of report option values
#
# The login callback prototype is
#   callback(%field_values)
#     where %field_values is a hash table of values indexed by the
#       login form field names. 
#
#***********************************************************************
sub Validator_GUI_Setup {
    my ($lang, $content_callback_fn, $crawl_callback, 
        $url_list_callback_fn, %report_options) = @_;

    #
    # Do we hide the Perl command prompt window ?
    #
    if ( $debug) {
        Win32::GUI::Show($dos_window);
    }
    else {
        Win32::GUI::Hide($dos_window);
    }

    #
    # Do we want the French GUI ?
    #
    if ( $lang =~ /^fr/i ) {
        $string_table = \%string_table_fr;
        $site_label_width = $site_label_width_fr;
    }
    else {
        #
        # present the English GUI
        #
        $string_table = \%string_table_en;
        $site_label_width = $site_label_width_en;
    }

    #
    # Save callback function addresses
    #
    $content_callback = $content_callback_fn;
    $site_crawl_callback = $crawl_callback;
    $url_list_callback = $url_list_callback_fn;

    #
    # Create main window
    #
    $main_window = Create_Main_Window(%report_options);

    #
    # Create results window
    #
    $results_window = Create_Results_Window;
}

#***********************************************************************
#
# Name: Validator_GUI_Report_Option_Labels
#
# Parameters: options_labels - pointer to hash table of option labels
#             options_values - pointer to a hash table of option values
#
# Description:
#
#   This function copies the report options labels type
# table into a global variable.
#
#***********************************************************************
sub Validator_GUI_Report_Option_Labels {
    my ($options_labels, $options_values) = @_;

    #
    # Copy content to global variable
    #
    %report_options_labels = %$options_labels;
    %report_options_config_options = reverse %$options_labels;
    %report_options_values = %$options_values;
}

#***********************************************************************
#
# Name: Validator_GUI_Report_Option_Testcase_Groups
#
# Parameters: config_option_label - label for configuration/profile file option
#             label - label for option
#             names - pointer to a list of names
#             values - pointer to hash table of values
#
# Description:
#
#   This function copies the testcase profile group options information
# into global variables.
#
#***********************************************************************
sub Validator_GUI_Report_Option_Testcase_Groups {
    my ($config_option_label, $label, $names, $values) = @_;

    #
    # Copy information to global variables
    #
    print "Validator_GUI_Report_Option_Testcase_Groups\n" if $debug;
    $testcase_profile_groups_config_option = $config_option_label;
    $testcase_profile_groups_label = $label;
    $testcase_profile_groups_names = $names;
    $testcase_profile_groups_values = $values;
}

#***********************************************************************
#
# Name: Validator_GUI_Set_Results_Save_Callback
#
# Parameters: callback - address of a callback function
#
# Description:
#
#   This function sets the Results Save callback.
#
# The content callback prototype is
#  callback($filename)
#    where filename is the directory and file name prefix
#            to save results.
#
#***********************************************************************
sub Validator_GUI_Set_Results_Save_Callback {
    my ($callback_fn) = @_;

    #
    # Save callback function pointer
    #
    $results_save_callback = $callback_fn;
}

#***********************************************************************
#
# Name: Validator_GUI_Start
#
# Parameters: none
#
# Description:
#
#   This function imports any required packages that cannot
# be handled via use statements.
#
#***********************************************************************
sub Validator_GUI_Start {
    my ($rc);

    #
    # Show main dialog window then wait until are ready to display results
    #
    print "Show main window and enter Win32::GUI::Dialog\n" if $debug;
    Main_Window_Tabstrip_Click();
    
    #
    # Set testcase profiles based on default group profile value.
    #
    if ( defined($testcase_profile_groups_label) ) {
        Select_Testcase_Profile_Group();
    }

    #
    # Show the main window and start the UI
    #
    $main_window->Show();
    $rc = Win32::GUI::Dialog();
    print "Exit Win32::GUI::Dialog, rc = $rc\n" if $debug;
}

#***********************************************************************
#
# Name: Run_Open_Data_Callback
#
# Parameters: address of hash table of dataset URLs
#             report_options - a hash table of report option values
#
# Description:
#
#   This function calls the Open Data callback function
#
#***********************************************************************
sub Run_Open_Data_Callback {
    my ($dataset_urls, %report_options) = @_;
    
    my ($eval_output);

    #
    # Add a signal handler to exit a thread.
    #
    $SIG{'KILL'} = sub { 
                           #
                           # Close browser window if we had it open
                           #
                           if ( defined($ie) ) {
                               print "Close IE\n" if $debug;
                               $ie->close();
                               undef $ie;
                           }

                           #
                           # Exit the thread
                           #
                           threads->exit();
                      };

    #
    # Call the Open Data callback function
    #
    print "Child: Call open_data_callback\n" if $debug;
    $eval_output = eval { &$open_data_callback($dataset_urls, %report_options); 1 };
    if ( ! $eval_output ) {
        print STDERR "open_data_callback fail, eval_output = \"$@\"\n";
        print "open_data_callback fail, eval_output = \"$@\"\n" if $debug;

        #
        # Report run time error to parent thread
        #
        if ( defined($runtime_error_callback) ) {
            &$runtime_error_callback($@);
       }
    }
    print "Child: Return from open_data_callback\n" if $debug;

    #
    # Close results CSV file
    #
    if ( defined($csv_results_fh) ) {
        close($csv_results_fh);
    }
}

#***********************************************************************
#
# Name: GUI_Do_Open_Data_Click
#
# Parameters: none
#
# Description:
#
#   This function handles the GUI_Do_Open_Data button from the main window.
#
#***********************************************************************
sub GUI_Do_Open_Data_Click {

    my (%dataset_urls, %report_options, $value, $tab_field_name);
    my ($tabid);

    #
    # Get open data description URL
    #
    print "GUI_Do_Open_Data_Click\n" if $debug;
    $tab_field_name = "description$open_data_tabid";
    $value = $main_window->ConfigTabs->$tab_field_name->Text();
    if ( defined($value) && ( ! ($value =~ /^\s*$/)) ) {
        $dataset_urls{"DESCRIPTION"} = $value;
    }

    #
    # Get data dictionary URL list
    #
    $tab_field_name = "data_dictionaries$open_data_tabid";
    $value = $main_window->ConfigTabs->$tab_field_name->Text();
    $dataset_urls{"DICTIONARY"} = $value;

    #
    # Get data URL list
    #
    $tab_field_name = "data_files$open_data_tabid";
    $value = $main_window->ConfigTabs->$tab_field_name->Text();
    $dataset_urls{"DATA"} = $value;

#    #
#    # Get resource URL list
#    #
#    $tab_field_name = "resource_files$open_data_tabid";
#    $value = $main_window->ConfigTabs->$tab_field_name->Text();
#    $dataset_urls{"RESOURCE"} = $value;

    #
    # Get API URL list
    #
    $tab_field_name = "api$open_data_tabid";
    $value = $main_window->ConfigTabs->$tab_field_name->Text();
    $dataset_urls{"API"} = $value;

    #
    # Show the results window and clear any text.
    #
    foreach $tabid (values %results_window_tab_labels) {
        $tab_field_name = "results$tabid";
        $results_window->ResultTabs->$tab_field_name->Text("");
    }

    #
    # Get any report options
    #
    %report_options = Get_Report_Options;

    #
    # Copy menu options into report options hash table
    #
    $report_options{"report_fails_only"} = $report_fails_only;
    $report_options{"save_content"} = $save_content;

    #
    # Show the results window.
    #
    Results_Window_Tabstrip_Click();
    $results_window->Show();
    $results_window->BringWindowToTop();
    Win32::GUI::DoEvents();

    #
    # Call the Open Data callback function
    #
    if ( defined($open_data_callback) ) {
        #
        # Create a new thread to handle the open data.  This leaves
        # the main thread free to respond to GUI events.
        #
        print "Child: Call open_data_callback\n" if $debug;
        $child_thread = threads->create(\&Run_Open_Data_Callback,\%dataset_urls,
                                        %report_options);

        #
        # Detach the thread so it can run freely
        #
        print "Detach url list thread\n" if $debug;
        $child_thread->detach();
    }
    else {
        print "Error: Missing url list callback function in GUI_Do_Open_Data_Click\n";
        exit(1);
    }

    return 0;
}

#***********************************************************************
#
# Name: Load_Open_Data_Config
#
# Parameters: self - reference to main dialog
#
# Description:
#
#   This function reads open data configuration parameters from a file.
#
#***********************************************************************
sub Load_Open_Data_Config {
    my ($self) = @_;

    my ($filename, $line, $field_name, $value, $name, $type, $url);
    my ($data_list, $dictionary_list, $resource_list, $api_list);
    my ($description_url, $valid_value, $got_group_profile);

    #
    # Get name of file to read configuration from
    #
    $filename = Win32::GUI::GetOpenFileName(
                   -owner  => $main_window,
                   -title  => String_Value("Load Config"),
                   -directory => "$program_dir\\profiles",
                   -file   => "",
                   -filter => [
                       'Text file (*.txt)' => '*.txt',
                       'All files' => '*.*',
                    ],
                   -defaultextension => "txt",
                   );

    #
    # Was a file name specified ?
    #
    if ( defined($filename) ) {
        #
        # Open the configuration file
        #
        if ( open(FILE, "$filename") ) {
            #
            # Initialise lists of URLs
            #
            $data_list = "";
            $dictionary_list = "";
            $resource_list = "";
            $api_list = "";
            $description_url = "";
            $got_group_profile = 0;

            #
            # Read all lines from the file looking for the configuration
            # parameters
            #
            while ( $line = <FILE> ) {
                chomp($line);

                #
                # Ignore blank and comment lines
                #
                if ( $line =~ /^$/ ) {
                    next;
                }
                elsif ( $line =~ /^\s+#/ ) {
                    next;
                }

                #
                # Split line into 2 parts, configuration parameter, value
                #
                ($field_name, $value) = split(/\s+/, $line, 2);

                #
                # Do we have a value ?
                #
                if ( ! defined($value) ) {
                    next;
                }

                #
                # Check configuration field name
                #
                if ( defined($site_configuration_fields{$field_name}) ) {
                    #
                    # Load value into main dialog
                    #
                    $name = $site_configuration_fields{$field_name};
                    print "Set configuration item $name to $value\n" if $debug;
                    $main_window->ConfigTabs->$name->Text("$value"); 

                    #
                    # Update the configuration
                    #
                    Win32::GUI::DoEvents();
                }
                elsif ( defined($report_options_field_names{$field_name}) ) {
                    #
                    # Load value into main dialog
                    #
                    $name = $report_options_field_names{$field_name};
                    ($valid_value, $value) = Validate_Option_Value($field_name, $value);
                    if ( $valid_value ) {
                        print "Set configuration selector $name to $value\n" if $debug;
                        $main_window->ConfigTabs->$name->SelectString("$value");
                        
                        #
                        # Is this a group profile option ?
                        #
                        if ( defined($testcase_profile_groups_config_option) &&
                             ($field_name eq $testcase_profile_groups_config_option) ) {
                            $got_group_profile = 1;
                        }
                    }

                    #
                    # Update the configuration
                    #
                    Win32::GUI::DoEvents();
                }
                #
                # Data file URL ?
                #
                elsif ( $field_name =~ /^DATA$/i ) {
                    $data_list .=  "$value\r\n";
                }
                #
                # Description URL ?
                #
                elsif ( $field_name =~ /^DESCRIPTION$/i ) {
                    $description_url =  "$value";
                }
                #
                # Dictionary file URL ?
                #
                elsif ( $field_name =~ /^DICTIONARY$/i ) {
                    $dictionary_list .=  "$value\r\n";
                }
                #
                # Resource file URL ?
                #
                elsif ( $field_name =~ /^RESOURCE$/i ) {
                    $resource_list .=  "$value\r\n";
                }
                #
                # API URL ?
                #
                elsif ( $field_name =~ /^API$/i ) {
                    $api_list .=  "$value\r\n";
                }
            }
            close(FILE);
            
            #
            # Did we find a group profile value ?
            #
            if ( $got_group_profile ) {
                #
                # Update all the other testcase profile options
                #
                Select_Testcase_Profile_Group();
            }

            #
            # Set URL lists in main window
            #
            $name = "description$open_data_tabid";
            $main_window->ConfigTabs->$name->Text("$description_url");
            $name = "data_dictionaries$open_data_tabid";
            $main_window->ConfigTabs->$name->Text("$dictionary_list");
            $name = "data_files$open_data_tabid";
            $main_window->ConfigTabs->$name->Text("$data_list");
#            $name = "resource_files$open_data_tabid";
#            $main_window->ConfigTabs->$name->Text("$resource_list");
            $name = "api$open_data_tabid";
            $main_window->ConfigTabs->$name->Text("$api_list");

            #
            # Update the results page
            #
            Win32::GUI::DoEvents();

        }
        else {
            Error_Message_Popup("Failed to open site configuration file $filename");
        }
    }
}

#***********************************************************************
#
# Name: Save_Open_Data_Config
#
# Parameters: self - reference to main dialog
#
# Description:
#
#   This function saves open data configuration parameters into a file.
#
#***********************************************************************
sub Save_Open_Data_Config {
    my ($self) = @_;

    my ($filename, $line, $field_name, $value, $tab_field_name);
    my ($url, $user, $password);

    #
    # Get name of file to save configuration in
    #
    $filename = Win32::GUI::GetSaveFileName(
                   -owner  => $main_window,
                   -title  => String_Value("Save Config"),
                   -directory => "$program_dir\\profiles",
                   -file   => "",
                   -filter => [
                       'Text file (*.txt)' => '*.txt',
                       'All files' => '*.*',
                    ],
                   -defaultextension => "txt",
                   -createprompt => 1,
                   );

    #
    # Was a file name specified ?
    #
    if ( defined($filename) ) {
        #
        # Open the configuration file
        #
        if ( open(FILE, "> $filename") ) {
            #
            # Save each configuration value
            #
            foreach $field_name (sort keys %report_options_field_names) {
                $tab_field_name = $report_options_field_names{$field_name};
                $value = $main_window->ConfigTabs->$tab_field_name->Text();
                print FILE "$field_name $value\n";
            }

            #
            # Get description URL
            #
            $tab_field_name = "description$open_data_tabid";
            $value = $main_window->ConfigTabs->$tab_field_name->Text();
            if ( defined($value) && (! ($value =~ /^\s*$/)) ) {
                print FILE "DESCRIPTION $value\n";
            }

            #
            # Get data dictionary URL list
            #
            $tab_field_name = "data_dictionaries$open_data_tabid";
            $value = $main_window->ConfigTabs->$tab_field_name->Text();
            foreach (split(/\n/, $value)) {
                print FILE "DICTIONARY $_\n";
            }

            #
            # Get data URL list
            #
            $tab_field_name = "data_files$open_data_tabid";
            $value = $main_window->ConfigTabs->$tab_field_name->Text();
            foreach (split(/\n/, $value)) {
                print FILE "DATA $_\n";
            }

#            #
#            # Get resource URL list
#            #
#            $tab_field_name = "resource_files$open_data_tabid";
#            $value = $main_window->ConfigTabs->$tab_field_name->Text();
#            foreach (split(/\n/, $value)) {
#                print FILE "RESOURCE $_\n";
#            }

            #
            # Get API URL list
            #
            $tab_field_name = "api$open_data_tabid";
            $value = $main_window->ConfigTabs->$tab_field_name->Text();
            foreach (split(/\n/, $value)) {
                print FILE "API $_\n";
            }

            close(FILE);
        }
        else {
            Error_Message_Popup("Failed to create site configuration file $filename");
        }
    }
}

#***********************************************************************
#
# Name: Add_Open_Data_Fields
#
# Parameters: main_window - window handle
#             tab_count - count of number of tabs in tab strip
#
# Description:
#
#   This function adds a tab for Open Data fields, to the main window.
#
#***********************************************************************
sub Add_Open_Data_Fields {
    my ($main_window, $tab_count) = @_;

    my ($current_pos) = 40;
    my ($tabid, $name, $h, $w, $dictionary_field_name);
    my ($datafile_field_name, $resource_field_name, $api_field_name);
    my ($description_field_name);

    #
    # Add title to the tab and increment tab count
    #
    $main_window->ConfigTabs->InsertItem(
        -text   => String_Value("Open Data"),
    );
    $tab_count++;

    #
    # Set tab identifier
    #
    $tabid = sprintf("_%02d", $tab_count);
    $open_data_tabid = $tabid;

    #
    # Get the height and width of the tab page.
    #
    $w = $main_window->ConfigTabs->Width - 20;
    $h = ($main_window->ConfigTabs->Height - 100) / 5;

    #
    # Add label text
    #
    $main_window->ConfigTabs->AddLabel(
        -name => "Label_Description" . $tabid,
        -text => String_Value("Description URL"),
        -pos => [20,$current_pos],
    );
    $current_pos += 15;

    #
    # Add scrolling text field for data dictionary URL list
    #
    $description_field_name = "description$tabid";
    $main_window->ConfigTabs->AddTextfield(
        -name => $description_field_name,
        -pos => [5,$current_pos],
        -size => [$w - 40,20],
    );
    $current_pos += 25;

    #
    # Add label text
    #
    $main_window->ConfigTabs->AddLabel(
        -name => "Label_Dictionary" . $tabid,
        -text => String_Value("Dictionary Files"),
        -pos => [20,$current_pos],
    );
    $current_pos += 15;

    #
    # Add text field for data dictionary URL list
    #
    $dictionary_field_name = "data_dictionaries$tabid";
    $main_window->ConfigTabs->AddTextfield(
        -name => $dictionary_field_name,
        -pos => [5,$current_pos],
        -size => [$w - 40,$h],
        -multiline => 1,
        -hscroll   => 1,
        -vscroll   => 1,
        -autohscroll => 1,
        -autovscroll => 1,
        -keepselection => 1,
        -wantreturn => 1,
    );
    $current_pos += $h + 15;

    #
    # Set maximum size for text area
    #
    $main_window->ConfigTabs->$dictionary_field_name->SetLimitText(10000);

    #
    # Add label text
    #
    $main_window->ConfigTabs->AddLabel(
        -name => "Label_Data" . $tabid,
        -text => String_Value("Data Files"),
        -pos => [20,$current_pos],
    );
    $current_pos += 15;
    
    #
    # Add scrolling text field for data file URL list
    #
    $datafile_field_name = "data_files$tabid";
    $main_window->ConfigTabs->AddTextfield(
        -name => $datafile_field_name,
        -pos => [5,$current_pos],
        -size => [$w - 40,$h],
        -multiline => 1,
        -hscroll   => 1,
        -vscroll   => 1,
        -autohscroll => 1,
        -autovscroll => 1,
        -keepselection => 1,
        -wantreturn => 1,
    );
    $current_pos += $h + 15;

    #
    # Set maximum size for text area
    #
    $main_window->ConfigTabs->$datafile_field_name->SetLimitText(10000);

#    #
#    # Add label text
#    #
#    $main_window->ConfigTabs->AddLabel(
#        -name => "Label_Resource" . $tabid,
#        -text => String_Value("Resource Files"),
#        -pos => [20,$current_pos],
#    );
#    $current_pos += 15;
    
#    #
#    # Add scrolling text field for resource file URL list
#    #
#    $resource_field_name = "resource_files$tabid";
#    $main_window->ConfigTabs->AddTextfield(
#        -name => $resource_field_name,
#        -pos => [5,$current_pos],
#        -size => [$w - 40,$h],
#        -multiline => 1,
#        -hscroll   => 1,
#        -vscroll   => 1,
#        -autohscroll => 1,
#        -autovscroll => 1,
#        -keepselection => 1,
#        -wantreturn => 1,
#    );
#    $current_pos += $h + 15;
#
#    #
#    # Set maximum size for text area
#    #
#    $main_window->ConfigTabs->$resource_field_name->SetLimitText(10000);

    #
    # Add label text
    #
    $main_window->ConfigTabs->AddLabel(
        -name => "Label_API" . $tabid,
        -text => String_Value("API URLs"),
        -pos => [20,$current_pos],
    );
    $current_pos += 15;

    #
    # Add scrolling text field for API URL list
    #
    $api_field_name = "api$tabid";
    $main_window->ConfigTabs->AddTextfield(
        -name => $api_field_name,
        -pos => [5,$current_pos],
        -size => [$w - 40,$h],
        -multiline => 1,
        -hscroll   => 1,
        -vscroll   => 1,
        -autohscroll => 1,
        -autovscroll => 1,
        -keepselection => 1,
        -wantreturn => 1,
    );
    $current_pos += $h + 15;

    #
    # Set maximum size for text area
    #
    $main_window->ConfigTabs->$api_field_name->SetLimitText(10000);

    #
    # Add button to reset fields
    #
    $name = "GUI_Reset_Open_Data$tabid";
    $main_window->ConfigTabs->AddButton(
          -name   => $name,
          -text   => String_Value("Reset"),
          -width  => 40,
          -height => 20,
          -pos => [20, $current_pos],
          -tabstop => 1,
          -onClick => sub {
                            $main_window->ConfigTabs->$description_field_name->Text("");
                            $main_window->ConfigTabs->$dictionary_field_name->Text("");
                            $main_window->ConfigTabs->$datafile_field_name->Text("");
#                            $main_window->ConfigTabs->$resource_field_name->Text("");
                            $main_window->ConfigTabs->$api_field_name->Text("");
                          }
    );

    #
    # Add button to check open data
    #
    $name = "GUI_Do_Open_Data$tabid";
    $main_window->ConfigTabs->AddButton(
	    -name   => $name,
	    -text   => String_Value("Check"),
	    -width  => 110,
	    -height => 20,
          -pos => [($w - 150), $current_pos],
          -tabstop => 1,
          -onClick => \&GUI_Do_Open_Data_Click
    );

    #
    # Return tab count
    #
    return($tab_count);
}

#***********************************************************************
#
# Name: Create_Open_Data_Main_Window
#
# Parameters: report_options - report options table
#
# Description:
#
#   This function creates the main dialog window.
#
#***********************************************************************
sub Create_Open_Data_Main_Window {
    my (%report_options) = @_;

    my ($current_pos, $group_start, $main_window);

    #
    # Setup dialog menu.
    #
    $main_window_menu = Win32::GUI::MakeMenu(
    "&" . String_Value("File") => "File",
    " > " . String_Value("Load Open Data Config") =>
            { 
                 -name => "LoadOpenDataConfig",
                 -onClick => \&Load_Open_Data_Config
            },

    " > " . String_Value("Save Open Data Config") =>
            { 
                 -name => "SaveOpenDataConfig",
                 -onClick => \&Save_Open_Data_Config 
            },

    " > " . String_Value("Exit") => 
            { 
                 -name => "Exit",
                 -onClick => \&Main_Exit 
            },

 "&" . String_Value("Options")=> "Options",
    " > " . String_Value("Report Fails Only")  =>
            { 
                 -name => "ReportFailsOnly", 
                 -onClick => sub { 
                                   $report_fails_only = 1; 
                                   $main_window_menu->{ReportFailsAndPasses}->Enabled(1);
                                   $main_window_menu->{ReportFailsOnly}->Enabled(0);
                                  }
            },

    " > " . String_Value("Report Fails and Passes")  => 
            { 
                 -name => "ReportFailsAndPasses", 
                 -onClick => sub { 
                                   $report_fails_only = 0;
                                   $main_window_menu->{ReportFailsAndPasses}->Enabled(0);
                                   $main_window_menu->{ReportFailsOnly}->Enabled(1);
                                  }
            },
    " > " . String_Value("XML Output")  =>
            { 
                 -name => "XMLOutput", 
                 -onClick => sub { 
                                   $xml_output_mode = 1; 
                                   $main_window_menu->{TextOutput}->Enabled(1);
                                   $main_window_menu->{XMLOutput}->Enabled(0);
                                  }
            },

    " > " . String_Value("Text Output")  => 
            { 
                 -name => "TextOutput", 
                 -onClick => sub { 
                                   $xml_output_mode = 0;
                                   $main_window_menu->{TextOutput}->Enabled(0);
                                   $main_window_menu->{XMLOutput}->Enabled(1);
                                  }
            },

    #
    # Help menu
    # 
    "&" . String_Value("Help") => "Help",
    " > " . String_Value("Version") . $version => 
            {
              -name => "Help", -enabled => 1
            },
      );

    #
    # Set default enabled/disabled state for menu options
    #
    $main_window_menu->{ReportFailsOnly}->Enabled(0);
    $main_window_menu->{TextOutput}->Enabled(0);
    $main_window_menu->{XMLOutput}->Enabled(1);

    #
    # Create main window
    #
    print "Create main window\n" if $debug;
    $main_window = new Win32::GUI::Window(
	    -name => 'Validator_GUI_Main',
	    -text => String_Value("Main Window Title"),
          -menu => $main_window_menu,
          -width => 800,
          -height => 700,
          -dialogui => 1,
          -resizable => 0,
          -maximizebox => 0,
          -minimizebox => 0,
    );
    $current_pos = 10;

    #
    # Add a TabStrip to the window.
    #
    print "Create main window tabstrip\n" if $debug;
    $main_window->AddTabStrip (
        -name   => "ConfigTabs",
        -panel  => "Tab",
        -width  => 775,
        -height => 650,
        -onClick => \&Main_Window_Tabstrip_Click
    );
    $current_pos += 600;
    $main_window_tab_count = -1;

    #
    # Add tab for direct open data URLs
    #
    $main_window_tab_count = Add_Open_Data_Fields($main_window,
                                                  $main_window_tab_count);

    #
    # Add tab for configuration options if we have any
    #
    if ( keys(%report_options) > 0 ) {
        $main_window_tab_count = Add_Config_Fields($main_window, 
                                                   $main_window_tab_count, 
                                                   %report_options);
    }

    #
    # Initialize program options
    #
    $report_fails_only = 1;

    #
    # Return window handle
    #
    return($main_window);
}

#***********************************************************************
#
# Name: Validator_GUI_Open_Data_Setup
#
# Parameters: lang - the language of the display
#             open_data_callback_fn - call back function
#             report_options - a table of report options
#
# Description:
#
#   This function creates a GUI for the open data mode of the WPSS 
# validation tool.  It creates the main dialog and presents it to the user.
#
#   The callback functions are called when one of the GUI validation
# buttons are selected. The callback can be used by clients to run
# the validation on either an entire site or pasted content.
#
# The open data callback prototype is
#  callback($url_list, %report_options)
#    where url_list is the list of urls to process
#          report_options - a hash table of report option values
#
#***********************************************************************
sub Validator_GUI_Open_Data_Setup {
    my ($lang, $open_data_callback_fn, %report_options) = @_;

    #
    # Do we hide the Perl command prompt window ?
    #
    if ( $debug) {
        Win32::GUI::Show($dos_window);
    }
    else {
        Win32::GUI::Hide($dos_window);
    }

    #
    # Do we want the French GUI ?
    #
    if ( $lang =~ /^fr/i ) {
        $string_table = \%string_table_fr;
        $site_label_width = $site_label_width_fr;
    }
    else {
        #
        # present the English GUI
        #
        $string_table = \%string_table_en;
        $site_label_width = $site_label_width_en;
    }

    #
    # Save callback function addresses
    #
    $open_data_callback = $open_data_callback_fn;

    #
    # Create main window
    #
    $main_window = Create_Open_Data_Main_Window(%report_options);

    #
    # Create results window
    #
    $results_window = Create_Results_Window;
}

#***********************************************************************
#
# Name: Validator_GUI_Runtime_Error_Callback
#
# Parameters: callback - address of a function
#
# Description:
#
#   This function sets a callback function to be called in the event 
# there is a runtime error with the tool.
#
# The callback prototype is
#  callback($message)
#    where message is the runtime error message
#
#***********************************************************************
sub Validator_GUI_Runtime_Error_Callback {
    my ($callback) = @_;

    #
    # Save callback function addresses
    #
    $runtime_error_callback = $callback;
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
# Get handle for DOS window then hide it.
#
$dos_window = Win32::GUI::GetPerlWindow();
Win32::GUI::Hide($dos_window);

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
# Redirect STDERR and STDOUT to a file so it isn't lost when 
# the command window closes
#
unlink("$program_dir/stderr.txt");
unlink("$program_dir/stdout.txt");
if ( open( STDERR, ">$program_dir/stderr.txt") ) {
    open( STDOUT, ">$program_dir/stdout.txt");
}
else {
    #
    # Could not create files in program directory, try the temp directory.
    #
    if ( defined($ENV{"TMP"}) ) {
        $tmp = $ENV{"TMP"};
    }
    else {
        $tmp = "/tmp";
    }

    #
    # Save stdout & stderr files in /tmp
    #
    unlink("$tmp/stderr.txt");
    unlink("$tmp/stdout.txt");
    open( STDERR, ">$tmp/stderr.txt");
    open( STDOUT, ">$tmp/stdout.txt");
}

#
# Handle STDERR & STDOUT output
# Allow UTF-8 output for STDERR & STDOUT
#
binmode STDERR, ":utf8";
binmode STDOUT, ":utf8";

#
# Read version file to get program version
#
if ( "$program_dir/version.txt" ) {
    open(VERSION, "$program_dir/version.txt");
    $version = <VERSION>;
    chomp($version);
    close(VERSION);
}

#
# Return true to indicate we loaded successfully
#
return 1;

