#***********************************************************************
#
# Name:   validate_markup.pm
#
# $Revision: 6552 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/HTML_Validate/Tools/validate_markup.pm $
# $Date: 2014-01-30 14:25:24 -0500 (Thu, 30 Jan 2014) $
#
# Description:
#
#   This file contains routines that validate content markup.
#
# Public functions:
#     Validate_Markup
#     Validate_Markup_Debug
#     Validate_Markup_Language
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

package validate_markup;

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
    @EXPORT  = qw(Validate_Markup
                  Validate_Markup_Debug
                  Validate_Markup_Language
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths, $validate_cmnd);

my ($debug) = 0;

my ($VALID_MARKUP) = 1;
my ($INVALID_MARKUP) = 0;

#
# Default language is English
#
my ($language) = "eng";

#********************************************************
#
# Name: Validate_Markup_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Validate_Markup_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;

    #
    # Set debug flag in supporting modules
    #
    CSS_Validate_Debug($debug);
    HTML_Validate_Debug($debug);
    JavaScript_Validate_Debug($debug);
    Robots_Check_Debug($debug);
    Feed_Validate_Debug($debug);
}

#********************************************************
#
# Name: Validate_Markup_Language
#
# Parameters: this_language - language value
#
# Description:
#
#   This function sets the package language value.
#
#********************************************************
sub Validate_Markup_Language {
    my ($this_language) = @_;

    #
    # Set language for supporting packages
    #
    CSS_Validate_Language($this_language);
    HTML_Validate_Language($this_language);
    Robots_Check_Language($this_language);
    Feed_Validate_Language($this_language);

    #
    # Set global language
    #
    if ( $language =~ /^fr/i ) {
        $language = "fra";
    }
    else {
        $language = "eng";
    }
}

#***********************************************************************
#
# Name: Validate_Markup
#
# Parameters: this_url - a URL
#             mime_type - mime type of content
#             charset - character set of content
#             content - content
#
# Description:
#
#   This function runs a content specific validator on the supplied content
# and returns the validation status result.
#
#***********************************************************************
sub Validate_Markup {
    my ($this_url, $mime_type, $charset, $content) = @_;

    my ($status) = $VALID_MARKUP;
    my (@results_list, $result_object, $other_content, @other_results_list);

    #
    # Do we have any content ?
    #
    if ( length($content) > 0 ) {
        #
        # Select the validator that is appropriate for the content type
        #
        print "Validate_Markup URL $this_url, mime_type = $mime_type\n" if $debug;
        if ( $mime_type =~ /text\/html/ ) {
            #
            # Validate the HTML content.
            #
            print "Validate HTML content\n" if $debug;
            @results_list = HTML_Validate_Content($this_url, $charset,
                                                  $content);

            #
            # HTML documents may have inline CSS code, extract any CSS
            # code for validation.
            #
            $other_content = CSS_Validate_Extract_CSS_From_HTML($this_url,
                                                              $content);
            if (  length($other_content) > 0 ) {
                #
                #
                # Validate CSS content
                #
                print "Validate inline CSS content\n" if $debug;
                @other_results_list = CSS_Validate_Content($this_url,
                                                           $other_content);

                #
                # Merge CSS validation results into HTML validation results
                #
                foreach $result_object (@other_results_list) {
                    push (@results_list, $result_object);
                }
            }
        }
        elsif ( $mime_type =~ /text\/css/ ) {
            #
            # Validate the CSS content.
            #
            print "Validate CSS content\n" if $debug;
            @results_list = CSS_Validate_Content($this_url, $content);
        }
        elsif ( $this_url =~ /\/robots\.txt$/ ) {
            #
            # Validate the robots.txt content.
            #
            print "Validate robots.txt content\n" if $debug;
            @results_list = Robots_Check($this_url, $content);
        }
        elsif ( ($mime_type =~ /application\/x-javascript/) ||
                ($mime_type =~ /text\/javascript/) ) {
            #
            # Validate the JavaScript content.
            #
            print "Validate JavaScript content\n" if $debug;
            @results_list = JavaScript_Validate_Content($this_url, "error", 
                                                        $content);
        }
        #
        # Is this XML content
        #
        elsif ( ($mime_type =~ /application\/xhtml\+xml/) ||
                ($mime_type =~ /application\/atom\+xml/) ||
                ($mime_type =~ /text\/xml/) ||
                ($this_url =~ /\.xml$/i) ) {
            #
            # Determine if the XML document is a Web Feed.
            #
            if ( Feed_Validate_Is_Web_Feed($this_url, $content) ) {
                print "Validate XML Web feed content\n" if $debug;
                @results_list = Feed_Validate_Content($this_url, $content);
            }
        }
    }
    else {
        #
        # No content
        #
        print "No content passed to Validate_Markup\n" if $debug;
    }

    #
    # Return result objects
    #
    print "Validate_Markup status = $status\n" if $debug;
    return(@results_list);
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
    my (@package_list) = ("css_validate", "html_validate",
                          "javascript_validate", "robots_check",
                          "tqa_result_object", "feed_validate");

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

