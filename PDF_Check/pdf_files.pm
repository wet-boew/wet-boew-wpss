#***********************************************************************
#
# Name: pdf_files.pm
#
# $Revision: 6587 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/PDF_Check/Tools/pdf_files.pm $
# $Date: 2014-03-12 15:33:00 -0400 (Wed, 12 Mar 2014) $
#
# Description
#
#   This file contains routines to deal with PDF files.  Convert PDF to
# text, read file properties (Metadata), etc.
#
# Public functions:
#     PDF_Files_Language
#     PDF_Files_Debug
#     PDF_Files_Get_Properties
#     PDF_Files_Get_Properties_From_Content
#     PDF_Files_PDF_Content_To_Text
#     PDF_Files_PDF_File_To_Text
#     PDF_Files_Validate_Properties
#     Set_Required_PDF_File_Properties
#     Set_Required_PDF_Property_Content
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

package pdf_files;

use strict;
use warnings;
use File::Basename;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(PDF_Files_Debug
                  PDF_Files_Language
                  PDF_Files_Get_Properties
                  PDF_Files_Get_Properties_From_Content
                  PDF_Files_PDF_Content_To_Text
                  PDF_Files_PDF_File_To_Text
                  PDF_Files_Validate_Properties
                  Set_Required_PDF_File_Properties
                  Set_Required_PDF_Property_Content
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);
my ($debug) = 0;

my (%property_required_profile_map, %content_required_profile_map);
my ($current_property_required, $current_content_required);
my ($pdfinfo_cmnd, $pdftotext_cmnd);
my ($results_list_addr, $current_url, $pdf_property_result_objects);

#
# Status values
#
my ($property_success)           = 0;
my ($property_missing)           = 1;
my ($property_content_missing)   = 2;

#
# Status values
#
my ($pdf_property_success)      = 0;
my ($pdf_property_error)        = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Missing property", "Missing property: ",
    "Missing content", "Missing content: ",
    "Invalid content", "Invalid content: ",
     );

#
# String table for error strings (French).
#
my %string_table_fr = (
    "Missing property", "Property manque: ",
    "Missing content", "Manque de contenu: ",
    "Invalid content", "Contenu non valide: ",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#
# String tables for testcase ID to testcase descriptions
#
my (%testcase_description_en) = (
"PDF_PROPERTY", "PDF Properties",
);

my (%testcase_description_fr) = (
"PDF_PROPERTY", "Profil de mitadonnies",
);

#
# Create reverse table, indexed by description
#
my (%reverse_testcase_description_en) = reverse %testcase_description_en;
my (%reverse_testcase_description_fr) = reverse %testcase_description_fr;
my ($reverse_testcase_description_table) = \%reverse_testcase_description_en;

#
# Default messages to English
#
my ($testcase_description_table) = \%testcase_description_en;

#**********************************************************************
#
# Name: PDF_Files_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub PDF_Files_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "PDF_Files_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
        $testcase_description_table = \%testcase_description_fr;
        $reverse_testcase_description_table = \%reverse_testcase_description_fr;
    }
    else {
        #
        # Default language is English
        #
        print "PDF_Files_Language, language = English\n" if $debug;
        $string_table = \%string_table_en;
        $testcase_description_table = \%testcase_description_en;
        $reverse_testcase_description_table = \%reverse_testcase_description_en;
    }
}

#***********************************************************************
#
# Name: Set_Required_PDF_File_Properties
#
# Parameters: profile - PDF file properties profile
#             required_properties - hash table of property name 
#             and required flag
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The required_properties hash table is indexed by a property name with
# the value being 0 = tag is optional, 1 = tag is required.
#
#***********************************************************************
sub Set_Required_PDF_File_Properties {
    my ($profile, %required_properties) = @_;

    my (%local_required_properties);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    %local_required_properties = %required_properties;
    $property_required_profile_map{$profile} = \%local_required_properties;
}

#***********************************************************************
#
# Name: Set_Required_PDF_Property_Content
#
# Parameters: profile - PDF file properties profile
#             required_content - hash table of property name and required flag
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The required_content hash table is indexed by a property name with
# the value being 0 = content is optional, 1 = content is required.
#
#***********************************************************************
sub Set_Required_PDF_Property_Content {
    my ($profile, %required_content) = @_;

    my (%local_required_content);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    %local_required_content = %required_content;
    $content_required_profile_map{$profile} = \%local_required_content;
}

#********************************************************
#
# Name: PDF_Files_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub PDF_Files_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#********************************************************
#
# Name: PDF_Files_Get_Properties
#
# Parameters: filename - name of PDF file
#
# Description:
#
#   This function extracts the properties (metadata) from a
# PDF file.
#
#********************************************************
sub PDF_Files_Get_Properties {
    my ($filename) = @_;

    my ($text, $tag, $value, @fields);
    my (%properties) = ();

    #
    # Check to see that the file exists
    #
    if ( ! -r "$filename" ) {
        print "Error: PDF_Files_Get_Properties PDF file not readable\n";
        print " --> $filename\n";
        return(0, %properties);
    }

    #
    # Run pdfinfo to get properties information
    #
    print "PDF_Files_Get_Properties: pdfinfo $filename -\n" if $debug;
    $text = `$pdfinfo_cmnd \"$filename\" 2>\&1`;

    #
    # Does it look like we got an error message "Error: Couldn't ..."
    #
    if ( $text =~ /Error: Couldn't/i ) {
        #
        # Error reading properties, return no properties
        #
        print "Error in pdfinfo $filename\n" if $debug;
        print " --> $text\n" if $debug;
        return(0, %properties);
    }
    else {
        #
        # Split pdfinfo output lines, each contains a tag and value pair
        #
        foreach (split(/\n/, $text)) {
            #
            # Split line of first colon
            #
            @fields = split(/:/, $_, 2);

            #
            # Do we have 2 fields ?
            #
            if ( @fields == 2 ) {
                $tag = $fields[0];
                $value = $fields[1];

                #
                # Strip of leading and trailing white space
                #
                $value =~ s/^\s+//g;
                $value =~ s/\s+$//g;
                print "Found property $tag, value \"$value\"\n" if $debug;
                $properties{$tag} = $value;
            }
            else {
                #
                # Malformed property line
                #
                print "Warning: Malformed property line from pdfinfo\n" if $debug;
                print " --> $_\n" if $debug;
            }
        }
    }

    #
    # Return properties from PDF file
    #
    return(1, %properties);
}

#********************************************************
#
# Name: PDF_Files_Get_Properties_From_Content
#
# Parameters: content - PDF content
#
# Description:
#
#   This function extracts the properties (metadata) from 
# PDF content.
#
# Returns
#   table of properties and values
#
#***********************************************************************
sub PDF_Files_Get_Properties_From_Content {
    my ($content) = @_;

    my ($pdf_file_name, %properties, $status);

    #
    # Did we get any content ?
    #
    print "PDF_Files_Get_Properties_From_Content\n" if $debug;
    if ( length($content) > 0 ) {
        #
        # Create temporary file for PDF content.
        #
        $pdf_file_name = "pdf_text$$.pdf";
        unlink($pdf_file_name);
        print "Create temporary PDF file $pdf_file_name\n" if $debug;
        if ( ! open(PDF, ">$pdf_file_name") ) {
            print "Failed to open $pdf_file_name for writing\n";
            return(0, %properties);
        }
        binmode PDF;
        print PDF $content;
        close(PDF);

        #
        # Get PDF file peroperties
        #
        ($status, %properties) = PDF_Files_Get_Properties($pdf_file_name);

        #
        # Remove temporary file
        #
        unlink($pdf_file_name);
    }

    #
    # Return table of properties and values
    #
    print "status = $status\n" if $debug;
    return($status, %properties);
}

#********************************************************
#
# Name: PDF_Files_PDF_File_To_Text
#
# Parameters: filename - name of PDF file
#
# Description:
#
#   This function extracts the text from a PDF file.
#
#********************************************************
sub PDF_Files_PDF_File_To_Text {
    my ($filename) = @_;

    my ($text);

    #
    # Check to see that the file exists
    #
    if ( ! -r "$filename" ) {
        print "Error: PDF_Files_PDF_File_To_Text PDF file not readable\n";
        print " --> $filename\n";
        return("");
    }

    #
    # Run pdftotext to get text
    #
    print "PDF_Files_PDF_File_To_Text: pdftotext $filename -\n" if $debug;
    $text = `$pdftotext_cmnd \"$filename\" - 2>\&1`;
    if ( ! defined($text) ) {
        $text = "";
    }

    #
    # Does it look like we got an error message "Error: Couldn't ..."
    #
    if ( $text =~ /Error: Couldn't/i ) {
        #
        # Error converting PDF, return no text
        #
        print "Error in pdftotext $filename\n" if $debug;
        print " --> $text\n" if $debug;
        $text = "";
    }

    #
    # Return text from PDF file
    #
    return($text);
}

#********************************************************
#
# Name: PDF_Files_PDF_Content_To_Text
#
# Parameters: content - PDF file content
#
# Description:
#
#   This function converts PDF content into text.
#
#********************************************************
sub PDF_Files_PDF_Content_To_Text {
    my ($content) = @_;

    my ($text, $pdf_file_name);

    #
    # Check content length
    #
    if ( (!defined($content) ) || length($content) == 0 ) {
        print "PDF_Files_PDF_Content_To_Text: No content supplied\n" if $debug;
        return("");
    }

    #
    # Create temporary file for PDF content.
    #
    $pdf_file_name = "pdf_text$$.pdf";
    unlink($pdf_file_name);
    print "Create temporary PDF file $pdf_file_name\n" if $debug;
    if ( ! open(PDF, ">$pdf_file_name") ) {
        print "PDF_Files_PDF_Content_To_Text: Failed to open $pdf_file_name for writing\n";
        return("");
    }
    binmode PDF;
    print PDF $content;
    close(PDF);

    #
    # Convert PDF file into text
    #
    $text = PDF_Files_PDF_File_To_Text($pdf_file_name);

    #
    # Remove temporary file
    #
    unlink($pdf_file_name);

    #
    # Return text from PDF file
    #
    return($text);
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
# Name: Initialize_Variables
#
# Parameters: profile - properties profile
#
# Description:
#
#   This function initializes variables
#
#***********************************************************************
sub Initialize_Variables {
    my ($profile) = @_;

    #
    # Set current hash tables
    #
    $current_property_required = $property_required_profile_map{$profile};
    $current_content_required = $content_required_profile_map{$profile};
}

#**********************************************************************
#
# Name: Testcase_Description
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase description
# table for the specified key.  If there is no entry in the table an error
# string is returned.
#
#**********************************************************************
sub Testcase_Description {
    my ($key) = @_;

    #
    # Do we have a string table entry for this key ?
    #
    if ( defined($$testcase_description_table{$key}) ) {
        #
        # return value
        #
        return ($$testcase_description_table{$key});
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
# Name: Record_Result
#
# Parameters: property - property name
#             status- status value
#             content - content from tag
#             message - message string
#
# Description:
#
#   This function records the pdf propertry result.
#
#***********************************************************************
sub Record_Result {
    my ($property, $status, $content, $message) = @_;

    my ($result_object, $property_object);

    #
    # Do we already have a result for this property ?
    #
    if ( defined($$pdf_property_result_objects{$property}) ) {
        $property_object = $$pdf_property_result_objects{$property};

        #
        # Append the content and sttributes values to the existing values
        #
        print "Append to existing PDF property content for $property\n" if $debug;
        $property_object->content($property_object->content . $content);
    }
    else {
        #
        # Create PDF property (metadata) object and save details
        #
        $property_object = metadata_result_object->new($property, $status,
                                                       $content, "",
                                                       $message);

        #
        # Save result object in case we get another instance of this property
        #
        $$pdf_property_result_objects{$property} = $property_object;
    }

    #
    # If the status is not success, record an error
    #
    if ( $status != $pdf_property_success ) {
        #
        # Create result object and save details
        #
        $message = "$property: " . $message;
        $result_object = tqa_result_object->new("PDF_PROPERTY",
                                                $pdf_property_error,
                                           Testcase_Description("PDF_PROPERTY"),
                                              -1, -1, "",
                                              $message, $current_url);
        push (@$results_list_addr, $result_object);

        #
        # Print error string to stdout
        #
        print "PDF Property : $message\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Check_Required_Properties
#
# Parameters: properties - properties table
#
# Description:
#
#   This function checks to see that all required properties were
# found.
#
#***********************************************************************
sub Check_Required_Properties {
    my (%properties) = @_;

    my ($property);

    #
    # Check all required properties
    #
    foreach $property (keys %$current_property_required) {
        print "Check_Required_Properties: Checking property $property\n" if $debug;
        if ( ! defined($properties{"$property"}) ) {
            print "Check_Required_Properties: Missing property $property\n" if $debug;

            #
            # Record property status
            #
            Record_Result($property, $property_missing, "", 
                          String_Value("Missing property"));
        }
    }
}

#***********************************************************************
#
# Name: PDF_Files_Validate_Properties
#
# Parameters: this_url - a URL
#             profile - properties profile
#             content - PDF content
#             pdf_property_results - hash table reference
#
# Description:
#
#   This function parses the supplied PDF content for properties
# (metadata).  It checks for required tags, required content.
# It returns the property content and status.
#
# Returns
#  list of result objects
#
#***********************************************************************
sub PDF_Files_Validate_Properties {
    my ( $this_url, $profile, $content, $pdf_property_results) = @_;

    my ($key, $value, $status, %properties);
    my (@pdf_property_results, $message);

    #
    # Set global debug flag.
    #
    print "PDF_Files_Validate_Properties: Checking URL $this_url, profile = $profile\n" if $debug;

    #
    # Do we have a valid profile ?
    #
    if ( ! defined($property_required_profile_map{$profile}) ) {
        print "PDF_Files_Validate_Properties: Unknown property profile passed $profile\n";
        return(@pdf_property_results);
    }

    #
    # Initialize variables.
    #
    Initialize_Variables($profile);
    $results_list_addr = \@pdf_property_results;
    $pdf_property_result_objects = $pdf_property_results;

    #
    # Save URL in global variable
    #
    if ( ($this_url =~ /^http/i) || ($this_url =~ /^file/i) ) {
        $current_url = $this_url;
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of code
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Did we get any content ?
    #
    if ( length($content) > 0 ) {
        #
        # Get PDF file peroperties
        #
        ($status, %properties) = PDF_Files_Get_Properties_From_Content($content);

        #
        # Did we get properties ?
        #
        if ( ! $status ) {
            print "Failed to get PDF file properties\n" if $debug;
            return(@pdf_property_results);
        }

        #
        # Copy property content into user supplied content table and
        # check for missing content.
        #
        while ( ($key, $value) = each %properties ) {
            $status = $property_success;;
            $message = "";

            #
            # Did we expect content for this property ?
            #
            if ( defined($$current_content_required{$key}) &&
                 $$current_content_required{$key} ) {
                if ( $value eq "" ) {
                    #
                    # Missing content
                    #
                    print "Missing content for property $key\n" if $debug;
                    $status = $property_content_missing;
                    $message = String_Value("Missing content");

                }
            }
            else {
                print "Content not required for property $key\n" if $debug;
            }

            #
            # Record property status
            #
            Record_Result($key, $status, $value, $message);
        }
    }
    else {
        print "No content passed to PDF_Files_Validate_Properties\n" if $debug;
    }

    #
    # Check for missing property items (required properties that we 
    # did not find).
    #
    Check_Required_Properties(%properties);

    #
    # Dump out property values
    #
    if ( $debug ) {
        foreach $key (sort keys %properties ) {
            $value = $properties{$key};
            printf("%20s value %s\n", $key, $value);
        }
    }

    #
    # Return list of results
    #
    return(@pdf_property_results);
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
    my (@package_list) = ("metadata_result_object", "tqa_result_object");

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
# Add to path for shared libraries (Solaris only)
#
if ( defined $ENV{LD_LIBRARY_PATH} ) {
    $ENV{LD_LIBRARY_PATH} .= ":/usr/local/lib:/opt/sfw/lib";
}
else {
    $ENV{LD_LIBRARY_PATH} = "/usr/local/lib:/opt/sfw/lib";
}

#
# Generate path supporting commands
# variable
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $pdfinfo_cmnd = "pdfinfo";
    $pdftotext_cmnd = "pdftotext";
} else {
    #
    # Not Windows.
    #
    $pdfinfo_cmnd = "$program_dir/pdfinfo";
    $pdftotext_cmnd = "$program_dir/pdftotext";
}

#
# Import required packages
#
Import_Packages;

#
# Return true to indicate we loaded successfully
#
return 1;
