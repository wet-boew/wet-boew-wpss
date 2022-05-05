#***********************************************************************
#
# Name:   metadata.pm
#
# $Revision: 7607 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Metadata_Check/Tools/metadata.pm $
# $Date: 2016-06-22 10:49:19 -0400 (Wed, 22 Jun 2016) $
#
# Description:
#
#   This file contains routines that parse Metadata elements from
# a block of HTML content.  It also contains routines to validate
# the content value for specific content types (e.g. dates).
#
# Public functions:
#     Set_Required_Metadata_Tags
#     Set_Required_Metadata_Content
#     Set_Invalid_Metadata_Content
#     Set_Metadata_Content_Type
#     Set_Metadata_Debug
#     Set_Metadata_Scheme_Value
#     Metadata_Check_Language
#     Set_Metadata_Thesaurus_File
#     Validate_Metadata
#     Extract_Metadata
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

package metadata;

#
# Check for module to share data structures between threads
#
my $have_threads = eval 'use threads; 1';
if ( $have_threads ) {
    $have_threads = eval 'use threads::shared; 1';
}
use strict;
use HTML::Parser;
use File::Basename;
use HTML::Entities;
use Encode;

#
# Use WPSS_Tool program modules
#
use language_map;
use metadata_result_object;
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
    @EXPORT  = qw(Set_Metadata_Thesaurus_File
                  Set_Required_Metadata_Tags
                  Set_Required_Metadata_Content 
                  Set_Invalid_Metadata_Content
                  Metadata_Check_Language
                  Set_Metadata_Content_Type
                  Set_Metadata_Debug
                  Set_Metadata_Scheme_Value
                  Validate_Metadata
                  Extract_Metadata);
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;

my (%tag_required_profile_map, %content_required_profile_map,
    %invalid_content_profile_map, %content_type_map,
    %scheme_values_map, $metadata_result_objects, @content_lines,
    $current_url, $results_list_addr, %last_metadata_table,
    $have_text_handler,
);
my ($last_url) = "";

#
# Create a blank metadata profile that is used when extracting metadata
# values only
#
my (%empty_hash) =();
$tag_required_profile_map{""} = \%empty_hash;
$content_required_profile_map{""} = \%empty_hash;
$invalid_content_profile_map{""} = \%empty_hash;
$content_type_map{""} = \%empty_hash;
$scheme_values_map{""} = \%empty_hash;

my ($current_tag_required, $current_content_required,
    $current_invalid_content, $current_content_type,
    $current_scheme_values);

#
# Valid Robots Metadata tag content.
# The first list is the standard list.
# The 2nd list are extensions added for Google.
# The 3rd list are extensions added for Yahoo.
#
# Reference http://www.searchtools.com/robots/robots-meta.html
# 
my ($VALID_ROBOTS_CONTENT) = " all index noindex follow nofollow " .
        "nippet osnippet odp noodp archive noarchive imageindex noimageindex " .
        "ydir noydir ";

#
# Variables shared between threads
#
my (%thesaurus_profile_map_en, %thesaurus_profile_map_fr,
    %thesaurus_profile_filename, %thesaurus_files);
if ( $have_threads ) {
    share(\%thesaurus_profile_map_en);
    share(\%thesaurus_profile_map_fr);
    share(\%thesaurus_profile_filename);
    share(\%thesaurus_files);
}

#
# Status values
#
my ($metadata_success)      = 0;
my ($metadata_error)        = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "and",             "and",
    "date",            "date ",
    "Date",            "Date ",
    "Date after",      "Date after",
    "Date prior to",   "Date prior to",
    "Date value",      "Date value ",
    "do not match",    "do not match",
    "Email address",   "Email address ",
    "for scheme",      " for scheme",
    "for attribute",   " for attribute ",
    "Invalid content", "Invalid content: ",
    "Invalid scheme",  "Invalid scheme: ",
    "Invalid separator for terms, found comma, expecting semicolon", "Invalid separator for terms, found comma, expecting semicolon",
    "Invalid term",    "Invalid term(s) ",
    "is not valid",    " is not valid",
    "Metadata tag",    "Metadata tag",
    "Missing content", "Missing content: ",
    "Missing tag",     "Missing tag: ",
    "Month",           "Month ",
    "not in YYYY-MM-DD format", " not in YYYY-MM-DD format",
    "out of range 1-12", " out of range 1-12",
    "out of range 1-31", " out of range 1-31",
    "out of range 1900-2100", " out of range 1900-2100",
    "Year",           "Year ",
    );

#
# String table for error strings (French).
#
my %string_table_fr = (
    "and",            "et",
    "date",           "date ",
    "Date",           "Date ",
    "Date after",     "Date après",
    "Date prior to",  "Date antérieure à",
    "Date value",     "Valeur à la date ",
    "do not match",   "ne correspondent pas",
    "Email address",  "Adresse e-mail ",
    "for attribute",  " pour attribute ",
    "for scheme",     " pour scheme",
    "Invalid content", "Contenu non valide: ",
    "Invalid scheme", "Scheme non valide: ",
    "Invalid separator for terms, found comma, expecting semicolon", "Séparateur invalide pour les termes, trouvé virgule, en attendant un point-virgule",
    "Invalid term",   "Invalides terme ",
    "is not valid",   " n'est pas valide",
    "Missing content", "Manque de contenu: ",
    "Metadata tag",   "Balise de métadonnées",
    "Missing tag",    "Manquants balise: ",
    "Month",          "Mois ",
    "not in YYYY-MM-DD format", " pas au format AAAA-MM-DD",
    "out of range 1-12", " hors de portée 1-12",
    "out of range 1-31", " hors de portée 1-31",
    "out of range 1900-2100", " hors de portée 1900-2000",
    "Year",           "Année ",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#
# String tables for testcase ID to testcase descriptions
#
my (%testcase_description_en) = (
"METADATA",  "Metadata Profile",
"TAG",       "Metadata tag",
"CONTENT",   "Metadata content",
);

my (%testcase_description_fr) = (
"METADATA",  "Profil de métadonnées",
"TAG",       "Métadonnées balise",
"CONTENT",   "Métadonnées contenu",
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

#***************************************************
#
# Name: Set_Metadata_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Metadata_Debug {
    my ($this_debug) = @_;

    #
    # Set debug flag in supporting modules.
    #
    Metadata_Result_Object_Debug($this_debug);
    
    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: Set_Metadata_Thesaurus_File
#
# Parameters: profile - thesaurus profile
#             filename - name of thesaurus file
#             language - the language of the thesaurus terms
#
# Description:
#
#   This function sets the filename for the thesaurus filename for
# the specified scheme and language.
#
#***********************************************************************
sub Set_Metadata_Thesaurus_File {
    my ($profile, $filename, $language) = @_;

    #
    # Save filename for scheme and language.
    #
    print "Set_Compressed_Metadata_Thesaurus_File profile = $profile, filename = $filename, language = $language\n" if $debug;
    $thesaurus_profile_filename{"$language:$profile"} = $filename;
}

#***********************************************************************
#
# Name: Read_Compressed_Metadata_Thesaurus_File
#
# Parameters: profile - thesaurus profile
#             filename - name of thesaurus file
#             language - the language of the thesaurus terms
#
# Description:
#
#   This function reads the specified compressed thesaurus file into a
# hash table.  It stores the address of the hash table in the global
# thesaurus profile map table.
#
#***********************************************************************
sub Read_Compressed_Metadata_Thesaurus_File {
    my ($profile, $filename, $language) = @_;

    my (%terms, $term, $encoded_term, $i, @fields);
    
    if ( $have_threads ) {
        share(\%terms);
    }
    
    #
    # Have we seen this thesaurus file before.
    #
    print "Read_Compressed_Metadata_Thesaurus_File profile = $profile, filename = $filename, language = $language\n" if $debug;
    if ( ! defined($thesaurus_files{$filename}) ) {
        #
        # Open the compressed thesaurus file.
        #
        if ( ! -f "$filename" ) {
            print "Error: Thesaurus file $filename does not exist\n";
            return;
        }
        open(THESAURUS, $filename) || die "Error: Failed to open thesaurus file $filename\n";
        binmode THESAURUS, ":utf8";;

        #
        # Read the file, ignore blank lines and comment lines.
        #
        while ( $term = <THESAURUS> ) {
            #
            # Skip comment lines and blank lines
            #
            if ( ($term =~ /^#/) || ($term =~ /^$/) ) {
                next;
            }

            #
            # Strip off any Windows end-of-line markers
            #
            chomp($term);
            $term =~ s/\r//g;
            $encoded_term = encode_entities($term);

            #
            # Save the thersaurus term
            #
            if ( $term ne "" ) {
                $terms{lc($encoded_term)} = lc($encoded_term);
                $terms{lc($term)} = lc($term);
                #print "Save DC_Subject term \"$term\" as \"" . lc($term) . "\" and " . lc($encoded_term) . "\"\n" if $debug;
            }
        }
        close(THESAURUS);
        $i = keys(%terms);
        print "Read $i terms from thesaurus\n" if $debug;

        #
        # Save the terms list in case it is used in multiple profiles
        #
        $thesaurus_files{$filename} = \%terms;
    }
    else {
        print "Reuse terms list\n" if $debug;
    }

    #
    # Make a local of the hash table address in the global thesaurus
    # profile map.
    #
    if ( $language =~ /eng/i ) {
        $thesaurus_profile_map_en{$profile} = $thesaurus_files{$filename};
    }
    elsif ( $language =~ /fra/i ) {
        $thesaurus_profile_map_fr{$profile} = $thesaurus_files{$filename};
    }
}

#***********************************************************************
#
# Name: Set_Required_Metadata_Tags
#
# Parameters: profile - metadata tag profile
#             required_tags - hash table of tag name and required flag
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The required_tags hash table is indexed by metadata tag name with 
# the value being 0 = tag is optional, 1 = tag is required.
#
#***********************************************************************
sub Set_Required_Metadata_Tags {
    my ($profile, %required_tags) = @_;

    my (%local_required_tags);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    %local_required_tags = %required_tags;
    $tag_required_profile_map{$profile} = \%local_required_tags;
}

#***********************************************************************
#
# Name: Set_Required_Metadata_Content
#
# Parameters: profile - metadata tag profile
#             required_content - hash table of tag name and required flag
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The required_content hash table is indexed by metadata tag name with 
# the value being 0 = content is optional, 1 = content is required.
#
#***********************************************************************
sub Set_Required_Metadata_Content {
    my ($profile, %required_content) = @_;

    my (%local_required_content);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    %local_required_content = %required_content;
    $content_required_profile_map{$profile} = \%local_required_content;
}

#***********************************************************************
#
# Name: Set_Invalid_Metadata_Content
#
# Parameters: profile - metadata tag profile
#             invalid_content - hash table of tag name and invalid content
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The invalid_content hash table is indexed by metadata tag name with 
# the value being "" (empty string), no invalid content values, or
# a series of list of strings (terminated by \n) of invalid content.
#
#***********************************************************************
sub Set_Invalid_Metadata_Content {
    my ($profile, %invalid_content) = @_;

    my (%local_invalid_content);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    %local_invalid_content = %invalid_content;
    $invalid_content_profile_map{$profile} = \%local_invalid_content;
}

#***********************************************************************
#
# Name: Set_Metadata_Content_Type
#
# Parameters: profile - metadata tag profile
#             content_type - hash table of tag name and content type
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The content_type hash table is indexed by metadata tag name with 
# the value being a content type (e.g. "YYYY-MM-DD", EMAIL_ADDRESS).
# The first meaning any text is valid content, while the second 
# means the content must be a date.
#
#***********************************************************************
sub Set_Metadata_Content_Type {
    my ($profile, %content_type) = @_;

    my (%local_content_type);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    %local_content_type = %content_type;
    $content_type_map{$profile} = \%local_content_type;
}

#***********************************************************************
#
# Name: Set_Metadata_Scheme_Value
#
# Parameters: profile - metadata tag profile
#             scheme_values - values for scheme attribute
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The scheme_value hash table is indexed by metadata tag name with 
# the value being the possible values for the scheme attribute for
# the metadata tag.
#
#***********************************************************************
sub Set_Metadata_Scheme_Value {
    my ($profile, %scheme_values) = @_;

    my (%local_scheme_values);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    %local_scheme_values = %scheme_values;
    $scheme_values_map{$profile} = \%local_scheme_values;
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
# Parameters: tcid - testcase identifier
#             tag - tag name
#             status- status value
#             line - line number
#             column - column number
#             content - content from tag
#             attributes - metadata tag attributes
#             source_line - source code line
#             message - message string
#
# Description:
#
#   This function records the metadata result.
#
#***********************************************************************
sub Record_Result {
    my ($tcid, $tag, $status, $line, $column, $content, $attributes,
        $source_line, $message) = @_;

    my ($result_object, $metadata_object);

    #
    # Do we already have a result for this tag ?
    #
    if ( defined($$metadata_result_objects{$tag}) ) {
        $metadata_object = $$metadata_result_objects{$tag};
        
        #
        # Append the content and attribute values to the existing values
        #
        print "Append to existing metadata content for $tag\n" if $debug;
        $metadata_object->content($metadata_object->content . $content);
        $metadata_object->attributes($metadata_object->attributes . $attributes);
    }
    else {
        #
        # Create metadata object and save details
        #
        $metadata_object = metadata_result_object->new($tag, $status, $content,
                                                     $attributes, $message);
                                                     
        #
        # Save result object in case we get another instance of this tag
        #
        $$metadata_result_objects{$tag} = $metadata_object;
    }

    #
    # If the metadata status is not success, record an error
    #
    if ( $status != $metadata_success ) {
        #
        # Create result object and save details
        #
        $message = "$tag: " . $message;
        $result_object = tqa_result_object->new($tcid, $metadata_error,
                                              Testcase_Description($tcid),
                                              $line, $column, $source_line,
                                              $message, $current_url);
        push (@$results_list_addr, $result_object);

        #
        # Print error string to stdout
        #
        print "Metadata : $message\n" if $debug;
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
# Name: Clean_Text
#
# Parameters: text - text string
#
# Description:
#
#   This function eliminates leading and trailing white space from text.
# It also compresses multiple white space characters into a single space.
#
#***********************************************************************
sub Clean_Text {
    my ($text) = @_;

    #
    # Encode entities.
    #
    $text = encode_entities($text);

    #
    # Convert &nbsp; into a single space.
    # Convert newline into a space.
    # Convert return into a space.
    #
    $text =~ s/\&nbsp;/ /g;
    $text =~ s/\r\n|\r|\n/ /g;

    #
    # Convert multiple spaces into a single space
    #
    $text =~ s/\s\s+/ /g;

    #
    # Trim leading and trailing white space
    #
    $text =~ s/^\s*//g;
    $text =~ s/\s*$//g;

    #
    # Return cleaned text
    #
    return($text);
}

#**********************************************************************
#
# Name: Metadata_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Metadata_Check_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Metadata_Check_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
        $testcase_description_table = \%testcase_description_fr;
        $reverse_testcase_description_table = \%reverse_testcase_description_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Metadata_Check_Language, language = English\n" if $debug;
        $string_table = \%string_table_en;
        $testcase_description_table = \%testcase_description_en;
        $reverse_testcase_description_table = \%reverse_testcase_description_en;
    }
}

#***********************************************************************
#
# Name: Initialize_Parser_Variables
#
# Parameters: profile - metadata tag profile
#             results - address of results table
#
# Description:
#
#   This function initializes parser variables
#
#***********************************************************************
sub Initialize_Parser_Variables {
    my ($profile, $results) = @_;

    #
    # Initialize hash tables
    #
    $metadata_result_objects = $results;

    #
    # Set current hash tables
    #
    $current_tag_required = $tag_required_profile_map{$profile};
    $current_content_required = $content_required_profile_map{$profile};
    $current_invalid_content = $invalid_content_profile_map{$profile};
    $current_content_type = $content_type_map{$profile};
    $current_scheme_values = $scheme_values_map{$profile};

    #
    # Set unit globals
    #
    $have_text_handler = 0;
}

#***********************************************************************
#
# Name: Check_YYYY_MM_DD_Format
#
# Parameters: content - content to check
#
# Description:
#
#   This function checks the validity of a date value.  It checks specifically
# for a YYYY-MM-DD format.
#
# Returns:
#    status - status value
#    message - error message (if applicable)
#
#***********************************************************************
sub Check_YYYY_MM_DD_Format {
    my ($content) = @_;

    my ($status, @fields, $message);

    #
    # Check for valid date format, ie dddd-dd-dd
    #
    if ( $content =~ /^\d\d\d\d-\d\d-\d\d$/ ) {
        #
        # We have the right pattern of digits and dashes, now do a
        # check on the values.
        #
        @fields = split(/-/, $content);

        #
        # Check that the year portion is in a reasonable range.
        # 1900 to 2100.  I am making the assumption that this
        # code wont still be running in 95 years and that we
        # aren't still writing HTML documents.
        #
        if ( ( $fields[0] < 1900 ) || ( $fields[0] > 2100 ) ) {
            $status = $metadata_error;
            $message = String_Value("Invalid content") .
                       String_Value("Year") . $fields[0] .
                       String_Value("out of range 1900-2100");
            print "$message\n" if $debug;
        }

        #
        # Check that the month is in the 01 to 12 range
        #
        elsif ( ( $fields[1] < 1 ) || ( $fields[1] > 12 ) ) {
            $status = $metadata_error;
            $message = String_Value("Invalid content") .
                       String_Value("Month") . $fields[1] .
                       String_Value("out of range 1-12");
            print "$message\n" if $debug;

        }

        #
        # Check that the date is in the 01 to 31 range.  We won't
        # bother checking the month to further limit the date.
        #
        elsif ( ( $fields[2] < 1 ) || ( $fields[2] > 31 ) ) {
            $status = $metadata_error;
            $message = String_Value("Invalid content") .
                       String_Value("Date") . $fields[2] .
                       String_Value("out of range 1-31");
            print "$message\n" if $debug;
        }

        #
        # Must have a well formed date.
        #
        else {
            $status = $metadata_success;
            $message= "";
        }
    }
    else {
        #
        # Invalid format
        #
        $status = $metadata_error;
        $message = String_Value("Invalid content") .
                   String_Value("Date value") . "\"$content\"" .
                   String_Value("not in YYYY-MM-DD format");
        print "$message\n" if $debug;
    }

    #
    # Return status and message
    #
    return($status, $message);
}

#***********************************************************************
#
# Name: Check_Email_Address_Format
#
# Parameters: content - content to check
#
# Description:
#
#   This function checks that the supplied content is an email address.
# It checks for a <name>@<host> value.  It does not check to see if the
# address is valid, only that it is well formed.
#
# Returns:
#    status - status value
#    message - error message, if applicable
#
#***********************************************************************
sub Check_Email_Address_Format {
    my ($content) = @_;

    my ($status, $message);

    #
    # Check for valid format 
    #
    if ( $content =~ /^[A-Za-z0-9](([_\.\-]?[a-zA-Z0-9]+)*)@([A-Za-z0-9]+)(([\.\-]?[a-zA-Z0-9]+)*)\.([A-Za-z]{2,})$/ ) {

        #
        # Well formed email address
        #
        $status = $metadata_success;
        $message = "";
    }
    else {
        #
        # Invalid format
        #
        $status = $metadata_error;
        $message = String_Value("Invalid content") .
                   String_Value("Email address") . "\"$content\"" .
                   String_Value("is not valid");
        print "$message\n" if $debug;
    }

    #
    # Return status and message
    #
    return($status, $message);
}

#***********************************************************************
#
# Name: DC_Subject_Content_Check
#
# Parameters: language - language of page
#             scheme - metadata scheme attribute
#             content - content to check
#
# Description:
#
#   This function checks the value of the dc.subject metadata tag.
# It checks to see if there is a thesaurus for the scheme then
# checks to see that all content terms are in the thesaurus.
#
# Returns:
#    status - status value
#    message - error message, if applicable
#
#***********************************************************************
sub DC_Subject_Content_Check {
    my ($language, $scheme, $content) = @_;

    my ($term, $alt_term, $thesaurus, @terms, $orig_term, $invalid_term_list);
    my ($filename, $utf8_term);
    my ($status) = $metadata_success;
    my ($message) = "";

    #
    # Do we have a scheme attribute for the dc.subject metadata tag ?
    #
    print "DC_Subject_Content_Check language = $language, scheme = $scheme\n" if $debug;
    if ( ! defined($scheme) ) {
        print "No schema for $scheme\n" if $debug;
        return($status, $message);
    }

    #
    # Do we have to read the thesaurus file?
    #
    if ( defined($thesaurus_profile_filename{"$language:$scheme"}) ) {
        $filename = $thesaurus_profile_filename{"$language:$scheme"};
        print "Have file for thesaurus = $filename\n" if $debug;
        
        #
        # Do we have the English thesaurus?
        #
        if ( ($language eq "eng") &&
             (! defined($thesaurus_profile_map_en{$scheme})) ) {
                #
                # Have to read the thesaurus file.
                #
                Read_Compressed_Metadata_Thesaurus_File($scheme,
                     $thesaurus_profile_filename{"$language:$scheme"},
                     $language);
         }
         elsif ( ($language eq "fra") &&
                  (! defined($thesaurus_profile_map_fr{$scheme})) ) {
                #
                # Have to read the thesaurus file.
                #
                Read_Compressed_Metadata_Thesaurus_File($scheme,
                     $thesaurus_profile_filename{"$language:$scheme"},
                     $language);
        }
    }
    
    #
    # Do we have a thesaurus for this scheme ?
    #
    if ( ($language eq "eng") &&
         (defined($thesaurus_profile_map_en{$scheme})) ) {
        $thesaurus = $thesaurus_profile_map_en{$scheme};
        print "Have English thesaurus for dc.subject scheme $scheme\n" if $debug;
    }
    elsif ( ($language eq "fra") &&
         (defined($thesaurus_profile_map_fr{$scheme})) ) {
        $thesaurus = $thesaurus_profile_map_fr{$scheme};
        print "Have French thesaurus for dc.subject scheme $scheme\n" if $debug;
    }
    else {
        #
        # No thesaurus or not English or French
        #
        print "Not English or French language ($language) or no thesaurus for dc.subject scheme $scheme\n" if $debug;
        return($status, $message);
    }
    
    #
    # Check for a comma in the content.  The separator is supposed to
    # be a semicolon.
    #
    if ( index($content, ",") != -1 ) {
        $status = $metadata_error;
        $message = String_Value("Invalid separator for terms, found comma, expecting semicolon");
        print "$message\n" if $debug;

        #
        # Return status
        #
        return($status, $message);
    }

    #
    # Split content on ';'
    #
    @terms = split(/;/, $content);

    #
    # Check each term
    #
    foreach $term (@terms) {
        #
        # Ignore empty terms
        #
        if ( $term =~ /^\s*$/ ) {
            next;
        }
        
        #
        # Eliminate whitespace and convert to lowercase
        #
        $term =~ s/^\s+//g;
        $term =~ s/\s+$//g;
        $term =~ s/’/'/g;
        $term = lc($term);
        $orig_term = $term;
        $utf8_term = decode_entities($term);
        $term = encode_entities($term);
        
        #
        # Convert windows right single quote character (’) into a regular
        # single quote (').  The regular single quote appears in the
        # downloadable CSV file rather than the windows character.
        #
        $alt_term = $term;
        $alt_term =~ s/&rsquo;/&#39;/g;

        #
        # Is this term in the thesaurus ?
        #
        if ( (! defined($$thesaurus{$term})) &&
             (! defined($$thesaurus{$alt_term})) &&
             (! defined($$thesaurus{$utf8_term})) &&
             (! defined($$thesaurus{$orig_term})) ) {
            $status = $metadata_error;
            print "Invalid term, \"$orig_term\" looking for \"$term\" or \"$alt_term\" or \"$orig_term\" or \"$utf8_term\", in dc.subject\n" if $debug;

            #
            # Add invalid term to messages string
            #
            if ( ! defined($invalid_term_list) ) {
                $invalid_term_list = "$orig_term";
            }
            else {
                $invalid_term_list .= "; $orig_term";
            }
        }
    }
    
    #
    # Did we find an error ?
    #
    if ( $status != $metadata_success ) {
        $message = String_Value("Invalid content") .
                   String_Value("Invalid term") . "\"$invalid_term_list\"";
        print "$message\n" if $debug;
    }

    #
    # Return status
    #
    return($status, $message);
}

#***********************************************************************
#   
# Name: DC_Language_Content_Check
#
# Parameters: url_language - language of URL
#             lang - language of content
#             name - name of tag (dc.language or dcterms.language)
#             content - content to check
#
# Description:
#
#   This function checks the value of the dc.language metadata tag
# to ensure it matches the document (URL) language and the HTML
# tag language value.
#
# Returns:
#    status - status value
#    message - error message, if applicable
#
#***********************************************************************
sub DC_Language_Content_Check {
    my ($url_language, $lang, $name, $content) = @_;

    my ($html_lang, $result_object);
    my ($status) = $metadata_success;
    my ($message) = "";

    #
    # Have we seen a html tag ?
    #
    if ( defined($$metadata_result_objects{"html"}) &&
         $status == $metadata_success ) {
        $result_object = $$metadata_result_objects{"html"};
        $html_lang = $result_object->content;
    }

    #
    # Check URL and content language only of the language of the
    # tag matches the overall document language (from <html> tag). We
    # don't check for a match if there is a lang attribute on the <meta> tag.
    #
    if ( defined($html_lang) && ($lang eq $html_lang) && 
         ($url_language ne "") ) {
        #
        # Does the content match the URL language ?
        #
        if ( ($url_language eq "fra") &&
                ( !(($content =~ /fra/i) || ($content =~ /fre/i)) ) ) {
            #
            # Allow content to be fra or fre, "fre" is not strictly speaking
            # correct, however a template was published with this value
            # and widely used.
            #
            $status = $metadata_error;
            $message = String_Value("Invalid content") . "URL ($url_language) "  .
                       String_Value("and") . " $name ($content) " .
                       String_Value("do not match");
            print "$message\n" if $debug;
        }
        elsif ( $url_language ne $content ) {
            $status = $metadata_error;
            $message = String_Value("Invalid content") . "URL ($url_language) "  .
                       String_Value("and") . " $name ($content) " .
                       String_Value("do not match");
            print "$message\n" if $debug;
        }
    }

    #
    # Do we have a content language (either on <html> tag or a lang attribute) ?
    #
    if ( defined($lang) && ($lang ne "") ) {
        #
        # Does the content match the language content value ?
        #
        if ( $lang ne $content ) {
            $status = $metadata_error;
            $message = String_Value("Invalid content") . "HTML ($lang) " .
                       String_Value("and") . " $name ($content) " .
                       String_Value("do not match");
            print "$message\n" if $debug;
        }
    }

    #
    # Return status and message
    #
    return($status, $message);
}

#***********************************************************************
#
# Name: Get_Metadata_Date_Content
#
# Parameters: tag - metadata tag name
#
# Description:
#
#   This function returns the date value of a metadata item as an integer.
# The value is converted to an integer by removing the - characters from
# the value (YYYY-MM-DD). If the metadata tag has an error, or not 
# content is available, a 0 is returned.
#
# Returns:
#    interger date
#
#***********************************************************************
sub Get_Metadata_Date_Content {
    my ($tag) = @_;

    my ($result_object);
    my ($date_value) = "";
    my ($date_value_int) = 0;

    #
    # Check to see if we have a metadata item
    #
    if ( defined($$metadata_result_objects{$tag}) ) {
        $result_object = $$metadata_result_objects{$tag};

        #
        # Did the tag have a valid value ?
        #
        if ( ($result_object->status == $metadata_success) &&
             ($result_object->content ne "") ) {
            $date_value = $result_object->content;

            #
            # Convert date (YYYY-MM-DD) into a number
            #
            $date_value_int = $date_value;
            $date_value_int =~ s/-//g;
        }
    }

    #
    # Return date value
    #
    return($date_value_int, $date_value);
}

#***********************************************************************
#
# Name: Check_DCTerms_Issued
#
# Parameters: this_date - content to check
#
# Description:
#
#   This function checks the value of the dcterms.issued item, it
# checks to see that the value is in agreement with other date metadata.
#
# Returns:
#    status - status value
#    message - error message, if applicable
#
#***********************************************************************
sub Check_DCTerms_Issued {
    my ($this_date) = @_;

    my ($result_object, $other_date, $other_date_int);
    my ($status) = $metadata_success;
    my ($message) = "";

    #
    # Convert this metadata items date into an integer.
    #
    $this_date =~ s/-//g;

    #
    # Check to see if we have a dcterms.modified metadata item
    #
    ($other_date_int, $other_date) = Get_Metadata_Date_Content("dcterms.modified");
            
    #
    # The dcterms.issued must not be greater than the
    # dcterms.modified value.
    #
    print "Check_DCTerms_Issued, content = $this_date, dcterms.modified = $other_date_int\n" if $debug;
    if ( ($other_date_int > 0 ) && ($this_date > $other_date_int) ) {
        $status = $metadata_error;
        $message = String_Value("Invalid content") .
                   String_Value("Date after") . " dcterms.modified " .
                   String_Value("date") . $other_date;
        print "$message\n" if $debug;
    }

    #
    # Check to see if we have a pwgsc.date.archived metadata item
    #
    if ( $status == $metadata_success ) {
        ($other_date_int, $other_date) = 
                 Get_Metadata_Date_Content("pwgsc.date.archived");

        #
        # The dcterms.issued must not be greater than the
        # pwgsc.date.archived value.
        #
        print "Check_DCTerms_Issued, content = $this_date, pwgsc.date.archived = $other_date_int\n" if $debug;
        if ( ($other_date_int > 0 ) && ($this_date > $other_date_int) ) {
            $status = $metadata_error;
            $message = String_Value("Invalid content") .
                       String_Value("Date after") . " pwgsc.date.archived " .
                       String_Value("date") . $other_date;
            print "$message\n" if $debug;
        }
    }

    #
    # Return status and message
    #
    return($status, $message);
}

#***********************************************************************
#
# Name: Check_DCTerms_Modified
#
# Parameters: this_date - content to check
#
# Description:
#
#   This function checks the value of the dcterms.modified item, it
# checks to see that the value is in agreement with other date metadata.
#
# Returns:
#    status - status value
#    message - error message, if applicable
#
#***********************************************************************
sub Check_DCTerms_Modified {
    my ($this_date) = @_;

    my ($result_object, $other_date, $other_date_int);
    my ($status) = $metadata_success;
    my ($message) = "";

    #
    # Convert this metadata items date into an integer.
    #
    $this_date =~ s/-//g;

    #
    # Check to see if we have a dcterms.issued metadata item
    #
    ($other_date_int, $other_date) = Get_Metadata_Date_Content("dcterms.issued");
           
    #
    # The dcterms.modified must not be less than the
    # dcterms.issued value.
    #
    print "Check_DCTerms_Modified, content = $this_date, dcterms.issued = $other_date_int\n" if $debug;
    if ( ($other_date_int > 0 ) && ($this_date < $other_date_int) ) {
        $status = $metadata_error;
        $message = String_Value("Invalid content") .
                   String_Value("Date prior to") . " dcterms.issued " .
                   String_Value("date") . $other_date;
        print "$message\n" if $debug;
    }

    #
    # Check to see if we have a pwgsc.date.archived metadata item
    #
    if ( $status == $metadata_success ) {
        ($other_date_int, $other_date) =
                 Get_Metadata_Date_Content("pwgsc.date.archived");

        #
        # The dcterms.modified must not be greater than the
        # pwgsc.date.archived value.
        #
        print "Check_DCTerms_Modified, content = $this_date, pwgsc.date.archived = $other_date_int\n" if $debug;
        if ( ($other_date_int > 0 ) && ($this_date > $other_date_int) ) {
            $status = $metadata_error;
            $message = String_Value("Invalid content") .
                       String_Value("Date after") . " pwgsc.date.archived " .
                       String_Value("date") . $other_date;
            print "$message\n" if $debug;
        }
    }

    #
    # Return status and message
    #
    return($status, $message);
}

#***********************************************************************
#
# Name: Check_PWGSC_Date_Archived
#
# Parameters: this_date - content to check
#
# Description:
#
#   This function checks the value of the pwgsc.date.archived item, it
# checks to see that the value is in agreement with other date metadata.
#
# Returns:
#    status - status value
#    message - error message, if applicable
#
#***********************************************************************
sub Check_PWGSC_Date_Archived {
    my ($this_date) = @_;

    my ($result_object, $other_date, $other_date_int);
    my ($status) = $metadata_success;
    my ($message) = "";

    #
    # Convert this metadata items date into an integer.
    #
    $this_date =~ s/-//g;

    #
    # Check to see if we have a dcterms.modified metadata item
    #
    ($other_date_int, $other_date) = Get_Metadata_Date_Content("dcterms.modified");
            
    #
    # The pwgsc.date.archived must not be less than the
    # dcterms.modified value.
    #
    print "Check_PWGSC_Date_Archived, content = $this_date, dcterms.modified = $other_date_int\n" if $debug;
    if ( ($other_date_int > 0 ) && ($this_date < $other_date_int) ) {
        $status = $metadata_error;
        $message = String_Value("Invalid content") .
                   String_Value("Date prior to") . " dcterms.modified " .
                   String_Value("date") . $other_date;
        print "$message\n" if $debug;
    }

    #
    # Check to see if we have a dcterms.issued metadata item
    #
    if ( $status == $metadata_success ) {
        ($other_date_int, $other_date) = 
                 Get_Metadata_Date_Content("dcterms.issued");

        #
        # The pwgsc.date.archived must not be less than the
        # dcterms.issued value.
        #
        print "Check_PWGSC_Date_Archived, content = $this_date, dcterms.issued = $other_date_int\n" if $debug;
        if ( ($other_date_int > 0 ) && ($this_date < $other_date_int) ) {
            $status = $metadata_error;
            $message = String_Value("Invalid content") .
                       String_Value("Date prior to") . " dcterms.issued " .
                       String_Value("date") . $other_date;
            print "$message\n" if $debug;
        }
    }

    #
    # Return status and message
    #
    return($status, $message);
}

#***********************************************************************
#
# Name: Check_Content_Type
#
# Parameters: content_type - content type
#             content - content to check
#
# Description:
#
#   This function checks to see that the supplied content is valid
# for the content type.
#
#  Returns:
#    status - status value
#    message - error message, if applicable
#
#***********************************************************************
sub Check_Content_Type {
    my ($content_type, $content) = @_;

    my ($status, $message);

    #
    # Remove any leading or trailing white space
    #
    $content =~ s/^\s+//g;
    $content =~ s/s+$//g;

    #
    # Is this a date content type ?
    #
    if ( $content_type eq "YYYY-MM-DD" ) {
        #
        # Check for digits & dashes and valid year, month & date.
        #
        ($status, $message) = Check_YYYY_MM_DD_Format($content);
    }

    elsif ( $content_type eq "EMAIL_ADDRESS" ) {
        #
        # Check that content is an email address i.e. name@host.domain
        #
        ($status, $message) = Check_Email_Address_Format($content);
    }

    #
    # Unknown content type, no check required
    #
    else {
        $status = $metadata_success;
        $message = "";
    }

    #
    # Return content check status and message
    #
    return($status, $message);
}

#***********************************************************************
#
# Name: Check_Invalid_Content
#
# Parameters: name - name of metadata tag
#             content - content to check
#
# Description:
#
#   This function checks to see if the supplied content is invalid
# (e.g. a template value).
#
#  Returns:
#    status - status value
#    message - error message, if applicable
#
#***********************************************************************
sub Check_Invalid_Content {
    my ($name, $content) = @_;

    my ($status) = $metadata_success;
    my ($message) = "";
    my ($invalid_content, $invalid_content_list);

    #
    # Do we have any invalid content for this metadata tag ?
    #
    if ( defined($$current_invalid_content{$name}) ) {
        #
        # Does the content match any of the invalid content values ?
        #
        $invalid_content_list = $$current_invalid_content{$name};
        foreach $invalid_content (split(/\n/, $invalid_content_list)) {
            if ( $content eq $invalid_content ) {
                $status = $metadata_error;
                $message = String_Value("Invalid content") .
                           " \"$content\"";
                print "$message\n" if $debug;
                last;
            }
        }
    }

    #
    # Return content check status
    #
    return($status, $message);
}

#***********************************************************************
#
# Name: Robots_Content_Check
#
# Parameters: content - metadata content
#
# Description:
#
#   This function checks the value of a Robots metadata tag.
#
#  Returns:
#    status - status value
#    message - error message, if applicable
#
#***********************************************************************
sub Robots_Content_Check {
    my ($content) = @_;

    my ($status) = $metadata_success;
    my ($message) = "";
    my ($term);

    #
    # Do we have content ?
    #
    if ( $content ne "" ) {
        #
        # Content is a comma seperated list of values.
        #
        foreach $term ( split(/,/, $content) ) {
            #
            # Convert term to lowercase before check. Strip off
            # leading or trailing whitespace.
            #
            $term = lc($term);
            $term =~ s/^\s+//g;
            $term =~ s/\s+$//g;
            print "Robots_Content_Check check term \"$term\"\n" if $debug;

            #
            # Look for value in valid values.
            #
            if ( index($VALID_ROBOTS_CONTENT, " $term ") == -1 ) {
                #
                # Invalid metadata content value
                #
                $status = $metadata_error;
                $message = String_Value("Invalid content") . " \"$term\"";
                print "$message\n" if $debug;
            }
        }
    }
    else {
        #
        # Missing content
        #
        $status = $metadata_error;
        $message = String_Value("Missing content");
        print "$message\n" if $debug;
    }

    #
    # Return status
    #
    return($status, $message);
}

#***********************************************************************
#
# Name: Check_Scheme_Value
#
# Parameters: name - metadata tag name
#             scheme - scheme to check
#             attr - attribute name
#
# Description:
#
#   This function checks to see that the supplied scheme is within
# the set of scheme values for this metadata tag.
#
#  Returns:
#    status - status value
#    message - error message, if applicable
#
#***********************************************************************
sub Check_Scheme_Value {
    my ($name, $scheme, $attr) = @_;

    my ($scheme_values);
    my ($status) = $metadata_success;
    my ($message) = "";

    #
    # Does this metadata tag have any scheme values ?
    #
    if ( defined($$current_scheme_values{$name}) ) {
        $scheme_values = $$current_scheme_values{$name};

        #
        # Remove any leading or trailing white space
        #
        $scheme =~ s/^\s+//g;
        $scheme =~ s/s+$//g;
        print "Check_Scheme_Value: Check $attr value \"$scheme\" for tag $name, valid values = \"$scheme_values\"\n" if $debug;

        #
        # Look for value in valid values.
        #
        if ( index($scheme_values, " $scheme ") == -1 ) {
            #
            # Invalid metadata scheme value
            #
            $status = $metadata_error;
            $message = String_Value("Invalid content") .
                       " $scheme " . String_Value("for attribute") .
                       " \"$attr\"";
            print "$message\n" if $debug;
        }
    }

    #
    # Return scheme value check status
    #
    return($status, $message);
}

#***********************************************************************
#
# Name: Start_Title_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             level - heading level
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the title tag.
#
#***********************************************************************
sub Start_Title_Tag_Handler {
    my ($self, $line, $column, $text, %attr ) = @_;

    #
    # Add a text handler to save the text of the title.
    #
    $self->handler( text => [], '@{dtext}' );
    $have_text_handler = 1;
}

#***********************************************************************
#
# Name: End_Title_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end title </title> tag.
#
#***********************************************************************
sub End_Title_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my (@anchor_text_list, $title);
    my ($status) = $metadata_success;
    my ($message) = "";

    #
    # Get all the text found within the title tag
    #
    print "End_Title_Tag_Handler: Check title tag\n" if $debug;
    if ( ! $have_text_handler ) {
        print "End title tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return($status, $message);
    }
    @anchor_text_list = @{ $self->handler("text") };
    $title = join("", @anchor_text_list);

    #
    # Clean up the title to convert any entities and trim whitespace
    #
    $title = Clean_Text($title);

    #
    # Check to see if this metadata tag requires content.
    #
    if ( defined($$current_content_required{"title"}) &&
         $$current_content_required{"title"} ) {
        print "End_Title_Tag_Handler: Check required content\n" if $debug;
        if ( $title eq "" ) {
            $status = $metadata_error;
            $message = String_Value("Missing content");
            print "$message\n" if $debug;
        }
        else {
            #
            # Does the content have any particular type ?
            #
            if ( defined($$current_content_type{"title"}) ) {
                ($status, $message) = Check_Content_Type($$current_content_type{"title"} , $title);
            }
        }
    }

    #
    # Record title check result
    #
    Record_Result("CONTENT", "title", $status, $line, $column, $title, "",
                  $content_lines[$line - 1], $message);
}

#***********************************************************************
#
# Name: Meta_Tag_Handler
#
# Parameters: language - url language
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the meta tag, it looks to see if it is used
# for page refreshing
#
#***********************************************************************
sub Meta_Tag_Handler {
    my ( $language, $line, $column, $text, %attr ) = @_;

    my ($key, $value, $name, $content, $scheme, $lang);
    my ($result_object);
    my ($attributes) = "";
    my ($status) = $metadata_success;
    my ($message) = "";

    #
    # Look for name attribute
    #
    if ( defined($attr{"name"}) ) {
        $name = $attr{"name"};
        print "Meta_Tag_Handler: Check metadata tag $name\n" if $debug;

        #
        # Look for a lang attribute
        #
        if ( defined($attr{"lang"}) ) {
            #
            # Override HTML language (if there is one) with this language
            #
            $lang = $attr{"lang"};
            print "Lang = $lang attribute found\n" if $debug;

            #
            # Strip off any possible dialect from the language code
            # e.g. en-US becomes en.
            #
            $lang =~ s/-.*//g;

            #
            # Convert from a 2 letter code to a 3 letter code.
            #
            if ( defined($language_map::iso_639_1_iso_639_2T_map{$lang}) ) {
                $lang = $language_map::iso_639_1_iso_639_2T_map{$lang};
            }
        }
        else {
            #
            # Use language from <html> tag (if there is one)
            #
            if ( defined($$metadata_result_objects{"html"}) &&
                 $status == $metadata_success ) {
                $result_object = $$metadata_result_objects{"html"};
                $lang = $result_object->content;
            }
        }

        #
        # Do we have a scheme attribute ?
        #
        if ( defined($attr{"scheme"}) ) {
            #
            # Have we a scheme value, is it valid ?
            #
            $scheme = $attr{"scheme"};
            print "Meta_Tag_Handler: Check scheme content $scheme\n" if $debug;

            #
            # Check scheme value for this metadata tag.
            #
            ($status, $message) = Check_Scheme_Value($name, $scheme, "scheme");
        }
        #
        # Do we have a title attribute ? In HTML 5 scheme is deprecated
        # and title is used instead.
        #
        elsif ( defined($attr{"title"}) ) {
            #
            # Have we a title value, is it valid ?
            #
            $scheme = $attr{"title"};
            print "Meta_Tag_Handler: Check title content $scheme\n" if $debug;

            #
            # Check title value for this metadata tag.
            #
            ($status, $message) = Check_Scheme_Value($name, $scheme, "title");
        }

        #
        # Do we have a content attribute ? if so remove any leading whitespace
        #
        if ( defined($attr{"content"}) ) {
            $content = $attr{"content"};
            $content =~ s/^\s+//g;
        }
        else {
            $content = "";
        }

        #
        # Check to see if this metadata tag requires content.
        #
        if ( ($status == $metadata_success) &&
             defined($$current_content_required{$name}) &&
             $$current_content_required{$name} ) {
            print "Meta_Tag_Handler: Check required content\n" if $debug;
            if ( $content eq "" ) {
                $status = $metadata_error;
                $message = String_Value("Missing content");
                print "$message\n" if $debug;
            }
            else {
                #
                # Does the content have any particular type ? If
                # so check that the value is appropriate.
                #
                if ( ($status == $metadata_success) && 
                     (defined($$current_content_type{$name})) ) {
                    ($status, $message) = Check_Content_Type($$current_content_type{$name},
                                                             $content);
                }

                #
                # Additional content checks for specific metadata tags
                #
                if ( ($status == $metadata_success) && 
                     (($name eq "dc.language") || ($name eq "dcterms.language")) ) {
                    #
                    # dc.language metadata tag.
                    #
                    ($status, $message) = DC_Language_Content_Check($language, $lang, $name, $content);
                }
                elsif ( ($status == $metadata_success) && ($name eq "dc.subject") ) {
                    #
                    # dc.subject metadata tag.
                    #
                    ($status, $message) = DC_Subject_Content_Check($lang, $attr{"scheme"}, $content);
                }
                elsif ( ($status == $metadata_success) && ($name eq "dcterms.subject") ) {
                    #
                    # dcterms.subject metadata tag.
                    #
                    ($status, $message) = DC_Subject_Content_Check($lang, $attr{"title"}, $content);
                }
                elsif ( ($status == $metadata_success) &&
                        ($name eq "dcterms.issued") ) {
                    #
                    # dcterms.issued metadata tag.
                    #
                    ($status, $message) = Check_DCTerms_Issued($content);
                }
                elsif ( ($status == $metadata_success) &&
                        ($name eq "dcterms.modified") ) {
                    #
                    # dcterms.modified metadata tag.
                    #
                    ($status, $message) = Check_DCTerms_Modified($content);
                }
                elsif ( ($status == $metadata_success) &&
                        ($name eq "pwgsc.date.archived") ) {
                    #
                    # pwgsc.date.archived metadata tag.
                    #
                    ($status, $message) = Check_PWGSC_Date_Archived($content);
                }
            }
        }
        else {
            #
            # Tag does not require content.
            #
            print "Meta_Tag_Handler: Content not required\n" if $debug;
        }

        #
        # Check for invalid content values (e.g. template values)
        #
        if ( $status == $metadata_success ) {
            ($status, $message) = Check_Invalid_Content($name, $content);
        }

        #
        # Check content of Robots metadata item
        #
        if ( ($status == $metadata_success) && ($name =~ /^robots$/i) ) {
            ($status, $message) = Robots_Content_Check($content);
        }

        #
        # Concatenate all other attributes into a single string.
        #
        while ( ($key, $value) = each %attr ) {
            if ( ($key ne "/") &&
                 ($key ne "name") &&
                 ($key ne "content") ) {
                $attributes .= "$key=\"$value\" ";
            }
        }

        #
        # Record tag result
        #
        Record_Result("CONTENT", $name, $status, $line, $column, $content,
                      $attributes, $content_lines[$line - 1], $message);
    }
}

#***********************************************************************
#
# Name: HTML_Tag_Handler
#
# Parameters: language - url language
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the html tag, it checks to see that the
# language specified matches the document language.
#
#***********************************************************************
sub HTML_Tag_Handler {
    my ( $language, $line, $column, $text, %attr ) = @_;

    my ($lang, $key, $value, $lang1, $lang2);
    my ($attributes) = "";
    my ($status) = $metadata_success;
    my ($message) = "";

    #
    # Do we have a lang or xml:lang attribute ?
    #
    print "HTML_Tag_Handler: Checking HTML tag\n" if $debug;
    if ( defined($attr{"lang"}) ) {
        $lang = lc($attr{"lang"});
        $lang1 = lc($attr{"lang"});
    }
    elsif ( defined($attr{"xml:lang"}) ) {
        $lang = lc($attr{"xml:lang"});
        $lang1 = lc($attr{"xml:lang"});
    }
    else {
        $lang ="";
        $lang1 ="";
    }

    #
    # Strip off any possible dialect from the language code
    # e.g. en-US becomes en.
    #
    $lang =~ s/-.*//g;

    #
    # Check to see if this metadata tag requires content.
    #
    if ( defined($$current_content_required{"html"}) &&
         $$current_content_required{"html"} ) {
        print "HTML_Tag_Handler: Check required lang attribute\n" if $debug;
        if ( $lang eq "" ) {
            #
            # Missing lang content
            #
            $status = $metadata_error;
            $message = String_Value("Missing content") .
                       String_Value("for attribute") . " lang/xml:lang";
            print "$message\n" if $debug;
        }
    }

    #
    # Do we have an xml:lang attribute ?
    #
    if ( ($status == $metadata_success) &&
         (defined($attr{"xml:lang"})) ) {
        #
        # Do the lang and xml:lang values match ? (note: we might
        # actually be checking the xml:lang to the xml:lang if there was
        # no lang attribute, but since we want to catch a mismatch the test
        # would succeed so we don't check where the $lang value came from).
        #
        $lang2 = lc($attr{"xml:lang"});
        if ( $lang1 ne $lang2 ) {
            print "Mismatch in lang($lang1) and xml:lang($lang2) values\n" if $debug;
            $status = $metadata_error;
            $message = String_Value("Invalid content") .
                       " lang ($lang1) " . String_Value("and") .
                       " xml:lang ($lang2) " .
                       String_Value("do not match");
            print "$message\n" if $debug;
        }
    }

    #
    # Does the lang value match the URL language ?
    #
    if ( $status == $metadata_success ) {
        #
        # Convert possible 2 character language code into
        # a 3 character code.
        #
        if ( defined($language_map::iso_639_1_iso_639_2T_map{$lang}) ) {
            $lang = $language_map::iso_639_1_iso_639_2T_map{$lang};
        }

        #
        # If the URL language is known, does the HTML language
        # match the URL language ?
        #
        if ( ($language ne "") && ($lang ne $language) ) {
            print "Mismatch in lang($lang) and URL language($language) values\n" if $debug;
            $status = $metadata_error;
            $message = String_Value("Invalid content") .
                       " lang/xml:lang ($lang) " . String_Value("and") .
                       " URL ($language) " .
                       String_Value("do not match");
            print "$message\n" if $debug;
        }
    }

    #
    # Concatenate all other attributes into a single string.
    #
    while ( ($key, $value) = each %attr ) {
        if ( ($key ne "/") &&
             ($key ne "lang") ) {
            $attributes .= "$key=\"$value\" ";
        }
    }

    #
    # Record tag result
    #
    Record_Result("CONTENT", "html", $status, $line, $column, $lang,
                  $attributes, $content_lines[$line - 1], $message);

}

#***********************************************************************
#
# Name: Start_Handler
#
# Parameters: self - reference to this parser
#             language - url language
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the start of HTML tags.
#
#***********************************************************************
sub Start_Handler {
    my ( $self, $language, $tagname, $line, $column, $text, @attr ) =
      @_;

    my (%attr_hash) = @attr;

    #
    # Check html tag
    #
    if ( $tagname eq "html" ) {
        HTML_Tag_Handler( $language, $line, $column, $text, %attr_hash );
    }

    #
    # Check for meta tag
    #
    elsif ( $tagname eq "meta" ) {
        Meta_Tag_Handler( $language, $line, $column, $text, %attr_hash );
    }

    #
    # Check for title
    #
    elsif ( $tagname eq "title" ) {
        Start_Title_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

}

#***********************************************************************
#
# Name: End_Handler
#
# Parameters: self - reference to this parser
#             language - url language
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end of HTML tags.
#
#***********************************************************************
sub End_Handler {
    my ( $self, $language, $tagname, $line, $column, $text, 
         @attr ) = @_;

    my (%attr_hash) = @attr;

    #
    # Check for title tag
    #
    if ( $tagname eq "title" ) {
        End_Title_Tag_Handler($self, $line, $column, $text);
    }
}

#***********************************************************************
#
# Name: Check_Required_Metadata_Tags
#
# Parameters: none
#
# Description:
#
#   This function checks to see that all required metadata tags were
# found.
#
#***********************************************************************
sub Check_Required_Metadata_Tags {

    my ($tag);

    #
    # Check all required tags
    #
    foreach $tag (keys %$current_tag_required) {
        print "Check_Required_Metadata_Tags: Checking metadata tag $tag\n" if $debug;
        if ( ! defined($$metadata_result_objects{"$tag"}) ) {
            Record_Result("TAG", $tag, $metadata_error, -1, -1, "", "",
                          "", String_Value("Missing tag"));
        }
    }
}

#***********************************************************************
#
# Name: Extract_Metadata
#
# Parameters: url - a URL
#             content - content pointer
#
# Description:
#
#   This function parses the supplied HTML content for metadata
# tags.  It returns a hash table of tags and content.
#
#***********************************************************************
sub Extract_Metadata {
    my ($url, $content) = @_;
    
    my (%metadata, @metadata_results_list);

    #
    # Did we already extract metadata information for this URL ?
    #
    if ( $url eq $last_url ) {
        %metadata = %last_metadata_table;
    }
    else {
        #
        # Run the metadata check and discard the testcase results
        #
        print "Extract_Metadata from $url\n" if $debug;
        @metadata_results_list = Validate_Metadata($url, "","", $content,
                                                   \%metadata);
    }

    #
    # Return metadata content
    #
    return(%metadata);
}

#***********************************************************************
#
# Name: Validate_Metadata
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - metadata tag profile
#             content - content pointer
#             metadata_table - address of hash table to contain
#                metadata content
#
# Description:
#
#   This function parses the supplied HTML content for metadata
# tags.  It checks for required tags, required content and content
# values.  It returns the metadata details, location, content and status.
#
#***********************************************************************
sub Validate_Metadata {
    my ( $this_url, $language, $profile, $content, $metadata_table ) = @_;

    my ( $parser, $key, $result_object, $status, @results_list );

    #
    # Do we have a valid profile ?
    #
    print "Validate_Metadata: Checking URL $this_url, lanugage = $language, profile = $profile\n" if $debug;
    if ( ! defined($tag_required_profile_map{$profile}) ) {
        print "Validate_Metadata: Unknown metadata profile passed $profile\n";
        return(@results_list);
    }

    #
    # Initialize parser variables.
    #
    Initialize_Parser_Variables($profile, $metadata_table);
    $results_list_addr = \@results_list;

    #
    # Save URL in global variable
    #
    if ( ($this_url =~ /^http/i) || ($this_url =~ /^file/i) ) {
        $current_url = $this_url;
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of HTML
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Do we get any content ?
    #
    if ( length($$content) > 0 ) {

        #
        # Split the content into lines
        #
        @content_lines = split( /\n/, $$content );

        #
        # Create a document parser
        #
        $parser = HTML::Parser->new;

        #
        # Add handlers for some of the HTML tags
        #
        $parser->handler(
            start => \&Start_Handler,
            "self,\"$language\",tagname,line,column,text,\@attr"
        );
        $parser->handler(
            end => \&End_Handler,
            "self,\"$language\",tagname,line,column,text,\@attr"
        );

        #
        # Parse the content.
        #
        $parser->parse($$content);
    }
    else {
        print "No content passed to Validate_Metadata\n" if $debug;
    }

    #
    # Check for missing metadata items (required tags that we did not find).
    #
    Check_Required_Metadata_Tags;

    #
    # Dump out metadata tag values
    #
    if ( $debug ) {
        print "Metadata dump\n";
        foreach $key (keys %$metadata_table) {
            $result_object = $$metadata_table{$key};
            printf("%20s status %d message %s content %s\n",
                   $result_object->tag, $result_object->status,
                   $result_object->message,
                   $result_object->content);
        }
    }

    #
    # Remember this metadata in case we want it again.
    #
    $last_url = $this_url;
    %last_metadata_table = %$metadata_table;

    #
    # Return results list
    #
    return(@results_list);
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

