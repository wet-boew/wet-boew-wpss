#***********************************************************************
#
# Name:   interop_check.pm
#
# $Revision: 6499 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Interop_Check/Tools/interop_check.pm $
# $Date: 2013-12-05 14:56:01 -0500 (Thu, 05 Dec 2013) $
#
# Description:
#
#   This file contains routines that check Web documents for a number
# of Interoperability check points.
#
# Public functions:
#     Set_Interop_Check_Language
#     Set_Interop_Check_Debug
#     Set_Interop_Check_Testcase_Data
#     Set_Interop_Check_Test_Profile
#     Interop_Check_Read_URL_Help_File
#     Interop_Check
#     Interop_Check_Testcase_URL
#     Interop_Check_Feed_Details
#     Interop_Check_Feeds
#     Interop_Check_Links
#     Interop_Check_Has_HTML_Data
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

package interop_check;

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
    @EXPORT  = qw(Set_Interop_Check_Language
                  Set_Interop_Check_Debug
                  Set_Interop_Check_Testcase_Data
                  Set_Interop_Check_Test_Profile
                  Interop_Check_Read_URL_Help_File
                  Interop_Check
                  Interop_Check_Testcase_URL
                  Interop_Check_Feed_Details
                  Interop_Check_Feeds
                  Interop_Check_Links
                  Interop_Check_Has_HTML_Data
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

#***********************************************************************
#
# Name: Set_Interop_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Interop_Check_Debug {
    my ($this_debug) = @_;

    #
    # Set other debug flags
    #
    Set_Interop_HTML_Check_Debug($this_debug);
    Set_Interop_XML_Check_Debug($this_debug);
    Interop_Testcase_Debug($this_debug);

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_Interop_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Interop_Check_Language {
    my ($language) = @_;

    #
    # Set language in other modules
    #
    Set_Interop_HTML_Check_Language($language);
    Set_Interop_XML_Check_Language($language);
}

#**********************************************************************
#
# Name: Interop_Check_Read_URL_Help_File
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
sub Interop_Check_Read_URL_Help_File {
    my ($filename) = @_;
    
    #
    # Read in Interoperability checks URL help
    #
    Interop_Testcase_Read_URL_Help_File($filename);
}

#**********************************************************************
#
# Name: Interop_Check_Testcase_URL
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase URL
# table for the specified key.
#
#**********************************************************************
sub Interop_Check_Testcase_URL {
    my ($key) = @_;
    
    my ($help_url);

    #
    # Get URL information
    #
    $help_url = Interop_Testcase_URL($key);
    
    #
    # Return URL value
    #
    return($help_url);
}

#***********************************************************************
#
# Name: Set_Interop_Check_Testcase_Data
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
sub Set_Interop_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Set other module testcase data
    #
    Set_Interop_HTML_Check_Testcase_Data($testcase, $data);
    Set_Interop_XML_Check_Testcase_Data($testcase, $data);
}

#***********************************************************************
#
# Name: Set_Interop_Check_Test_Profile
#
# Parameters: profile - TQA check test profile
#             checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by testcase name.
#
#***********************************************************************
sub Set_Interop_Check_Test_Profile {
    my ($profile, $checks ) = @_;

    #
    # Set test case profile information in other modules
    #
    Set_Interop_HTML_Check_Test_Profile($profile, $checks);
    Set_Interop_XML_Check_Test_Profile($profile, $checks);
}

#***********************************************************************
#
# Name: Interop_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             mime_type - mime type of content
#             resp - HTTP::Response object
#             content - content
#
# Description:
#
#   This function runs a number of technical QA checks the content.
#
#***********************************************************************
sub Interop_Check {
    my ( $this_url, $language, $profile, $mime_type, $resp, $content ) = @_;

    my (@tqa_results_list);

    #
    # Did we get any content ?
    #
    print "Interop_Check: URL $this_url, mime-type = $mime_type, lanugage = $language, profile = $profile\n" if $debug;
    if ( length($content) > 0 ) {
        #
        # Is this HTML content
        #
        if ( $mime_type =~ /text\/html/ ) {
            @tqa_results_list = Interop_HTML_Check($this_url, $language,
                                                   $profile, $mime_type, $resp,
                                                   $content);
        }
        #
        # Is this XML content
        #
        elsif ( ($mime_type =~ /application\/xhtml\+xml/) ||
                ($mime_type =~ /application\/atom\+xml/) ||
                ($mime_type =~ /application\/xml/) ||
                ($mime_type =~ /application\/rss\+xml/) ||
                ($mime_type =~ /text\/xml/) ||
                ($this_url =~ /\.xml$/i) ) {
            @tqa_results_list = Interop_XML_Check($this_url, $language,
                                                  $profile, $mime_type, $resp,
                                                  $content);
        }
    }
    else {
        print "No content passed to Interop_Check\n" if $debug;
    }

    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Interop_Check_Feed_Details
#
# Parameters: this_url - a URL
#             content - content
#
# Description:
#
#   This function returns a news feed object containing a number
# of feed details (e.g. type, title).  If the content is not a
# valid news feed, undefined is returned.
#
#***********************************************************************
sub Interop_Check_Feed_Details {
    my ($this_url, $content) = @_;

    my ($feed_object);

    $feed_object = Interop_XML_Feed_Details($this_url, $content);
    return($feed_object);
}

#***********************************************************************
#
# Name: Interop_Check_Feeds
#
# Parameters: profile - testcase profile
#             feed_list - list of feed objects
#
# Description:
#
#    This function checks a list of feed objects to see if there are
# any non Atom feeds that don't have a matching Atom feed (e.g. an
# RSS only feed).
#
#***********************************************************************
sub Interop_Check_Feeds {
    my ($profile, @feed_list) = @_;

    return(Interop_XML_Check_Feeds($profile, @feed_list));
}

#***********************************************************************
#
# Name: Interop_Check_Links
#
# Parameters: results_list - address of hash table results
#             url - URL
#             title - document title
#             mime_type - mime type of content
#             profile - testcase profile
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function performs a number of checks on links found within a
# document.
#
#***********************************************************************
sub Interop_Check_Links {
    my ($results_list, $url, $title, $mime_type, $profile, $language,
        $link_sets) = @_;

    #
    # Perform HTML link checks.
    #
    print "Interop_Check_Links: profile = $profile, language = $language\n" if $debug;
    if ( $mime_type =~ /text\/html/ ) {
        Interop_HTML_Check_Links($results_list, $url, $title, $profile,
                                 $language, $link_sets);
    }
}

#***********************************************************************
#
# Name: Interop_Check_Has_HTML_Data
#
# Parameters: url - URL
#
# Description:
#
#    This function returns whether or not the last URL analysed
# contained HTML data mark-up.
#
#***********************************************************************
sub Interop_Check_Has_HTML_Data {
    my ($url) = @_;

    #
    # Get HTML data flag from last HTML document analysed
    #
    return(Interop_HTML_Check_Has_HTML_Data($url));
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
    my (@package_list) = ("tqa_result_object", "interop_html_check",
                          "interop_xml_check", "interop_testcases");

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

