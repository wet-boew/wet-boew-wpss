#***********************************************************************
#
# Name:   xml_ttml_check.pm
#
# $Revision: 6999 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/TQA_Check/Tools/xml_ttml_check.pm $
# $Date: 2015-01-19 09:49:46 -0500 (Mon, 19 Jan 2015) $
#
# Description:
#
#   This file contains routines that parse TTML XML files and check for
# a number of acceessibility (WCAG) check points.
#
# Public functions:
#     Set_XML_TTML_Check_Language
#     Set_XML_TTML_Check_Debug
#     Set_XML_TTML_Check_Testcase_Data
#     Set_XML_TTML_Check_Test_Profile
#     XML_TTML_Check
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

package xml_ttml_check;

use strict;
use URI::URL;
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
    @EXPORT  = qw(Set_XML_TTML_Check_Language
                  Set_XML_TTML_Check_Debug
                  Set_XML_TTML_Check_Testcase_Data
                  Set_XML_TTML_Check_Test_Profile
                  XML_TTML_Check
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (%testcase_data, $results_list_addr);
my (@paths, $this_path, $program_dir, $program_name, $paths);
my (%xml_ttml_check_profile_map, $current_xml_ttml_check_profile, $current_url);
my ($save_text_between_tags, $saved_text, $current_content_lang_code);

my ($max_error_message_string)= 2048;

#
# Status values
#
my ($xml_ttml_check_fail) = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "does not match content language", "does not match content language",
    "Missing tt language attribute",   "Missing <tt> language attribute",
    "TT language attribute",           "<tt> language attribute",
    );

my %string_table_fr = (
    "does not match content language", "ne correspond pas à la langue de contenu",
    "Missing tt language attribute",   "Attribut manquant pour <tt>",
    "TT language attribute",           "L'attribut du langage <tt>",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_XML_TTML_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_XML_TTML_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_XML_TTML_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_XML_TTML_Check_Language {
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
# Name: Set_XML_TTML_Check_Testcase_Data
#
# Parameters: testcase - testcase identifier
#             data - string of data
#
# Description:
#
#   This function copies the passed data into a hash table
# for the specified testcase identifier.
#
#***********************************************************************
sub Set_XML_TTML_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_XML_TTML_Check_Test_Profile
#
# Parameters: profile - XML check test profile
#             xml_ttml_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by XML testcase name.
#
#***********************************************************************
sub Set_XML_TTML_Check_Test_Profile {
    my ($profile, $xml_ttml_checks) = @_;

    my (%local_xml_ttml_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_XML_TTML_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_xml_ttml_checks = %$xml_ttml_checks;
    $xml_ttml_check_profile_map{$profile} = \%local_xml_ttml_checks;
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - XML check test profile
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
    $current_xml_ttml_check_profile = $xml_ttml_check_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;
    
    #
    # Initialize global variables
    #
    $save_text_between_tags = 0;
    $saved_text = "";
    $current_content_lang_code = "unknown";
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
    if ( defined($testcase) && defined($$current_xml_ttml_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $xml_ttml_check_fail,
                                                TQA_Testcase_Description($testcase),
                                                $line, $column, $text,
                                                $error_string, $current_url);
        $result_object->testcase_groups(TQA_Testcase_Groups($testcase));
        push (@$results_list_addr, $result_object);

        #
        # Print error string to stdout
        #
        Print_Error($line, $column, $text, "$testcase : $error_string");
    }
}

#***********************************************************************
#
# Name: TT_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <tt> tag.  It checks for an xml:lang attribute.
#
#***********************************************************************
sub TT_Tag_Handler {
    my ($self, $tagname, %attr) = @_;

    my ($lang);

    #
    # Do we have a language attribute ?
    #
    if ( ! defined($attr{"xml:lang"}) ) {
        #
        # Missing language attribute
        #
        Record_Result("WCAG_2.0-SC3.1.1", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("Missing tt language attribute") .
                      " 'xml:lang'");
    }
    else {
        #
        # Save language code, but strip off any dialect value
        #
        $lang = lc($attr{"xml:lang"});
        $lang =~ s/-.*$//g;

        #
        # Convert possible 2 character language code into a 3 character code.
        #
        if ( defined($language_map::iso_639_1_iso_639_2T_map{$lang}) ) {
            $lang = $language_map::iso_639_1_iso_639_2T_map{$lang};
            print "tt language is $lang\n" if $debug;
        }
        else {
            print "Unknown tt language $lang\n" if $debug;
        }

        #
        # Does the lang attribute match the content language ?
        #
        if ( ($current_content_lang_code ne "" ) &&
             ($lang ne $current_content_lang_code) ) {
            Record_Result("WCAG_2.0-SC3.1.1", $self->current_line,
                      $self->current_column, $self->original_string,
                          String_Value("TT language attribute") .
                          " '$lang' " .
                          String_Value("does not match content language") .
                          " '$current_content_lang_code'");
        }
    }
}

#***********************************************************************
#
# Name: Start_Handler
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
sub Start_Handler {
    my ($self, $tagname, %attr) = @_;

    #
    # Check tags.
    #
    print "Start_Handler tag $tagname\n" if $debug;
    if ( $tagname eq "tt" ) {
        TT_Tag_Handler($self, $tagname, %attr);
    }
}

#***********************************************************************
#
# Name: End_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles end tags.
#
#***********************************************************************
sub End_Handler {
    my ($self, $tagname) = @_;

    #
    # Check tag
    #
    print "End_Handler tag $tagname\n" if $debug;

}

#***********************************************************************
#
# Name: Char_Handler
#
# Parameters: self - reference to this parser
#             string - text
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles text content between tags.
#
#***********************************************************************
sub Char_Handler {
    my ($self, $string) = @_;

    #
    # Are we saving text ?
    #
    if ( $save_text_between_tags ) {
        $saved_text .= $string;
    }
}

#***********************************************************************
#
# Name: XML_TTML_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             content - XML content pointer
#
# Description:
#
#   This function runs a number of technical QA checks on XML content.
#
#***********************************************************************
sub XML_TTML_Check {
    my ($this_url, $language, $profile, $content) = @_;

    my (@tqa_results_list, $result_object, $parser, $eval_output);
    my ($lang_code, $lang, $ttml_content, $status);

    #
    # Do we have a valid profile ?
    #
    print "XML_TTML_Check: Checking URL $this_url, lanugage = $language, profile = $profile\n" if $debug;
    if ( ! defined($xml_ttml_check_profile_map{$profile}) ) {
        print "XML_TTML_Check: Unknown XML testcase profile passed $profile\n";
        return(@tqa_results_list);
    }

    #
    # Save URL in global variable
    #
    if ( ($this_url =~ /^http/i) || ($this_url =~ /^file/i) ) {
        $current_url = $this_url;
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of XML
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Did we get any content ?
    #
    if ( length($$content) == 0 ) {
        print "No content passed to XML_TTML_Check\n" if $debug;
        return(@tqa_results_list);
    }
    else {
        #
        # Get TTML content
        #
        ($lang_code, $ttml_content) = XML_TTML_Text_Extract_Text($$content);

        #
        # Get content language
        #
        ($lang_code, $lang, $status) = TextCat_Text_Language(\$ttml_content);

        #
        # Did we get a language from the content ?
        #
        if ( $status == 0 ) {
            #
            # Save language in a global variable
            #
            $current_content_lang_code = $lang_code;
        }
        else {
            $current_content_lang_code = "";
        }

        #
        # Create a document parser
        #
        print "XML_TTML_Check\n" if $debug;
        $parser = XML::Parser->new;

        #
        # Add handlers for some of the XML tags
        #
        $parser->setHandlers(Start => \&Start_Handler);
        $parser->setHandlers(End => \&End_Handler);

        #
        # Parse the content.
        #
        eval { $parser->parse($$content, ErrorContext => 2); };
        $eval_output = $@ if $@;
        print "Eval output = \"$eval_output\"\n" if $debug;
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "XML_TTML_Check results\n";
        foreach $result_object (@tqa_results_list) {
            print "Testcase: " . $result_object->testcase;
            print "  status   = " . $result_object->status . "\n";
            print "  message  = " . $result_object->message . "\n";
        }
    }

    #
    # Return list of results
    #
    return(@tqa_results_list);
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
    my (@package_list) = ("tqa_result_object", "tqa_testcases",
                          "language_map", "textcat", "xml_ttml_text");

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

