#***********************************************************************
#
# Name: extract_anchors.pm	
#
# $Revision: 7400 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Link_Check/Tools/extract_anchors.pm $
# $Date: 2015-12-18 05:17:40 -0500 (Fri, 18 Dec 2015) $
#
# Description:
#
#   This file contains routines that parse HTML content to extract
# named anchors (e.g. <a name="top">).
#
# Public functions:
#     Extract_Anchors
#     Extract_Anchors_Debug
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

package extract_anchors;

use strict;
use HTML::Parser;
use File::Basename;

#
# Use WPSS_Tool program modules
#
use crawler;
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
    @EXPORT  = qw(Extract_Anchors
                  Extract_Anchors_Debug);
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my ($named_anchor_list, %anchor_url_hits, %anchor_url_anchors);
my (%url_anchor_hits, %url_anchor_anchors);
my ($url_anchor_count) = 0;
my ($MAX_url_anchor_count)   = 10000;
my ($Clean_url_anchor_count) =  7500;

#********************************************************
#
# Name: Extract_Anchors_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Extract_Anchors_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: Clean_URL_Anchor_List
#
# Parameters: none
#
# Description:
#
#   This function updates the global url/anchor hash tables.  It
# goes through the tables, removing URLs with the lowest hit
# count, until there is sufficient room for new URL additions.
#
# Returns:
#   Nothing
#
#***********************************************************************
sub Clean_URL_Anchor_List {
    my ($url, $hits);
    my ($current_hit_count) = 1;

    #
    # Loop until the URL count is below the threshold
    #
    while ( $url_anchor_count > $Clean_url_anchor_count ) {

        #
        # Loop through the URL list looking for URLs with a hit count
        # less than or equal to the current hit count
        #
        while ( ($url, $hits) = each %url_anchor_hits ) {
            if ( $hits <= $current_hit_count ) {
                #
                # Remove this URL from the hash tables and decrement the
                # number of URLs in the list.
                #
                delete $url_anchor_hits{$url};
                delete $url_anchor_anchors{$url};
            }
        }

        #
        # Increment the hit counter for the next pass
        #
        $current_hit_count++;
        $url_anchor_count = keys(%url_anchor_hits);
    }
}

#***********************************************************************
#
# Name: Initialize_Parser_Variables
#
# Parameters: none
#
# Description:
#
#   This function initializes parser settings and global variables
#
#***********************************************************************
sub Initialize_Parser_Variables {

    #
    # Initialize variables
    #
    $named_anchor_list = " ";
}

#***********************************************************************
#
# Name: Anchor_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles anchor tags.
#
#***********************************************************************
sub Anchor_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($name);

    #
    # Do we have a name attribute ?
    #
    if ( defined($attr{"name"}) ) {
        #
        # Remove leading and trailing white space.
        #
        $name = $attr{"name"};
        $name =~ s/^\s*//g;
        $name =~ s/\s*$//g;
        print "Anchor_Tag_Handler, name = \"$name\" an $line:$column\n" if $debug;

        #
        # Do we have a value ?
        # as the validator will catch it.
        #
        if ( $name ne "" ) {
            #
            # Save anchor name in global list of anchors.
            #
            $named_anchor_list .= "$name " ;
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
    my ($self, $tagname, $line, $column, $text, %attr) = @_;

    my ($id);

    #
    # Check anchor tag
    #
    if ( $tagname eq "a" ) {
        Anchor_Tag_Handler( $self, $line, $column, $text, %attr );
    }

    #
    # Check for an id attribute
    #
    if ( defined($attr{"id"}) ) {
        $id = $attr{"id"};
        $id =~ s/^\s*//g;
        $id =~ s/\s*$//g;
        print "Start_Handler, tag = $tagname, id= \"$id\" at $line:$column\n" if $debug;

        #
        # Do we have a value ?
        #
        if ( $id ne "" ) {
            #
            # Save anchor name in global list of anchors.
            #
            $named_anchor_list .= "$id " ;
        }
    }
}

#***********************************************************************
#
# Name: Extract_Anchors
#
# Parameters: this_url - URL of document to extract links from
#             resp - HTTP::Response object
#             content - content pointer
#             force_refresh - flag to force a refresh of the anchor list
#
# Description:
#
#   This function extracts named anchors from the supplied HTML content and
# returns then as a list.
#
#***********************************************************************
sub Extract_Anchors {
    my ($this_url, $resp, $content, $force_refresh) = @_;

    my ($parser, $protocol, $domain, $dir, $query, $new_url);

    #
    # Extract components of the URL, we want to strip off any named anchors
    # from the URL.
    #
    print "Extract_Anchors: Checking URL $this_url\n" if $debug;
    if ( $this_url =~ /^http/ ) {
        ($protocol, $domain, $dir, $query, $new_url) = 
            URL_Check_Parse_URL($this_url);

        #
        # Do we have a leading # in the query field ?
        #
        if ( $query =~ /#/ ) {
            print "Strip anchor from URL $this_url\n" if $debug;
            $this_url =~ s/#.*//g;
        }
    }

    #
    # Have we aready seen this URL ?
    #
    if ( defined($url_anchor_anchors{$this_url}) ) {
        #
        # Increment hit count and return list of anchors
        #
        $named_anchor_list = $url_anchor_anchors{$this_url};
        $url_anchor_hits{$this_url}++;
        
        #
        # Is a refresh of the anchor list being forced ? (e.g. for
        # generated markup versus original markup)
        #
        if ( $force_refresh ) {
            print "Force refresh of anchor list\n" if $debug;
        }
        else {
            print "Return cached anchor list for URL $this_url\n" if $debug;
            print "Anchors = $named_anchor_list\n" if $debug;
            return($named_anchor_list);
        }
    }

    #
    # Do we have to get the content from the HTTP::Response object
    #
    if ( ($$content eq "") && defined($resp) ) {
        $$content = Crawler_Decode_Content($resp);
    }

    #
    # Initialize parser variables.
    #
    Initialize_Parser_Variables;

    #
    # Did we get any content ?
    #
    if ( length($$content) > 0 ) {
        #
        # Create a document parser
        #
        $parser = HTML::Parser->new;

        #
        # Add handlers for some of the HTML tags
        #
        $parser->handler(
            start => \&Start_Handler,
            "self,tagname,line,column,text,\@attr"
        );

        #
        # Parse the content.
        #
        $parser->parse($$content);
    }
    else {
        print "Extract_Anchors: no content in document\n" if $debug;
    }

    #
    # A URL we have not seen yet.  Before we record its
    # list of anchors, check the number of URLs to see that
    # we don't have too many.  If we do we must clean up
    # the hash table to control our memory usage.
    #
    if ( $url_anchor_count > $MAX_url_anchor_count ) {
        Clean_URL_Anchor_List;
    }

    #
    # Save list of anchors for quick access in the future.
    #
    $url_anchor_hits{$this_url} = 1;
    $url_anchor_anchors{$this_url} = $named_anchor_list;
    $url_anchor_count++;

    #
    # Return list of anchors
    #
    print "Extract_Anchors: Return anchor list for URL $this_url\n" if $debug;
    print "Anchors = $named_anchor_list\n" if $debug;
    return($named_anchor_list);
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

