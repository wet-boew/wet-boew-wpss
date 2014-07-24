#***********************************************************************
#
# Name:   css_validate.pm
#
# $Revision: 6706 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/CSS_Validate/Tools/css_validate.pm $
# $Date: 2014-07-22 12:17:06 -0400 (Tue, 22 Jul 2014) $
#
# Description:
#
#   This file contains routines that extract inline CSS from HTML as well
# as validate CSS content.
#
# Public functions:
#     CSS_Validate_Debug
#     CSS_Validate_Content
#     CSS_Validate_Extract_CSS_From_HTML
#     CSS_Validate_Language
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

package css_validate;

use strict;
use File::Basename;
use HTML::Parser;
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
    @EXPORT  = qw(CSS_Validate_Content
                  CSS_Validate_Debug
                  CSS_Validate_Extract_CSS_From_HTML
                  CSS_Validate_Language
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);
my ($validate_cmnd, $extracted_css_content, $have_text_handler);
my ($last_style_end, $inline_style_count);

my ($debug) = 0;

my ($VALID_CSS) = 1;
my ($INVALID_CSS) = 0;

#
# Default language is English
#
my ($language) = "eng";

#********************************************************
#
# Name: CSS_Validate_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub CSS_Validate_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#********************************************************
#
# Name: CSS_Validate_Language
#
# Parameters: this_language - language value
#
# Description:
#
#   This function sets the package language value.
#
#********************************************************
sub CSS_Validate_Language {
    my ($this_language) = @_;

    #
    # Set global language
    #
    if ( $this_language =~ /^fr/i ) {
        $language = "fra";
    }
    else {
        $language = "eng";
    }
}

#***********************************************************************
#
# Name: CSS_Validate_Content
#
# Parameters: this_url - a URL
#             content - CSS content pointer
#
# Description:
#
#   This function runs the CSS validator on the supplied URL
# and returns the validation status and results.
#
#***********************************************************************
sub CSS_Validate_Content {
    my ($this_url, $content) = @_;

    my ($validator_output, $format, $temp_file_name);
    my (@results_list, $result_object, $fh);
    my ($in_error) = 0;
    my ($errors) = "";

    #
    # Create temporary file for CSS content.
    #
    print "CSS_Validate_Content create temporary css file\n" if $debug;
    ($fh, $temp_file_name) = tempfile( SUFFIX => '.css');
    if ( ! defined($fh) ) {
        print "Error: Failed to create temporary file in CSS_Validate_Content\n";
        return(@results_list);
    }
    binmode $fh;
    print $fh $$content;
    close($fh);

    #
    # Set tool output language
    #
    if ( $language =~ /^fr/ ) {
        $format = "-lang fr";
    }
    else {
        $format = "-lang en";
    }

    #
    # Run the validator on the supplied content
    #
    print "Run validator\n --> $validate_cmnd $format file:$temp_file_name 2>\&1\n" if $debug;
    $validator_output = `$validate_cmnd $format file:$temp_file_name 2>\&1`;
    print "Validator output = $validator_output\n" if $debug;
    unlink($temp_file_name);

    #
    # Read the output from the validator looking for errors
    #
    foreach (split(/\n/, $validator_output)) {

        #
        # Are we at the end of the errors section ?
        #
        if ( (/^Valid CSS information/i) ||
             (/^Votre feuille de style CSS/i) ) {
            last;
        }
        #
        # Are we at the beginning of the warnings section ?
        #
        elsif ( (/^Warnings /i) ||
             (/^Avertissements /i) ) {
            last;
        }
        #
        # Skip URI lines
        #
        elsif (/^URI :/) {
            next;
        }
        #
        # Skip blank lines
        #
        elsif (/^$/) {
            $in_error = 0;
            next;
        }
        #
        # Look for line number that starts an error
        #
        elsif (/^\s*Line : /) {
            $in_error = 1;
            $errors .= $_ . "\n";
        }
        else {
            #
            # Unrecognized line, are we within an error block ?
            #
            if ( $in_error ) {
                    $errors .= $_ . "\n";
            }
        }
    }

    #
    # Did we find any errors ?
    #
    if ( $errors ne "" ) {
        $result_object = tqa_result_object->new("CSS_VALIDATION",
                                                1,
                                                "CSS_VALIDATION",
                                                -1, -1, "",
                                                $errors, $this_url);
        push (@results_list, $result_object);
    }

    #
    # Return results
    #
    return(@results_list);
}

#***********************************************************************
#
# Name: Initialize_Parser_Variables
#
# Parameters: none
#
# Description:
#
#   This function initializes variables used by the parser.
#
#***********************************************************************
sub Initialize_Parser_Variables {

    #
    # Initialize global variables
    #
    $last_style_end = 1;
    $inline_style_count = 0;
}

#***********************************************************************
#
# Name: Style_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles style tags. It starts a text handler
# to capture the text between the <style> and </style> tags.  It
# adds blank lines to the text handler to account for the skipped
# HTML lines (to keep the CSS line count in line with the original
# HTML line count).
#
#***********************************************************************
sub Style_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;
    
    my ($i);

    #
    # Add a text handler to save the text portion of the style
    # tag.
    #
    print "Found <style> at line $line\n" if $debug;
    $self->handler( text => [], '@{dtext}' );
    $have_text_handler = 1;

    #
    # Insert blank lines to account for the space between
    # the last </style> and this <style>.  This allows
    # line numbers of CSS analysis tools to match the
    # original HTML input.
    #
    for ($i = $last_style_end; $i < $line; $i++) {
        push( @{ $self->handler("text") }, "\n" );
    }
}

#***********************************************************************
#
# Name: Inline_Style_Handler
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles inline styles.  It creates a local style
# and saves the content of the "style" attribute in it.  The local
# style is named after the tag it is found in.
#
#***********************************************************************
sub Inline_Style_Handler {
    my ( $tagname, $line, $column, $text, %attr ) = @_;

    my ($i, $style_name);

    #
    # Insert blank lines to account for the space between
    # the last </style> and this <style>.  This allows
    # line numbers of CSS analysis tools to match the
    # original HTML input.
    #
    print "Found style= at line $line\n" if $debug;
    for ($i = $last_style_end; $i < $line; $i++) {
        $extracted_css_content .= "\n";
    }

    #
    # Create a local style name
    #
    $inline_style_count++;
    $style_name = "$tagname.inline$inline_style_count";

    #
    # Write style information
    #
    $extracted_css_content .= "$style_name {" . $attr{"style"} . "}";

    #
    # Save the location of this "style" attribute, we need it
    # if there are more styles and we want to know
    # how many HTML content lines are between them.
    #
    $last_style_end = $line;
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
# handles the start of HTML tags.  Tag specific functions are called
# to handle specific tags.
#
#***********************************************************************
sub Start_Handler {
    my ( $self, $tagname, $line, $column, $text, $skipped_text, @attr) = @_;

    my (%attr_hash) = @attr;

    #
    # Check style tags
    #
    if ( $tagname eq "style" ) {
        Style_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check for style attribute on the tag.
    #
    if ( defined($attr_hash{"style"}) ) {
        Inline_Style_Handler($tagname, $line, $column, $text, %attr_hash);
    }
}

#***********************************************************************
#
# Name: End_Style_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end style tag.  All the text captured between the start
# and end style is saved in a global variable.  Any @import CSS
# calls are stripped from the content, these lines will trigger
# validation errors if they reference local files.
#
#***********************************************************************
sub End_Style_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($this_text, @text_list);
    my ($all_text) = "";

    #
    # Get all the text found within the style tag
    #
    print "Found </style> at line $line\n" if $debug;
    if ( ! $have_text_handler ) {
        print "End style tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }
    @text_list = @{ $self->handler("text") };

    #
    # Get the style text as a string.
    #
    $all_text = join(" ", @text_list);

    #
    # Remove any @import lines.  These may not make sense when analysing
    # a block of CSS as the URL may relative and we don't have a base
    # URL to work with.
    #
    $all_text =~ s/\@import\s+.*?(;|$)//g;
    print "End_Style_Tag_Handler: Add $all_text to extracted CSS text\n" if $debug;

    #
    # Append text to global variable
    #
    $extracted_css_content .= " " . $all_text;

    #
    # Destroy the text handler that was used to save the text
    # portion of the style tag.
    #
    $self->handler( "text", undef );
    $have_text_handler = 0;

    #
    # Save the location of this </style> tag, we need it
    # if there are more <style> tags and we want to know
    # how many HTML content lines are between them.
    #
    $last_style_end = $line;
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
# handles the end of HTML tags. Tag specific functions are called
# to handle specific tags.
#
#***********************************************************************
sub End_Handler {
    my ( $self, $tagname, $line, $column, $text, @attr ) = @_;

    my (%attr_hash) = @attr;

    #
    # Check style tag
    #
    if ( $tagname eq "style" ) {
        End_Style_Tag_Handler($self, $line, $column, $text);
    }
}

#***********************************************************************
#
# Name: CSS_Validate_Extract_CSS_From_HTML
#
# Parameters: this_url - a URL
#             content - HTML content pointer
#
# Description:
#
#   This function extracts any inline CSS styles from the HTML text. The
# HTML content is parsed with the text from <style> tags returned as the
# CSS content.
#
#***********************************************************************
sub CSS_Validate_Extract_CSS_From_HTML {
    my ($this_url, $content) = @_;

    my ($parser);

    #
    # Do we have any content ?
    #
    print "CSS_Validate_Extract_CSS_From_HTML: Extract CSS from $this_url\n" if $debug;
    $extracted_css_content = "";
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
            "self,tagname,line,column,text,skipped_text,\@attr"
        );
        $parser->handler(
            end => \&End_Handler,
            "self,tagname,line,column,text,\@attr"
        );

        #
        # Initialize parser variables
        #
        Initialize_Parser_Variables();

        #
        # Parse the content.
        #
        $have_text_handler = 0;
        $parser->parse($$content);
        print "Extracted CSS content\n$extracted_css_content\n" if $debug;
    }
    else {
        print "No content passed to CSS_Validate_Extract_CSS_From_HTML\n" if $debug;
    }

    #
    # Return extracted CSS content.
    #
    return ($extracted_css_content);
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
# Set validator command and options
#   -profile css3 = validate to CSS3
#   -warning -1 = suppress warnings
#   -vextwarning true = treat vendor extensions as warnings
#
$validate_cmnd = "java -classpath $program_dir/lib/css-validator.jar;" .
                 "$program_dir/lib/jigsaw.jar;" .
                 "$program_dir/lib/velocity.jar;" .
                 "$program_dir/lib/tagsoup.jar;" .
                 "$program_dir/lib/commons-lang.jar;" .
                 "$program_dir/lib/commons-collections.jar;" .
                 "$program_dir/lib/xercesImpl.jar " .
                 "org.w3c.css.css.CssValidator " .
                 "-profile css3 -warning -1 -vextwarning true";

#
# Check for operating system specifics
#
if ( !( $^O =~ /MSWin32/ ) ) {
    #
    # Not Windows, change ; separator to : separator in class path,
    # add LANG environment variable setting for Unix.
    #
    $validate_cmnd =~ s/;/:/g;
    $validate_cmnd = "LANG=en_US.ISO8859-1;export LANG;" . $validate_cmnd;
}

#
# Import required packages
#
Import_Packages;

#
# Return true to indicate we loaded successfully
#
return 1;

