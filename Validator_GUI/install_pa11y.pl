#!/usr/bin/perl -w
#***********************************************************************
#
# Name:   install_pa11y.pl
#
# $Revision: 2445 $
# $URL: svn://10.36.148.185/WPSS_Tool/Validator_GUI/Tools/install_pa11y.pl $
# $Date: 2022-12-16 14:05:14 -0500 (Fri, 16 Dec 2022) $
#
# Synopsis: install_pa11y.pl [ -debug ]
#
# Where: -debug enables program debugging.
#
# Description:
#
#   This program checks the installation of the Pa11y accessibility tool
# It checks that the required software packages are installed
# with the appropriate matching versions. If software is not installed, or
# if there are version mismatches, it prompts the user to install the
# software.
#
# Terms and Conditions of Use
#
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is
# distributed under the MIT License.
#
# MIT License
#
# Copyright (c) 2022 Government of Canada
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

use strict;
use lib ".";
use Cwd;
use File::Basename;
use File::Temp qw/ tempfile tempdir /;
use JSON::PP;

my ($debug) = 0;
my (@paths, $this_path, $program_dir, $program_name, $paths);
my ($input, $is_windows, $userprofile);
my ($install_complete) = 0;

#***********************************************************************
#
# Name: Check_Node
#
# Parameters: none
#
# Description:
#
#   This function checks to see if Node is installed.
#
# Returns:
#   1 - requirements met
#   0 - requirements not met
#
#***********************************************************************
sub Check_Node {
    my ($file_path, $version, $major, $minor, $bug_fix);
    my ($meets_requirements) = 1;

    #
    # Check for Node program
    #
    print "Check_Node\n" if $debug;
    print "Check for Node installation\n";
    if ( $is_windows ) {
        $file_path = `where node 2>&1`;
    }
    else {
        $file_path = `which node 2>&1`;
    }
    if ( ($file_path =~ /Could not find/i) || ($file_path =~ /no node in/i) ) {
        print "Node not installed or not in path\n";
        print "Go to https://nodejs.org/en/download/ to download an install Node version 8 or newer\n";
        $meets_requirements = 0;
    }
    else {
        print "Check Node version\n";
        $version = `node -v`;
        chomp($version);
        print "Node version $version found at $file_path\n";

        #
        # Is the Node version 8 or newer?
        #
        ($major, $minor, $bug_fix) = $version =~ /^v(\d+)\.(\d+)\.(\d+)+$/io;
        if ( ! defined($major) ) {
            print "Could not determine major version number, expecting \"v[digits].[digits].[digits]\" found \"$version\"\n";
            print "Go to https://nodejs.org/en/download/ to download an install a newer version\n";
            $meets_requirements = 0;
        }
        elsif ( $major < 8) {
            print "Node major version number ($major) is older than required version 8\n";
            print "Go to https://nodejs.org/en/download/ to download an install a newer version\n";
            $meets_requirements = 0;
        }
        else {
            print "Node major version number ($major) is 8 or newer\n";
        }
    }

    #
    # Return requirements indicator
    #
    return($meets_requirements);
}

#***********************************************************************
#
# Name: Get_Required_Node_Module_Version
#
# Parameters: module - name of module
#             installed_version - the currently installed version
#
# Description:
#
#   This function gets the list of available versions for the
# specified module to see if a newer version exists. The user is
# prompted to see if they want to install the newer version.
#
# Returns:
#   required version of the module
#
#***********************************************************************
sub Get_Required_Node_Module_Version {
    my ($module, $installed_version) = @_;

    my ($output, $version, @version_list, $list, $line, $required_version);
    my ($numeric_version, $numeric_installed_version, $newer_version);
    my ($response, $major, $minor, $bug);

    #
    # Assume that we want to keep the existing version
    #
    print "Get_Required_Node_Module_Version for $module, installed version $installed_version\n" if $debug;
    $required_version = $version;

    #
    # Get the list of available versions
    #
    $output = `npm view $module versions json`;

    #
    # Did we get a list?
    #
    if ( $output eq "" ) {
        print "Error in retriving list of versions for module $module\n";
        print "Press <enter> to exit program\n";
        $response = <STDIN>;
        exit(1);
    }

    #
    # Clean up the output to reduce whitespace
    #
    $output =~ s/\t//g;
    $output =~ s/\r\n//g;
    $output =~ s/\n//g;
    $output =~ s/\s+//g;
    $output =~ s/'/"/g;

    #
    # Convert the output into a list.
    #
    $list = decode_json($output);
    @version_list = @$list;
    print "Module versions " . join(", ", @version_list) . "\n" if $debug;

    #
    # Is there a newer version of the module?
    #
    if ( $installed_version eq "unknown" ) {
        $numeric_installed_version = 0;
    }
    else {
        $numeric_installed_version = $installed_version;
        $numeric_installed_version =~ s/\-.*//g;
        ($major, $minor, $bug) = split(/\./, $numeric_installed_version);
        $numeric_installed_version = sprintf("%d%02d%04d", $major, $minor, $bug);
    }
    foreach $version (reverse(@version_list)) {
        $numeric_version = $version;
        $numeric_version =~ s/\-.*//g;
        ($major, $minor, $bug) = split(/\./, $numeric_version);
        $numeric_version = sprintf("%d%02d%04d", $major, $minor, $bug);
        if ( $numeric_version > $numeric_installed_version ) {
            $newer_version = $version;
            last;
        }
    }

    #
    # Do we have a newer version?
    #
    if ( defined($newer_version) ) {
        print "Newer version ($newer_version) of module $module found.\n";
        print "Do you want to install this version (y/n)?\n";
        $response = <STDIN>;

        #
        # Do we upgrade the version?
        #
        if ( $response =~ /^y/i ) {
            $required_version = $newer_version;
        }
    }
    #
    # Return required module version
    #
    return($required_version);
}

#***********************************************************************
#
# Name: Install_pa11y
#
# Parameters: required_version - required version of module
#
# Description:
#
#   This function installs the latest version of the pa11y module if
# a required version is specified. If not, it prompts the user to install
# the pa11y module.
##
# Returns:
#   1 - Installed
#   0 - Not installed
#
#***********************************************************************
sub Install_pa11y {
    my ($required_version) = @_;

    my ($installed) = 0;
    my ($response, $output, $version, $line);

    #
    # Do we have a required version?
    #
    print "Install_pa11y\n" if $debug;
    if ( defined($required_version) ) {
        $response = "y";
    }
    else {
        #
        # Prompt user to install pa11y module
        #
        print "Do you want to install the pa11y module? (y/n)\n";
        $response = <STDIN>;
    }

    #
    # Do we install the module?
    #
    if ( $response =~ /^y/i ) {
        #
        # Install the module
        #
        print "Installing pa11y module\n";
        print "npm install -g pa11y\n";
        `npm install -g pa11y`;

        #
        # Check installation
        #
        $output = `npm list pa11y -g 2>&1`;
        foreach $line (split(/[\n\r]/, $output)) {
            if ( $line =~ /^\|/ ) {
                #
                # Skip pa11y from nested module
                #
                next;
            }
            elsif ( $line =~ /^  `/ ) {
                #
                # Skip pa11y from nested module
                #
                next;
            }
            elsif ( $line =~ /pa11y/ ) {
                print "Found pa11y version $line\n" if $debug;
                $line =~ s/^.*@//g;
                $version = $line;
                last;
            }
        }
        if ( defined($version) ) {
            print "Installation complete\n";
            $installed = 1;
        }
        else {
            print "Installation failed\n";
        }
    }
    else {
        print "pa11y module not installed\n";
    }

    #
    # Return installation status
    #
    return($installed);

}

#***********************************************************************
#
# Name: Check_Pa11y
#
# Parameters: none
#
# Description:
#
#   This function checks to see if Pa11y is installed.
#
# Returns:
#   1 - requirements met
#   0 - requirements not met
#
#***********************************************************************
sub Check_Pa11y {
    my ($version, $file_path, $required_version);
    my ($meets_requirements) = 1;

    #
    # Check that Pa11y installed
    #
    print "Check_Pa11y\n" if $debug;
    print "Check for pa11y program\n" if $debug;
    if ( $is_windows ) {
        $file_path = `where pa11y 2>&1`;
    }
    else {
        $file_path = `which pa11y 2>&1`;
    }
    print "where pa11y output\n$file_path\n" if $debug;
    if ( ($file_path =~ /Could not find/i) || ($file_path =~ /no pa11y in/i) ) {
        print "Pa11y not installed\n";

        #
        # Install Pa11y
        #
        $meets_requirements = Install_pa11y();
    }
    else {
        #
        # Get pa11y version
        #
        $version = `pa11y --version 2>&1`;
        chomp($version);
        $version = $version;
        print "Pa11y $version found\n";

        #
        # See if there is a newer version
        #
        $required_version = Get_Required_Node_Module_Version("pa11y",
                                                             $version);

        #
        # Is the required version different from the installed version?
        #
        if ( defined($required_version) && ($required_version ne $version) ) {
            #
            # Install pa11y
            #
            $meets_requirements = Install_pa11y($required_version);
        }
    }

    #
    # Get pa11y version
    #
    if ( $meets_requirements && defined($required_version) && ($required_version ne $version) ) {
        $version = `pa11y --version 2>&1`;
        chomp($version);
        $version = $version;
        print "Pa11y $version found\n";
    }

    #
    # Return requirements indicator
    #
    return($meets_requirements);
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
# If directory is '.', get the current working directory
#
if ( $program_dir eq "." ) {
    $program_dir = getcwd();
}

#
# Process command-line options
#
foreach (@ARGV) {
    if ( /-debug/ ) {
        $debug = 1;
    }
}

#
# Is this a Windows or Unix platform
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $is_windows = 1;
    $paths = $ENV{"PATH"};
    $userprofile = $ENV{"USERPROFILE"};
    $paths .= ";$userprofile/AppData/Roaming/npm";
    $ENV{"PATH"} = $paths;
} else {
    #
    # Not Windows (should be Linux).
    #
    $is_windows = 0;
}

#
# Check Node installation
#
if ( Check_Node() ) {
    #
    # Check for pa11y module
    #
    $install_complete = Check_Pa11y();
}

#
# Wait for user before exiting
#
print "Press <enter> to exit program\n";
$input = <STDIN>;


