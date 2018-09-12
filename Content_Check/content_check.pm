#***********************************************************************
#
# Name:   content_check.pm
#
# $Revision: 7501 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Content_Check/Tools/content_check.pm $
# $Date: 2016-02-11 07:56:49 -0500 (Thu, 11 Feb 2016) $
#
# Description:
#
#   This file contains routines that parse HTML files and check for
# a number of technical quality assurance check points.
#
# Public functions:
#     Content_Check
#     Content_Check_Get_Headings
#     Content_Check_HTML_Headings_Report
#     Content_Check_HTML_PDF_Titles
#     Content_Check_Unique_Titles
#     Set_Content_Check_Debug
#     Set_Content_Check_Language
#     Set_Content_Check_Test_Profile
#     Content_Check_Read_URL_Help_File
#     Content_Check_Testcase_URL
#     Content_Check_Extract_Content_From_HTML
#     Content_Check_All_Extracted_Content
#     Content_Check_Alternate_Language_Heading_Check
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

package content_check;

use strict;
use HTML::Parser;
use File::Basename;
use HTML::Entities;

#
# Use WPSS_Tool program modules
#
use content_sections;
use html_landmark;
use language_map;
use pdf_files;
use textcat;
use tqa_result_object;
use tqa_tag_object;
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
    @EXPORT  = qw(Content_Check
                  Content_Check_Get_Headings
                  Content_Check_HTML_Headings_Report
                  Content_Check_HTML_PDF_Titles
                  Content_Check_Unique_Titles
                  Set_Content_Check_Debug
                  Set_Content_Check_Language
                  Set_Content_Check_Test_Profile
                  Content_Check_Read_URL_Help_File
                  Content_Check_Testcase_URL
                  Content_Check_Extract_Content_From_HTML
                  Content_Check_All_Extracted_Content
                  Content_Check_Alternate_Language_Heading_Check
                 );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (%content_check_profile_map, $current_testcase_profile);
my ($html_lang, $current_url, $found_content_section);
my (%parent_subsection_heading_value, %parent_subsection_heading_location);
my (%peer_subsection_heading_value, %peer_subsection_heading_location);
my ($current_heading_level, $results_list_addr);
my (@content_headings, $content_section_handler, %inside_html_tag);
my ($dc_title_text, $dcterms_title_text, @tag_order_stack);
my (%subsection_text, $have_text_handler, $title_text, @all_headings);
my ($current_tag_object, $current_landmark, $landmark_marker);

#
# Create a blank content check profile that is used when extracting headings
# only
#
my (%empty_hash) =();
$content_check_profile_map{""} = \%empty_hash;

#
# List of tags that should have a newline after them
#
my ($line_break_before_tags) = " br dd h1 h2 h3 h4 h5 h6 li ol p ul ";
my ($line_break_after_tags) = " h1 h2 h3 h4 h5 h6 ol ul ";

#
# List of URL suffixes taht should be HTML content
#
my (@html_suffix_list) = (".html", ".HTML", ".htm", ".HTM");

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
#        "track", "track",
        "wbr", "wbr",
);

#
# Status values
#
my ($content_check_pass)       = 0;
my ($content_check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Content language",			"Content language ",
    "does not match URL language", 	" does not match URL language ",
    "Unable to determine content language", "Unable to determine content language",
    "Duplicate headings",		"Duplicate headings",
    "at",				"at",
    "and",				"and",
    "line:column",			" (line:column) ",
    "Insufficient content to determine language", "Insufficient content to determine language",
    "Title",     "Title",
    "No Headings In Document", "** No Headings In Document **",
    "Heading count mismatch", "Heading count mismatch",
    "Heading level mismatch", "Heading level mismatch",
    "in",                     "in",
    "Duplicate title",        "Duplicate title",
    "Title mismatch",         "Title mismatch",
    "Title/dc.title mismatch", "Title/dc.title mismatch",
    "Title/dcterms.title mismatch", "Title/dcterms.title mismatch",
    );

my %string_table_fr = (
    "Content language",			"La langue du contenu ",
    "does not match URL language", 	" ne correspond pas au langue d'URL ",
    "Unable to determine content language", "Impossible de déterminer la langue du contenu",
    "Duplicate headings",		"Double rubriques",
    "at",				"à",
    "and",				"et",
    "line:column",			" (la ligne:colonne) ",
    "Insufficient content to determine language", "Contenu insuffisant pour déterminer la langue",
    "Title",    "Titre",
    "No Headings In Document", "** Rubriques pas trouvées dans le document **",
    "Heading count mismatch", "Rubrique décalage comptent",
    "Heading level mismatch", "Rubrique décalage de niveau",
    "in",                     "dans",
    "Duplicate title",        "Double titre",
    "Title mismatch",         "Titre ne correspond pas",
    "Title/dc.title mismatch", "Title/dc.title ne correspond pas",
    "Title/dcterms.title mismatch", "Title/dcterms.title ne correspond pas",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#
# String tables for testcase ID to testcase descriptions
#
my (%testcase_description_en) = (
"CONTENT_URL_LANGUAGE", "CONTENT_URL_LANGUAGE: Content/URL language mismatch",
"DUPLICATE_HEADINGS", "DUPLICATE_HEADINGS: Multiple headings with the same text",
"DUPLICATE_TITLES", "DUPLICATE_TITLES: Multiple documents with the same title",
"HTML_PDF_TITLE", "HTML_PDF_TITLE: HTML/PDF document title mismatch",
"LANGUAGE_HEADINGS", "LANGUAGE_HEADINGS: Alternate language heading mismatch",
"TITLE_DC_TITLE_MATCH", "TITLE_DC_TITLE_MATCH: <title>/dc.title mismatch",
"TITLE_DCTERMS_TITLE_MATCH", "TITLE_DCTERMS_TITLE_MATCH: <title>/dcterms.title mismatch",
);

my (%testcase_description_fr) = (
"CONTENT_URL_LANGUAGE", "CONTENT_URL_LANGUAGE: Contenu / inadéquation langue URL",
"DUPLICATE_HEADINGS", "DUPLICATE_HEADINGS: Plusieurs en-têtes portant le même texte",
"DUPLICATE_TITLES", "DUPLICATE_TITLES: Plusieurs documents portant le même titre",
"HTML_PDF_TITLE", "HTML_PDF_TITLE: HTML/PDF inadéquation titre du document",
"LANGUAGE_HEADINGS", "LANGUAGE_HEADINGS: Autre langue rubrique discordance",
"TITLE_DC_TITLE_MATCH", "TITLE_DC_TITLE_MATCH: <title>/dc.title inadéquation",
"TITLE_DCTERMS_TITLE_MATCH", "TITLE_DCTERMS_TITLE_MATCH: <title>/dcterms.title inadéquation",
);

#
# Heading indents
#
my (%heading_indents) = (
"1", "&nbsp;",
"2", "&nbsp;&nbsp;",
"3", "&nbsp;&nbsp;&nbsp;",
"4", "&nbsp;&nbsp;&nbsp;&nbsp;",
"5", "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
"6", "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
);


#
# Default to English testcase descriptions
#
my ($testcase_description) = \%testcase_description_en;

#
# Create reverse table, indexed by description
#
my (%reverse_testcase_description_en) = reverse %testcase_description_en;
my (%reverse_testcase_description_fr) = reverse %testcase_description_fr;
my ($reverse_testcase_description_table) = \%reverse_testcase_description_en;

#
#******************************************************************
#
# String table for testcase help URLs
#
#******************************************************************
#

my (%testcase_url_en, %testcase_url_fr);

#
# Default URLs to English
#
my ($url_table) = \%testcase_url_en;

#***********************************************************************
#
# Name: Set_Content_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Content_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;

    #
    # Set debug flag for supporting modules
    #
    HTML_Landmark_Debug($debug);
}

#***********************************************************************
#
# Name: Content_Check_Get_Headings
#
# Parameters: none
#
# Description:
#
#   This function returns the list of headings that were extracted
# from content via a call to Content_Check.
#
#***********************************************************************
sub Content_Check_Get_Headings {

    #
    # Return list of content headings if we found the content section
    #
    if ( $found_content_section ) {
        print "Content_Check_Get_Headings return content headings\n" if $debug;
        return(@content_headings);
    }
    else {
        #
        # Return all headings
        #
        print "Content_Check_Get_Headings return all headings\n" if $debug;
        return(@all_headings);
    }
}

#***********************************************************************
#
# Name: Content_Check_Alternate_Language_Heading_Check
#
# Parameters: profile - testcase profile
#             headings_list - hash table of a list of headings
#                             indexed by URL
#
# Description:
#
#   This function checks for alternate language instances of a
# document (e.g. document-eng.html & document-fra.html) and compares
# the number and level of headings.
#
# Returns:
#    List of result objects
#
#***********************************************************************
sub Content_Check_Alternate_Language_Heading_Check {
    my ($profile, %headings_list) = @_;

    my ($url, $url_eng, $url_headings, $url_eng_headings);
    my ($heading_count, $eng_heading_count, $i, $heading);
    my ($heading_level, $heading_value, $eng_heading_level);
    my (@content_results_list, $eng_heading_value);

    #
    # Do we have a valid profile ?
    #
    print "Content_Check_Alternate_Language_Heading_Check profile = $profile\n" if $debug;
    if ( ! defined($content_check_profile_map{$profile}) ) {
        print "Content_Check_Alternate_Language_Heading_Check: Unknown testcase profile passed $profile\n";
        return(@content_results_list);
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@content_results_list);

    #
    # Check each URL in the headings list
    #
    while ( ($url, $url_headings) = each %headings_list ) {
        print "Headings check of $url\n" if $debug;
        
        #
        # Get English URL for this URL
        #
        $url_eng = URL_Check_Get_English_URL($url);
        print "English URL = $url_eng\n" if $debug;
        
        #
        # Did we get an English URL ?
        #
        if ( ($url_eng ne "") && ($url_eng ne $url) ) {
            #
            # Do we have a headings list entry for this URL ?
            #
            $current_url = $url_eng;
            if ( defined($headings_list{$url_eng}) ) {
                $url_eng_headings = $headings_list{$url_eng};
                
                #
                # Get number of headings for each URL
                #
                $heading_count = @$url_headings;
                $eng_heading_count = @$url_eng_headings;
                print "Heading counts $heading_count and $eng_heading_count\n" if $debug;
                
                #
                # Compare heading counts
                #
                if ( $heading_count != $eng_heading_count ) {
                    #
                    # Heading cound mismatch
                    #
                    Record_Result("LANGUAGE_HEADINGS",
                          String_Value("Heading count mismatch") .
                          " $eng_heading_count " . String_Value("in") . " $url_eng\n" .
                          " $heading_count " . String_Value("in") . " $url");
                }
                else {
                    #
                    # Number of headings match, do the levels match
                    # in order ?
                    #
                    for ($i = 0; $i < $heading_count; $i++) {
                        #
                        # Head heading level and values
                        #
                        $heading = $$url_headings[$i];
                        ($heading_level, $heading_value) = split(/:/, $heading);
                        $heading = $$url_eng_headings[$i];
                        ($eng_heading_level, $eng_heading_value) = split(/:/, $heading);

                        #
                        # Do the heading values match ?
                        #
                        print "Heading # $i, levels $heading_level, $eng_heading_level\n" if $debug;
                        if ( $heading_level != $eng_heading_level ) {
                            print "Heading level mismatch\n" if $debug;
                            Record_Result("LANGUAGE_HEADINGS",
                                 String_Value("Heading level mismatch") .
                                 String_Value("heading #") . $i + 1 .
                                 " <h$eng_heading_level>$eng_heading_value</h$eng_heading_level> " .
                                 String_Value("in") . " $url_eng\n" .
                                 " <h$heading_level>$heading_value</h$heading_level> " .
                                 String_Value("in") . " $url");
                        }
                    }
                }
            }
        }
    }
    
    #
    # Return list of tqa_result_objects
    #
    return(@content_results_list);
}

#***********************************************************************
#
# Name: Content_Check_All_Extracted_Content
#
# Parameters: none
#
# Description:
#
#   This function returns the text from each content section that was
# extracted from content via a call to Content_Check.
#
#***********************************************************************
sub Content_Check_All_Extracted_Content {

    #
    # Return text from all sections
    #
    return(%subsection_text);
}

#***********************************************************************
#
# Name: Content_Check_HTML_Headings_Report
#
# Parameters: heading_table - address of a hash table of headings
#             title_table - address of a hash table of titles
#
# Description:
#
#   This function returns a report of documents, their title and
# their headings.  The 2 tables provided are indexed by URLs and
# consist of a title value or a list of headings.  The report is
# formatted with HTML.
#
#***********************************************************************
sub Content_Check_HTML_Headings_Report {
    my ($heading_table, $title_table) = @_;
    
    my ($url, $heading_level, $heading_value, $title);
    my (@urls, $heading_list, $heading);
    my ($report) = "";
    
    #
    # Get sorted list of URLs from the title table.
    # Both tables are expected to have the same keys.
    #
    print "Content_Check_HTML_Headings_Report\n" if $debug;
    @urls = sort(keys(%$title_table));

    #
    # Loop through the URLs and report their title & headings
    #
    foreach $url (@urls) {
        #
        # Get title
        #
        $title = $$title_table{$url};
        $title = encode_entities($title);
        print "URL: $url\n" if $debug;
        print "    Title: $title\n" if $debug;
        $report .= "
<h2><a href=\"$url\">$url</a></h2>
<p>" . String_Value("Title") . " =\"$title\"</p>
";

        #
        # Get address of heading list
        #
        $heading_list = $$heading_table{$url};
        
        #
        # Do we have any headings ?
        #
        if ( ! defined($heading_list) ) {
        }
        elsif ( @$heading_list > 0 ) {
            $report .= "<ul>";
            foreach $heading (@$heading_list) {
                ($heading_level, $heading_value) = split(/:/, $heading);
                $heading_value = encode_entities($heading_value);
                print "    H$heading_level: $heading_value\n" if $debug;
                $report .= "
<li>" . $heading_indents{$heading_level} . "H$heading_level: $heading_value</li>
";
            }
        $report .= "
</ul>
";
        }
        else {
            #
            # No headings in this URL
            #
            $report .= "
<p>" . encode_entities(String_Value("No Headings In Document")) . "</p>";
        }
    }
    
    #
    # Return report
    #
    return($report);
}

#***********************************************************************
#
# Name: Set_Content_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Content_Check_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        $string_table = \%string_table_fr;
        $testcase_description = \%testcase_description_fr;
    }
    else {
        #
        # Default language is English
        #
        $string_table = \%string_table_en;
        $testcase_description = \%testcase_description_en;
    }
}

#***********************************************************************
#
# Name: Set_Content_Check_Test_Profile
#
# Parameters: profile - content check test profile
#             content_checks - hash table of test name and required value
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by test name with 
# the value being 0 = test is optional, 1 = test is required.
#
#***********************************************************************
sub Set_Content_Check_Test_Profile {
    my ($profile, $content_checks ) = @_;

    my (%local_content_checks);
    my ($key, $value);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    %local_content_checks = %$content_checks;
    $content_check_profile_map{$profile} = \%local_content_checks;
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
# Name: Record_Result
#
# Parameters: testcase - testcase identifier
#             error_string - error string
#
# Description:
#
#   This function records the testcase result.
#
#***********************************************************************
sub Record_Result {
    my ( $testcase, $error_string ) = @_;

    my ($result_object);

    #
    # Is this testcase included in the profile
    #
    if ( defined($testcase) && defined($$current_testcase_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase,
                                                $content_check_fail,
                                                $$testcase_description{$testcase},
                                                -1, -1, "",
                                                $error_string, $current_url);
        $result_object->landmark($current_landmark);
        $result_object->landmark_marker($landmark_marker);

        #
        # Save result object in list of results
        #
        push (@$results_list_addr, $result_object);

        #
        # Print error string to stdout
        #
        print "$testcase : $error_string\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - testcase profile
#             local_results_list_addr - address of results list.
#
# Description:
#
#   This function initializes the test case results table.
#
#***********************************************************************
sub Initialize_Test_Results {
    my ($profile, $local_results_list_addr) = @_;

    my ($test_case, $level); 

    #
    # Initialize heading tables
    #
    %parent_subsection_heading_value = ();
    %parent_subsection_heading_location = ();
    %peer_subsection_heading_value = ();
    %peer_subsection_heading_location = ();

    #
    # Set current hash tables
    #
    $current_testcase_profile = $content_check_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;
    
    #
    # Initialize other variables
    #
    @content_headings = ();
    @all_headings = ();
    $have_text_handler = 0;
    $title_text = "";
    $dc_title_text = "";
    $dcterms_title_text = "";
    $found_content_section = 0;
}

#***********************************************************************
#
# Name: HTML_Tag_Handler
#
# Parameters: line - line number
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
    my ( $line, $column, $text, %attr ) = @_;

    my ($lang);

    #
    # Do we have a lang attribute ?
    #
    print "Content_Check:HTML_Tag_Handler\n" if $debug;
    if ( defined( $attr{"lang"} ) ) {
        #
        # Convert language into language code and set global variable
        #
        $lang = lc($attr{"lang"});

        #
        # Is this a 2 character language (ISO 639-1) ?
        #
        if ( defined($language_map::iso_639_1_iso_639_2T_map{$lang}) ) {
            $html_lang = $language_map::iso_639_1_iso_639_2T_map{$lang};
        }
        else {
            #
            # Unknown language
            #
            $html_lang = "";
        }
    }
}

#***********************************************************************
#
# Name: Start_H_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - heading tag name
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the h tag, it starts a text handler to
# capture the heading title.
#
#***********************************************************************
sub Start_H_Tag_Handler {
    my ( $self, $tagname, $line, $column, $text, %attr ) = @_;

    my ($level, $i, @peer_value, @peer_location, $array, $subsection);
    my ($parent_heading_value, $parent_heading_location);
    my ($peer_heading_value, $peer_heading_location);

    #
    # Get heading level number from the tag
    #
    print "Content_Check:Start_H_Tag_Handler\n" if $debug;
    $level = $tagname;
    $level =~ s/^h//g;
    print "Found heading $tagname\n" if $debug;

    #
    # Add a text handler to save the text portion of the object
    # tag.
    #
    $self->handler( text => [], '@{dtext}' );
    $have_text_handler = 1;

    #
    # Get the current subsection name, if we don't have one assume it is
    # the content subsection.
    #
    $subsection = $content_section_handler->current_content_subsection;
    if ( $subsection eq "" ) {
        $subsection = "CONTENT";
    }

    #
    # Get parent and peer heading tables
    #
    if ( ! defined($parent_subsection_heading_value{$subsection}) ) {
        my (%parent_heading_value_table, %parent_heading_location_table);
        my (%peer_heading_value_table, %peer_heading_location_table);
        $parent_subsection_heading_value{$subsection} = \%parent_heading_value_table;
        $parent_subsection_heading_location{$subsection} = \%parent_heading_location_table;
        $peer_subsection_heading_value{$subsection} = \%peer_heading_value_table;
        $peer_subsection_heading_location{$subsection} = \%peer_heading_location_table;
    }
    $parent_heading_value =  $parent_subsection_heading_value{$subsection};
    $parent_heading_location =  $parent_subsection_heading_location{$subsection};
    $peer_heading_value =  $peer_subsection_heading_value{$subsection};
    $peer_heading_location =  $peer_subsection_heading_location{$subsection};

    #
    # Clear out heading values for the next few (in case
    # there is a skip in level numbers).
    #
    for ( $i = $level + 1; $i < ($level + 5); $i++) {
        if ( defined($$parent_heading_value{$i}) ) {
            delete $$parent_heading_value{$i};
        }
        if ( defined($$peer_heading_value{$i}) ) {
            delete $$peer_heading_value{$i};
            delete $$peer_heading_location{$i};
        }
    }

    #
    # Save heading location in parent heading structure
    #
    $current_heading_level = $level;
    $$parent_heading_location{$level} = "$line:$column";

    #
    # Create peer heading lists if they do not exist
    #
    if ( ! defined($$peer_heading_value{$level}) ) {
        $$peer_heading_value{$level} = \@peer_value;
        $$peer_heading_location{$level} = \@peer_location;
    }

    #
    # Save heading location in peer heading structure
    #
    $array = $$peer_heading_location{$level};
    push(@$array, "$line:$column");
    print "h$level at $line:$column\n" if $debug;
}

#***********************************************************************
#
# Name: Check_Parent_Heading_Values
#
# Parameters: heading_value - heading value
#             parent_heading_value - address of table of parent heading values
#             parent_heading_location - address of table of parent heading
#                                       locations
#
# Description:
#
#   This function checks parent heading values for a duplicate of this
# heading value.
#
#***********************************************************************
sub Check_Parent_Heading_Values {
    my ($heading_value, $parent_heading_value, $parent_heading_location) = @_;

    my ($i, $lc_heading_value);
    
    #
    # Do we have heading text, skip duplicate heading check for
    # empty headings.
    #
    if ( $heading_value eq "" ) {
        print "Check_Parent_Heading_Values skip empty heading\n" if $debug;
        return;
    }

    #
    # Convert heading to lowercase to case before looking for duplicates
    #
    $lc_heading_value = lc($heading_value);

    #
    # Check parent headings looking for a duplicate
    #
    for ($i = $current_heading_level - 1; $i > 0; $i--) {
        if ( defined($$parent_heading_value{$i}) &&
             (lc($$parent_heading_value{$i}) eq $lc_heading_value) ) {
            #
            # Duplicate heading value
            #
            print "Duplicate heading value \"$heading_value\" at " .
                  $$parent_heading_location{$current_heading_level} .
                  " and " .
                  $$parent_heading_location{$i} . "\n" if $debug;

            Record_Result("DUPLICATE_HEADINGS",
                          String_Value("Duplicate headings") .
                          "\"" . $$parent_heading_value{$i} . "\"" .
                          " h$current_heading_level " . String_Value("at") .
                          String_Value("line:column") .
                          $$parent_heading_location{$current_heading_level} .
                          " " . String_Value("and") . " h$i " .
                          String_Value("at") . String_Value("line:column") .
                          $$parent_heading_location{$i});
        }
    }
}

#***********************************************************************
#
# Name: Check_Peer_Heading_Values
#
# Parameters: heading_value - heading value
#             peer_heading_value - address of table of peer heading values
#             peer_heading_location - address of table of peer heading
#                                     locations
#
# Description:
#
#   This function checks peer heading values for a duplicate of this
# heading value.
#
#***********************************************************************
sub Check_Peer_Heading_Values {
    my ($heading_value, $peer_heading_value, $peer_heading_location) = @_;

    my ($i, $lc_heading_value, $heading_count, $peer_value, $peer_location);
    my ($current_location);

    #
    # Do we have heading text, skip duplicate heading check for
    # empty headings.
    #
    if ( $heading_value eq "" ) {
        print "Check_Peer_Heading_Values skip empty heading\n" if $debug;
        return;
    }

    #
    # Convert heading to lowercase to case before looking for duplicates
    #
    $lc_heading_value = lc($heading_value);

    #
    # Get current heading location
    #
    $peer_value = $$peer_heading_value{$current_heading_level};
    $peer_location = $$peer_heading_location{$current_heading_level};
    $heading_count = @$peer_location;
    $current_location = $$peer_location[$heading_count - 1];

    #
    # Check peer headings looking for a duplicate
    #
    for ($i = 0; $i < $heading_count; $i++) {
        print "Heading # $i at " . $$peer_location[$i] . 
              " value " . $$peer_value[$i] . "\n" if $debug;
        if ( defined($$peer_value[$i]) && 
             (lc($$peer_value[$i]) eq $lc_heading_value) ) {
            #
            # Duplicate heading value
            #
            print "Duplicate heading title \"$heading_value\" at " .
                  $$peer_location[$i] . " and " .
                  $current_location . "\n" if $debug;

            Record_Result("DUPLICATE_HEADINGS",
                          String_Value("Duplicate headings") . 
                          " h$current_heading_level " . 
                          "\"$heading_value\" " . String_Value("at") .
                          String_Value("line:column") .
                          $$peer_location[$i] .
                          " " . String_Value("and") .  " " .
                          String_Value("at") . String_Value("line:column") .
                          $current_location . "\n");
        }
    }
}

#***********************************************************************
#
# Name: End_H_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the end h tag, it saves the heading title
# and checks for duplicates.
#
#***********************************************************************
sub End_H_Tag_Handler {
    my ( $self, $tagname, $line, $column, $text ) = @_;

    my (@all_heading_text, $heading_title, $array, $subsection);
    my ($parent_heading_value, $parent_heading_location);
    my ($peer_heading_value, $peer_heading_location);

    #
    # Get all the text found within the heading tag
    #
    print "Content_Check:End_H_Tag_Handler\n" if $debug;
    if ( ! $have_text_handler ) {
        print "End heading tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }
    @all_heading_text = @{ $self->handler("text") };
    $heading_title = join("", @all_heading_text);

    #
    # Strip leading & trailing white space
    #
    $heading_title =~ s/^\s+//g;
    $heading_title =~ s/\s+$//g;
    print "End $tagname, title = \"$heading_title\"\n" if $debug;
 
    #
    # Get the current subsection name, if we don't have one assume it is
    # the content subsection.
    #
    $subsection = $content_section_handler->current_content_subsection;
    if ( $subsection eq "" ) {
        $subsection = "CONTENT";
    }

    #
    # Get parent and peer heading tables
    #
    if ( defined($parent_subsection_heading_value{$subsection}) ) {
        $parent_heading_value =  $parent_subsection_heading_value{$subsection};
        $parent_heading_location =  $parent_subsection_heading_location{$subsection};
        $peer_heading_value =  $peer_subsection_heading_value{$subsection};
        $peer_heading_location =  $peer_subsection_heading_location{$subsection};

        #
        # If we are at <h2> or greater, look for duplicates in our
        # parent's headings.
        #
        print "Check content heading\n" if $debug;
        if ( $current_heading_level > 1 ) {
            Check_Parent_Heading_Values($heading_title,
                                        $parent_heading_value,
                                        $parent_heading_location);
        }

        #
        # Check for duplicate peer level headings
        #
        Check_Peer_Heading_Values($heading_title,
                                  $peer_heading_value,
                                  $peer_heading_location);

        #
        # Save current heading value
        #
        $$parent_heading_value{$current_heading_level} = $heading_title;
        $array = $$peer_heading_value{$current_heading_level};
        push(@$array, "$heading_title");
        print "h$current_heading_level value $heading_title\n" if $debug;
    }

    #
    # Save heading if we are inside the content area
    #
    if ( $content_section_handler->current_content_subsection eq "CONTENT" ) {
        push(@content_headings, "$current_heading_level:$heading_title");
    }
    push(@all_headings, "$current_heading_level:$heading_title");

    #
    # Destroy the text handler that was used to save heading text
    #
    $self->handler( "text", undef );
    $have_text_handler = 0;
}

#***********************************************************************
#
# Name: Start_Title_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles title tags.
#
#***********************************************************************
sub Start_Title_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # We found a title tag.
    #
    print "Start_Title_Tag_Handler\n" if $debug;

    #
    # Add a text handler to save the text portion of the title
    # tag.
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
#   This function handles the end title tag.
#
#***********************************************************************
sub End_Title_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($attr, $protocol, $domain, $file_path, $query, $url);

    #
    # Get all the text found within the title tag
    #
    if ( ! $have_text_handler ) {
        print "End title tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }
    $title_text = join("", @{ $self->handler("text") });
    print "End_Title_Tag_Handler, title = \"$title_text\"\n" if $debug;

    #
    # Remove leading and trailing white space
    #
    $title_text =~ s/^\s*//g;
    $title_text =~ s/\s*$//g;

    #
    # Destroy the text handler that was used to save the text
    # portion of the title tag.
    #
    $self->handler( "text", undef );
    $have_text_handler = 0;
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
#   This function handles the meta tag, it looks for the dc.title metadata
# item.
#
#***********************************************************************
sub Meta_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    my ($name, $content);

    #
    # Look for name attribute
    #
    if ( defined($attr{"name"}) ) {
        $name = $attr{"name"};
        print "Meta_Tag_Handler: Check metadata tag $name\n" if $debug;

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
        # Additional content checks for specific metadata tags
        #
        if ( $name eq "dc.title" ) {
            #
            # dc.title metadata tag, save value.
            #
            $dc_title_text = $content;
        }
        elsif ( $name eq "dcterms.title" ) {
            #
            # dcterms.title metadata tag, save value.
            #
            $dcterms_title_text = $content;
        }
    }
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
    my ( $self, $tagname, $line, $column, $text, @attr ) =
      @_;

    my (%attr_hash) = @attr;

    #
    # Create a new tag object
    #
    $current_tag_object = tqa_tag_object->new($tagname, $line, $column,
                                              \%attr_hash);
    push(@tag_order_stack, $current_tag_object);

    #
    # Compute the current landmark and add it to the tag object.
    #
    ($current_landmark, $landmark_marker) = HTML_Landmark($tagname, $line,
                       $column, $current_landmark, $landmark_marker,
                       \@tag_order_stack, %attr_hash);
    $current_tag_object->landmark($current_landmark);
    $current_tag_object->landmark_marker($landmark_marker);

    #
    # Check html tag
    #
    if ( $tagname eq "html" ) {
        HTML_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check h tag
    #
    elsif ( $tagname =~ /^h[0-9]?$/ ) {
        Start_H_Tag_Handler($self, $tagname, $line, $column, $text, %attr_hash);
    }

    #
    # Check for meta tag
    #
    elsif ( $tagname eq "meta" ) {
        Meta_Tag_Handler( $line, $column, $text, %attr_hash );
    }

    #
    # Check title tag
    #
    elsif ( $tagname eq "title" ) {
        Start_Title_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check for start of content section
    #
    $content_section_handler->check_start_tag($tagname, $line, $column,
                                              %attr_hash);
    
    #
    # Did we find the content area ?
    #
    if ( $content_section_handler->current_content_section eq "CONTENT" ) {
        $found_content_section = 1;
    }

    #
    # Is this a tag that has no end tag ? If so we must set the last tag
    # seen value here rather than in the End_Handler function.
    #
    if ( defined ($html_tags_with_no_end_tag{$tagname}) ) {
        $current_tag_object = pop(@tag_order_stack);
        $current_landmark = $current_tag_object->landmark();
        $landmark_marker = $current_tag_object->landmark_marker();
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
    my ( $self, $tagname, $line, $column, $text, @attr ) = @_;

    my (%attr_hash) = @attr;
    my ($last_item);

    #
    # Check heading tag
    #
    if ( $tagname =~ /^h[0-9]?$/ ) {
        End_H_Tag_Handler($self, $tagname, $line, $column, $text);
    }

    #
    # Check title tag
    #
    elsif ( $tagname eq "title" ) {
        End_Title_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Is this the end of a content area ?
    #
    $content_section_handler->check_end_tag($tagname, $line, $column);

    #
    # Pop last tag of the stack
    #
    if ( @tag_order_stack > 0 ) {
        $current_tag_object = pop(@tag_order_stack);
        if ( @tag_order_stack > 0 ) {
            $last_item = @tag_order_stack - 1;
            $current_tag_object = $tag_order_stack[$last_item];
            $current_landmark = $current_tag_object->landmark();
            $landmark_marker = $current_tag_object->landmark_marker();
        }
        else {
            $current_landmark = "";
            $landmark_marker = "";
        }
    }
    else {
        $current_landmark = "";
        $landmark_marker = "";
    }
}

#***********************************************************************
#
# Name: Check_Content_Language
#
# Parameters: this_url - document URL
#             mime_type - mime type
#             content - content pointer
#
# Description:
#
#   This function checks that the content language matches either
# the URL language (e.g. -eng or -fra in URL) or the HTML tag
# language (HTML files only).
#
#***********************************************************************
sub Check_Content_Language {
    my ($this_url, $mime_type, $content) = @_;

    my ($url_language, $content_language, $lang, $lang_code, $status);
    my ($pdf_content);

    #
    # Are we checking content language in this testcase profile ?
    #
    if ( defined($$current_testcase_profile{"CONTENT_URL_LANGUAGE"}) ) {
        #
        # Testcase has been executed.
        #
        print "Check_Content_Language\n" if $debug;

        #
        # Determine the URL's language (-eng, -fra, etc).
        #
        $url_language = URL_Check_GET_URL_Language($this_url);

        #
        # If the URL language is unknown, and it is an HTML document,
        # use the language from the <html> tag.
        #
        if ( ($url_language eq "") &&
             ($mime_type =~ /text\/html/) ) {
            $url_language = $html_lang;
        }

        #
        # If the URL language is known, compare it to the content
        # language
        #
        if ( $url_language ne "" ) {
            #
            # Initialize language to unknown.
            #
            $lang = "";

            #
            # Do we have text/html mime type ?
            #
            if ( $mime_type =~ /text\/html/ ) {
                #
                # Determine language of HTML content.
                #
                print "Get language of HTML content\n" if $debug;
                ($lang_code, $lang, $status) = TextCat_HTML_Language($content);
            }
            #
            # Do we have application/pdf mime type ?
            #
            elsif ( $mime_type =~ /application\/pdf/ ) {
                #
                # Extract text from PDF content and determine its language
                #
                print "Convert PDF to text\n" if $debug;
                $pdf_content = PDF_Files_PDF_Content_To_Text($content);
                ($lang_code, $lang, $status) = TextCat_Text_Language(\$pdf_content);
            }
            #
            # Do we have text/text mime type ?
            #
            elsif ( $mime_type =~ /text\/plain/ ) {
                #
                # Determine language of  text content
                #
                print "Get language of Text content\n" if $debug;
                ($lang_code, $lang, $status) = TextCat_Text_Language($content);
            }
            else {
            }
            print "TextCat language = $lang\n" if $debug;

            #
            # If we have a content language, compare it to the URL or HTML
            # tag language.
            #
            if ( $lang_code ne "" ) {
                if ( $url_language ne $lang_code ) {
                    Record_Result("CONTENT_URL_LANGUAGE",
                                  String_Value("Content language") .
                                  $lang_code . 
                                  String_Value("does not match URL language")
                                  . $url_language);
                    print "Content language $lang_code does not match URL language $url_language\n" if $debug;
                }
            }
            else {
                #
                # Could not determine content language.
                # Record this as a warning to trigger a manual check.
                #
                if ( defined($$current_testcase_profile{"CONTENT_URL_LANGUAGE_WARNING"}) ) {
                    print "Unable to determine content language\n" if $debug;
                    if ( $status == -1 ) {
                        Record_Result("CONTENT_URL_LANGUAGE_WARNING",
                          String_Value("Insufficient content to determine language"));
                    }
                    elsif ( $status == -2 ) {
                        Record_Result("CONTENT_URL_LANGUAGE_WARNING",
                          String_Value("Unable to determine content language"));
                    }
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: HTML_Content_Check
#
# Parameters: content - content pointer
#
# Description:
#
#   This function runs a number of content QA checks the HTML content.
#
#***********************************************************************
sub HTML_Content_Check {
    my ($content) = @_; 

    my ($parser);

    #
    # Create a document parser
    #
    print "HTML_Content_Check\n" if $debug;
    $parser = HTML::Parser->new;

    #
    # Create a content section object
    #
    if ( ! defined($content_section_handler) ) {
        $content_section_handler = content_sections->new;
    }
    
    #
    # Initialize language to unknown
    #
    $html_lang = "";
    undef %inside_html_tag;
    @tag_order_stack = ();
    $current_landmark = "";
    $landmark_marker = "";

    #
    # Add handlers for some of the HTML tags
    #
    $parser->handler(
        start => \&Start_Handler, "self,tagname,line,column,text,\@attr"
    );
    $parser->handler(
        end => \&End_Handler, "self,tagname,line,column,text,\@attr"
    );
    
    #
    # Parse the content.
    #
    $parser->parse($$content);
}

#***********************************************************************
#
# Name: Content_Check
#
# Parameters: this_url - a URL
#             profile - testcase profile
#             mime_type - mime type of document
#             content - content pointer
#
# Description:
#
#   This function runs a number of content QA checks the content.
#
#***********************************************************************
sub Content_Check {
    my ($this_url, $profile, $mime_type, $content) = @_;

    my (@content_results_list, $result_object, $testcase);

    #
    # Do we have a valid profile ?
    #
    print "Content_Check: Checking URL $this_url, mime type = $mime_type, profile = $profile\n" if $debug;
    if ( ! defined($content_check_profile_map{$profile}) ) {
        print "Content_Check: Unknown Content Check testcase profile passed $profile\n";
        return(@content_results_list);
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@content_results_list);
    $current_url = $this_url;

    #
    # Check mime-type, skip check if we don't handle a particular type.
    #
    if ( ($mime_type eq "text/html") ||
         ($mime_type eq "text/plain") ||
         ($mime_type eq "application/pdf") ) {

        #
        # Did we get any content ?
        #
        if ( length($$content) > 0 ) {
            #
            # Which content type do we have ?
            #
            if ( $mime_type =~ /text\/html/ ) {
                #
                # HTML/XHTML content
                #
                HTML_Content_Check($content);

                #
                # Check title and dc.title
                #
                Check_Title_DC_Title_Match();

                #
                # Check title and dcterms.title
                #
                Check_Title_DCTERMS_Title_Match();
            }

            #
            # Check content and URL languages
            #
            Check_Content_Language($this_url, $mime_type, $content);
        }
        else {
            print "No content passed to Content_Check\n" if $debug;
        }

        #
        # Print testcase information
        #
        if ( $debug ) {
            print "Content_Check results\n";
            foreach $result_object (@content_results_list) {
                print "Testcase: " . $result_object->testcase;
                print "  status   = " . $result_object->status . "\n";
                print "  message  = " . $result_object->message . "\n";
            }
        }
    }
    else {
        #
        # Unsupported mime-type
        #
        print "Unsupported mime-type, ignore content.\n" if $debug;
    }

    #
    # Return list of results
    #
    return(@content_results_list);
}

#***********************************************************************
#
# Name: Content_Check_HTML_PDF_Titles
#
# Parameters: html_titles - address of hash table
#             pdf_titles - address of hash table
#             profile - testcase profile
#
# Description:
#
#   This function compares the title of PDF documents against their
# HTML equivalents.  The equivalents are determined by the URL, the
# same path & file name with different file suffix.  It returns a
# hash table indexed by "html_url\npdf_url" with the value of
# "html_title\npdf_title".
#
#***********************************************************************
sub Content_Check_HTML_PDF_Titles {
    my ($html_titles, $pdf_titles, $profile) = @_;

    my ($pdf_url, $pdf_title, $html_url_base, $html_url, $html_suffix);
    my ($html_title, @content_results_list);
    
    #
    # Do we have a valid profile ?
    #
    print "Content_Check_HTML_PDF_Titles profile = $profile\n" if $debug;
    if ( ! defined($content_check_profile_map{$profile}) ) {
        print "Content_Check_HTML_PDF_Titles: Unknown Content Check testcase profile passed $profile\n";
        return(@content_results_list);
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@content_results_list);

    #
    # Are we checking for HTML/PDF title mismatch ?
    #
    if ( defined($$current_testcase_profile{"HTML_PDF_TITLE"}) ) {
        #
        # Look through the list of PDF URLs, usually there are fewer PDF
        # documents in a site than HTML documents, so it should be the
        # shorter list.
        #
        while ( ($pdf_url, $pdf_title) = each %$pdf_titles ) {
            #
            # Copy PDF url to HTML url and strip off trailing PDF or pdf 
            # suffix.
            #
            $html_url_base = $pdf_url;
            $html_url_base =~ s/\.pdf$//gi;

            #
            # Convert special characters into entities 
            #
            $pdf_title = decode_entities($pdf_title);
            $pdf_title = encode_entities($pdf_title);

            #
            # Loop through list of possible HTML file suffixes
            # looking for a match in the html_title hash table.
            #
            print "Checking PDF URL $pdf_url\n" if $debug;
            $current_url = $pdf_url;
            foreach $html_suffix (@html_suffix_list) {
                #
                # Do we have a match on the HTML url ?
                #
                $html_url = $html_url_base . $html_suffix;
                print "Checking HTML URL $html_url\n" if $debug;
                if ( defined($$html_titles{$html_url}) ) {
                    #
                    # Convert special characters into entities
                    #
                    $html_title = $$html_titles{$html_url};
                    $html_title = decode_entities($html_title);
                    $html_title = encode_entities($html_title);
                    print "Found HTML URL $html_url\n" if $debug;

                    #
                    # Check for title mismatch
                    #
                    print "PDF title  = \"$pdf_title\"\n" if $debug;
                    print "HTML title = \"$html_title\"\n" if $debug;
                    if ( $html_title ne $pdf_title ) {
                        #
                        # Title mismatch.
                        #
                        Record_Result("HTML_PDF_TITLE",
                                      String_Value("Title mismatch") .
                                      " HTML: \"$html_title\" $html_url\n" .
                                      " PDF: \"$pdf_title\" $pdf_url\n");

                        if ( $debug ) {
                            print "HTML/PDF Title mismatch\n";
                            print "  HTML url = $html_url\n";
                            print "  PDF url  = $pdf_url\n";
                            print " HTML title = \"$html_title\"";
                            print " PDF title  = \"$pdf_title\"";
                        }
                    }

                    #
                    # Stop looking for HTML urls, there will be only 1
                    #
                    last;
                }
            }
        }
    }

    #
    # Return result objects
    #
    return(@content_results_list);
}

#***********************************************************************
#
# Name: Content_Check_Unique_Titles
#
# Parameters: url_title_map - address of hash table
#             profile - testcase profile
#
# Description:
#
#   This function checks the title of documents to see if there are
# any duplicates.
#
#***********************************************************************
sub Content_Check_Unique_Titles {
    my ($url_title_map, $profile) = @_;

    my ($url, $title, %title_url_map, @content_results_list);
    my (%duplicate_titles, $url_list, @list);

    #
    # Do we have a valid profile ?
    #
    print "Content_Check_Unique_Titles profile = $profile\n" if $debug;
    if ( ! defined($content_check_profile_map{$profile}) ) {
        print "Content_Check_Unique_Titles: Unknown Content Check testcase profile passed $profile\n";
        return(@content_results_list);
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@content_results_list);

    #
    # Are we checking for duplicate titles ?
    #
    if ( defined($$current_testcase_profile{"DUPLICATE_TITLES"}) ) {
        #
        # Process each URL in the hash table
        #
        while ( ($url, $title) = each %$url_title_map ) {
            #
            # Strip off any leading or trailing white space as this is
            # not significant.
            #
            $title =~ s/\n/ /g;
            $title =~ s/^\s*//g;
            $title =~ s/\s*$//g;
            print "Check document title \"$title\"\n" if $debug;

            #
            # Have we seen this title before ?
            #
            if ( defined($title_url_map{$title}) ) {
                #
                # Is this the first occurance of a duplicate for this title ?
                #
                if ( ! defined($duplicate_titles{$title}) ) {
                    #
                    # Save first URL with this title
                    #
                    $duplicate_titles{$title} = $title_url_map{$title};
                }

                #
                # Save duplicate URL. Use \n to seperate the URLs.
                #
                $duplicate_titles{$title} .= "\n$url";
                print "Duplicate title \"$title\"\n" if $debug;
                print "URL list = " . $duplicate_titles{$title} . "\n" if $debug;
            }
            else {
                #
                # Save title and URL in title/url map
                #
                $title_url_map{$title} = $url;
            }
        }
        
        #
        # Did we find any duplicates ?
        #
        while ( ($title, $url_list) = each %duplicate_titles ) {
            #
            # Ignore empty titles, this would have been reported
            # under accessibility (WCAG 2.0) checking.
            #
            if ( $title ne "" ) {
                #
                # Take first URL from the list as the one to report the
                # error against.
                #
                @list = split(/\n/, $url_list);
                $current_url = $list[0];
                Record_Result("DUPLICATE_TITLES",
                              String_Value("Duplicate title") .
                              " \"$title\" " .
                              String_Value("in") . " URLs $url_list");
            }
        }
    }

    #
    # Return list of result objects
    #
    return(@content_results_list);
}

#***********************************************************************
#
# Name: Check_Title_DC_Title_Match
#
# Parameters: none
#
# Description:
#
#   This function compares the title and dc.title of the document
# to see that they match.
#
#***********************************************************************
sub Check_Title_DC_Title_Match {

    my ($conv_html_title, $conv_dc_title);

    #
    # Do we have a dc.title value ?
    #
    if ( $dc_title_text eq "" ) {
        return;
    }

    #
    # Strip off any leading or trailing white space from both
    # titles before we compare them
    #
    $title_text =~ s/\n/ /g;
    $title_text =~ s/^\s+//g;
    $title_text =~ s/\s+$//g;
    $dc_title_text =~ s/\n/ /g;
    $dc_title_text =~ s/^\s+//g;
    $dc_title_text =~ s/\s+$//g;

    #
    # Convert any special characters into HTML entities before
    # the compare.
    #
    $conv_html_title =  decode_entities($title_text);
    $conv_html_title =  encode_entities($conv_html_title);
    $conv_dc_title =  decode_entities($dc_title_text);
    $conv_dc_title =  encode_entities($conv_dc_title);

    #
    # Check for title mismatch
    #
    print "HTML title = \"$conv_html_title\"\n" if $debug;
    print "dc.title  = \"$conv_dc_title\"\n" if $debug;
    if ( lc($conv_html_title) ne lc($conv_dc_title) ) {
        #
        # Check to see if the dc.title is a substing of the title.
        # Sometimes the title includes a departmental name
        #  e.g. title = Public Services and Procurement Canada - Canada.ca
        #    dc.title = Public Services and Procurement Canada
        #
        if ( index($conv_html_title, $conv_dc_title) != 0 ) {
            #
            # Title mismatch.
            #
            Record_Result("TITLE_DC_TITLE_MATCH",
                          String_Value("Title/dc.title mismatch") .
                          " title \"$title_text\" " .
                          " dc.title \"$dc_title_text\" ");
        }
    }
}

#***********************************************************************
#
# Name: Check_Title_DCTERMS_Title_Match
#
# Parameters: none
#
# Description:
#
#   This function compares the title and dcterms.title of the document
# to see that they match.
#
#***********************************************************************
sub Check_Title_DCTERMS_Title_Match {

    my ($conv_html_title, $conv_dc_title);

    #
    # Do we have a dcterms.title value ?
    #
    if ( $dcterms_title_text eq "" ) {
        return;
    }

    #
    # Strip off any leading or trailing white space from both
    # titles before we compare them
    #
    $title_text =~ s/\n/ /g;
    $title_text =~ s/^\s+//g;
    $title_text =~ s/\s+$//g;
    $dcterms_title_text =~ s/\n/ /g;
    $dcterms_title_text =~ s/^\s+//g;
    $dcterms_title_text =~ s/\s+$//g;

    #
    # Convert any special characters into HTML entities before
    # the compare.
    #
    $conv_html_title =  decode_entities($title_text);
    $conv_html_title =  encode_entities($conv_html_title);
    $conv_dc_title =  decode_entities($dcterms_title_text);
    $conv_dc_title =  encode_entities($conv_dc_title);

    #
    # Check for title mismatch
    #
    print "HTML title = \"$conv_html_title\"\n" if $debug;
    print "dcterms.title  = \"$conv_dc_title\"\n" if $debug;
    if ( lc($conv_html_title) ne lc($conv_dc_title) ) {
        #
        # Title mismatch.
        #
        Record_Result("TITLE_DCTERMS_TITLE_MATCH",
                      String_Value("Title/dcterms.title mismatch") .
                      " title \"$title_text\" " .
                      " dcterms.title \"$dcterms_title_text\" ");
    }
}

#**********************************************************************
#
# Name: Content_Check_Testcase_URL
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase URL 
# table for the specified key.
#
#**********************************************************************
sub Content_Check_Testcase_URL {
    my ($key) = @_;

    #
    # Do we have a string table entry for this key ?
    #
    print "Content_Check_Testcase_URL, key = $key\n" if $debug;
    if ( defined($$url_table{$key}) ) {
        #
        # return value
        #
        print "value = " . $$url_table{$key} . "\n" if $debug;
        return ($$url_table{$key});
    }
    #
    # Was the testcase description provided rather than the testcase
    # identifier ?
    #
    elsif ( defined($$reverse_testcase_description_table{$key}) ) {
        #
        # return value
        #
        $key = $$reverse_testcase_description_table{$key};
        print "value = " . $$url_table{$key} . "\n" if $debug;
        return ($$url_table{$key});
    }
    else {
        #
        # No string table entry, either we are missing a string or
        # we have a typo in the key name.
        #
        return;
    }
}

#**********************************************************************
#
# Name: Content_Check_Read_URL_Help_File
#
# Parameters: filename - path to help file
#
# Description:
#
#   This function reads a testcase help file.  The file contains
# a list of testcases and the URL of a help page or standard that
# relates to the testcase.  A language field allows for English & French
# URLs for the testcase.
#
#**********************************************************************
sub Content_Check_Read_URL_Help_File {
    my ($filename) = @_;

    my (@fields, $tcid, $lang, $url);

    #
    # Clear out any existing testcase/url information
    #
    %testcase_url_en = ();
    %testcase_url_fr = ();

    #
    # Check to see that the help file exists
    #
    if ( !-f "$filename" ) {
        print "Error: Missing URL help file\n" if $debug;
        print " --> $filename\n" if $debug;
        return;
    }

    #
    # Open configuration file at specified path
    #
    print "Content_Check_Read_URL_Help_File Openning file $filename\n" if $debug;
    if ( ! open(HELP_FILE, "$filename") ) {
        print "Failed to open file\n" if $debug;
        return;
    }

    #
    # Read file looking for testcase, language and URL
    #
    while (<HELP_FILE>) {
        #
        # Ignore comment and blank lines.
        #
        chop;
        if ( /^#/ ) {
            next;
        }
        elsif ( /^$/ ) {
            next;
        }

        #
        # Split the line into fields.
        #
        @fields = split(/\s+/, $_, 3);

        #
        # Did we get 3 fields ?
        #
        if ( @fields == 3 ) {
            $tcid = $fields[0];
            $lang = $fields[1];
            $url  = $fields[2];
            print "Add Testcase/URL mapping $tcid, $lang, $url\n" if $debug;

            #
            # Do we have an English URL ?
            #
            if ( $lang =~ /eng/i ) {
                $testcase_url_en{$tcid} = $url;
                $reverse_testcase_description_en{$url} = $tcid;
            }
            #
            # Do we have a French URL ?
            #
            elsif ( $lang =~ /fra/i ) {
                $testcase_url_fr{$tcid} = $url;
                $reverse_testcase_description_fr{$url} = $tcid;
            }
            else {
                print "Unknown language $lang\n" if $debug;
            }
        }
        else {
            print "Line does not contain 3 fields, ignored: \"$_\"\n" if $debug;
        }
    }
    
    #
    # Close configuration file
    #
    close(HELP_FILE);
}

#********************************************************
#
# Name: Text_Handler
#
# Parameters: text - text string
#
# Description:
#
#   This appends the supplied text to the content string
# if we are inside the content area.
#
#********************************************************
sub Text_Handler {
    my ($text) = @_;
    
    my ($current_section);

    #
    # Are we inside a content section ?
    #
    $current_section = $content_section_handler->current_content_subsection;
    if ( $current_section ne "" ) {
        #
        # Are we outside of a script or style tag ?
        #
        if ( ! ($inside_html_tag{"script"} || $inside_html_tag{"style"}) ) {
            $subsection_text{$current_section} .= $text;
        }
        else {
            print "Text inside of script/style\n" if $debug;
        }
    }
}

#********************************************************
#
# Name: Start_Tag_Handler
#
# Parameters: tag - tag name
#             line - line number
#             column - column number
#             attr - hash table of attributes
#
# Description:
#
#   This updates the global inside_html_tag table to indicate
# whether or not we are inside a tag start/end pair.  It also
# checks for the beginning of a document section (e.g. content,
# footer) if the tag is a <div> tag.
#
#********************************************************
sub Start_Tag_Handler {
    my ($tag, $line, $column, %attr) = @_;

    my ($class_name, $class_list, $list_addr, $section_div);
    my ($current_section);

    #
    # Increment tag setting.
    #
    $inside_html_tag{$tag}++;

    #
    # Are we inside a content section ?
    #
    $current_section = $content_section_handler->current_content_subsection;
    if ( $current_section ne "" ) {
        #
        # Add white space to content string since tags could
        # be used as word seperators.
        #
        $subsection_text{$current_section} .= " ";

        #
        # We may need to add a newline to get
        # a break in text (e.g. start of heading, start of paragraph).
        #
        if ( index($line_break_before_tags, " $tag ") != -1 ) {
            $subsection_text{$current_section} .= "\n";
        }
    }

    #
    # Check for start of content section
    #
    $content_section_handler->check_start_tag($tag, $line, $column,
                                              %attr);
}

#********************************************************
#
# Name: End_Tag_Handler
#
# Parameters: tag - tag name
#             line - line number
#             column - column number
#
# Description:
#
#   This updates the global inside_html_tag table to indicate
# whether or not we are inside a tag start/end pair.  It also
# checks for the ending of a document section (e.g. content,
# footer) if the tag is a <div> tag.
#
#********************************************************
sub End_Tag_Handler {
    my ($tag, $line, $column) = @_;
    
    my ($current_section);

    #
    # Decrement tag setting.
    #
    if ( $inside_html_tag{$tag} > 0 ) {
        $inside_html_tag{$tag}--;
    }

    #
    # Are we inside a content section ?
    #
    $current_section = $content_section_handler->current_content_subsection;
    if ( $current_section ne "" ) {
        #
        # Add white space to content string since tags could
        # be used as word seperators.
        #
        $subsection_text{$current_section} .= " ";

        #
        # We may need to add a newline to get
        # a break in text (e.g. end of heading, end of paragraph).
        #
        if ( index($line_break_after_tags, " $tag ") != -1 ) {
            $subsection_text{$current_section} .= "\n";
        }
    }

    #
    # Is this the end of a content area ?
    #
    $content_section_handler->check_end_tag($tag, $line, $column);
}

#********************************************************
#
# Name: Content_Check_Extract_Content_From_HTML
#
# Parameters: content - pointer to content
#
# Description:
#
#   This function extracts text from the content area of HTML text.
# The content area is expected to be delimited by marker comments, id,
# CSS class or role values, .
#
# Returns:
#
#  text
#
#********************************************************
sub Content_Check_Extract_Content_From_HTML {
    my ($content) = @_;

    my ($parser, $text, $section, $subsection, $html_input);

    #
    # Initialize global variables.
    #
    print "Content_Check_Extract_Content_From_HTML\n" if $debug;
    foreach $section (Content_Section_Names()) {
        foreach $subsection (Content_Subsection_Names($section)) {
            $subsection_text{$subsection} = "";
        }
    }
    undef %inside_html_tag;
    
    #
    # Create a parser to parse the HTML content.
    #
    print "Create parser object\n" if $debug;
    $parser = HTML::Parser->new;

    #
    # Add handlers for some of the HTML tags
    #
    $parser->handler(
        text => \&Text_Handler, "dtext"
    );
    $parser->handler(
        start => \&Start_Tag_Handler, "tagname,line,column,\@attr");
    $parser->handler(
        end => \&End_Tag_Handler, "tagname,line,column");

    #
    # Create a content section object
    #
    $content_section_handler = content_sections->new;

    #
    # Parse the HTML to extract the text
    #
    $html_input = $$content;
    $html_input =~ s/\n/ /g;
    print "Parse the HTML content\n" if $debug;
    $parser->parse($html_input);

    #
    # Convert multiple whitespaces into a single whitespace
    #
    while ( ($section, $text) = each %subsection_text ) {
        #
        # If the initial text is an empty string, we did not find
        # any text for this subsection. Remove it from the hash table.
        #
        if ( $text eq "" ) {
            delete $subsection_text{$section};
        }
        else {
            #
            # Compress white space.
            #
            $text =~ s/[ \t]+/ /g;
            $subsection_text{$section} = $text;
        }
    }

    #
    # Return content section text.
    #
    if ( defined($subsection_text{"CONTENT"}) ) {
        print "Return CONTENT section\n" if $debug;
        return($subsection_text{"CONTENT"});
    }
    else {
        print "Return empty string, no CONTENT section found\n" if $debug;
        return("");
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

