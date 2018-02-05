#***********************************************************************
#
# Name:   epub_opf_parse.pm
#
# $Revision: 705 $
# $URL: svn://10.36.148.185/TQA_Check/Tools/epub_opf_parse.pm $
# $Date: 2018-02-02 09:01:45 -0500 (Fri, 02 Feb 2018) $
#
# Description:
#
#   This file contains routines that parses and checks EPUB OPF files.
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
use File::Basename;

#
# Use WPSS_Tool program modules
#
use epub_item_object;
use epub_opf_object;
use language_map;
use tqa_result_object;
use tqa_testcases;
use url_check;


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
my ($spine_count, %item_id, %item_idref, %metadata_found, $metadata_tag_found);
my (%meta_refines, $current_refines, %title_ids, $current_title_id);
my (%id_location, $found_nav, $nav_item_object, $found_manifest);
my ($found_spine, $linear_spine_itemref_count);
my (@required_metadata) = ("dc:identifier", "dc:language", "dc:title");
my (%required_property) = (
  # property name
  "schema:accessibilityFeature", 1,
  "schema:accessibilityHazard", 1,
  "schema:accessMode", 1,
  "schema:accessModeSufficient", 1,
);
my (%property_testcase_id) = (
  "schema:accessMode",           "EPUB-META-001",
  "schema:accessModeSufficient", "EPUB-META-002",
  "schema:accessibilityFeature", "EPUB-META-003",
  "schema:accessibilityHazard",  "EPUB-META-004",
  "schema:accessibilitySummary", "EPUB-META-005",
  "schema:accessibilityAPI",     "EPUB-META-006",
  "schema:accessibilityControl", "EPUB-META-007",
);

#
# Required accessibility properties values.
#
my (%required_property_values) = (
  # property name, list of required values
  "schema:accessibilityFeature", "tableOfContents",
  "schema:accessMode",           "textual",
  "schema:accessModeSufficient", "textual",
  "schema:accessibilityHazard",  "none",
);

my (%metadata_values, $current_property);
my ($invalid_epub_version) = 0;
my (%epub_versions);

#
# Status values
#
my ($epub_check_pass)       = 0;
my ($epub_check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "does not match manifest",                     "does not match <manifest>",
    "Duplicate file in spine",                     "Duplicate file in <spine>",
    "Duplicate id",                                "Duplicate 'id'",
    "expecting",                                   "expecting",
    "expecting one of",                            "expecting one of",
    "Fails validation",                            "Fails validation",
    "Invalid EPUB version",                        "Invalid EPUB version",
    "Invalid media type for navigation file",       "Invalid 'media-type' for navigation file",
    "Invalid schema:accessibilityHazard property value", "Invalid 'schema:accessibilityHazard' property value",
    "Invalid title text value",                    "Invalid 'dc.title' text value",
    "Missing attribute",                           "Missing attribute",
    "Missing EPUB version",                        "Missing EPUB version",
    "Missing package file",                        "Missing 'package' file",
    "Missing required metadata property",          "Missing required metadata property",
    "Missing required metadata property value",    "Missing required metadata property value",
    "Missing schema:accessMode property value",    "Missing 'property=\"schema:accessMode\"' value",
    "Missing tag",                                 "Missing tag",
    "Missing text in",                             "Missing text in",
    "Missing textual sufficient access mode",      "Missing 'textual' sufficient access mode",
    "Multiple item tags with nav property",        "Multiple <item> tags with properties=\"nav\"",
    "Multiple spine tags found",                   "Multiple <spine> tags found",
    "Multiple values for",                         "Multiple values for",
    "Navigation file must be HTML",                "Navigation file must be HTML",
    "Navigation file not found in",                "Navigation file not found in",
    "No HTML resources in spine",                  "No HTML resources in <spine>",
    "No item found with",                          "No <item> found with",
    "No item tags found in manifest",              "No <item> tags found in <manifest>",
    "No itemref tags found in spine",              "No <itemref> tags found in <spine>",
    "No linear reading order content documents",   "No linear reading order content documents",
    "No manifest item matching",                   "No manifest item matching",
    "No navigation item found in spine",           "No navigation item found in <spine>",
    "Previous instance found at",                  "Previous instance found at (line:column) ",
    "referenced by",                               "referenced by",
    "Resource file not found",                     "Resource file not found",
    "Unexpected schema:accessibilitySummary property value", "Unexpected property=\"schema:accessibilitySummary\" value",
);

#
# String table for error strings (French).
#
my %string_table_fr = (
    "does not match manifest",                     "ne correspond pas <manifest>",
    "Duplicate file in spine",                     "Dupliquer le fichier dans <spine>",
    "Duplicate id",                                "Doublon 'id' ",
    "expecting",                                   "attendre",
    "expecting one of",                            "attend un de",
    "Fails validation",                            "Échoue la validation",
    "Invalid EPUB version",                        "Version EPUB invalide",
    "Invalid media type for navigation file",      "Valeur de 'media-type' non valide pour le fichier de navigation",
    "Invalid schema:accessibilityHazard property value", "Valeur de propriété 'schema:accessibilityHazard' non valide",
    "Invalid title text value",                    "Valeur de texte 'dc.title' est invalide",
    "Missing attribute",                           "attribut manquant",
    "Missing EPUB version",                        "Version EPUB manquante",
    "Missing package file",                        "Fichier 'package' manquant",
    "Missing required metadata property",          "Propriété de métadonnées requise manquante",
    "Missing required metadata property value",    "Valeur de propriété de métadonnées requise manquante",
    "Missing schema:accessMode property value",    "Valeur de 'property=\"schema:accessMode\"' manquante",
    "Missing tag",                                 "Balises manquant",
    "Missing text in",                             "Manquant texte dans",
    "Missing textual sufficient access mode",      "Manquant 'textual' mode d'accès suffisant",
    "Multiple item tags with nav property",        "Plusieurs balises <item> avec properties=\"nav\"",
    "Multiple spine tags found",                   "Plusieurs balises <spine> ont été trouvées",
    "Multiple values for",                         "Valeurs multiples pour",
    "Navigation file must be HTML",                "Le fichier de navigation doit être HTML",
    "Navigation file not found in",                "Fichier de navigation introuvable dans",
    "No HTML resources in spine",                  "Aucune ressource HTML dans <spine>",
    "No item found with",                          "Aucun <item> trouvé avec",
    "No item tags found in manifest",              "Pas de balises <itemr> trouvées dans <manifest>",
    "No itemref tags found in spine",              "Pas de balises <itemref> trouvées dans <spine>",
    "No linear reading order content documents",   "Aucun document de contenu de commande de lecture linéaire",
    "No manifest item matching",                   "Aucun <manifest> <item> correspondant",
    "No navigation item found in spine",           "Aucun élément de navigation trouvé dans <spine>",
    "Previous instance found at",                  "Instance précédente trouvée à (la ligne:colonne) ",
    "referenced by",                               "référencé par",
    "Resource file not found",                     "Fichier de ressources introuvable",
    "Unexpected schema:accessibilitySummary property value", "Valeur property=\"schema:accessibilitySummary\" inattendue",
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
    
    my ($type, $versions, $line, @version_list);

    #
    # Check for minimum EPUB version setting for testcase WCAG_2.0-Guideline41
    #
    if ( $testcase eq "WCAG_2.0-Guideline41" ) {
        #
        # Check each line of the testcase data
        #
        foreach $line (split(/\n/, $data)) {
            #
            # Split the data line into a technology type and versions
            #
            ($type, $versions) = split(/\s+/, $line, 2);

            if ( defined($versions) && ($type =~ /^EPUB_VERSIONS$/i) ) {
                #
                # Save the versions in a table for easy checking
                #
                @version_list = split(/\s+/, $versions);
                foreach (@version_list) {
                    $epub_versions{$_} = 1;
                }
                last;
            }
        }
    }
    #
    # Save any other testcase data into the table
    #
    else {
        $testcase_data{$testcase} = $data;
    }
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
    # If the EPUB version is invalid, we don't report any errors
    # other than the version error.
    #
    if ( $invalid_epub_version ) {
        return;
    }

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
    $saved_text = "";
    $save_text_between_tags = 1;
    $metadata_found{"dc:identifier"} = 1;
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
    if ( $saved_text ne "" ) {
        #
        # Do we already have a identifier setting?
        #
        $current_value = $epub_opf_object->identifier();
        if ( $current_value eq "" ) {
            #
            # Save identifier value
            #
            $epub_opf_object->identifier($saved_text);
            print "dc:identifier = \"$saved_text\"\n" if $debug;
        }
        else {
            #
            # Multiple identifier are valid.
            #
            print "Multiple values for dc:identifier, $current_value and $saved_text\n" if $debug;
        }
    }
    else {
        print "Missing value for dc:identifier\n" if $debug;
        Record_Result("WCAG_2.0-G134", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("Missing text in") . " <dc:identifier>");
    }

    #
    # Turn off text saving
    #
    $saved_text = "";
    $save_text_between_tags = 0;
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
    $saved_text = "";
    $save_text_between_tags = 1;
    $metadata_found{"dc:language"} = 1;
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
    $saved_text =~ s/^\s*//g;
    $saved_text =~ s/\s*$//g;

    #
    # Did we get a language value?
    #
    if ( $saved_text ne "" ) {
        #
        # Do we already have a language setting?
        #
        $current_lang = $epub_opf_object->language();
        if ( $current_lang eq "" ) {
            #
            # Convert language string into an 639.2 3 letter language code
            # and save it in the opf object.
            #
            $current_lang = ISO_639_2_Language_Code($saved_text);
            $epub_opf_object->language($current_lang);
            print "dc:language = \"$current_lang\"\n" if $debug;
        }
        else {
            #
            # Multiple language values are valid (e.g. multi-lingual document)
            #
            print "Multiple values for dc:language, $current_lang and $saved_text\n" if $debug;
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
    $saved_text = "";
    $save_text_between_tags = 0;
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

    my ($value);
    
    #
    # Get optional id attribute
    #
    if ( defined($attr{"id"}) ) {
        $value = $attr{"id"};
        $current_title_id = $value;
        print "Start of dc:title tag, id = $value\n" if $debug;
    }
    #
    # No id, do we have a language?
    #
    elsif ( defined($attr{"xml:lang"}) ) {
        $value = $attr{"xml:lang"};
        $current_title_id = $value;
        print "Start of dc:title tag, xml:lang = $value\n" if $debug;
    }
    #
    # No id or language, set id variable to "default"
    #
    else {
        $current_title_id = "default";
    }

    #
    # Start a text handler to capture the tag content
    #
    $saved_text = "";
    $save_text_between_tags = 1;
    $metadata_found{"dc:title"} = 1;
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

    my ($current_value, $invalid_title);
    my ($protocol, $domain, $file_path, $query, $url);

    #
    # Did we get a title value?
    #
    if ( $saved_text ne "" ) {
        #
        # Do we already have a title setting?
        #
        $current_value = $epub_opf_object->title();
        if ( $current_value eq "" ) {
            #
            # Save title value.  We may get another title that will take
            # precedence, but we use this one for now.
            #
            $epub_opf_object->title($saved_text);
            print "dc:title = \"$saved_text\"\n" if $debug;
        }
        else {
            #
            # Multiple title values are valid.
            #
            print "Multiple values for dc:title, $current_value and $saved_text\n" if $debug;
        }

        #
        # Did the start dc:title tag include an id attribute? If so we save
        # save the title in a table indexed by the id value.
        #
        if ( ! defined($title_ids{$current_title_id}) ) {
            $title_ids{$current_title_id} = $saved_text;
        }
        else {
            #
            # Multiple dc:title tags with no way to differentiate them.
            #
            print "Multiple dc:title tags with no language or id\n" if $debug;
            Record_Result("WCAG_2.0-F25", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Multiple values for") .
                          " <dc:title>");
        }

        #
        # See if the title is the same as the file name from the URL
        # Strip the name of the OPF file from the file path to get
        # the base EPUB file name.
        #
        ($protocol, $domain, $file_path, $query, $url) = URL_Check_Parse_URL($current_url);
        $file_path =~ s/:.*$//g;
        $file_path =~ s/^.*\///g;
        if ( lc($saved_text) eq lc($file_path) ) {
            Record_Result("WCAG_2.0-F25", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Invalid title text value") . " '$saved_text'");
        }

        #
        # Check the value of the title to see if it is an invalid title.
        # See if it is the default place holder title value generated
        # by a number of authoring tools.  Invalid titles may include
        # "untitled", "new document", ...
        #
        $saved_text =~ s/^[\s\n\r]*//g;
        $saved_text =~ s/[\s\n\r]*$//g;
        if ( defined($testcase_data{"WCAG_2.0-F25"}) ) {
            foreach $invalid_title (split(/\n/, $testcase_data{"WCAG_2.0-F25"})) {
                #
                # Do we have a match on the invalid title text ?
                #
                print "Check invalid title value \"$invalid_title\"\n" if $debug;
                if ( lc($saved_text) eq lc($invalid_title) ) {
                    Record_Result("WCAG_2.0-F25", $self->current_line,
                                  $self->current_column, $self->original_string,
                                  String_Value("Invalid title text value") .
                                  " '$saved_text'");
                }
            }
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
    $saved_text = "";
    $save_text_between_tags = 0;
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
    
    my ($item_object, $id, $href, $media_type, $dir, $properties);
    my (%properties_table);

    #
    # Get id attribute
    #
    if ( defined($attr{"id"}) ) {
        $id = $attr{"id"};
        
        #
        # Have we already seen an item tag with this id value?
        #
        if ( ! defined($item_id{$id}) ) {
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
        #
        # Get the directory for this O)PF container.  Item hrefs may be
        # relative to this directory.
        #
        $dir = $epub_opf_object->dir();
        $href = $attr{"href"};

        #
        # Is the href a URL?
        #
        if ( $href =~ /^http/ ) {
            print "External resource file reference, $href\n" if $debug;
        }
        #
        # Resource is assumed to be a file within the EPUB
        #
        else {
            #
            # Include the directory from the OPF file in the path for the
            # resource file.
            #
            $href = $dir . $href;
            
            #
            # Does the href exist in the extracted EPUB folder?
            #
            if ( ! -f $epub_opf_object->uncompressed_directory . "/$href" ) {
                print "Resource file not found, $href\n" if $debug;
                Record_Result("WCAG_2.0-G134", $self->current_line,
                              $self->current_column, $self->original_string,
                              String_Value("Resource file not found") .
                              " '$href'");
            }
        }
    }
    #
    # Missing href attribute
    #
    else {
        $href = "";
        Record_Result("WCAG_2.0-G134", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("Missing attribute") . " 'href'");
    }

    #
    # Get media-type attribute
    #
    if ( defined($attr{"media-type"}) ) {
        $media_type = $attr{"media-type"};
    }
    else {
        $media_type = "";
        Record_Result("WCAG_2.0-G134", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("Missing attribute") . " 'media-type'");
    }

    #
    # Create an item object and add it to the manifest of the OPF object
    #
    $item_object = epub_item_object->new($id, $href, $media_type);
    $epub_opf_object->add_to_manifest($item_object);
    $item_id{$id} = $item_object;
    
    #
    # Do we have a properties attribute?
    #
    if ( defined($attr{"properties"}) ) {
        $properties = $attr{"properties"};
        $item_object->properties($properties);
        %properties_table = $item_object->properties();
        
        #
        # Is this the navigation file?
        #
        if ( defined($properties_table{"nav"}) ) {
            #
            # We can have only 1 item with the nav property.
            #
            if ( $found_nav ) {
                print "Multiple nav items in the manifest\n" if $debug;
                Record_Result("WCAG_2.0-G134", $self->current_line,
                              $self->current_column, $self->original_string,
                              String_Value("Multiple item tags with nav property"));
            }
            else {
                #
                # Save reference to nav item object
                #
                $found_nav = 1;
                $nav_item_object = $item_object;
                print "Found navigation file with id $id\n" if $debug;
            }
            
            #
            # Is the media type HTML?
            #
            if ( $media_type ne "application/xhtml+xml" ) {
                Record_Result("WCAG_2.0-Guideline41", $self->current_line,
                              $self->current_column, $self->original_string,
                              String_Value("Invalid media type for navigation file") .
                              " \"$media_type\" " . String_Value("expecting") .
                              " \"application/xhtml+xml\"");
            }
        }
    }
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
#   This function handles the <itemref> tag.  It checks that
#    - the idref attribute is set and contains an id value
#      that matches an <item> tag.
#    - idref attributes are not duplicated
# It records the number of linear reading order items in the spine.
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
            Record_Result("EPUB-ACCESS-001", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Duplicate file in spine") .
                          " <itemref idref=\"$id\">" .
                          String_Value("Previous instance found at") .
                          $item_idref{$id});
        }
        else {
            #
            # Record the position of this itemref in the spine
            #
            print "Save itemref idref=$id in spine list\n" if $debug;
            $item_idref{$id} = $self->current_line . ":" . $self->current_column;
        }
        
        #
        # Does this id match an <item> id value?
        #
        if ( ! defined($item_id{$id}) ) {
            Record_Result("EPUB-ACCESS-001", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("No item found with") . " id=\"$id\"");
        }
    }

    #
    # Is there a linear attribute?
    #
    if ( defined($attr{"linear"}) && ($attr{"linear"} eq "no") ) {
        #
        # Content document is not in the linear reading order
        #
        print "Non-linear reading order content document\n" if $debug;
    }
    else {
        #
        # Content document is part of the linear reading order
        #
        $linear_spine_itemref_count++;
    }
}

#***********************************************************************
#
# Name: Manifest_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <manifest> tag.
#
#***********************************************************************
sub Manifest_Tag_Handler {
    my ($self, %attr) = @_;

    #
    # Set flag to indicate we found the <manifest>
    #
    print "Manifest_Tag_Handler, found <manifest>\n" if $debug;
    $found_manifest = 1;
}

#***********************************************************************
#
# Name: End_Manifest_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </manifest> tag.  It checks that
# at least one <item> appeared in the <manifest> and that there is
# an item with property="nav".
#
#***********************************************************************
sub End_Manifest_Tag_Handler {
    my ($self) = @_;

    my ($id);

    #
    # Did we fine at least 1 <item> tag?
    #
    if ( keys(%item_id) == 0 ) {
        Record_Result("WCAG_2.0-G134", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("No item tags found in manifest"));
    }
    #
    # Did we find an item with property="nav"
    #
    elsif ( ! $found_nav ) {
        Record_Result("EPUB-ACCESS-002", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("Navigation file not found in") .
                      " <manifest>");
    }
}

#***********************************************************************
#
# Name: Meta_Tag_Handler
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <meta> tag.  It checks the property attribute
# and starts a text handler to capture the tag value.
#
#***********************************************************************
sub Meta_Tag_Handler {
    my ($self, %attr) = @_;

    my ($value);

    #
    # Get property attribute
    #
    if ( defined($attr{"property"}) ) {
        $value = $attr{"property"};
        $current_property = $value;
        print "Start of meta tag, property = $value\n" if $debug;
    }
    else {
        $current_property = "";
    }

    #
    # Get refines attribute
    #
    if ( defined($attr{"refines"}) ) {
        $value = $attr{"refines"};
        $current_refines = $value;
        print "Start of meta tag, refines = $value\n" if $debug;
    }
    else {
        $current_refines = "";
    }

    #
    # Start a text handler to capture the tag content
    #
    $saved_text = "";
    $save_text_between_tags = 1;
}

#***********************************************************************
#
# Name: End_Meta_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </meta> tag.
#
#***********************************************************************
sub End_Meta_Tag_Handler {
    my ($self) = @_;

    my ($tcid, @list, $list_addr, $table_addr, %table);

    #
    # Trim leading and trailing whitespace
    #
    $saved_text =~ s/^\s*//g;
    $saved_text =~ s/\s*$//g;

    #
    # Do we have a testcase identifier for this metadata property? If
    # we don't then we skip checking the value.
    #
    print "End of meta tag, current property = $current_property\n" if $debug;
    print "Saved text = \"$saved_text\"\n" if $debug;
    if ( defined($property_testcase_id{$current_property}) ) {
        #
        # Did we get a tag value?
        #
        $tcid = $property_testcase_id{$current_property};
        if ( $saved_text eq "" ) {
            print "Missing value for meta property=$current_property\n" if $debug;
            Record_Result($tcid, $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Missing text in") . " <meta property=\"$current_property\">");
        }
    
        #
        # Save the metadata value
        #
        if ( ! defined($metadata_values{$current_property}) ) {
            $metadata_values{$current_property} = \@list;
        }
        $list_addr = $metadata_values{$current_property};
        push(@$list_addr, $saved_text);
        print "Save \"$saved_text\" to metadata files for $current_property\n" if $debug;
    }
    
    #
    # If we have a refines value, this meta tag refines another tag with the
    # same id value.
    #
    if ( $current_refines ne "" ) {
        #
        # Get address of table to store meta tag value
        #
        if ( ! defined($meta_refines{$current_refines}) ) {
            $meta_refines{$current_refines} = \%table;
        }
        $table_addr = $meta_refines{$current_refines};

        #
        # Save metadata value in a table indexed by the property value
        #
        $$table_addr{$current_property} = $saved_text;
    }
    
    #
    # Is the current property "schema:accessibilitySummary"?
    # This is used to provide a brief summary of accessibility deficiencies
    # in the EPUB document.  If this metadata item exists, with content,
    # it implies there is an accessibility convern with the document.
    #
    if ( ($current_property eq "schema:accessibilitySummary") &&
         ($saved_text ne "") ) {
                Record_Result($tcid, $self->current_line,
                              $self->current_column, $self->original_string,
                              String_Value("Unexpected schema:accessibilitySummary property value") .
                              " \"$saved_text\"");
    }
    
    #
    # Turn off text saving
    #
    $saved_text = "";
    $save_text_between_tags = 0;

    #
    # Clear the current property and refines values
    #
    $current_property = "";
    $current_refines = "";
}

#***********************************************************************
#
# Name: End_Metadata_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </metadata> tag. It checks to see that
# all required metadata items were found.
#
#***********************************************************************
sub End_Metadata_Tag_Handler {
    my ($self) = @_;

    my ($tcid, $value, $list_addr, $found_textual, $mode, $property);
    my ($all_access_modes, $required_value, $found, %access_modes);
    my (@list, $id, $table_addr);

    #
    # Have end of metadata
    #
    $metadata_tag_found = 1;
    
    #
    # Check all required metadata properties
    #
    foreach $property (keys(%required_property)) {
        #
        # Did we find this metadata property?
        #
        print "Check required property $property\n" if $debug;
        $tcid = $property_testcase_id{$property};
        if ( ! defined($metadata_values{$property}) ) {
            print "Missing <meta property=\"$property\">\n" if $debug;
            Record_Result($tcid, $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Missing required metadata property") .
                          " <meta property=\"$property\">");
        }
        #
        # Do we have required values for this property?
        #
        elsif ( defined($required_property_values{$property}) ) {
            $list_addr = $metadata_values{$property};
            foreach $required_value (split(/,\s*/, $required_property_values{$property})) {
                print "Check required property value $required_value\n" if $debug;
                $found = 0;
                foreach $value (@$list_addr) {
                    #
                    # Does this value match the required value?
                    #
                    if ( $value eq $required_value ) {
                        $found = 1;
                        last;
                    }
                }
                
                #
                # Did we find the required property value?
                #
                if ( ! $found ) {
                    Record_Result($tcid, $self->current_line,
                                  $self->current_column, $self->original_string,
                                  String_Value("Missing required metadata property value") .
                                  " <meta property=\"$property\">$required_value</meta>");
                }
            }
        }
    }
    
    #
    # Get a table of all access mode values
    #
    if ( defined($metadata_values{"schema:accessMode"}) ) {
        $list_addr = $metadata_values{"schema:accessMode"};
        foreach $mode (@$list_addr) {
            $access_modes{$mode} = 1;
        }
    }

    #
    # Check the sufficient accessibility mode.  In order to be fully
    # accessible it must have a textual mode (e.g. for screen reader users).
    #
    $tcid = $property_testcase_id{"schema:accessModeSufficient"};
    if ( defined($metadata_values{"schema:accessModeSufficient"}) ) {
        print "Check that schema:accessModeSufficient values appear in schema:accessMode value set\n" if $debug;
        $list_addr = $metadata_values{"schema:accessModeSufficient"};
        
        #
        # Check that each value in schema:accessModeSufficient also
        # appears in schema:accessMode property values also.
        #
        $found_textual = 0;
        @list = @$list_addr;
        foreach $value (@list) {
            #
            # The value may be a comma seperated list, check each
            # value against the values in the schema:accessMode properties.
            #
            print "Check schema:accessModeSufficient value $value\n" if $debug;
            foreach $mode (split(/,\s*/, $value)) {
                print "Check for schema:accessModeSufficient value \"$mode\" in schema:accessMode values\n" if $debug;
                if ( ! defined($access_modes{$mode}) ) {
                    Record_Result($tcid, $self->current_line,
                                  $self->current_column, $self->original_string,
                                  String_Value("Missing schema:accessMode property value") . " \"$mode\" " .
                                  String_Value("referenced by") .
                                  " <meta property=\"schema:accessModeSufficient\">$value</meta>");
                }
            }
            
            #
            # Check the sufficient accessibility mode for the value "textual".
            # In order to be fully accessible there must be a textual mode
            # (e.g. for screen reader users).
            #
            if ( $value =~ /^\s*textual\s*$/i ) {
                $found_textual = 1;
            }
        }
        
        #
        # Did we not find a textual sufficient accessibility mode
        #
        if ( ! $found_textual ) {
            Record_Result($tcid, $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Missing textual sufficient access mode") .
                          " <meta property=\"schema:accessModeSufficient\">textual</meta>");
        }
    }

    #
    # Check the accessibility hazard.  In order to be fully
    # accessible there must be no accessibility hazards, the only
    # acceptable value is "none".
    #
    $tcid = $property_testcase_id{"schema:accessibilityHazard"};
    if ( defined($metadata_values{"schema:accessibilityHazard"}) ) {
        print "Check that schema:accessibilityHazard values\n" if $debug;
        $list_addr = $metadata_values{"schema:accessibilityHazard"};

        #
        # Check each value in schema:accessibilityHazard to ensure it is
        # "none".
        #
        @list = @$list_addr;
        foreach $value (@list) {
            print "Check schema:accessibilityHazard value $value\n" if $debug;
            if ( $value ne "none" ) {
                Record_Result($tcid, $self->current_line,
                              $self->current_column, $self->original_string,
                              String_Value("Invalid schema:accessibilityHazard property value") . " \"$value\" " .
                              String_Value("expecting") .
                              " <meta property=\"schema:accessibilityHazard\">none</meta>");
            }
        }
    }

    #
    # Did we find all required metadata tags (e.g. dc.title)?
    #
    foreach $value (@required_metadata) {
        print "Check for required metadata item $value\n" if $debug;
        if ( ! defined($metadata_found{$value}) ) {
            Record_Result("WCAG_2.0-G134", -1, 0, "",
                      String_Value("Missing metadata item") . " <$value>");
        }
    }
    
    #
    # Did we find any <meta> tags that change the default title?
    # E.g. a <meta refines> tag.
    #
    print "Check for <meta refines> to change default dc:title\n" if $debug;
    foreach $id (keys(%meta_refines)) {
        $table_addr = $meta_refines{$id};
        
        #
        # Check for property "title-type" with value of "main".
        # This indicates the id is the id of the main title.
        #
        if ( defined($$table_addr{"title-type"}) &&
             ($$table_addr{"title-type"} eq "main") ) {
            #
            # Do we have a title with an id matching the refines id value?
            #
            print "Have <meta refines=\"$id\" property=\"title-type\">main</meta>\n" if $debug;
            if ( defined($title_ids{$id}) ) {
                print "Set EPUB title to " . $title_ids{$id} . "\n" if $debug;
                $epub_opf_object->title($title_ids{$id});
                last;
            }
            else {
                print "<meta refines=\"$id\" references non existent <dc:title>\n" if $debug;
                
            }
        }
        #
        # Check for property "display-seq" with value of "1".
        # This indicates the id is the id of the main title.
        #
        elsif ( defined($$table_addr{"display-seq"}) &&
             ($$table_addr{"display-seq"} eq "1") ) {
            #
            # Do we have a title with an id matching the refines id value?
            #
            print "Have <meta refines=\"$id\" property=\"display-seq\">1</meta>\n" if $debug;
            if ( defined($title_ids{$id}) ) {
                print "Set EPUB title to " . $title_ids{$id} . "\n" if $debug;
                $epub_opf_object->title($title_ids{$id});
                last;
            }
            else {
                print "<meta refines=\"$id\" references non existent <dc:title>\n" if $debug;

            }
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
    
    my ($version, $message);

    #
    # Get version attribute
    #
    if ( defined($attr{"version"}) ) {
        $version = $attr{"version"};
        print "Found package version attribute $version\n" if $debug;
        $epub_opf_object->version($version);

        #
        # Is the EPUB version an acceptable version?
        #
        if ( ! defined($epub_versions{$version}) ) {
            print "EPUB version not valid\n" if $debug;
            if ( keys(%epub_versions) > 1 ) {
                $message = String_Value("expecting one of") . " ";
            }
            else {
                $message = String_Value("expecting") . " ";
            }
            Record_Result("WCAG_2.0-Guideline41", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Invalid EPUB version") . " $version " .
                          $message .
                          join(", ",sort(keys(%epub_versions))));
            $invalid_epub_version = 1;
        }
    }
    #
    # No version specified
    #
    else {
        print "EPUB version not specified\n" if $debug;
        Record_Result("WCAG_2.0-Guideline41", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("Missing EPUB version"));
        $invalid_epub_version = 1;
    }
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
    
    my ($toc_id);

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
    # Set flag to indicate we found the <spine>
    #
    print "Spine_Tag_Handler, found <spine>\n" if $debug;
    $found_spine = 1;
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
# - at least one <itemref> appears in the <spine>,
# - there are some resource that are part of the linear reading order
# - there is a navigation resource
#
#***********************************************************************
sub End_Spine_Tag_Handler {
    my ($self) = @_;
    
    my ($item_object, $id, $found_nav, $html_item_count, %properties_table);
    
    #
    # Did we fine at least 1 <itemref> tags?
    #
    if ( keys(%item_id) == 0 ) {
        Record_Result("EPUB-ACCESS-002", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("No itemref tags found in spine"));
    }
    #
    # Are all content documents not in the linear reading order
    # (i.e. have a linear="no" attribute).
    #
    elsif ( $linear_spine_itemref_count == 0 ) {
        Record_Result("EPUB-ACCESS-001", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("No linear reading order content documents"));
    }
    
    #
    # Check to see if there is a navigation resource in the spine.
    # Count the number of HTML items referenced in the spine.  If
    # there are no HTML items, then the EPUB document is not
    # accessible.
    #
    $found_nav = 0;
    $html_item_count = 0;
    foreach $id (keys(%item_idref)) {
        #
        # Does the id reference a valid item ?
        #
        if ( ! defined($item_id{$id}) ) {
            #
            # Invalid id, don't need to report it here as it was already
            # reported in the itemref tab handler.
            #
            print "Invalid id in itemref $id\n" if $debug;
            next;
        }
        
        #
        # Does this item have properties="nav"?
        #
        $item_object = $item_id{$id};
        %properties_table = $item_object->properties();
        if ( defined($properties_table{"nav"}) ) {
            $found_nav = 1;
        }
        #
        # Is this an HTML content document item?
        #
        elsif ( $item_object->media_type() eq "application/xhtml+xml" ) {
            $html_item_count++;
        }
    }
    
    #
    # Did we find a navigation resource?
    #
    if ( ! $found_nav ) {
        Record_Result("EPUB-ACCESS-002", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("No navigation item found in spine"));
    }
    
    #
    # Did we find at least 1 HTML item?
    #
    if ( $html_item_count > 0 ) {
        print "Spine has $html_item_count HTML items\n" if $debug;
    }
    else {
        Record_Result("WCAG_2.0-Guideline41", $self->current_line,
                      $self->current_column, $self->original_string,
                      String_Value("No HTML resources in spine"));
    }
}

#***********************************************************************
#
# Name: Check_Attributes
#
# Parameters: self - reference to this parser
#             attr - hash table of attributes
#
# Description:
#
#   This function checks attributes for tags.  If an id tag is
# specified, it checks to see that it is unique.
#
#***********************************************************************
sub Check_Attributes {
    my ($self, %attr) = @_;
    
    my ($id);
    
    #
    # Do we have an id attribute?
    #
    if ( defined($attr{"id"}) ) {
        $id = $attr{"id"};

        #
        # Have we already seen a tag with this id value?
        #
        if ( defined($id_location{$id}) ) {
            Record_Result("WCAG_2.0-F77", $self->current_line,
                          $self->current_column, $self->original_string,
                          String_Value("Duplicate id") . " \"$id\" " .
                          String_Value("Previous instance found at") .
                          $id_location{$id});
        }
        else {
            $id_location{$id} = $self->current_line . ":" . $self->current_column;
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
    # Check common attributes
    #
    Check_Attributes($self, %attr);
    
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
    # Check for itemref tag.
    #
    elsif ( $tagname eq "itemref" ) {
        Itemref_Tag_Handler($self, %attr);
    }
    #
    # Check for manifest tag.
    #
    elsif ( $tagname eq "manifest" ) {
        Manifest_Tag_Handler($self, %attr);
    }
    #
    # Check for meta tag.
    #
    elsif ( $tagname eq "meta" ) {
        Meta_Tag_Handler($self, %attr);
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
    # Check for manifest tag
    #
    elsif ( $tagname eq "manifest" ) {
        End_Manifest_Tag_Handler($self);
    }
    #
    # Check for meta tag
    #
    elsif ( $tagname eq "meta" ) {
        End_Meta_Tag_Handler($self);
    }
    #
    # Check for metadata tag
    #
    elsif ( $tagname eq "metadata" ) {
        End_Metadata_Tag_Handler($self);
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

    my ($parser, $eval_output, $value, @tqa_results, $opf_dir, $count);
    my ($id);

    #
    # Check testcase profile
    #
    print "EPUB_OPF_Parse: Checking URL $this_url, file = $filename, profile = $profile\n" if $debug;
    if ( ! defined($epub_check_profile_map{$profile}) ) {
        print "Unknown EPUB testcase profile passed $profile\n";
        return(\@tqa_results, $epub_opf_object);
    }

    #
    # Initialize unit globals.
    #
    print "EPUB_OPF_Parse $filename in directory $epub_uncompressed_dir/\n" if $debug;
    $results_list_addr = \@tqa_results;
    $current_epub_check_profile = $epub_check_profile_map{$profile};
        
    #
    # Save URL in global variable
    #
    if ( ($this_url =~ /^http/i) || ($this_url =~ /^file/i) ) {
        $current_url = $this_url . ":$filename";
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of content
        # from the standalone validator which does not have a URL.
        #
        $current_url = "$filename";
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
        # Set the directory for the OPF file.  The items listed in the manifest
        # are relative to the OPF file.
        #
        $opf_dir = dirname($filename);
        if ( $opf_dir eq "." ) {
            $epub_opf_object->dir("/");
        }
        else {
            $epub_opf_object->dir("$opf_dir/");
        }

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
        # Set parser global variables
        #
        $current_property = "";
        $current_refines = "";
        $current_title_id = "default";
        $found_nav = 0;
        $found_manifest = 0;
        $found_spine = 0;
        %id_location = ();
        $invalid_epub_version = 0;
        %item_id = ();
        %item_idref = ();
        $linear_spine_itemref_count = 0;
        %metadata_found = ();
        %meta_refines = ();
        $metadata_tag_found = 0;
        %metadata_values = ();
        undef $nav_item_object;
        $save_text_between_tags = 0;
        $saved_text = "";
        $spine_count = 0;
        %title_ids = ();

        #
        # Parse the OPF file.
        #
        print "Parse OPF file\n" if $debug;
        eval { $parser->parsefile("$epub_uncompressed_dir/$filename"); };
        $eval_output = $@ if $@;
        
        #
        # Did the parsing fail ?
        #
        if ( defined($eval_output) && ($eval_output ne "1") ) {
            $eval_output =~ s/\n at .* line \d*$//g;
            print "Parse of EPUB OPF file failed \"$eval_output\"\n" if $debug;
            Record_Result("WCAG_2.0-G134", -1, 0, "",
                      String_Value("Fails validation") . " \"$eval_output\"");
        }
        else {
        
            #
            # Did we find a <manifest> with items?
            #
            if ( ! $found_manifest ) {
                Record_Result("WCAG_2.0-G134", -1, 0, "",
                          String_Value("Missing tag") . " <manifest>");
            }

            #
            # Did we find a <spine> tag?
            #
            print "End parsing of OPF file, spine count = $spine_count\n" if $debug;
            if ( ! $found_spine ) {
                Record_Result("WCAG_2.0-G134", -1, 0, "",
                              String_Value("Missing tag") . " <spine>");
            }

            #
            # Did we find a <metadata> tag?
            #
            if ( ! $metadata_tag_found ) {
                Record_Result("WCAG_2.0-G134", -1, 0, "",
                          String_Value("Missing tag") . " <metadata>");
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

