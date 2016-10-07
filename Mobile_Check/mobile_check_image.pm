#***********************************************************************
#
# Name:   mobile_check_image.pm
#
# $Revision$
# $URL$
# $Date$
#
# Description:
#
#   This file contains routines that parse CSS files and check for
# a number of mobile optimization checkpoints.
#
# Public functions:
#     Set_Mobile_Check_Image_Language
#     Set_Mobile_Check_Image_Debug
#     Set_Mobile_Check_Image_Testcase_Data
#     Set_Mobile_Check_Image_Test_Profile
#     Mobile_Check_Image
#     Mobile_Check_Image_Dimensions
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

package mobile_check_image;

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
    @EXPORT  = qw(Set_Mobile_Check_Image_Language
                  Set_Mobile_Check_Image_Debug
                  Set_Mobile_Check_Image_Testcase_Data
                  Set_Mobile_Check_Image_Test_Profile
                  Mobile_Check_Image
                  Mobile_Check_Image_Dimensions
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

my (%testcase_data, %mobile_check_profile_map, $current_mobile_check_profile);
my ($results_list_addr, $current_url, $jpegoptim, $optipng);
my ($minimum_image_size, $minimum_percent_reduction);

#
# Status values
#
my ($check_pass)       = 0;
my ($check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Converting GIF to PNG results in a", "Converting GIF to PNG results in a",
    "exceeds minimum acceptable value", "exceeds minimum acceptable value",
    "image size reduction",          "image size reduction",
    "Potential image optimization",  "Potential image optimization",
    );

my %string_table_fr = (
    "Converting GIF to PNG results in a", "Convertir le GIF en PNG résultats dans un",
    "exceeds minimum acceptable value", "épasse la valeur minimum acceptable",
    "image size reduction",          "réduire la taille de l'image",
    "Potential image optimization",  "Optimisation de l'image potentiel",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_Mobile_Check_Image_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Mobile_Check_Image_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_Mobile_Check_Image_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Mobile_Check_Image_Language {
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
    
    #
    # Set language in supporting modules
    #
    Mobile_Testcase_Language($language);
}

#***********************************************************************
#
# Name: Set_Mobile_Check_Image_Testcase_Data
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
sub Set_Mobile_Check_Image_Testcase_Data {
    my ($profile, $testcase, $data) = @_;

    my ($variable, $value);

    #
    # Get testcase specific data
    #
    if ( $testcase eq "OPT_IMAGES" ) {
        #
        # Get variable and value
        #
        ($variable, $value) = split(/\s+/, $data);

        #
        # Save minumum image size and minimum percent size reduction
        #
        if ( defined($value) && ($variable eq "MIN_SIZE") ) {
            $minimum_image_size = $value;
        }
        elsif ( defined($value) && ($variable eq "MIN_PERCENT") ) {
            $minimum_percent_reduction = $value;
        }
    }
    else {
        #
        # Copy the data into the table
        #
        $testcase_data{$testcase} = $data;
    }
}

#***********************************************************************
#
# Name: Set_Mobile_Check_Image_Test_Profile
#
# Parameters: profile - profile name
#             mobile_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by testcase name.
#
#***********************************************************************
sub Set_Mobile_Check_Image_Test_Profile {
    my ($profile, $mobile_checks ) = @_;

    my (%local_mobile_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Mobile_Check_Image_Test_Profile, profile = $profile\n" if $debug;
    %local_mobile_checks = %$mobile_checks;
    $mobile_check_profile_map{$profile} = \%local_mobile_checks;
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - Mobile check test profile
#             local_results_list_addr - address of results list.
#
# Description:
#
#   This function initializes the test case results table.
#
#***********************************************************************
sub Initialize_Test_Results {
    my ($profile, $local_results_list_addr) = @_;

    #
    # Set current hash tables
    #
    $current_mobile_check_profile = $mobile_check_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;

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
# Name: Print_Error
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             error_string - error string
#
# Description:
#
#   This function prints error messages if debugging is enabled..
#
#***********************************************************************
sub Print_Error {
    my ( $line, $column, $text, $error_string ) = @_;

    #
    # Print error message if we are in debug mode
    #
    if ( $debug ) {
        print "$error_string\n";
    }
}

#***********************************************************************
#
# Name: Record_Result
#
# Parameters: testcase - testcase identifier
#             line - line number
#             column - column number
#             text - text from tag
#             error_string - error string
#
# Description:
#
#   This function records the testcase result.
#
#***********************************************************************
sub Record_Result {
    my ( $testcase, $line, $column, $text, $error_string ) = @_;

    my ($result_object);

    #
    # Is this testcase included in the profile
    #
    if ( defined($testcase) && defined($$current_mobile_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $check_fail,
                                                Mobile_Testcase_Description($testcase),
                                                $line, $column, $text,
                                                $error_string, $current_url);
        push (@$results_list_addr, $result_object);

        #
        # Print error string to stdout
        #
        Print_Error($line, $column, $text, "$testcase : $error_string");
    }
}

#***********************************************************************
#
# Name: JPEG_Image_Details
#
# Parameters: this_url - a URL
#             resp - HTTP::Response object
#
# Description:
#
#   This function gets a number of jpeg image optimization details.
#
#***********************************************************************
sub JPEG_Image_Details {
    my ($this_url, $resp) = @_;

    my ($fh, $filename, $output, $orig_size, $new_size, $percent);
    my ($height) = 0;
    my ($width) = 0;

    #
    # Write content to a file for analysis
    #
    print "JPEG_Image_Details\n" if $debug;
    ($fh, $filename) = tempfile("WPSS_TOOL_XXXXXXXXXX", SUFFIX => '.jpg',
                                TMPDIR => 1);
    if ( ! defined($fh) ) {
        print "Error: Failed to create temporary file in JPEG_Image_Details\n";
        return;
    }
    binmode $fh;
    print $fh $resp->content;
    close($fh);

    #
    #
    # Run jpeg optimization program
    #
    print "Run $jpegoptim --strip-all -n $filename\n" if $debug;
    $output = `$jpegoptim --strip-all -n $filename 2>\&1`;
    print "Output = $output\n" if $debug;

    #
    # Parse out the image dimensions, original size, final size,
    # and the percent optimized from the command output
    #
    ($width, $height, $orig_size, $new_size, $percent) =
       $output =~ /[^\s]*\s+(\d+)x(\d+).*\s(\d+)\s+-->\s+(\d+)\s+bytes\s+\((\d+\.\d*)\%\).*$/io;

    #
    # Did we get the jpegoptim output ?
    #
    if ( defined($percent) ) {
        print "Image height = $height, width = $width, original size = $orig_size, new size = $new_size, percent = $percent\n" if $debug;
    }

    #
    # Clean up temporary file and return values
    #
    unlink($filename);
    return($height, $width, $orig_size, $new_size, $percent);
}

#***********************************************************************
#
# Name: Check_JPEG
#
# Parameters: this_url - a URL
#             resp - HTTP::Response object
#
# Description:
#
#   This function checks the optimzation level of a JPEG image.
#
#***********************************************************************
sub Check_JPEG {
    my ($this_url, $resp) = @_;

    my ($height, $width, $orig_size, $new_size, $percent);
    
    #
    # Get image details
    #
    print "Check_JPEG\n" if $debug;
    ($height, $width, $orig_size, $new_size, $percent) =
        JPEG_Image_Details($this_url, $resp);

    #
    # Did we get the image details ?
    #
    if ( defined($percent) ) {
        #
        # Is the image large enough to check ?
        #
        if ( defined($minimum_image_size) &&
             ($orig_size > $minimum_image_size) ) {
            #
            # Is the potential size reduction percentage above the minumum ?
            #
            $percent = int($percent);
            if ( defined($minimum_percent_reduction) &&
                 ($percent > $minimum_percent_reduction) ) {
                Record_Result("OPT_IMAGES", -1, -1, "",
                              String_Value("Potential image optimization") .
                              " $percent % " .
                              String_Value("exceeds minimum acceptable value") .
                              " $minimum_percent_reduction %");
            }
        }
    }
}

#***********************************************************************
#
# Name: PNG_Image_Details
#
# Parameters: this_url - a URL
#             resp - HTTP::Response object
#
# Description:
#
#   This function gets a number of png image optimization details.
#
#***********************************************************************
sub PNG_Image_Details {
    my ($this_url, $resp) = @_;

    my ($fh, $filename, $output, $line, $orig_size, $new_size, $percent);
    my ($height) = 0;
    my ($width) = 0;

    #
    # Write content to a file for analysis
    #
    print "PNG_Image_Details\n" if $debug;
    ($fh, $filename) = tempfile("WPSS_TOOL_XXXXXXXXXX", SUFFIX => '.png',
                                TMPDIR => 1);
    if ( ! defined($fh) ) {
        print "Error: Failed to create temporary file in PNG_Image_Details\n";
        return;
    }
    binmode $fh;
    print $fh $resp->content;
    close($fh);

    #
    #
    # Run png optimization program
    #
    print "Run $optipng $filename\n" if $debug;
    $output = `$optipng $filename 2>\&1`;
    print "Output = $output\n" if $debug;

    #
    # Parse out the final size, in bytes, and the percent optimized
    # from the command output
    #
    foreach $line (split(/\n/, $output)) {
        #
        # Get original file size
        #
        if ( $line =~ /Input file size/i ) {
            ($orig_size) = $line =~ /.*Input file size\s+=\s+(\d+)\s+bytes.*$/io;
        }
        #
        # Get output file size and percentage decrease
        #
        elsif ( $line =~ /Output file size/i ) {
            ($new_size, $percent) =
              $line =~ /.*Output file size\s+=\s+(\d+)\s+bytes.*bytes\s+=\s+(\d+\.\d*)\%.*$/io;
        }
        #
        # Get image dimensions
        #
        elsif ( $line =~ / pixels,/i ) {
            ($width, $height) = $line =~ /^\s*(\d+)x(\d+)\s+pixels,.*$/io;
        }
    }

    #
    # Did we get the optipng output ?
    #
    if ( defined($percent) ) {
        print "Image height = $height, width = $width, original size = $orig_size, new size = $new_size, percent = $percent\n" if $debug;
    }

    #
    # Clean up temporary file and return values
    #
    unlink($filename);
    return($height, $width, $orig_size, $new_size, $percent);
}

#***********************************************************************
#
# Name: Check_PNG
#
# Parameters: this_url - a URL
#             resp - HTTP::Response object
#
# Description:
#
#   This function checks the optimzation level of a PNG image.
#
#***********************************************************************
sub Check_PNG {
    my ($this_url, $resp) = @_;

    my ($height, $width, $orig_size, $new_size, $percent);

    #
    # Get image details
    #
    print "Check_PNG\n" if $debug;
    ($height, $width, $orig_size, $new_size, $percent) =
        PNG_Image_Details($this_url, $resp);

    #
    # Did we get the image details ?
    #
    if ( defined($orig_size) && defined($new_size) && defined($percent) ) {
        #
        # Is the image large enough to check ?
        #
        if ( defined($minimum_image_size) &&
             ($orig_size > $minimum_image_size) ) {
            #
            # Is the potential size reduction percentage above the minumum ?
            #
            $percent = int($percent);
            if ( defined($minimum_percent_reduction) &&
                 ($percent > $minimum_percent_reduction) ) {
                Record_Result("OPT_IMAGES", -1, -1, "",
                              String_Value("Potential image optimization") .
                              " $percent % " .
                              String_Value("exceeds minimum acceptable value") .
                              " $minimum_percent_reduction %");
            }
        }
    }
}

#***********************************************************************
#
# Name: GIF_Image_Details
#
# Parameters: this_url - a URL
#             resp - HTTP::Response object
#
# Description:
#
#   This function gets a number of gif image optimization details.
#
#***********************************************************************
sub GIF_Image_Details {
    my ($this_url, $resp) = @_;

    my ($fh, $filename, $output, $line, $orig_size, $new_size, $percent);
    my ($png_filename);
    my ($height) = 0;
    my ($width) = 0;

    #
    # Write content to a file for analysis
    #
    print "GIF_Image_Details\n" if $debug;
    ($fh, $filename) = tempfile("WPSS_TOOL_XXXXXXXXXX", SUFFIX => '.gif',
                                TMPDIR => 1);
    if ( ! defined($fh) ) {
        print "Error: Failed to create temporary file in GIF_Image_Details\n";
        return;
    }
    binmode $fh;
    print $fh $resp->content;
    close($fh);

    #
    # Get a temporary file for the PNG file by replacing the .gif suffix with
    # .png
    #
    $png_filename = $filename;
    $png_filename =~ s/\.gif$/.png/;

    #
    #
    # Run png optimization program to convert it to a PNG
    #
    print "Run $optipng $filename -out $png_filename\n" if $debug;
    $output = `$optipng $filename -out $png_filename 2>\&1`;
    print "Output = $output\n" if $debug;

    #
    # Parse out the final size, in bytes, and the percent optimized
    # from the command output
    #
    foreach $line (split(/\n/, $output)) {
        #
        # Get original file size
        #
        if ( $line =~ /Input file size/i ) {
            ($orig_size) = $line =~ /.*Input file size\s+=\s+(\d+)\s+bytes.*$/io;
        }
        #
        # Get output file size and percentage decrease
        #
        elsif ( $line =~ /Output file size/i ) {
            ($new_size, $percent) =
              $line =~ /.*Output file size\s+=\s+(\d+)\s+bytes.*bytes\s+=\s+(\d+\.\d*)\%.*$/io;
        }
        #
        # Get image dimensions
        #
        elsif ( $line =~ / pixels,/i ) {
            ($width, $height) = $line =~ /^\s*(\d+)x(\d+)\s+pixels,.*$/io;
        }
    }

    #
    # Did we get the optipng output ?
    #
    if ( defined($percent) ) {
        print "Image height = $height, width = $width, original size = $orig_size, new size = $new_size, percent = $percent\n" if $debug;
    }

    #
    # Clean up temporary file and return values
    #
    unlink($filename);
    unlink($png_filename);
    return($height, $width, $orig_size, $new_size, $percent);
}

#***********************************************************************
#
# Name: Check_GIF
#
# Parameters: this_url - a URL
#             resp - HTTP::Response object
#
# Description:
#
#   This function checks the optimzation level of a GIF image. It
# converts the GIT to a PNG to see if it results in a significant
# size reduction.
#
#***********************************************************************
sub Check_GIF {
    my ($this_url, $resp) = @_;

    my ($height, $width, $orig_size, $new_size, $percent);

    #
    # Get image details
    #
    print "Check_GIF\n" if $debug;
    ($height, $width, $orig_size, $new_size, $percent) =
        GIF_Image_Details($this_url, $resp);

    #
    # Did we get the image details ?
    #
    if ( defined($orig_size) && defined($new_size) && defined($percent) ) {
        #
        # Is the image large enough to check ?
        #
        if ( defined($minimum_image_size) &&
             ($orig_size > $minimum_image_size) ) {
            #
            # Is the potential size reduction percentage above the minumum ?
            #
            $percent = int($percent);
            if ( defined($minimum_percent_reduction) &&
                 ($percent > $minimum_percent_reduction) ) {
                Record_Result("OPT_IMAGES", -1, -1, "",
                              String_Value("Converting GIF to PNG results in a") .
                              " $percent \% " .
                              String_Value("image size reduction"));
            }
        }
    }
}

#***********************************************************************
#
# Name: Mobile_Check_Image
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
#   This function runs a number of mobile QA checks the content.
#
#***********************************************************************
sub Mobile_Check_Image {
    my ($this_url, $language, $profile, $mime_type, $resp, $content) = @_;

    my (@tqa_results_list, $result_object);

    #
    # Check for mobile optimization
    #
    print "Mobile_Check_Image\n" if $debug;

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);
    $current_url = $this_url;

    #
    # Check image based on type (GIF, JPG or PNG).
    #
    if ( ($mime_type =~ /image\/gif/) ||
         ($this_url =~ /\.gif$/i) ) {
        #
        # Check GIF image optimization
        #
        Check_GIF($this_url, $resp);
    }
    elsif ( ($mime_type =~ /image\/jpeg/) ||
         ($this_url =~ /\.jpg$/i) ||
         ($this_url =~ /\.jpeg$/i) ) {
        #
        # Check JPEG image optimization
        #
        Check_JPEG($this_url, $resp);
    }
    elsif ( ($mime_type =~ /image\/png/) ||
            ($this_url =~ /\.png$/i) ) {
        #
        # Check PNG image optimization
        #
        Check_PNG($this_url, $resp);
    }

    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Mobile_Check_Image_Dimensions
#
# Parameters: this_url - a URL
#             resp - HTTP::Response object
#
# Description:
#
#   This function returns an image file's height and width diemnsions.
#
#***********************************************************************
sub Mobile_Check_Image_Dimensions {
    my ($this_url, $resp) = @_;
    
    my ($height, $width, $orig_size, $new_size, $percent);
    my ($header, $mime_type);

    #
    # Get mime type
    #
    print "Mobile_Check_Image_Dimensions $this_url\n" if $debug;
    $header = $resp->headers;
    $mime_type = $header->content_type ;

    #
    # Check image based on type (GIF, JPG or PNG).
    #
    if ( ($mime_type =~ /image\/gif/) ||
         ($this_url =~ /\.gif$/i) ) {
        ($height, $width, $orig_size, $new_size, $percent) =
            GIF_Image_Details($this_url, $resp);
    }
    elsif ( ($mime_type =~ /image\/jpeg/) ||
         ($this_url =~ /\.jpg$/i) ||
         ($this_url =~ /\.jpeg$/i) ) {
        ($height, $width, $orig_size, $new_size, $percent) =
            JPEG_Image_Details($this_url, $resp);
    }
    elsif ( ($mime_type =~ /image\/png/) ||
            ($this_url =~ /\.png$/i) ) {
        ($height, $width, $orig_size, $new_size, $percent) =
            PNG_Image_Details($this_url, $resp);
    }

    #
    # Return height and width
    #
    return($height, $width);
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
    my (@package_list) = ("tqa_result_object", "mobile_testcases");

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
# Generate path the JPEG and PNG optimization commands
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $jpegoptim = ".\\bin\\jpegoptim.exe";
    $optipng = ".\\bin\\optipng.exe";
} else {
    #
    # Not Windows.
    #
    $jpegoptim = "$program_dir/jpegoptim";
    $optipng = "$program_dir/validate";
}

#
# Import required packages
#
Import_Packages;

#
# Return true to indicate we loaded successfully
#
return 1;

