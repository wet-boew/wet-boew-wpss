#***********************************************************************
#
# Name:   clf_check.pm
#
# $Revision: 142 $
# $URL: svn://10.36.20.203/CLF_Check/Tools/clf_check.pm $
# $Date: 2016-12-07 13:05:31 -0500 (Wed, 07 Dec 2016) $
#
# Description:
#
#   This file contains routines that parse HTML files and check for
# a number of Common Look and Feel check points.
#
# Public functions:
#     Set_CLF_Check_Language
#     Set_CLF_Check_Debug
#     CLF_Check_Set_Archive_Markers
#     Set_CLF_Check_Testcase_Data
#     Set_CLF_Check_Test_Profile
#     CLF_Check_Read_URL_Help_File
#     CLF_Check
#     CLF_Check_Links
#     CLF_Check_Testcase_URL
#     CLF_Check_Other_Tool_Results
#     CLF_Check_Is_Archived
#     CLF_Check_Archive_Check
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

package clf_check;

use strict;
use HTML::Entities;
use URI::URL;
use File::Basename;

#
# Use WPSS_Tool program modules
#
use clf_archive;
use clf20_check;
use swu_check;
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
    @EXPORT  = qw(Set_CLF_Check_Language
                  Set_CLF_Check_Debug
                  CLF_Check_Set_Archive_Markers
                  Set_CLF_Check_Testcase_Data
                  Set_CLF_Check_Test_Profile
                  CLF_Check_Read_URL_Help_File
                  CLF_Check
                  CLF_Check_Links
                  CLF_Check_Testcase_URL
                  CLF_Check_Other_Tool_Results
                  CLF_Check_Is_Archived
                  CLF_Check_Archive_Check
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
# Name: Set_CLF_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_CLF_Check_Debug {
    my ($this_debug) = @_;

    #
    # Set other debug flags
    #
    URL_Check_Debug($this_debug);
    CLF_Archive_Debug($this_debug);
    Set_CLF20_Check_Debug($this_debug);
    Set_SWU_Check_Debug($this_debug);

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: CLF_Check_Set_Archive_Markers
#
# Parameters: profile - profile name
#             marker_type - archive marker type
#             data - string of data
#
# Description:
#
#   This function passes archive marker settings to the CLF_Archive
# module.
#
#***********************************************************************
sub CLF_Check_Set_Archive_Markers {
    my ($profile, $marker_type, $data) = @_;

    #
    # Set archive markers in archive module
    #
    CLF_Archive_Set_Archive_Markers($profile, $marker_type, $data);
}

#**********************************************************************
#
# Name: Set_CLF_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_CLF_Check_Language {
    my ($language) = @_;

    #
    # Set language in other modules
    #
    Set_URL_Check_Language($language);
    Set_CLF20_Check_Language($language);
    Set_SWU_Check_Language($language);
    Set_Archive_Check_Language($language);
}

#**********************************************************************
#
# Name: CLF_Check_Read_URL_Help_File
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
sub CLF_Check_Read_URL_Help_File {
    my ($filename) = @_;
    
    #
    # Read in CLF 2.0 URL help
    #
    CLF20_Check_Read_URL_Help_File($filename);
    
    #
    # Read in Standard on Web Usability URL help
    #
    SWU_Check_Read_URL_Help_File($filename);
}

#**********************************************************************
#
# Name: CLF_Check_Testcase_URL
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase URL
# table for the specified key.
#
#**********************************************************************
sub CLF_Check_Testcase_URL {
    my ($key) = @_;
    
    my ($help_url);

    #
    # Get CLF 2.0 URL information
    #
    $help_url = CLF20_Check_Testcase_URL($key);
    
    #
    # Get Standard on Web Usability URL information
    #
    if ( ! defined($help_url) ) {
        $help_url = SWU_Check_Testcase_URL($key);
    }

    #
    # Return URL value
    #
    return($help_url);
}

#***********************************************************************
#
# Name: CLF_Check_Other_Tool_Results
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
sub CLF_Check_Other_Tool_Results {
    my (%tool_results) = @_;

    #
    # Set CLF 2.0 other tool results
    #
    CLF20_Check_Other_Tool_Results(%tool_results);
}

#***********************************************************************
#
# Name: Set_CLF_Check_Testcase_Data
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
sub Set_CLF_Check_Testcase_Data {
    my ($profile, $testcase, $data) = @_;

    #
    # Set other module testcase data
    #
    Set_URL_Check_Testcase_Data($testcase, $data);
    Set_CLF20_Check_Testcase_Data($testcase, $data);
    Set_SWU_Check_Testcase_Data($profile, $testcase, $data);
}

#***********************************************************************
#
# Name: Set_CLF_Check_Test_Profile
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
sub Set_CLF_Check_Test_Profile {
    my ($profile, $clf_checks ) = @_;

    #
    # Set test case profile information in other modules
    #
    Set_URL_Check_Test_Profile($profile, $clf_checks);
    Set_CLF20_Check_Test_Profile($profile, $clf_checks);
    Set_SWU_Check_Test_Profile($profile, $clf_checks);
}

#***********************************************************************
#
# Name: CLF_Check
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
sub CLF_Check {
    my ( $this_url, $language, $profile, $mime_type, $resp, $content ) = @_;

    my (@tqa_results_list, $result_object, @other_tqa_results_list, $tcid);

    #
    # Did we get any content ?
    #
    print "CLF_Check: URL $this_url, mime-type = $mime_type, lanugage = $language, profile = $profile\n" if $debug;
    if ( length($$content) > 0 ) {
        #
        # Perform CLF 2.0 checks.
        #
        @tqa_results_list = CLF20_Check($this_url, $language, $profile,
                                        $mime_type, $resp, $content);
                                        
        #
        # Perform Standard on Web Usability checks.
        #
        @other_tqa_results_list = SWU_Check($this_url, $language, $profile,
                                        $mime_type, $resp, $content);

        #
        # Add results from Standard on Web Usability Results check into those
        # from the CLF2.0 check to get results for the entire document.
        #
        foreach $result_object (@other_tqa_results_list) {
            push(@tqa_results_list, $result_object);
        }
    }
    else {
        print "No content passed to CLF_Check\n" if $debug;
    }

    #
    # Perform checks on the URL
    #
    @other_tqa_results_list = URL_Check($this_url, $profile);

    #
    # Add results from URL check into those from the previous check
    # to get resuilts for the entire document.
    #
    foreach $result_object (@other_tqa_results_list) {
        push(@tqa_results_list, $result_object);
    }

    #
    # Add help URL to result
    #
    foreach $result_object (@tqa_results_list) {
        $tcid = $result_object->testcase();
        if ( defined(CLF_Check_Testcase_URL($tcid)) ) {
            $result_object->help_url(CLF_Check_Testcase_URL($tcid));
        }
    }
    
    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: CLF_Check_Links
#
# Parameters: tqa_results_list - address of hash table results
#             url - URL
#             profile - testcase profile
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#             site_links - hash table of site links
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
sub CLF_Check_Links {
    my ($tqa_results_list, $url, $profile, $language, $link_sets,
        $site_links, $logged_in) = @_;

    my ($result_object, $tcid);

    #
    # Perform CLF 2.0 link checks.
    #
    print "CLF_Check_Links: profile = $profile, language = $language\n" if $debug;
    CLF20_Check_Links($tqa_results_list, $url, $profile, $language, $link_sets);
    
    #
    # Perform Standard on Web Usability link checks.
    #
    SWU_Check_Links($tqa_results_list, $url, $profile, $language, $link_sets,
                    $site_links, $logged_in);

    #
    # Add help URL to result
    #
    foreach $result_object (@$tqa_results_list) {
        $tcid = $result_object->testcase();
        if ( defined(CLF_Check_Testcase_URL($tcid)) ) {
            $result_object->help_url(CLF_Check_Testcase_URL($tcid));
        }
    }
}

#***********************************************************************
#
# Name: CLF_Check_Is_Archived
#
# Parameters: profile - profile name
#             url - URL
#             content - content pointer
#
# Description:
#
#    This function checks the content contains any "Archived on the web"
# markers.
#
#***********************************************************************
sub CLF_Check_Is_Archived {
    my ($profile, $url, $content) = @_;

    #
    # Return archived flag
    #
    print "CLF_Check_Is_Archived\n" if $debug;
    return(CLF_Archive_Is_Archived($profile, $url, $content));
}

#**********************************************************************
#
# Name: CLF_Check_Archive_Check
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
# is marked as Archived on the Web.
#
#**********************************************************************
sub CLF_Check_Archive_Check {
    my ($this_url, $language, $profile, $mime_type, $resp, $content) = @_;

    my (@tqa_results_list, $result_object, @other_tqa_results_list);
    
    #
    # Did we get any content ?
    #
    print "CLF_Check_Archive_Check URL $this_url, mime-type = $mime_type, lanugage = $language, profile = $profile\n" if $debug;
    if ( length($$content) > 0 ) {
        #
        # Perform CLF 2.0 archived checks.
        #
        @tqa_results_list = CLF20_Check_Archive_Check($this_url, $language,
                                                      $profile, $mime_type,
                                                      $resp, $content);

        #
        # Perform Standard on Web Usability archived checks.
        #
        @other_tqa_results_list = SWU_Check_Archive_Check($this_url, $language,
                                                          $profile, $mime_type,
                                                          $resp, $content);

        #
        # Add results from Standard on Web Usability Results check into those
        # from the CLF2.0 check to get results for the entire document.
        #
        foreach $result_object (@other_tqa_results_list) {
            push(@tqa_results_list, $result_object);
        }
    }
    else {
        print "No content passed to CLF_Check_Archive_Check\n" if $debug;
    }

    #
    # Return list of results
    #
    return(@tqa_results_list);
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

