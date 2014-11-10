#***********************************************************************
#
# Name:   css_extract_links.pm
#
# $Revision: 6789 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/CSS_Validate/Tools/css_extract_links.pm $
# $Date: 2014-10-10 14:05:57 -0400 (Fri, 10 Oct 2014) $
#
# Description:
#
#   This file contains routines that parse CSS files and extract URLs
# from the content.
#
# Public functions:
#     CSS_Extract_Links_Debug
#     CSS_Extract_Links_From_CSS_Style
#     CSS_Extract_Links
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

package css_extract_links;

use strict;
use URI::URL;
use File::Basename;
use CSS;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(CSS_Extract_Links_Debug
                  CSS_Extract_Links_From_CSS_Style
                  CSS_Extract_Links
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
# Name: CSS_Extract_Links_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub CSS_Extract_Links_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;

    #
    # Set debug flag of supporting packages.
    #
    Link_Object_Debug($debug);
}

#***********************************************************************
#
# Name: CSS_Extract_Links_From_CSS_Style
#
# Parameters: url - URL of CSS content
#             style - name of style
#             style_object - style object
#
# Description:
#
#   This function extracts URLs from a CSS style.
#
#***********************************************************************
sub CSS_Extract_Links_From_CSS_Style {
    my ($url, $style, $style_object) = @_;

    my (@properties, $property, $value, $hash, $this_prop);
    my ($selector, $name, @urls, $link, $abs_url);

    #
    # Process each selector within the style
    #
    print "CSS_Extract_Links_From_CSS_Style from $style in $url\n" if $debug;
    for $selector (@{$style_object->{selectors}}) {
        $name = $selector->{name};
        print "Processing selector $name\n" if $debug;

        #
        # Get the list of properties for this selector/class name.
        # Process each one.
        #
        @properties = $style_object->properties;
        for $this_prop (@properties) {
            #
            # Get the property name and its value
            #
            $hash = $$this_prop{"options"};
            $property = $$hash{"property"};
            $value = $$hash{"value"};
            print "Property $property, value $value\n" if $debug;

            #
            # Look for url in the value portion
            #
            if ( $value =~ /^.*url\s*\(/i ) {
                #
                # Strip off leading url( and trailing )
                #
                $value =~ s/^.*url\s*\(\s*//i;
                $value =~ s/\).*//;

                #
                # Is it a single quoted URL ?
                #
                if ( $value =~ /^'/ ) {
                    $value =~ s/^'\s*//g;
                    $value =~ s/\s*'$//g;
                }
                #
                # Double quoted URL ?
                #
                elsif (  $value =~ /^"/ ) {
                    $value =~ s/^"\s*//g;
                    $value =~ s/\s*"$//g;
                }

                #
                # Remove any leading or trailing whitespace
                #
                $value =~ s/^\s*//;
                $value =~ s/\s*$//;

                #
                # Add URL to the list
                #
                if ( $value ne "" ) {
                    print "Extracted URL $value from CSS\n" if $debug;
                    $abs_url = URL_Check_Make_URL_Absolute($value, $url);
                    $link = link_object->new($value, $abs_url, "", "url",
                                             "", -1, -1, "");
                    push (@urls, $link);
                }
            }
        }
    }

    #
    # Return list of URLs
    #
    return(@urls);
}

#***********************************************************************
#
# Name: CSS_Extract_Links
#
# Parameters: url - URL of CSS content
#             base - base for convertin relative to absolute URLs
#             lang - language
#             content_ptr - css content pointer
#
# Description:
#
#   This function extracts any URLs from the CSS content.
#
#***********************************************************************
sub CSS_Extract_Links {
    my ($url, $base, $lang, $content_ptr) = @_;

    my ($css, $style, @properties, $property, $value, $hash, $this_prop);
    my ($selector, $name, @urls, $link, $abs_url, $content, @style_urls);

    #
    # Do we have any url strings in the content ?
    #
    $content = $$content_ptr;
    if ( ! ($content =~ /url\s*\(/i) ) {
        print "CSS_Extract_Links: No url() in content\n" if $debug;
        return(@urls);
    }

    #
    # Remove any comments from the CSS content and compress white space
    #
    print "CSS_Extract_Links from $url\n" if $debug;
    $content = $$content_ptr;
    $content =~ s/<!--.+?-->//gs;
    $content =~ s!/\*.+?\*/!!gs;
    $content =~ s/\r\n|\r|\n/ /g;
    $content =~ s/\s\s+/ /g;

    #
    # Create a CSS parser object and set the output adaptor.
    #
    $css = CSS->new();
    $css->set_adaptor('CSS::Adaptor::Objects');

    #
    # Parse the CSS content
    #
    $css->read_string($content);

    #
    # Check each style in the list of styles
    #
    for $style (@{$css->{styles}}){
        #
        # Process each selector within the style
        #
        for $selector (@{$style->{selectors}}) {
            $name = $selector->{name};
            print "Processing selector $name\n" if $debug;
            @style_urls = CSS_Extract_Links_From_CSS_Style($url, $name,
                                                           $style);

            #
            # Add this style's URLs to the full list
            #
            foreach $link (@style_urls) {
                push(@urls, $link);
            }
        }
    }

    #
    # Return list of URLs
    #
    return(@urls);
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
    my (@package_list) = ("link_object", "url_check");

    #
    # Import packages, we don't use a 'use' statement as these packages
    # may not be in the INC path.
    #
    push @INC, "$program_dir";
    foreach $package (@package_list) {
        #
        # Import the package routines.
        #
        require "$package.pm";
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

