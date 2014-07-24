#***********************************************************************
#
# Name:   web_analytics_check.pm
#
# $Revision$
# $URL$
# $Date$
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
my (@paths, $this_path, $program_dir, $program_name, $paths);

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
    );

#
# String table for error strings (French).
#
my %string_table_fr = (
    "Found Google Analytics",    "Trouvé des analytiques de Google",
    "Missing Google Analytics IP anonymization", "Manquantes Google Analytics anonymisation IP",
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
);

my (%testcase_description_fr) = (
"WA_GA",       "WA_GA: Analytiques de Google",
"WA_ID",       "WA_ID: Web Analytique Anonymisation des renseignements",
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
    # Do we have TP_PW_SITE testcase specific data?
    #
    elsif ( $testcase eq "TP_PW_SITE" ) {
        #
        # Get the site includes data type
        #
        ($type, $value) = split(/\s+/, $data, 2);

        #
        # Do we have a site includes directory ?
        #
        if ( ($type eq "DIRECTORY") && defined($value) ) {
            if ( ! ($object->has_field("site_inc_directory")) ) {
                $object->add_field("site_inc_directory", "scalar");
                $object->set_scalar_field("site_inc_directory", $value);
            }
        }
        #
        # Do we have the site includes repository ?
        #
        elsif ( ($type eq "REPOSITORY") && defined($value) ) {
            if ( ! ($object->has_field("site_inc_repository")) ) {
                $object->add_field("site_inc_repository", "scalar");
                $object->set_scalar_field("site_inc_repository", $value);
            }
        }
        #
        # Do we have a trusted domain ? one that we do not
        # have to perform a check of site includes.
        #
        elsif ( ($type eq "TRUSTED") && defined($value) ) {
            if ( ! ($object->has_field("trusted_site_inc_domains")) ) {
                $object->add_field("trusted_site_inc_domains", "hash");
            }
            $hash = $object->get_field("trusted_site_inc_domains");

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
# Name: Check_JavaScript_Web_Analytics
#
# Parameters: content - content pointer
#
# Description:
#
#   This function checks the JavaScript content for possible web analytics
# code.
#
#***********************************************************************
sub Check_JavaScript_Web_Analytics {
    my ($content) = @_;

    #
    # Check for possible google analytics code
    #
    if ( ($$content =~ /_gaq\.push\s*\(/i) ||
         ($$content =~ /_trackPageview/i) ||
         ($$content =~ /ga\s*\(\s*'send',\s*'pageview'\s*/i) ) {

         #
         # Found google analytics
         #
         Record_Result("WA_GA", -1, -1, "",
                       String_Value("Found Google Analytics"));

        #
        # Is there code to anonymize the IP address ?
        #
        if ( ! ( $$content =~ /anonymizeIp/i ) ) {
            Record_Result("WA_ID", -1, -1, "",
                          String_Value("Missing Google Analytics IP anonymization"));
        }

        #
        # Set flag to indicate we found Google Analytics code
        #
        print "Found Google Analytics code\n" if $debug;
        $analytics_type = "Google";
        $found_web_analytics = 1;
    }
    #
    # Look for Piwik analytics code
    #
    elsif ( ($$content =~ /\.trackPageView\s*\(/i) ||
            ($$content =~ /\['trackPageView'\]/i) ) {
        #
        # Set flag to indicate we found Piwik Analytics code
        #
        print "Found Piwik Analytics code\n" if $debug;
        $analytics_type = "Piwik";
        $found_web_analytics = 1;
    }
    #
    # Look for Urchin analytics code
    #
    elsif ( $$content =~ /urchinTracker\s*\(/i ) {
        #
        # Set flag to indicate we found Urchin Analytics code
        #
        print "Found Urchin Analytics code\n" if $debug;
        $analytics_type = "Urchin";
        $found_web_analytics = 1;
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
    my ( $this_url, $language, $profile, $mime_type, $resp, $content ) = @_;

    my (@tqa_results_list, $tcid, $do_tests, $javascript_content);

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
            Check_JavaScript_Web_Analytics(\$javascript_content);
        }
        #
        # Is this JavaScript code ?
        #
        elsif ( ($mime_type =~ /application\/x\-javascript/) ||
                ($mime_type =~ /text\/javascript/) ) {
            #
            # Check for Web Analytics
            #
            Check_JavaScript_Web_Analytics($content);
        }
    }
    else {
        print "No content passed to Web_Analytics_Check\n" if $debug;
        return(@tqa_results_list);
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
    my (@package_list) = ("tqa_result_object", "testcase_data_object",
                          "javascript_validate");

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

