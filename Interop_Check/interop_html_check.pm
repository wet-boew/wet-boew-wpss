#***********************************************************************
#
# Name:   interop_html_check.pm
#
# $Revision: 6710 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Interop_Check/Tools/interop_html_check.pm $
# $Date: 2014-07-22 12:19:13 -0400 (Tue, 22 Jul 2014) $
#
# Description:
#
#   This file contains routines that parse HTML files and check for
# a number of Standard on Web Usability check points.
#
# Public functions:
#     Set_Interop_HTML_Check_Language
#     Set_Interop_HTML_Check_Debug
#     Set_Interop_HTML_Check_Testcase_Data
#     Set_Interop_HTML_Check_Test_Profile
#     Interop_HTML_Check_Read_URL_Help_File
#     Interop_HTML_Check_Testcase_URL
#     Interop_HTML_Check
#     Interop_HTML_Check_Links
#     Interop_HTML_Check_Has_HTML_Data
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

package interop_html_check;

use strict;
use HTML::Entities;
use URI::URL;
use File::Basename;
use JSON;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Set_Interop_HTML_Check_Language
                  Set_Interop_HTML_Check_Debug
                  Set_Interop_HTML_Check_Testcase_Data
                  Set_Interop_HTML_Check_Test_Profile
                  Interop_HTML_Check_Read_URL_Help_File
                  Interop_HTML_Check_Testcase_URL
                  Interop_HTML_Check
                  Interop_HTML_Check_Links
                  Interop_HTML_Check_Has_HTML_Data
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (%testcase_data, %interop_check_profile_map);
my (@paths, $this_path, $program_dir, $program_name, $paths);

my ($current_interop_check_profile, $current_url);
my ($results_list_addr, @content_lines, $charset);
my ($doctype_label, $doctype_version, $doctype_class);
my ($doctype_line, $doctype_column, $doctype_text);
my ($charset, $charset_line, $charset_column, $charset_text);
my (%ignore_rel_domains, %html_data_vocab);
my ($microdata_found, $microdata_line, $microdata_column, $microdata_text);
my ($microdata_attr, $microdata_attr_count, $rdfa_found, $rdfa_attr_count);
my ($missing_rdfa_vocab_reported, $missing_rdfa_typeof_reported);
my (@other_rdfa_lite_attributes) = ("prefix", "resource");
my (@vocab_tag_stack, @typeof_tag_stack, $inside_vocab, $inside_typeof);
my (%schema_details, $current_schema_types, $current_schema_properties);
my ($current_schema_details, $current_schema_vocab, @typeof_stack);
my ($current_typeof_value);

my ($max_error_message_string) = 2048;

#
# Valid values for the rel attribute of tags
#  Source: http://www.w3.org/TR/2011/WD-html5-20110525/links.html#linkTypes
#  Value "shortcut" is not listed in the above page but is a valid value
#  for <link> tags.
#  Date: 2012-11-09
#
my %valid_rel_values = (
   "a",    " alternate author bookmark external help license next nofollow noreferrer prefetch prev search sidebar tag ",
   "area", " alternate author bookmark external help license next nofollow noreferrer prefetch prev search sidebar tag ",
   "link", " alternate author help icon license next pingback prefetch prev search shortcut sidebar stylesheet tag ",
);

#
# Values for the rel attribute of tags
#  Source: http://microformats.org/wiki/existing-rel-values#HTML5_link_type_extensions
#  Date: 2012-11-09
#
$valid_rel_values{"a"} .= "attachment category disclosure entry-content external home index profile publisher rendition sidebar widget http://docs.oasis-open.org/ns/cmis/link/200908/acl ";
$valid_rel_values{"area"} .= "attachment category disclosure entry-content external home index profile publisher rendition sidebar widget http://docs.oasis-open.org/ns/cmis/link/200908/acl ";
$valid_rel_values{"link"} .= "apple-touch-icon apple-touch-icon-precomposed apple-touch-startup-image attachment canonical category dns-prefetch EditURI home index meta openid.delegate openid.server openid2.local_id openid2.provider p3pv1 pgpkey pingback prerender profile publisher rendition servive shortlink sidebar sitemap timesheet widget wlwmanifest image_src  http://docs.oasis-open.org/ns/cmis/link/200908/acl stylesheet/less schema.dc schema.dcterms ";

#
# List of HTML tags that do not have an explicit end tag.
#
my (%html_tags_with_no_end_tag) = (
        "area", "area",
        "base", "base",
        "br", "br",
        "col", "col",
        "command", "command",
        "embed", "embed",
        "frame", "frame",
        "hr", "hr",
        "img", "img",
        "input", "input",
        "keygen", "keygen",
        "link", "link",
        "meta", "meta",
        "param", "param",
        "source", "source",
        "track", "track",
        "wbr", "wbr",
);

#
# Status values
#
my ($check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "DOCTYPE missing",                "DOCTYPE missing",
    "DOCTYPE is not HTML 5",          "DOCTYPE is not HTML 5",
    "Charset is not UTF-8",           "Charset is not UTF-8",
    "Charset is not defined",         "Charset is not defined",
    "Missing rel attribute in",       "Missing 'rel' attribute in ",
    "Missing rel value in",           "Missing 'rel' value in ",
    "Invalid rel value",              "Invalid 'rel' value",
    "Missing rel value",              "Missing 'rel' value",
    "Microdata HTML data syntax found", "Microdata HTML data syntax found",
    "More Microdata HTML data attributes found", "More Microdata HTML data attributes found than RDFa Lite attributes",
    "Missing vocab content",          "Missing vocab content",
    "Invalid vocab content",          "Invalid vocab content",
    "Content missing from RDFa attribute", "Content missing from RDFa attribute",
    "Missing vocab attribute",        "Missing 'vocab' attribute",
    "Missing typeof attribute",       "Missing 'typeof' attribute",
    "expecting one of",               "expecting one of",
    "Missing RDFa Lite attributes, found vocab only", "Missing RDFa Lite attributes, found vocab only",
    "Value not defined in vocab",     "Value not defined in \"vocab\"",
    "for attribute",                  "for attribute",
);

#
# String table for error strings (French).
#
my %string_table_fr = (
    "DOCTYPE missing",                "DOCTYPE manquant",
    "DOCTYPE is not HTML 5",          "DOCTYPE ne pas HTML 5",
    "Charset is not UTF-8",           "Charset ne pas UTF-8",
    "Charset is not defined",         "Charset n'est pas définie",
    "Missing rel attribute in",       "Attribut 'rel' manquant dans ",
    "Missing rel value in",           "Valeur manquante dans 'rel' ",
    "Invalid rel value",              "Valeur de texte 'rel' est invalide",
    "Missing rel value",              "Valeur manquante pour 'rel'",
    "Microdata HTML data syntax found", "Microdata HTML syntaxe des données trouvé",
    "More Microdata HTML data attributes found", "Plus attributs de données de Microdata HTML trouvé que des attributs RDFa Lite",
    "Missing vocab content",          "Le contenu de 'vocab' est manquant",
    "Invalid vocab content",          "Contenu invalide pour 'vocab'",
    "Content missing from RDFa attribute", "Contenu manquant pour l'attribut RDFa",
    "Missing vocab attribute",        "Attribut 'vocab' manquant",
    "Missing typeof attribute",       "Attribut 'typeof' manquant",
    "expecting one of",               "expectant un des",
    "Missing RDFa Lite attributes, found vocab only", "Manquant des attributs RDFa Lite, trouvé \"vocab\" seulement",
    "Value not defined in vocab",     "Valeur n'est pas définie dans \"vocab\"",
    "for attribute",                  "pour l'attribut",
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#**********************************************************************
#
# Name: Set_Interop_HTML_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Interop_HTML_Check_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_Interop_HTML_Check_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_Interop_HTML_Check_Language, language = English\n" if $debug;
        $string_table = \%string_table_en;
    }
}

#***********************************************************************
#
# Name: Set_Interop_HTML_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Interop_HTML_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
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
# Name: Read_Schema_Details
#
# Parameters: schema - schema name
#             filename - name of file containing schema details
#
# Description:
#
#   This function reads the specified file which is expected to contain
# schema details (types, properties) in JSON format.  The function returns
# a reference to the JSON data structure for the schema details.  An
# undefined value is returned if the file could not be be found, read or if
# the content count not be parsed.  Comment lines in the file (leadiing #
# character) are removed prior to parsing.
#
#***********************************************************************
sub Read_Schema_Details {
    my ($schema, $filename) = @_;
    
    my ($line, $content, $ref, $eval_output);
    
    #
    # Open the schema details file
    #
    if ( open(SCHEMA, "$program_dir/$filename") ) {
        while ( $line = <SCHEMA> ) {
            #
            # Ignore comment lines
            #
            if ( $line =~ /^\s*#/ ) {
                next;
            }
            else {
                $content .= $line;
            }
        }
        
        #
        # Close the schema file
        #
        close(SCHEMA);
        
        #
        # Parse the content as JSON
        #
        $eval_output = eval { $ref = decode_json($content); 1 } ;

        #
        # Did the parse fail ?
        #
        if ( ! $eval_output ) {
            $eval_output =~ s/ at \S* line \d*$//g;
            print "Error: Failed to parse schema details file $eval_output\n" if $debug;
        }
    }
    else {
        print "Error: Failed to open schema details file $program_dir/$filename\n" if $debug;
    }
    
    #
    # Return the reference to the JSON object
    #
    return($ref);
}

#***********************************************************************
#
# Name: Set_Interop_HTML_Check_Testcase_Data
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
sub Set_Interop_HTML_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    my ($type, $value, $schema, $filename, $ref);

    #
    # Check the testcase id
    #
    if ( $testcase =~ /^SWI_D$/i ) {
        ($type, $value) = split(/\s+/, $data, 2);
        
        #
        # Check the type of SWI_D data
        #
        if ( defined($value) && ($type =~ /^IGNORE_REL_DOMAIN$/i) ) {
            $ignore_rel_domains{$value} = 1;
        }
    }
    elsif ( $testcase =~ /^SWI_E$/i ) {
        ($type, $value) = split(/\s+/, $data, 2);
        
        #
        # Check the type of SWI_E data
        #
        if ( defined($value) && ($type =~ /^HTML_DATA_VOCAB$/i) ) {
            #
            # Set possible "vocab" value.
            #
            $html_data_vocab{$value} = 1;
        }
        elsif ( defined($value) && ($type =~ /^SCHEMA_DETAILS$/i) ) {
            #
            # Get schema name and types & properties file name.
            #
            ($schema, $filename) = split(/\s+/, $value, 2);
            
            #
            # If we have a filemame, read the types & properties from
            # the file.
            #
            if ( defined($filename) ) {
                $ref = Read_Schema_Details($schema, $filename);
                
                #
                # If we have a ref value, save it in the schema details table.
                #
                if ( defined($ref) ) {
                    print "Got schema details for $schema from $filename\n" if $debug;
                    $schema_details{$schema} = $ref;
                }
            }
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
# Name: Set_Interop_HTML_Check_Test_Profile
#
# Parameters: profile - check test profile
#             interop_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by testcase name.
#
#***********************************************************************
sub Set_Interop_HTML_Check_Test_Profile {
    my ($profile, $interop_checks ) = @_;

    my (%local_interop_checks);
    my ($key, $value);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Interop_HTML_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_interop_checks = %$interop_checks;
    $interop_check_profile_map{$profile} = \%local_interop_checks;
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - test profile
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
    $current_interop_check_profile = $interop_check_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;

    #
    # Initialize flags and counters
    #
    $doctype_label = "";
    $doctype_version = 0;
    $doctype_class = "";
    $charset = "";
    $charset_line = -1;
    $charset_column = 0;
    $charset_text = "";
    $rdfa_found = 0;
    $missing_rdfa_vocab_reported = 0;
    $missing_rdfa_typeof_reported = 0;
    $rdfa_attr_count = 0;
    $microdata_found = 0;
    $microdata_attr = "";
    $microdata_attr_count = 0;
    $microdata_line = "";
    $microdata_column = "";
    $microdata_text = "";
    @vocab_tag_stack = ();
    @typeof_tag_stack = ();
    $current_typeof_value = "";
    @typeof_stack = ();
    $inside_vocab = 0;
    $inside_typeof = 0;
    undef($current_schema_details);
    undef($current_schema_properties);
    undef($current_schema_types);
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
    if ( defined($testcase) && defined($$current_interop_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $check_fail,
                                                Interop_Testcase_Description($testcase),
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
# Name: Declaration_Handler
#
# Parameters: text - declaration text
#             line - line number
#             column - column number
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the declaration line in an HTML document.
#
#***********************************************************************
sub Declaration_Handler {
    my ( $text, $line, $column ) = @_;

    my ($testcase, $tcid);
    my ($top, $availability, $registration, $organization, $type, $label);
    my ($language, $url, $doctype_language);

    #
    # Save declaration location
    #
    $doctype_line   = $line;
    $doctype_column = $column;
    $doctype_text   = $text;

    #
    # Convert any newline or return characters into whitespace
    #
    $text =~ s/\r/ /g;
    $text =~ s/\n/ /g;

    #
    # Parse the declaration line to get its fields, we only care about the FPI
    # (Formal Public Identifier) field.
    #
    #  <!DOCTYPE root-element PUBLIC "FPI" ["URI"]
    #    [ <!-- internal subset declarations --> ]>
    #
    ($top, $availability, $registration, $organization, $type, $label, $language, $url) =
         $text =~ /^\s*\<!DOCTYPE\s+(\w+)\s+(\w+)\s+"(.)\/\/(\w+)\/\/(\w+)\s+([\w\s\.\d]*)\/\/(\w*)".*>\s*$/io;

    #
    # Did we get an FPI ?
    #
    if ( defined($label) ) {
        #
        # Parse out the language (HTML vs XHTML), the version number
        # and the class (e.g. strict)
        #
        $doctype_label = $label;
        ($doctype_language, $doctype_version, $doctype_class) =
            $doctype_label =~ /^([\w\s]+)\s+(\d+\.\d+)\s*(\w*)\s*.*$/io;
    }
    #
    # No Formal Public Identifier, perhaps this is a HTML 5 document ?
    #
    elsif ( $text =~ /\s*<!DOCTYPE\s+html>\s*/i ) {
        $doctype_label = "HTML";
        $doctype_version = 5;
        $doctype_class = "";
    }
    print "DOCTYPE label = $doctype_label, version = $doctype_version, class = $doctype_class\n" if $debug;
}

#***********************************************************************
#
# Name: Meta_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the meta tag, it looks to see if it is used
# for specifying the page character set.
#
#***********************************************************************
sub Meta_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    my ($content, @values, $value);

    #
    # Do we have a charset attribute (HTML 5 syntax)?
    #
    if ( defined($attr{"charset"}) ) {
        $charset = $attr{"charset"};
        $charset_line = $line;
        $charset_column = $column;
        $charset_text = $text;
        print "Found meta charset = $charset\n" if $debug;
    }

    #
    # Do we have http-equiv="Content-Type"
    #
    elsif ( defined($attr{"http-equiv"}) &&
            ($attr{"http-equiv"} =~ /Content-Type/i) ) {
        #
        # Check for content
        #
        if ( defined($attr{"content"}) ) {
            $content = $attr{"content"};

            #
            # Split content on ';'
            #
            @values = split(/;/, $content);

            #
            # Look for a 'charset=' value
            #
            foreach $value (@values) {
                if ( $value =~ /^\s*charset=/i ) {
                    ($value, $charset) = split(/=/, $value);
                    $charset_line = $line;
                    $charset_column = $column;
                    $charset_text = $text;
                    print "Found meta http-equiv=Content-Type, charset = $charset\n" if $debug;
                    last;
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Microdata_Data_Attributes
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks the tag for possible Microdata HTML data attributes.
#
#***********************************************************************
sub Check_Microdata_Data_Attributes {
    my ($tagname, $line, $column, $text, %attr) = @_;

    #
    # Check for Microdata syntax.
    #
    if ( defined($attr{"itemscope"}) ) {
        $microdata_attr = "itemscope";
        $microdata_attr_count++;
    }
    elsif ( defined($attr{"itemtype"}) ) {
        $microdata_attr = "itemtype";
        $microdata_attr_count++;
    }
    elsif ( defined($attr{"itemprop"}) ) {
        $microdata_attr = "itemprop";
        $microdata_attr_count++;
    }

    #
    # If this is the first time we found an attribute,
    # set flag and save the location details
    #
    if ( (! $microdata_found) && ($microdata_attr ne "") ) {
        print "Found Microdata attribute $microdata_attr at $line:$column\n" if $debug;
        $microdata_found = 1;
        $microdata_line = $line;
        $microdata_column = $column;
        $microdata_text = $text;
    }
}

#***********************************************************************
#
# Name: Check_Vocab_Attribute
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks the tag for a possible RDFa Lite HTML vocab
# attribute.
#
#***********************************************************************
sub Check_Vocab_Attribute {
    my ($tagname, $line, $column, $text, %attr) = @_;

    my ($vocab, $values);

    #
    # Check for RDFa Lite attribute vocab
    #
    print "Check_Vocab_Attribute\n" if $debug;
    if ( defined($attr{"vocab"}) ) {
        $inside_vocab = 1;
        $rdfa_found = 1;
        $rdfa_attr_count++;
        print "Found RDFa Lite attribute vocab in tag $tagname at $line:$column\n" if $debug;

        #
        # Is the vocabulary one of the expected values ?
        #
        $vocab = $attr{"vocab"};
        if (  $vocab =~ /^\s*$/ ) {
            #
            # Missing vocabulary
            #
            $values = join(", ", keys %html_data_vocab);
            Record_Result("SWI_E", $line, $column, $text,
                          String_Value("Missing vocab content") . " " .
                          String_Value("expecting one of") . " \"$values\"");
        }
        elsif ( ! defined($html_data_vocab{$vocab}) ) {
            #
            # Invalid vocabulary
            #
            $values = join(", ", keys %html_data_vocab);
            Record_Result("SWI_E", $line, $column, $text,
                          String_Value("Invalid vocab content") .
                          " \"$vocab\" " . String_Value("expecting one of") .
                          " \"$values\"");
        }

        #
        # Do we have schema details for this vocabulary
        #
        if ( defined($schema_details{$vocab}) ) {
            $current_schema_details = $schema_details{$vocab};
            $current_schema_types = $$current_schema_details{"types"};
            $current_schema_properties = $$current_schema_details{"properties"};
            $current_schema_vocab = $vocab;
        }
    }
}

#***********************************************************************
#
# Name: Check_Typeof_Attribute
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks the tag for a possible RDFa Lite HTML typeof
# attribute.
#
#***********************************************************************
sub Check_Typeof_Attribute {
    my ($tagname, $line, $column, $text, %attr) = @_;

    my ($attribute, $content);

    #
    # Check for typeof attribute
    #
    print "Check_Typeof_Attribute\n" if $debug;
    if ( defined($attr{"typeof"}) ) {
        $inside_typeof = 1;
        $rdfa_found = 1;
        $rdfa_attr_count++;
        print "Found RDFa Lite attribute typeof in tag $tagname at $line:$column\n" if $debug;

        #
        # Have we seen a vocab attribute to set the vocabulary ?
        #
        if ( (! $inside_vocab) && ( ! $missing_rdfa_vocab_reported) ) {
            Record_Result("SWI_E_RDFA", $line, $column, $text,
                          String_Value("Missing vocab attribute"));

            #
            # Set flag so we don't report this again until we see a vocab.
            #
            $missing_rdfa_vocab_reported = 1;
        }

        #
        # Do we have content for the attribute ?
        #
        $content = $attr{"typeof"};
        if ( $content =~ /^\s*$/ ) {
            Record_Result("SWI_E_RDFA", $line, $column, $text,
                          String_Value("Content missing from RDFa attribute") .
                          " \"typeof\"");
        }
        else {
            #
            # Save current "typeof" value (so we can use it
            # when checking properties).
            #
            $current_typeof_value = $content;

            #
            # Do we have current schema details ?
            #
            if ( defined($current_schema_types) ) {
                #
                # Is this "typeof" value defined for the schema ?
                # Skip values that contain a colon ":", this syntax is
                # used when multiple vocabularies are used.  We are only
                # checking the primary vocabulary.
                #
                print "Check typeof = $content in schema\n" if $debug;
                if ( ! ($content =~ /:/) ) {
                    if ( ! defined($$current_schema_types{$content}) ) {
                        print "Error: typeof \"$content\" not defined in vocab\n" if $debug;
                        Record_Result("SWI_E_RDFA", $line, $column, $text,
                                      String_Value("Value not defined in vocab") .
                                      " \"$current_schema_vocab\" " .
                                      String_Value("for attribute") .
                                      " \'typeof=\"$content\"\'");
                    }
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Property_Attribute
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks the tag for possible RDFa Lite HTML data
# attributes.
#
#***********************************************************************
sub Check_Property_Attribute {
    my ($tagname, $line, $column, $text, %attr) = @_;

    my ($content, $properties, $ref, @empty_list, $property, $found);

    #
    # Check for property attribute
    #
    print "Check_Property_Attribute\n" if $debug;
    if ( defined($attr{"property"}) ) {
        print "Found RDFa Lite attribute property in tag $tagname at $line:$column\n" if $debug;

        #
        # Have we seen a vocab attribute to set the vocabulary ?
        #
        if ( (! $inside_vocab) && ( ! $missing_rdfa_vocab_reported) ) {
            Record_Result("SWI_E_RDFA", $line, $column, $text,
                          String_Value("Missing vocab attribute"));

            #
            # Set flag so we don't report this again until we see a vocab.
            #
            $missing_rdfa_vocab_reported = 1;
        }

        #
        # Do we have content for the attribute ?
        #
        if ( $attr{"property"} =~ /^\s*$/ ) {
            Record_Result("SWI_E_RDFA", $line, $column, $text,
                          String_Value("Content missing from RDFa attribute") .
                          " \"property\"");
        }
        #
        # Are we inside a typeof ?
        #
        elsif ( ! $inside_typeof ) {
            Record_Result("SWI_E_RDFA", $line, $column, $text,
                          String_Value("Missing typeof attribute"));
        }
        #
        # Do we have current schema details ?
        #
        elsif ( defined($current_schema_details) ) {
            #
            # Is this "property" value defined for the typeof
            # value in this schema ?
            # Skip values that contain a colon ":", this syntax is
            # used when multiple vocabularies are used.  We are only
            # checking the primary vocabulary.
            #
            $content = $attr{"property"};
            print "Check typeof = $content in schema\n" if $debug;
            if ( ! ($content =~ /:/) ) {
                #
                # Get properties for the current typeof value
                #
                $properties = \@empty_list;
                if ( defined($current_typeof_value) &&
                     defined($$current_schema_types{$current_typeof_value}) ) {
                    $ref = $$current_schema_types{$current_typeof_value};
                    if ( defined($$ref{"properties"}) ) {
                        $properties = $$ref{"properties"};
                        print "Properties for $current_typeof_value are " .
                              join(",", @$properties) . "\n" if $debug;
                    }
                }

                #
                # Is this property in the list of properties for the
                # typeof value ?
                #
                $found = 0;
                foreach $property (@$properties) {
                    if ( $content eq $property ) {
                        print "Found match on property value\n" if $debug;
                        $found = 1;
                        last;
                    }
                }

                #
                # Did we find a match on the property value
                #
                if ( ! $found ) {
                    print "Error: property \"$content\" not defined in vocab\n" if $debug;
                    Record_Result("SWI_E_RDFA", $line, $column, $text,
                                  String_Value("Value not defined in vocab") .
                                  " \"$current_schema_vocab\" " .
                                  String_Value("for attribute") .
                                  " \'typeof=\"$current_typeof_value\" property=\"$content\"\'");
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Other_RDFa_Attributes
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks the tag for possible RDFa Lite HTML data
# attributes.
#
#***********************************************************************
sub Check_Other_RDFa_Attributes {
    my ($tagname, $line, $column, $text, %attr) = @_;

    my ($attribute);

    #
    # Check for other RDFa Lite attributes
    #
    print "Check_Other_RDFa_Attributes\n" if $debug;
    foreach $attribute (@other_rdfa_lite_attributes) {
        if ( defined($attr{"$attribute"}) ) {
            $rdfa_found = 1;
            $rdfa_attr_count++;
            print "Found RDFa Lite attribute $attribute in tag $tagname at $line:$column\n" if $debug;

            #
            # Have we seen a vocab attribute to set the vocabulary ?
            #
            if ( (! $inside_vocab) && ( ! $missing_rdfa_vocab_reported) ) {
                Record_Result("SWI_E_RDFA", $line, $column, $text,
                              String_Value("Missing vocab attribute"));

                #
                # Set flag so we don't report this again until we see a vocab.
                #
                $missing_rdfa_vocab_reported = 1;
            }

            #
            # Have we seen a typeof attribute to set the item type ?
            #
            if ( (! $inside_typeof) && ( ! $missing_rdfa_typeof_reported) ) {
                Record_Result("SWI_E_RDFA", $line, $column, $text,
                              String_Value("Missing typeof attribute"));

                #
                # Set flag so we don't report this again until we see a typeof.
                #
                $missing_rdfa_typeof_reported = 1;
            }

            #
            # Do we have content for the attribute ?
            #
            if ( $attr{"$attribute"} =~ /^\s*$/ ) {
                Record_Result("SWI_E_RDFA", $line, $column, $text,
                              String_Value("Content missing from RDFa attribute") .
                              " \"$attribute\"");
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_RDFa_Lite_Data_Attributes
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks the tag for possible RDFa Lite HTML data
# attributes.
#
#***********************************************************************
sub Check_RDFa_Lite_Data_Attributes {
    my ($tagname, $line, $column, $text, %attr) = @_;

    #
    # Check for RDFa Lite attribute vocab
    #
    print "Check_RDFa_Lite_Data_Attributes\n" if $debug;
    Check_Vocab_Attribute($tagname, $line, $column, $text, %attr);
    
    #
    # Check for RDFa Lite attribute typeof
    #
    Check_Typeof_Attribute($tagname, $line, $column, $text, %attr);

    #
    # Check for RDFa Lite attribute property
    #
    Check_Property_Attribute($tagname, $line, $column, $text, %attr);

    #
    # Check for other RDFa Lite attributes
    #
    Check_Other_RDFa_Attributes($tagname, $line, $column, $text, %attr);

}

#***********************************************************************
#
# Name: Check_HTML_Data_Attributes
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function checks the tag for possible HTML data attributes.
#
#***********************************************************************
sub Check_HTML_Data_Attributes {
    my ($tagname, $line, $column, $text, %attr) = @_;

    #
    # Check for possible RDFa Lite mark-up
    #
    Check_RDFa_Lite_Data_Attributes($tagname, $line, $column, $text, %attr);

    #
    # Check for possible Microdata mark-up
    #
    Check_Microdata_Data_Attributes($tagname, $line, $column, $text, %attr);
}

#***********************************************************************
#
# Name: Start_Handler
#
# Parameters: self - reference to this parser
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
    my ( $self, $tagname, $line, $column, $text, @attr ) = @_;

    my (%attr_hash) = @attr;

    #
    # Check meta tags
    #
    $tagname =~ s/\///g;
    print "Start_Handler tag $tagname at $line:$column\n" if $debug;
    if ( $tagname eq "meta" ) {
        Meta_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check for HTML Data attributes on the tag
    #
    Check_HTML_Data_Attributes($tagname, $line, $column, $text, %attr_hash);

    #
    # Does this tag have an explicit end tag ?
    #
    if ( ! defined($html_tags_with_no_end_tag{$tagname}) ) {
        #
        # Are we inside a "vocab" setting ? If so we must remember this
        # tag so we know when get get to the end of the block that
        # started the "vocab".
        #
        if ( $inside_vocab ) {
            print "Push tag onto vocab tag stack $tagname at $line:$column\n" if $debug;
            push(@vocab_tag_stack, $tagname);
        }

        #
        # Are we inside a "typeof" setting ? If so we must remember this
        # tag so we know when get get to the end of the block that
        # started the "typeof". Also save the typeof value.
        #
        if ( $inside_typeof ) {
            print "Push tag onto typeof tag stack $tagname at $line:$column\n" if
 $debug;
            push(@typeof_tag_stack, "$tagname:$line:$column");
            push(@typeof_stack, $current_typeof_value);
        }
    }
}

#***********************************************************************
#
# Name: End_Handler
#
# Parameters: self - reference to this parser
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
    my ( $self, $tagname, $line, $column, $text, %attr ) = @_;

    my ($popped_tag);

    #
    # Does this tag have an explicit end tag ?
    #
    print "End_Handler tag $tagname at $line:$column\n" if $debug;
    if ( ! defined($html_tags_with_no_end_tag{$tagname}) ) {
        #
        # Are we inside a "vocab" setting ? If so we must pop a tag
        # (should be this tag) from the stack.  If we end up with no
        # tags left, we have ended the "vocab" block.
        #
        if ( $inside_vocab ) {
            $popped_tag = pop(@vocab_tag_stack);
            print "Popped tag from vocab tag stack $tagname at $line:$column\n" if $debug;

            #
            # Do we have any tags left ?
            #
            if ( @vocab_tag_stack == 0 ) {
                print "End of vocab tag stack\n" if $debug;
                $inside_vocab = 0;
                $missing_rdfa_vocab_reported = 0;
                undef($current_schema_details);
                undef($current_schema_properties);
                undef($current_schema_types);
            }
        }

        #
        # Are we inside a "typeof" setting ? If so we must pop a tag
        # (should be this tag) from the stack.  If we end up with no
        # tags left, we have ended the "typeof" block.
        #
        if ( $inside_typeof ) {
            $popped_tag = pop(@typeof_tag_stack);
            print "Popped tag from typeof tag stack $tagname at $line:$column\n" if $debug;
            
            #
            # Pop off the last typeof value
            #
            $current_typeof_value = pop(@typeof_stack);

            #
            # Do we have any tags left ?
            #
            if ( @typeof_tag_stack == 0 ) {
                print "End of typeof tag stack\n" if $debug;
                $inside_typeof = 0;
                $missing_rdfa_typeof_reported = 0;
                $current_typeof_value = "";
            }
            else {
                $current_typeof_value = $typeof_stack[$#typeof_stack - 1];
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Baseline_Technologies
#
# Parameters: none
#
# Description:
#
#   This function checks that the appropriate baseline technologie is
# used in the web page.
#
#***********************************************************************
sub Check_Baseline_Technologies {

    #
    # Did we find a DOCTYPE line ?
    #
    if ( $doctype_label ne "" ) {
        #
        # It is HTML 5 ?
        #
        if ( ($doctype_label ne "HTML") || ($doctype_version != 5) ||
              ($doctype_class ne "") ) {
            #
            # Missing DOCTYPE
            #
            Record_Result("SWI_D", $doctype_line, $doctype_column, $doctype_text,
                          String_Value("DOCTYPE is not HTML 5"));
        }
    }
    else {
        #
        # Missing DOCTYPE
        #
        Record_Result("SWI_D", -1, 0, "",
                      String_Value("DOCTYPE missing"));
    }
}

#***********************************************************************
#
# Name: Check_Encoding
#
# Parameters: resp - HTTP response object
#
# Description:
#
#   This function checks the character encoding of the web page.
#
#***********************************************************************
sub Check_Encoding {
    my ($resp) = @_;

    #
    # Do we have a HTTP::Response object ?
    #
    if ( defined($resp) ) {
        #
        # Does the HTTP response object indicate the content is UTF-8
        #
        if ( ($resp->header('Content-Type') =~ /charset=UTF-8/i) ||
             ($resp->header('X-Meta-Charset') =~ /UTF-8/i) ) {
            print "UTF-8 content\n" if $debug;
        }
        else {
            #
            # Did we find any <meta> tag with a charset setting ?
            #
            if ( $charset =~ /UTF-8/i ) {
                print "UTF-8 content\n" if $debug;
            }
            elsif ( $charset eq "" ) {
                #
                # Not UTF 8 content
                #
                Record_Result("SWI_C", -1, 0, "",
                              String_Value("Charset is not defined"));
            }
            else {
                #
                # Not UTF 8 content
                #
                Record_Result("SWI_C", $charset_line, $charset_column,
                              $charset_text,
                              String_Value("Charset is not UTF-8"));
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_HTML_Data_Type
#
# Parameters: none
#
# Description:
#
#   This function checks if we only found a non standard HTML data syntax
#  (e.g. Microdata).  If RDFa Lite is found along with other syntaxes, no
# error is reported.
#
#***********************************************************************
sub Check_HTML_Data_Type {

    #
    # Did we not find RDFa Lite syntax ?
    #
    if ( ! $rdfa_found ) {
        print "No RDFa Lite HTML data found in document\n" if $debug;
        #
        # Did we find Microdata ?
        #
        if ( $microdata_found ) {
            #
            # Invalid HTML Data syntax used
            #
            Record_Result("SWI_E", $microdata_line, $microdata_column,
                          $microdata_text,
                          String_Value("Microdata HTML data syntax found"));
        }
    }
    #
    # Do we have only 1 RDFa Lite attribute ? (i.e. the vocab attribute)
    #
    elsif ( $rdfa_attr_count == 1 ) {
        print "Only 1 RDFa Lite attribute found\n" if $debug;
        Record_Result("SWI_E", -1, -1, "",
                      String_Value("Missing RDFa Lite attributes, found vocab only"));
    }
    #
    # Do we have RDFa Lite and Microdata
    #
    elsif ( $rdfa_found && $microdata_found ) {
        print "RDFa Lite HTML data and Micordata found in document\n" if $debug;
        print "RDFa Lite attribute count = $rdfa_attr_count, Mocrodata count = $microdata_attr_count\n" if $debug;
        #
        # Do we have more Microdata attributes than RDFa Lite attributes ?
        #
        if ( $microdata_attr_count > $rdfa_attr_count ) {
            Record_Result("SWI_E", -1, -1, "",
                          String_Value("More Microdata HTML data attributes found"));
        }
    }
}

#***********************************************************************
#
# Name: Interop_HTML_Check
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
#   This function runs a number of interoperability QA checks the content.
#
#***********************************************************************
sub Interop_HTML_Check {
    my ( $this_url, $language, $profile, $mime_type, $resp, $content ) = @_;

    my (@tqa_results_list, $parser, $result_object);

    #
    # Call the appropriate check function based on the mime type
    #
    print "Interop_HTML_Check: URL $this_url, mime-type = $mime_type, lanugage = $language, profile = $profile\n" if $debug;

    #
    # Do we have a valid profile ?
    #
    print "Interop_HTML_Check: profile = $profile, language = $language\n" if $debug;
    if ( ! defined($interop_check_profile_map{$profile}) ) {
        print "Unknown Interop testcase profile passed $profile\n" if $debug;
        return;
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Are any of the testcases defined in this module
    # in the testcase profile ?
    #
    if ( keys(%$current_interop_check_profile) == 0 ) {
        #
        # No tests handled by this module
        #
        print "No tests handled by this module\n" if $debug;
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
        # Doesn't look like a URL.  Could be just a block of HTML
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Did we get any content ?
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
            declaration => \&Declaration_Handler,
            "text,line,column"
        );
        $parser->handler(
            start => \&Start_Handler,
            "self,tagname,line,column,text,\@attr"
        );
        $parser->handler(
            end => \&End_Handler,
            "self,tagname,line,column,text,\@attr"
        );

        #
        # Parse the content.
        #
        $parser->parse($$content);
    }
    else {
        print "No content passed to Interop_HTML_Check\n" if $debug;
        return(@tqa_results_list);
    }

    #
    # Check baseline technologies
    #
    Check_Baseline_Technologies();
    
    #
    # Check character encoding
    #
    Check_Encoding($resp);

    #
    # Check HTML Data type (e.g. RDFa vs Microdata)
    #
    Check_HTML_Data_Type();

    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Clean_Title
#
# Parameters: text - text string
#
# Description:
#
#   This function eliminates leading and trailing white space from text.
# It encodes any special characters into entities, removes all
# whitespace and convers all characters to lowercase.
#
#***********************************************************************
sub Clean_Title {
    my ($text) = @_;

    #
    # Encode entities.
    #
    $text = decode_entities($text);
    $text = encode_entities($text);

    #
    # Removes &nbsp;, space, newline and return characters.
    #
    $text =~ s/\&nbsp;//g;
    $text =~ s/\n//g;
    $text =~ s/\r//g;
    $text =~ s/\s+//g;

    #
    # Convert to lower case
    #
    $text =lc($text);

    #
    # Return cleaned text
    #
    return($text);
}

#***********************************************************************
#
# Name: Check_Rel_Value
#
# Parameters: link - link object
#             rel - rel attribute value
#             value - expected value
#
# Description:
#
#    This function checks the rel attribute value for a specific
# string value.
#
#***********************************************************************
sub Check_Rel_Value {
    my ($link, $rel, $value) = @_;

    my ($found, $rel_value);

    #
    # Check each word in the rel value for the expected value
    #
    print "Check rel value $rel for $value\n" if $debug;
    $found = 0;
    foreach $rel_value (split(/\s+/, $rel)) {
        if ( $rel_value eq $value ) {
            $found = 1;
            last;
        }
    }

    #
    # Did we find the expected value ?
    #
    if ( ! $found ) {
        print "Missing rel value\n" if $debug;
        Record_Result("SWI_D", $link->line_no, $link->column_no,
                      $link->source_line,
                      String_Value("Missing rel value") .
                      " \"$value\"");
    }
}

#***********************************************************************
#
# Name: Check_Invalid_Rel_Value
#
# Parameters: link - link object
#             rel - rel attribute value
#             value - invalid value
#
# Description:
#
#    This function checks the rel attribute value to see it does
# not contain the specified value.
#
#***********************************************************************
sub Check_Invalid_Rel_Value {
    my ($link, $rel, $value) = @_;

    my ($found, $rel_value);

    #
    # Check each word in the rel value for the invalid value
    #
    print "Check rel value $rel for $value\n" if $debug;
    $found = 0;
    foreach $rel_value (split(/\s+/, $rel)) {
        if ( $rel_value eq $value ) {
            $found = 1;
            last;
        }
    }

    #
    # Did we find the invalid value ?
    #
    if ( $found ) {
        print "Invalid rel value\n" if $debug;
        Record_Result("SWI_D", $link->line_no, $link->column_no,
                      $link->source_line,
                      String_Value("Invalid rel value") .
                      " \"$value\"");
    }
}

#***********************************************************************
#
# Name: Check_Rel_Attribute
#
# Parameters: link - link object
#             tag - tag name
#             required - flag to indicate if the rel attribute
#                        is required
#
# Description:
#
#    This function checks the rel attribute of a tag. It checks
# to see the attribute is present and has a value.
# This function ignores the possibility
# that HTML content may be coded in a language other than HTML5.
#
# Returns
#    rel value
#    empty string - if no rel value exists
#
#***********************************************************************
sub Check_Rel_Attribute {
    my ($link, $tag, $required) = @_;

    my (%attr, $rel_value);
    my ($rel) = "";

    #
    # Get any attributes of the link
    #
    %attr = $link->attr();

    #
    # Do we have a rel attribute ?
    #
    if ( ! defined($attr{"rel"}) ) {
        #
        # Is it required ?
        #
        if ( $required ) {
            Record_Result("SWI_D", $link->line_no, $link->column_no,
                          $link->source_line,
                          String_Value("Missing rel attribute in") . "<$tag>");
        }
    }
    #
    # Do we have a value for the rel attribute ?
    #
    elsif ( $attr{"rel"} eq "" ) {
        #
        # Is it required ?
        #
        if ( $required ) {
            Record_Result("SWI_D", $link->line_no, $link->column_no,
                          $link->source_line,
                          String_Value("Missing rel value in") . "<$tag>");
        }
    }
    #
    # Check validity of the value
    #
    else {
        #
        # Convert rel value to lowercase to make checking easier
        #
        $rel = lc($attr{"rel"});
        print "Rel = $rel\n" if $debug;
        
        #
        # Do we have a set of valid values for this tag ?
        #
        if ( defined($valid_rel_values{$tag}) ) {
            #
            # Check each possible value (may be a whitespace separated list)
            #
            foreach $rel_value (split(/\s+/, $rel)) {
                if ( index($valid_rel_values{$tag}, " $rel_value ") == -1 ) {
                    print "Unknown rel value '$rel_value'\n" if $debug;
                    Record_Result("SWI_D", $link->line_no, $link->column_no,
                                  $link->source_line,
                                  String_Value("Invalid rel value") .
                                  " \"$rel_value\"");
                }
            }
        }
    }
    
    #
    # Return rel value
    #
    return($rel);
}

#***********************************************************************
#
# Name: Anchor_or_Area_Tag
#
# Parameters: link - link object
#             url - source URL
#             title - document title
#
# Description:
#
#    This function checks the rel attribute of a <a> or <area> tag. It checks
# to see the attribute is present, have a value and the value matches
# the file type of the href attribute.  This function ignores the possibility
# that HTML content may be coded in a language other than HTML5.
#
#***********************************************************************
sub Anchor_or_Area_Tag {
    my ($link, $url, $title) = @_;

    my ($rel, $protocol, $source_domain, $dest_domain, $file_path, $query);
    my ($new_url, $dest_url, %source_site_titles, %dest_site_titles);
    my ($source_title, $dest_title, $source_lang, $dest_lang, $title_found);
    my ($domain_minus_www);

    #
    # Is this a javascript: or mailto: link ?
    #
    if ( ($link->href =~ /^javascript:/) || ($link->href =~ /^mailto:/) ) {
        print "javascript or mailto link, skip rel attribute check\n" if $debug;
        return;
    }

    #
    # Check for and get any attributes of the link
    #
    $rel = Check_Rel_Attribute($link, $link->link_type, 0);

    #
    # Get the domain name of the source URL
    #
    ($protocol, $source_domain, $file_path, $query, $new_url) = 
            URL_Check_Parse_URL($url);

    #
    # Get domain of the destination URL
    #
    $dest_url = $link->abs_url;
    if ( defined($dest_url) && ($dest_url ne "") ) {
        ($protocol, $dest_domain, $file_path, $query, $new_url) = 
                URL_Check_Parse_URL($dest_url);

        #
        # Strip off a possible leading www. from the domain
        #
        $domain_minus_www = $dest_domain;
        $domain_minus_www =~ s/^www\.//;

        #
        # Do the domains differ ? If so check the site title.
        # there should be "external" in the rel attribute if the
        # links are to different sites.
        #
        #
        if ( $dest_domain ne $source_domain ) {
            print "Domains differ $source_domain != $dest_domain\n" if $debug;

            #
            # Get the source and destination site title vlues.
            #
            %source_site_titles = Link_Check_Site_Titles($source_domain);
            %dest_site_titles = Link_Check_Site_Titles($dest_domain);
            
            #
            # Check for a match on any title (we may not have all languages
            # for all domains).
            #
            $title_found = 0;
            while ( ($source_lang, $source_title) = each %source_site_titles ) {
                while ( ($dest_lang, $dest_title) = each %dest_site_titles ) {
                    if ( $dest_title eq $source_title ) {
                        print "Found match on site title $source_title\n" if $debug;
                        $title_found = 1;
                        last;
                    }
                }
                
                #
                # Did we find a match with this language ?
                #
                if ( $title_found ) {
                    last;
                }
            }

            #
            # Did we match site title ? If so we do not expect to find a
            # rel="external" attribute.
            #
            if ( $title_found ) {
                Check_Invalid_Rel_Value($link, $rel, "external");
            }
        }

        #
        # If the domains match we should not have a rel="external" attribute.
        #
        if ( $dest_domain eq $source_domain ) {
            print "Domains match\n" if $debug;
            Check_Invalid_Rel_Value($link, $rel, "external");
        }
    }

    #
    # Check mime-type of target document, if it is not text/html it
    # may be an alternate format of this URL. Check to see that
    # both documents are from the same domain, it is unlikely that
    # an alternate format of a document resides on another domain.
    # are the same
    #
    if ( ($dest_domain eq $source_domain) &&
         (! ($link->mime_type =~ /text\/html/)) ) {
        #
        # Does the target URL's title match this one ?
        #
        if ( defined($link->url_title) && 
             ($title eq Clean_Title($link->url_title)) ) {
            #
            # Check for rel="alternate"
            #
            print "Title matches, check for rel=\"alternate\"\n" if $debug;
            Check_Rel_Value($link, $rel, "alternate");
        }
    }
}

#***********************************************************************
#
# Name: Link_Tag
#
# Parameters: link - link object
#             url - source URL
#
# Description:
#
#    This function checks the rel attribute of a <link> tag. It checks
# to see the attribute is present, have a value and the value matches
# the file type of the href attribute.  This function ignores the possibility
# that HTML content may be coded in a language other than HTML5.
#
#***********************************************************************
sub Link_Tag {
    my ($link, $url) = @_;
    
    my ($rel, $mime_type);
    
    #
    # Check for and get any attributes of the link
    #
    $rel = Check_Rel_Attribute($link, "link", 1);

    #
    # Check the mime type of the link
    #
    $mime_type = $link->mime_type;

    #
    # Is this a <link> to a CSS file ?
    #
    if ( defined($mime_type) && ($mime_type =~ /text\/css/) ) {
        #
        # Does the rel attribute contain the string "stylesheet" ?
        #
        Check_Rel_Value($link, $rel, "stylesheet");
    }
}

#***********************************************************************
#
# Name: Interop_HTML_Check_Links
#
# Parameters: results_list - address of hash table results
#             url - URL
#             title - document title
#             profile - testcase profile
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function performs a number of checks on links found within a
# document.  Checks are performed rel attribute of links.
#
#***********************************************************************
sub Interop_HTML_Check_Links {
    my ($results_list, $url, $title, $profile, $language, $link_sets) = @_;
    
    my ($link, $list_addr, $section, $link_type, %attr);
    my (@local_results_list, $result_object);

    #
    # Do we have a valid profile ?
    #
    print "Interop_HTML_Check_Links: profile = $profile, language = $language\n" if $debug;
    if ( ! defined($interop_check_profile_map{$profile}) ) {
        print "Unknown Interop testcase profile passed $profile\n" if $debug;
        return;
    }

    #
    # Initialize the test case pass/fail table.
    #
    $current_interop_check_profile = $interop_check_profile_map{$profile};
    $results_list_addr = \@local_results_list;

    #
    # Clean up the title to make comparisons easier
    #
    $title = Clean_Title($title);

    #
    # Check each document section's list of links
    #
    while ( ($section, $list_addr) = each %$link_sets ) {
        print "Check links in section $section\n" if $debug;
        #
        # Check each link in the section
        #
        foreach $link (@$list_addr) {
            $link_type = $link->link_type;
            
            #
            # Ignore mailto links
            #
            if ( ! ($link->abs_url =~/^mailto:/i) ) {
                #
                # Check each type of link
                #
                if ( $link_type eq "a" ) {
                    #
                    # Check for a 'rel' attribute
                    #
                    Anchor_or_Area_Tag($link, $url, $title);
                }
                elsif ( $link_type eq "area" ) {
                    #
                    # Check for a 'rel' attribute
                    #
                    Anchor_or_Area_Tag($link, $url, $title);
                }
                elsif ( $link_type eq "link" ) {
                    #
                    # Check for a 'rel' attribute
                    #
                    Link_Tag($link, $url);
                }
            }
        }
    }

    #
    # Add our results to previous results
    #
    foreach $result_object (@local_results_list) {
        push(@$results_list, $result_object);
    }
}

#***********************************************************************
#
# Name: Interop_HTML_Check_Has_HTML_Data
#
# Parameters: url - URL
#
# Description:
#
#   This function checks the URL against the last HTML document analysed.
# If it is a match, it returns whether or not the HTML document contained
# HTML Data mark-up.
#
#***********************************************************************
sub Interop_HTML_Check_Has_HTML_Data {
    my ($url) = @_;

    #
    # Does this URL match the last one analysed ?
    #
    if ( $url eq $current_url ) {
        return($rdfa_found || $microdata_found);
    }
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
    my (@package_list) = ("tqa_result_object", "content_check",
                          "interop_testcases", "url_check", "link_checker");

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

