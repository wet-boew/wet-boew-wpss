#***********************************************************************
#
# Name:   xml_validate.pm
#
# $Revision: 6919 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/XML_Validate/Tools/xml_validate.pm $
# $Date: 2014-12-16 13:31:15 -0500 (Tue, 16 Dec 2014) $
#
# Description:
#
#   This file contains routines that validate XML content.
#
# Public functions:
#     XML_Validate_Content
#     XML_Validate_Language
#     XML_Validate_Debug
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

package xml_validate;

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
    @EXPORT  = qw(XML_Validate_Content
                  XML_Validate_Language
                  XML_Validate_Debug
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths, $validate_cmnd);

my ($debug) = 0;

my ($VALID_XML) = 1;
my ($INVALID_XML) = 0;

#********************************************************
#
# Name: XML_Validate_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub XML_Validate_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#********************************************************
#
# Name: XML_Validate_Language
#
# Parameters: language - language value
#
# Description:
#
#   This function sets the package language value.
#
#********************************************************
sub XML_Validate_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "XML_Validate_Language, language = French\n" if $debug;
    }
    else {
        #
        # Default language is English
        #
        print "XML_Validate_Language, language = English\n" if $debug;
    }
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
    # Check tags.
    #
    print "Start_Handler tag $tagname\n" if $debug;
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
    # Check tag
    #
    print "End_Handler tag $tagname\n" if $debug;
}

#***********************************************************************
#
# Name: General_XML_Validate
#
# Parameters: this_url - a URL
#             content - XML content pointer
#
# Description:
#
#   This function performas markup validation on XML content.
#
#***********************************************************************
sub General_XML_Validate {
    my ($this_url, $content) = @_;

    my ($parser, $eval_output, $result_object);

    #
    # Create a document parser
    #
    print "General_XML_Validate\n" if $debug;
    $parser = XML::Parser->new;

    #
    # Add handlers for some of the XML tags
    #
    $parser->setHandlers(Start => \&Start_Handler);
    $parser->setHandlers(End => \&End_Handler);

    #
    # Parse the content.
    #
    eval { $parser->parse($$content, ErrorContext => 2); };
    $eval_output = $@ if $@;

    #
    # Do we have any parsing errors ?
    #
    if ( defined($eval_output) ) {
        $eval_output =~ s/\n at .* line \d*$//g;
        $eval_output =~ s/\n at .* line \d* thread \d*\.$//g;
        print "Validation failed \"$eval_output\"\n" if $debug;
        $result_object = tqa_result_object->new("XML_VALIDATION",
                                                1, "XML_VALIDATION",
                                                -1, -1, "",
                                                $eval_output,
                                                $this_url);
    }

    #
    # Return result list
    #
    return($result_object);
}

#***********************************************************************
#
# Name: XML_Validate_Content
#
# Parameters: this_url - a URL
#             content - XML content pointer
#
# Description:
#
#   This function runs the Web feed validator on the supplied content
# and returns the validation status result.
#
#***********************************************************************
sub XML_Validate_Content {
    my ($this_url, $content) = @_;

    my (@results_list, $result_object);

    #
    # Do we have any content ?
    #
    print "XML_Validate_Content, validate $this_url\n" if $debug;
    if ( length($$content) > 0 ) {
        #
        # Determine if the XML document is a Web Feed.
        #
        if ( Feed_Validate_Is_Web_Feed($this_url, $content) ) {
            print "Validate XML Web feed content\n" if $debug;
            @results_list = Feed_Validate_Content($this_url, $content);
        }
        #
        # Determine if the XML document is TTML.
        #
        elsif ( XML_TTML_Validate_Is_TTML($this_url, $content) ) {
            print "Validate TTML XML content\n" if $debug;
            @results_list = XML_TTML_Validate_Content($this_url, $content);
        }

        #
        # General XML validation.  We do this regardless whether or not
        # there was a content specific validation.
        #
        print "Validate general XML content\n" if $debug;
        $result_object = General_XML_Validate($this_url, $content);
        if ( defined($result_object) ) {
            push(@results_list, $result_object);
        }
    }
    else {
        #
        # No content
        #
        print "No content passed to XML_Validate_Content\n" if $debug;
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
    my (@package_list) = ("feed_validate", "tqa_result_object",
                          "xml_ttml_validate");

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

