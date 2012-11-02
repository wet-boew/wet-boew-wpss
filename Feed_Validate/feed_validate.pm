#***********************************************************************
#
# Name:   feed_validate.pm
#
# $Revision: 5860 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/HTML_Validate/Tools/feed_validate.pm $
# $Date: 2012-05-29 11:36:26 -0400 (Tue, 29 May 2012) $
#
# Description:
#
#   This file contains routines that validate Web feed (RSS & ATOM) content.
#
# Public functions:
#     Feed_Validate_Content
#     Feed_Validate_Language
#     Feed_Validate_Debug
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

package feed_validate;

use strict;
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
    @EXPORT  = qw(Feed_Validate_Content
                  Feed_Validate_Language
                  Feed_Validate_Debug
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths, $validate_cmnd);
my ($feed_type, $in_feed);

my ($debug) = 0;

my ($VALID_FEED) = 1;
my ($INVALID_FEED) = 0;

#********************************************************
#
# Name: Feed_Validate_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Feed_Validate_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#********************************************************
#
# Name: Feed_Validate_Language
#
# Parameters: language - language value
#
# Description:
#
#   This function sets the package language value.
#
#********************************************************
sub Feed_Validate_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Feed_Validate_Language, language = French\n" if $debug;
    }
    else {
        #
        # Default language is English
        #
        print "Feed_Validate_Language, language = English\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Run_Web_Feed_Validator
#
# Parameters: this_url - a URL
#             content - HTML content
#
# Description:
#
#   This function runs the Feed validator on the supplied content
# and returns the validation status result.
#
#***********************************************************************
sub Run_Web_Feed_Validator {
    my ($this_url, $content) = @_;

    my ($status) = $VALID_FEED;
    my ($validator_output, $line, $result_object, @results_list);

    #
    # Run the validator on the supplied URL
    #
    print "Run validator\n --> $validate_cmnd $this_url 2>\&1\n" if $debug;
    $validator_output = `$validate_cmnd $this_url 2>\&1`;
print "Validator output\n$validator_output\n" if $debug;

    #
    # Do we have no errors or warnings ?
    #
    if ( ! defined($validator_output) ||
        ($validator_output =~ /No errors or warnings/i) ) {
        print "Validation successful\n" if $debug;
    }
    else {
        $status = $INVALID_FEED;
        $result_object = tqa_result_object->new("FEED_VALIDATION",
                                                1, "FEED_VALIDATION",
                                                -1, -1, "",
                                                $validator_output,
                                                $this_url);
        push (@results_list, $result_object);
    }

    #
    # Return result list
    #
    print "Run_Web_Feed_Validator status = $status\n" if $debug;
    return(@results_list);
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
        print "Atom feed\n" if $debug;
        $feed_type = "atom";
        $in_feed = 1;
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
# Name: Start_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the start of XML tags.
#
#***********************************************************************
sub Start_Handler {
    my ($self, $tagname, %attr) = @_;

    my ($key, $value);

    #
    # Check for feed tag, indicating this is an Atom feed.
    #
    if ( $tagname eq "feed" ) {
        Feed_Tag_Handler($self, $tagname, %attr);
    }
    #
    # Check for rss tag, indicating this is an RSS feed.
    #
    elsif ( $tagname eq "rss" ) {
        RSS_Tag_Handler($self, $tagname, %attr);
    }
}

#***********************************************************************
#
# Name: Is_Web_Feed
#
# Parameters: this_url - a URL
#             content - content
#
# Description:
#
#   This function runs a number of interoperability QA checks the content.
#
#***********************************************************************
sub Is_Web_Feed {
    my ( $this_url, $content) = @_;

    my ($parser, $eval_output);

    #
    # Initialize global variables.
    #
    $feed_type = "";
    $in_feed = 0;

    #
    # Create a document parser
    #
    $parser = XML::Parser->new;

    #
    # Add handlers for some of the XML tags
    #
    $parser->setHandlers(Start => \&Start_Handler);

    #
    # Parse the content.
    #
    $eval_output = eval { $parser->parse($content); } ;

    #
    # Did we find an RSS or atom feed type ?
    #
    if ( $feed_type ne "" ) {
        print "URL is a $feed_type Web feed\n" if $debug;
        return(1);
    }
    else {
        print "URL is not a Web feed\n" if $debug;
        return(0);
    }
}

#***********************************************************************
#
# Name: Feed_Validate_Content
#
# Parameters: this_url - a URL
#             content - XML content
#
# Description:
#
#   This function runs the Web feed validator on the supplied content
# and returns the validation status result.
#
#***********************************************************************
sub Feed_Validate_Content {
    my ($this_url, $content) = @_;

    my (@results_list);

    #
    # Do we have any content ?
    #
    print "Feed_Validate_Content, validate $this_url\n" if $debug;
    if ( length($content) > 0 ) {

        #
        # Determine if the XML document is a Web Feed.
        #
        if ( Is_Web_Feed($this_url, $content) ) {

            #
            # Run the web feed validator.
            #
            @results_list = Run_Web_Feed_Validator($this_url, $content);
        }
        else {
            print "Not a Web feed\n" if $debug;
        }
    }
    else {
        #
        # No content
        #
        print "No content passed to Feed_Validate_Content\n" if $debug;
    }

    #
    # Return result list
    #
    return(@results_list);
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
    my (@package_list) = ("tqa_result_object");

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
# Generate path the validate command
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $validate_cmnd = "feedvalidator.py";
} else {
    #
    # Not Windows.
    #
    $validate_cmnd = "$program_dir/feedvalidator.py";
}

#
# Import required packages
#
Import_Packages;

#
# Return true to indicate we loaded successfully
#
return 1;

