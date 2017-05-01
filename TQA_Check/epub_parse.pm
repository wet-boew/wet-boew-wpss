#***********************************************************************
#
# Name:   epub_parse.pm
#
# $Revision: 358 $
# $URL: svn://10.36.20.203/TQA_Check/Tools/epub_parse.pm $
# $Date: 2017-04-28 10:49:15 -0400 (Fri, 28 Apr 2017) $
#
# Description:
#
#   This file contains routines that parse EPUB files.
#
# Public functions:
#     Set_EPUB_Parse_Debug
#     Set_EPUB_Parse_Language
#     Set_EPUB_Parse_Testcase_Data
#     Set_EPUB_Parse_Test_Profile
#     EPUB_Parse_Get_OPF_File
#     EPUB_Parse_Cleanup
#
# Terms and Conditions of Use
# 
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is 
# distributed under the MIT License.
# 
# MIT License
# 
# Copyright (c) 2017 Government of Canada
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

package epub_parse;

use strict;
use Cwd;
use XML::Parser;
use File::Basename;
use File::Path qw/ remove_tree /;
use File::Temp qw/ tempfile tempdir /;
use Archive::Zip qw(:ERROR_CODES);

#
# Use WPSS_Tool program modules
#
use tqa_result_object;
use tqa_testcases;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Set_EPUB_Parse_Debug
                  Set_EPUB_Parse_Language
                  Set_EPUB_Parse_Testcase_Data
                  Set_EPUB_Parse_Test_Profile
                  EPUB_Parse_Get_OPF_File
                  EPUB_Parse_Cleanup
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
my (%epub_check_profile_map, $current_epub_check_profile, $current_url);
my ($save_text_between_tags, $saved_text, $opf_file_name);

#
# Status values
#
my ($epub_check_pass)       = 0;
my ($epub_check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Error in reading EPUB, status =",              "Error in reading EPUB, status =",
    "Invalid media-type value in rootfile tag",     "Invalid 'media-type' value in 'rootfile' tag",
    "Missing full-path attribute in rootfile tag",  "Missing 'full-path' attribute in 'rootfile' tag",
    "Missing media-type attribute in rootfile tag",  "Missing 'media-type' attribute in 'rootfile' tag",
    "Missing META-INF/container.xml file",          "Missing META-INF/container.xml file",
    "Fails validation",                             "Fails validation",
    "rootfile not specified in container.xml file", "'rootfile' not specified in 'container.xml' file",
);

#
# String table for error strings (French).
#
my %string_table_fr = (
    "Error in reading EPUB, status =",             "Erreur de lecture fichier EPUB, status =",
    "Invalid media-type value in rootfile tag",    "Valeur de 'media-type' non valide dans la balise 'rootfile'",
    "Missing full-path attribute in rootfile tag", "Attribut 'full-path' manquant dans le balise 'rootfile'",
    "Missing media-type attribute in rootfile tag", "Attribut 'media-type' manquant dans le balise 'rootfile'",
    "Missing META-INF/container.xml file",         "Fichier META-INF/container.xml manquant",
    "Fails validation",                            "Échoue la validation",
    "rootfile not specified in container.xml file", "'rootfile' non spécifié dans le fichier 'container.xml'",
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_EPUB_Parse_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_EPUB_Parse_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_EPUB_Parse_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_EPUB_Parse_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_EPUB_Parse_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_EPUB_Parse_Language, language = English\n" if $debug;
        $string_table = \%string_table_en;
    }
}

#***********************************************************************
#
# Name: Set_EPUB_Parse_Testcase_Data
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
sub Set_EPUB_Parse_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_EPUB_Parse_Test_Profile
#
# Parameters: profile - EPUB check test profile
#             epub_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by testcase name.
#
#***********************************************************************
sub Set_EPUB_Parse_Test_Profile {
    my ($profile, $epub_checks) = @_;

    my (%local_epub_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_EPUB_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_epub_checks = %$epub_checks;
    $epub_check_profile_map{$profile} = \%local_epub_checks;
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
    if ( defined($testcase) && defined($$current_epub_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $epub_check_fail,
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
# Name: Container_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <container> tag.
#
#***********************************************************************
sub Container_Tag_Handler {
    my ($self, %attr) = @_;
}

#***********************************************************************
#
# Name: Rootfile_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <package> tag.
#
#***********************************************************************
sub Rootfile_Tag_Handler {
    my ($self, %attr) = @_;

    #
    # Check for a full-path attribute
    #
    if ( defined($attr{"full-path"}) ) {
        #
        # Check the media-type attribute
        #
        if ( ! defined($attr{"media-type"}) ) {
            Record_Result("WCAG_2.0-G134", -1, 0, "",
                          String_Value("Missing media-type attribute in rootfile tag"));
        }
        elsif ( $attr{"media-type"} ne "application/oebps-package+xml" ) {
            Record_Result("WCAG_2.0-G134", -1, 0, "",
                          String_Value("Invalid media-type value in rootfile tag") .
                          " \"" . $attr{"media-type"} . "\"");
        }
        else {
            $opf_file_name = $attr{"full-path"};
            $opf_file_name =~ s/^\s*//g;
            print "OPF File name " . $attr{"full-path"} . "\n" if $debug;
        }
    }
    else {
        Record_Result("WCAG_2.0-G134", -1, 0, "",
                      String_Value("Missing full-path attribute in rootfile tag"));
    }
}

#***********************************************************************
#
# Name: Rootfiles_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <rootfiles> tag.
#
#***********************************************************************
sub Rootfiles_Tag_Handler {
    my ($self, %attr) = @_;
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

    my ($key, $value);

    #
    # Check for container tag.
    #
    print "Start_Handler tag $tagname\n" if $debug;
    if ( $tagname eq "container" ) {
        Container_Tag_Handler($self, %attr);
    }
    #
    # Check for rootfile tag.
    #
    elsif ( $tagname eq "rootfile" ) {
        Rootfile_Tag_Handler($self, %attr);
    }
    #
    # Check for rootfiles tag.
    #
    elsif ( $tagname eq "rootfiles" ) {
        Rootfiles_Tag_Handler($self, %attr);
    }
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
# Name: End_Container_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </container> tag.
#
#***********************************************************************
sub End_Container_Tag_Handler {
    my ($self) = @_;

}

#***********************************************************************
#
# Name: End_Rootfile_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </rootfile> tag.
#
#***********************************************************************
sub End_Rootfile_Tag_Handler {
    my ($self) = @_;

}

#***********************************************************************
#
# Name: End_Rootfiles_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </rootfiles> tag.
#
#***********************************************************************
sub End_Rootfiles_Tag_Handler {
    my ($self) = @_;

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
    # Check for container tag
    #
    print "End_Handler tag $tagname\n" if $debug;
    if ( $tagname eq "container" ) {
        End_Container_Tag_Handler($self);
    }
    #
    # Check for rootfile tag
    #
    elsif ( $tagname eq "rootfile" ) {
        End_Rootfile_Tag_Handler($self);
    }
    #
    # Check for rootfiles tag
    #
    elsif ( $tagname eq "rootfiles" ) {
        End_Rootfiles_Tag_Handler($self);
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

    print "XML doctype $version, $encoding, $standalone\n" if $debug;
}

#***********************************************************************
#
# Name: EPUB_Parse_Get_OPF_File
#
# Parameters: this_url - a URL
#             resp - HTTP::Response object
#             profile - testcase profile
#             content - EPUB content pointer
#
# Description:
#
#   This function parses an EPUB file and returns the name of
# the OPF package file.
#
#***********************************************************************
sub EPUB_Parse_Get_OPF_File {
    my ($this_url, $resp, $profile, $content) = @_;

    my ($parser, $eval_output, $zip_file, $current_dir, @tqa_results_list);
    my ($temp_epub_fh, $epub_filename, $zip_status, $container_file);
    my ($epub_uncompressed_dir, $created_temp_file);

    #
    # Initialize unit globals.
    #
    $save_text_between_tags = 0;
    $saved_text = "";
    $opf_file_name = "";
    $current_epub_check_profile = $epub_check_profile_map{$profile};
    $results_list_addr = \@tqa_results_list;
    $epub_uncompressed_dir = "";

    #
    # Save URL in global variable
    #
    if ( ($this_url =~ /^http/i) || ($this_url =~ /^file/i) ) {
        $current_url = $this_url;
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of content
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }
    
    #
    # Have we already saved the EPUB content in a file (the EPUB validate
    # module will do this and store the file name in the HTTP::Response
    # object)?
    #
    if ( defined($resp) && (defined($resp->header("WPSS-Content-File"))) ) {
        $epub_filename = $resp->header("WPSS-Content-File");
        $created_temp_file = 0;
    }
    else {
        #
        # Save EPUB content in a temporary file
        #
        ($temp_epub_fh, $epub_filename) = tempfile("WPSS_TOOL_XXXXXXXXXX",
                                                   SUFFIX => '.epub',
                                                   TMPDIR => 1);

        #
        # Was the temporary file created?
        #
        if ( ! defined($temp_epub_fh) ) {
            print "Error: Failed to create temporary file in EPUB_Parse_Get_OPF_File\n";
            print STDERR "Error: Failed to create temporary file in EPUB_Parse_Get_OPF_File\n";
            return($results_list_addr, $opf_file_name, $epub_uncompressed_dir);
        }
        binmode $temp_epub_fh, ":utf8";
        print "Temporary EPUB file = $epub_filename\n" if $debug;
        print $temp_epub_fh $$content;
        close($temp_epub_fh);
        $created_temp_file = 1;
    }

    #
    # Uncompress the EPUB file into a temporary folder
    #
    $epub_uncompressed_dir = tempdir("WPSS_TOOL_EPUB_XXXXXXXXXX", TMPDIR => 1);
    $current_dir = getcwd;
    chdir($epub_uncompressed_dir);
    $zip_file = Archive::Zip->new($epub_filename);
    $zip_status = $zip_file->read($epub_filename);

    #
    # Did we read the ZIP successfully ?
    #
    if ( $zip_status != AZ_OK ) {
        print "Error reading archive, status = $zip_status\n" if $debug;
        undef($zip_file);
        Record_Result("WCAG_2.0-G134", -1, -1, "",
                      String_Value("Error in reading EPUB, status =")
                       . " $zip_status");
        chdir($current_dir);
        if ( $created_temp_file ) {
            unlink($epub_filename);
        }
        return($results_list_addr, $opf_file_name, $epub_uncompressed_dir);
    }
    
    #
    # Extract all files from the EPUB file
    #
    $zip_file->extractTree();
    print "EPUB extracted into $epub_uncompressed_dir\n" if $debug;
    chdir($current_dir);
    
    #
    # Remove the temporary EPUB file
    #
    if ( $created_temp_file ) {
        unlink($epub_filename);
    }
    
    #
    # Get the path to the container.xml file, it should be in the META-INF
    # directory.
    #
    $container_file = "$epub_uncompressed_dir/META-INF/container.xml";
    if ( -f $container_file ) {
        #
        # Create a document parser
        #
        $parser = XML::Parser->new;

        #
        # Add handlers for some of the XML tags
        #
        $parser->setHandlers(Start => \&Start_Handler);
        $parser->setHandlers(XMLDecl => \&Declaration_Handler);
        $parser->setHandlers(End => \&End_Handler);
        $parser->setHandlers(Char => \&Char_Handler);

        #
        # Parse the container file.
        #
        $eval_output = eval { $parser->parsefile($container_file); 1 } ;

        #
        # Did the parsing fail ?
        #
        if ( ! $eval_output ) {
            $eval_output =~ s/\n at .* line \d*$//g;
            print "Parse of EPUB file failed \"$eval_output\"\n" if $debug;
            Record_Result("WCAG_2.0-G134", -1, 0, "",
                      String_Value("Fails validation") . " \"$eval_output\"");
        }
        else {
            print "End parsing of container file\n" if $debug;
        }

        #
        # Did we get a rootfile (OPF file) ?
        #
        if ( $opf_file_name eq "" ) {
            Record_Result("WCAG_2.0-G134", -1, 0, "",
                          String_Value("rootfile not specified in container.xml file"));
        }
    }
    else {
        print "Missing container.xml file in EPUB_Parse_Get_OPF_File, file name = \"$container_file\"\n" if $debug;
        Record_Result("WCAG_2.0-G134", -1, 0, "",
                      String_Value("Missing META-INF/container.xml file"));
    }

    #
    # Return testcase results, EPUB OPF file name and EPUB directory
    #
    return($results_list_addr, $opf_file_name, $epub_uncompressed_dir);
}

#***********************************************************************
#
# Name: EPUB_Parse_Cleanup
#
# Parameters: epub_uncompressed_dir - directory
#
# Description:
#
#   This function cleans up any temporary files or directories created
# by this module.
#
#***********************************************************************
sub EPUB_Parse_Cleanup {
    my ($epub_uncompressed_dir) = @_;

    my ($error, $diag, $file, $message);

    #
    # Remove any EPUB uncompressed folder
    #
    if ( -d $epub_uncompressed_dir ) {
        print "Remove temporary EPUB uncompressed folder $epub_uncompressed_dir\n" if $debug;
        remove_tree($epub_uncompressed_dir, {error => \$error});

        #
        # Check for possible errors
        #
        if ( @$error ) {
            print "Error: Failed to remove_tree $epub_uncompressed_dir\n";
            for $diag (@$error) {
                ($file, $message) = %$diag;
                if ( $file eq '' ) {
                    print "general error: $message\n";
                }
                else {
                    print "problem unlinking $file: $message\n";
                }
            }
        }
    }
}

#***********************************************************************
#
# Mainline
#
#***********************************************************************

#
# Return true to indicate we loaded successfully
#
return 1;

