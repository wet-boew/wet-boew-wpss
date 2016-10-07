#***********************************************************************
#
# Name: validator_gui.pm
#
# $Revision: 7537 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Validator_CLI/Tools/validator_gui.pm $
# $Date: 2016-03-02 06:47:50 -0500 (Wed, 02 Mar 2016) $
#
# Description:
#
#   This file contains routines that implement a command line interface
# (CLI) for the validator tools. The interface functions are defined
# in the GUI version of this package.  The functions that have no
# value in a CLI mode exist simply to conform to the interface specification.
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

use File::Temp();
use File::Basename;
use Text::CSV;
use Term::ReadKey;

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
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);
my ($content_callback, $site_crawl_callback, $stop_on_errors);
my ($url_list_callback, $version, %default_report_options);
my (%report_options_labels, $results_file_name, $open_data_callback);
my (%results_file_suffixes, $first_results_tab, $runtime_error_callback);
my (%login_credentials, $results_save_callback);
my (%url_401_user, %url_401_password, $enable_generated_markup);
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

my ($debug) = 0;
my ($xml_output_mode) = 0;

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
    "report_fails_only", "",
    "report_passes_only", "",
   );

my ($language) = "eng";
my ($default_crawllimit) = 100;
my ($default_crawl_depth) = 0;

#
# String table for UI strings.
#
my %string_table_en = (
    "Average faults per page",  "Average faults per page: ",
    "Column",                   "Column: ",
    "Compliance score",         "Compliance score: ",
    "Firewall authorization required",	  "Firewall authorization required",
    "Line",                     "Line: ",
    "Malformed URL",            "Malformed URL",
    "number of faults",         "number of faults: ",
    "Number of faults",         "Number of faults: ",
    "Overall compliance score", "Overall compliance score: ",
    "Page",                     "Page: ",
    "referrer",                 "referrer",
    "Source line",              "Source line: ",
    "Testcase",                 "Testcase: ",
    "Text Output",              "Text Output",
    "Total fault count",        "Total fault count: ",
    "Version",                  "Version ",
    "WPSS Validation Tool Results", "WPSS Validation Tool Results",
    "XML Output",               "XML Output",
    "2 spaces",                 "  ",
    "4 spaces",                 "    ",
);

my %string_table_fr = (
    "Average faults per page",  "Nombre moyen des pannes par page: ",
    "Column",                   "Colonne : ",
    "Compliance score",         "Score de conformité: ",
    "Firewall authorization required",	  "Autorisation de pare-feu obligatoire",
    "Line",                     "la ligne : ",
    "Malformed URL",            "URL incorrecte",
    "number of faults",         "nombre des pannes: ",
    "Number of faults",         "Nombre des pannes: ",
    "Overall compliance score", "Score de conformité totale: ",
    "Page",                     "Page : ",
    "referrer",                 "recommandataire",
    "Source line",              "Ligne de la source",
    "Testcase",                 "Cas de test : ",
    "Text Output",              "format de sortie du texte",
    "Total fault count",        "Nombre total des pannes: ",
    "Version",                  "Version ",
    "WPSS Validation Tool Results", "Résultats du validateur SPNW",
    "XML Output",               "format de sortie XML",
    "2 spaces",                 "  ",
    "4 spaces",                 "    ",
);

my ($string_table);

my (@package_list) = ("tqa_result_object", "validator_xml");

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

    #
    # Redirect STDERR and STDOUT to a file so it isn't lost when
    # the command window closes
    #
    if ( $debug ) {
        unlink("$program_dir/stderr.txt");
        open( STDERR, ">$program_dir/stderr.txt");
        unlink("$program_dir/stdout.txt");
        open( STDOUT, ">$program_dir/stdout.txt");
    }
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
    # Save data in global variable
    #
    %results_file_suffixes = %local_file_suffix_map;
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

    $results_save_callback = $callback_fn;
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
#   This function updates the text in the results page.
#
#***********************************************************************
sub Update_Results_Tab {
    my ($tab_label, $text) = @_;
  
    my ($suffix, $file_name);

    #
    # Do we have text ?
    #
    if ( ! defined($text) ) {
        $text = "";
    }

    #
    # Are we saving the results directly to a file ?
    #
    print "Update_Results_Tab tab = $tab_label\n" if $debug;
    if ( defined($results_file_name) ) {
        if ( defined($results_file_suffixes{$tab_label}) ) {
            $suffix = $results_file_suffixes{$tab_label};

            #
            # Are we in XML mode ?
            #
            if ( $xml_output_mode ) {
                $file_name = $results_file_name . ".xml";
            }
            else {
                $file_name = $results_file_name . "_$suffix.txt";
            }
            print "Add to results file $file_name\n" if $debug;

            #
            # Append text to the end of the file
            #
            if ( open(FILE, ">>$file_name") ) {
                binmode FILE;
                print(FILE "$text\n");
                close(FILE);
            }
            else {
                print "Error: Failed to save results file $file_name\n";
                exit(1);
            }
        }
    }
    else {
        #
        # Print text to standard out
        #
        print "$text\n";
    }
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
#   This function updates the text in the results page.
#
#***********************************************************************
sub Validator_GUI_Update_Results {
    my ($tab_label, $text) = @_;

    #
    # Print text if we are not in XML mode.
    #
    if ( ! $xml_output_mode ) {
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
        # Create CSV file for testcase results
        #
        $csv_results_file_name = $results_file_name . "_rslt.csv";
        unlink($csv_results_file_name);
        if ( ! open($csv_results_fh, ">$csv_results_file_name") ) {
            print "Error: Failed to create file $csv_results_file_name in Print_TQA_Result_to_CSV\n";
            return;
        }
        binmode $csv_results_fh, ":utf8";
        print "Testcase results CSV file $csv_results_file_name\n" if $debug;

        #
        # Create CSV object
        #
        $csv_object = Text::CSV->new ( { binary => 1, eol => $/ } );
        $csv_object->print($csv_results_fh, \@csv_results_fields);
    }
    else {
        #
        # Open existing results CSV file
        #
        if ( ! open($csv_results_fh, ">>$csv_results_file_name") ) {
            print "Error: Failed to open file $csv_results_file_name in Print_TQA_Result_to_CSV\n";
            return;
        }
        binmode $csv_results_fh, ":utf8";
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
    
    #
    # Close the file
    #
    close($csv_results_fh);
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
        # Print page, if there is one
        #
        elsif ( $result_object->page_no > 0 ) {
            $output_line = sprintf(String_Value("4 spaces") .
                                   String_Value("Page") .
                                   "%3d", $result_object->page_no);
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

    #
    # If this is the first results tab, remember it.  Some messages
    # are only displayed in the first tab, especially in XML
    # output mode.
    #
    if ( ! defined($first_results_tab) ) {
        $first_results_tab = $tab_label;
    }
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

    my ($file_name, $suffix);

    #
    # Are we saving the results directly to a file ?
    #
    print "Validator_GUI_Clear_Results tab = $tab_label\n" if $debug;
    if ( defined($results_file_name) ) {
        if ( defined($results_file_suffixes{$tab_label}) ) {
            $suffix = $results_file_suffixes{$tab_label};

            #
            # Are we in XML mode ?
            #
            if ( $xml_output_mode ) {
                $file_name = $results_file_name . ".xml";
            }
            else {
                $file_name = $results_file_name . "_$suffix.txt";
            }
            print "Add to results file $file_name\n" if $debug;
            print "Clear results file $file_name\n" if $debug;

            #
            # Create an empty file for results.
            #
            unlink($file_name);
            if ( open(FILE, ">$file_name") ) {
                close(FILE);
            }
            else {
                print "Error: Failed to create results file $file_name\n";
                exit(1);
            }
        }
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

    #
    # Print overall compliance score to stdout
    #
    print "\n";
    print String_Value("Overall compliance score") . "$score %, " .
          String_Value("Average faults per page") . "$faults\n";
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
    else {
        #
        # Print fault count and fault count.
        #
        Update_Results_Tab($tab_label, "    " .
                           String_Value("Number of faults") . "$faults");
        Update_Results_Tab($tab_label, "");
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

    #
    # Print overall fault count to stdout
    #
    print "\n";
    print String_Value("Total fault count") . "$faults, " .
          String_Value("Average faults per page") . "$faults_per_page\n";
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
    # Print error message to file.
    #
    Update_Results_Tab($tab_label, "$count:  $url");
    Update_Results_Tab($tab_label, String_Value("2 spaces") . $error);
    Update_Results_Tab($tab_label, "");

    #
    # Print error message to stdout
    #
    if ( defined($results_file_name) ) {
        print "$count:  $url\n";
        print String_Value("2 spaces") . $error . "\n\n";
    }
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

    #
    # Print error message to stdout
    #
    if ( defined($results_file_name) ) {
        print String_Value("2 spaces") . $error . "\n\n";
    }
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
        # Print URL to file.
        #
        print "Validator_GUI_Start_URL tab = $tab_label\n" if $debug;
        $url_line = "$count:  $url      (" .  String_Value("referrer") . 
                    " $referrer)";

        Update_Results_Tab($tab_label, $url_line);
    }

    #
    # If output is to a file, print just the URL to stdout
    #
    if ( defined($results_file_name) ) {
        print "$count:  $url\n";
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
        if ( $tab_label eq $first_results_tab ) {
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
        # Write end analysis message to first tab only (to avoid
        # multiple end messages).
        #
        if ( $tab_label eq $first_results_tab ) {
            $output_line = Validator_XML_End_Analysis($date, $message);
            Update_Results_Tab($tab_label, $output_line);
        }
    }
    else {
        #
        # Print message
        #
        print "Validator_GUI_End_Analysis tab = $tab_label\n" if $debug;
        Update_Results_Tab($tab_label, "$message $date\n\n");
    }
}

#***********************************************************************
#
# Name: Run_Direct_HTML_Input_Callback
#
# Parameters: content - HTML content
#             report_options - a hash table of report option values
#
# Description:
#
#   This function calls on the direct HTML input callback function to 
# analyse a block of HTML code.
#
#***********************************************************************
sub Run_Direct_HTML_Input_Callback {
    my ($content, %report_options) = @_;

    #
    # Call the content callback function
    #
    print "Call content_callback\n" if $debug;
    if ( defined($content_callback) ) {
        &$content_callback($content, %report_options);
        print "Return from content_callback\n" if $debug;
    }
    else {
        print "Error: Missing content callback function in Run_Direct_HTML_Input_Callback\n";
        exit(1);
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
#   This function calls on the URL list callback function to 
# analyse a list of URLs.
#
#***********************************************************************
sub Run_URL_List_Callback {
    my ($url_list, %report_options) = @_;

    my ($eval_output, $key, $value);
    
    print "Run_URL_List_Callback\n" if $debug;
    while ( ($key, $value) = each %report_options ) {
        print "$key = $value\n" if $debug;
    }

    #
    # Call the URL list callback function
    #
    print "Call url_list_callback\n" if $debug;
    if ( defined($url_list_callback) ) {
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
        print "Return from url_list_callback\n" if $debug;

        #
        # Close results CSV file
        #
        if ( defined($csv_results_fh) ) {
            close($csv_results_fh);
        }
    }
    else {
        print "Error: Missing url list callback function in Run_URL_List_Callback\n";
        exit(1);
    }
}

#***********************************************************************
#
# Name: Run_Site_Crawl
#
# Parameters: crawl_details - a hash table of crawl detail values
#
# Description:
#
#   This function calls on the crawl callback function
#
#***********************************************************************
sub Run_Site_Crawl {
    my (%crawl_details) = @_;

    my ($eval_output);

    #
    # Call the site crawl callback function
    #
    print "Call site_crawl_callback\n" if $debug;
    if ( defined($site_crawl_callback) ) {
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

        print "Return from site_crawl_callback\n" if $debug;

        #
        # Close results CSV file
        #
        if ( defined($csv_results_fh) ) {
            close($csv_results_fh);
        }

        #
        # Do we have a Save Results call back function ?
        #
        if ( defined($results_save_callback) && defined($results_file_name) ) {
            print "Call Results_Save_As callback function\n" if $debug;
            &$results_save_callback($results_file_name);
        }
    }
    else {
        print "Error: Missing crawler callback function in Run_Site_Crawl\n";
        exit(1);
    }
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
    # Call the Open Data callback function
    #
    print "Child: Call open_data_callback\n" if $debug;
    if ( defined($open_data_callback) ) {
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
    else {
        print "Error: Missing Open Data callback function in Run_Open_Data_Callback\n";
        exit(1);
    }
}

#***********************************************************************
#
# Name: Read_Password
#
# Parameters: none
#
# Description:
#
#   This function reads a password from STDIN.  It does not echo
# the typed characters.
#
#***********************************************************************
sub Read_Password {
    my $key = 0;
    my $password = "";

    #
    # Disable the control keys
    #
    ReadMode(4);
    
    #
    # Read until we get the Enter key (decimal value of 10 or 13)
    #
    while( 1 ) {
        #
        # Read a keystroke from stdin
        #
        $key = ReadKey(0);
        
        #
        # Did we get a character ?
        #
        if ( ! defined($key) ) {
            last;
        }
        #
        # Do we have enter, either 13 for Windows or 10 for Linux.
        #
        elsif ( (ord($key) == 13) || (ord($key) == 10) ) {
            last;
        }
        #
        # Was a backspace or del key pressed ?
        #
        elsif (ord($key) == 127 || ord($key) == 8) {
            #
            # Remove the last char from the password
            #
            chop($password);

            #
            # Move the cursor back by one, print a blank character,
            # move the cursor back by one
            #
            print "\b \b";
        }
        #
        # Ignore any control characters
        #
        elsif( ord($key) < 32 ) {
        }
        #
        # A character for the password.  Print an
        # asterisk to the screen.
        #
        else {
            $password = $password . $key;
            print "*";
        }
    }
    print "\n";

    #
    # Reset the terminal once we are done
    #
    ReadMode(0);
    
    #
    # Return password value
    #
    return($password);
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
    #
    # If the URL is an empty string, it means that we are attempting to
    # authenticate to a firewall (e.g. PWGSC firewall to access the internet).
    #
    elsif ( $url eq "" ) {
        print String_Value("Firewall authorization required") . "\n";
        #print " Realm = $realm\n";
        print " User name: ";
        $user = <STDIN>;
        print " Password: ";
        $password = Read_Password();
        $user =~ s/^\s+//g;
        $user =~ s/\s+$//g;
        $password =~ s/^\s+//g;
        $user =~ s/\s+$//g;
    }
    else {
        $user = "";
        $password = "";
    }

    #
    # Return login values
    #
    return($user, $password);
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
# response.  It returns a hash table of form field and value.
#
#***********************************************************************
sub Validator_GUI_Login {
    my (%login_fields) = @_;

    my ($field_name, %login_form_values);

    #
    # Copy any field values that were supplied in the
    # login credentials file (-login parameter)
    #
    foreach $field_name (keys %login_fields) {
        if ( defined($login_credentials{$field_name}) ) {
            $login_form_values{$field_name} = $login_credentials{$field_name};
        }
        else {
            $login_form_values{$field_name} = "";
        }
    }

    #
    # Return login form values
    #
    return(%login_form_values);
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
#           $report_fails_only, %report_options)
#    where site_dir_e - English site domain & directory
#          site_dir_f - French site domain & directory
#          site_entry_e - English entry page
#          site_entry_f - French entry page
#          loginpagee - English login page
#          logoutpagee - English logout page
#          loginpagef - French login page
#          logoutpagef - French logout page
#          report_fails_only - report fails only
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

    my ($key, $value);

    #
    # Save callback function addresses
    #
    $content_callback = $content_callback_fn;
    $site_crawl_callback = $crawl_callback;
    $url_list_callback = $url_list_callback_fn;

    #
    # Save default report options
    #
    while ( ($key, $value) = each %report_options ) {
        #
        # Save the first value in the report options list as
        # the default
        #
        $default_report_options{$key} = $$value[0];
        print "Default report option for $key = " . $$value[0] . "\n" if $debug;
    }

    #
    # Set message strings language.
    #
    if ( $lang eq "fra" ) {
        #
        # Results in French
        #
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Results in English
        #
        $string_table = \%string_table_en;
    }
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
# Name: Parse_Site_URL
#
# Parameters: url - URL
#
# Description:
#
#   This function parses a URL to split it into its directory and
# file name components.
#
#***********************************************************************
sub Parse_Site_URL {
    my ($url) = @_;

    my ($site_dir, $site_page, $protocol, $domain, $file_path, $query);
    my ($dir, $file);

    #
    # Do we have a leading http ?
    #
    print "Parse_Site_URL, url = $url\n" if $debug;
    if ( ! ($url =~ /^http[s]?:/i) ) {
        #
        # Missing protocol, add http:// to the URL
        #
        print "No protocol in URL, adding http://\n" if $debug;
        $url = "http://" . $url;
    }

    #
    # Get components of the URL, we expect 1 of the following
    #   http://domain/path?query
    #   http://domain/path#anchor
    #   https://domain/path?query
    #   https://domain/path#anchor
    #
    ($protocol, $domain, $file_path, $query) =
          $url =~ /^(http[s]?:)\/\/?([^\/\s]+)\/([\/\w\-\.]*[^#?]*)(.*)?$/io;

    #
    # Did we get a domain ?
    #
    if ( ! defined($domain) ) {
        #
        # Perhaps we are missing the / after the domain ?
        #  http://domain?query
        #
        ($protocol, $domain, $query) =
          $url =~ /^(http[s]?:)\/\/?([^\/\s#?]*)(.*)?$/io;
        $file_path = "/";
    }

    #
    # Make sure protocol is in lowercase
    #
    if ( defined($protocol) ) {
        $protocol =~ tr/A-Z/a-z/;
    }
    else {
        print "Error, missing or malformed protocol\n" if $debug;
        print String_Value("Malformed URL") . " $url\n";
        exit(1);
    }

    #
    # Did we get a domain ?
    #
    if ( ! defined($domain) ) {
        #
        # Perhaps we are missing the / after the domain ?
        #  http://domain?query
        #
        ($protocol, $domain, $query) =
          $url =~ /^(http[s]?:)\/\/?([^\/\s#?]*)(.*)?$/io;
        $file_path = "/";
    }

    #
    # Change double slash (//) into a single slash in the file path
    #
    while ( $file_path =~ /\/\// ) {
        $file_path =~ s/\/\//\//g;
    }

    #
    # If we again didn't get anthing, return empty strings
    #
    if ( ! defined($domain) ) {
        $site_dir = "";
        $site_page = "";
    }

    #
    # Reconstruct the URL properly
    #
    if ( $file_path ne "/" ) {
        #
        # Get directory portion from the file path
        #
        $dir = dirname($file_path);
        if ( $dir eq "." ) {
            $dir = "";
            $site_dir = "$protocol//$domain";
        }
        else {
            $site_dir = "$protocol//$domain/$dir";
        }
        $file = basename($file_path);
        $site_page = "$file$query";
    }
    else {
        $site_dir = "$protocol//$domain";
        $site_page = "/$query";
    }
    $site_dir =~ s/\/$//g;

    #
    # Return directory and page components
    #
    print "Site directory = $site_dir, page = $site_page\n" if $debug;
    return($site_dir, $site_page);
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
# Name: Select_Testcase_Profile_Group
#
# Parameters: group_name - testcase profile group name
#             report_options - pointer to a report options hash table
#
# Description:
#
#   TSelect the individual testcase profile values based on the group
# specified.
#
#***********************************************************************
sub Select_Testcase_Profile_Group {
    my ($group_name, $report_options) = @_;

    my ($name, $value, $profiles, $valid_value, $custom_value, $label);

    #
    # Is the testcase profile group the "Custom" group ?
    # If so, we don't update the testcase profile values, we leave them
    # the way the user set them.
    #
    print "Select_Testcase_Profile_Group, name = $group_name\n" if $debug;
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
        # Get the valid values for this testcase profile type
        #
        ($valid_value, $value) = Validate_Option_Value($name, $value);
        if ( $valid_value ) {
            print "Select testcase profile $name to $value\n" if $debug;
            $label = $report_options_labels{$name};
            $$report_options{$label} = $value;
        }
    }
}

#***********************************************************************
#
# Name: Read_Crawl_File
#
# Parameters: crawl_file - path of crawl details file
#
# Description:
#
#   This function reads the crawl details file and fills in the crawl
# details hash table.
#
#***********************************************************************
sub Read_Crawl_File {
    my ($crawl_file) = @_;
    
    my (%crawl_details, $line, $key, $value, $site_dir, $site_entry);
    my ($label, $tab, $suffix, $type, $url);

    #
    # Initialize crawl details table to empty string values
    #
    foreach $key (keys(%site_configuration_fields)) {
        $crawl_details{$key} = "";
    }

    #
    # Report failures only
    #
    $crawl_details{"report_fails_only"} = 1;
    $crawl_details{"report_passes_only"} = 0;
    $crawl_details{"process_pdf"} = 1;

    #
    # Copy in default report options
    #
    foreach $key (keys(%default_report_options)) {
        $crawl_details{$key} = $default_report_options{$key};
    }

    #
    # Open the crawl details file
    #
    print "Read_Crawl_File, file name = $crawl_file\n" if $debug;
    if ( ! open (CRAWL_FILE, "$crawl_file") ) {
        print "Error: Failed to open file $crawl_file\n";
        exit(1);
    }

    #
    # Read each line from the crawl details file
    #
    while ( $line = <CRAWL_FILE> ) {
        chomp($line);
        $line =~ s/^\s*//g;
        $line =~s/\r//g;

        #
        # Ignore empty lines and comment lines
        #
        if ( $line =~ /^#/ ) {
            next;
        }
        elsif ( $line =~ /^$/ ) {
            next;
        }
        #
        # Ignore WAAT_Tool configuration type lines
        #
        elsif ( $line =~ /^\s*configType/i ) {
            next;
        }

        #
        # Split the line on the first whitespace, we are expecting
        # a key and value pair.
        #
        ($key, $value) = split(/\s+/, $line, 2);

        #
        # If we don't have a value, set it to an empty string
        #
        if ( ! defined($value) ) {
            $value = "";
        }

        #
        # Did we get a known key value ?
        #
        if ( defined($site_configuration_fields{$key})) {
            print "crawl detail $key, value = $value\n" if $debug;
            $crawl_details{$key} = $value;
        }
        #
        # Check for single English URL (both directory and entry page
        # in a single value).
        #
        elsif ( $key eq "site_url_eng" ) {
            if ( $value ne "" ) {
                $value =~ s/\/*$//g;
                print "crawl detail $key, value = $value\n" if $debug;
                ($site_dir, $site_entry) = Parse_Site_URL($value);
                $crawl_details{"sitedire"} = $site_dir;
                $crawl_details{"siteentrye"} = $site_entry;
            }
        }
        #
        # Check for single French URL (both directory and entry page
        # in a single value).
        #
        elsif ( $key eq "site_url_fra" ) {
            if ( $value ne "" ) {
                $value =~ s/\/*$//g;
                print "crawl detail $key, value = $value\n" if $debug;
                ($site_dir, $site_entry) = Parse_Site_URL($value);
                $crawl_details{"sitedirf"} = $site_dir;
                $crawl_details{"siteentryf"} = $site_entry;
            }
        }
        #
        # Is this a report option type ?
        #
        elsif ( defined($report_options_labels{$key})) {
            print "Report options type $key, value = $value\n" if $debug;
            $label = $report_options_labels{$key};
            $crawl_details{$label} = $value;
            
            #
            # Is this a group profile option ?
            #
            if ( $key eq $testcase_profile_groups_config_option ) {
                #
                # Update all the other testcase profile options
                #
                Select_Testcase_Profile_Group($value, \%crawl_details);
            }
        }
        #
        # Is an output file specified
        #
        elsif ( $key eq "output_file" ) {
            if ( $value ne "" ) {
                #
                # It is possible that the user selected an existing
                # results file.  We have to strip of the results suffix
                # to get the base file name.
                #
                $value =~ s/\.txt$//;
                $value =~ s/\.xml$//;
                while ( ($tab, $suffix) = each %results_file_suffixes ) {
                    $value =~ s/_$suffix$//;
                }
                $results_file_name = $value;
            }
        }
        elsif ( $key eq "HTTP_401" ) {
            #
            # Have HTTP 401 credentials
            #
            ($key, $url, $type, $value) = split(/\s+/, $line);

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
        # Have generated source flag ?
        #
        elsif ( $key eq "enable_generated_markup" ) {
            ($key, $value) = split(/\s+/, $line, 2);
            $enable_generated_markup = $value;
        }
    }

    #
    # Make sure we have values for both the English and French
    # directory and entry pages.
    #
    if ( $crawl_details{"sitedirf"} eq "" ) {
        $crawl_details{"sitedirf"} = $crawl_details{"sitedire"};
    }
    if ( $crawl_details{"siteentryf"} eq "" ) {
        $crawl_details{"siteentryf"} = $crawl_details{"siteentrye"};
    }
    if ( $crawl_details{"sitedire"} eq "" ) {
        $crawl_details{"sitedire"} = $crawl_details{"sitedirf"};
    }
    if ( $crawl_details{"siteentrye"} eq "" ) {
        $crawl_details{"siteentrye"} = $crawl_details{"siteentryf"};
    }

    #
    # Strip off any trailing / from site directory settings.
    #
    $crawl_details{"sitedire"} =~ s/\/$//g;
    $crawl_details{"sitedirf"} =~ s/\/$//g;

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
    # If we don't have a crawl limit, use 0 to get unlimited crawl
    #
    if ( $crawl_details{"crawllimit"} eq "" ) {
        $crawl_details{"crawllimit"} = 0;
    }

    #
    # If we don't have a crawl depth, use default
    #
    if ( $crawl_details{"crawl_depth"} eq "" ) {
        $crawl_details{"crawl_depth"} = $default_crawl_depth;
    }

    #
    # Do we have values for all fields
    #
    if ( $crawl_details{"sitedire"} eq "" ) {
        print "Missing English Site Directory field\n";
        exit(1);
    }

    #
    # Close the crawl details file
    #
    close(CRAWL_FILE);

    #
    # Return the crawl details
    #
    return(%crawl_details);
}

#***********************************************************************
#
# Name: Read_URL_File
#
# Parameters: url_file - path of url details file
#
# Description:
#
#   This function reads the url details file and extracts the list of
# URLs to process and any reporting options.
#
#***********************************************************************
sub Read_URL_File {
    my ($url_file) = @_;
    
    my (%report_options, $line, $key, $value);
    my ($label, $tab, $suffix, $url, $type);
    my ($urls) = "";

    #
    # Copy in default report options
    #
    foreach $key (keys(%default_report_options)) {
        $report_options{$key} = $default_report_options{$key};
    }

    #
    # Report failures only
    #
    $report_options{"report_fails_only"} = 1;
    $report_options{"report_passes_only"} = 0;
    $report_options{"process_pdf"} = 1;

    #
    # Open the url file
    #
    print "Read_URL_File, file name = $url_file\n" if $debug;
    if ( ! open (URL_FILE, "$url_file") ) {
        print "Error: Failed to open file $url_file\n";
        exit(1);
    }

    #
    # Read each line from the file
    #
    while ( $line = <URL_FILE> ) {
        chomp($line);
        $line =~ s/^\s*//g;
        $line =~s/\r//g;

        #
        # Ignore empty lines and comment lines
        #
        if ( $line =~ /^#/ ) {
            next;
        }
        elsif ( $line =~ /^$/ ) {
            next;
        }
        #
        # Ignore WAAT_Tool configuration type lines
        #
        elsif ( $line =~ /^\s*configType/i ) {
            next;
        }

        #
        # Split the line on the first whitespace, we are expecting
        # a key and value pair.
        #
        ($key, $value) = split(/\s+/, $line, 2);

        #
        # Did we get a known site configuration key value ?
        #
        if ( defined($site_configuration_fields{$key})) {
            print "Report option $key, value = $value\n" if $debug;
            if ( defined($value) ) {
                $report_options{$key} = $value;
            }
        }
        #
        # Did we get a known key value ?
        #
        elsif ( defined($default_report_options{$key})) {
            print "Report option $key, value = $value\n" if $debug;
            if ( defined($value) ) {
                $report_options{$key} = $value;
            }
        }
        #
        # Is this a report option type ?
        #
        elsif ( defined($report_options_labels{$key})) {
            print "Report options type $key, value = $value\n" if $debug;
            if ( defined($value) ) {
                $label = $report_options_labels{$key};
                $report_options{$label} = $value;
            }

            #
            # Is this a group profile option ?
            #
            if ( $key eq $testcase_profile_groups_config_option ) {
                #
                # Update all the other testcase profile options
                #
                Select_Testcase_Profile_Group($value, \%report_options);
            }
        }
        #
        # Is an output file specified
        #
        elsif ( $key eq "output_file" ) {
            if ( defined($value) ) {
                #
                # It is possible that the user selected an existing
                # results file.  We have to strip of the results suffix
                # to get the base file name.
                #
                $value =~ s/\.txt$//;
                $value =~ s/\.xml$//;
                while ( ($tab, $suffix) = each %results_file_suffixes ) {
                    $value =~ s/_$suffix$//;
                }
                $results_file_name = $value;
            }
        }
        elsif ( $key eq "HTTP_401" ) {
            #
            # Have HTTP 401 credentials
            #
            ($key, $url, $type, $value) = split(/\s+/, $line);

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
        # Have generated source flag ?
        #
        elsif ( $key eq "enable_generated_markup" ) {
            ($key, $value) = split(/\s+/, $line, 2);
            $enable_generated_markup = $value;
        }
        else {
            #
            # Assume this is a URL
            #
            if ( (! ($line =~ /^http[s]?:/i)) && 
                 (! ($line =~ /^file:/i) ) ) {
                #
                # Missing protocol, add http:// to the URL
                #
                print "No protocol in URL, adding http://\n" if $debug;
                $line = "http://" . $line;
            }
            $urls .= "\r" . $line;
        }
    }

    #
    # Close the urls file
    #
    close(URL_FILE);

    #
    # Return the url list and report options
    #
    return($urls, %report_options);
}

#***********************************************************************
#
# Name: Read_HTML_File
#
# Parameters: html_file - path of HTML details file
#
# Description:
#
#   This function reads the HTML details file to get the reporting
# options as well as the block of HTML code to analyse.
#
#***********************************************************************
sub Read_HTML_File {
    my ($html_file) = @_;
    
    my (%report_options, $line, $key, $value);
    my ($label, $tab, $suffix);
    my ($content) = "";

    #
    # Copy in default report options
    #
    foreach $key (keys(%default_report_options)) {
        $report_options{$key} = $default_report_options{$key};
    }

    #
    # Report failures only
    #
    $report_options{"report_fails_only"} = 1;
    $report_options{"report_passes_only"} = 0;
    $report_options{"process_pdf"} = 1;

    #
    # Open the HTML file
    #
    print "Read_HTML_File, file name = $html_file\n" if $debug;
    if ( ! open (HTML_FILE, "$html_file") ) {
        print "Error: Failed to open file $html_file\n";
        exit(1);
    }

    #
    # Read each line from the file
    #
    while ( $line = <HTML_FILE> ) {
        chomp($line);
        $line =~ s/^\s*//g;

        #
        # Ignore empty lines and comment lines
        #
        if ( $line =~ /^#/ ) {
            next;
        }
        elsif ( $line =~ /^$/ ) {
            next;
        }

        #
        # Split the line on the first whitespace, we are expecting
        # a key and value pair.
        #
        ($key, $value) = split(/\s+/, $line, 2);

        #
        # Did we get a known key value ?
        #
        if ( defined($default_report_options{$key})) {
            print "Report option $key, value = $value\n" if $debug;
            if ( defined($value) ) {
                $report_options{$key} = $value;
            }
        }
        #
        # Is this a report option type ?
        #
        elsif ( defined($report_options_labels{$key})) {
            print "Report options type $key, value = $value\n" if $debug;
            if ( defined($value) ) {
                $label = $report_options_labels{$key};
                $report_options{$label} = $value;
            }

            #
            # Is this a group profile option ?
            #
            if ( $key eq $testcase_profile_groups_config_option ) {
                #
                # Update all the other testcase profile options
                #
                Select_Testcase_Profile_Group($value, \%report_options);
            }
        }
        #
        # Is an output file specified
        #
        elsif ( $key eq "output_file" ) {
            if ( defined($value) ) {
                #
                # It is possible that the user selected an existing
                # results file.  We have to strip of the results suffix
                # to get the base file name.
                #
                $value =~ s/\.txt$//;
                $value =~ s/\.xml$//;
                while ( ($tab, $suffix) = each %results_file_suffixes ) {
                    $value =~ s/_$suffix$//;
                }
                $results_file_name = $value;
            }
        }
        #
        # Is the name of the HTML content file specified ?
        #
        elsif ( $key eq "html_file" ) {
            if ( defined($value) ) {
                #
                # Read the HTML content from the file
                #
                if ( ! open(HTML_CONTENT, "$value") ) {
                    print "Error: Failed to open HTML content file $$value\n";
                    exit(1);
                }
                $content = "";
                while ( <HTML_CONTENT> ) {
                    $content .= $_;
                }
                close(HTML_CONTENT);
            }
        }
    }

    #
    # Close the content file
    #
    close(HTML_FILE);

    #
    # Return the content and report options
    #
    return($content, %report_options);
}

#***********************************************************************
#
# Name: Read_Login_Credentials_File
#
# Parameters: login_file - path of login credentials file
#
# Description:
#
#   This function reads the login credentials file to get any
# username, password and other credentials for a login.  Once
# the file is read it is removed.
#
#***********************************************************************
sub Read_Login_Credentials_File {
    my ($login_file) = @_;

    my ($line, @fields, $field_name, $field_value);

    #
    # Open the HTML file
    #
    print "Read_Login_Credentials_File, file name = $login_file\n" if $debug;
    if ( ! open (LOGIN_FILE, "$login_file") ) {
        print "Error: Failed to open file $login_file\n";
        exit(1);
    }

    #
    # Read each line from the file
    #
    while ( $line = <LOGIN_FILE> ) {
        chomp($line);
        $line =~ s/^\s*//g;

        #
        # Skip blank lines
        #
        if ( $line =~ /^$/ ) {
            next;
        }

        #
        # Split line on white space
        #
        @fields = split(/\s+/, $line, 2);

        #
        # Save credentials
        #
        $field_name = $fields[0];
        $field_value = $fields[1];
        if ( defined($field_value) ) {
            $login_credentials{$field_name} = $field_value;
        }
        else {
            $login_credentials{$field_name} = "";
        }
        print "Found credential $field_name = $field_value\n" if $debug;
    }

    #
    # Close the file
    #
    close(LOGIN_FILE);

    #
    # Remove the login credentials
    #
    unlink($login_file);
}

#***********************************************************************
#
# Name: Read_Open_Data_File
#
# Parameters: open_data_file - path of open data dataset file
#
# Description:
#
#   This function reads the open data file to get the set of dataset URLs.
#
#***********************************************************************
sub Read_Open_Data_File {
    my ($open_data_file) = @_;

    my (%report_options, $line, $field_name, $value, %dataset_urls);
    my ($data_list, $dictionary_list, $resource_list, $tab, $suffix);
    my ($key, $api_list, $description_url, $label);

    #
    # Copy in default report options
    #
    foreach $key (keys(%default_report_options)) {
        $report_options{$key} = $default_report_options{$key};
    }

    #
    # Report failures only
    #
    $report_options{"report_fails_only"} = 1;
    $report_options{"report_passes_only"} = 0;
    $report_options{"process_pdf"} = 1;

    #
    # Open the url file
    #
    print "Read_Open_Data_File, file name = $open_data_file\n" if $debug;
    if ( ! open (OPEN_DATA_FILE, "$open_data_file") ) {
        print "Error: Failed to open file $open_data_file\n";
        exit(1);
    }

    #
    # Read all lines from the file looking for the configuration
    # parameters
    #
    while ( $line = <OPEN_DATA_FILE> ) {
        chomp($line);
        $line =~ s/^\s*//g;
        $line =~s/\r//g;

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
        if ( defined($report_options_labels{$field_name}) ) {
            print "Report options type $field_name, value = $value\n" if $debug;
            if ( defined($value) ) {
                $label = $report_options_labels{$field_name};
                $report_options{$label} = $value;
                print "Report options type $label, value = $value\n" if $debug;
            }
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
        #
        # Is an output file specified
        #
        elsif ( $field_name eq "output_file" ) {
            if ( $value ne "" ) {
                #
                # It is possible that the user selected an existing
                # results file.  We have to strip of the results suffix
                # to get the base file name.
                #
                $value =~ s/\.txt$//;
                $value =~ s/\.xml$//;
                while ( ($tab, $suffix) = each %results_file_suffixes ) {
                    $value =~ s/_$suffix$//;
                }
                $results_file_name = $value;
            }
        }
    }
    close(FILE);

    #
    # Save dataset URLs
    #
    if ( defined($data_list) ) {
        $dataset_urls{"DATA"} = $data_list;
    }    
    if ( defined($description_url) && ( ! ($description_url =~ /^\s*$/)) ) {
        $dataset_urls{"DESCRIPTION"} = $description_url;
    }
    if ( defined($dictionary_list) ) {
        $dataset_urls{"DICTIONARY"} = $dictionary_list;
    }    
    if ( defined($resource_list) ) {
        $dataset_urls{"RESOURCE"} = $resource_list;
    }    
    if ( defined($api_list) ) {
        $dataset_urls{"API"} = $api_list;
    }    

    #
    # Return URLs and report options
    #
    return(\%dataset_urls, %report_options);
}

#***********************************************************************
#
# Name: Validator_GUI_Start
#
# Parameters: args - argument list
#
# Description:
#
#   This function runs the validator Command Line Interface.
#
#***********************************************************************
sub Validator_GUI_Start {
    my (@args) = @_;
    
    my ($urls, %report_options, $url_file, $crawl_file, $arg, %crawl_details);
    my ($crawl_limit, $html_file, $content, $login_credentials_file);
    my ($open_data_file, $dataset_urls, $crawl_depth);
    
    #
    # Check argument list
    #
    print "Validator_GUI_Start args = " . join(", ", @args) . "\n" if $debug;
    if ( @args == 0 ) {
        #
        # No arguments, prompt user for arguments
        #
        print "Program action\n";
        print "  c - crawl a site\n";
        print "  u - process a URL list\n";
        #print "  o - process an Open Data file\n";
        chomp($arg = <STDIN>);
        $arg =~s/\r//g;
        push(@args, "-$arg");
        print "Profile file path\n";
        chomp($arg = <STDIN>);
        $arg =~s/\r//g;
        push(@args, $arg);
    }

    #
    # Process arguments
    #
    while ( $arg = shift(@args) ) {
        #
        # Look for -c leading for crawling a site
        #
        if ( $arg eq "-c" ) {
            #
            # Do we have a pathname ?
            #
            if ( @args > 0 ) {
                $crawl_file = shift(@args);
                print "Got Crawl URL $crawl_file\n" if $debug;
            }
            else {
                print "Error: Missing path after -c\n";
                exit(1);
            }
        }
        #
        # Look for -d <crawl depth>
        #
        elsif ( $arg eq "-d" ) {
            #
            # Do we have a crawl depth ?
            #
            if ( @args > 0 ) {
                $crawl_depth = shift(@args);
                print "Got crawl depth $crawl_depth\n" if $debug;
            }
            else {
                print "Error: Missing number after -d\n";
                exit(1);
            }
        }
        #
        # Look for -h <html content file>
        #
        elsif ( $arg eq "-h" ) {
            #
            # Do we have a pathname ?
            #
            if ( @args > 0 ) {
                $html_file = shift(@args);
                print "Got direct HTML file $html_file\n" if $debug;
            }
            else {
                print "Error: Missing path after -h\n";
                exit(1);
            }
        }
        #
        # Look for -l <crawl limit>
        #
        elsif ( $arg eq "-l" ) {
            #
            # Do we have a crawl limit ?
            #
            if ( @args > 0 ) {
                $crawl_limit = shift(@args);
                print "Got crawl limit $crawl_limit\n" if $debug;
            }
            else {
                print "Error: Missing number after -l\n";
                exit(1);
            }
        }
        #
        # Look for -login <login credentials file>
        #
        elsif ( $arg eq "-login" ) {
            #
            # Do we have a login credentials file ?
            #
            if ( @args > 0 ) {
                $login_credentials_file = shift(@args);
                print "Got login credentials file $login_credentials_file\n" if $debug;
            }
            else {
                print "Error: Missing file name after -login\n";
                exit(1);
            }
        }
        #
        # Look for -o <open data file>
        #
        elsif ( $arg eq "-o" ) {
            #
            # Do we have a pathname ?
            #
            if ( @args > 0 ) {
                $open_data_file = shift(@args);
                print "Got Open Data file $open_data_file\n" if $debug;
            }
            else {
                print "Error: Missing path after -o\n";
                exit(1);
            }
        }
        #
        # Look for -u <url list file>
        #
        elsif ( $arg eq "-u" ) {
            #
            # Do we have a pathname ?
            #
            if ( @args > 0 ) {
                $url_file = shift(@args);
                print "Got URL file $url_file\n" if $debug;
            }
            else {
                print "Error: Missing path after -u\n";
                exit(1);
            }
        }
        #
        # XML output mode
        #
        elsif ( $arg eq "-xml" ) {
            $xml_output_mode = 1;
        }
    }

    #
    # Do we have a login credentials file ?
    #
    if ( defined($login_credentials_file) ) {
        Read_Login_Credentials_File($login_credentials_file);
    }

    #
    # Do we have a crawl file ?
    #
    if ( defined($crawl_file) ) {
        #
        # Read the crawl file to get crawl details
        #
        %crawl_details = Read_Crawl_File($crawl_file);

        #
        # See if there was a crawl limit specified
        #
        if ( defined($crawl_limit) ) {
            $crawl_details{"crawllimit"} = $crawl_limit;
        }
        
        #
        # See if there was a crawl depth specified
        #
        if ( defined($crawl_depth) ) {
            $crawl_details{"crawl_depth"} = $crawl_depth;
        }

        #
        # Doing a site crawl
        #
        Run_Site_Crawl(%crawl_details);
    }
    #
    # Do we have a URL list file ?
    #
    elsif ( defined($url_file) ) {
        #
        # Get list of URLs from the file and reporting options
        #
        ($urls, %report_options) = Read_URL_File($url_file);

        #
        # Analyse the list of URLs
        #
        Run_URL_List_Callback($urls, %report_options);
    }
    #
    # Do we have a direct HTML input file ?
    #
    elsif ( defined($html_file) ) {
        #
        # Get list of URLs from the file and reporting options
        #
        ($content, %report_options) = Read_HTML_File($html_file);

        #
        # Analyse the block of HTML code
        #
        Run_Direct_HTML_Input_Callback($content, %report_options);
    }
    #
    # Are we in open data mode ?
    #
    elsif ( defined($open_data_file) ) {
        #
        # Get list of URLs from the file and reporting options
        #
        ($dataset_urls, %report_options) = Read_Open_Data_File($open_data_file);

        #
        # Analyse the dataset URLs
        #
        Run_Open_Data_Callback($dataset_urls, %report_options);
    }
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

    my ($key, $value);

    #
    # Save callback function addresses
    #
    $open_data_callback = $open_data_callback_fn;

    #
    # Save default report options
    #
    while ( ($key, $value) = each %report_options ) {
        #
        # Save the first value in the report options list as
        # the default
        #
        $default_report_options{$key} = $$value[0];
        print "Default report option for $key = " . $$value[0] . "\n" if $debug;
    }

    #
    # Set message strings language.
    #
    if ( $lang eq "fra" ) {
        #
        # Results in French
        #
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Results in English
        #
        $string_table = \%string_table_en;
    }
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

