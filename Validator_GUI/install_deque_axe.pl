#!/usr/bin/perl -w
#***********************************************************************
#
# Name:   install_deque_axe.pl
#
# $Revision: 2507 $
# $URL: svn://10.36.148.185/WPSS_Tool/Validator_GUI/Tools/install_deque_axe.pl $
# $Date: 2023-04-19 10:12:41 -0400 (Wed, 19 Apr 2023) $
#
# Synopsis: install_deque_axe.pl [ -debug ]
#
# Where: -debug enables program debugging.
#
# Description:
#
#   This program checks the installation of the Deque Axe accessibility tool
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
my ($default_windows_chrome_path, $puppeteer_chrome_min_version);
my ($chrome_version, $input, $is_windows, $userprofile);
my ($install_complete) = 0;

#***********************************************************************
#
# Name: Read_Config_File
#
# Parameters: path - the path to configuration file
#
# Description:
#
#   This function reads a configuration file.
#
#***********************************************************************
sub Read_Config_File {
    my ($config_file) = $_[0];

    my (@fields, $config_type, @alternate_lang_profiles);

    #
    # Check to see that the configuration file exists
    #
    if ( !-f "$config_file" ) {
        print "Error: Missing configuration file\n";
        print " --> $config_file\n";
        exit(1);
    }

    #
    # Open configuration file at specified path
    #
    print "Opening configuration file $config_file\n" if $debug;
    open( CONFIG_FILE, "$config_file" )
      || die
      "Failed to open configuration file, errno is $!\n  --> $config_file\n";

    #
    # Read file looking for values for config parameters.
    #
    while (<CONFIG_FILE>) {

        #
        # Ignore comment and blank lines.
        #
        chop;
        if ( /^#/ ) {
            next;
        }
        elsif ( /^$/ ) {
            next;
        }

        #
        # Split the line into fields.
        #
        @fields = split;
        $config_type = $fields[0];

        #
        # Check for Chrome install path
        #
        if ( $config_type eq "default_windows_chrome_path" ) {
            #
            # Set Windows default chrome browser path value
            #
            if ( @fields > 1 ) {
                @fields = split(/\s+/, $_, 2);
                if ( defined($default_windows_chrome_path) ) {
                    $default_windows_chrome_path .= "\n" . $fields[1];
                }
                else {
                    $default_windows_chrome_path = $fields[1];
                }
            }
        }
        elsif ( $config_type eq "puppeteer_chrome_min_version" ) {
            #
            # Set puppeteer minimum Chrome version value
            #
            if ( @fields > 1 ) {
                @fields = split(/\s+/, $_, 2);
                $puppeteer_chrome_min_version = $fields[1];
            }
            else {
                $puppeteer_chrome_min_version = 0;
            }
        }
    }
    close(CONFIG_FILE);
}

#***********************************************************************
#
# Name: Check_Chrome
#
# Parameters: none
#
# Description:
#
#   This function checks to see if the Google Chrome browser is installed.
#
# Returns:
#   1 - requirements met
#   0 - requirements not met
#
#***********************************************************************
sub Check_Chrome {
    my ($file_path, $version, $major, $minor, $version_str, $chrome_path);
    my ($meets_requirements) = 1;

    #
    # Do we have configuration parameters?
    #
    print "Check_Chrome\n" if $debug;
    print "Check for Headless Chrome and Puppeteer configuration settings\n";
    if ( (! defined($default_windows_chrome_path)) ||
         (! defined($puppeteer_chrome_min_version)) ) {
        print "Headless Chrome and Puppeteer configuration not provided\n";
        $meets_requirements = 0;
        return($meets_requirements);
    }

    #
    # Find Chrome in the path or use default path
    #
    print "Check for Google Chrome installation\n";
    if ( $is_windows ) {
        $chrome_path = `where chrome 2>&1`;
    }
    else {
        $chrome_path = `which chrome 2>&1`;
    }
    if ( ($chrome_path =~ /Could not find/i) || ($chrome_path =~ /no chrome in/i) ) {
        print "Chrome not in path, checking default paths\n";
        if ( defined($default_windows_chrome_path) ) {
            #
            # Check each path for an instance of Chrome
            #
            print "Default chrome paths = $default_windows_chrome_path\n" if $debug;
            foreach $file_path (split(/\n/, $default_windows_chrome_path)) {
                if ( -f $file_path ) {
                    $chrome_path = $file_path;
                    print "Chrome found at path = $file_path\n";
                    last;
                }
            }
        }
        else {
            print "No default chrome path\n" if $debug;
            undef $chrome_path;
        }
    }

    #
    # Did we get a path? If so get version.
    #
    if ( defined($chrome_path) && (-f $chrome_path) ) {
        #
        # Check version of chrome
        #
        $file_path = $chrome_path;

        if ( $is_windows ) {
            #
            # Escape all backslash characters in file path.
            # Use wmic command to get Chrome version as the --version
            # argument does not always work.
            #
            $file_path =~ s/\\/\\\\/g;
            print "Get Chrome verion\n";
            print "Check Chrome version from\nwmic datafile where name=\"$file_path\" get Version /value\n" if $debug;
            $version_str = `wmic datafile where name=\"$file_path\" get Version /value`;
            ($version) = $version_str =~ /^[\s\n\r]*version=([\d\.]+).*$/mio;
            ($major, $minor) = $version =~ /^(\d+)\.(\d+).*$/io;
            print "Chrome version = $major from $version_str\n" if $debug;
            $chrome_version = "$major.$minor";
            print "Found Chrome version $major.$minor\n";
        }

        #
        # Is the major version number greater than the minimum required?
        #
        print "Check minimum supported Chrome version\n";
        if ( defined($puppeteer_chrome_min_version) && defined($major) &&
             ($major >= $puppeteer_chrome_min_version) ) {
            print "Chrome version ($major) meets minimum supported version by Puppeteer ($puppeteer_chrome_min_version)\n";
        }
        else {
            #
            # Either no versions or version below minimum
            #
            print "Chrome version ($chrome_version) below minimum supported version by Puppeteer ($puppeteer_chrome_min_version)\n";
            print "Go to https://www.google.com/chrome/ to download an install Google Chrome version 69 or newer\n";
            $meets_requirements = 0;
        }
    }
    else {
        #
        # No chrome executable
        #
        print "Google Chrome broswer not found\n";
        print "Go to https://www.google.com/chrome/ to download an install Google Chrome version 69 or newer\n";
        $meets_requirements = 0;
    }

    #
    # Return requirements indicator
    #
    return($meets_requirements);
}

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
# Name: Install_deque_axe_core_cli
#
# Parameters: required_version - required version of module
#
# Description:
#
#   This function installs the latest version of the axe-core/cli module if
# a required version is specified. If not, it prompts the user to install
# the pa11y module.
##
# Returns:
#   1 - Installed
#   0 - Not installed
#
#***********************************************************************
sub Install_deque_axe_core_cli {
    my ($required_version) = @_;

    my ($installed) = 0;
    my ($response, $output, $version, $line);

    #
    # Do we have a required version?
    #
    print "Install_deque_axe_core_cli\n" if $debug;
    if ( defined($required_version) ) {
        $response = "y";
    }
    else {
        #
        # Prompt user to install pa11y module
        #
        print "Do you want to install the Deque axe-core/cli module? (y/n)\n";
        $response = <STDIN>;
    }

    #
    # Do we install the module?
    #
    if ( $response =~ /^y/i ) {
        #
        # Install the module
        #
        print "Installing Deque axe-core/cli module\n";
        print "npm install -g \@axe-core/cli\n";
        `npm install -g \@axe-core/cli`;

        #
        # Check installation
        #
        $output = `npm list \@axe-core/cli -g 2>&1`;
        foreach $line (split(/[\n\r]/, $output)) {
            if ( $line =~ /^\|/ ) {
                #
                # Skip axe-core/cli from nested module
                #
                next;
            }
            elsif ( $line =~ /^  `/ ) {
                #
                # Skip axe-core/cli from nested module
                #
                next;
            }
            elsif ( $line =~ /axe\-core\/cli/ ) {
                print "Found axe-core/cli version $line\n" if $debug;
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
        print "axe-core/cli module not installed\n";
    }

    #
    # Return installation status
    #
    return($installed);

}

#***********************************************************************
#
# Name: Check_Axe_Core_CLI
#
# Parameters: none
#
# Description:
#
#   This function checks to see if the axe-core/cli module is installed.
#
# Returns:
#   1 - requirements met
#   0 - requirements not met
#
#***********************************************************************
sub Check_Axe_Core_CLI {
    my ($version, $file_path, $required_version);
    my ($meets_requirements) = 1;

    #
    # Check that Axe core installed
    #
    print "Check_Axe_Core_CLI\n" if $debug;
    print "Check for deque axe program\n" if $debug;
    if ( $is_windows ) {
        $file_path = `where axe 2>&1`;
    }
    else {
        $file_path = `which axe 2>&1`;
    }
    print "where axe output\n$file_path\n" if $debug;
    if ( ($file_path =~ /Could not find/i) || ($file_path =~ /no axe in/i) ) {
        print "Deque axe not installed\n";

        #
        # Install Deque axe
        #
        $meets_requirements = Install_deque_axe_core_cli();
    }
    else {
        #
        # Get axe version
        #
        $version = `axe --version 2>&1`;
        chomp($version);
        $version = $version;
        print "Deque axe $version found\n";

        #
        # See if there is a newer version
        #
        $required_version = Get_Required_Node_Module_Version("\@axe-core/cli",
                                                             $version);

        #
        # Is the required version different from the installed version?
        #
        if ( defined($required_version) && ($required_version ne $version) ) {
            #
            # Install Deque axe
            #
            $meets_requirements = Install_deque_axe_core_cli($required_version);
        }
    }

    #
    # Get axe version
    #
    if ( $meets_requirements && defined($required_version) && ($required_version ne $version) ) {
        $version = `axe --version 2>&1`;
        chomp($version);
        $version = $version;
        print "Deque axe $version found\n";
    }

    #
    # Return requirements indicator
    #
    return($meets_requirements);
}

#***********************************************************************
#
# Name: Install_Chromedriver
#
# Parameters: required_version - optional required version
#
# Description:
#
#   This function prompts the user to install the chromedriver module.
#
# Returns:
#   1 - Installed
#   0 - Not installed
#
#***********************************************************************
sub Install_Chromedriver {
    my ($required_version) = @_;
    
    my ($installed) = 0;
    my ($response, $output, $version, $list, $line);

    #
    # Prompt user to install chromedriver module
    #
    print "Install_Chromedriver\n" if $debug;
    if ( ! defined($required_version) ) {
        print "Do you want to install the chromedriver module? (y/n)\n";
        $response = <STDIN>;
    }
    else {
        $response = "y";
    }

    #
    # Do we install the module?
    #
    if ( $response =~ /^y/i ) {
        #
        # Get the list of available versions, we want the one that
        # matches the Google Chrome browser version.
        #
        $output = `npm view chromedriver versions json`;
        $output =~ s/\t//g;
        $output =~ s/\r\n//g;
        $output =~ s/\n//g;
        $output =~ s/\s+//g;
        $output =~ s/'/"/g;

        #
        # Conversion the output into a list.
        #
        $list = decode_json($output);

        #
        # Get the chromedriver version that matches our Google Chrome version
        #
        foreach $version (@$list) {
            if ( index($version, $chrome_version) == 0 ) {
                #
                # Found a matching major.minor version
                #
                print "Chromedriver version $version valid for Chrome version $chrome_version\n" if $debug;
                $required_version = $version;
            }
        }

        #
        # Did we find a suitable version?
        #
        if ( defined($required_version) ) {
            #
            # Install the module
            #
            print "Installing chromedriver module version $required_version\n";
            print "npm install -g chromedriver\@$required_version\n";
            `npm install -g chromedriver\@$required_version`;

            #
            # Check installation
            #
            $output = `npm list chromedriver -g 2>&1`;
            foreach $line (split(/[\n\r]/, $output)) {
                if ( $line =~ /^\|/ ) {
                    #
                    # Skip chromedrive from nested module
                    #
                    next;
                }
                elsif ( $line =~ /^  `/ ) {
                    #
                    # Skip chromedrive from nested module
                    #
                    next;
                }
                elsif ( $line =~ /chromedriver/ ) {
                    print "Found chromedriver version $line\n" if $debug;
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
            #
            # No matching version found
            #
            print "Did not find a verion of chromedriver matching Chrome version \"$chrome_version\"\n";
        }
    }
    else {
        print "Chromedrivere module not installed\n";
    }

    #
    # Return installation status
    #
    return($installed);

}

#***********************************************************************
#
# Name: Check_Chromedriver
#
# Parameters: none
#
# Description:
#
#   This function checks to see if the chromedriver module for Node is installed.
#
# Returns:
#   1 - requirements met
#   0 - requirements not met
#
#***********************************************************************
sub Check_Chromedriver {
    my ($js_filename, $node_output, $line, $version, $required_version);
    my ($meets_requirements) = 1;

    #
    # Check for Node program
    #
    print "Check_Chromedriver\n" if $debug;

    #
    # Get chromedriver version
    #
    print "Check chromedriver version\n";
    $node_output = `npm list chromedriver -g 2>&1`;
    $version = "";
    foreach $line (split(/[\n\r]/, $node_output)) {
        if ( $line =~ /^\|/ ) {
            #
            # Skip chromedrive from nested module
            #
            next;
        }
        elsif ( $line =~ /^  `/ ) {
            #
            # Skip chromedrive from nested module
            #
            next;
        }
        elsif ( $line =~ /chromedriver/ ) {
            print "Found chromedriver version $line\n" if $debug;
            $line =~ s/^.*@//g;
            $version = $line;
            last;
        }
    }

    #
    # Did we get the chromedriver version?
    #
    if ( $version eq "" ) {
        print "Chromedriver module not installed\n";

        #
        # Install chromedriver-core
        #
        $meets_requirements = Install_Chromedriver();
    }
    else {
        print "Chromedriver module version $version found\n";
        
        #
        # See if there is a newer version
        #
        $required_version = Get_Required_Node_Module_Version("chromedriver",
                                                             $version);

        #
        # Is the required version different from the installed version?
        #
        if ( defined($required_version) && ($required_version ne $version) ) {
            #
            # Install pa11y
            #
            $meets_requirements = Install_Chromedriver($required_version);
        }
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
    $paths .= ";$userprofile/AppData/Roaming/npm/node_modules/chromedriver/lib/chromedriver" .
              ";$userprofile/AppData/Roaming/npm";
    $ENV{"PATH"} = $paths;
} else {
    #
    # Not Windows (should be Linux).
    #
    $is_windows = 0;
}

#
# Read program configuration files
#
Read_Config_File("$program_dir/conf/wpss_tool.config");

#
# Check Chrome installation
#
if ( Check_Chrome() ) {
    #
    # Check Node installation
    #
    if ( Check_Node() ) {
        #
        # Check for Deque AXE core/cli module
        #
        if ( Check_Axe_Core_CLI() ) {
                $install_complete = Check_Chromedriver();
        }

    }
}

#
# Wait for user before exiting
#
print "Press <enter> to exit program\n";
$input = <STDIN>;


