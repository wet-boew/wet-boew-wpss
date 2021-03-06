#***********************************************************************
#
# Name:   tqa_deque_axe.pm
#
# $Revision: 1759 $
# $URL: svn://10.36.148.185/WPSS_Tool/TQA_Check/Tools/tqa_deque_axe.pm $
# $Date: 2020-03-21 15:23:12 -0400 (Sat, 21 Mar 2020) $
#
# Description:
#
#   This file contains routines to run the Deque Axe accessibility test tool.
#
# Public functions:
#     Deque_AXE_Config
#     Deque_AXE_Debug
#     Set_Deque_AXE_Language
#     Set_Deque_AXE_Testcase_Data
#     Set_Deque_AXE_Test_Profile
#     Deque_AXE_Check
#
# Terms and Conditions of Use
#
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is
# distributed under the MIT License.
#
# MIT License
#
# Copyright (c) 2020 Government of Canada
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

package tqa_deque_axe;

use strict;
use Encode;
use File::Basename;
use JSON::PP;

#
# Use WPSS_Tool program modules
#
use tqa_result_object;
use tqa_testcases;

my $have_threads = eval 'use threads; 1';
if ( $have_threads ) {
    $have_threads = eval 'use threads::shared; 1';
}

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Deque_AXE_Config
                  Deque_AXE_Debug
                  Set_Deque_AXE_Language
                  Set_Deque_AXE_Testcase_Data
                  Set_Deque_AXE_Test_Profile
                  Deque_AXE_Check
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);
my (%tqa_check_profile_map, $current_tqa_check_profile);
my ($current_url, $results_list_addr, %testcase_data);
my ($debug) = 0;
my ($axe_runtime_reported) = 0;
my ($default_windows_chrome_path);

my ($deque_axe_installed);
if ( $have_threads ) {
    share(\$deque_axe_installed);
}


#
# String table for error strings.
#
my %string_table_en = (
    "Deque Axe not installed",       "Deque Axe not installed",
    "Runtime Error",                 "Runtime Error",
);

my %string_table_fr = (
    "Deque Axe not installed",       "Deque Axe pas install�",
    "Runtime Error",                 "Erreur D'Ex�cution",
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#********************************************************
#
# Name: Deque_AXE_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Deque_AXE_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: Deque_AXE_Config
#
# Parameters: config_vars
#
# Description:
#
#   This function sets a number of package configuration values.
# The values are passed in as a hash table.
#
#***********************************************************************
sub Deque_AXE_Config {
    my (%config_vars) = @_;

    my ($key, $value);

    #
    # Check for known configuration values
    #
    while ( ($key, $value) = each %config_vars ) {
        #
        # Check for known configuration variables
        #
    }
}

#**********************************************************************
#
# Name: Set_Deque_AXE_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Deque_AXE_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_Deque_AXE_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_Deque_AXE_Language, language = English\n" if $debug;
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
# Name: Set_Deque_AXE_Testcase_Data
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
sub Set_Deque_AXE_Testcase_Data {
    my ($testcase, $data) = @_;

    my ($type, $value);

    #
    # Is this data for the default location of Chrome on Windows
    # platforms?
    #
    if ( $testcase eq "AXE" ) {
        ($type, $value) = split(/\s/, $data, 2);

        #
        # Is this the default chrome path?
        #
        if ( defined($value) && ($type eq "default_windows_chrome_path") ) {
            $default_windows_chrome_path = $value;
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
# Name: Set_Deque_AXE_Test_Profile
#
# Parameters: profile - TQA check test profile
#             tqa_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by TQA testcase name.
#
#***********************************************************************
sub Set_Deque_AXE_Test_Profile {
    my ($profile, $tqa_checks ) = @_;

    my (%local_tqa_checks);
    my ($key, $value);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Deque_AXE_Test_Profile, profile = $profile\n" if $debug;
    %local_tqa_checks = %$tqa_checks;
    $tqa_check_profile_map{$profile} = \%local_tqa_checks;
}

#***********************************************************************
#
# Name: Check_Deque_Axe_Requirements
#
# Parameters: none
#
# Description:
#
#   This function checks to see if all the system requirements are
# available to run Deque axe.  The requirements are:
#    - Node runtime environment
#    - axe-core module installed in Node
#
# Returns:
#   1 - requirements met
#   0 - requirements not met
#
#***********************************************************************
sub Check_Deque_Axe_Requirements {
    my ($file_path, $chrome_path);
    my ($meets_requirements) = 1;

    #
    # Have we already checked that Deque Axe requirements are available
    #
    print "Check_Deque_Axe_Requirements\n" if $debug;
    if ( defined($deque_axe_installed) ) {
        return($deque_axe_installed);
    }

    #
    # Check for requirements
    #
    if ( $^O =~ /MSWin32/ ) {
        #
        # Windows.
        #
        # Get path to axe
        #
        print "Check for axe program\n" if $debug;
        $file_path = `where axe 2>&1`;
        if ( $file_path =~ /Could not find/i ) {
            print "axe not in path\n" if $debug;
            print STDERR "Deque Axe not installed, axe not available\n";
            $meets_requirements = 0;
        }
        else {
            print "axe found at $file_path\n" if $debug;
        }
        
        #
        # Get path to node
        #
        if ( $meets_requirements ) {
            print "Check for node program\n" if $debug;
            $file_path = `where node 2>&1`;
            if ( $file_path =~ /Could not find/i ) {
                print "Node not in path\n" if $debug;
                print STDERR "Node not installed, headless chrome not available\n";
                $meets_requirements = 0;
            }
            else {
                print "Node found at $file_path\n" if $debug;
            }
        }

        #
        # Check for headless chrome
        #
        if ( $meets_requirements ) {
            #
            # Find Chrome in the path or use default path
            #
            $chrome_path = `where chrome 2>&1`;
            if ( $chrome_path =~ /Could not find/i ) {
                print "Chrome not in path, use default\n" if $debug;
                if ( defined($default_windows_chrome_path) ) {
                    print "Default chrome path = $default_windows_chrome_path\n" if $debug;
                    $chrome_path = $default_windows_chrome_path;
                }
                else {
                    print "No default chrome path\n" if $debug;
                    undef $chrome_path;
                }
            }

            #
            # Did we get a path?
            #
            if ( defined($chrome_path) && (-f $chrome_path) ) {
                print "Chrome executable found at $chrome_path\n" if $debug;
            }
            else {
                #
                # No chrome executable
                #
                print "Chrome executable not found\n" if $debug;
                print STDERR "Chrome not installed, headless chrome not available\n";
                $meets_requirements = 0;
            }
        }
    }
    else {
        #
        # Not Windows.
        #
        # Get path to axe
        #
        print "Check for axe program\n" if $debug;
        $file_path = `which axe 2>&1`;
        if ( $file_path =~ /no axe/i ) {
            print "axe not in path\n" if $debug;
            print STDERR "Deque Axe not installed, axe not available\n";
            $meets_requirements = 0;
        }
        else {
            print "axe found at $file_path\n" if $debug;
        }

        #
        # Not Windows.
        #
        print STDERR "Not Windows, headless chrome not available\n";
        $meets_requirements = 0;
    }

    #
    # Return requirements indicator
    #
    $deque_axe_installed = $meets_requirements;
    return($meets_requirements);
}

#***********************************************************************
#
# Name: Print_Error
#
# Parameters: text - text from tag
#             error_string - error string
#
# Description:
#
#   This function prints error messages if debugging is enabled..
#
#***********************************************************************
sub Print_Error {
    my ( $text, $error_string ) = @_;

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
# Parameters: id - testcase id
#             help - help string for id
#             context - context from HTML markup
#             description - message description
#             help_url - URL for testcase help
#             impact - impact value
#             tags - tags value
#
# Description:
#
#   This function records the testcase result.
#
#***********************************************************************
sub Record_Result {
    my ($id, $help, $context, $description, $help_url, $impact, $tags) = @_;

    my ($result_object);

    #
    # Create result object and save details.
    # There is no line number of column number available.
    #
    $result_object = tqa_result_object->new("AXE", 1, "$id: $help",
                                            -1, -1, $context,
                                            $description, $current_url);
    push (@$results_list_addr, $result_object);

    #
    # Add help URL if it is not blank.
    #
    if ( $help_url ne "" ) {
        $result_object->help_url($help_url);
    }

    #
    # Add impact if it is not blank.
    #
    if ( $impact ne "" ) {
        $result_object->impact($impact);
    }

    #
    # Add tags if it is not blank.
    #
    if ( $tags ne "" ) {
        $result_object->tags($tags);
    }

    #
    # Print error string to stdout
    #
    Print_Error($context, "$id : $help");
}

#***********************************************************************
#
# Name: Deque_AXE_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             resp - HTTP::Response object
#             content - HTML content pointer
#
# Description:
#
#   This function runs the Deque Axe tool to check for accessibility errors.
#
#***********************************************************************
sub Deque_AXE_Check {
    my ($this_url, $language, $profile, $resp, $content) = @_;

    my ($sec, $min, $hour, $time, $cmd, $output);
    my (@tqa_results_list, @lines, $error, $eval_output);
    my ($ref, $ref_type, $array_item, $id, $description, $html, $tags);
    my ($help, $violations_array, $violations_item, $tags_array);
    my ($help_url, $nodes, $node, $impact);
    my ($error_found) = 0;

    #
    # Do we have a valid profile ?
    #
    print "Deque_AXE_Check Checking URL $this_url, lanugage = $language, profile = $profile\n" if $debug;
    if ( ! defined($tqa_check_profile_map{$profile}) ) {
        print "Deque_AXE_Check Unknown TQA testcase profile passed $profile\n";
        return(@tqa_results_list);
    }

    #
    # Set current hash tables
    #
    $current_tqa_check_profile = $tqa_check_profile_map{$profile};
    $results_list_addr = \@tqa_results_list;

    #
    # Are we doing Deque Axe checks (https://github.com/dequelabs/axe-core) ?
    #
    if ( ! defined($$current_tqa_check_profile{"AXE"}) ) {
        print "AXE testcase not in current profile\n" if $debug;
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
        # We can't run the axe tool on a block of HTML markup.
        #
        $current_url = "";
        return(@tqa_results_list);
    }
    
    #
    # Check to see if the required programs and files are
    # available (i.e. axe, Node, etc.).
    #
    if ( Check_Deque_Axe_Requirements() ) {
        #
        # Run the axe program to check this web page.
        # Set output to JSON format and select WCAG 2.0 A & AA checks.
        #
        # Command line details from
        #  https://medium.com/accessibility-a11y/using-axe-command-line-to-evaluate-a-web-page-for-accessibility-1cc4be4aacc9
        #
        # Do not limit analysis to WCAG tags (--tags wcag2a,wcag2aa)
        #
        ($sec, $min, $hour) = (localtime)[0,1,2];
        $time = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
        print "axe started at $time\n" if $debug;
        $cmd = "axe \"$this_url\" --stdout";
        print "$cmd\n" if $debug;
        $output = `$cmd`;
        ($sec, $min, $hour) = (localtime)[0,1,2];
        $time = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
        print "axe finished at $time\n" if $debug;
        print "axe output = $output\n" if $debug;
        
        #
        # Did we encounter a runtime error? This
        # can happen if headless chrome is not installed.
        #
        if ( $output =~ /^Error: /im ) {
            print "Error running axe: $output\n" if $debug;
            $error_found - 1;
            
            #
            # Record only 1 runtime error
            #
            $error_found = 1;
            if ( ! $axe_runtime_reported ) {
                Record_Result("AXE", "",
                              String_Value("Runtime Error") .
                              " \"$cmd\"\n" . " \"$output\"");

                #
                # Suppress further errors
                #
                $axe_runtime_reported = 1;
            }
        }
        #
        # Did we get any output? We expect a JSON string with a
        # "violations" field.
        #
        elsif ( $output =~ /"violations"/i ) {
            #
            # The output is a JSON array of tests. Decode the JSON
            #
            print "Found string violations in axe output, decode JSON\n" if $debug;
            $ref = decode_json($output);
            if ( ! eval { $ref = decode_json($output); 1 } ) {
                $eval_output = $@;
                $eval_output =~ s/ at \S* line \d*\.$//g;
                $error_found = 1;
                print "Decode of JSON failed $eval_output\n" if $debug;
                
                #
                # Record only 1 runtime error
                #
                if ( ! $axe_runtime_reported ) {
                    Record_Result("AXE", "",
                                  String_Value("Runtime Error") .
                                  " $eval_output");

                    #
                    # Suppress further errors
                    #
                    $axe_runtime_reported = 1;
                }
            }
            else {
                #
                # Is the top level an array?
                #
                $ref_type = ref $ref;
                print "Top level object is type $ref_type\n" if $debug;
                if ( $ref_type ne "ARRAY" ) {
                    print "Expected ARRAY type for top level, found $ref_type\n" if $debug;
                    $error_found = 1;
                    if ( ! $axe_runtime_reported ) {
                        Record_Result("AXE", "",
                                      String_Value("Runtime Error") .
                                      " Expected ARRAY type for top level of axe output, found $ref_type\n$output");
                        $axe_runtime_reported = 1;
                    }
                }
            }

            #
            # The first element in the array contains the
            # axe test results
            #
            if ( ! $error_found ) {
                $array_item = pop(@$ref);

                #
                # The item should be an object
                #
                $ref_type = ref $array_item;
                print "Array item is type $ref_type\n" if $debug;
                if ( $ref_type ne "HASH" ) {
                    print "Expected HASH type for top level array element, found $ref_type\n" if $debug;
                    $error_found = 1;
                    if ( ! $axe_runtime_reported ) {
                        Record_Result("AXE", "",
                                      String_Value("Runtime Error") .
                                      " Expected HASH type for top level array element of axe output, found $ref_type\n$output");
                        $axe_runtime_reported = 1;
                    }
                }
                #
                # Get the violations field
                #
                elsif ( ! defined($$array_item{"violations"}) ) {
                    #
                    # Missing violations field in axe output
                    #
                    print "Missing violations field in top level array element\n" if $debug;
                    $error_found = 1;
                    if ( ! $axe_runtime_reported ) {
                        Record_Result("AXE", "",
                                      String_Value("Runtime Error") .
                                      " Missing violations field in top level array element\n$output");
                        $axe_runtime_reported = 1;
                    }
                }
            }

            #
            # This should be an array of violation
            # objects
            #
            if ( ! $error_found ) {
                $violations_array = $$array_item{"violations"};
                $ref_type = ref $violations_array;
                print "Violations array is a $ref_type\n" if $debug;
                if ( $ref_type ne "ARRAY" ) {
                    #
                    # Invalid object type found
                    #
                    print "Violations field is not an array\n" if $debug;
                    $error_found = 1;
                    if ( ! $axe_runtime_reported ) {
                        Record_Result("AXE", "",
                                      String_Value("Runtime Error") .
                                      " Expected ARRAY type for violations of axe output, found $ref_type\n$output");
                        $axe_runtime_reported = 1;
                    }
                }
            }

            #
            # Loop through the array to get the list of violations
            #
            if ( ! $error_found ) {
                print "Check each item in the violations array, length = " .
                      scalar(@$violations_array) . "\n" if $debug;
                foreach $violations_item (@$violations_array) {
                    #
                    # Get the violation details e.g. id, help
                    # HTML fragment, tags, etc.
                    #
                    $ref_type = ref $violations_item;
                    if ( $ref_type eq "HASH" ) {
                        #
                        # Get testcase details
                        #
                        if ( defined($$violations_item{"id"}) ) {
                            $id = $$violations_item{"id"};
                            $id = "AXE-" . ucfirst($id);
                        }
                        else {
                            $id = "AXE-Unknown";
                        }
                        if ( defined($$violations_item{"help"}) ) {
                            $help = $$violations_item{"help"};
                        }
                        else {
                            $help = "";
                        }
                        if ( defined($$violations_item{"helpUrl"}) ) {
                            $help_url = $$violations_item{"helpUrl"};
                        }
                        else {
                            $help_url = "";
                        }
                        if ( defined($$violations_item{"impact"}) ) {
                            $impact = $$violations_item{"impact"};
                        }
                        else {
                            $impact = "";
                        }

                        #
                        # Get the tags array and make a string of all the values
                        #
                        if ( defined($$violations_item{"tags"}) ) {
                            $tags_array = $$violations_item{"tags"};
                            $ref_type = ref $tags_array;
                            if ( $ref_type eq "ARRAY" ) {
                                print "Found " . scalar(@$tags_array) . " tags\n" if $debug;
                                $tags = join(",", @$tags_array);
                            }
                            else {
                                print "No tags item is not an array\n" if $debug;
                                $tags = "";
                            }
                        }
                        else {
                            print "No tags item in violations object\n" if $debug;
                            $tags = "";
                        }
                        
                        #
                        # Get all occurances of this error from the nodes array
                        #
                        if ( defined($$violations_item{"nodes"}) ) {
                            $nodes = $$violations_item{"nodes"};
                            $ref_type = ref $nodes;
                            
                            #
                            # Is this an array?
                            #
                            if ( $ref_type eq "ARRAY" ) {
                                #
                                # Get each occurance from the array
                                #
                                print "Get each item in the nodes array, length = " .
                                      scalar(@$nodes) . "\n" if $debug;
                                foreach $node (@$nodes) {
                                    $ref_type = ref $node;
                                    if ( $ref_type eq "HASH" ) {
                                        #
                                        # Get instance specific details
                                        #
                                        if ( defined($$node{"html"}) ) {
                                            $html = $$node{"html"};
                                        }
                                        else {
                                            $html = "";
                                        }

                                        #
                                        # Record error
                                        #
                                        print "Record result, id = $id, description = $description\n" if $debug;
                                        Record_Result($id, $help, $html,
                                                      $description, $help_url,
                                                      $impact, $tags);
                                    }
                                }
                            }
                        }
                    }
                    #
                    # Invalid object type found
                    #
                    else {
                        print "Violations array item is not a hash\n" if $debug;
                        if ( ! $axe_runtime_reported ) {
                            Record_Result("AXE", "",
                                          String_Value("Runtime Error") .
                                          " Expected HASH type for violations item of axe output, found $ref_type\n$output");
                            $axe_runtime_reported = 1;
                        }
                    }
                }
            }
        }
        #
        # Output either empty or does not contain the violations field.
        #
        else {
            #
            # Record only 1 runtime error
            #
            print "No axe output or does not contain violations string\n" if $debug;
            if ( ! $axe_runtime_reported ) {
                Record_Result("AXE", "",
                              String_Value("Runtime Error") .
                              " Expected 'violations' field in axe command output, found\n$output");

                #
                # Suppress further errors
                #
                $axe_runtime_reported = 1;
            }
        }
    }
    #
    # Axe not available, cannot run checks.  Report error on
    # first occurance only.
    #
    elsif ( ! $axe_runtime_reported ) {
        print "Could not run axe checks\n" if $debug;
        Record_Result("AXE", "",
                      String_Value("Runtime Error") . " " .
                      String_Value("Deque Axe not installed"));

        #
        # Suppress further errors
        #
        $axe_runtime_reported = 1;
    }

    #
    # Return results
    #
    return(@tqa_results_list);
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
# Return true to indicate we loaded successfully
#
return 1;


