#***********************************************************************
#
# Name:   crawler_phantomjs.pm
#
# $Revision: 7621 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Crawler/Tools/crawler_phantomjs.pm $
# $Date: 2016-07-13 03:32:58 -0400 (Wed, 13 Jul 2016) $
#
# Description:
#
#   This file contains routines to interact with the PhantomJS program.
#
# Public functions:
#     Crawler_Phantomjs_Clear_Cache
#     Crawler_Phantomjs_Debug
#     Crawler_Phantomjs_Page_Markup
#
# Terms and Conditions of Use
#
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is
# distributed under the MIT License.
#
# MIT License
#
# Copyright (c) 2015 Government of Canada
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

package crawler_phantomjs;

use strict;
use Encode;
use File::Basename;
use File::Path qw(remove_tree);

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Crawler_Phantomjs_Clear_Cache
                  Crawler_Phantomjs_Debug
                  Crawler_Phantomjs_Page_Markup
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths, $phantomjs_cmnd);
my ($phantomjs_arg, $phantomjs_cache);

my ($debug) = 0;

#********************************************************
#
# Name: Crawler_Phantomjs_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Crawler_Phantomjs_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: Crawler_Phantomjs_Clear_Cache
#
# Parameters: cookie_file - path to cookie jar file
#
# Description:
#
#   This function clears the disk cache and cookie jar for PhantomJS.
#
#***********************************************************************
sub Crawler_Phantomjs_Clear_Cache {
    my ($cookie_file) = @_;
    
    my ($error, $diag, $file, $message);

    #
    # Remove cookie jar file if it exists
    #
    print "Crawler_Phantomjs_Clear_Cache, remove cookie jar $cookie_file\n" if $debug;
    if ( defined($cookie_file) && ($cookie_file ne "") ) {
        unlink($cookie_file);
    }
    
    #
    # Remove the disk cache
    #
    print "Remove disk cache $phantomjs_cache\n" if $debug;
    remove_tree($phantomjs_cache, {error => \$error});
    
    #
    # Check for possible errors
    #
    if ( @$error ) {
        print "Error: Failed to remove_tree $phantomjs_cache\n";
        for $diag (@$error) {
            ($file, $message) = %$diag;
            if ($file eq '') {
                print "general error: $message\n";
            }
            else {
                print "problem unlinking $file: $message\n";
            }
        }
    }
}

#***********************************************************************
#
# Name: Crawler_Phantomjs_Page_Markup
#
# Parameters: this_url - a URL
#             cookie_file - path to cookie jar file
#             image_file - name of file to contain the screen capture
#               of the web page
#
# Description:
#
#   This function runs the page_markup.js program in PhantomJS to
# get the HTML markup of the page after any load time JavaScript is
# run on the page.
#
#***********************************************************************
sub Crawler_Phantomjs_Page_Markup {
    my ($this_url, $cookie_file, $image_file) = @_;

    my ($content, $output, $line, $load_time, $markup);
    my ($sec, $min, $hour, $date, $image_param);

    #
    # Get current time/date
    #
    ($sec, $min, $hour) = (localtime)[0,1,2];
    $date = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
    
    #
    # Are we capturing an image of the web page ?
    #
    if ( defined($image_file) && ($image_file ne "") ) {
        $image_param = " -page_image \"$image_file\"";
    }
    else {
        $image_param = "";
    }

    #
    # Get page markup from the URL ?
    #
    print "Crawler_Phantomjs_Content start $date page markup from $this_url\n" if $debug;
    $output = `$phantomjs_cmnd --disk-cache=true --cookies-file=\"$cookie_file\" $phantomjs_arg \"$this_url\" $image_param 2>> phantomjs_stderr.txt`;
    ($sec, $min, $hour) = (localtime)[0,1,2];
    $date = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
    print "Crawler_Phantomjs_Content end   $date page markup\n" if $debug;

    #
    # Did we get the page markup ?
    #
    if ( $output =~ /===== PAGE MARKUP ENDS =====/ ) {
        $markup = 0;
        foreach $line (split(/\n/, $output)) {
            if ( $line =~ /^.*page load time/ ) {
                $load_time = $line;
                $load_time =~ s/^.*page load time//g;
            }
            elsif ( $line =~ /===== PAGE MARKUP BEGINS =====/ ) {
                #
                # Start of markup
                #
                $markup = 1;
            }
            elsif ( $line =~ /===== PAGE MARKUP ENDS =====/ ) {
                #
                # End of markup
                #
                $markup = 0;
            }
            elsif ( $markup ) {
                $content .= $line . "\n";
            }
        }
        print "Found page markup and load time $load_time\n" if $debug;
        $content = decode("utf8", $content);
    }
    else {
        #
        # Error running phantomjs
        #
        print STDERR "Error running phantomjs\n";
        print STDERR "  $phantomjs_cmnd --disk-cache=true --cookies-file=\"$cookie_file\" $phantomjs_arg \"$this_url\" $image_param\n";
        print STDERR "$output\n";
        $content = "";
    }

    #
    # Return content
    #
    return($content);
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
    my (@package_list) = ();

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
# Get path to PhantomJS command
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $phantomjs_cmnd = ".\\bin\\phantomjs";
    $phantomjs_arg = ".\\lib\\page_markup.js";
    $phantomjs_cache = $ENV{"HOME"} . "/AppData/Local/Ofi Labs/PhantomJS";
} else {
    #
    # Not Windows.
    #
    $phantomjs_cmnd = "$program_dir/bin/phantomjs";
    $phantomjs_arg = "./lib/page_markup.js";
    $phantomjs_cache = $ENV{"HOME"} . "/.qws/cache/Ofi Labs/PhantomJS";
}

#
# Import required packages
#
Import_Packages;

#
# Return true to indicate we loaded successfully
#
return 1;


