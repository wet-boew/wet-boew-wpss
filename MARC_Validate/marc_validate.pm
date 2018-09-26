#***********************************************************************
#
# Name:   marc_validate.pm
#
# $Revision: 913 $
# $URL: svn://10.36.148.185/MARC_Validate/Tools/marc_validate.pm $
# $Date: 2018-07-19 13:51:56 -0400 (Thu, 19 Jul 2018) $
#
# Description:
#
#   This file contains routines that validate MARC 21 files
#
# Public functions:
#     MARC_Validate_Debug
#     MARC_Validate_Content
#     MARC_Validate_Language
#
# Terms and Conditions of Use
#
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is
# distributed under the MIT License.
#
# MIT License
#
# Copyright (c) 2018 Government of Canada
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

package marc_validate;

use strict;
use File::Basename;
use File::Temp qw/ tempfile tempdir /;

#
# Use WPSS_Tool program modules
#
use tqa_result_object;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(MARC_Validate_Content
                  MARC_Validate_Debug
                  MARC_Validate_Language
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);
my ($validate_cmnd);
my ($runtime_error_reported) = 0;

my ($debug) = 0;

my ($VALID_MARK_UP) = 1;
my ($INVALID_MARK_UP) = 0;

#
# String table for error strings.
#
my %string_table_en = (
    "Runtime Error",         "Runtime Error",
);

my %string_table_fr = (
    "Runtime Error",         "Erreur D'Exécution",
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#
# Default language is English
#
my ($language) = "eng";

#********************************************************
#
# Name: MARC_Validate_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub MARC_Validate_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#********************************************************
#
# Name: MARC_Validate_Language
#
# Parameters: this_language - language value
#
# Description:
#
#   This function sets the package language value.
#
#********************************************************
sub MARC_Validate_Language {
    my ($this_language) = @_;

    #
    # Set global language
    #
    if ( $this_language =~ /^fr/i ) {
        $language = "fra";
        $string_table = \%string_table_fr;
    }
    else {
        $language = "eng";
        $string_table = \%string_table_en;
    }
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

#***********************************************************************
#
# Name: MARC_Validate_Content
#
# Parameters: this_url - a URL
#             content - MARC content pointer
#             marc_file - optional name of MARC content file
#             tcid - testcase identifier
#             tc_desc - testcase description
#
# Description:
#
#   This function validates MARC content.
#
#***********************************************************************
sub MARC_Validate_Content {
    my ($this_url, $content, $marc_file, $tcid, $tc_desc) = @_;

    my ($validator_output, $temp_file_name);
    my (@results_list, $result_object, $fh);
    my ($in_error) = 0;
    my ($errors) = "";
    my ($non_error_messages) = "";

    #
    # Do we need to write the XML content to a file ?
    #
    print "MARC_Validate_Content\n" if $debug;
    if ( $marc_file eq "" ) {
        #
        # Create temporary file for MARC content.
        #
        print "Create temporary MARC file\n" if $debug;
        ($fh, $temp_file_name) = tempfile("WPSS_TOOL_XXXXXXXXXX", SUFFIX => '.mrc',
                                          TMPDIR => 1);
        if ( ! defined($fh) ) {
            print "Error: Failed to create temporary file in MARC_Validate_Content\n";
            return(@results_list);
        }
        binmode $fh;
        print $fh $$content;
        close($fh);
    }
    else {
        $temp_file_name = $marc_file;
    }

    #
    # Run the validator on the supplied content
    #
    print "Run validator\n --> $validate_cmnd $temp_file_name 2>\&1\n" if $debug;
    $validator_output = `$validate_cmnd $temp_file_name 2>\&1`;
    print "Validator output = $validator_output\n" if $debug;
    if ( $marc_file eq "" ) {
        unlink($temp_file_name);
    }

    #
    # Read the output from the validator looking for errors
    #
    foreach (split(/\n/, $validator_output)) {

        #
        # Ignore the information line generated by the
        # class org.reflections.Reflections
        #
        if ( /\s+INFO\s+org\.reflections\.Reflections\s+-\s+Reflections\s+took/i ) {
            print "Ignore summary line\n" if $debug;
            next;
        }
        #
        # Are we at the beginning of errors for a record ?
        #
        elsif ( /^Errors in /i) {
            $in_error = 1;
            $errors .= $_ . "\n";
        }
        else {
            #
            # Unrecognized line, are we within an error block ?
            #
            if ( $in_error ) {
                    $errors .= $_ . "\n";
            }
            else {
                #
                # Not in an error block, could be a runtime error message
                #
                $non_error_messages .= $_ . "\n";
            }
        }
    }

    #
    # Did we find any errors ?
    #
    if ( $errors ne "" ) {
        $result_object = tqa_result_object->new($tcid, 1, $tc_desc,
                                                -1, -1, "",
                                                $errors, $this_url);
        push (@results_list, $result_object);
    }
    elsif ( $non_error_messages ne "" ) {
        #
        # Some error trying to run the validator
        #
        print "MARC validator command failed\n" if $debug;
        print STDERR "MARC validator command failed\n";
        print STDERR "$validate_cmnd $temp_file_name\n";
        print STDERR "$validator_output\n";

        #
        # Report runtime error only once
        #
        if ( ! $runtime_error_reported ) {
            $result_object = tqa_result_object->new($tcid, 1, $tc_desc,
                                                    -1, -1, "",
                                                    String_Value("Runtime Error") .
                                                    " \"$validate_cmnd $temp_file_name\"\n" .
                                                    " \"$validator_output\"",
                                                    $this_url);
            $runtime_error_reported = 1;
            push (@results_list, $result_object);
        }
    }

    #
    # Return results
    #
    return(@results_list);
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
# Set validator command and options
#
$validate_cmnd = "java " .
                 "-cp $program_dir/lib/metadata-qa-marc-0.2-dependencies.jar;" .
                 "$program_dir/lib/metadata-qa-marc-0.2.jar " .
                 "de.gwdg.metadataqa.marc.cli.Validator -nolog -f stdout";

#
# Check for operating system specifics
#
if ( !( $^O =~ /MSWin32/ ) ) {
    #
    # Not Windows, change ; separator to : separator in class path,
    # add LANG environment variable setting for Unix.
    #
    $validate_cmnd =~ s/jar;/jar:/g;
    $validate_cmnd = "LANG=en_US.ISO8859-1;export LANG;" . $validate_cmnd;
}

#
# Return true to indicate we loaded successfully
#
return 1;

