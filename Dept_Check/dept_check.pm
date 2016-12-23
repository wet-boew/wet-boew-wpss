#***********************************************************************
#
# Name:   dept_check.pm
#
# $Revision: 7486 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Dept_Check/Tools/dept_check.pm $
# $Date: 2016-02-08 08:38:14 -0500 (Mon, 08 Feb 2016) $
#
# Description:
#
#   This file contains routines that parse HTML files and check for
# a number of departmental checkpoints.
#
# Public functions:
#     Set_Dept_Check_Language
#     Set_Dept_Check_Debug
#     Set_Dept_Check_Testcase_Data
#     Set_Dept_Check_Test_Profile
#     Dept_Check_Read_URL_Help_File
#     Dept_Check
#     Dept_Check_Links
#     Dept_Check_Testcase_URL
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

package dept_check;

use strict;
use HTML::Entities;
use URI::URL;
use File::Basename;

#
# Use WPSS_Tool program modules
#
use content_check;
use tp_pw_check;
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
    @EXPORT  = qw(Set_Dept_Check_Language
                  Set_Dept_Check_Debug
                  Set_Dept_Check_Testcase_Data
                  Set_Dept_Check_Test_Profile
                  Dept_Check_Read_URL_Help_File
                  Dept_Check
                  Dept_Check_Links
                  Dept_Check_Testcase_URL
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;

#***********************************************************************
#
# Name: Set_Dept_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Dept_Check_Debug {
    my ($this_debug) = @_;

    #
    # Set other debug flags
    #
    URL_Check_Debug($this_debug);
    Set_TP_PW_Check_Debug($this_debug);

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_Dept_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Dept_Check_Language {
    my ($language) = @_;

    #
    # Set language in other modules
    #
    Set_URL_Check_Language($language);
    Set_TP_PW_Check_Language($language);
    Set_Content_Check_Language($language);
}

#**********************************************************************
#
# Name: Dept_Check_Read_URL_Help_File
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
sub Dept_Check_Read_URL_Help_File {
    my ($filename) = @_;

    #
    # Read in PWGSC checks URL help
    #
    TP_PW_Check_Read_URL_Help_File($filename);

    #
    # Read in content checks URL help
    #
    Content_Check_Read_URL_Help_File($filename);

}

#**********************************************************************
#
# Name: Dept_Check_Testcase_URL
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase URL
# table for the specified key.
#
#**********************************************************************
sub Dept_Check_Testcase_URL {
    my ($key) = @_;
    
    my ($help_url);

    #
    # Get PWGSC check URL information
    #
    $help_url = TP_PW_Check_Testcase_URL($key);

    #
    # Check for content check URL information
    #
    if ( ! defined($help_url) ) {
        $help_url = Content_Check_Testcase_URL($key);
    }
    
    #
    # Return URL value
    #
    return($help_url);
}

#***********************************************************************
#
# Name: Set_Dept_Check_Testcase_Data
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
sub Set_Dept_Check_Testcase_Data {
    my ($profile, $testcase, $data) = @_;

    #
    # Set other module testcase data
    #
    Set_URL_Check_Testcase_Data($testcase, $data);
    Set_TP_PW_Check_Testcase_Data($profile, $testcase, $data);
}

#***********************************************************************
#
# Name: Set_Dept_Check_Test_Profile
#
# Parameters: profile - TQA check test profile
#             dept_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by TQA testcase name.
#
#***********************************************************************
sub Set_Dept_Check_Test_Profile {
    my ($profile, $dept_checks ) = @_;

    #
    # Set test case profile information in other modules
    #
    Set_URL_Check_Test_Profile($profile, $dept_checks);
    Set_TP_PW_Check_Test_Profile($profile, $dept_checks);
    Set_Content_Check_Test_Profile($profile, $dept_checks);
}

#***********************************************************************
#
# Name: Dept_Check
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
sub Dept_Check {
    my ($this_url, $language, $profile, $mime_type, $resp, $content) = @_;

    my (@tqa_results_list, $result_object, @other_tqa_results_list, $tcid);

    #
    # Did we get any content ?
    #
    print "Dept_Check: URL $this_url, mime-type = $mime_type, lanugage = $language, profile = $profile\n" if $debug;
    if ( ($mime_type =~ /text\/html/) && (length($$content) > 0) ) {
        #
        # Perform PWGSC checks.
        #
        @tqa_results_list = TP_PW_Check($this_url, $language, $profile,
                                        $mime_type, $resp, $content);

        #
        # Perform content checks the document
        #
        print "Perform_Content_Check on URL\n  --> $this_url\n" if $debug;
        @other_tqa_results_list = Content_Check($this_url, $profile,
                                                $mime_type, $content);

        #
        # Add results from content check into those from PWGSC to get
        # results for the entire document.
        #
        foreach $result_object (@other_tqa_results_list) {
            push(@tqa_results_list, $result_object);
        }

    }
    else {
        print "No HTML content passed to Dept_Check\n" if $debug;
    }

    #
    # Content specific additional checks
    #
    if ( ($mime_type =~ /application\/x\-javascript/) ||
         ($mime_type =~ /text\/javascript/) ||
         ($this_url =~ /\.js$/i) ) {
    }
    elsif ( $mime_type =~ /text\/css/ ) {
    }
    else {
        #
        # Perform checks on the URL
        #
        @other_tqa_results_list = URL_Check($this_url, $profile);

        #
        # Add results from URL check into those from the previous check
        # to get results for the entire document.
        #
        foreach $result_object (@other_tqa_results_list) {
            push(@tqa_results_list, $result_object);
        }
    }

    #
    # Add help URL to result
    #
    foreach $result_object (@tqa_results_list) {
        $tcid = $result_object->testcase();
        if ( defined(Dept_Check_Testcase_URL($tcid)) ) {
            $result_object->help_url(Dept_Check_Testcase_URL($tcid));
        }
    }

    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Dept_Check_Links
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
# document.  Checks are performed on the common menu bar, left
# navigation and footer.
#
#***********************************************************************
sub Dept_Check_Links {
    my ($tqa_results_list, $url, $profile, $language, $link_sets,
        $logged_in) = @_;
        
    my ($tcid, $result_object);

    #
    # Perform PWGSC link checks.
    #
    print "Dept_Check_Links: profile = $profile, language = $language\n" if $debug;
    TP_PW_Check_Links($tqa_results_list, $url, $profile, $language,
                      $link_sets, $logged_in);
                      
    #
    # Add help URL to result
    #
    foreach $result_object (@$tqa_results_list) {
        $tcid = $result_object->testcase();
        if ( defined(Dept_Check_Testcase_URL($tcid)) ) {
            $result_object->help_url(Dept_Check_Testcase_URL($tcid));
        }
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

