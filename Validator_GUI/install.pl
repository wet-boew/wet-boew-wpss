#!/usr/bin/perl -w
#***********************************************************************
#
# Name:   install.pl
#
# $Revision: 6733 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Validator_GUI/Tools/install.pl $
# $Date: 2014-07-24 14:57:12 -0400 (Thu, 24 Jul 2014) $
#
# Synopsis: install.pl [ uninstall ] [ -no_pause ]
#
# Description:
#
#   This program handles the installation of the WPSS Validation tool.
# It installs all required packages and tests the perl installation. It
# also can uninstall the program.
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

use strict;
use File::Basename;
use Sys::Hostname;
use Win32::TieRegistry( Delimiter=>"#", ArrayValues=>0 );
use LWP::UserAgent;
use HTTP::Headers;
use ExtUtils::Installed;
use File::Temp qw/ tempfile/;

#***********************************************************************
#
# Program global variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);
my ($line, $perl_install);
my ($debug) = 0;
my ($uninstall) = 0;
my ($pause_before_exit) = 1;

#
# String table for UI strings.
#
my %string_table_en = (
    "Missing Win32::GUI folder","Error, Missing Win32::GUI module folder",
    "Missing Win32::GUI file","Error, Missing Win32::GUI module file",
    "install Win32::GUI failed","Error: Failed to install Win32::GUI module, return code =",
    "install Win32::GUI complete","Win32::GUI package install complete",
    "installing Win32::GUI","Installing Win32::GUI package",
    "complete WPSS Validation Installation","Press <return> complete WPSS Validation Installation",
    "Failed to register installation","Warning: Failed to register installation",
);

my %string_table_fr = (
    "k","v",
);

my ($string_table) = \%string_table_en;

#
# Supporting directories
#
my (@supporting_directories) = ("results", "profiles");
my ($dir);

#**********************************************************************
#
# Name: Exit_With_Pause
#
# Parameters: satus - status value
#
# Description:
#
#   This function optionally pauses before performing an exit for the
# program.  A pause is needed if the install is run from a Windows
# explorer window to allow the user to read any messages.  If a 
# pause is required, the program waits until the user presses the <enter>
# key.
#
#**********************************************************************
sub Exit_With_Pause {
    my ($status) = @_;

    my ($input);

    #
    # Do we wait for the user to press enter ?
    #
    if ( $pause_before_exit ) {
       print "Press <enter> to exit install.pl\n";
        $input = <STDIN>;
    }

    #
    # Exit the program
    #
    exit($status);
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

#**********************************************************************
#
# Name: Set_Language
#
# Parameters: none
#
# Description:
#
#   This function determines the language of this workstation and
# sets the string table appropriately.
#
#**********************************************************************
sub Set_Language {
    my ($pound, $data, $key);

    #
    # Set default language to English in case we cannot determine the
    # workstation language.
    #
    $string_table = \%string_table_en;

    #
    # Get the registry key for language setting of the current user
    #
    $pound= $Registry->Delimiter("/");
    if ( $key= $Registry->{"HKEY_CURRENT_USER/Control Panel/International/"} ) {

        #
        # Look for the Language item
        #
        if ( $data= $key->{"/sLanguage"} ) {
            #
            # Is the value one of the French possibilities ?
            #
            if ( $data =~ /^FR/i ) {
                $string_table = \%string_table_fr;
            }
        }
    }
}

#**********************************************************************
#
# Name: Write_To_Log
#
# Parameters: text
#
# Description:
#
#   This function writes the supplied message to the installation
# log file.
#
#**********************************************************************
sub Write_To_Log {
    my ($text) = @_;

    #
    # Check for a logs directory.
    #
    if ( ! -d "$program_dir/logs" ) {
        mkdir("$program_dir/logs", 0755);
    }

    #
    # Open the log file
    #
    if ( open(LOG_FILE, ">> $program_dir/logs/install.log") ) {
        #
        # Print message to log file
        #
        print LOG_FILE "$text\n";
        close(LOG_FILE);
    }
}

#**********************************************************************
#
# Name: Write_Log_Header
#
# Parameters: none
#
# Description:
#
#   This function writes the log file header message.
#
#**********************************************************************
sub Write_Log_Header {

    my ($sec, $min, $hour, $mday, $mon, $year);
    my ($date_stamp, $time_stamp);

    #
    # Get current time
    #
    ($sec, $min, $hour, $mday, $mon, $year) =
      ( localtime(time) )[ 0, 1, 2, 3, 4, 5 ];

    #
    # Get full year number (not just offset from 1900).
    #
    $year = 1900 + $year;

    #
    # Adjust the month from 0 based (ie. Jan = 0) to 1 based (ie. Jan = 1).
    #
    $mon++;

    #
    # Get string values for date, YYYY-MM-DD formats
    #
    $date_stamp = sprintf( "%d-%02d-%02d", $year, $mon, $mday );

    #
    # Get full time value as HH:MM:SS format
    #
    $time_stamp = sprintf( "%02d:%02d:%02d", $hour, $min, $sec );

    Write_To_Log("Start install.pl at $time_stamp on $date_stamp");
}

#**********************************************************************
#
# Name: Check_Python
#
# Parameters: none
#
# Description:
#
#   This function checks to see if Python is installed.
#
#**********************************************************************
sub Check_Python {

    my ($assoc_output, $python_output);

    #
    # Check file type association for .py files.
    #
    Write_To_Log("Check python installation");
    print "Test python installation\n";
    $assoc_output = `assoc .py`;

    #
    # Do we have an association for .py files ?
    #
    if ( $assoc_output =~ /\.py=/i ) {
        #
        # Check python version.
        #
        Write_To_Log("Check python version");
        chdir($program_dir);
        unlink("test$$.py");
        open(PYTHON, ">test$$.py");
        print PYTHON "import sys\n";
        print PYTHON "if sys.version_info<(2,3,0):\n";
        print PYTHON "   print 'fail, version less than 2.3.0'\n";
        print PYTHON "else:\n";
        print PYTHON "   print 'pass version greater than 2.3.0'\n";
        print PYTHON "if sys.version_info<(3,0,0):\n";
        print PYTHON "   print 'pass version less than 3.0.0'\n";
        print PYTHON "else:\n";
        print PYTHON "   print 'fail, version greater than 3.0.0'\n";
        print PYTHON "print sys.version_info\n";
        close(PYTHON);
        $python_output = `.\\test$$.py`;
        unlink("test$$.py");

        #
        # Is the python version too old ? or too new ?
        #
        Write_To_Log("Python test output $python_output");
        if ( ($python_output =~ /fail/i) ||
             ( ! ($python_output =~ /pass/i) ) ) {
            Write_To_Log("Invalid Python version found");
            print "\n*****\n";
            print "Invalid Python version found, must be greater than 2.3.0, less than 3.0.0\n";
            print "\n*****\n";
            Write_To_Log("Failed install.pl");
            Exit_With_Pause(1);
        }
    }
    else {
        #
        # Install Python
        #
        Write_To_Log("The installer can not find Python on this computer");
        Write_To_Log("  assoc .py");
        Write_To_Log("  $assoc_output");
        Write_To_Log("Failed install.pl");
        print "\n*****\n";
        print "The installer can not find Python on this computer\n";
        print "\n*****\n";
        Exit_With_Pause(1);
    }
}

#**********************************************************************
#
# Name: Check_Perl
#
# Parameters: none
#
# Description:
#
#   This function checks the verion of Perl that is installed.
#
#**********************************************************************
sub Check_Perl {
    my ($major, $minor, $version);

    #
    # Get the output of perl --version
    #
    Write_To_Log("Check Perl version");
    print "Check Perl version\n";
    $version = `perl.exe --version`;
    Write_To_Log("  Version = $version");

    #
    # Is this ActiveState Perl ?
    #
    if ( $version =~ /ActiveState/i ) {
        $perl_install = "ActiveState";

        #
        # Check Perl version for ActiveState Perl
        #
        ($major, $minor) = $] =~ /^(\d+)\.(\d\d\d).*$/;
        Write_To_Log("Perl $major.$minor installed on system");
        if ( $major != 5 ) {
            Write_To_Log("Unsupported Perl version $major.$minor");
            print "\n*****\n";
            print "Unsupported Perl version $major.$minor\n";
            print "\n*****\n";
            Exit_With_Pause(1);
        }
        elsif ( $minor == 14 ) {
            #
            # Perl 5.14 installed, a valid release
            #
        }
        else {
            Write_To_Log("Unsupported Perl version $major.$minor");
            print "\n*****\n";
            print "Unsupported Perl version $major.$minor\n";
            print "\n*****\n";
            Exit_With_Pause(1);
        }
    }
    else {
        $perl_install = "";
    }
}

#**********************************************************************
#
# Name: Install_Win32_GUI_On_ActiveState_Perl
#
# Parameters: none
#
# Description:
#
#   This function installs the Win32::GUI package on ActiveState Perl
# using ppm.
#
#**********************************************************************
sub Install_Win32_GUI_On_ActiveState_Perl {
    my ($rc);

    #
    # Check that the Win32::GUI module files are present
    #
    Write_To_Log("Installing Win32-GUI-1.06-PPM-5.14");
    if ( ! -d "$program_dir/Win32-GUI-1.06-PPM-5.14" ) {
        print "\n*****\n";
        print String_Value("Missing Win32::GUI folder") . "\n";
        print " --> $program_dir/Win32-GUI-1.06-PPM-5.14\n";
        print "\n*****\n";
        Write_To_Log("Missing Win32::GUI folder");
        Write_To_Log("  --> $program_dir/Win32-GUI-1.06-PPM-5.14");
        Exit_With_Pause(1);
    }
    if ( ! -f "$program_dir/Win32-GUI-1.06-PPM-5.14/Win32-GUI-1.06.ppd" ) {
        print "\n*****\n";
        print String_Value("Missing Win32::GUI file") . "\n";
        print " --> $program_dir/Win32-GUI-1.06-PPM-5.14/Win32-GUI-1.06.ppd\n";
        print "\n*****\n";
        Write_To_Log("Missing Win32::GUI file");
        Write_To_Log(" --> $program_dir/Win32-GUI-1.06-PPM-5.14/Win32-GUI-1.06.ppd");
        Exit_With_Pause(1);
    }

    #
    # Install the Win32::GUI module
    #
    chdir("$program_dir/Win32-GUI-1.06-PPM-5.14");
    print "ppm install ./Win32-GUI-1.06.ppd\n";
    Write_To_Log("ppm install ./Win32-GUI-1.06.ppd");
    $rc = system("ppm install ./Win32-GUI-1.06.ppd");

    #
    # Was install successful ?
    #
    if ( $rc != 0 ) {
        print "\n*****\n";
        print "ppm install ./Win32-GUI-1.06.ppd failed $rc\n";
        print "\n*****\n";
        Write_To_Log("ppm install ./Win32-GUI-1.06.ppd failed, rc = $rc");
        Exit_With_Pause(1);
    }
    chdir($program_dir);
    Write_To_Log("install Win32::GUI complete");
}

#**********************************************************************
#
# Name: Install_Win32_GUI_On_Perl
#
# Parameters: none
#
# Description:
#
#   This function installs the Win32::GUI package on the Perl
# installation using make.
#
#**********************************************************************
sub Install_Win32_GUI_On_Perl {

    my ($output);

    #
    # Check that the Win32::GUI module files are present
    #
    Write_To_Log("Installing Win32-GUI-1.06");
    if ( ! -d "$program_dir/Win32-GUI-1.06" ) {
        print "\n*****\n";
        print String_Value("Missing Win32::GUI folder") . "\n";
        print " --> $program_dir/Win32-GUI-1.06\n";
        print "\n*****\n";
        Write_To_Log("Missing Win32::GUI folder");
        Write_To_Log("  --> $program_dir/Win32-GUI-1.06");
        Exit_With_Pause(1);
    }

    #
    # Install the Win32::GUI module
    #
    chdir("$program_dir/Win32-GUI-1.06");
    print "  perl.exe Makefile.PL\n";
    Write_To_Log("perl.exe Makefile.PL");
    $output = `perl.exe Makefile.PL`;
    Write_To_Log("Output of perl.exe Makefile.PL");
    Write_To_Log("$output\n");
    print "  dmake\n";
    Write_To_Log("dmake");
    $output = `dmake 2>\&1`;
    Write_To_Log("Output of dmake");
    Write_To_Log("$output\n");
    print "  dmake install\n";
    Write_To_Log("dmake install");
    $output = `dmake install 2>\&1`;
    Write_To_Log("Output of dmake install");
    Write_To_Log("$output\n");

    #
    # Install complete, it will be tested later to see if 
    # it was successful or not.
    #
    chdir($program_dir);
    Write_To_Log("install Win32::GUI complete");
}

#**********************************************************************
#
# Name: Install_Win32_GUI
#
# Parameters: none
#
# Description:
#
#   This function installs the Win32::GUI package on the system.
#
#**********************************************************************
sub Install_Win32_GUI {
    my ($rc, $major, $minor);

    #
    # Check to see if Win32::GUI is already present
    #
    Write_To_Log("Check for Win32::GUI");
    print "Check for Win32::GUI\n";
    $rc = eval 'use Win32::GUI(); 1';
    if ( $rc ) {
        Write_To_Log("Win32::GUI already installed");
    }
    else {
        #
        # Install Win32_GUI system
        #
        print "Install Win32::GUI\n";
        if ( $perl_install eq "ActiveState" ) {
            Install_Win32_GUI_On_ActiveState_Perl();
        }
        else {
            Install_Win32_GUI_On_Perl();
        }

        #
        # Check if the install of Win32::GUI was successful
        #
        Write_To_Log("Check for Win32::GUI after install");
        $rc = eval 'use Win32::GUI(); 1';
        if ( ! $rc ) {
            Write_To_Log("Win32::GUI install failed");
            print "\n*****\n";
            print "Missing Perl module Win32::GUI\n";
            print "\n*****\n";
            Write_To_Log(" rc = $rc");
            Exit_With_Pause(1);
        }
    }
}

#**********************************************************************
#
# Name: Register_Installation
#
# Parameters: none
#
# Description:
#
#   This function creates a registration file for this tool.
#
#**********************************************************************
sub Register_Installation {

    my ($host, $sec, $min, $hour, $mday, $mon, $year);
    my ($version);

    #
    # Open registration file
    #
    Write_To_Log("Create registration file");
    open (REGISTER, "> $program_dir/registration.txt") ||
        die "Error, failed to create registration file\n";

    #
    # Get host name for this workstation
    #
    $host = hostname;

    #
    # Get current time/date
    #
    ( $sec, $min, $hour, $mday, $mon, $year ) =
      ( localtime(time) )[ 0, 1, 2, 3, 4, 5 ];

    #
    # Get full year number (not just offset from 1900).
    #
    $year = 1900 + $year;

    #
    # Adjust the month from 0 based (ie. Jan = 0) to 1 based (ie. Jan = 1).
    #
    $mon++;

    #
    # Get WPSS_Tool release version
    #
    if ( open(VERSION, "$program_dir/version.txt") ) {
        $version = <VERSION>;
        chomp($version);
        close(VERSION);
    }
    else {
        $version = "Unknown";
    }

    #
    # Write out registration information.
    #   Host name, date, tool version, ...
    #
    printf(REGISTER "Date: %4d-%02d-%02d %02d:%02d\n", $year, $mon, $mday,
           $hour, $min);
    printf(REGISTER "Host: %s\n", $host);
    printf(REGISTER "Version: %s\n", $version);

    #
    # Close registration file
    #
    close(REGISTER);
}

#**********************************************************************
#
# Name: Delete_Everything
#
# Parameters: none
#
# Description:
#
#   Deletes everything related to this install script.
#
#**********************************************************************
sub Delete_Everything(){
    Write_To_Log("Remove registration file");
    unlink ("$program_dir/registration.txt");
}

#**********************************************************************
#
# Name: Create_Shortcuts
#
# Parameters: none
#
# Description:
#
#   This function creates desktop sortcuts for the tools on
# Windows based systems.
#
#**********************************************************************
sub Create_Shortcuts {

    my ($desktop, $rc);

    #
    # Is this not a Windows system ?
    #
    if ( ! ($^O =~ /MSWin32/) ) {
        return;
    }
    Write_To_Log("Create desktop shortcuts");

    #
    # Check for path to the user's home directory
    #
    if ( ! defined($ENV{"USERPROFILE"}) ) {
        return;
    }
    $desktop = $ENV{"USERPROFILE"} . "/Desktop";
    if ( ! -d $desktop ) {
        return;
    }
    Write_To_Log("Desktop path = $desktop");

    #
    # Do we already have shortcuts ?
    #
    if ( (-f "$desktop/WPSS_Tool.lnk")
         && (-f "$desktop/Open_Data_Tool.lnk") ) {
        Write_To_Log("Shortcut files already exist");
        return;
    }

    #
    # Create a temporary VB script to create shortcut files
    #
    print "Create desktop shortcuts\n";
    Write_To_Log("Create shortcut VB script for WPSS_Tool.lnk");
    unlink("CreateShortcut.vbs");
    if ( ! open(VB, "> CreateShortcut.vbs") ) {
        print "Failed to create shortcuts\n";
        Exit_With_Pause(1);
    }
    print VB 
"Set oWS = WScript.CreateObject(\"WScript.Shell\")
sLinkFile = \"$desktop\\WPSS_Tool.lnk\"
Set oLink = oWS.CreateShortcut(sLinkFile)
oLink.TargetPath = \"$program_dir\\wpss_tool.pl\"
oLink.Save";
    close(VB);

    #
    # Run the VB script to generate the shortcuts
    #
    Write_To_Log("Running cscript CreateShortcut.vbs");
    $rc = `cscript CreateShortcut.vbs 2>\&1`;
    Write_To_Log("cscript CreateShortcut.vbs return code = $rc");

    unlink("CreateShortcut.vbs");
    if ( ! open(VB, "> CreateShortcut.vbs") ) {
        print "Failed to create shortcuts\n";
        Exit_With_Pause(1);
    }
    Write_To_Log("Create shortcut VB script for Open_Data_Tool.lnk");
    print VB
"Set oWS = WScript.CreateObject(\"WScript.Shell\")
sLinkFile = \"$desktop\\Open_Data_Tool.lnk\"
Set oLink = oWS.CreateShortcut(sLinkFile)
oLink.TargetPath = \"$program_dir\\open_data_tool.pl\"
oLink.Save";
    close(VB);

    #
    # Run the VB script to generate the shortcuts
    #
    Write_To_Log("Running cscript CreateShortcut.vbs");
    $rc = `cscript CreateShortcut.vbs 2>\&1`;
    Write_To_Log("cscript CreateShortcut.vbs return code = $rc");
    unlink("CreateShortcut.vbs");

    #
    # Do the shortcuts exist ?
    #
    if ( (! -f "$desktop/WPSS_Tool.lnk")
         || (! -f "$desktop/Open_Data_Tool.lnk") ) {
        print "Failed to create desktop shortcuts\n";
        Write_To_Log("Failed to create desktop shortcuts");
        Exit_With_Pause(1);
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
print "Starting install.pl\n";

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
# Process command-line options
#
foreach (@ARGV) {
    if ( /uninstall/ ) {
        $uninstall = 1;
    }
    elsif ( /-no_pause/ ) {
        $pause_before_exit = 0;
    }
}

#
# Get the language of this system
#
Set_Language();

#
# Remove any exist installation log file and write log header
#
if ( ! $uninstall ) {
    unlink("$program_dir/logs/install.log");
}
Write_Log_Header();

#
# Run install/uninstall script
#
if ($uninstall){
    #
    # Delete the installation
    #
    Delete_Everything();
}else{
    #
    # Check for Python
    #
    Check_Python();

    #
    # Check for Perl version
    #
    Check_Perl();

    #
    # Install the Win32::GUI module
    # 
    Install_Win32_GUI();

    #
    # Create supporting directories
    #
    foreach $dir (@supporting_directories) {
        if ( ! -d "$program_dir/$dir" ) {
            Write_To_Log("Create directory $dir");
            mkdir("$program_dir/$dir", 0755);
        }
    }

    #
    # Register the tool installation
    #
    Register_Installation();

    #
    # Create desktop shortcuts
    #
    Create_Shortcuts();
}

#
# Installation complete
#
Write_To_Log("Completed install.pl");
print "Completed install.pl\n";
Exit_With_Pause(0);

