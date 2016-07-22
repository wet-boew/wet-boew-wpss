#***********************************************************************
#
# Name:   xml_ttml_validate.pm
#
# $Revision: 7629 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/XML_Validate/Tools/xml_ttml_validate.pm $
# $Date: 2016-07-21 08:29:10 -0400 (Thu, 21 Jul 2016) $
#
# Description:
#
#   This file contains routines that validate XML content.
#
# Public functions:
#     XML_TTML_Validate_Content
#     XML_TTML_Validate_Language
#     XML_TTML_Validate_Debug
#     XML_TTML_Validate_Is_TTML
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

package xml_ttml_validate;

use strict;
use File::Basename;
use XML::Parser;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(XML_TTML_Validate_Content
                  XML_TTML_Validate_Language
                  XML_TTML_Validate_Debug
                  XML_TTML_Validate_Is_TTML
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths, $validate_cmnd);
my ($is_ttml);
my ($runtime_error_reported) = 0;

my ($debug) = 0;

my ($VALID_XML) = 1;
my ($INVALID_XML) = 0;

#
# String table for error strings.
#
my %string_table_en = (
    "Error",                 "Error: ",
    "Line",                  "Line",
    "column",                "column",
    "Runtime Error",         "Runtime Error",
    "Source line",           "Source line:",
);

my %string_table_fr = (
    "Error",                 "Erreur: ",
    "Line",                  "Ligne",
    "column",                "colonne",
    "Runtime Error",         "Erreur D'Exécution",
    "Source line",           "Ligne de la source:",
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#********************************************************
#
# Name: XML_TTML_Validate_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub XML_TTML_Validate_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#********************************************************
#
# Name: XML_TTML_Validate_Language
#
# Parameters: language - language value
#
# Description:
#
#   This function sets the package language value.
#
#********************************************************
sub XML_TTML_Validate_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "XML_TTML_Validate_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "XML_TTML_Validate_Language, language = English\n" if $debug;
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
# Name: XML_TTML_Validate_Content
#
# Parameters: this_url - a URL
#             content - XML content pointer
#
# Description:
#
#   This function runs the XML TTML validator on the supplied URL
# and returns the validation status result.
#
#***********************************************************************
sub XML_TTML_Validate_Content {
    my ($this_url, $content) = @_;

    my (@results_list, $result_object, $validator_output, @lines);
    my ($error, $line, $column, $message, $errors);

    #
    # Do we have any content ?
    #
    print "XML_TTML_Validate_Content, validate $this_url\n" if $debug;
    if ( length($$content) > 0 ) {
        #
        # Run the validator on the URL
        #
        print "Run validator\n --> java -jar ttv.jar --quiet --hide-warnings --hide-resource-location $this_url 2>\&1\n" if $debug;
        $validator_output = `java -jar \"$program_dir/lib/ttv.jar\" --quiet --hide-warnings --hide-resource-location $this_url 2>\&1`;

        #
        # Do we have an error ? ('Error at' in the output line)
        #
        if ( $validator_output ne "" ) {
            print "Validation failed \"$validator_output\"\n" if $debug;
            
            #
            # Split content into lines
            #
            @lines = split(/\n/, $$content);
            
            #
            # Parse the validation output to get line numbers for the errors
            #
            $errors = "";
            foreach $error (split(/\n/, $validator_output)) {
                #
                # Get the error location and message
                #
                ($line, $column, $message) =
                $error =~ /^\[E\]:\[(\d+),(\d+)\]\:(.*)$/io;
                    
                #
                # Did we get a message ? or did the parse fail ?
                #
                if ( defined($message) ) {
                    #
                    # Append this message to the error list
                    #
                    $errors .= String_Value("Error") . $message . "\n" .
                               String_Value("Line") . " $line " .
                               String_Value("column") . " $column\n" .
                               String_Value("Source line") . " " .
                               $lines[$line - 1] . "\n\n";
                }
            }
            
            #
            # Did we find any error messages ?
            #
            if ( $errors ne "" ) {
                #
                # Create testcase result object
                #
                $result_object = tqa_result_object->new("XML_VALIDATION",
                                                        1, "XML_VALIDATION",
                                                        -1, -1, "",
                                                       $errors, $this_url);
                push (@results_list, $result_object);
            }
            else {
                #
                # Some error trying to run the validator
                #
                print "TTML validator command failed\n" if $debug;
                print STDERR "TTML validator command failed\n";
                print STDERR "java -jar ttv.jar --quiet --hide-warnings --hide-resource-location $this_url\n";
                print STDERR "$validator_output\n";

                #
                # Report runtime error only once
                #
                if ( ! $runtime_error_reported ) {
                    $result_object = tqa_result_object->new("XML_VALIDATION",
                                                            1, "XML_VALIDATION",
                                                            -1, -1, "",
                                                            String_Value("Runtime Error") .
                                                            " \"java -jar ttv.jar --quiet --hide-warnings --hide-resource-location $this_url\"\n" .
                                                            " \"$validator_output\"",
                                                            $this_url);
                    $runtime_error_reported = 1;
                    push (@results_list, $result_object);
                }
            }

        }
    }
    else {
        #
        # No content
        #
        print "No content passed to XML_TTML_Validate_Content\n" if $debug;
    }

    #
    # Return result list
    #
    return(@results_list);
}

#***********************************************************************
#
# Name: Is_TTML_Start_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles the start of XML tags.
#
#***********************************************************************
sub Is_TTML_Start_Handler {
    my ($self, $tagname, %attr) = @_;

    #
    # Check tags.
    #
    print "Start_Handler tag $tagname\n" if $debug;

    #
    # If we find a <tt> tag, we assume this is a ttml xml file
    #
    if ( $tagname eq "tt" ) {
        $is_ttml = 1;
    }
}

#***********************************************************************
#
# Name: XML_TTML_Validate_Is_TTML
#
# Parameters: this_url - a URL
#             content - content pointer
#
# Description:
#
#   This function checks to see if the suppliedt XML
# content is TTML or not.
#
#***********************************************************************
sub XML_TTML_Validate_Is_TTML {
    my ( $this_url, $content) = @_;

    my ($parser, $eval_output);

    #
    # Initialize global variables.
    #
    $is_ttml = 0;

    #
    # Create a document parser
    #
    $parser = XML::Parser->new;

    #
    # Add handlers for some of the XML tags
    #
    $parser->setHandlers(Start => \&Is_TTML_Start_Handler);

    #
    # Parse the content.
    #
    $eval_output = eval { $parser->parse($$content); } ;

    #
    # Did we TTML tags ?
    #
    if ( $is_ttml ) {
        print "URL is TTML XML\n" if $debug;
    }
    else {
        print "URL is not TTML XML\n" if $debug;
    }
    return($is_ttml);
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
    my (@package_list) = ("tqa_result_object");

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
# Import required packages
#
Import_Packages;

#
# Return true to indicate we loaded successfully
#
return 1;

