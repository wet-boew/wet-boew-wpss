#***********************************************************************
#
# Name:   epub_opf_parse.pm
#
# $Revision: 358 $
# $URL: svn://10.36.20.203/TQA_Check/Tools/epub_opf_parse.pm $
# $Date: 2017-04-28 10:49:15 -0400 (Fri, 28 Apr 2017) $
#
# Description:
#
#   This file contains routines that parse EPUB OPF files.
#
# Public functions:
#     Set_EPUB_OPF_Parse_Debug
#     Set_EPUB_OPF_Parse_Language
#     Set_EPUB_OPF_Parse_Testcase_Data
#     Set_EPUB_OPF_Parse_Test_Profile
#     EPUB_OPF_Parse
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

package epub_opf_parse;

use strict;
use XML::Parser;

#
# Use WPSS_Tool program modules
#
use epub_item_object;
use epub_opf_object;
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
    @EXPORT  = qw(Set_EPUB_OPF_Parse_Debug
                  Set_EPUB_OPF_Parse_Language
                  Set_EPUB_OPF_Parse_Testcase_Data
                  Set_EPUB_OPF_Parse_Test_Profile
                  EPUB_OPF_Parse
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my ($save_text_between_tags, $saved_text, $epub_opf_object);
my (%testcase_data, $results_list_addr);
my (%epub_check_profile_map, $current_epub_check_profile, $current_url);
my ($spine_count, %item_id, %item_idref, %metadata_found);
my (@required_metadata) =("dc:identifier", "dc:language", "dc:title");

#
# Status values
#
my ($epub_check_pass)       = 0;
my ($epub_check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Duplicate item id",                           "Duplicate <item> 'id'",
    "Duplicate itemref idref",                     "Duplicate <itemref> 'idref'",
    "Fails validation",                            "Fails validation",
    "Missing metadata item",                       "Missing metadata item",
    "Missing package file",                        "Missing 'package' file",
    "Missing spine tag",                           "Missing <spine> tag",
    "Missing text in",                             "Missing text in",
    "Multiple values for",                         "Multiple values for",
    "Multiple spine tags found",                   "Multiple <spine> tags found",
    "No item id matching",                         "No <item> 'id' matching <itemref> 'idref'",
    "No itemref tags found in spine",              "No <itemref> tags found in <spine>",
    "Previous instance found at",                  "Previous instance found at (line:column) ",
);

#
# String table for error strings (French).
#
my %string_table_fr = (
    "Duplicate item id",                           "Doublon <item> 'id' ",
    "Duplicate itemref idref",                     "Doublon <itemref> 'idref' ",
    "Fails validation",                            "Échoue la validation",
    "Missing metadata item",                       "Élément de métadonnées manquant",
    "Missing package file",                        "Fichier 'package' manquant",
    "Missing spine tag",                           "Balises <spine> manquant",
    "Missing text in",                             "Manquant texte dans",
    "Multiple values for",                         "Valeurs multiples pour",
    "Multiple spine tags found",                   "Plusieurs balises <spine> ont été trouvées",
    "No item id matching",                         "Aucune <item> 'id' correspondance de valeur",
    "No itemref tags found in spine",              "Pas de balises <itemref> trouvées dans <spine>",
    "Previous instance found at",                  "Instance précédente trouvée à (la ligne:colonne) ",
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;


#***********************************************************************
#
# Name: Set_EPUB_OPF_Parse_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_EPUB_OPF_Parse_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
    
    #
    # Set debug flag in supportig modules
    #
    Set_EPUB_Item_Object_Debug($debug);
}

#**********************************************************************
#
# Name: Set_EPUB_OPF_Parse_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_EPUB_OPF_Parse_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_EPUB_OPF_Parse_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_EPUB_OPF_Parse_Language, language = English\n" if $debug;
        $string_table = \%string_table_en;
    }
}

#***********************************************************************
#
# Name: Set_EPUB_OPF_Parse_Testcase_Data
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
sub Set_EPUB_OPF_Parse_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_EPUB_OPF_Parse_Test_Profile
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
sub Set_EPUB_OPF_Parse_Test_Profile {
    my ($profile, $epub_checks) = @_;

    my (%local_epub_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_EPUB_OPF_Parse_Test_Profile, profile = $profile\n" if $debug;
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
# Name: DC_Identifier_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <dc:identifier> tag.
#
#***********************************************************************
sub DC_Identifier_Tag_Handler {
    my ($self, %attr) = @_;

    #
    # Start a text handler to capture the tag content
    #
    $saved_text = 1;
    $save_text_between_tags = "";
    $metadata_found{"dc:identifier"} = 1;
}

#***********************************************************************
#
# Name: DC_Language_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <dc:language> tag.
#
#***********************************************************************
sub DC_Language_Tag_Handler {
    my ($self, %attr) = @_;

    #
    # Start a text handler to capture the tag content
    #
    $saved_text = 1;
    $save_text_between_tags = "";
    $metadata_found{"dc:language"} = 1;
}

#***********************************************************************
#
# Name: DC_Title_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <dc:title> tag.
#
#***********************************************************************
sub DC_Title_Tag_Handler {
    my ($self, %attr) = @_;

    #
    # Start a text handler to capture the tag content
    #
    $saved_text = 1;
    $save_text_between_tags = "";
    $metadata_found{"dc:title"} = 1;
}

#***********************************************************************
#
# Name: Item_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <item> tag.  It gets the file details
# and creates a new epub_manifest_object to store the details.
#
#***********************************************************************
sub Item_Tag_Handler {
    my ($self, %attr) = @_;
    
    my ($item_object, $id, $href, $media_type);

    #
    # Get id attribute
    #
    if ( defined($attr{"id"}) ) {
        $id = $attr{"id"};
        
        #
        # Have we already seen an item tag with this id value?
        #
        if ( defined($item_id{$id}) ) {
            Record_Result("WCAG_2.0-F77", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Duplicate item id") . " \"$id\" " .
                          String_Value("Previous instance found at") .
                          $item_id{$id});
        }
        else {
            $item_id{$id} = $self->current_line . ":" . $self->current_column;
        }
    }
    else {
        $id = "";
    }
    
    #
    # Get href attribute
    #
    if ( defined($attr{"href"}) ) {
        $href = $attr{"href"};
    }
    else {
        $href = "";
    }

    #
    # Get media-type attribute
    #
    if ( defined($attr{"media-type"}) ) {
        $media_type = $attr{"media-type"};
    }
    else {
        $media_type = "";
    }

    #
    # Create an item object and add it to the manifest of the OPF object
    #
    $item_object = epub_item_object->new($id, $href, $media_type);
    $epub_opf_object->add_to_manifest($item_object);
}

#***********************************************************************
#
# Name: Itemref_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <itemref> tag.  It checks that the idref
# attribute is set and contains an id value that matches an <item> tag.
#
#***********************************************************************
sub Itemref_Tag_Handler {
    my ($self, %attr) = @_;

    my ($item_object, $id, $href, $media_type);

    #
    # Get idref attribute
    #
    if ( defined($attr{"idref"}) ) {
        $id = $attr{"idref"};

        #
        # Have we already seen an item tag with this id value?
        #
        if ( defined($item_idref{$id}) ) {
            Record_Result("WCAG_2.0-G134", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Duplicate itemref idref") . " \"$id\" " .
                          String_Value("Previous instance found at") .
                          $item_idref{$id});
        }
        else {
            $item_idref{$id} = $self->current_line . ":" . $self->current_column;
        }
        
        #
        # Does this id match an <item> id value?
        #
        if ( ! defined($item_id{$id}) ) {
            Record_Result("WCAG_2.0-G134", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("No item id matching") . " <itemref idref=\"$id\">");
        }
    }
}

#***********************************************************************
#
# Name: Package_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <package> tag.
#
#***********************************************************************
sub Package_Tag_Handler {
    my ($self, %attr) = @_;

    #
    # Get version attribute
    #
    if ( defined($attr{"version"}) ) {
        $epub_opf_object->version($attr{"version"});
        print "EPUB version " . $attr{"version"} . "\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Spine_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <spine> tag.
#
#***********************************************************************
sub Spine_Tag_Handler {
    my ($self, %attr) = @_;
    
    my ($id);

    #
    # Have we already seen a <spine> tag?
    #
    if ( $spine_count > 0 ) {
        Record_Result("WCAG_2.0-G134", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("Multiple spine tags found"));
    }
    $spine_count++;
    
    #
    # Do we have a toc attribute?
    #
    if ( defined($attr{"toc"}) ) {
        $id = $attr{"toc"};

        #
        # Does this id match an <item> id value?
        #
        if ( ! defined($item_id{$id}) ) {
            Record_Result("WCAG_2.0-G134", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("No item id matching") . " <spine toc=\"$id\">");
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
   
    my ($key, $value);

    #
    # Check for dc:identifier tag.
    #
    print "Start_Handler tag $tagname\n" if $debug;
    if ( $tagname eq "dc:identifier" ) {
        DC_Identifier_Tag_Handler($self, %attr);
    }
    #
    # Check for dc:language tag.
    #
    elsif ( $tagname eq "dc:language" ) {
        DC_Language_Tag_Handler($self, %attr);
    }
    #
    # Check for dc:title tag.
    #
    elsif ( $tagname eq "dc:title" ) {
        DC_Title_Tag_Handler($self, %attr);
    }
    #
    # Check for item tag.
    #
    elsif ( $tagname eq "item" ) {
        Item_Tag_Handler($self, %attr);
    }
    #
    # Check for package tag.
    #
    elsif ( $tagname eq "package" ) {
        Package_Tag_Handler($self, %attr);
    }
    #
    # Check for spine tag.
    #
    elsif ( $tagname eq "spine" ) {
        Spine_Tag_Handler($self, %attr);
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
# Name: End_DC_Identifier_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </dc:identifier> tag.
#
#***********************************************************************
sub End_DC_Identifier_Tag_Handler {
    my ($self) = @_;

    my ($current_value);

    #
    # Did we get a identifier value?
    #
    if ( $save_text_between_tags ne "" ) {
        #
        # Do we already have a identifier setting?
        #
        $current_value = $epub_opf_object->identifier();
        if ( $current_value eq "" ) {
            #
            # Save identifier value
            #
            $epub_opf_object->identifier($save_text_between_tags);
            print "dc:identifier = \"$save_text_between_tags\"\n" if $debug;
        }
        else {
            print "Multiple values for dc:identifier, $current_value and $save_text_between_tags\n" if $debug;
            Record_Result("WCAG_2.0-G134", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Multiple values for") . " <dc:identifier>");
        }
    }
    else {
        print "Missing value for dc:identifier\n" if $debug;
        Record_Result("WCAG_2.0-G134", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("Missing text in") . " <dc:identifier>");
    }
}

#***********************************************************************
#
# Name: End_DC_Language_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </dc:language> tag.
#
#***********************************************************************
sub End_DC_Language_Tag_Handler {
    my ($self) = @_;
    
    my ($current_lang);

    #
    # Strip leading and trailing whitespace
    #
    $save_text_between_tags =~ s/^\s*//g;
    $save_text_between_tags =~ s/\s*$//g;
    
    #
    # Did we get a language value?
    #
    if ( $save_text_between_tags ne "" ) {
        #
        # Do we already have a language setting?
        #
        $current_lang = $epub_opf_object->language();
        if ( $current_lang eq "" ) {
            #
            # Save language value
            #
            $epub_opf_object->language($save_text_between_tags);
            print "dc:language = \"$save_text_between_tags\"\n" if $debug;
        }
        else {
            print "Multiple values for dc:language, $current_lang and $save_text_between_tags\n" if $debug;
            Record_Result("WCAG_2.0-SC3.1.1", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Multiple values for") . " <dc:language>");
        }
    }
    else {
        print "Missing value for dc:language\n" if $debug;
        Record_Result("WCAG_2.0-SC3.1.1", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("Missing text in") . " <dc:language>");
    }

    #
    # Turn off text saving
    #
    $saved_text = 0;
    $save_text_between_tags = "";
}

#***********************************************************************
#
# Name: End_DC_Title_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </dc:title> tag.
#
#***********************************************************************
sub End_DC_Title_Tag_Handler {
    my ($self) = @_;
    
    my ($current_value);

    #
    # Did we get a title value?
    #
    if ( $save_text_between_tags ne "" ) {
        #
        # Do we already have a title setting?
        #
        $current_value = $epub_opf_object->title();
        if ( $current_value eq "" ) {
            #
            # Save title value
            #
            $epub_opf_object->title($save_text_between_tags);
            print "dc:title = \"$save_text_between_tags\"\n" if $debug;
        }
        else {
            print "Multiple values for dc:title, $current_value and $save_text_between_tags\n" if $debug;
            Record_Result("WCAG_2.0-F25", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Multiple values for") . " <dc:title>");
        }
    }
    else {
        print "Missing value for dc:title\n" if $debug;
        Record_Result("WCAG_2.0-F25", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("Missing text in") . " <dc:title>");
    }

    #
    # Turn off text saving
    #
    $saved_text = 0;
    $save_text_between_tags = "";
}

#***********************************************************************
#
# Name: End_Package_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </package> tag.
#
#***********************************************************************
sub End_Package_Tag_Handler {
    my ($self) = @_;

}

#***********************************************************************
#
# Name: End_Spine_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </spine> tag.  It checks that
# at least one <itemref> appeared in the <spine>
#
#***********************************************************************
sub End_Spine_Tag_Handler {
    my ($self) = @_;
    
    #
    # Did we fine at least 1 <itemref> tags?
    #
    if ( keys(%item_id) == 0 ) {
        Record_Result("WCAG_2.0-G135", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("No itemref tags found in spine"));
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
    # Check for dc:identifier tag
    #
    print "End_Handler tag $tagname\n" if $debug;
    if ( $tagname eq "dc:identifier" ) {
        End_DC_Identifier_Tag_Handler($self);
    }
    #
    # Check for dc:language tag
    #
    elsif ( $tagname eq "dc:language" ) {
        End_DC_Language_Tag_Handler($self);
    }
    #
    # Check for dc:title tag
    #
    elsif ( $tagname eq "dc:title" ) {
        End_DC_Title_Tag_Handler($self);
    }
    #
    # Check for package tag
    #
    elsif ( $tagname eq "package" ) {
        End_Package_Tag_Handler($self);
    }
    #
    # Check for spine tag
    #
    elsif ( $tagname eq "spine" ) {
        End_Spine_Tag_Handler($self);
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
# Name: EPUB_OPF_Parse
#
# Parameters: this_url - a URL
#             epub_uncompressed_dir - directory containing EPUB files
#             filename - name of OPF file
#             profile - testcase profile
#
# Description:
#
#   This function parses an EPUB OPF file and returns an object
# containing the core details.
#
#***********************************************************************
sub EPUB_OPF_Parse {
    my ($this_url, $epub_uncompressed_dir, $filename, $profile) = @_;

    my ($parser, $eval_output, $value);

    #
    # Initialize unit globals.
    #
    print "EPUB_OPF_Parse $filename in directory $epub_uncompressed_dir/$filename\n" if $debug;
    $save_text_between_tags = 0;
    $saved_text = "";
    $spine_count = 0;
    %item_id = ();
    %item_idref = ();
    %metadata_found = ();

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
    # Do we have an OPF file ?
    #
    if ( -f "$epub_uncompressed_dir/$filename" ) {
        #
        # Create EPUB OPF object to hold details of the EPUB file.
        #
        $epub_opf_object = epub_opf_object->new($filename, $epub_uncompressed_dir);
        
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
        # Parse the OPF file.
        #
        $eval_output = eval { $parser->parsefile("$epub_uncompressed_dir/$filename"); 1 } ;
        
        #
        # Did the parsing fail ?
        #
        if ( ! $eval_output ) {
            $eval_output =~ s/\n at .* line \d*$//g;
            print "Parse of EPUB OPF file failed \"$eval_output\"\n" if $debug;
            Record_Result("WCAG_2.0-G134", -1, 0, "",
                      String_Value("Fails validation") . " \"$eval_output\"");
        }
        else {
            print "End parsing of OPF file\n" if $debug;

            #
            # Did we find a <spine> tag?
            #
            if ( $spine_count == 0 ) {
                Record_Result("WCAG_2.0-G134", -1, 0, "",
                          String_Value("Missing spine tag"));
            }
            
            #
            # Did we find all required metadata?
            #
            foreach $value (@required_metadata) {
                if ( ! defined($metadata_found{$value}) ) {
                    Record_Result("WCAG_2.0-G134", -1, 0, "",
                              String_Value("Missing metadata item") . " $value");
                }
            }
        }
    }
    else {
        print "Missing OPF file in EPUB_OPF_Parse, file name = \"$filename\"\n" if $debug;
        Record_Result("WCAG_2.0-G134", -1, 0, "",
                      String_Value("Missing package file") .
                      " \"$filename\"");
        undef $epub_opf_object;
    }

    #
    # Return address of results array and an EPUB OPF file object
    #
    return($results_list_addr, $epub_opf_object);
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

