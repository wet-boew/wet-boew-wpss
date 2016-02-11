#***********************************************************************
#
# Name:   interop_xml_check.pm
#
# $Revision: 6743 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Interop_Check/Tools/interop_xml_check.pm $
# $Date: 2014-07-25 14:57:36 -0400 (Fri, 25 Jul 2014) $
#
# Description:
#
#   This file contains routines that parse XML (web feed) files and check for
# a number of Standard on Web Usability check points.
#
# Public functions:
#     Set_Interop_XML_Check_Language
#     Set_Interop_XML_Check_Debug
#     Set_Interop_XML_Check_Testcase_Data
#     Set_Interop_XML_Check_Test_Profile
#     Interop_XML_Check
#     Interop_XML_Feed_Details
#     Interop_XML_Check_Feeds
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

package interop_xml_check;

use strict;
use XML::Parser;
use File::Basename;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Set_Interop_XML_Check_Language
                  Set_Interop_XML_Check_Debug
                  Set_Interop_XML_Check_Testcase_Data
                  Set_Interop_XML_Check_Test_Profile
                  Interop_XML_Check
                  Interop_XML_Feed_Details
                  Interop_XML_Check_Feeds
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (%testcase_data);
my (@paths, $this_path, $program_dir, $program_name, $paths);

my ($current_interop_check_profile, $current_url);
my ($results_list_addr);
my ($charset, $charset_text, %entry_id_values, %feed_id_values);
my ($feed_type, $in_entry, $in_item, $saved_text, $save_text_between_tags);
my (%news_feed_found_tags, %news_entry_found_tags, $in_feed, $in_rss);
my ($feed_title, $entry_title, $feed_lang, $entry_html_link);
my ($entry_updated, $entry_published, $entry_uri, $entry_id, $entry_author);
my ($feed_updated, $feed_uri, $feed_id, $feed_self_link);
my ($in_author, $feed_html_link, $feed_author, $entry_count);

#
# Create an empty profile that is used when we only want to extract
# news feed details.
#
my (%empty_hash) =();
my (%interop_check_profile_map) = (
  "", \%empty_hash,
);

my ($max_error_message_string) = 2048;

#
# Status values
#
my ($check_fail)       = 1;

#
# Required news feed tags
#
my (%news_feed_required_tags) = (
    "author",     0,
    "feed",       0,
    "icon",       0,
    "id",         0,
    "link",       0,
    "logo",       0,
    "name",       0,
    "rights",     0,
    "title",      0,
    "updated",    0,
    "uri",        0,
);

#
# Required news feed tags
#
my (%news_entry_required_tags) = (
    "author",     0,
    "entry",      0,
    "id",         0,
    "link",       0,
    "name",       0,
    "published",  0,
    "rights",     0,
    "title",      0,
    "updated",    0,
    "uri",        0,
);

#
# String table for error strings.
#
my %string_table_en = (
    "Encoding is not UTF-8",     "Encoding is not UTF-8",
    "Missing tags in",           "Missing tags in",
    "title",                     "title",
    "tags",                      "tags",
    "No Atom Web feed found with title", "No Atom Web feed found with title",
    "Missing href attribute for", "Missing 'href' attribute for",
    "href does not match URL in", "'href' does not match URL in",
    "Missing xml:lang attribute for", "Missing 'xml:lang' attribute for",
    "Invalid URL in uri",         "Invalid URL in <uri>",
    "for",                        "for",
    "in",                         "in",
    "and",                        "and",
    "Missing text in",            "Missing text in",
    "Invalid content",            "Invalid content: ",
    "Year",                       "Year ",
    "out of range 1900-2100",     " out of range 1900-2100",
    "Month",                      "Month ",
    "out of range 1-12",          " out of range 1-12",
    "Date",                       "Date ",
    "out of range 1-31",          " out of range 1-31",
    "Date value",                 "Date value ",
    "not in YYYY-MM-DD format",   " not in YYYY-MM-DD format",
    "Missing href content for",   "Missing 'href' content for ",
    "Duplicate entry id",         "Duplicate <entry> <id>",
    "Duplicate feed id",          "Duplicate <feed> <id>",
    "previously found in",        "previously found in",
    "found in",                   "found in",
    "Values do not match for",    "Values do not match for",
    "uri values do not match for", "<uri> values do not match for",
    "Fails validation",            "Fails validation, see validation results for details.",
);

#
# String table for error strings (French).
#
my %string_table_fr = (
    "Encoding is not UTF-8",     "Encoding ne pas UTF-8",
    "Missing tags in",           "Balise manquantes pour <feed>",
    "title",                     "titre",
    "tags",                      "balise",
    "No Atom Web feed found with title", "Aucun flux Web Atom trouvé avec le titre",
    "Missing href attribute for", "Attribut 'href' manquant pour",
    "href does not match URL in", "'href' ne correspond pas à l'adresse URL dans",
    "Missing xml:lang attribute for", "Attribut 'xml:lang' manquant pour",
    "Invalid URL in uri",         "URL non valide dans <uri>",
    "for",                        "pour",
    "in",                         "dans",
    "and",                        "et",
    "Missing text in",            "Texte manquant dans",
    "Invalid content",            "Contenu non valide: ",
    "Year",                       "Année ",
    "out of range 1900-2100",     " hors de portée 1900-2000",
    "Month",                      "Mois ",
    "out of range 1-12",          " hors de portée 1-12",
    "Date",                       "Date ",
    "out of range 1-31",          " hors de portée 1-31",
    "Date value",                 "Valeur à la date ",
    "not in YYYY-MM-DD format",   " pas au format AAAA-MM-DD",
    "Missing href content for",   "Le contenu de 'href' est manquant pour ",
    "Duplicate entry id",         "Doublon <id> dans <entry>",
    "Duplicate feed id",          "Doublon <id> dans <feed>",
    "previously found in",        "trouvé avant dans",
    "found in",                   "trouvé dans",
    "Values do not match for",    "Valeurs ne correspondent pas pour",
    "uri values do not match for", "Valeurs ne correspondent pas pour <uri>",
    "Fails validation",            "Échoue la validation, voir les résultats de validation pour plus de détails.",
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_Interop_XML_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Interop_XML_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;

    #
    # Set debug flag in supporting modules
    #
    XML_Feed_Object_Debug($this_debug);
}

#**********************************************************************
#
# Name: Set_Interop_XML_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Interop_XML_Check_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_Interop_XML_Check_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_Interop_XML_Check_Language, language = English\n" if $debug;
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
# Name: Set_Interop_XML_Check_Testcase_Data
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
sub Set_Interop_XML_Check_Testcase_Data {
    my ($testcase, $data) = @_;
    
}

#***********************************************************************
#
# Name: Set_Interop_XML_Check_Test_Profile
#
# Parameters: profile - TQA check test profile
#             interop_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by testcase name.
#
#***********************************************************************
sub Set_Interop_XML_Check_Test_Profile {
    my ($profile, $interop_checks ) = @_;

    my (%local_interop_checks);
    my ($key, $value);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Interop_XML_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_interop_checks = %$interop_checks;
    $interop_check_profile_map{$profile} = \%local_interop_checks;
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - TQA check test profile
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
    $charset = "";
    $feed_type = "";
    $feed_lang = "";
    $in_feed = 0;
    $in_rss = 0;
    $in_entry = 0;
    $in_item = 0;
    $save_text_between_tags = 0;
    $saved_text = "";
    %news_feed_found_tags = %news_feed_required_tags;
    undef($feed_uri);
    undef($feed_title);
    undef($feed_id);
    undef($feed_self_link);
    undef($feed_author);
    %entry_id_values = ();
    $entry_count = 0;
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
# Name: Check_Required_Feed_Tags
#
# Parameters: none
#
# Description:
#
#   This function checks to see that all required tags were found
# between the open & close feed tags.
#
#***********************************************************************
sub Check_Required_Feed_Tags {

    my ($tag);
    my ($tag_list) = "";
    
    #
    # Check each tag in the table
    #
    print "Check_Required_Feed_Tags\n" if $debug;
    foreach $tag (keys(%news_entry_found_tags)) {
        #
        # Is tag missing ?
        #
        if ( ! $news_entry_found_tags{$tag} ) {
            $tag_list .= "<$tag> ";
        }
    }
    
    #
    # Were there any missing tags ?
    #
    if ( $tag_list ne "" ) {
        Record_Result("SWI_B", -1, 0, "",
                      String_Value("Missing tags in") .
                      "  <feed> " . String_Value("tags") . " \"$tag_list\"");

    }
}

#***********************************************************************
#
# Name: Check_Required_Entry_Tags
#
# Parameters: title_text - entry title for error recording
#
# Description:
#
#   This function checks to see that all required tags were found
# between the open & close entry tags.
#
#***********************************************************************
sub Check_Required_Entry_Tags {
    my ($title_text) = @_;

    my ($tag);
    my ($tag_list) = "";

    #
    # Check each tag in the table
    #
    print "Check_Required_Entry_Tags\n" if $debug;
    foreach $tag (keys(%news_entry_found_tags)) {
        #
        # Is tag missing ?
        #
        if ( ! $news_entry_found_tags{$tag} ) {
            $tag_list .= "<$tag> ";
        }
    }

    #
    # Were there any missing tags ?
    #
    if ( $tag_list ne "" ) {
        Record_Result("SWI_B", -1, 0, "",
                      String_Value("Missing tags in") . " <entry> " .
                      $title_text . String_Value("tags") . " \"$tag_list\"");

    }
}

#***********************************************************************
#
# Name: Author_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <author> tag.
#
#***********************************************************************
sub Author_Tag_Handler {
    my ($self, $tagname, %attr) = @_;

    #
    # Inside <author> and </author>
    #
    $in_author = 1;
}

#***********************************************************************
#
# Name: Link_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <link> tag.  It checks if the rel attribute
# is "self", that the href attribute matches the feed URL.
#
#***********************************************************************
sub Link_Tag_Handler {
    my ($self, $tagname, %attr) = @_;

    my ($possible_html_link);

    #
    # Are we inside an entry ? This could be a link to the
    # HTML version of the content.
    #
    if ( $in_entry && defined($attr{"href"}) ) {
        #
        # Do we have an hreflang attribute and does it match the feed
        # language ?
        #
        $possible_html_link = 1;
        if ( defined($attr{"hreflang"}) &&
            ($attr{"hreflang"} ne $feed_lang) ) {
            #
            # This is not the HTML version of the entry.
            #
            $possible_html_link = 0;
        }

        #
        # Do we have a type attribute and is it "text/html" ?
        #
        if ( $possible_html_link && defined($attr{"type"}) &&
             ($attr{"type"} ne "text/html") ) {
            #
            # This is not the HTML version of the entry.
            #
            $possible_html_link = 0;
        }

        #
        # If this is a possible entry link, save the href value
        #
        if ( $possible_html_link ) {
            $entry_html_link = $attr{"href"};     
            print "Entry HTML link = $entry_html_link\n" if $debug;
        }
    }
    #
    # Are we inside a feed, but not in an entry ?
    #
    if ( $in_feed && (! $in_entry) ) {
        #
        #
        # Do we have a rel attribute with the value 'self' ?
        #
        if ( defined($attr{"rel"}) && ($attr{"rel"} eq "self") ) {
            if ( defined($attr{"href"}) ) {
                $feed_self_link = $attr{"href"};
            }
            else {
                $feed_self_link = "";
            }
        }
        #
        # Not a self link, see if it is an HTML alternate for the
        # feed.
        #
        else {
            #
            # Do we have an hreflang attribute and does it match the feed
            # language ?
            #
            $possible_html_link = 1;
            if ( defined($attr{"hreflang"}) &&
                ($attr{"hreflang"} ne $feed_lang) ) {
                #
                # This is not the HTML version of the feed.
                #
                $possible_html_link = 0;
            }

            #
            # Do we have a type attribute and is it "text/html" ?
            #
            if ( $possible_html_link && defined($attr{"type"}) &&
                 ($attr{"type"} ne "text/html") ) {
                #
                # This is not the HTML version of the feed.
                #
                $possible_html_link = 0;
            }

            #
            # If this is a possible feed link, save the href value
            #
            if ( $possible_html_link && defined($attr{"href"}) ) {
                $feed_html_link = $attr{"href"};
                print "Feed HTML link = $feed_html_link\n" if $debug;
            }
        }
    }
}

#***********************************************************************
#
# Name: Feed_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <feed> tag.  It sets the feed type,
# checks for an xml:lang attribute and initializes the required tag
# set.
#
#***********************************************************************
sub Feed_Tag_Handler {
    my ($self, $tagname, %attr) = @_;

    #
    # Inside a news <feed>. Set feed type.
    #
    if ( ! $in_feed ) {
        $in_feed = 1;
        print "Atom feed\n" if $debug;
        $feed_type = "atom";

        #
        # Get a blank copy of the required news feed required
        # tags table.
        #
        %news_feed_found_tags = %news_feed_required_tags;
    }

    #
    # Check for xml:lang attribute
    #
    if ( defined($attr{"xml:lang"}) ) {
        $feed_lang = $attr{"xml:lang"};
    }
    else {
        Record_Result("SWI_B", -1, 0, "",
                      String_Value("Missing xml:lang attribute for") .
                      " <feed>");
    }
}

#***********************************************************************
#
# Name: Entry_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <entry> tag.  It initializes the required tag
# set.
#
#***********************************************************************
sub Entry_Tag_Handler {
    my ($self, $tagname, %attr) = @_;

    #
    # Inside a news <entry>. Set entry type.
    #
    if ( (! $in_entry) && $in_feed ) {
        $in_entry = 1;

        #
        # Get a blank copy of the required news entry required
        # tags table.
        #
        %news_entry_found_tags = %news_entry_required_tags;
        
        #
        # Initialize entry attribute variables
        #
        undef($entry_title);
        undef($entry_html_link);
        undef($entry_uri);
        undef($entry_updated);
        undef($entry_published);
        undef($entry_id);
        undef($entry_author);
        $in_author = 0;
    }

    #
    # Increment entry counter
    #
    $entry_count++;
}

#***********************************************************************
#
# Name: ID_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <id> tag.
#
#***********************************************************************
sub ID_Tag_Handler {
    my ($self, $tagname, %attr) = @_;

    #
    # Save the text between <id> and </id>
    #
    $save_text_between_tags = 1;
    $saved_text = "";
}

#***********************************************************************
#
# Name: Name_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <name> tag.
#
#***********************************************************************
sub Name_Tag_Handler {
    my ($self, $tagname, %attr) = @_;

    #
    # Save the text between <name> and </name>
    #
    if ( $in_author ) {
        $save_text_between_tags = 1;
        $saved_text = "";
    }
}

#***********************************************************************
#
# Name: Published_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <published> tag.
#
#***********************************************************************
sub Published_Tag_Handler {
    my ($self, $tagname, %attr) = @_;

    #
    # Save the text between <published> and </published>
    #
    $save_text_between_tags = 1;
    $saved_text = "";
}

#***********************************************************************
#
# Name: RSS_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <rss> tag.  It sets the feed type.
#
#***********************************************************************
sub RSS_Tag_Handler {
    my ($self, $tagname, %attr) = @_;

    #
    # An RSS type feed.
    #
    print "RSS feed\n" if $debug;
    $feed_type = "rss";
    $in_rss = 1;
}

#***********************************************************************
#
# Name: Title_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <title> tag.
#
#***********************************************************************
sub Title_Tag_Handler {
    my ($self, $tagname, %attr) = @_;

    #
    # Save the text between <title> and </title>
    #
    $save_text_between_tags = 1;
    $saved_text = "";
}

#***********************************************************************
#
# Name: Updated_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <updated> tag.
#
#***********************************************************************
sub Updated_Tag_Handler {
    my ($self, $tagname, %attr) = @_;

    #
    # Save the text between <updated> and </updated>
    #
    $save_text_between_tags = 1;
    $saved_text = "";
}

#***********************************************************************
#
# Name: URI_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <uri> tag.
#
#***********************************************************************
sub URI_Tag_Handler {
    my ($self, $tagname, %attr) = @_;

    #
    # Save the text between <uri> and </uri>
    #
    $save_text_between_tags = 1;
    $saved_text = "";
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
    # Check for author tag.
    #
    print "Start_Handler tag $tagname\n" if $debug;
    if ( $tagname eq "author" ) {
        Author_Tag_Handler($self, $tagname, %attr);
    }
    #
    # Check for entry tag.
    #
    elsif ( $tagname eq "entry" ) {
        Entry_Tag_Handler($self, $tagname, %attr);
    }
    #
    # Check for feed tag, indicating this is an Atom feed.
    #
    elsif ( $tagname eq "feed" ) {
        Feed_Tag_Handler($self, $tagname, %attr);
    }
    #
    # Check for item tag (RSS feeds)
    #
    elsif ( $tagname eq "item" ) {
        if ( ! $in_item ) {
            #
            # We are inside an <item>
            #
            $in_item = 1;
        }
    }
    #
    # Check for id tag
    #
    elsif ( $tagname eq "id" ) {
        ID_Tag_Handler($self, $tagname, %attr);
    }
    #
    # Check for link tag
    #
    elsif ( $tagname eq "link" ) {
        Link_Tag_Handler($self, $tagname, %attr);
    }
    #
    # Check for name tag
    #
    elsif ( $tagname eq "name" ) {
        Name_Tag_Handler($self, $tagname, %attr);
    }
    #
    # Check for published tag
    #
    elsif ( $tagname eq "published" ) {
        Published_Tag_Handler($self, $tagname, %attr);
    }
    #
    # Check for rss tag, indicating this is an RSS feed.
    #
    elsif ( $tagname eq "rss" ) {
        RSS_Tag_Handler($self, $tagname, %attr);
    }
    #
    # Check for title tag
    #
    elsif ( $tagname eq "title" ) {
        Title_Tag_Handler($self, $tagname, %attr);
    }
    #
    # Check for updated tag
    #
    elsif ( $tagname eq "updated" ) {
        Updated_Tag_Handler($self, $tagname, %attr);
    }
    #
    # Check for uri tag
    #
    elsif ( $tagname eq "uri" ) {
        URI_Tag_Handler($self, $tagname, %attr);
    }
    
    #
    # Are we inside an <entry> and is this a required tag ?
    #
    if ( $in_entry && defined($news_entry_found_tags{$tagname}) ) {
        $news_entry_found_tags{$tagname} = 1;
    }
    #
    # Are we inside a <feed>, outside an <entry> and is this a required tag ?
    #
    elsif ( $in_feed && (! $in_entry) &&
            defined($news_feed_found_tags{$tagname}) ) {
        $news_feed_found_tags{$tagname} = 1;
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
    # Strip off any time specification, we only care about the date portion
    #
    $content =~ s/T.*$//g;

    #
    # Check for valid date format, ie dddd-dd-dd
    #
    if ( $content =~ /\d\d\d\d-\d\d-\d\d/ ) {
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
            $status = 1;
            $message = String_Value("Invalid content") .
                       String_Value("Year") . $fields[0] .
                       String_Value("out of range 1900-2100");
            print "$message\n" if $debug;
        }

        #
        # Check that the month is in the 01 to 12 range
        #
        elsif ( ( $fields[1] < 1 ) || ( $fields[1] > 12 ) ) {
            $status = 1;
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
            $status = 1;
            $message = String_Value("Invalid content") .
                       String_Value("Date") . $fields[0] .
                       String_Value("out of range 1-31");
            print "$message\n" if $debug;
        }

        #
        # Must have a well formed date.
        #
        else {
            $status = 0;
            $message= "";
        }
    }
    else {
        #
        # Invalid format
        #
        $status = 1;
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
# Name: Check_Entry_Date_Value
#
# Parameters: tagname - name of tag
#             content - content of tag
#             title_text - title text for error
#
# Description:
#
#   This function checks the format of a date value for an entry
#
#***********************************************************************
sub Check_Entry_Date_Value {
    my ($tagname, $content, $title_text) = @_;

    my ($status, $message);

    #
    # Do we have content to check ?
    #
    if ( defined($content) ) {
        #
        # Remove leading whitespace from content
        #
        $content =~ s/^\s*//g;

        #
        # Do we have any content ?
        #
        if ( $content eq "" ) {
            #
            # No date provided
            #
            Record_Result("SWI_B", -1, 0, "",
                          String_Value("Missing text in") .
                          " <$tagname> " .
                          String_Value("for") . " <entry> " . $title_text);
        }
        #
        # Does the text look like a date (YYYY-MM-DD) ?
        #
        else {
            ($status, $message) = Check_YYYY_MM_DD_Format($content);
            if ( $status == 1 ) {
                Record_Result("SWI_B", -1, 0, "",
                              "$message " . String_Value("in") .
                              " <$tagname> " .
                              String_Value("for") . " <entry> " . $title_text);
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Entry_Author_Value
#
# Parameters: author_text - author value
#             title_text - title of entry
#
# Description:
#
#   This function checks the value of the author attribute for entries.
#
#***********************************************************************
sub Check_Entry_Author_Value {
    my ($author_text, $title_text) = @_;

    #
    # Do we have an author value ?
    #
    if ( defined($author_text) ) {
        #
        # Is the value missing ?
        #
        if ( $author_text eq "" ) {
            print "Missing entry author value\n" if $debug;
            Record_Result("SWI_B", -1, 0, "",
                          String_Value("Missing text in") .
                          " <author> " . String_Value("in") .
                          " <entry> $title_text");
        }
    }
}

#***********************************************************************
#
# Name: Check_Entry_ID_Value
#
# Parameters: id_text - id value
#             title_text - title of entry
#
# Description:
#
#   This function checks the value of the ID attribute for entries.
#
#***********************************************************************
sub Check_Entry_ID_Value {
    my ($id_text, $title_text) = @_;

    #
    # Do we have an id value ?
    #
    if ( defined($id_text) ) {
        #
        # Is the value missing ?
        #
        if ( $id_text eq "" ) {
            print "Missing entry id value\n" if $debug;
            Record_Result("SWI_B", -1, 0, "",
                          String_Value("Missing text in") .
                          " <id> " . String_Value("in") .
                          " <entry> $title_text");
        }
        #
        # Have we seen this ID before ?
        #
        elsif ( defined($entry_id_values{$id_text}) &&
                ($title_text ne $entry_id_values{$id_text}) ) {
            print "Duplicate entry id $id_text\n" if $debug;
            Record_Result("SWI_B", -1, 0, "",
                          String_Value("Duplicate entry id") .
                          " \"$id_text\" " . String_Value("found in") .
                          " $title_text " . String_Value("and") . " " .
                          $entry_id_values{$id_text});
        }
        #
        # New id value, save it
        #
        else {
            $entry_id_values{$id_text} = $title_text;
            print "Entry id = $id_text\n" if $debug;
        }
    }
}

#***********************************************************************
#
# Name: Compare_Entry_Strings
#
# Parameters: string1 - string value
#             string2 - string value
#             tagname - name of tag
#             metadata - name of metadata tag
#             title_text - title of entry
#
# Description:
#
#   This function compares the value of 2 strings for an entry.
#
#***********************************************************************
sub Compare_Entry_Strings {
    my ($string1, $string2, $tagname, $metadata, $title_text) = @_;

    #
    # Are the strings not equal ?
    #
    if ( $string1 ne $string2 ) {
        Record_Result("SWI_B", -1, 0, "",
                      String_Value("Values do not match for") .
                      " <$tagname> \"$string1\" " . String_Value("and") .
                      " $metadata \"$string2\" " .
                      String_Value("in") . " <entry> \"$title_text\"");
    }
}

#***********************************************************************
#
# Name: Check_Entry_Link_Value
#
# Parameters: link_text - link value
#             title_text - title of entry for error messages
#             published - published value of entry
#             updated - updated value of entry
#             author - author value of entry
#             title - title value of entry
#
# Description:
#
#   This function checks the value of the link attribute for entries.
#
#***********************************************************************
sub Check_Entry_Link_Value {
    my ($link_text, $title_text, $published, $updated, $author, $title) = @_;
    
    my ($resp, $content, $resp_url, %metadata, $metadata_object);

    #
    # Do we have an link value ?
    #
    if ( defined($link_text) ) {
        #
        # Do we have  href content ?
        #
        if ( $link_text eq "" ) {
            Record_Result("SWI_B", -1, 0, "",
                          String_Value("Missing href content for") .
                          "<link> " . String_Value("in") .
                          " <entry> \"$title_text\"");
        }
        #
        # Does the href look like a URL ?
        #
        elsif ( $link_text =~ /^http[s]?:/i ) {
            #
            # Get the URL content
            #
            print "GET entry link href\n" if $debug;
            ($resp_url, $resp) = Crawler_Get_HTTP_Response($link_text, "");
            
            #
            # Was the GET successful ?
            #
            if ( $resp->is_success ) {
                #
                # Decode possible UTF-8 content
                #
                $content = Crawler_Decode_Content($resp);
                
                #
                # Extract metadata from content
                #
                %metadata = Extract_Metadata($link_text, \$content);
                
                #
                # If we have an author and dcterms.creator, check that they
                # match.
                #
                if ( defined($author) && defined($metadata{"dcterms.creator"}) ) {
                    $metadata_object = $metadata{"dcterms.creator"};
                    Compare_Entry_Strings($author, $metadata_object->content,
                                          "author", "dcterms.creator",
                                          $title_text);
                }
                
                #
                # If we have a published value and dcterms.issued, check
                # that they match.
                #
                if ( defined($published) && defined($metadata{"dcterms.issued"}) ) {
                    $published =~ s/T.*$//g;
                    $metadata_object = $metadata{"dcterms.issued"};
                    Compare_Entry_Strings($published, $metadata_object->content,
                                          "published", "dcterms.issued",
                                          $title_text);
                }

                #
                # If we have an updated value and dcterms.modified, check
                # that they match.
                #
                if ( defined($updated) && defined($metadata{"dcterms.modified"}) ) {
                    $updated =~ s/T.*$//g;
                    $metadata_object = $metadata{"dcterms.modified"};
                    Compare_Entry_Strings($updated, $metadata_object->content,
                                          "updated", "dcterms.modified",
                                          $title_text);
                }
                
                #
                # If we have a title and dcterms.title, check that they
                # match.
                #
                if ( defined($title) && defined($metadata{"dcterms.title"}) ) {
                    $metadata_object = $metadata{"dcterms.title"};
                    Compare_Entry_Strings($title, $metadata_object->content,
                                          "title", "dcterms.title",
                                          $title_text);
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_URI_Value
#
# Parameters: tagname - name of tag
#             uri_text - uri content
#             feed_uri_text - feed uri content
#             title_text - title of tagname
#
# Description:
#
#   This function checks the value of the URI attribute.
#
#***********************************************************************
sub Check_URI_Value {
    my ($tagname, $uri_text, $feed_uri, $title_text) = @_;

    my ($protocol, $domain, $file_path, $query, $url);

    #
    # Does the text look like a URL ?
    #
    if ( defined($uri_text) ) {
        ($protocol, $domain, $file_path, $query, $url) = URL_Check_Parse_URL($uri_text);
        if ( $url eq "" ) {
            Record_Result("SWI_B", -1, 0, "",
                          String_Value("Invalid URL in uri") .
                          " \"$uri_text\" " .
                          String_Value("for") . " <$tagname> " . $title_text);
        }
        else {
            #
            # Does the uri value match the feed uri value ?
            # If we are checking the actual feed uri, then uri_text
            # will match the feed_uri value.
            #
            if ( defined($feed_uri) && ($feed_uri ne "" ) &&
                 ($uri_text ne $feed_uri) ) {
                Record_Result("SWI_B", -1, 0, "",
                              String_Value("uri values do not match for") .
                              " <feed> \"$feed_uri\" " . String_Value("and") .
                              " <entry> \"$uri_text\" " .
                              String_Value("for") . " <entry> " . $title_text);
            }
        }
    }
}

#***********************************************************************
#
# Name: End_Entry_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the end <entry> tag.
#
#***********************************************************************
sub End_Entry_Tag_Handler {
    my ($self) = @_;
    
    my ($title_text);

    #
    # Are we inside an entry ?
    #
    if ( $in_entry ) {
        #
        # We are no longer inside an <entry>
        #
        $in_entry = 0;

        #
        # Check entry title
        #
        if ( defined($entry_title) && ($entry_title eq "") ) {
            Record_Result("SWI_B", -1, 0, "",
                          String_Value("Missing text in") .
                          " <entry> #$entry_count <title>");
            $title_text = " #$entry_count";
        }
        else {
            $title_text = " #$entry_count \"$entry_title\" ";
        }

        #
        # Check that all required tags were found in the entry.
        #
        Check_Required_Entry_Tags($title_text);

        #
        # Check author value
        #
        Check_Entry_Author_Value($entry_id, $title_text);
        
        #
        # Check ID value
        #
        Check_Entry_ID_Value($entry_id, $title_text);

        #
        # Check link value
        #
        Check_Entry_Link_Value($entry_html_link, $title_text, $entry_published,
                               $entry_updated, $entry_author, $entry_title);

        #
        # Check entry published value
        #
        Check_Entry_Date_Value("published", $entry_published, $title_text);
        
        #
        # Check entry updated value
        #
        Check_Entry_Date_Value("updated", $entry_updated, $title_text);
        
        #
        # Check uri value
        #
        Check_URI_Value("entry", $entry_uri, $feed_uri, $title_text);
    }
}

#***********************************************************************
#
# Name: Check_Feed_Date_Value
#
# Parameters: tagname - name of tag
#             content - content of tag
#             title_text - title text for error
#
# Description:
#
#   This function checks the format of a date value for a feed
#
#***********************************************************************
sub Check_Feed_Date_Value {
    my ($tagname, $content, $title_text) = @_;

    my ($status, $message);

    #
    # Remove leading whitespace from content
    #
    $content =~ s/^\s*//g;

    #
    # Do we have any content ?
    #
    if ( $content eq "" ) {
        #
        # No date provided
        #
        Record_Result("SWI_B", -1, 0, "",
                      String_Value("Missing text in") .
                      " <$tagname> " .
                      String_Value("for") . " <feed> " . $title_text);
    }
    #
    # Does the text look like a date (YYYY-MM-DD) ?
    #
    else {
        ($status, $message) = Check_YYYY_MM_DD_Format($content);
        if ( $status == 1 ) {
            Record_Result("SWI_B", -1, 0, "",
                          "$message " . String_Value("in") . " <$tagname> " .
                          String_Value("for") . " <feed>");
        }
    }
}

#***********************************************************************
#
# Name: Check_Feed_ID_Value
#
# Parameters: id_text - id value
#
# Description:
#
#   This function checks the value of the ID attribute for feeds.
#
#***********************************************************************
sub Check_Feed_ID_Value {
    my ($id_text) = @_;

    #
    # Do we have an id value ?
    #
    if ( defined($id_text) ) {
        #
        # Is the value missing ?
        #
        if ( $id_text eq "" ) {
            print "Missing feed id value\n" if $debug;
            Record_Result("SWI_B", -1, 0, "",
                          String_Value("Missing text in") .
                          " <feed> <id>");
        }
        #
        # Have we seen this ID before ?
        #
        elsif ( defined($feed_id_values{$id_text}) ) {
            print "Duplicate feed id $id_text\n" if $debug;
            Record_Result("SWI_B", -1, 0, "",
                          String_Value("Duplicate feed id") .
                          " \"$id_text\" " .
                          String_Value("previously found in") .
                          " \"" . $feed_id_values{$id_text} . "\"");
        }
        #
        # New id value, save it
        #
        else {
            $feed_id_values{$id_text} = $current_url;
            print "Feed id = $id_text\n" if $debug;
        }
    }
}

#***********************************************************************
#
# Name: Check_Feed_Self_Link_Value
#
# Parameters: link_text - link value
#
# Description:
#
#   This function checks the value of the self link attribute for feeds.
#
#***********************************************************************
sub Check_Feed_Self_Link_Value {
    my ($link_text) = @_;

    #
    # Do we have a self link value ?
    #
    if ( defined($link_text) ) {
        #
        # Do we have  href content ?
        #
        if ( $link_text eq "" ) {
            Record_Result("SWI_B", -1, 0, "",
                          String_Value("Missing href content for") .
                          "<link rel=\"self\"> " . String_Value("in") .
                          " <feed>");
        }
        
        #
        # Does the href match the feed URL ?
        #
        elsif ( $link_text ne $current_url ) {
            Record_Result("SWI_B", -1, 0, "",
                          String_Value("href does not match URL in") .
                          " <link rel=\"self\" href=\"$link_text\" " .
                          String_Value("for") . " <feed>");
        }
    }
}

#***********************************************************************
#
# Name: Compare_Feed_Strings
#
# Parameters: string1 - string value
#             string2 - string value
#             tagname - name of tag
#             metadata - name of metadata tag
#
# Description:
#
#   This function compares the value of 2 strings for a feed.
#
#***********************************************************************
sub Compare_Feed_Strings {
    my ($string1, $string2, $tagname, $metadata) = @_;

    #
    # Are the strings not equal ?
    #
    if ( $string1 ne $string2 ) {
        Record_Result("SWI_B", -1, 0, "",
                      String_Value("Values do not match for") .
                      " <$tagname> \"$string1\" " . String_Value("and") .
                      " $metadata \"$string2\" " .
                      String_Value("in") . " <feed>");
    }
}

#***********************************************************************
#
# Name: Check_Feed_HTML_Link_Value
#
# Parameters: link_text - link value
#             updated - updated value of feed
#             author - author value of feed
#             title - title value of feed
#
# Description:
#
#   This function checks the value of the HTML link for feeds.
#
#***********************************************************************
sub Check_Feed_HTML_Link_Value {
    my ($link_text, $updated, $author, $title) = @_;

    my ($resp, $content, $resp_url, %metadata, $metadata_object);

    #
    # Do we have an link value ?
    #
    if ( defined($link_text) ) {
        #
        # Do we have  href content ?
        #
        if ( $link_text eq "" ) {
            Record_Result("SWI_B", -1, 0, "",
                          String_Value("Missing href content for") .
                          "<link> " . String_Value("in") .
                          " <feed>");
        }
        #
        # Does the href look like a URL ?
        #
        elsif ( $link_text =~ /^http[s]?:/i ) {
            #
            # Get the URL content
            #
            print "GET feed link href\n" if $debug;
            ($resp_url, $resp) = Crawler_Get_HTTP_Response($link_text, "");

            #
            # Was the GET successful ?
            #
            if ( $resp->is_success ) {
                #
                # Decode possible UTF-8 content
                #
                $content = Crawler_Decode_Content($resp);

                #
                # Extract metadata from content
                #
                %metadata = Extract_Metadata($link_text, $content);

                #
                # If we have an author and dcterms.creator, check that they
                # match.
                #
                if ( defined($author) && defined($metadata{"dcterms.creator"}) ) {
                    $metadata_object = $metadata{"dcterms.creator"};
                    Compare_Feed_Strings($author, $metadata_object->content,
                                          "author", "dcterms.creator");
                }

                #
                # If we have an updated value and dcterms.modified, check
                # that they match.
                #
                if ( defined($updated) && defined($metadata{"dcterms.modified"}) ) {
                    $updated =~ s/T.*$//g;
                    $metadata_object = $metadata{"dcterms.modified"};
                    Compare_Feed_Strings($updated, $metadata_object->content,
                                          "updated", "dcterms.modified");
                }

                #
                # If we have a title and dcterms.title, check that they
                # match.
                #
                if ( defined($title) && defined($metadata{"dcterms.title"}) ) {
                    $metadata_object = $metadata{"dcterms.title"};
                    Compare_Feed_Strings($title, $metadata_object->content,
                                          "title", "dcterms.title");
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: End_Feed_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the end <feed> tag.
#
#***********************************************************************
sub End_Feed_Tag_Handler {
    my ($self) = @_;

    #
    # Are we inside a feed ?
    #
    if ( $in_feed ) {
        #
        # We are no longer inside an <feed>
        #
        $in_feed = 0;

        #
        # Check feed title
        #
        if ( defined($feed_title) && ($feed_title eq "") ) {
            Record_Result("SWI_B", -1, 0, "",
                          String_Value("Missing text in") .
                          " <feed> <title>");
        }
        
        #
        # Check that all required tags were found in the feed.
        #
        Check_Required_Feed_Tags();

        #
        # Check ID value
        #
        Check_Feed_ID_Value($feed_id);

        #
        # Check self link value
        #
        Check_Feed_Self_Link_Value($feed_self_link);

        #
        # Check html alternate link value
        #
        Check_Feed_HTML_Link_Value($feed_html_link, $feed_updated,
                                   $feed_author, $feed_title);

        #
        # Check feed updated value
        #
        Check_Feed_Date_Value("updated", $feed_updated);

        #
        # Check uri value
        #
        Check_URI_Value("feed", $feed_uri, $feed_uri, "");
    }
}

#***********************************************************************
#
# Name: End_Author_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </author> tag.
#
#***********************************************************************
sub End_Author_Tag_Handler {
    my ($self) = @_;

    #
    # No longer  inside an author ?
    #
    $in_author = 0;
}

#***********************************************************************
#
# Name: End_ID_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </id> tag.
#
#***********************************************************************
sub End_ID_Tag_Handler {
    my ($self) = @_;

    #
    # Check the id text, it should be unique within the feed
    #
    print "ID text = $saved_text\n" if $debug;

    #
    # Are we inside an entry ?
    #
    if ( $in_entry ) {
        #
        # Do we have an ID ?
        #
        $saved_text =~ s/^\s*//g;
        $saved_text =~ s/\s*$//g;
        $entry_id = $saved_text;
    }
    #
    # Are we inside a feed ?
    #
    elsif ( $in_feed ) {
        #
        # Do we have an ID ?
        #
        $saved_text =~ s/^\s*//g;
        $saved_text =~ s/\s*$//g;
        $feed_id = $saved_text;
    }

    #
    # Turn off text saving
    #
    $save_text_between_tags = 0;
    $saved_text = "";
}

#***********************************************************************
#
# Name: End_Name_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </name> tag.
#
#***********************************************************************
sub End_Name_Tag_Handler {
    my ($self) = @_;

    #
    # Are we inside an anthor inside an entry ?
    #
    if ( $in_author && $in_entry ) {
        print "Entry name text = $saved_text\n" if $debug;
        #
        # Do we have an author ?
        #
        $saved_text =~ s/^\s*//g;
        $saved_text =~ s/\s*$//g;
        $entry_author = $saved_text;
    }
    #
    # Are we inside an anthor inside a feed ?
    #
    elsif ( $in_author && $in_feed ) {
        print "Feed name text = $saved_text\n" if $debug;
        #
        # Do we have an author ?
        #
        $saved_text =~ s/^\s*//g;
        $saved_text =~ s/\s*$//g;
        $feed_author = $saved_text;
    }

    #
    # Turn off text saving
    #
    $save_text_between_tags = 0;
    $saved_text = "";
}

#***********************************************************************
#
# Name: End_Published_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </published> tag.
#
#***********************************************************************
sub End_Published_Tag_Handler {
    my ($self) = @_;

    #
    # Check the published text.
    #
    print "Published text = $saved_text\n" if $debug;

    #
    # Are we inside an entry ?
    #
    if ( $in_entry ) {
        $saved_text =~ s/^\s*//g;
        $entry_published = $saved_text;
    }

    #
    # Turn off text saving
    #
    $save_text_between_tags = 0;
    $saved_text = "";
}

#***********************************************************************
#
# Name: End_Title_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the end <title> tag.
#
#***********************************************************************
sub End_Title_Tag_Handler {
    my ($self) = @_;

    #
    # Remoev leading and trailing whitespace from any saved text
    #
    $saved_text =~ s/^\s*//g;
    $saved_text =~ s/\s*$//g;

    #
    # Is this an entry title ?
    #
    if ( $in_entry ) {
        print "Entry title = $saved_text\n" if $debug;
        $entry_title = $saved_text;
    }
    #
    # Is this an item title ?
    #
    elsif ( $in_item ) {
        #
        # Ignore item title, this applies to RSS type feeds only.
        #
    }
    #
    # Are we inside a feed ?
    #
    elsif ( $in_feed ) {
        print "Feed title = $saved_text\n" if $debug;
        $feed_title = $saved_text;
    }
    #
    # Are we inside a RSS type feed ?
    #
    elsif ( $in_rss ) {
        print "RSS feed title = $saved_text\n" if $debug;
        $feed_title = $saved_text;
    }

    #
    # Turn off text saving
    #
    $save_text_between_tags = 0;
    $saved_text = "";
}

#***********************************************************************
#
# Name: End_Updated_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </updated> tag.
#
#***********************************************************************
sub End_Updated_Tag_Handler {
    my ($self) = @_;

    #
    # Check the updated text.
    #
    print "Published text = $saved_text\n" if $debug;
    
    #
    # Are we inside an entry ?
    #
    if ( $in_entry ) {
        $saved_text =~ s/^\s*//g;
        $entry_updated = $saved_text;
    }
    #
    # Are we inside a feed ?
    #
    elsif ( $in_feed ) {
        $saved_text =~ s/^\s*//g;
        $feed_updated = $saved_text;
    }

    #
    # Turn off text saving
    #
    $save_text_between_tags = 0;
    $saved_text = "";
}

#***********************************************************************
#
# Name: End_URI_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the </uri> tag.
#
#***********************************************************************
sub End_URI_Tag_Handler {
    my ($self) = @_;

    #
    # Get the uri text
    #
    print "URI text = $saved_text\n" if $debug;

    #
    # Are we inside an entry ?
    #
    if ( $in_entry ) {
        $saved_text =~ s/^\s*//g;
        $entry_uri = $saved_text;
        $entry_uri =~ s/\/$//g;
    }
    #
    # Are we inside a feed ?
    #
    elsif ( $in_feed ) {
        $saved_text =~ s/^\s*//g;
        $feed_uri = $saved_text;
        $feed_uri =~ s/\/$//g;
    }

    #
    # Turn off text saving
    #
    $save_text_between_tags = 0;
    $saved_text = "";
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
    # Check for author tag
    #
    print "End_Handler tag $tagname\n" if $debug;
    if ( $tagname eq "author" ) {
        End_Author_Tag_Handler($self);
    }
    #
    # Check for entry tag
    #
    elsif ( $tagname eq "entry" ) {
        End_Entry_Tag_Handler($self);
    }
    #
    # Check for feed tag
    #
    elsif ( $tagname eq "feed" ) {
        End_Feed_Tag_Handler($self);
    }
    #
    # Check for id tag
    #
    elsif ( $tagname eq "id" ) {
        End_ID_Tag_Handler($self);
    }
    #
    # Check for item tag (RSS feeds)
    #
    elsif ( $tagname eq "item" ) {
        if ( $in_item ) {
            #
            # We are no longer inside an <item>
            #
            $in_item = 0;
        }
    }
    #
    # Check for name tag
    #
    elsif ( $tagname eq "name" ) {
        End_Name_Tag_Handler($self);
    }
    #
    # Check for published tag
    #
    elsif ( $tagname eq "published" ) {
        End_Published_Tag_Handler($self);
    }
    #
    # Check for title tag
    #
    elsif ( $tagname eq "title" ) {
        End_Title_Tag_Handler($self);
    }
    #
    # Check for updated tag
    #
    elsif ( $tagname eq "updated" ) {
        End_Updated_Tag_Handler($self);
    }
    #
    # Check for uri tag
    #
    elsif ( $tagname eq "uri" ) {
        End_URI_Tag_Handler($self);
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
    # Save character encoding attribute.
    #
    print "XML doctype $version, $encoding, $standalone\n" if $debug;
    $charset = $encoding;
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
    # Do we have a resp object ?
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
            # Did we find any encoding in the XML declaration line ?
            #
            if ( $charset =~ /UTF-8/i ) {
                print "UTF-8 content\n" if $debug;
            }
            else {
                #
                # Not UTF 8 content
                #
                Record_Result("SWI_C", -1, 0, $charset_text,
                              String_Value("Encoding is not UTF-8"));
            }
        }
    }
}

#***********************************************************************
#
# Name: Interop_XML_Check
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
sub Interop_XML_Check {
    my ( $this_url, $language, $profile, $mime_type, $resp, $content ) = @_;

    my (@tqa_results_list, $parser, $result_object);
    my ($tcid, $eval_output);

    #
    # Do we have a valid profile ?
    #
    print "Interop_XML_Check: URL $this_url, mime-type = $mime_type, lanugage = $language, profile = $profile\n" if $debug;
    if ( ! defined($interop_check_profile_map{$profile}) ) {
        print "Unknown testcase profile passed $profile\n";
        return(@tqa_results_list);
    }

    #
    # Is this a web feed ? We don't check XML files that are not
    # web feeds.
    #
    if ( ! Feed_Validate_Is_Web_Feed($this_url, $content) ) {
        print "Not a web feed\n" if $debug;
        return(@tqa_results_list);
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
        # Doesn't look like a URL.  Could be just a block of XML
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Did we get any content ?
    #
    if ( length($$content) > 0 ) {
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
        # Parse the content.
        #
        $eval_output = eval { $parser->parse($$content); 1 } ;
        
        #
        # Did the parsing fail ?
        #
        if ( $eval_output ne "1" ) {
            Record_Result("SWI_B", -1, 0, "",
                          String_Value("Fails validation"));

        }
    }
    else {
        print "No content passed to Interop_XML_Check\n" if $debug;
        return(@tqa_results_list);
    }

    #
    # Check character encoding
    #
    Check_Encoding($resp);

    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Interop_XML_Feed_Details
#
# Parameters: this_url - a URL
#             content - content pointer
#
# Description:
#
#   This function returns a news feed object containing a number
# of feed details (e.g. type, title).  If the content is not a 
# valid news feed, undefined is returned.
#
#***********************************************************************
sub Interop_XML_Feed_Details {
    my ($this_url, $content) = @_;

    my ($feed_object, @tqa_results_list, $resp);

    #
    # Do we have to analyse this content to get the details or was
    # it the last one preocessed ?
    #
    print "Interop_XML_Feed_Details, url = $this_url\n" if $debug;
    if ( $this_url ne $current_url ) {
        #
        # Analyse content to get details.
        #
        print "Run Interop_XML_Check to get feed details\n" if $debug;
        @tqa_results_list = Interop_XML_Check($this_url, "", "", 
                                              "application/xhtml+xml", $resp,
                                              $content);

    }

    #
    # Did we get a news feed type ?
    #
    if ( $feed_type ne "" ) {
        print "News feed details, type = $feed_type, title = $feed_title\n" if $debug;
        $feed_object = xml_feed_object->new($feed_type, $feed_title, $this_url);
    }

    #
    # Return the feed object
    #
    return($feed_object);
}

#***********************************************************************
#
# Name: Interop_XML_Check_Feeds
#
# Parameters: profile - testcase profile
#             feed_list - list of feed objects
#
# Description:
#
#    This function checks a list of feed objects to see if there are
# any non Atom feeds that don't have a matching Atom feed (e.g. an
# RSS only feed). 
#
#***********************************************************************
sub Interop_XML_Check_Feeds {
    my ($profile, @feed_list) = @_;

    my ($tcid, $do_tests, %atom_feeds, %non_atom_feeds, $feed_object);
    my (@tqa_results_list, $title);

    #
    # Do we have a valid profile ?
    #
    print "Interop_XML_Check_Feeds: profile = $profile\n" if $debug;
    if ( ! defined($interop_check_profile_map{$profile}) ) {
        print "Unknown testcase profile passed $profile\n";
        return(@tqa_results_list);
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
    # Split feed list into atom and non atom feeds
    #
    foreach $feed_object (@feed_list) {
        if ( $feed_object->type eq "atom" ) {
            $atom_feeds{$feed_object->title} = $feed_object;
        }
        else {
            $non_atom_feeds{$feed_object->title} = $feed_object;
        }
    }

    #
    # Check each non atom feed to see if there is an atom feed with
    # the same title.
    #
    while ( ($title, $feed_object) = each %non_atom_feeds ) {
        #
        # Do we have an atom feed with the exact title ?
        #
        if ( ! defined($atom_feeds{$title}) ) {
            $current_url = $feed_object->url;
            Record_Result("SWI_B", -1, 0, "",
                          String_Value("No Atom Web feed found with title") .
                          " \"$title\"");
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
    my (@package_list) = ("tqa_result_object", "content_check", 
                          "xml_feed_object", "interop_testcases",
                          "url_check", "crawler", "metadata",
                          "feed_validate");

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

