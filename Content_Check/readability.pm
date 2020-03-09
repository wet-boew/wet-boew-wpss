#***********************************************************************
#
# Name:   readability.pm
#
# $Revision: 7172 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Content_Check/Tools/readability.pm $
# $Date: 2015-06-05 10:50:19 -0400 (Fri, 05 Jun 2015) $
#
# Description:
#
#   This file contains routines that grade the readability of content.
#
# Fog index
#
# The Fog index, developed by Robert Gunning, is a well known
# and simple formula for measuring readability. The index indicates
# the number of years of formal education a reader of average
# intelligence would need to read the text once and understand
# that piece of writing with its word sentence workload.
#
#    18 unreadable
#    14 difficult
#    12 ideal
#    10 acceptable
#     8 childish
#
#
# Flesch-Kincaid grade score
#
# This score rates text on U.S. grade school level. So a score
# of 8.0 means that the document can be understood by an eighth
# grader. A score of 7.0 to 8.0 is considered to be optimal.
#
# Public functions:
#     Readability_Grade_HTML
#     Readability_Grade_Text
#     Set_Readability_Debug
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

package readability;

use strict;
use HTML::Parser;
use HTML::Entities;
use File::Basename;
use Lingua::EN::Fathom;
use File::Temp qw/ tempfile tempdir /;


#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Readability_Grade_HTML
                  Readability_Grade_Text
                  Set_Readability_Debug
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my ($fathom_object, $last_start_tag, @tag_stack, $save_text);
my ($all_text);

#
# List of tags that have no end tag.
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
# List of HTML 5 tags with an implicit end tag.
# The tag is implicitly closed if it is followed by one of the
# specified start tags.
# Source: http://dev.w3.org/html5/spec/Overview.html#optional-tags
#
my (%implicit_end_tag_start_handler) = (
  "address", " p ",
  "article", " p ",
  "aside", " p ",
  "blockquote", " p ",
  "dd", " dd dt ",
  "dir", " p ",
  "dl", " p ",
  "dt", " dd dt ",
  "fieldset", " p ",
  "footer", " p ",
  "form", " p ",
  "h1", " p ",
  "h2", " p ",
  "h3", " p ",
  "h4", " p ",
  "h5", " p ",
  "h6", " p ",
  "header", " p ",
  "hgroup", " p ",
  "hr", " p ",
  "li", " li ",
  "menu", " p ",
  "nav", " p ",
  "ol", " p ",
  "p", " p ",
  "pre", " p ",
  "rp", " rp rt ",
  "rt", " rp rt ",
  "table", " p ",
  "tbody", " tbody tfoot ",
  "thead", " tbody tfoot ",
  "tfoot", " tbody ",
  "td", " td th ",
  "th", " td th ",
  "tr", " tr ",
  "ul", " p ",
);

#
# List of HTML 5 tags with an implicit end tag.
# The tag is implicitly closed if it is followed by one of the
# specified close tags.
# Source: http://dev.w3.org/html5/spec/Overview.html#optional-tags
#
my (%implicit_end_tag_end_handler) = (
  "dd", " dl ",
  "li", " ol ul ",
  "p",  " address article aside blockquote body button dd del details div" .
        " dl fieldset figure form footer header ins li map menu nav ol" .
        " pre section table td th ul ",
  "tbody", " table ",
  "thead", " table ",
  "tfoot", " table ",
  "td", " table ",
  "th", " table ",
  "tr", " table ",
);

#
# Minimum number of characters needed to analyse
#
my ($MINIMUM_INPUT_LENGTH) = 500;

#***********************************************************************
#
# Name: Set_Readability_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Readability_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: Check_For_Implicit_End_Tag_Before_Start_Tag
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             attr - hash table of attributes
#
# Description:
#
#   This function checks for an implicit end tag caused by a start tag.
#
#***********************************************************************
sub Check_For_Implicit_End_Tag_Before_Start_Tag {
    my ($tagname, $line, $column, %attr) = @_;

    my ($previous_tag, $index, $tag_list);

    #
    # Get previous start tag.
    #
    print "Check_For_Implicit_End_Tag_Before_Start_Tag for $tagname\n" if $debug;
    $index = @tag_stack - 1;
    if ( $index >= 0 ) {
        $previous_tag = $tag_stack[$index];
    }
    else {
        print "Tag order stack is empty\n" if $debug;
        return;
    }

    #
    # Check to see if there is a list of tags that may be implicitly
    # ended by this start tag.
    #
    print "Check for implicit end tag caused by start tag $tagname\n" if $debug;
    if ( defined($implicit_end_tag_start_handler{$tagname}) ) {
        #
        # Is the last tag in the list of tags that
        # implicitly closed by the current tag ?
        #
        $tag_list = $implicit_end_tag_start_handler{$tagname};
        if ( index($tag_list, " $previous_tag ") != -1 ) {
            #
            # Call End Handler to close the last tag
            #
            print "Tag $previous_tag implicitly closed by $tagname\n" if $debug;
            End_Handler($previous_tag, $line, $column, ());
        }
        else {
            #
            # The last tag is not implicitly closed by this tag.
            #
            print "Tag $previous_tag not implicitly closed by $tagname\n" if $debug;
        }
    }
    else {
        #
        # No implicit end tag possible, we have a tag ordering
        # error.
        #
        print "No tags implicitly closed by $tagname\n" if $debug;
    }
    print "Finish Check_For_Implicit_End_Tag_Before_Start_Tag for $tagname\n" if $debug;
}

#********************************************************
#
# Name: HTML_Text_Handler
#
# Parameters: text - text string
#
# Description:
#
#   This appends the supplied text to the content string.
#
#********************************************************
sub HTML_Text_Handler {
    my ($text) = @_;

    #
    # Are we saving text ?
    #
    if ( $save_text ) {
        #
        # Decode any entities in text before saving it.
        #
        decode_entities($text);
        
        #
        # Convert multiple whitespace sequences into a single space character
        #
        $text =~ s/\s+/ /g;
        
        #
        # Append text to all the text collected.
        #
        $all_text .= $text;
    }
}

#***********************************************************************
#
# Name: HTML_Start_Handler
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the start of HTML tags.
#
#***********************************************************************
sub HTML_Start_Handler {
    my ( $tagname, $line, $column, %attr ) = @_;

    #
    # Is this a <p> tag ? If so start saving text.
    #
    if ( $tagname eq "p" ) {
        $save_text = 1;
        print "Start text handler at $line:$column\n" if $debug;
    }
    
    #
    # Save last start tag in tag stack
    #
    if ( ! defined ($html_tags_with_no_end_tag{$tagname}) ) {
        push(@tag_stack, $last_start_tag);
    }
    $last_start_tag = $tagname;
}

#***********************************************************************
#
# Name: Check_End_Tag_Order
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             attr - hash table of attributes
#
# Description:
#
#   This function checks end tag ordering.  It checks to see if the
# supplied end tag is valid, and that it matches the last start tag.
# It also fills in implicit end tags where an explicit end tag is
# optional.
#
#***********************************************************************
sub Check_End_Tag_Order {
    my ($tagname, $line, $column, %attr) = @_;

    my ($tag_list);
    
    #
    # Does this end tag not match the last start tag ?
    #
    if ( $tagname ne $last_start_tag ) {
        print "This tag $tagname, does not match last start tag $last_start_tag\n" if $debug;
        #
        # This end tag could implicitly close some other start tags.
        #
        if ( defined($implicit_end_tag_end_handler{$last_start_tag}) ) {
            #
            # Is this tag in the list of tags that
            # implicitly close the last tag in the tag stack ?
            #
            $tag_list = $implicit_end_tag_end_handler{$last_start_tag};
            if ( index($tag_list, " $tagname ") != -1 ) {
                #
                # Call End Handler to close the last tag
                #
                print "Tag $last_start_tag implicitly closed by $tagname\n" if $debug;
                HTML_End_Handler($last_start_tag, $line, $column, ());

                #
                # Check the end tag order again after implicitly
                # ending the last start tag above.
                #
                print "Check tag order again after implicitly ending $last_start_tag\n" if $debug;
                Check_End_Tag_Order($tagname, $line, $column, %attr);
            }
        }
    }
            
    #
    # Pop last start tag from tag stack
    #
    if ( @tag_stack > 0 ) {
        $last_start_tag = pop(@tag_stack);
    }
    else {
        $last_start_tag = "";
    }
    print "New last start tag = $last_start_tag\n" if $debug;
}

#***********************************************************************
#
# Name: HTML_End_Handler
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end of HTML tags.
#
#***********************************************************************
sub HTML_End_Handler {
    my ($tagname, $line, $column, %attr) = @_;

    #
    # Check end tag ordering, we may have implicit closing of
    # tags.
    #
    Check_End_Tag_Order($tagname, $line, $column, %attr);

    #
    # Is this the end of a <p> ? if so, turn off text saving.
    #
    if ( $save_text && ($tagname eq "p") ) {
        $save_text = 0;
        print "End text handle at $line:$column\n" if $debug;
        
        #
        # Replace non-standard sentence termination (e.g. a colon)
        #
        $all_text =~ s/[:;]\s*$/./g;
        
        #
        # Check for a trailing period.
        #
        if ( ! ($all_text =~ /\.\s*$/) ) {
            $all_text =~ s/\s*$/./g;
            #$all_text .= ".";
        }

        #
        # Add double new line to end the paragraph
        #
        $all_text .= "\n\n";
    }
}

#********************************************************
#
# Name: Extract_Paragraph_Text_From_HTML
#
# Parameters: html_input - pointer to block of HTML text
#
# Description:
#
#   This function extracts paragraph text from a block of HTML markup.
#
# Returns:
#  text
#
#********************************************************
sub Extract_Paragraph_Text_From_HTML {
    my ($html_input) = @_;

    my ($parser, $lang, $content);

    #
    # Initialize global variables
    #
    $save_text = 0;
    $all_text = "";
    $last_start_tag = "";

    #
    # Do we have any content ?
    #
    if ( (! defined($html_input))
         || (! defined($$html_input))
         || ($$html_input eq "") ) {
        print "Extract_Paragraph_Text_From_HTML No content\n" if $debug;
        return($all_text);
    }
    print "Extract_Paragraph_Text_From_HTML, content length = " . length($$html_input) .
          "\n" if $debug;

    #
    # Create a parser to parse the HTML content.
    #
    print "Create parser object\n" if $debug;
    $parser = HTML::Parser->new(api_version => 3,
                                marked_sections => 1);

    #
    # Add handlers for some of the HTML tags
    #
    $parser->handler(
        start => \&HTML_Start_Handler, "tagname,line,column,\@attr"
    );
    $parser->handler(
        end => \&HTML_End_Handler, "tagname,line,column,\@attr"
    );
    $parser->handler(
        text => \&HTML_Text_Handler, "dtext"
    );

    #
    # Parse the HTML to extract the text
    #
    print "Parse the HTML content\n" if $debug;
    $parser->parse($$html_input);

    #
    # Print content
    #
    print "Content from HTML = \n$all_text\n" if $debug;

    #
    # Return the content.
    #
    return($all_text);
}

#***********************************************************************
#
# Name: Analyse_Text
#
# Parameters: content - content pointer
#
# Description:
#
#   This function writes the supplied content to a temporary file
# then analyses the content.  Once the analysis is complete the
# temporary file is removed.
#
# Returns
#   fog - Fog index for the text.
#   flesch_kincaid - Flesch-Kincaid grade level score for the text.
#
#***********************************************************************
sub Analyse_Text {
    my ($content) = @_;

    my ($temp_file_name, $fh);

    #
    # Create temporary file for content.
    #
    ($fh, $temp_file_name) = tempfile("WPSS_TOOL_READ_XXXXXXXXXX", SUFFIX => '.txt',
                                      TMPDIR => 1);
    if ( ! defined($fh) ) {
        print "Error: Failed to create temporary file in Analyse_Text\n";
        return;
    }
    binmode $fh, ":encoding(UTF-8)";
    print $fh $$content;
    close($fh);

    #
    # Do we need to create the Lingua::EN::Fathom handler ?
    # We only have to create it once and reuse it for all
    # analyses.
    #
    if ( ! defined($fathom_object) ) {
        $fathom_object = new Lingua::EN::Fathom;
    }

    #
    # Analyse the text in the file.
    #
    $fathom_object->analyse_file("$temp_file_name");

    #
    # Remove temporary file as we no longer need it.
    #
    unlink($temp_file_name);
}

#***********************************************************************
#
# Name: Readability_Grade_Text
#
# Parameters: content - content pointer
#
# Description:
#
#   This function determines the readability level of a block of text.
# If there is insufficient text to analyse, this function returns -1 for
# both the fog and flesch-kincaid values.
#
# Online readability scoring https://readability-score.com/
#
# Returns
#   fog - Fog index for the text.
#   flesch_kincaid - Flesch-Kincaid grade level score for the text.
#
#***********************************************************************
sub Readability_Grade_Text {
    my ($content) = @_;

    #
    # Initial values for scores. A -1 value indicates no score.
    #
    my (%readability_scores);
    my ($fog, $flesch_kincaid) = (-1, -1);

    #
    # Is there enough text to analyse ?
    #
    if ( length($$content) > $MINIMUM_INPUT_LENGTH ) {
        #
        # Analyse the text to compute readability metrics.
        #
        Analyse_Text($content);

        #
        # Get the Fog index value.
        #
        # The Fog index, developed by Robert Gunning, is a well known
        # and simple formula for measuring readability. The index indicates 
        # the number of years of formal education a reader of average 
        # intelligence would need to read the text once and understand 
        # that piece of writing with its word sentence workload.
        #
        #    18 unreadable
        #    14 difficult
        #    12 ideal
        #    10 acceptable
        #     8 childish
        #
        $fog = int($fathom_object->fog);

        #
        # Get the Flesch-Kincaid grade score
        #
        # This score rates text on U.S. grade school level. So a score 
        # of 8.0 means that the document can be understood by an eighth 
        # grader. A score of 7.0 to 8.0 is considered to be optimal.
        #
        $flesch_kincaid = int($fathom_object->kincaid);
        #print " Words per sentense  = " . $fathom_object->words_per_sentence . "\n";
        #print " Syllables per words = " . $fathom_object->syllables_per_word . "\n";
        #print " Words     = " . $fathom_object->num_words . "\n";
        #print " Sentences = " . $fathom_object->num_sentences . "\n";
        #print "Kincaid = " . $fathom_object->kincaid . "\n";
    }
    else {
        print "Not enough content, length = " . length($$content) . "\n" if $debug;
    }

    #
    # Return readability scores
    #
    print "Readability_Grade_Text Fog = $fog, Flesch-Kincaid = $flesch_kincaid\n" if $debug;
    $readability_scores{"Fog"} = $fog;
    $readability_scores{"Flesch-Kincaid"} = $flesch_kincaid;
    return(%readability_scores);
}

#***********************************************************************
#
# Name: Readability_Grade_HTML
#
# Parameters: url - a URL
#             content - content pointer
#
# Description:
#
#   This function determines the readability level of text with 
# the content area of a text document.  The content area is delimited
# with marker comments.  If the content area cannot be located, or if
# there is insufficient text to analyse, this function returns -1 for
# both the fog and flesch-kincaid values.
#
# Returns
#   fog - Fog index for the text.
#   flesch_kincaid - Flesch-Kincaid grade level score for the text.
#
#***********************************************************************
sub Readability_Grade_HTML {
    my ($url, $content) = @_;

    my ($content_text, %readability_scores);

    #
    # Extract the content area from the HTML (paragraphs only).
    #
    $content_text = Extract_Paragraph_Text_From_HTML($content);
    #print "Readability_Grade_HTML, url = $url\n  content = \n-------------------\n$content_text\n----------------\n";

    #
    # Get readability grade level
    #
    %readability_scores = Readability_Grade_Text(\$content_text);
    #print "Flesch-Kincaid = " . $readability_scores{"Flesch-Kincaid"} ."\n";
    #print "Fog = " . $readability_scores{"Fog"} ."\n";

    #
    # Return readability scores
    #
    return(%readability_scores);
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

