#***********************************************************************
#
# Name:   web_analytics_check.pm
#
# $Revision: 7484 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Web_Analytics/Tools/web_analytics_check.pm $
# $Date: 2016-02-08 08:37:13 -0500 (Mon, 08 Feb 2016) $
#
# Description:
#
#   This file contains routines that parse web pages to check for 
# Web Analytics checkpoints.
#
# Public functions:
#     Set_Web_Analytics_Check_Language
#     Set_Web_Analytics_Check_Debug
#     Set_Web_Analytics_Check_Testcase_Data
#     Set_Web_Analytics_Check_Test_Profile
#     Web_Analytics_Check_Read_URL_Help_File
#     Web_Analytics_Check_Testcase_URL
#     Web_Analytics_Check
#     Web_Analytics_Has_Web_Analytics
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

package web_analytics_check;

use strict;
use File::Basename;

#
# Use WPSS_Tool program modules
#
use javascript_validate;
use testcase_data_object;
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
    @EXPORT  = qw(Set_Web_Analytics_Check_Language
                  Set_Web_Analytics_Check_Debug
                  Set_Web_Analytics_Check_Testcase_Data
                  Set_Web_Analytics_Check_Test_Profile
                  Web_Analytics_Check_Read_URL_Help_File
                  Web_Analytics_Check_Testcase_URL
                  Web_Analytics_Check
                  Web_Analytics_Has_Web_Analytics
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;

my (%tcid_profile_map, $current_profile, $current_profile_name);
my ($analytics_type, $found_web_analytics);
my ($results_list_addr, $current_url);

my ($max_error_message_string) = 2048;

my (%testcase_data_objects);

#
# Status values
#
my ($check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Found Google Analytics",    "Found Google Analytics",
    "Missing Google Analytics IP anonymization", "Missing Google Analytics IP anonymization",
    "Multiple Web Analytics found on page", "Multiple Web Analytics found on page",
    "Web Analytics not found on page", "Web Analytics not found on page",
    );

#
# String table for error strings (French).
#
my %string_table_fr = (
    "Found Google Analytics",    "Trouvé des analytiques de Google",
    "Missing Google Analytics IP anonymization", "Manquantes Google Analytics anonymisation IP",
    "Multiple Web Analytics found on page", "Plusieurs analyses Web trouvées sur la page",
    "Web Analytics not found on page", "Web Analytics introuvable sur la page",
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
    "WA_GA",       "WA_GA: Google Analytics",
    "WA_ID",       "WA_ID: Web Analytics De-Identification",
    "WA_MULTIPLE", "WA_MULTIPLE: Multiple Web Analytic",
);

my (%testcase_description_fr) = (
    "WA_GA",       "WA_GA: Analytiques de Google",
    "WA_ID",       "WA_ID: Web Analytique Anonymisation des renseignements",
    "WA_MULTIPLE", "WA_MULTIPLE: Plusieurs analyses Web",
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
# Name: Set_Web_Analytics_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Web_Analytics_Check_Debug {
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
# Name: Set_Web_Analytics_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Web_Analytics_Check_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_Web_Analytics_Check_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
        $testcase_description_table = \%testcase_description_fr;
        $reverse_testcase_description_table = \%reverse_testcase_description_fr;
        $url_table = \%testcase_url_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_Web_Analytics_Check_Language, language = English\n" if $debug;
        $string_table = \%string_table_en;
        $testcase_description_table = \%testcase_description_en;
        $reverse_testcase_description_table = \%reverse_testcase_description_en;
        $url_table = \%testcase_url_en;
    }
}

#**********************************************************************
#
# Name: Web_Analytics_Check_Read_URL_Help_File
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
sub Web_Analytics_Check_Read_URL_Help_File {
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
    print "Web_Analytics_Check_Read_URL_Help_File Openning file $filename\n" if $debug;
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
# Name: Web_Analytics_Check_Testcase_URL
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase URL
# table for the specified key.
#
#**********************************************************************
sub Web_Analytics_Check_Testcase_URL {
    my ($key) = @_;

    #
    # Do we have a string table entry for this key ?
    #
    print "Web_Analytics_Check_Testcase_URL, key = $key\n" if $debug;
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
# Name: Set_Web_Analytics_Check_Testcase_Data
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
sub Set_Web_Analytics_Check_Testcase_Data {
    my ($profile, $testcase, $data) = @_;

}

#***********************************************************************
#
# Name: Set_Web_Analytics_Check_Test_Profile
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
sub Set_Web_Analytics_Check_Test_Profile {
    my ($profile, $clf_checks ) = @_;

    my (%local_clf_checks);
    my ($key, $value, $object);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Web_Analytics_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_clf_checks = %$clf_checks;
    $tcid_profile_map{$profile} = \%local_clf_checks;
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
    $current_profile = $tcid_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;
    
    #
    # Initialize flags and counters
    #
    $current_profile_name = $profile;
    $analytics_type = "";
    $found_web_analytics = 0;
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
#   This function records the testcase result.
#
#***********************************************************************
sub Record_Result {
    my ($testcase_list, $line, $column, $text, $error_string) = @_;

    my ($result_object, $testcase, $id);

    #
    # Check for a possible list of testcase identifiers.  The first
    # identifier that is part of the current profile is the one that
    # the error will be reported against.
    #
    foreach $id (split(/,/, $testcase_list)) {
        if ( defined($$current_profile{$id}) ) {
            $testcase = $id;
            last;
        }
    }

    #
    # Is this testcase included in the profile
    #
    if ( defined($testcase) && defined($$current_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $check_fail,
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
# Name: Check_Web_Analytics_Markers
#
# Parameters: html_content - HTML content pointer
#             javascript_content - JavaScript content pointer
#
# Description:
#
#   This function checks the HTML and JavaScript content for
# possible web analytics code.
#
#***********************************************************************
sub Check_JavaScript_Web_Analytics {
    my ($html_content, $javascript_content) = @_;
    
    my ($analytics_type_count) = 0;
    my ($analytics_types) = "";

    #
    # Check for possible google analytics code in JavaScript
    #
    if ( ($$javascript_content =~ /_gaq\.push\s*\(/i) ||
         ($$javascript_content =~ /_trackPageview/i) ||
         ($$javascript_content =~ /ga\s*\(\s*'send',\s*'pageview'\s*/i) ) {

         #
         # Found google analytics
         #
         Record_Result("WA_GA", -1, -1, "",
                       String_Value("Found Google Analytics"));

        #
        # Is there code to anonymize the IP address ?
        #
        if ( ! ( $$javascript_content =~ /anonymizeIp/i ) ) {
            Record_Result("WA_ID", -1, -1, "",
                          String_Value("Missing Google Analytics IP anonymization"));
        }

        #
        # Set flag to indicate we found Google Analytics code
        #
        print "Found Google Analytics code\n" if $debug;
        $analytics_type = "Google";
        $found_web_analytics = 1;
        $analytics_type_count++;
        $analytics_types .= "$analytics_type ";
    }
    
    #
    # Look for Piwik analytics code in the JavaScript
    #
    if ( ($$javascript_content =~ /\.trackPageView\s*\(/i) ||
         ($$javascript_content =~ /\['trackPageView'\]/i) ) {
        #
        # Set flag to indicate we found Piwik Analytics code
        #
        print "Found Piwik Analytics code\n" if $debug;
        $analytics_type = "Piwik";
        $found_web_analytics = 1;
        $analytics_type_count++;
        $analytics_types .= "$analytics_type ";
    }
    
    #
    # Look for Adobe analytics code in JavaScript
    #
    if ( $$javascript_content =~ /_satellite\.pageBottom\s*\(\s*\)\s*;/i ) {
        #
        # Set flag to indicate we found Adobe Analytics code
        #
        print "Found Adobe Analytics code\n" if $debug;
        $analytics_type = "Adobe";
        $found_web_analytics = 1;
        $analytics_type_count++;
        $analytics_types .= "$analytics_type ";
    }
    
    #
    # Look for Urchin analytics code in the JavaScript
    #
    if ( $$javascript_content =~ /urchinTracker\s*\(/i ) {
        #
        # Set flag to indicate we found Urchin Analytics code
        #
        print "Found Urchin Analytics code\n" if $debug;
        $analytics_type = "Urchin";
        $found_web_analytics = 1;
        $analytics_type_count++;
        $analytics_types .= "$analytics_type ";
    }

    #
    # Do we have multiple analytics types?
    #
    if ( $analytics_type_count > 1 ) {
         Record_Result("WA_MULTIPLE", -1, -1, "",
                       String_Value("Multiple Web Analytics found on page") .
                       " $analytics_types");
    }
}

#***********************************************************************
#
# Name: Web_Analytics_Check
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
sub Web_Analytics_Check {
    my ($this_url, $language, $profile, $mime_type, $resp, $content) = @_;

    my (@tqa_results_list, $tcid, $do_tests, $javascript_content);
    my ($result_object);
    my ($empty_string) = "";

    #
    # Initialize the test case pass/fail table.
    #
    print "Web_Analytics_Check: URL $this_url, mime-type = $mime_type, lanugage = $language, profile = $profile\n" if $debug;
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Are any of the testcases defined in this module 
    # in the testcase profile ?
    #
    $do_tests = 0;
    foreach $tcid (keys(%testcase_description_en)) {
        if ( defined($$current_profile{$tcid}) ) {
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
        # Check mime-type of content
        #
        if ( $mime_type =~ /text\/html/ ) {
            #
            # Extract JavaScript from the HTML code
            #
            $javascript_content = 
                JavaScript_Validate_Extract_JavaScript_From_HTML($this_url,
                                                                 $content);

            #
            # Check for Web Analytics
            #
            Check_JavaScript_Web_Analytics($content, \$javascript_content);
        }
        #
        # Is this JavaScript code ?
        #
        elsif ( ($mime_type =~ /application\/x\-javascript/) ||
                ($mime_type =~ /text\/javascript/) ) {
            #
            # Check for Web Analytics
            #
            Check_JavaScript_Web_Analytics(\$empty_string, $content);
        }
    }
    else {
        print "No content passed to Web_Analytics_Check\n" if $debug;
        return(@tqa_results_list);
    }

    #
    # Add help URL to result
    #
    foreach $result_object (@tqa_results_list) {
        $tcid = $result_object->testcase();
        if ( defined(Web_Analytics_Check_Testcase_URL($tcid)) ) {
            $result_object->help_url(Web_Analytics_Check_Testcase_URL($tcid));
        }
    }

    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Web_Analytics_Has_Web_Analytics
#
# Parameters: none
#
# Description:
#
#   This function returns whether or not the last URL analysed contained
# web analytics.  It also returns the type of Web analytics (e.g. google).
#
#***********************************************************************
sub Web_Analytics_Has_Web_Analytics {

    return($found_web_analytics, $analytics_type);
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

