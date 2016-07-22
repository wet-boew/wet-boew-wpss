#***********************************************************************
#
# Name:   open_data_xml.pm
#
# $Revision: 7624 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Open_Data/Tools/open_data_xml.pm $
# $Date: 2016-07-13 03:35:29 -0400 (Wed, 13 Jul 2016) $
#
# Description:
#
#   This file contains routines that parse XML files and check for
# a number of open data check points.
#
# Public functions:
#     Set_Open_Data_XML_Language
#     Set_Open_Data_XML_Debug
#     Set_Open_Data_XML_Testcase_Data
#     Set_Open_Data_XML_Test_Profile
#     Open_Data_XML_Check_Data
#     Open_Data_XML_Check_Dictionary
#     Open_Data_XML_Check_API
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

package open_data_xml;

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
    @EXPORT  = qw(Set_Open_Data_XML_Language
                  Set_Open_Data_XML_Debug
                  Set_Open_Data_XML_Testcase_Data
                  Set_Open_Data_XML_Test_Profile
                  Open_Data_XML_Check_Data
                  Open_Data_XML_Check_Dictionary
                  Open_Data_XML_Check_API
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
my (%open_data_profile_map, $current_open_data_profile, $current_url);
my ($tag_count, $save_text_between_tags, $saved_text);
my ($have_pwgsc_data_dictionary, $xsd_url);

my ($max_error_message_string)= 2048;

#
# Status values
#
my ($check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Duplicate definition",        "Duplicate definition",
    "Duplicate term",              "Duplicate term",
    "Encoding is not UTF-8, found", "Encoding is not UTF-8, found",
    "Fails validation",            "Fails validation",
    "for",                         "for",
    "found for",                   "found for",
    "found in",                    "found in",
    "found outside of",            "found outside of",
    "in",                          "in",
    "Invalid PWGSC XML data dictionary", "Invalid PWGSC XML data dictionary",
    "Invalid",                     "Invalid",
    "Missing text in <description>",  "Missing text in <description> for <heading>",
    "Missing text in <heading>",   "Missing text in <heading>",
    "Missing xml:lang in <description>", "Missing xml:lang in <description> for <heading>",
    "Missing",                     "Missing",
    "Multiple",                    "Multiple",
    "No content in API",           "No content in API",
    "No content in file",          "No content in file",
    "No terms in found data dictionary", "No terms found in data dictionary",
    "No",                          "No",
    "Previous instance found at",  "Previous instance found at line ",
    "tags found in",               "tags found in",
    "Unrecognized XML dictionary format", "Unrecognized XML dictionary format",
    );

my %string_table_fr = (
    "Duplicate definition",        "Doublon définition",
    "Duplicate term",              "Doublon term",
    "Encoding is not UTF-8, found", "Encoding ne pas UTF-8, trouvé",
    "Fails validation",            "Échoue la validation",
    "for",                         "pour",
    "found for",                   "trouvé pour",
    "found in",                    "trouvé dans",
    "found outside of",            "trouvent à l'extirieur de",
    "in",                          "dans",
    "Invalid PWGSC XML data dictionary", "TPSGC dictionnaire de donnies XML non valide",
    "Invalid",                     "Non valide",
    "Missing text in <description>",  "Manquant texte dans <description> pour <heading>",
    "Missing text in <heading>",   "Manquant texte dans <heading>",
    "Missing xml:lang in <description>", "Manquant xml:lang dans <description> pour <heading>",
    "Missing",                     "Manquant",
    "Multiple",                    "Plusieurs",
    "No content in API",           "Aucun contenu dans API",
    "No content in file",          "Aucun contenu dans fichier",
    "No terms found in data dictionary", "Pas de termes trouvés dans dictionnaire de données",
    "No",                          "Aucun",
    "Previous instance found at",  "Instance précédente trouvée à la ligne ",
    "tags found in",               "balises trouvées dans",
    "Unrecognized XML dictionary format", "Format de dictionnaire XML non reconnu",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_Open_Data_XML_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Open_Data_XML_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
    
    #
    # Set debug flag in supporting modules
    #
    Set_Open_Data_XML_Dictionary_Debug($debug);
}

#**********************************************************************
#
# Name: Set_Open_Data_XML_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Open_Data_XML_Language {
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
    Set_Open_Data_XML_Dictionary_Language($language);
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
# Name: Set_Open_Data_XML_Testcase_Data
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
sub Set_Open_Data_XML_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
    
    #
    # Set testcase data in supporting modules
    #
    Set_Open_Data_XML_Dictionary_Testcase_Data($testcase, $data);
}

#***********************************************************************
#
# Name: Set_Open_Data_XML_Test_Profile
#
# Parameters: profile - open data check test profile
#             testcase_names - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by open data testcase name.
#
#***********************************************************************
sub Set_Open_Data_XML_Test_Profile {
    my ($profile, $testcase_names) = @_;

    my (%local_testcase_names);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Open_Data_XML_Test_Profile, profile = $profile\n" if $debug;
    %local_testcase_names = %$testcase_names;
    $open_data_profile_map{$profile} = \%local_testcase_names;
    
    #
    # Set testcase profile in supporting modules
    #
    Set_Open_Data_XML_Dictionary_Test_Profile($profile, $testcase_names);
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - open data check test profile
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
    $current_open_data_profile = $open_data_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;
    $tag_count = 0;
    $save_text_between_tags = 0;
    $saved_text = "";
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
    my ( $testcase, $line, $column,, $text, $error_string ) = @_;

    my ($result_object);

    #
    # Is this testcase included in the profile
    #
    if ( defined($testcase) && defined($$current_open_data_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $check_fail,
                                                Open_Data_Testcase_Description($testcase),
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
# Name: Start_Text_Handler
#
# Parameters: none
#
# Description:
#
#   This function starts a text handler. It initializes global
# variables for text capture.
#
#***********************************************************************
sub Start_Text_Handler {

    #
    # Enable text capture and initialize captured string
    #
    $save_text_between_tags = 1;
    $saved_text = "";
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
# Name: Declaration_Handler
#
# Parameters: self - reference to this parser
#             version - XML version
#             encoding - ancoding attribute (if any)
#             standalone - standalone attribute
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles the declaration tag.
#
#***********************************************************************
sub Declaration_Handler {
    my ($self, $version, $encoding, $standalone) = @_;

    #
    # Check character encoding attribute.
    #
    print "XML doctype $version, $encoding, $standalone\n" if $debug;
    if ( $encoding =~ /UTF-8/i ) {
        print "Found UTF-8 encoding\n" if $debug;
    }
    else {
        Record_Result("OD_2", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("Encoding is not UTF-8, found") .
                      " \"$encoding\"");
    }
}

#***********************************************************************
#
# Name: Data_Start_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles the start of XML tags for data files.
#
#***********************************************************************
sub Data_Start_Handler {
    my ($self, $tagname, %attr) = @_;

    my ($key, $value);

    #
    # Check tags.
    #
    print "Data_Start_Handler tag $tagname\n" if $debug;
    $tag_count++;
}

#***********************************************************************
#
# Name: Data_End_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles end tags for data files.
#
#***********************************************************************
sub Data_End_Handler {
    my ($self, $tagname) = @_;

    #
    # Check tag
    #
    print "Data_End_Handler tag $tagname\n" if $debug;
}

#***********************************************************************
#
# Name: Open_Data_XML_Check_Data
#
# Parameters: this_url - a URL
#             profile - testcase profile
#             filename - XML content filename
#             dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function runs a number of open data checks on XML data file content.
#
#***********************************************************************
sub Open_Data_XML_Check_Data {
    my ( $this_url, $profile, $filename, $dictionary ) = @_;

    my ($parser, $url, @tqa_results_list, $result_object, $testcase);
    my ($eval_output);

    #
    # Do we have a valid profile ?
    #
    print "Open_Data_XML_Check_Data: Checking URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($open_data_profile_map{$profile}) ) {
        print "Open_Data_XML_Check_Data: Unknown testcase profile passed $profile\n";
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
    # Create a document parser
    #
    $parser = XML::Parser->new;

    #
    # Add handlers for some of the XML tags
    #
    $parser->setHandlers(Start => \&Data_Start_Handler);
    $parser->setHandlers(End => \&Data_End_Handler);
    $parser->setHandlers(XMLDecl => \&Declaration_Handler);
    $parser->setHandlers(Char => \&Char_Handler);

    #
    # Parse the content.
    #
    $eval_output = eval { $parser->parsefile($filename); 1 } ;

    #
    # Did the parse fail ?
    #
    if ( ! $eval_output ) {
        $eval_output =~ s/\n at .* line \d*$//g;
        Record_Result("OD_3", -1, 0, "$eval_output",
                      String_Value("Fails validation"));
    }
    #
    # Did we find some tags (may or may not be data) ?
    #
    elsif ( $tag_count == 0 ) {
        Record_Result("OD_3", -1, 0, "",
                      String_Value("No content in file"));
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "Open_Data_XML_Check_Data results\n";
        foreach $result_object (@tqa_results_list) {
            print "Testcase: " . $result_object->testcase;
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
# Name: Start_Data_Dictionary_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the start data-dictionary tag which is used to
# identify PWGSC XML data dictionary files.
#
#***********************************************************************
sub Start_Data_Dictionary_Tag_Handler {
    my ($self, %attr) = @_;

    #
    # This tag applies to PWGSC defined XML data dictionaries only.
    # Check that this is the first tag and that it has a dd_version attribute.
    #
    if ( ($tag_count == 1) && defined($attr{"dd_version"}) ) {
        #
        # We have a PWGSC dictionary
        #
        $have_pwgsc_data_dictionary = 1;
        print "Found PWGSC Data Dictionary\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Dictionary_Start_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles the start of XML tags for dictionary file.
#
#***********************************************************************
sub Dictionary_Start_Handler {
    my ($self, $tagname, %attr) = @_;
    
    my (@fields, $directory, $file_name);

    #
    # Check tags.
    #
    print "Dictionary_Start_Handler tag $tagname\n" if $debug;
    $tag_count++;

    #
    # Check for a possible xsi:schemaLocation attribute
    #
    if ( defined($attr{"xsi:schemaLocation"}) ) {
        $xsd_url = $attr{"xsi:schemaLocation"};

        #
        # Get the URL directory and file name components
        #
        @fields = split(/\s+/, $xsd_url);

        #
        # Join the URL components together
        #
        if ( @fields > 1 ) {
            $directory = $fields[0];
            $file_name = $fields[1];

            #
            # Is the file name component an absolute URL ?
            #
            if ( $file_name =~ /^http[s]:/ ) {
                $xsd_url = $file_name;
            }
            #
            # Does the directory URL have a trailing slash ?
            #
            elsif ( $directory =~ /\/$/ ) {
                $xsd_url = $directory . $file_name;
            }
            else {
                $xsd_url = "$directory/$file_name";
            }
        }
        else {
            $xsd_url = "";
        }
    }

    #
    # Check for PWGSC data-dictionary tag
    #
    if ( $tagname eq "data-dictionary" ) {
        Start_Data_Dictionary_Tag_Handler($self, %attr);
    }
}

#***********************************************************************
#
# Name: Dictionary_End_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles end tags for dictionary files.
#
#***********************************************************************
sub Dictionary_End_Handler {
    my ($self, $tagname) = @_;

    #
    # Check tag
    #
    print "Dictionary_End_Handler tag $tagname\n" if $debug;
}

#***********************************************************************
#
# Name: Initialize_Dictionary_Globals
#
# Parameters: dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function initialized global variables for PWGSC data dictionaries.
#
#***********************************************************************
sub Initialize_Dictionary_Globals {
    my ($dictionary) = @_;

    #
    # Initialize variables
    #
    $have_pwgsc_data_dictionary = 0;
    $tag_count = 0;
    $xsd_url = "";
}

#***********************************************************************
#
# Name: Open_Data_XML_Check_Dictionary
#
# Parameters: this_url - a URL
#             profile - testcase profile
#             filename - XML content file
#             dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function runs a number of open data checks on XML data file content.
#
#***********************************************************************
sub Open_Data_XML_Check_Dictionary {
    my ($this_url, $profile, $filename, $dictionary) = @_;

    my ($parser, $url, @tqa_results_list, $result_object, $testcase);
    my ($eval_output, @other_results);
    my ($validation_failed) = 0;

    #
    # Do we have a valid profile ?
    #
    print "Open_Data_XML_Check_Dictionary: Checking URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($open_data_profile_map{$profile}) ) {
        print "Open_Data_XML_Check_Dictionary: Unknown testcase profile passed $profile\n";
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
    # Create a document parser
    #
    $parser = XML::Parser->new;
        
    #
    # Initialize dictionary global variables
    #
    Initialize_Dictionary_Globals($dictionary);

    #
    # Add handlers for some of the XML tags
    #
    $parser->setHandlers(Start => \&Dictionary_Start_Handler);
    $parser->setHandlers(End => \&Dictionary_End_Handler);
    $parser->setHandlers(XMLDecl => \&Declaration_Handler);
    $parser->setHandlers(Char => \&Char_Handler);

    #
    # Parse the content.
    #
    $eval_output = eval { $parser->parsefile($filename); 1 } ;

    #
    # Did the parse fail ?
    #
    if ( ! $eval_output ) {
        $eval_output = $@;
        $eval_output =~ s/ at [\w:\/\.]*Parser.pm line \d*.*$//g;
        Record_Result("OD_3", -1, 0, "$eval_output",
                      String_Value("Fails validation"));
        $validation_failed = 1;
    }
    #
    # Did we get a XSD schema URL ?
    #
    elsif ( $xsd_url ne "" ) {
        #
        # Validate the XML against it.
        #
        $result_object = XML_Validate_XSD($this_url, "", $filename, $xsd_url, "OD_3",
                                          String_Value("Fails validation"));
        if ( defined($result_object) ) {
            push(@tqa_results_list, $result_object);
            $validation_failed = 1;
        }
    }
    
    #
    # If XML/XSD validation did not fail, check the contents of the
    # dictionary.
    #
    if ( ! $validation_failed ) {
        #
        # Did we find a PWGSC Data Dictionary ?
        #
        if ( $have_pwgsc_data_dictionary ) {
            #
            # Parse the PWGSC data dictionary
            #
            @other_results = Open_Data_XML_Dictionary_Check_Dictionary($this_url,
                                       $profile, $filename, $dictionary);
                           
            #
            # Add the results to the results list
            #
            foreach $result_object (@other_results) {
                push(@tqa_results_list, $result_object);
            }
        }
        #
        # Did we find some tags (may or may not be terms) ?
        #
        elsif ( $tag_count == 0 ) {
            Record_Result("OD_3", -1, 0, "",
                          String_Value("No terms found in data dictionary"));
        }
        #
        # Not a recognized XML dictionary format
        #
        else {
            Record_Result("TP_PW_OD_XML_1", -1, 0, "",
                          String_Value("Unrecognized XML dictionary format"));
        }
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "Open_Data_XML_Check_Dictionary results\n";
        foreach $result_object (@tqa_results_list) {
            print "Testcase: " . $result_object->testcase;
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
# Name: Open_Data_XML_Check_API
#
# Parameters: this_url - a URL
#             profile - testcase profile
#             filename - XML content filename
#
# Description:
#
#   This function runs a number of open data checks on XML API content.
#
#***********************************************************************
sub Open_Data_XML_Check_API {
    my ( $this_url, $profile, $filename, $dictionary ) = @_;

    my ($parser, $url, @tqa_results_list, $result_object, $testcase);
    my ($eval_output);

    #
    # Do we have a valid profile ?
    #
    print "Open_Data_XML_Check_API: Checking URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($open_data_profile_map{$profile}) ) {
        print "Open_Data_XML_Check_API: Unknown testcase profile passed $profile\n";
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
    # Create a document parser
    #
    $parser = XML::Parser->new;

    #
    # Add handlers for some of the XML tags
    #
    $parser->setHandlers(Start => \&Data_Start_Handler);
    $parser->setHandlers(End => \&DataI_End_Handler);
    $parser->setHandlers(XMLDecl => \&Declaration_Handler);
    $parser->setHandlers(Char => \&Char_Handler);

    #
    # Parse the content.
    #
    $eval_output = eval { $parser->parsefile($filename); 1 } ;

    #
    # Did the parse fail ?
    #
    if ( ! $eval_output ) {
        $eval_output = $@;
        $eval_output =~ s/ at [\w:\/\.]*Parser.pm line \d*.*$//g;
        Record_Result("OD_3", -1, 0, "$eval_output",
                      String_Value("Fails validation"));
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "Open_Data_XML_Check_API results\n";
        foreach $result_object (@tqa_results_list) {
            print "Testcase: " . $result_object->testcase;
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
    my (@package_list) = ("tqa_result_object", "open_data_testcases",
                          "open_data_xml_dictionary", "xml_validate");

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

