#***********************************************************************
#
# Name:   mobile_check.pm
#
# $Revision: 6715 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Mobile_Check/Tools/mobile_check.pm $
# $Date: 2014-07-22 12:23:44 -0400 (Tue, 22 Jul 2014) $
#
# Description:
#
#   This file contains routines that parse HTML files and check for
# a number of mobile optimization checkpoints.
#
# Public functions:
#     Set_Mobile_Check_Language
#     Set_Mobile_Check_Debug
#     Set_Mobile_Check_Testcase_Data
#     Set_Mobile_Check_Test_Profile
#     Mobile_Check_Read_URL_Help_File
#     Mobile_Check
#     Mobile_Check_Links
#     Mobile_Check_Testcase_URL
#     Mobile_Check_Compute_Page_Size
#     Mobile_Check_Save_Web_Page_Size
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

package mobile_check;

use strict;
use File::Basename;
use File::Temp qw/ tempfile tempdir /;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Set_Mobile_Check_Language
                  Set_Mobile_Check_Debug
                  Set_Mobile_Check_Testcase_Data
                  Set_Mobile_Check_Test_Profile
                  Mobile_Check_Read_URL_Help_File
                  Mobile_Check
                  Mobile_Check_Links
                  Mobile_Check_Testcase_URL
                  Mobile_Check_Compute_Page_Size
                  Mobile_Check_Save_Web_Page_Size
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

my (%testcase_data, %mobile_check_profile_map);

#
# List of tags which contribute to the "OTHER" catagory of a web page
# size (i.e. not CSS, Javascript, Images, etc).
my (%other_type_link_tags) = (
    "frame", 1,
    "iframe", 1,
    "object", 1,
    );

#
# String table for error strings.
#
my %string_table_en = (
    "Fails validation",              "Fails validation, see validation results for details.",
    );




my %string_table_fr = (
    "Fails validation",             "Échoue la validation, voir les résultats de validation pour plus de détails.",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_Mobile_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Mobile_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_Mobile_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Mobile_Check_Language {
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
}

#**********************************************************************
#
# Name: Mobile_Check_Read_URL_Help_File
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
sub Mobile_Check_Read_URL_Help_File {
    my ($filename) = @_;

}

#**********************************************************************
#
# Name: Mobile_Check_Testcase_URL
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase URL
# table for the specified key.
#
#**********************************************************************
sub Mobile_Check_Testcase_URL {
    my ($key) = @_;

    my ($help_url);

    #
    # Return URL value
    #
    return($help_url);
}

#***********************************************************************
#
# Name: Set_Mobile_Check_Testcase_Data
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
sub Set_Mobile_Check_Testcase_Data {
    my ($profile, $testcase, $data) = @_;
    
    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_Mobile_Check_Test_Profile
#
# Parameters: profile - TQA check test profile
#             mobile_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by TQA testcase name.
#
#***********************************************************************
sub Set_Mobile_Check_Test_Profile {
    my ($profile, $mobile_checks ) = @_;

    my (%local_mobile_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Mobile_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_mobile_checks = %$mobile_checks;
    $mobile_check_profile_map{$profile} = \%local_mobile_checks;
}

#***********************************************************************
#
# Name: Mobile_Check
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
sub Mobile_Check {
    my ($this_url, $language, $profile, $mime_type, $resp, $content) = @_;

    my (@tqa_results_list, $result_object);


    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Mobile_Check_Links
#
# Parameters: url - URL
#             profile - testcase profile
#             content - web page content pointer
#             link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function performs a number of checks on links found within a
# document.  Checks are performed on the common menu bar, left
# navigation and footer.
#
#***********************************************************************
sub Mobile_Check_Links {
    my ($url, $profile, $content, $link_sets) = @_;

    #
    # Perform Mobile link checks.
    #
    print "Mobile_Check_Links: profile = $profile\n" if $debug;
}

#***********************************************************************
#
# Name: Mobile_Check_Compute_Page_Size
#
# Parameters: url - URL
#             resp - HTTP Response object
#             link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function computes a number of size values of a web page.
# The sizes include the overall page size as well as the size of
# a number of components (e.g. images, CSS, etc).
#
#***********************************************************************
sub Mobile_Check_Compute_Page_Size {
    my ($url, $resp, $link_sets) = @_;

    my ($size, $html_size, $link, $section, $links_addr, $link_type);
    my ($size_string);
    my ($css_size) = 0;
    my ($js_size) = 0;
    my ($img_size) = 0;
    my ($other_size) = 0;
    my ($css_count) = 0;
    my ($js_count) = 0;
    my ($img_count) = 0;
    my ($other_count) = 0;

    #
    # Get total document size
    #
    print "Mobile_Check_Compute_Page_Size\n" if $debug;
    $html_size = length($resp->content);

    #
    # Check the links in each document section
    #
    foreach $section (keys(%$link_sets)) {
        print "Check lists in section $section\n" if $debug;
        $links_addr = $$link_sets{$section};
        foreach $link (@$links_addr) {
            #
            # Ignore links in modified code (IE conditional code) and
            # in <noscript> tags.
            #
            $link_type = $link->link_type;
            if ( (! $link->modified_content) && (! $link->noscript) ) {
                #
                # Check for <img> tag
                #
                if ( $link->link_type eq "img" ) {
                    $img_size += $link->content_length;
                    $img_count++;
                    print "Add IMG " . $link->abs_url . " content length " .
                          $link->content_length . " total = $img_size\n" if $debug;
                }
                #
                # Check for other type tags e.g. frame/iframe, object
                #
                elsif ( defined($other_type_link_tags{$link_type}) ) {
                    $other_size += $link->content_length;
                    $other_count++;
                    print "Add $link_type " .
                          $link->abs_url . " content length " .
                          $link->content_length . " total = $other_size\n" if $debug;
                }
                #
                # Check for <link> to CSS
                #
                elsif ( ($link_type eq "link") && ($link->mime_type eq "text/css") ) {
                    $css_size += $link->content_length;
                    $css_count++;
                    print "Add CSS " . $link->abs_url . " content length " .
                          $link->content_length . " total = $css_size\n" if $debug;
                }
                #
                # Check for <script> and JavaScript
                #
                elsif ( ($link_type eq "script") &&
                        (($link->mime_type =~ /application\/x\-javascript/) ||
                         ($link->mime_type =~ /text\/javascript/) ||
                         ($link->abs_url =~ /\.js$/i) ) )  {
                    $js_size += $link->content_length;
                    $js_count++;
                    print "Add JavaScript " . $link->abs_url . " content length " .
                          $link->content_length . " total = $js_size\n" if $debug;
                }
            }
        }
    }

    #
    # Compute overall size
    #
    $size = $html_size + $css_size + $js_size + $img_size + $other_size;
    print "Total page size = $size\n" if $debug;
    $size_string = "$size,$html_size,$css_count,$css_size,$js_count,$js_size,$img_count,$img_size,$other_count,$other_size";
    print "Total page size = $size HTML = $html_size, CSS = $css_size, JS = $js_size, IMG = $img_size, OTHER = $other_size\n" if $debug;
    print "Link type count CSS = $css_count, JS = $js_count, IMG = $img_count, OTHER = $other_count\n" if $debug;
    
    #
    # Return sizes as a string
    #
    return($size_string);
}

#***********************************************************************
#
# Name: Mobile_Check_Save_Web_Page_Size
#
# Parameters: file_handle - a file handle
#             file_name - name of file
#             url - a URL
#             size_string - string os sizes
#
# Description:
#
#   This function saves web page size details as a CSV file.  If
# the file_handle variable is undefind, a temporary file is created.
#
#***********************************************************************
sub Mobile_Check_Save_Web_Page_Size {
    my ($file_handle, $file_name, $url, $size_string) = @_;

    #
    # Do we have a file handle ? or do we create a temporary file ?
    #
    print "Mobile_Check_Save_Web_Page_Size_Details\n" if $debug;
    if ( ! defined($file_handle) ) {
        print "Create temporary CSV file\n" if $debug;
        ($file_handle, $file_name) = tempfile( SUFFIX => '.css');
        if ( ! defined($file_handle) ) {
            print "Error: Failed to create temporary file in Mobile_Check_Save_Web_Page_Size\n";
            return;
        }
        print "CSC file name = $file_name\n" if $debug;
        binmode $file_handle;

        #
        # Print header row for CSV file
        #
        print $file_handle "url,size,html_size,css_count,css_size,js_count,js_size,img_count,img_size,other_count,other_size\n";
    }

    #
    # print size string to file
    #
    print $file_handle "$url,$size_string\n";

    #
    # Return file handle and file name
    #
    return($file_handle, $file_name);
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
    my (@package_list) = ("tqa_result_object");

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

