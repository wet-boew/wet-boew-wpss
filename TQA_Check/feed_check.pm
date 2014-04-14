#***********************************************************************
#
# Name:   xml_check.pm
#
# $Revision: 6588 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/TQA_Check/Tools/feed_check.pm $
# $Date: 2014-03-12 15:33:51 -0400 (Wed, 12 Mar 2014) $
#
# Description:
#
#   This file contains routines that parse Web feed files and check for
# a number of accessibility (WCAG) check points.
#
# Public functions:
#     Set_Feed_Check_Language
#     Set_Feed_Check_Debug
#     Set_Feed_Check_Testcase_Data
#     Set_Feed_Check_Test_Profile
#     Feed_Check
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

package feed_check;

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
    @EXPORT  = qw(Set_Feed_Check_Language
                  Set_Feed_Check_Debug
                  Set_Feed_Check_Testcase_Data
                  Set_Feed_Check_Test_Profile
                  Feed_Check
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

my (%feed_check_profile_map, $current_feed_check_profile, $current_url);
my ($feed_type, $in_entry, $in_item, $saved_text, $save_text_between_tags);
my ($in_feed, $in_rss, $in_author, $feed_title, $entry_title);
my ($entry_count, $current_content_lang_code);

my ($max_error_message_string)= 2048;

#
# Status values
#
my ($feed_check_pass)       = 0;
my ($feed_check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Fails validation",           "Fails validation, see validation results for details.",
    "Missing title in",           "Missing <title> in",
    "Missing text in",            "Missing text in",
    "Missing feed language attribute", "Missing <feed> language attribute",
    "Feed language attribute",    "<feed> language attribute",
    "does not match content language", "does not match content language",
    );




my %string_table_fr = (
    "Fails validation",             "Échoue la validation, voir les résultats de validation pour plus de détails.",
    "Missing title in",             "<title> manquant pour",
    "Missing text in",              "Texte manquant dans",
    "Missing feed language attribute", "Attribut manquant pour <feed>",
    "Feed language attribute",      "L'attribut du langage <feed>",
    "does not match content language",  "ne correspond pas à la langue de contenu",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_Feed_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Feed_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_Feed_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Feed_Check_Language {
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
# Name: Set_Feed_Check_Testcase_Data
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
sub Set_Feed_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_Feed_Check_Test_Profile
#
# Parameters: profile - XML check test profile
#             feed_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by XML testcase name.
#
#***********************************************************************
sub Set_Feed_Check_Test_Profile {
    my ($profile, $feed_checks ) = @_;

    my (%local_feed_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Feed_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_feed_checks = %$feed_checks;
    $feed_check_profile_map{$profile} = \%local_feed_checks;
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
    $current_feed_check_profile = $feed_check_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;

    #
    # Initialize other global variables
    #
    $feed_type = "";
    $in_feed = 0;
    $in_rss = 0;
    $in_entry = 0;
    $in_item = 0;
    $save_text_between_tags = 0;
    $saved_text = "";
    undef($feed_title);
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
    my ( $testcase, $line, $column,, $text, $error_string ) = @_;

    my ($result_object);

    #
    # Is this testcase included in the profile
    #
    if ( defined($testcase) && defined($$current_feed_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $feed_check_fail,
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

    my ($lang);

    #
    # Inside a news <feed>. Set feed type.
    #
    if ( ! $in_feed ) {
        $in_feed = 1;
        print "Atom feed\n" if $debug;
        $feed_type = "atom";
    }

    #
    # Do we have a language attribute ?
    #
    if ( ! defined($attr{"xml:lang"}) ) {
        #
        # Missing language attribute
        #
        Record_Result("WCAG_2.0-SC3.1.1", -1, -1, "",
                      String_Value("Missing feed language attribute") .
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
            print "Web feed language is $lang\n" if $debug;
        }
        else {
            $lang = $lang;
            print "Unknown web feed language $lang\n" if $debug;
        }

        #
        # Does the lang attribute match the content language ?
        #
        if ( ($current_content_lang_code ne "" ) &&
             ($lang ne $current_content_lang_code) ) {
            Record_Result("WCAG_2.0-SC3.1.1", -1, -1, "",
                          String_Value("Feed language attribute") .
                          " '$lang' " .
                          String_Value("does not match content language") .
                          " '$current_content_lang_code'");
        }
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
#   This function handles the <entry> tag.
#
#***********************************************************************
sub Entry_Tag_Handler {
    my ($self, $tagname, %attr) = @_;

    #
    # Inside a news <entry>.
    #
    if ( (! $in_entry) && $in_feed ) {
        $in_entry = 1;
        #
        # Initialize entry attribute variables
        #
        undef($entry_title);
    }

    #
    # Increment entry count
    #
    $entry_count++;
}

#***********************************************************************
#
# Name: Item_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the <item> tag.
#
#***********************************************************************
sub Item_Tag_Handler {
    my ($self, $tagname, %attr) = @_;

    #
    # Inside a news <item>.
    #
    if ( (! $in_item) && $in_rss ) {
        $in_item = 1;
        #
        # Initialize item attribute variables
        #
        undef($entry_title);
    }

    #
    # Increment entry count
    #
    $entry_count++;
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
    # Check for item tag (RSS feeds)
    #
    elsif ( $tagname eq "item" ) {
        Item_Tag_Handler($self, $tagname, %attr);
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
        if ( ! defined($entry_title) ) {
            Record_Result("WCAG_2.0-F25", -1, 0, "",
                          String_Value("Missing title in") .
                          " <entry> #$entry_count");
        }
        elsif ( $entry_title eq "" ) {
            Record_Result("WCAG_2.0-F25", -1, 0, "",
                          String_Value("Missing text in") .
                          " <entry> #$entry_count <title>");
        }
    }
}

#***********************************************************************
#
# Name: End_Item_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the end <item> tag.
#
#***********************************************************************
sub End_Item_Tag_Handler {
    my ($self) = @_;

    #
    # Are we inside an item ?
    #
    if ( $in_item ) {
        #
        # We are no longer inside an <item>
        #
        $in_item = 0;

        #
        # Check item title
        #
        if ( ! defined($entry_title) ) {
            Record_Result("WCAG_2.0-F25", -1, 0, "",
                          String_Value("Missing title in") .
                          " <item> #$entry_count");
        }
        elsif ( $entry_title eq "" ) {
            Record_Result("WCAG_2.0-F25", -1, 0, "",
                          String_Value("Missing text in") .
                          " <item> #$entry_count <title>");
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
        if ( ! defined($feed_title) ) {
            Record_Result("WCAG_2.0-F25", -1, 0, "",
                          String_Value("Missing title in") .
                          " <feed>");
        }
        elsif ( $feed_title eq "" ) {
            Record_Result("WCAG_2.0-F25", -1, 0, "",
                          String_Value("Missing text in") .
                          " <feed> <title>");
        }
    }
}

#***********************************************************************
#
# Name: End_RSS_Tag_Handler
#
# Parameters: self - reference to this parser
#
# Description:
#
#   This function handles the end <rss> tag.
#
#***********************************************************************
sub End_RSS_Tag_Handler {
    my ($self) = @_;

    #
    # Are we inside a rss feed ?
    #
    if ( $in_rss ) {
        #
        # We are no longer inside an <feed>
        #
        $in_rss = 0;

        #
        # Check feed title
        #
        if ( ! defined($feed_title) ) {
            Record_Result("WCAG_2.0-F25", -1, 0, "",
                          String_Value("Missing title in") .
                          " <rss>");
        }
        elsif ( $feed_title eq "" ) {
            Record_Result("WCAG_2.0-F25", -1, 0, "",
                          String_Value("Missing text in") .
                          " <rss> <title>");
        }
    }
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
        print "Item title = $saved_text\n" if $debug;
        $entry_title = $saved_text;
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
        End_Entry_Tag_Handler($self);
    }
    #
    # Check for feed tag
    #
    elsif ( $tagname eq "feed" ) {
        End_Feed_Tag_Handler($self);
    }
    #
    # Check for item tag (RSS feeds)
    #
    elsif ( $tagname eq "item" ) {
        End_Item_Tag_Handler($self);
    }
    #
    # Check for rss tag
    #
    elsif ( $tagname eq "rss" ) {
        End_RSS_Tag_Handler($self);
    }
    #
    # Check for title tag
    #
    elsif ( $tagname eq "title" ) {
        End_Title_Tag_Handler($self);
    }
}

#***********************************************************************
#
# Name: Feed_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             content - XML content
#
# Description:
#
#   This function runs a number of technical QA checks on XML content.
#
#***********************************************************************
sub Feed_Check {
    my ( $this_url, $language, $profile, $content ) = @_;

    my ($parser, @urls, $url, @tqa_results_list, $result_object, $testcase);
    my ($eval_output, $lang_code, $lang, $status);

    #
    # Do we have a valid profile ?
    #
    print "Feed_Check: Checking URL $this_url, lanugage = $language, profile = $profile\n" if $debug;
    if ( ! defined($feed_check_profile_map{$profile}) ) {
        print "Feed_Check: Unknown XML testcase profile passed $profile\n";
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
    if ( length($content) == 0 ) {
        print "No content passed to Feed_Check\n" if $debug;
        return(@tqa_results_list);
    }
    else {
        #
        # Get content language
        #
        ($lang_code, $lang, $status) = TextCat_XML_Language($content);

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
        $parser = XML::Parser->new;

        #
        # Add handlers for some of the XML tags
        #
        $parser->setHandlers(Start => \&Start_Handler);
        $parser->setHandlers(End => \&End_Handler);
        $parser->setHandlers(Char => \&Char_Handler);

        #
        # Parse the content.
        #
        $eval_output = eval { $parser->parse($content); } ;
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "Feed_Check results\n";
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
                          "language_map", "textcat");

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

