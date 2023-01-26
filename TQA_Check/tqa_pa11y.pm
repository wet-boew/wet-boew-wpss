#***********************************************************************
#
# Name:   tqa_pa11y.pm
#
# $Revision: 2440 $
# $URL: svn://10.36.148.185/WPSS_Tool/TQA_Check/Tools/tqa_pa11y.pm $
# $Date: 2022-12-15 10:33:02 -0500 (Thu, 15 Dec 2022) $
#
# Description:
#
#   This file contains routines to run the Pa11y accessibility test tool.
#
# Public functions:
#     Pa11y_Check_Config
#     Pa11y_Check_Debug
#     Set_Pa11y_Check_Language
#     Set_Pa11y_Check_Testcase_Data
#     Set_Pa11y_Check_Test_Profile
#     Pa11y_Check
#     Pa11y_Version
#
# Terms and Conditions of Use
#
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is
# distributed under the MIT License.
#
# MIT License
#
# Copyright (c) 2019 Government of Canada
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

package tqa_pa11y;

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
    @EXPORT  = qw(Pa11y_Check_Config
                  Pa11y_Check_Debug
                  Set_Pa11y_Check_Language
                  Set_Pa11y_Check_Testcase_Data
                  Set_Pa11y_Check_Test_Profile
                  Pa11y_Check
                  Pa11y_Version
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths, $userprofile);
my (%tqa_check_profile_map, $current_tqa_check_profile);
my ($current_url, $results_list_addr, %testcase_data);
my ($debug) = 0;
my ($pa11y_runtime_reported) = 0;

my ($pa11y_installed, $pa11y_version, $pa11y_install_error);
if ( $have_threads ) {
    share(\$pa11y_installed);
    share(\$pa11y_version);
    share(\$pa11y_install_error);
}


#
# String table for error strings.
#
my %string_table_en = (
    "Pa11y not installed",           "Pa11y not installed",
    "Runtime Error",                 "Runtime Error",
);

my %string_table_fr = (
    "Pa11y not installed",           "Pa11y pas installé",
    "Runtime Error",                 "Erreur D'Exécution",
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#********************************************************
#
# Name: Pa11y_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Pa11y_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: Pa11y_Check_Config
#
# Parameters: config_vars
#
# Description:
#
#   This function sets a number of package configuration values.
# The values are passed in as a hash table.
#
#***********************************************************************
sub Pa11y_Check_Config {
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
# Name: Set_Pa11y_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Pa11y_Check_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_Pa11y_Check_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_Pa11y_Check_Language, language = English\n" if $debug;
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
# Name: Set_Pa11y_Check_Testcase_Data
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
sub Set_Pa11y_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_Pa11y_Check_Test_Profile
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
sub Set_Pa11y_Check_Test_Profile {
    my ($profile, $tqa_checks ) = @_;

    my (%local_tqa_checks);
    my ($key, $value);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Pa11y_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_tqa_checks = %$tqa_checks;
    $tqa_check_profile_map{$profile} = \%local_tqa_checks;
}

#***********************************************************************
#
# Name: Check_Pa11y_Requirements
#
# Parameters: none
#
# Description:
#
#   This function checks to see if all the system requirements are
# available to run Pa11y.  The requirements are:
#    - Node runtime environment
#    - Pa11y module installed in Node
#
# Returns:
#   1 - requirements met
#   0 - requirements not met
#
#***********************************************************************
sub Check_Pa11y_Requirements {
    my ($file_path, $version);
    my ($meets_requirements) = 1;

    #
    # Have we already checked that Pa11y requirements are available
    #
    print "Check_Pa11y_Requirements\n" if $debug;
    if ( defined($pa11y_installed) ) {
        return($pa11y_installed);
    }

    #
    # Check for requirements
    #
    if ( $^O =~ /MSWin32/ ) {
        #
        # Windows.
        #
        # Get path to Pa11y
        #
        print "Check for pa11y program\n" if $debug;
        $file_path = `where pa11y 2>&1`;
        if ( $file_path =~ /Could not find/i ) {
            print "Pa11y not in path\n" if $debug;
            print STDERR "Pa11y not installed, Pa11y not available\n";
            $meets_requirements = 0;
            $pa11y_install_error = "Pa11y not installed, Pa11y not available";
        }
        else {
            #
            # Get pa11y version
            #
            $version = `pa11y --version 2>&1`;
            chomp($version);
            $pa11y_version = $version;
            print "Pa11y $version found\n" if $debug;
        }
    }
    else {
        #
        # Not Windows.
        #
        # Get path to Pa11y
        #
        print "Check for pa11y program\n" if $debug;
        $file_path = `which pa11y 2>&1`;
        if ( $file_path =~ /no pa11y/i ) {
            print "Pa11y not in path\n" if $debug;
            print STDERR "Pa11y not installed, Pa11y not available\n";
            $pa11y_install_error = "Pa11y not installed, Pa11y not available";
            $meets_requirements = 0;
        }
        else {
            print "Pa11y found at $file_path\n" if $debug;
        }
    }

    #
    # Return requirements indicator
    #
    $pa11y_installed = $meets_requirements;
    return($meets_requirements);
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
# Parameters: code - testcase code
#             context - context from HTML markup
#             message - error string
#
# Description:
#
#   This function records the testcase result.
#
#***********************************************************************
sub Record_Result {
    my ($code, $context, $message) = @_;

    my ($result_object);


    #
    # Create result object and save details.
    # There is no line number of column number available.
    #
    $result_object = tqa_result_object->new("Pa11y", 1, $code,
                                            -1, -1, $context,
                                            $message, $current_url);
    push (@$results_list_addr, $result_object);

    #
    # Print error string to stdout
    #
    Print_Error($context, "$code : $message");
    return($result_object);
}

#***********************************************************************
#
# Name: Pa11y_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             resp - HTTP::Response object
#             content - HTML content pointer
#
# Description:
#
#   This function runs the Pa11y tool to check for accessibility errors.
#
#***********************************************************************
sub Pa11y_Check {
    my ($this_url, $language, $profile, $resp, $content) = @_;

    my ($sec, $min, $hour, $time, $cmd, $output, $result_object);
    my (@tqa_results_list, @lines, $error, $eval_output);
    my ($ref, $ref_type, $array_item, $code, $context, $message);

    #
    # Do we have a valid profile ?
    #
    print "Pa11y_Check Checking URL $this_url, lanugage = $language, profile = $profile\n" if $debug;
    if ( ! defined($tqa_check_profile_map{$profile}) ) {
        print "Pa11y_Check Unknown TQA testcase profile passed $profile\n";
        return(@tqa_results_list);
    }

    #
    # Set current hash tables
    #
    $current_tqa_check_profile = $tqa_check_profile_map{$profile};
    $results_list_addr = \@tqa_results_list;

    #
    # Are we doing Pa11y checks (https://github.com/pa11y/pa11y) ?
    #
    if ( ! defined($$current_tqa_check_profile{"Pa11y"}) ) {
        print "Pa11y testcase not in current profile\n" if $debug;
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
        # We can't run the pa11y tool on a block of HTML markup.
        #
        $current_url = "";
        return(@tqa_results_list);
    }
    
    #
    # Check to see if the required programs and files are
    # available (i.e. pa11y, Node, etc.).
    #
    if ( Check_Pa11y_Requirements() ) {
        #
        # Run the Pa11y program to check this web page.
        # Set output to JSON format and select WCAG 2.0 AA checks.
        #
        ($sec, $min, $hour) = (localtime)[0,1,2];
        $time = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
        print "pa11y started at $time\n" if $debug;
        $cmd = "pa11y -r json -s WCAG2AA $this_url 2>&1";
        print "$cmd\n" if $debug;
        $output = `$cmd`;
        ($sec, $min, $hour) = (localtime)[0,1,2];
        $time = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
        print "pa11y finished at $time\n" if $debug;
        print "Pa11y output = $output\n" if $debug;
        
        #
        # If we got no output, there were no errors detected
        #
        if ( $output eq "" ) {
            print "No errors reported by pa11y\n" if $debug;
        }
        #
        # Did we encounter an error?
        #
        elsif ( $output =~ /^Error: /i ) {
            #
            # First line of output should contain the error.  The rest of
            # the lines are the execution traceback.
            #
            @lines = split(/\n/, $output);
            $error = $lines[0];
            print "Error running pa11y: $error\n" if $debug;
            
            #
            # Record only 1 runtime error
            #
            if ( ! $pa11y_runtime_reported ) {
                print STDERR "Pa11ly runtime error\n";
                print STDERR "$cmd\n";
                print STDERR "$output\n";
                $result_object = Record_Result("Pa11y", "",
                                               String_Value("Runtime Error") .
                                               " \"$cmd\"\n" . " \"$output\"");

                #
                # Reset the source line value of the testcase error result.
                # The initial setting may have been truncated while in this
                # case we want the entire value.
                #
                $result_object->source_line(String_Value("Runtime Error") .
                                            " \"$cmd\"\n" . " \"$output\"");

                #
                # Suppress further errors
                #
                $pa11y_runtime_reported = 1;
            }
        }
        #
        # Errors reported by pa11y
        #
        else {
            #
            # The output is a JSON array of errors. Decode the JSON
            #
            if ( ! eval { $ref = decode_json($output); 1 } ) {
                $eval_output = $@;
                $eval_output =~ s/ at \S* line \d*\.$//g;
                
                #
                # Record only 1 runtime error
                #
                if ( ! $pa11y_runtime_reported ) {
                    Record_Result("Pa11y", "",
                                  String_Value("Runtime Error") .
                                  " $eval_output");

                    #
                    # Suppress further errors
                    #
                    $pa11y_runtime_reported = 1;
                }
            }
            else {
                #
                # Is the top level an array?
                #
                $ref_type = ref $ref;
                if ( $ref_type eq "ARRAY" ) {
                    #
                    # Each array item is a hash table of the details
                    #
                    foreach $array_item (@$ref) {
                        $ref_type = ref $array_item;
                        if ( $ref_type eq "HASH" ) {
                            if ( defined($$array_item{"code"}) &&
                                 defined($$array_item{"context"}) &&
                                 defined($$array_item{"message"}) ) {
                                #
                                # Record error
                                #
                                $code = $$array_item{"code"};
                                $context = $$array_item{"context"};
                                $message = $$array_item{"message"};
                                Record_Result($code, $context, $message);
                            }
                            else {
                                #
                                # Hash table is missing some fields
                                #
                                print "Missing hash table fields\n" if $debug;
                                if ( ! $pa11y_runtime_reported ) {
                                    Record_Result("Pa11y", "",
                                                  String_Value("Runtime Error") .
                                                  " Expected ARRAY type for top level of Pa11y output, found $ref_type");

                                    #
                                    # Suppress further errors
                                    #
                                    $pa11y_runtime_reported = 1;
                                }
                            }
                        }
                    }
                }
                else {
                    print "Expected ARRAY type for top level, found $ref_type\n" if $debug;
                    if ( ! $pa11y_runtime_reported ) {
                        Record_Result("Pa11y", "",
                                      String_Value("Runtime Error") .
                                      " Expected ARRAY type for top level of Pa11y output, found $ref_type");

                        #
                        # Suppress further errors
                        #
                        $pa11y_runtime_reported = 1;
                    }
                }
            }
        }
    }
    #
    # Pa11y not available, cannot run checks.  Report error on
    # first occurance only.
    #
    elsif ( ! $pa11y_runtime_reported ) {
        print "Could not run pa11y checks\n" if $debug;
        Record_Result("Pa11y", "",
                      String_Value("Runtime Error") . " " .
                      String_Value("Pa11y not installed") .
                      " $pa11y_install_error");

        #
        # Suppress further errors
        #
        $pa11y_runtime_reported = 1;
    }

    #
    # Return results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Pa11y_Version
#
# Parameters: none
#
# Description:
#
#   This function returns the version of the Pa11y software.
#
#***********************************************************************
sub Pa11y_Version {
    #
    # Do we have version string?
    #
    print "Pa11y_Version\n" if $debug;
    Check_Pa11y_Requirements();
    if ( defined($pa11y_version) && ($pa11y_version ne "") ) {
        return($pa11y_version);
    }
    elsif ( defined($pa11y_install_error) && ($pa11y_install_error ne "") ) {
        return($pa11y_install_error);
    }
    else {
        return("");
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
# Make sure npm modules are in the path
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $paths = $ENV{"PATH"};
    $userprofile = $ENV{"USERPROFILE"};
    $paths .= ";$userprofile/AppData/Roaming/npm";
    $ENV{"PATH"} = $paths;
}

#
# Return true to indicate we loaded successfully
#
return 1;


