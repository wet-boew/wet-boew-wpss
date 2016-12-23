#***********************************************************************
#
# Name:   xml_extract_links.pm
#
# $Revision: 6712 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Link_Check/Tools/xml_extract_links.pm $
# $Date: 2014-07-22 12:20:01 -0400 (Tue, 22 Jul 2014) $
#
# Description:
#
#   This file contains routines that parse XML (web feed) files to extract
# links.
#
# Public functions:
#     XML_Extract_Links_Debug
#     XML_Extract_Links
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

package xml_extract_links;

use strict;
use XML::Parser;
use File::Basename;
use URI::URL;

#
# Use WPSS_Tool program modules
#
use language_map;
use link_object;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(XML_Extract_Links_Debug
                  XML_Extract_Links
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my ($feed_lang, $in_feed, $link_object_reference, $current_lang);
my ($current_resp_base, $saved_text, $save_text_between_tags);

#***********************************************************************
#
# Name: XML_Extract_Links_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub XML_Extract_Links_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: Initialize_XML_Parser_Variables
#
# Parameters: none
#
# Description:
#
#   This function initializes the parser global variables
#
#***********************************************************************
sub Initialize_XML_Parser_Variables {
    my ($profile, $local_results_list_addr) = @_;

    #
    # Initialize flags and counters
    #
    $in_feed = 0;
    $feed_lang = "";
    $save_text_between_tags = 0;
    $saved_text = "";
}

#***********************************************************************
#
# Name: Make_URL_Absolute
#
# Parameters: url - extracted url
#             base - base to convert relative to absolute URLs
#
# Description:
#
#   This function converts a relative URL into absolute, domain
# qualified URL.
#
# Returns:
#   url
#
#***********************************************************************
sub Make_URL_Absolute {
    my ($url, $base) = @_;

    my ($protocol, $domain, $dir, $query);

    #
    # Extract the domain & directory portion from the URL
    #
    print "Make_URL_Absolute:\n" if $debug;
    print "  url  = $url\n" if $debug;
    print "  base = $base\n" if $debug;
    ($protocol, $domain, $dir, $query) = $base =~ /^(http[s]?:)\/\/?([^\/\s]+)\/([\/\w\-\.\%]*[^#?]*)(.*)?$/io;
    print "Protocol = $protocol, domain = $domain, dir = $dir, query = $query\n" if $debug;

    #
    # Convert domain portion to lowercase
    #
    $domain =~ tr/A-Z/a-z/;

    #
    # Clean up the directory portion
    #
    $dir =~ s/\/*$//g;

    #
    # If the original base had a trailing /, it was just a directory.
    # We have to replace the slash that was removed by the above
    # substitution.
    #
    if ( ($base =~ /\/$/) && ($dir ne "") ) {
        $dir .= "/";
    }

    #
    # Rebuild the base URL
    #
    $base = "$protocol//$domain/$dir$query";

    #
    # Convert relative URL into absolute
    #
    $url = url( $url, $base)->abs;

    #
    # Return absolute URL
    #
    print "New url = $url\n" if $debug;
    return($url);
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

#***********************************************************************
#
# Name: Get_Lang
#
# Parameters: tag - tagname
#             attr - hash table of attributes
#
# Description:
#
#   This function looks for a possible lang attribute. If found
# it converts a 2 character language code into a 3 character code.
# If no lang attribute is found, the current language code is used.
#
#***********************************************************************
sub Get_Lang {
    my ($tag, %attr) = @_;
    
    my ($lang);

    #
    # Do we have a hreflang attribute
    #
    if ( defined( $attr{"hreflang"} ) ) {
        $lang = $attr{"hreflang"};
        print "Get_Lang: Have hreflang = $lang attribute\n" if $debug;

        #
        # Remove any language dialect
        #
        $lang =~ s/-.*$//g;

        #
        # Convert possible 2 character code into a 3 character code.
        #
        if ( defined($language_map::iso_639_1_iso_639_2T_map{$lang}) ) {
            $lang = $language_map::iso_639_1_iso_639_2T_map{$lang};
        }
    }
    #
    # Do we have a lang attribute
    #
    elsif ( defined( $attr{"lang"} ) ) {
        $lang = lc($attr{"lang"});
        print "Get_Lang: Have lang = $lang attribute\n" if $debug;
        
        #
        # Remove any language dialect
        #
        $lang =~ s/-.*$//g;

        #
        # Convert possible 2 character code into a 3 character code.
        #
        if ( defined($language_map::iso_639_1_iso_639_2T_map{$lang}) ) {
            $lang = $language_map::iso_639_1_iso_639_2T_map{$lang};
        }
    }
    #
    # Do we have a xml:lang attribute
    #
    elsif ( defined( $attr{"xml:lang"} ) ) {
        $lang = lc($attr{"xml:lang"});
        print "Get_Lang: Have xml:lang = $lang attribute\n" if $debug;

        #
        # Remove any language dialect
        #
        $lang =~ s/-.*$//g;

        #
        # Convert possible 2 character code into a 3 character code.
        #
        if ( defined($language_map::iso_639_1_iso_639_2T_map{$lang}) ) {
            $lang = $language_map::iso_639_1_iso_639_2T_map{$lang};
        }
    }
    else {
        #
        # Use current language value
        #
        $lang = $current_lang;
        print "Get_Lang: Use current lang = $lang\n" if $debug;
    }
    
    #
    # Return language code
    #
    return($lang);
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

    my ($href, $lang, $abs_url, $link_object);

    #
    # Are we inside a web feed and do we have an href value ?
    #
    if ( $in_feed && defined($attr{"href"}) ) {
        $href = Clean_Text($attr{"href"});

        #
        # Do we have an href value ?
        #
        if ( $href ne "" ) {
            #
            # Convert href into an absolute URL
            #
            $abs_url = Make_URL_Absolute($href, $current_resp_base);
            print "Link tag with href = $href\n" if $debug;

            #
            # Do we have a lang attribute
            #
            $lang = Get_Lang("link", %attr);

            #
            # Save link details
            #
            $link_object = link_object->new($href, $abs_url, "",
                                            "link", $lang, -1, -1, "");
            $link_object->attr(%attr);
            push (@$link_object_reference, $link_object);
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
    # Found <feed> so this is a web feed
    #
    $in_feed = 1;
    print "XML document is an atom web feed\n" if $debug;

    #
    # Check for xml:lang attribute
    #
    if ( defined($attr{"xml:lang"}) ) {
        $current_lang = $attr{"xml:lang"};

        #
        # Remove any language dialect
        #
        $current_lang =~ s/-.*$//g;

        #
        # Convert possible 2 character code into a 3 character code.
        #
        if ( defined($language_map::iso_639_1_iso_639_2T_map{$current_lang}) ) {
            $current_lang = $language_map::iso_639_1_iso_639_2T_map{$current_lang};
        }
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
    # Found <rss> so this is a web feed
    #
    $in_feed = 1;
    print "XML document is an RSS web feed\n" if $debug;
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
    # Check for feed tag.
    #
    print "Start_Handler tag $tagname\n" if $debug;
    if ( $tagname eq "feed" ) {
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
    # Check for uri tag
    #
    elsif ( $tagname eq "uri" ) {
        URI_Tag_Handler($self, $tagname, %attr);
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
    # Web feed finished
    #
    $in_feed = 0;
    print "End of atom web feed\n" if $debug;
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
    # Web feed finished
    #
    $in_feed = 0;
    print "End of rss web feed\n" if $debug;
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

    my ($href, $abs_url, $link_object);

    #
    # Get the uri text
    #
    print "URI text = $saved_text\n" if $debug;

    #
    # Are we inside a feed ?
    #
    if ( $in_feed ) {
        $href = Clean_Text($saved_text);

        #
        # Do we have an href value ?
        #
        if ( $href ne "" ) {
            #
            # Convert href into an absolute URL
            #
            $abs_url = Make_URL_Absolute($href, $current_resp_base);

            #
            # Save link details
            #
            $link_object = link_object->new($href, $abs_url, "",
                                            "uri", $current_lang, -1, -1, "");
            print "Add uri link to list\n" if $debug;
            push (@$link_object_reference, $link_object);
        }
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
    # Check for feed tag
    #
    print "End_Handler tag $tagname\n" if $debug;
    if ( $tagname eq "feed" ) {
        End_Feed_Tag_Handler($self);
    }
    #
    # Check for rss tag
    #
    elsif ( $tagname eq "rss" ) {
        End_RSS_Tag_Handler($self);
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
# Name: XML_Extract_Links
#
# Parameters: this_url - URL of document to extract links from
#             this_base - the base value from the response object (resp->base)
#             this_lang - language of URL
#             content - content pointer
#
# Description:
#
#   This function extracts links from the supplied XML content and
# returns the details as an array of link objects.
#
#***********************************************************************
sub XML_Extract_Links {
    my ( $this_url, $this_base, $this_lang, $content ) = @_;

    my (@link_objects, $parser, $link, $eval_output);

    #
    # Save addresses of link object array in a global variable.
    #
    print "XML_Extract_Links: Checking URL $this_url\n" if $debug;
    $link_object_reference = \@link_objects;

    #
    # Save current language setting and response base value
    #
    $current_lang = $this_lang;
    $current_resp_base = $this_base;

    #
    # Initialize parser variables.
    #
    Initialize_XML_Parser_Variables;

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
        $parser->setHandlers(End => \&End_Handler);

        #
        # Parse the content.
        #
        $eval_output = eval { $parser->parse($$content); }
    }

    #
    # Return array of link objects
    #
    print "Found " . @link_objects . " links in XML content\n" if $debug;
    return(@link_objects);
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

