#***********************************************************************
#
# Name:   epub_check.pm
#
# $Revision: 1794 $
# $URL: svn://10.36.148.185/WPSS_Tool/TQA_Check/Tools/epub_check.pm $
# $Date: 2020-04-29 08:44:45 -0400 (Wed, 29 Apr 2020) $
#
# Description:
#
#   This file contains routines that parse EPUB files and check for
# a number of accessibility (WCAG) check points.
#
# Public functions:
#     Set_EPUB_Check_Language
#     Set_EPUB_Check_Debug
#     Set_EPUB_Check_Valid_Markup
#     Set_EPUB_Check_Testcase_Data
#     Set_EPUB_Check_Test_Profile
#     EPUB_Check
#     EPUB_Check_Manifest_File
#     EPUB_Check_Get_OPF_File
#     EPUB_Check_OPF_Parse
#     EPUB_Check_Cleanup
#
# Terms and Conditions of Use
#
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is
# distributed under the MIT License.
#
# MIT License
#
# Copyright (c) 2015 Government of Canada
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

package epub_check;

use strict;
use Encode;
use URI::URL;
use File::Basename;
use XML::Parser;

#
# Use WPSS_Tool program modules
#
use epub_html_check;
use epub_opf_parse;
use epub_parse;
use html_check;
use tqa_result_object;
use tqa_testcases;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Set_EPUB_Check_Language
                  Set_EPUB_Check_Debug
                  Set_EPUB_Check_Valid_Markup
                  Set_EPUB_Check_Testcase_Data
                  Set_EPUB_Check_Test_Profile
                  EPUB_Check
                  EPUB_Check_Manifest_File
                  EPUB_Check_Get_OPF_File
                  EPUB_Check_OPF_Parse
                  EPUB_Check_Cleanup
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
my (%epub_check_profile_map, $current_epub_check_profile, $current_url);
my ($invalid_epub_version) = 0;
my (%epub_versions);

my ($is_valid_markup) = -1;
my ($max_error_message_string)= 2048;

#
# Status values
#
my ($epub_check_pass)       = 0;
my ($epub_check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Fails validation",           "Fails validation, see validation results for details.",
    "Missing landmarks navigation list", "Missing landmarks navigation list",
    "Missing list of illustrations", "Missing list of illustrations",
    "Missing list of pages",      "Missing list of pages",
    "Missing list of tables",     "Missing list of tables",
    "Missing table of content",   "Missing table of content",
    );

my %string_table_fr = (
    "Fails validation",           "Échoue la validation, voir les résultats de validation pour plus de détails.",
    "Missing landmarks navigation list", "Liste de navigation des landmarks manquants",
    "Missing list of illustrations", "Liste manquante d'illustrations",
    "Missing list of pages",      "Liste manquante de pages",
    "Missing list of tables",     "Liste manquante de tables",
    "Missing table of content",   "Table des matières manquante",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_EPUB_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_EPUB_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
    
    #
    # Set debug flag in supporting modules
    #
    Set_EPUB_OPF_Parse_Debug($debug);
    Set_EPUB_Parse_Debug($debug);
    Set_EPUB_HTML_Check_Debug($debug);
}

#**********************************************************************
#
# Name: Set_EPUB_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_EPUB_Check_Language {
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
    
    #
    # Set language in supporting modules
    #
    Set_EPUB_OPF_Parse_Language($language);
    Set_EPUB_Parse_Language($language);
    Set_EPUB_HTML_Check_Language($language);
}

#***********************************************************************
#
# Name: Set_EPUB_Check_Valid_Markup
#
# Parameters: valid_epub - flag
#
# Description:
#
#   This function copies the passed flag into the global
# variable is_valid_xtml.  The possible values are
#    1 - valid EPUB
#    0 - not valid EPUB
#   -1 - unknown validity.
# This value is used when assessing WCAG 2.0-G134
#
#***********************************************************************
sub Set_EPUB_Check_Valid_Markup {
    my ($valid_epub) = @_;

    #
    # Copy the data into global variable
    #
    if ( defined($valid_epub) ) {
        $is_valid_markup = $valid_epub;
    }
    else {
        $is_valid_markup = -1;
    }
    print "Set_EPUB_Check_Valid_Markup, validity = $is_valid_markup\n" if $debug;
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
# Name: Set_EPUB_Check_Testcase_Data
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
sub Set_EPUB_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    my ($type, $versions, $line, @version_list);

    #
    # Check for minimum EPUB version setting for testcase WCAG_2.0-Guideline41
    #
    if ( $testcase eq "WCAG_2.0-Guideline41" ) {
        #
        # Check each line of the testcase data
        #
        foreach $line (split(/\n/, $data)) {
            #
            # Split the data line into a technology type and versions
            #
            ($type, $versions) = split(/\s+/, $line, 2);

            if ( defined($versions) && ($type =~ /^EPUB_VERSIONS$/i) ) {
                #
                # Save the versions in a table for easy checking
                #
                @version_list = split(/\s+/, $versions);
                foreach (@version_list) {
                    $epub_versions{$_} = 1;
                }
                last;
            }
        }
    }
    #
    # Save any other testcase data into the table
    #
    else {
        $testcase_data{$testcase} = $data;
    }

    #
    # Set testcase data in supporting modules
    #
    Set_EPUB_OPF_Parse_Testcase_Data($testcase, $data);
    Set_EPUB_Parse_Testcase_Data($testcase, $data);
    Set_EPUB_HTML_Check_Testcase_Data($testcase, $data);
}

#***********************************************************************
#
# Name: Set_EPUB_Check_Test_Profile
#
# Parameters: profile - EPUB check test profile
#             epub_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by XML testcase name.
#
#***********************************************************************
sub Set_EPUB_Check_Test_Profile {
    my ($profile, $epub_checks) = @_;

    my (%local_epub_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_EPUB_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_epub_checks = %$epub_checks;
    $epub_check_profile_map{$profile} = \%local_epub_checks;
    
    #
    # Set profile in supporting modules
    #
    Set_EPUB_Parse_Test_Profile($profile, $epub_checks);
    Set_EPUB_OPF_Parse_Test_Profile($profile, $epub_checks);
    Set_EPUB_HTML_Check_Test_Profile($profile, $epub_checks);
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - EPUB check test profile
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
    $current_epub_check_profile = $epub_check_profile_map{$profile};
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

    my ($result_object, $impact);

    #
    # Is this testcase included in the profile
    #
    if ( defined($testcase) && defined($$current_epub_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $epub_check_fail,
                                                TQA_Testcase_Description($testcase),
                                                $line, $column, $text,
                                                $error_string, $current_url);
        $result_object->testcase_groups(TQA_Testcase_Groups($testcase));
        push (@$results_list_addr, $result_object);

        #
        # Add impact if it is not blank.
        #
        $impact = TQA_Testcase_Impact($testcase);
        if ( $impact ne "" ) {
            $result_object->impact($impact);
        }

        #
        # Print error string to stdout
        #
        Print_Error($line, $column, $text, "$testcase : $error_string");
    }
}

#***********************************************************************
#
# Name: EPUB_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             content - EPUB content pointer
#
# Description:
#
#   This function runs a number of technical QA checks on EPUB files.
# Only the EPUB container file is checked, the EPUB_Check_Manifest_File
# function is used to check the content of each component file.
#
#***********************************************************************
sub EPUB_Check {
    my ($this_url, $language, $profile, $content) = @_;

    my (@tqa_results_list, $result_object);

    #
    # Do we have a valid profile ?
    #
    print "EPUB_Check: Checking URL $this_url, lanugage = $language, profile = $profile\n" if $debug;
    if ( ! defined($epub_check_profile_map{$profile}) ) {
        print "EPUB_Check: Unknown testcase profile passed $profile\n";
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
        # Doesn't look like a URL.  Could be just a block of content
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Check to see if we were told that this document is not
    # a valid EPUB
    #
    if ( $is_valid_markup == 0 ) {
        Record_Result("WCAG_2.0-G134", -1, 0, "",
                      String_Value("Fails validation"));
    }

    #
    # Did we get any content ?
    #
    if ( length($$content) > 0 ) {
    }
    else {
        print "No content passed to EPUB_Check\n" if $debug;
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "EPUB_Check results\n";
        foreach $result_object (@tqa_results_list) {
            print "Testcase: " . $result_object->testcase;
            print "  status   = " . $result_object->status . "\n";
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
# Name: Check_Navigation_File
#
# Parameters: epub_opf_object - an object containing details on the
#                                complete EPUB document
#             nav_item_object - an object containing details on
#                                the epub file
#             this_url - a URL
#
# Description:
#
#   This function performs checks on navigation files.
#
#***********************************************************************
sub Check_Navigation_File {
    my ($epub_opf_object, $nav_item_object, $this_url) = @_;
    
    my (%epub_nav_types, $page_count, $illustration_count, $list_item);
    my ($manifest_list, $table_count);

    #
    # Navigation file specific checks
    # Get the table of navigation types found in the file.
    #
    print "Check_Navigation_File\n" if $debug;
    %epub_nav_types = $nav_item_object->nav_types();
    
    #
    # Are we missing a table of contents
    #
    if ( ! defined($epub_nav_types{"toc"}) ) {
        Record_Result("EPUB-ACCESS-002", -1, 0, "",
                      String_Value("Missing table of content"));
    }
    
    #
    # Count the number of page breaks, illustrations and tables found in
    # content documents.
    #
    $page_count = 0;
    $illustration_count = 0;
    $manifest_list = $epub_opf_object->manifest();
    for $list_item (@$manifest_list) {
        $page_count += $list_item->page_count();
        $illustration_count += $list_item->illustration_count();
        $table_count += $list_item->table_count();
    }
    
    #
    # Do we have a page count with no page list?
    #
    if ( ($page_count > 1) && ( ! defined($epub_nav_types{"page-list"})) ) {
        Record_Result("EPUB-PAGE-003", -1, 0, "",
                      String_Value("Missing list of pages"));
    }

    #
    # Do we have an illustration count with no list of illustrations?
    # Set threshold for the list at 5 illustrations.
    #
    if ( ($illustration_count > 5) && ( ! defined($epub_nav_types{"loi"})) ) {
        Record_Result("EPUB-ACCESS-002", -1, 0, "",
                      String_Value("Missing list of illustrations"));
    }

    #
    # Do we have an table count with no list of tables?
    # Set threshold for the list at 5 tables.
    #
    if ( ($table_count > 5) && ( ! defined($epub_nav_types{"lot"})) ) {
        Record_Result("EPUB-ACCESS-002", -1, 0, "",
                      String_Value("Missing list of tables"));
    }

    #
    # Do we have a landmarks navigation section?
    #
    if ( ! defined($epub_nav_types{"landmarks"}) ) {
        Record_Result("EPUB-SEM-003", -1, 0, "",
                      String_Value("Missing landmarks navigation list"));
    }
}


#***********************************************************************
#
# Name: Is_String_UTF_8
#
# Parameters: byte_string - a byte string
#
# Description:
#
#   This function checks to see if a string is UTF-8 or not.
#
#***********************************************************************
sub Is_String_UTF_8 {
    my ($byte_string) = @_;
    
    #
    # Attempt to decode the byte string as UTF-8
    #
    if ( eval { decode( 'UTF-8', $byte_string, Encode::FB_CROAK ) } ) {
        return(1);
    }
    else {
        return(0);
    }
}
    
#***********************************************************************
#
# Name: EPUB_Check_Manifest_File
#
# Parameters: epub_opf_object - an object containing details on the
#                                complete EPUB document
#             epub_item_object - an object containing details on
#                                the epub file
#             this_url - a URL
#             profile - testcase profile
#             file_name - path to file
#             epub_uncompressed_dir - directory of uncompressed EPUB
#
# Description:
#
#   This function runs a number of technical QA checks on EPUB content.
#
#***********************************************************************
sub EPUB_Check_Manifest_File {
    my ($epub_opf_object, $epub_item_object, $this_url, $profile,
        $file_name, $epub_uncompressed_dir) = @_;

    my (@tqa_results_list, $result_object, $content, $line, $media_type);
    my ($resp, @links, $version, @other_results, $language, %properties);

    #
    # Do we have a valid profile ?
    #
    $language = $epub_opf_object->language();
    print "EPUB_Check_Manifest_File Checking URL $this_url, lanugage = $language, profile = $profile\n" if $debug;
    if ( ! defined($epub_check_profile_map{$profile}) ) {
        print "EPUB_Check: Unknown testcase profile passed $profile\n";
        return(@tqa_results_list);
    }
    
    #
    # Is the EPUB version valid?
    #
    $version = $epub_opf_object->version();
    if ( ($version eq "") ||
         (! defined($epub_versions{$version})) ) {
        print "Skip EPUB checks, version not valid\n" if $debug;
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
        # Doesn't look like a URL.  Could be just a block of content
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);
    
    #
    # Read the content from the file
    #
    print "Read content from file $epub_uncompressed_dir/$file_name\n" if $debug;
    $content = "";
    if ( ! open (CONTENT, "$epub_uncompressed_dir/$file_name") ) {
        print  "EPUB_Check_Manifest_File: Failed to open file\n" if $debug;
        print STDERR "EPUB_Check_Manifest_File: Failed to open file\n";
        print STDERR "$epub_uncompressed_dir/$file_name\n";
        print STDERR "from URL $this_url\n";
        return(@tqa_results_list);
    }
    binmode CONTENT, ":utf8";
    while ( $line = <CONTENT> ) {
        $content .= $line;
    }
    close(CONTENT);
    
    #
    # Is content UTF-8?
    #
    if ( Is_String_UTF_8($content) ) {
        #
        # Did we get any content ?
        #
        print "Content length = " . length($content) . "\n" if $debug;
        if ( length($content) > 0 ) {
            #
            # Check mime-type/media-type of file
            #
            $media_type = $epub_item_object->media_type();
            print "Check media_type = $media_type\n" if $debug;
            if ( $media_type =~ /html/i ) {
                print "Run HTML check on content\n" if $debug;
                @tqa_results_list = HTML_Check_EPUB_File($this_url,
                                                     $language, $profile,
                                                     \$content);
                                           
                #
                # Run EPUB specific checks on the HTML content
                #
                print "Run EPUB specific HTML check on content\n" if $debug;
                @other_results = EPUB_HTML_Check($this_url,
                                                 $language, $profile,
                                                 \$content, $epub_item_object);

                #
                # Add results from the EPUB checks to the general
                # HTML checks
                #
                foreach $result_object (@other_results) {
                    push(@tqa_results_list, $result_object);
                }
            }
        }
        else {
            print "No content passed to EPUB_Check_Manifest_File\n" if $debug;
        }
    }
    else {
            print "Non UTF-8 content passed to EPUB_Check_Manifest_File\n" if $debug;
    }
    
    #
    # Is this a navigation file? Additional checks must be performed
    # such as checking for table of contents.
    #
    %properties = $epub_item_object->properties();
    if ( defined($properties{"nav"}) ) {
       Check_Navigation_File($epub_opf_object, $epub_item_object, $this_url);
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "EPUB_Check_Manifest_File results\n";
        foreach $result_object (@tqa_results_list) {
            print "Testcase: " . $result_object->testcase;
            print "  status   = " . $result_object->status . "\n";
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
# Name: EPUB_Check_Get_OPF_File
#
# Parameters: this_url - a URL
#             resp - HTTP::Response object
#             profile - testcase profile
#             content - EPUB content pointer
#
# Description:
#
#   This function parses an EPUB file and returns the name of
# the OPF package file.
#
#***********************************************************************
sub EPUB_Check_Get_OPF_File {
    my ($this_url, $resp, $profile, $content) = @_;
    
    my ($results_list_addr, $opf_file_names, $epub_uncompressed_dir);
    
    #
    # Call EPUB Parse function to get the OPF container file name
    #
    print "EPUB_Check_Get_OPF_File url = $this_url\n" if $debug;
    ($results_list_addr, $opf_file_names, $epub_uncompressed_dir) =
        EPUB_Parse_Get_OPF_File($this_url, $resp, $profile, $content);
    return($results_list_addr, $opf_file_names, $epub_uncompressed_dir);
}

#***********************************************************************
#
# Name: EPUB_Check_OPF_Parse
#
# Parameters: this_url - a URL
#             epub_uncompressed_dir - directory containing EPUB files
#             filename - name of OPF file
#             profile - testcase profile
#
# Description:
#
#   This function parses an EPUB OPF file and returns an object
# containing the core details.
#
#***********************************************************************
sub EPUB_Check_OPF_Parse {
    my ($this_url, $epub_uncompressed_dir, $filename, $profile) = @_;
    
    my ($results_list_addr, $epub_opf_object);
    
    #
    # Call EPUB OPF Parse function to get the EPUB package details
    #
    print "EPUB_Check_OPF_Parse\n" if $debug;
    ($results_list_addr, $epub_opf_object) = EPUB_OPF_Parse($this_url,
                                                            $epub_uncompressed_dir,
                                                            $filename, $profile);
    return($results_list_addr, $epub_opf_object);
}

#***********************************************************************
#
# Name: EPUB_Check_Cleanup
#
# Parameters: epub_uncompressed_dir - directory
#
# Description:
#
#   This function cleans up any temporary files or directories created
# by this module.
#
#***********************************************************************
sub EPUB_Check_Cleanup {
    my ($epub_uncompressed_dir) = @_;

    #
    # Call on EPUB Parse Cleanup to remove temporary files
    #
    EPUB_Parse_Cleanup($epub_uncompressed_dir);
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

