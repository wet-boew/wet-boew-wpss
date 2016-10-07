#***********************************************************************
#
# Name:   epub_validate.pm
#
# $Revision: 7635 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/EPUB_Validate/Tools/epub_validate.pm $
# $Date: 2016-07-22 03:40:16 -0400 (Fri, 22 Jul 2016) $
#
# Description:
#
#   This file contains routines that validate EPUB content.
#
# Public functions:
#     EPUB_Validate_Content
#     EPUB_Validate_Language
#     EPUB_Validate_Debug
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

package epub_validate;

use strict;
use Archive::Zip qw(:ERROR_CODES);
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
    @EXPORT  = qw(EPUB_Validate_Content
                  EPUB_Validate_Language
                  EPUB_Validate_Debug
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths, $validate_cmnd);
my ($runtime_error_reported) = 0;
my ($debug) = 0;

#
# String table for error strings.
#
my %string_table_en = (
    "Error in reading EPUB, status =",   "Error in reading EPUB, status =",
    "Runtime Error",                     "Runtime Error",
);

#
# String table for error strings (French).
#
my %string_table_fr = (
    "Error in reading EPUB, status =",  "Erreur de lecture fichier EPUB, status =",
    "Runtime Error",                    "Erreur D'Exécution",
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#********************************************************
#
# Name: EPUB_Validate_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub EPUB_Validate_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#********************************************************
#
# Name: EPUB_Validate_Language
#
# Parameters: $this_language - language value
#
# Description:
#
#   This function sets the package language value.
#
#********************************************************
sub EPUB_Validate_Language {
    my ($this_language) = @_;

    #
    # Check for French language
    #
    if ( $this_language =~ /^fr/i ) {
        print "EPUB_Validate_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "EPUB_Validate_Language, language = English\n" if $debug;
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
# Name: EPUB_Validate_Content
#
# Parameters: this_url - a URL
#             resp - HTTP::Response object
#             content - EPUB content pointer
#
# Description:
#
#   This function runs the EPUB validator on the supplied content
# and returns the validation status result. It also saves the content
# in a local file and creates a Archive::Zip object to open it.
#
#***********************************************************************
sub EPUB_Validate_Content {
    my ($this_url, $resp, $content) = @_;

    my (@results_list, $epub_file, $fh, $zip, $zip_status, $header);
    my ($validator_output, $result_object, $epub_url, $pattern);

    #
    # Do we have any content ?
    #
    print "EPUB_Validate_Content, validate $this_url\n" if $debug;
    if ( length($$content) > 0 ) {
        #
        # Create a temporary file for the EPUB content
        #
        print "EPUB_Validate_Content create temporary EPUB file\n" if $debug;
        ($fh, $epub_file) = tempfile("WPSS_TOOL_XXXXXXXXXX", SUFFIX => '.epub',
                                     TMPDIR => 1);
        if ( ! defined($fh) ) {
            print STDERR "Error: Failed to create temporary file in EPUB_Validate_Content\n";
            return(@results_list);
        }
        binmode $fh;
        print $fh $$content;
        close($fh);

        #
        # Add the file name to the HTTP::Response object so other
        # modules can access it.
        #
        $header = $resp->headers;
        $header->header("WPSS-Content-File" => $epub_file);
        
        #
        # Run the validator on the EPUB file
        #
        print "Run epubcheck validator\n$validate_cmnd \"$epub_file\"\n" if $debug;
        $validator_output = `$validate_cmnd \"$epub_file\" 2>\&1`;
        print "Validator output = $validator_output\n" if $debug;
            
        #
        # Strip out the temporary file name from the validator output.
        # This avoids confusion since the file name does not match the
        # URL for the EPUB.
        #
        $epub_url = basename($this_url);
        $pattern = $epub_file;
        $pattern =~ s/\\/\//g;
        $validator_output =~ s/$pattern/$epub_url/g;

        #
        # Did validation fail ?
        #
        if ( $validator_output =~ /Check finished with errors/im ) {
            $result_object = tqa_result_object->new("EPUB_VALIDATION",
                                                    1, "EPUB_VALIDATION",
                                                    -1, -1, "",
                                                    $validator_output,
                                                    $this_url);
            push(@results_list, $result_object);
        }
        elsif ( $validator_output ne "" ) {
            #
            # Some error trying to run the validator
            #
            print "EPUB validator command failed\n" if $debug;
            print STDERR "EPUB validator command failed\n";
            print STDERR "$validate_cmnd \"$epub_file\"\n";
            print STDERR "$validator_output\n";

            #
            # Report runtime error only once
            #
            if ( ! $runtime_error_reported ) {
                $result_object = tqa_result_object->new("EPUB_VALIDATION",
                                                        1, "EPUB_VALIDATION",
                                                        -1, -1, "",
                                                        String_Value("Runtime Error") .
                                                        " \"$validate_cmnd \"$epub_file\"\n" .
                                                        " \"$validator_output\"",
                                                        $this_url);
                $runtime_error_reported = 1;
                push (@results_list, $result_object);
            }
        }

        #
        # Create an Archive::Zip object to get at the EPUB contents
        #
        $zip = Archive::Zip->new();
        $zip_status = $zip->read($epub_file);

        #
        # Did we read the ZIP successfully ?
        #
        if ( $zip_status != AZ_OK ) {
            print "Error reading archive, status = $zip_status\n" if $debug;
            $result_object = tqa_result_object->new("EPUB_VALIDATION",
                                                    1, "EPUB_VALIDATION",
                                                    -1, -1, "",
                                                    String_Value("Error in reading EPUB, status =") .
                                                    " $zip_status", $this_url);
            push(@results_list, $result_object);
        }
        
        #
        # Discard the Archive::Zip object
        #
        undef($zip);
    }
    else {
        #
        # No content
        #
        print "No content passed to EPUB_Validate_Content\n" if $debug;
    }

    #
    # Return result list
    #
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
    my (@package_list) = ("crawler", "tqa_result_object");

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
# Generate path the validate command
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $validate_cmnd = "java -jar .\\bin\\epubcheck\\epubcheck.jar -e -q";
} else {
    #
    # Not Windows.
    #
    $validate_cmnd = "java -jar ./bin/epubcheck/epubcheck.jar -e -q";
}

#
# Import required packages
#
Import_Packages;

#
# Return true to indicate we loaded successfully
#
return 1;

