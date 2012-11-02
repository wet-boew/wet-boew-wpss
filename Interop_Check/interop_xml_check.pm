#***********************************************************************
#
# Name:   interop_xml_check.pm
#
# $Revision: 6024 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Interop_Check/Tools/interop_xml_check.pm $
# $Date: 2012-10-11 15:15:30 -0400 (Thu, 11 Oct 2012) $
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
my ($results_list_addr, @content_lines);
my ($charset, $charset_text);
my ($feed_type, $in_entry, $saved_text, $save_text_between_tags);
my (%news_feed_found_tags, %news_entry_found_tags, $in_feed);
my ($feed_title, $entry_title);

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
    $in_feed = 0;
    $in_entry = 0;
    $save_text_between_tags = 0;
    $saved_text = "";
    %news_feed_found_tags = %news_feed_required_tags;
    $feed_title = "";
    $entry_title = "";
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
                      "  <feed> \"$tag_list\"");

    }
}

#***********************************************************************
#
# Name: Check_Required_Entry_Tags
#
# Parameters: none
#
# Description:
#
#   This function checks to see that all required tags were found
# between the open & close entry tags.
#
#***********************************************************************
sub Check_Required_Entry_Tags {

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
                      String_Value("Missing tags in") .
                      " <entry> " . String_Value("title") . " \"$entry_title\" " .
                      String_Value("tags") . " \"$tag_list\"");

    }
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

    #
    # Do we have a rel attribute with the value 'self' ?
    #
    if ( defined($attr{"rel"}) && ($attr{"rel"} eq "self") ) {
        #
        # Check for href attribute
        #
        if ( defined($attr{"href"}) ) {
            #
            # Does it match the feed's URL ?
            #
            if ( $attr{"href"} ne $current_url ) {
                Record_Result("SWI_B", -1, 0, "",
                              String_Value("href does not match URL in") .
                              " <link rel=\"self\"");
            }
        }
        else {
            #
            # Missing href attribute
            #
            Record_Result("SWI_B", -1, 0, "",
                          String_Value("Missing href attribute for") .
                          " <link>");
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
    if ( ! defined($attr{"xml:lang"}) ) {
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
            $entry_title = "";
    }
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
    # Check for entry tag.
    #
    print "Start_Handler tag $tagname\n" if $debug;
    if ( $tagname eq "entry" ) {
        Entry_Tag_Handler($self, $tagname, %attr);
    }
    #
    # Check for feed tag, indicating this is an Atom feed.
    #
    elsif ( $tagname eq "feed" ) {
        Feed_Tag_Handler($self, $tagname, %attr);
    }
    #
    # Check for link tag
    #
    elsif ( $tagname eq "link" ) {
        Link_Tag_Handler($self, $tagname, %attr);
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
# Name: End_Title_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#
# Description:
#
#   This function handles the end <title> tag.
#
#***********************************************************************
sub End_Title_Tag_Handler {
    my ($self, $tagname) = @_;

    #
    # Is this an entry title ?
    #
    if ( $in_entry ) {
        print "Entry title = $saved_text\n" if $debug;
        $entry_title = $saved_text;
    }
    else {
        #
        # Must be feed title
        #
        print "Feed title = $saved_text\n" if $debug;
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
    # Check for entry tag
    #
    print "End_Handler tag $tagname\n" if $debug;
    if ( $tagname eq "entry" ) {
        if ( $in_entry ) {
            #
            # We are no longer inside an <entry>
            #
            $in_entry = 0;

            #
            # Check that all required tags were found in the entry.
            #
            Check_Required_Entry_Tags();
        }
    }
    elsif ( $tagname eq "feed" ) {
        if ( $in_feed ) {
            #
            # We are no longer inside an <feed>
            #
            $in_feed = 0;
        
            #
            # Check that all required tags were found in the feed.
            #
            Check_Required_Feed_Tags();
        }
    }
    #
    # Check for title tag
    #
    elsif ( $tagname eq "title" ) {
        End_Title_Tag_Handler($self, $tagname);
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
#             content - content
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
    if ( $this_url =~ /^http/i ) {
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
    if ( length($content) > 0 ) {
        #
        # Split the content into lines
        #
        @content_lines = split( /\n/, $content );

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
        $eval_output = eval { $parser->parse($content); } ;
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
#             content - content
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
                          "xml_feed_object", "interop_testcases");

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

