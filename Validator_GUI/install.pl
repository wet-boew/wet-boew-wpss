#!/usr/bin/perl -w
#***********************************************************************
#
# Name:   install.pl
#
# $Revision: 1158 $
# $URL: svn://10.36.148.185/Validator_GUI/Tools/install.pl $
# $Date: 2019-01-18 13:27:07 -0500 (Fri, 18 Jan 2019) $
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
use File::Copy;
use File::Path qw(make_path remove_tree);
use Cwd;
use Sys::Hostname;
#use Win32::TieRegistry( Delimiter=>"#", ArrayValues=>0 );
use Win32::TieRegistry;
use Archive::Zip;

#***********************************************************************
#
# Program global variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);
my ($line, $python_path, $is_windows);
my ($perl_install) = "";
my ($debug) = 0;
my ($uninstall) = 0;
my ($pause_before_exit) = 1;
my ($default_python_path) = "/usr/bin/python";
my ($default_perl_path) = "/usr/bin/perl";


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
        #
        # Did install fail ?
        #
        if ( $status != 0 ) {
            print "\n";
            print "Failed install.pl\n";
            print "Check $program_dir/logs/install.log for details\n";
            print "\n";
        }
        
        #
        # Wait for user
        #
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
    if ( $is_windows ) {
        $pound = $Registry->Delimiter("/");
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
# Name: OS_Version
#
# Parameters: none
#
# Description:
#
#   This function prints the operating system version to the
# log file.
#
#**********************************************************************
sub OS_Version {
    my ($version);

    #
    # Get the os version
    #
    Write_To_Log("Get OS version");
    if ( $is_windows ) {
        $version = `wmic os get Caption,CSDVersion /value 2>\&1`;
        Write_To_Log("  Windows version = $version");
    }
    else {
        $version = `uname -a 2>\&1`;
        Write_To_Log("  Linux version = $version");
    }
}

#**********************************************************************
#
# Name: Check_Java
#
# Parameters: none
#
# Description:
#
#   This function checks the verion of Java that is installed.
#
#**********************************************************************
sub Check_Java {
    my ($version, $lead, $trail, $version_number);
    my ($major, $minor, $maint);

    #
    # Get the output of java -version
    #
    Write_To_Log("Check Java version");
    print "Check Java version\n";
    $version = `java -version 2>\&1`;
    Write_To_Log("  Version = $version");

    #
    # Try to get the version number from the version output
    #
    ($lead, $version_number, $trail) = $version =~ /^(.* version ")(\d+\.\d+\.\d+)(.*)$/m;
    if ( defined($version_number) ) {
        ($major, $minor, $maint) = $version_number =~ /^(\d+)\.(\d+)\.(\d+)$/;
        Write_To_Log("  Version major = $major, Minor = $minor, Maintenance = $maint");
    }
    else {
        $major = 0;
        $minor = 0;
        $version_number = "0.0";
        Write_To_Log("  Version number = $version_number");
    }

    #
    # Is this Oracle Java version 8 (major = 1, minor = 8) or greater ?
    #
    if ( ($lead =~ /^java /i) && ($major == 1) && ($minor >= 8) ) {
        #
        # Have Java 8
        #
    }
    #
    # Is this Open Java version 11 (major = 11) or greater ?
    #
    elsif ( ($lead =~ /^openjdk /i) && ($major == 11) ) {
        #
        # Have Openjdk Java 11
        #
    }
    else {
        Write_To_Log("Unsupported Java version $version");
        print "\n*****\n";
        print "Unsupported Java version $version\n";
        print "\n*****\n";
        Exit_With_Pause(1);
    }
}

#**********************************************************************
#
# Name: Install_Setuptools_Python_Module
#
# Parameters: none
#
# Description:
#
#   This function installs the setuptools module.
#
#**********************************************************************
sub Install_Setuptools_Python_Module {

    my ($output, $python_output, $zip_file);

    #
    # Extract the setuptools module
    #
    chdir("$program_dir/python/");
    $zip_file = Archive::Zip->new("setuptools-29.0.1.zip");
    $zip_file->extractTree();

    #
    # Build the setuptools module
    #
    Write_To_Log("Build python module 'setuptools'");
    chdir("$program_dir/python/setuptools-29.0.1");
    print "setup.py build setuptools\n";
    Write_To_Log("setup.py build");
    if ( $is_windows ) {
        $python_output = `.\\setup.py build 2>\&1`;
    }
    else {
        $python_output = `python setup.py build 2>\&1`;
    }

    #
    # Was the build phase successful ?
    #
    if ( ($python_output =~ /Error/i) &&
          ( ! ($python_output =~ /Copying/i) ) ) {
        print "\n*****\n";
        print "setup.py build failed for setuptools\n";
        print "\n*****\n";
        Write_To_Log("setup.py build failed for setuptools, output = $python_output");
        Exit_With_Pause(1);
    }
    else {
        Write_To_Log("build setuptools complete");
        Write_To_Log("Output = $python_output");
    }

    #
    # Install the setuptools module
    #
    Write_To_Log("Install python module 'setuptools'");
    print "setup.py install setuptools\n";
    Write_To_Log("setup.py install --root $program_dir\\python");
    if ( $is_windows ) {
        $python_output = `.\\setup.py install --root \"$program_dir\\python\" 2>\&1`;
    }
    else {
        $python_output = `python setup.py install --root \"$program_dir/python\" 2>\&1`;
    }

    #
    # Was the build phase successful ?
    #
    if ( ($python_output =~ /Error/i) &&
          ( ! ($python_output =~ /Copying/i) ) ) {
        print "\n*****\n";
        print "setup.py install --root $program_dir\\python failed for setuptools\n";
        print "\n*****\n";
        Write_To_Log("setup.py install --root $program_dir\\python failed for setuptools, output = $python_output");
        Exit_With_Pause(1);
    }
    else {
        Write_To_Log("install setuptools complete");
        Write_To_Log("Output = $python_output");
    }
    
    #
    # Check python module.
    #
    Write_To_Log("Test install of python module 'setuptools'");
    chdir($program_dir);
    unlink("test$$.py");
    open(PYTHON, ">test$$.py");
    print PYTHON "from setuptools import setup\n";
    print PYTHON "print 'pass'\n";
    close(PYTHON);
    if ( $is_windows ) {
        $python_output = `.\\test$$.py 2>\&1`;
    }
    else {
        $python_output = `python test$$.py 2>\&1`;
    }
    unlink("test$$.py");

    #
    # Was the module found ?
    #
    Write_To_Log("Python module test setuptools output $python_output");
    if ( ($python_output =~ /No module named setuptools/i) ||
         ( ! ($python_output =~ /pass/i) ) ) {
        print "\n*****\n";
        print "Python module setuptools not found\n";
        print "\n*****\n";
        Write_To_Log("Python module setuptools not found");
        Write_To_Log("Failed install.pl");
        Exit_With_Pause(1);
    }
}

#**********************************************************************
#
# Name: Install_Functools32_Python_Module
#
# Parameters: none
#
# Description:
#
#   This function installs the functools32 module, which is used
# by the jsonschema module.
#
#**********************************************************************
sub Install_Functools32_Python_Module {

    my ($output, $python_output, $zip_file);

    #
    # Extract the functools32 module
    #
    chdir("$program_dir/python/");
    $zip_file = Archive::Zip->new("functools32-3.2.3-2.zip");
    $zip_file->extractTree();

    #
    # Build the functools32 module
    #
    Write_To_Log("Build python module 'functools32'");
    chdir("$program_dir/python/functools32-3.2.3-2");
    print "setup.py build functools32\n";
    Write_To_Log("setup.py build");
    if ( $is_windows ) {
        $python_output = `.\\setup.py build 2>\&1`;
    }
    else {
        $python_output = `python setup.py build 2>\&1`;
    }

    #
    # Was the build phase successful ?
    #
    if ( ($python_output =~ /Error/i) &&
          ( ! ($python_output =~ /Copying/i) ) ) {
        print "\n*****\n";
        print "setup.py build failed for functools32\n";
        print "\n*****\n";
        Write_To_Log("setup.py build failed for functools32, output = $python_output");
        Exit_With_Pause(1);
    }
    else {
        Write_To_Log("build functools32 complete");
        Write_To_Log("Output = $python_output");
    }

    #
    # Install the functools32 module
    #
    Write_To_Log("Install python module 'functools32'");
    print "setup.py install functools32\n";
    Write_To_Log("setup.py install --root $program_dir\\python");
    if ( $is_windows ) {
        $python_output = `.\\setup.py install --root \"$program_dir\\python\" 2>\&1`;
    }
    else {
        $python_output = `python setup.py install --root \"$program_dir/python\" 2>\&1`;
    }

    #
    # Was the build phase successful ?
    #
    if ( ($python_output =~ /Error/i) &&
          ( ! ($python_output =~ /Copying/i) ) ) {
        print "\n*****\n";
        print "setup.py install --root $program_dir\\python failed for functools32\n";
        print "\n*****\n";
        Write_To_Log("setup.py install --root $program_dir\\python failed for functools32, output = $python_output");
        Exit_With_Pause(1);
    }
    else {
        Write_To_Log("install functools32 complete");
        Write_To_Log("Output = $python_output");
    }
}

#**********************************************************************
#
# Name: Install_Vcversioner_Python_Module
#
# Parameters: none
#
# Description:
#
#   This function installs the vcversioner module, which is used
# by the jsonschema module.
#
#**********************************************************************
sub Install_Vcversioner_Python_Module {

    my ($output, $python_output, $zip_file);

    #
    # Extract the vcversioner module
    #
    chdir("$program_dir/python/");
    $zip_file = Archive::Zip->new("vcversioner-2.16.0.0.zip");
    $zip_file->extractTree();

    #
    # Build the vcversioner module
    #
    Write_To_Log("Build python module 'vcversioner'");
    chdir("$program_dir/python/vcversioner-2.16.0.0");
    print "setup.py build vcversioner\n";
    Write_To_Log("setup.py build");
    if ( $is_windows ) {
        $python_output = `.\\setup.py build 2>\&1`;
    }
    else {
        $python_output = `python setup.py build 2>\&1`;
    }

    #
    # Was the build phase successful ?
    #
    if ( ($python_output =~ /Error/i) &&
          ( ! ($python_output =~ /Copying/i) ) ) {
        print "\n*****\n";
        print "setup.py build failed for vcversioner\n";
        print "\n*****\n";
        Write_To_Log("setup.py build failed for vcversioner, output = $python_output");
        Exit_With_Pause(1);
    }
    else {
        Write_To_Log("build vcversioner complete");
        Write_To_Log("Output = $python_output");
    }

    #
    # Install the vcversioner module
    #
    Write_To_Log("Install python module 'vcversioner'");
    print "setup.py install vcversioner\n";
    Write_To_Log("setup.py install --root $program_dir\\python");
    if ( $is_windows ) {
        $python_output = `.\\setup.py install --root \"$program_dir\\python\" 2>\&1`;
    }
    else {
        $python_output = `python setup.py install --root \"$program_dir/python\" 2>\&1`;
    }

    #
    # Was the build phase successful ?
    #
    if ( ($python_output =~ /Error/i) &&
          ( ! ($python_output =~ /Copying/i) ) ) {
        print "\n*****\n";
        print "setup.py install --root $program_dir\\python failed for vcversioner\n";
        print "\n*****\n";
        Write_To_Log("setup.py install --root $program_dir\\python failed for vcversioner, output = $python_output");
        Exit_With_Pause(1);
    }
    else {
        Write_To_Log("install vcversioner complete");
        Write_To_Log("Output = $python_output");
    }
}

#**********************************************************************
#
# Name: Install_Jsonschema_Python_Module
#
# Parameters: none
#
# Description:
#
#   This function installs the jsonschema module.
#
#**********************************************************************
sub Install_Jsonschema_Python_Module {

    my ($output, $python_output, $zip_file);

    #
    # Install prerequisit module vcversioner
    #
    Install_Vcversioner_Python_Module();
    
    #
    # Extract the jsonschema module
    #
    chdir("$program_dir/python/");
    $zip_file = Archive::Zip->new("jsonschema-2.6.0.zip");
    $zip_file->extractTree();

    #
    # Build the jsonschema module
    #
    Write_To_Log("Build python module 'jsonschema'");
    chdir("$program_dir/python/jsonschema-2.6.0");
    print "setup.py build jsonschema\n";
    Write_To_Log("setup.py build");
    if ( $is_windows ) {
        $python_output = `.\\setup.py build 2>\&1`;
    }
    else {
        $python_output = `python setup.py build 2>\&1`;
    }

    #
    # Was there an error when trying to download supporting packages
    #
    if ( $python_output =~ /Download error on https/i ) {
        print "\n*****\n";
        print "setup.py build failed for jsonschema\n";
        print "Failed to download supporting modules, check Internet access\n";
        print "\n*****\n";
        Write_To_Log("setup.py build failed for jsonschema, output = $python_output");
        Exit_With_Pause(1);
    }
    #
    # Was the build phase successful ?
    #
    elsif ( ($python_output =~ /Error/i) &&
          ( ! ($python_output =~ /Copying/i) ) ) {
        print "\n*****\n";
        print "setup.py build failed for jsonschema\n";
        print "\n*****\n";
        Write_To_Log("setup.py build failed for jsonschema, output = $python_output");
        Exit_With_Pause(1);
    }
    else {
        Write_To_Log("build jsonschema complete");
        Write_To_Log("Output = $python_output");
    }

    #
    # Install the jsonschema module
    #
    Write_To_Log("Install python module 'jsonschema'");
    print "setup.py install jsonschema\n";
    Write_To_Log("setup.py install --root $program_dir\\python");
    if ( $is_windows ) {
        $python_output = `.\\setup.py install --root \"$program_dir\\python\" 2>\&1`;
    }
    else {
        $python_output = `python setup.py install --root \"$program_dir/python\" 2>\&1`;
    }

    #
    # Was the build phase successful ?
    #
    if ( ($python_output =~ /Error/i) &&
          ( ! ($python_output =~ /Copying/i) ) ) {
        print "\n*****\n";
        print "setup.py install --root $program_dir\\python failed for jsonschema\n";
        print "\n*****\n";
        Write_To_Log("setup.py install --root $program_dir\\python failed for jsonschema, output = $python_output");
        Exit_With_Pause(1);
    }
    else {
        Write_To_Log("install jsonschema complete");
        Write_To_Log("Output = $python_output");
    }
    
    #
    # jsonschema requires the functools32 module
    #
    Install_Functools32_Python_Module();

    #
    # Check python module jsonschema.
    #
    Write_To_Log("Test install of python module 'jsonschema'");
    chdir($program_dir);
    unlink("test$$.py");
    open(PYTHON, ">test$$.py");
    print PYTHON "import jsonschema\n";
    print PYTHON "print 'pass'\n";
    close(PYTHON);
    if ( $is_windows ) {
        $python_output = `.\\test$$.py 2>\&1`;
    }
    else {
        $python_output = `python test$$.py 2>\&1`;
    }
    unlink("test$$.py");

    #
    # Was the module found ?
    #
    Write_To_Log("Python module test output $python_output");
    if ( ($python_output =~ /No module named jsonschema/i) ||
         ( ! ($python_output =~ /pass/i) ) ) {
        print "\n*****\n";
        print "Python module jsonschema not found\n";
        print "\n*****\n";
        Write_To_Log("Python module jsonschema not found");
        Write_To_Log("Failed install.pl");
        Exit_With_Pause(1);
    }
}

#**********************************************************************
#
# Name: Check_Python_Modules
#
# Parameters: none
#
# Description:
#
#   This function checks to see if required Python modules
# are installed.
#
#**********************************************************************
sub Check_Python_Modules {

    my ($module, $python_output);

    #
    # Check for required python modules
    #
    Write_To_Log("Check python modules");
    print "Check python modules\n";

    #
    # Check python module setuptools.
    #
    Write_To_Log("Check python module 'setuptools'");
    chdir($program_dir);
    unlink("test$$.py");
    open(PYTHON, ">test$$.py");
    print PYTHON "\n";
    print PYTHON "from setuptools import setup\n";
    print PYTHON "print 'pass'\n";
    close(PYTHON);
    if ( $is_windows ) {
        $python_output = `.\\test$$.py 2>\&1`;
    }
    else {
        $python_output = `python test$$.py 2>\&1`;
    }
    unlink("test$$.py");

    #
    # Does python module setup exist?
    #
    Write_To_Log("Python module 'setuptools' test output $python_output");
    if ( ($python_output =~ /No module named setuptools/i) ||
         ( ! ($python_output =~ /pass/i) ) ) {

        #
        # Install the setuptools module
        #
        Install_Setuptools_Python_Module();
    }

    #
    # Check python module jsonschema.
    #
    Write_To_Log("Check python module 'jsonschema'");
    chdir($program_dir);
    unlink("test$$.py");
    open(PYTHON, ">test$$.py");
    print PYTHON "import jsonschema\n";
    print PYTHON "print 'pass'\n";
    close(PYTHON);
    if ( $is_windows ) {
        $python_output = `.\\test$$.py 2>\&1`;
    }
    else {
        $python_output = `python test$$.py 2>\&1`;
    }
    unlink("test$$.py");

    #
    # Does python module jsonschema exist?
    #
    Write_To_Log("Python module 'jsonschema' test output $python_output");
    if ( ($python_output =~ /No module named jsonschema/i) ||
         ( ! ($python_output =~ /pass/i) ) ) {
         
        #
        # Install the jsonschema module
        #
        Install_Jsonschema_Python_Module();
    }
}

#**********************************************************************
#
# Name: Set_Hash_Bang
#
# Parameters: file - name of file
#             hash_bang_line - the hash bang line required
#
# Description:
#
#   This function reads the named file to check if it has the required
# hash bang line.  If ti does not, the line is inserted into the file.
#
#**********************************************************************
sub Set_Hash_Bang {
    my ($file, $hash_bang_line) = @_;

    my ($dir, $new_file, $line, @fields);

    #
    # Open the file to get the first line.
    #
    print "Set_Hash_Bang of file $file to $hash_bang_line\n" if $debug;
    if ( ! open(OLD_FILE, "$file") ) {
        print "\n*****\n";
        print "Failed to open file $file\n";
        print "\n*****\n";
        Write_To_Log("Failed to to open file $file");
        Write_To_Log("Failed install.pl");
        Exit_With_Pause(1);
    }

    #
    # Get the first line and split on whitespace.  This gives us the
    # hash bang and arguments (if present).
    #
    Write_To_Log("Check hash bang of file $file");
    $line = <OLD_FILE>;
    @fields = split(/\s+/, $line);

    #
    # Do we have a hash bang line?
    #
    if ( defined($fields[0]) && ($fields[0] =~ /^#!/) ) {
        #
        # Does the hash bang match the one we want?
        #
        if ( $fields[0] eq $hash_bang_line ) {
            #
            # Hash bangs match, we don't have anything to do
            #
            Write_To_Log("Hash bang value matches required value");
            close(OLD_FILE);
        }
        else {
            #
            # Have to insert a new hash bang line.  Copy old file into
            # a new file with the required hash bang line.
            #
            $new_file = "$file.new";
            unlink($new_file);
            if ( ! open(NEW_FILE, "> $new_file") ) {
                print "\n*****\n";
                print "Failed to create file in directory $program_dir/bin\n";
                print "\n*****\n";
                Write_To_Log("Failed to create file in $new_file in directory $program_dir/bin");
                Write_To_Log("Failed install.pl");
                Exit_With_Pause(1);
            }

            #
            # Write new hash bang with any optional arguments
            #
            print NEW_FILE "$hash_bang_line";
            shift(@fields);
            if ( @fields > 0 ) {
                print NEW_FILE " " . join(" ", @fields);
            }
            print NEW_FILE "\n";

            #
            # Copy the rest of the lines from the old to the new file
            #
            while ( $line = <OLD_FILE> ) {
                print NEW_FILE "$line";
            }
            close(OLD_FILE);
            close(NEW_FILE);

            #
            # Remove the old file and rename the new one to the old file's
            # name.
            #
            unlink($file);
            copy($new_file, $file);
            unlink($new_file);
        }
    }
    else {
        print "No hash bang line in file\n" if $debug;
        Write_To_Log("No hash bang line in file");
    }
}

#**********************************************************************
#
# Name: Set_Python_Hash_Bang
#
# Parameters: none
#
# Description:
#
#   This function sets the hash bang line (first line) of Python
# programs to ensure the proper python installation is used.  The
# python that is in the current path is used if it is different
# from the default (/usr/bin/python).
#
#**********************************************************************
sub Set_Python_Hash_Bang {

    my ($python_path, $dir, $file, $rc);

    #
    # Is this a Windows install, if so return as nothing needs to be done
    #
    if ( $is_windows ) {
        return;
    }
    
    #
    # Get path to python from the current PATH.
    #
    $python_path = `which python`;
    chomp($python_path);
    
    #
    # Is the path different from the default?
    #
    if ( $python_path eq $default_python_path ) {
        Write_To_Log("Python path matches default path");
        return;
    }
    
    #
    # Check for .py files in the bin directory
    #
    chdir("$program_dir/bin");
    opendir($dir, ".");
    while ( $file = readdir $dir ) {
        if ( -f $file && ($file =~ /\.py$/) ) {
            #
            # Create a copy of the python script with a new hash bang line
            #
            print "Python file = $file\n" if $debug;
            Set_Hash_Bang($file, "#!$python_path");
        }
    }
    closedir($dir);
    chdir("$program_dir");
    
    #
    # Since this is not the default python location, we have to create
    # a link in the python modules folder to allow the locally installed
    # modules be found.  The expectation is that modules are under a
    # usr/local path.
    #
    # Get the bin directory for python, then the "local" directory
    # and finally the top level directory for the local python installation.
    #
    $python_path = dirname($python_path);
    $python_path = dirname($python_path);
    $python_path = dirname($python_path);
    
    #
    # Create a link in the python modules folder to this python path. The
    # link name is "usr".
    #
    chdir("$program_dir/python");
    $python_path =~ s/^\///g;
    Write_To_Log("Create python \"usr/\" link as ln -s \"$python_path\" usr");
    $rc = system("ln -s \"$python_path\" usr");
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

    my ($assoc_output, $python_output, $major, $minor);

    #
    # Check file type association for .py files.
    #
    Write_To_Log("Check python installation");
    print "Test python installation\n";
    if ( $is_windows ) {
        $assoc_output = `assoc .py`;
    }
    else {
        $assoc_output = ".py=";
    }

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
        print PYTHON "if sys.version_info<(2,7,0):\n";
        print PYTHON "   print 'fail, version less than 2.7.0'\n";
        print PYTHON "else:\n";
        print PYTHON "   print 'pass version greater than 2.7.0'\n";
        print PYTHON "if sys.version_info<(3,0,0):\n";
        print PYTHON "   print 'pass version less than 3.0.0'\n";
        print PYTHON "else:\n";
        print PYTHON "   print 'fail, version greater than 3.0.0'\n";
        print PYTHON "print sys.version_info\n";
        print PYTHON "print 'Version: major:',sys.version_info[0],' minor:',sys.version_info[1]\n";
        close(PYTHON);
        if ( $is_windows ) {
            $python_output = `.\\test$$.py 2>\&1`;
        }
        else {
            $python_output = `python test$$.py 2>\&1`;
        }
        unlink("test$$.py");

        #
        # Is the python version too old ? or too new ?
        #
        Write_To_Log("Python test output $python_output");
        if ( ($python_output =~ /fail/i) ||
             ( ! ($python_output =~ /pass/i) ) ) {
            Write_To_Log("Invalid Python version found");
            print "\n*****\n";
            print "Invalid Python version found, must be greater than 2.7.0, less than 3.0.0\n";
            print "\n*****\n";
            Write_To_Log("Failed install.pl");
            Exit_With_Pause(1);
        }

        #
        # Get major and minor release numbers
        #
        ($major) = $python_output =~ /major:\s*(\d).*/im;
        ($minor) = $python_output =~ /minor:\s*(\d).*/im;
        if ( (! defined($major)) || (! defined($minor)) ) {
            Write_To_Log("Could not determine python version major and minor numbers");
            print "\n*****\n";
            print "Could not determine python version major and minor numbers\n";
            print "\n*****\n";
            Write_To_Log("Failed install.pl");
            Exit_With_Pause(1);

        }
        Write_To_Log("Python version major = $major, minor = $minor");
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
    
    #
    # Get the directory path that python is installed in
    #
    unlink("test$$.py");
    open(PYTHON, ">test$$.py");
    print PYTHON "import os\n";
    print PYTHON "import sys\n";
    print PYTHON "print os.path.dirname(sys.executable)\n";
    close(PYTHON);
    if ( $is_windows ) {
        $python_output = `.\\test$$.py 2>\&1`;
    }
    else {
        $python_output = `python test$$.py 2>\&1`;
    }
    unlink("test$$.py");
    Write_To_Log("Python installation path");
    Write_To_Log("  $python_output");

    #
    # Set path to local python packages
    #
    chop($python_output);
    if ( $is_windows ) {
        $python_output =~ s/^[A-Z]://ig;
        $python_path = "$program_dir\\python" . "$python_output\\Lib\\site-packages";
    }
    else {
        $python_output = dirname($python_output);
        $python_path = "$program_dir/python/$python_output/lib/python$major.$minor/site-packages";
    }
    Write_To_Log("python_path = $python_path");
    
    #
    # Set PYTHONPATH environment variable
    #
    if ( defined($ENV{"PYTHONPATH"}) ) {
        $ENV{"PYTHONPATH"} .= ";$python_path";
    }
    else {
        $ENV{"PYTHONPATH"} = "$python_path";
    }
    Write_To_Log("PYTHONPATH environment variable = " . $ENV{"PYTHONPATH"});

    #
    # Check for specific python modules
    #
    Check_Python_Modules();
    
    #
    # Set python hash bang in .py files for Linux
    #
    Set_Python_Hash_Bang();
}

#**********************************************************************
#
# Name: Set_Perl_Hash_Bang
#
# Parameters: none
#
# Description:
#
#   This function sets the hash bang line (first line) of perl
# programs to ensure the proper perl installation is used.  The
# perl that is in the current path is used if it is different
# from the default (/usr/bin/perl).
#
#**********************************************************************
sub Set_Perl_Hash_Bang {

    my ($perl_path, $dir, $file);

    #
    # Is this a Windows install, if so return as nothing needs to be done
    #
    if ( $is_windows ) {
        return;
    }

    #
    # Get path to perl from the current PATH.
    #
    $perl_path = `which perl`;
    chomp($perl_path);

    #
    # Is the path different from the default?
    #
    if ( $perl_path eq $default_perl_path ) {
        Write_To_Log("Perl path matches default path");
        return;
    }

    #
    # Check for .pl files in the current directory
    #
    chdir("$program_dir");
    opendir($dir, ".");
    while ( $file = readdir $dir ) {
        if ( -f $file && ($file =~ /\.pl$/) ) {
            #
            # Create a copy of the perl script with a new hash bang line
            #
            print "Perl file = $file\n" if $debug;
            if ( $file eq "install.pl" ) {
                print "Skip install.pl program\n" if $debug;
            }
            else {
                Set_Hash_Bang($file, "#!$perl_path");
            }
        }
    }
    closedir($dir);

    #
    # Check for .pl files in the bin directory
    #
    chdir("$program_dir/bin");
    opendir($dir, ".");
    while ( $file = readdir $dir ) {
        if ( -f $file && ($file =~ /\.pl$/) ) {
            #
            # Create a copy of the perl script with a new hash bang line
            #
            print "Perl file = $file\n" if $debug;
            Set_Hash_Bang($file, "#!$perl_path");
        }
    }
    closedir($dir);
    chdir("$program_dir");
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
    if ( $is_windows ) {
        $version = `perl.exe --version`;
    }
    else {
        $version = `perl --version`;
    }
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
    elsif ( $version =~ /This is perl/i ) {
        #
        # Check major and minor version numbers
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
        elsif ( $minor < 18 ) {
            Write_To_Log("Unsupported Perl version $major.$minor");
            print "\n*****\n";
            print "Unsupported Perl version $major.$minor\n";
            print "\n*****\n";
            Exit_With_Pause(1);
        }
        
        #
        # Check for possible 64 bit installation.  The Win32::GUI
        # module will not install on a 64 bit installation.
        #
        if ( $version =~ /MSWin32-x64/i ) {
            Write_To_Log("Unsupported 64 bit Perl installation");
            print "\n*****\n";
            print "Unsupported Perl 64 bit Perl installation\n";
            print "  Version = $version\n";
            print "\n*****\n";
            Exit_With_Pause(1);
        }
    }
    else {
        $perl_install = "";
    }

    #
    # Set perl hash bang in .pl files for Linux
    #
    Set_Perl_Hash_Bang();
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

    my ($start_menu, $error, $diag, $file, $message);

    #
    # Remove tool installation folder
    #
    if ( -d $program_dir ) {
        remove_tree($program_dir, {error => \$error});

        #
        # Check for possible errors
        #
        if ( @$error ) {
            print "Error: Failed to remove_tree $program_dir\n";
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

    #
    # Is this not a Windows system ?
    #
    if ( ! ($^O =~ /MSWin32/) ) {
        return;
    }

    #
    # Remove start menu shortcuts
    #
    $start_menu = "C:/ProgramData/Microsoft/Windows/Start Menu/Programs/Web and Open Data Validator";
    if ( -d $start_menu ) {
        remove_tree($start_menu, {error => \$error});

        #
        # Check for possible errors
        #
        if ( @$error ) {
            print "Error: Failed to remove_tree $start_menu\n";
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
}

#**********************************************************************
#
# Name: Create_Shortcuts
#
# Parameters: none
#
# Description:
#
#   This function creates start menu shortcuts for the tools on
# Windows based systems.
#
#**********************************************************************
sub Create_Shortcuts {

    my ($start_menu, $rc);

    #
    # Is this not a Windows system ?
    #
    if ( ! ($^O =~ /MSWin32/) ) {
        return;
    }
    Write_To_Log("Create desktop shortcuts");

    #
    # Check for start menu folder
    #
    $start_menu = "C:/ProgramData/Microsoft/Windows/Start Menu/Programs/Web and Open Data Validator";
    #$start_menu = $ENV{"USERPROFILE"} . "/desktop/Web and Open Data Validator";
    if ( ! -d $start_menu ) {
        Write_To_Log("Create start menu folder $start_menu");
        if ( ! mkdir($start_menu) ) {
            $rc = $!;
            Write_To_Log("Error creating start menu, errno = $rc");
            
            #
            # Are we denied permission?
            #
            if ( $rc =~ /Permission denied/i ) {
                Write_To_Log("Skip creating start menu shortcuts");
                return();
            }
            print "Error creating start menu, errno = $rc\n";
            Exit_With_Pause(1);
        }
        print "Start menu created\n";
    }
    Write_To_Log("Start menu path = $start_menu");

    #
    # Do we already have shortcuts ?
    #
    if ( (-f "$start_menu/WPSS Tool.lnk")
         && (-f "$start_menu/Open Data Tool.lnk") ) {
        Write_To_Log("Shortcut files already exist");
        return;
    }

    #
    # Create a temporary VB script to create shortcut files
    #
    print "Create desktop shortcuts\n";
    Write_To_Log("Create shortcut VB script for WPSS Tool.lnk");
    unlink("CreateShortcut.vbs");
    if ( ! open(VB, "> CreateShortcut.vbs") ) {
        print "Failed to create shortcuts\n";
        Exit_With_Pause(1);
    }
    print VB 
"Set oWS = WScript.CreateObject(\"WScript.Shell\")
sLinkFile = \"$start_menu\\WPSS Tool.lnk\"
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

    #
    # Create a temporary VB script to create shortcut files
    #
    unlink("CreateShortcut.vbs");
    if ( ! open(VB, "> CreateShortcut.vbs") ) {
        print "Failed to create shortcuts\n";
        Exit_With_Pause(1);
    }
    Write_To_Log("Create shortcut VB script for Open Data Tool.lnk");
    print VB
"Set oWS = WScript.CreateObject(\"WScript.Shell\")
sLinkFile = \"$start_menu\\Open Data Tool.lnk\"
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
    # Create a temporary VB script to create shortcut files
    #
    Write_To_Log("Create shortcut VB script for Uninstall.lnk");
    if ( ! open(VB, "> CreateShortcut.vbs") ) {
        print "Failed to create shortcuts\n";
        Exit_With_Pause(1);
    }
    print VB
"Set oWS = WScript.CreateObject(\"WScript.Shell\")
sLinkFile = \"$start_menu\\Uninstall.lnk\"
Set oLink = oWS.CreateShortcut(sLinkFile)
oLink.TargetPath = \"$program_dir\\uninstall.pl\"
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
    if ( (! -f "$start_menu/WPSS Tool.lnk")
         || (! -f "$start_menu/Open Data Tool.lnk")
         || (! -f "$start_menu/Uninstall.lnk")) {
        print "Failed to create start menu shortcuts\n";
        Write_To_Log("Failed to create start start menu shortcuts");
        Exit_With_Pause(1);
    }
}

#**********************************************************************
#
# Name: Set_Permissions
#
# Parameters: none
#
# Description:
#
#   This function sets execute permissions on programs for Linux systems.
#
#**********************************************************************
sub Set_Permissions {

    my ($p);
    
    #
    # Set execute for all .pl scripts
    #
    chdir($program_dir);
    opendir(DIR, ".");
    while ( $p = readdir(DIR) ) {
        if ( $p =~ /\.pl$/ ) {
            chmod 0755, $p;
        }
    }
    closedir(DIR);

    #
    # Set execute for all files in the bin directory
    #
    chdir("bin");
    opendir(DIR, ".");
    while ( $p = readdir(DIR) ) {
        if ( -f $p ) {
            chmod 0755, $p;
        }
    }
    closedir(DIR);

    #
    # Set execute for all files in the bin/csv-validator/bin directory
    #
    chdir("csv-validator/bin");
    opendir(DIR, ".");
    while ( $p = readdir(DIR) ) {
        if ( -f $p ) {
            chmod 0755, $p;
        }
    }
    closedir(DIR);
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
# If directory is '.', get the current working directory
#
if ( $program_dir eq "." ) {
    $program_dir = getcwd();
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
    elsif ( /-debug/ ) {
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
} else {
    #
    # Not Windows (should be Linux).
    #
    $is_windows = 0;
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
    # Get OS version
    #
    OS_Version();

    #
    # Check for Java version
    #
    Check_Java();

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
    if ( $is_windows ) {
        Install_Win32_GUI();
    }
    
    #
    # Set permissions for Linux systems
    #
    if ( ! $is_windows ) {
        Set_Permissions();
    }

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

