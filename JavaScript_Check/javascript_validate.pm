#***********************************************************************
#
# Name:   javascript_validate.pm
#
# $Revision: 6636 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/JavaScript_Check/Tools/javascript_validate.pm $
# $Date: 2014-04-30 08:07:30 -0400 (Wed, 30 Apr 2014) $
#
# Description:
#
#   This file contains routines that validate JavaScript content.
#
# Public functions:
#     JavaScript_Validate_JSL_Config
#     JavaScript_Validate_Content
#     JavaScript_Validate_Debug
#     JavaScript_Validate_Extract_JavaScript_From_HTML
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

package javascript_validate;

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
    @EXPORT  = qw(JavaScript_Validate_JSL_Config
                  JavaScript_Validate_Content
                  JavaScript_Validate_Debug
                  JavaScript_Validate_Extract_JavaScript_From_HTML

                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths, $validate_cmnd);
my (%jsl_config_file_profile_map, $extracted_javascript_content);
my ($have_text_handler, $last_script_end);

my ($debug) = 0;

my ($VALID_JAVASCRIPT) = 1;
my ($INVALID_JAVASCRIPT) = 0;

#***********************************************************************
#
# Name: JavaScript_Validate_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub JavaScript_Validate_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: JavaScript_Validate_JSL_Config
#
# Parameters: profile - jsl configuration profile name
#             filename - jsl configuration file name
#
# Description:
#
#   This function assigns a profile name to a jsl configuration file.
# The configuration file is used to enab;e or disable specific jsl
# warnings and other settings.
#
#***********************************************************************
sub JavaScript_Validate_JSL_Config {
    my ($profile, $filename) = @_;

    #
    # Check to see that the configuration file is available.
    #
    if ( ! -f "$filename" ) {
        print "Error: JSL configuration file is not available\n";
        print " --> $filename\n";
        exit(1);
    }

    #
    # Save configuration file name in a global hash table indexed
    # by the profile name.
    #
    $jsl_config_file_profile_map{$profile} = $filename;
}

#***********************************************************************
#
# Name: JavaScript_Validate_Content
#
# Parameters: this_url - a URL
#             profile - name of JSL configuration profile
#             content - JavaScript content
#
# Description:
#
#   This function runs the JavaScript validator on the supplied content
# and returns the validation status and results.
#
#***********************************************************************
sub JavaScript_Validate_Content {
    my ($this_url, $profile, $content) = @_;

    my ($validator_output, $line, $filename, $cmnd);
    my (@results_list, $result_object, $fh);

    #
    # Do we have any content ?
    #
    if ( length($content) > 0 ) {
        #
        # Write the content to a temporary file
        #
        print "Create temporary JS file\n" if $debug;
        ($fh, $filename) = tempfile( SUFFIX => '.js');
        if ( ! defined($fh) ) {
            print "Error: Failed to create temporary file in JavaScript_Validate_Content\n";
            return(@results_list);
        }
        binmode $fh;
        print $fh $content;
        close($fh);

        #
        # Do we have a valid profile ?
        #
        if ( defined($profile) && 
             defined($jsl_config_file_profile_map{$profile}) ) {
            $cmnd = "$validate_cmnd -conf " . 
                     $jsl_config_file_profile_map{$profile} . " ";
        }
        else {
            $cmnd = "$validate_cmnd ";
        }

        #
        # Run the validator on the supplied content
        #
        $cmnd .= "-process $filename";
        print "Run validator\n --> $cmnd 2>\&1\n" if $debug;
        $validator_output = `$cmnd 2>\&1`;
        print "Validator output = $validator_output\n" if $debug;

        #
        # Did we get any output ?
        #
        if ( $validator_output ne "" ) {
            $result_object = tqa_result_object->new("JAVASCRIPT_VALIDATION",
                                                    1,
                                                    "JAVASCRIPT_VALIDATION",
                                                    -1, -1, "",
                                                    $validator_output,
                                                    $this_url);
            push (@results_list, $result_object);
        }

        #
        # Clean up temporary files
        #
        unlink($filename);
    }
    else {
        #
        # No content, fails validation
        #
        print "No content passed to JavaScript_Validate_Content\n" if $debug;
    }

    #
    # Return status
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
    $last_script_end = 1;
}

#***********************************************************************
#
# Name: Script_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles script tags.
#
#***********************************************************************
sub Script_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($i);
    
    #
    # Check the script type, must be text/javascript
    #
    if ( defined($attr{"type"}) &&
         ($attr{"type"} eq "text/javascript") ) {

        #
        # Do we have a src attribute ? This means the JavaScript is
        # in a file rather than inline.
        #
        if ( ! defined($attr{"src"}) ) {
            #
            # Got inline JavaScript, start a text handler to capture
            # the text.
            #
            print "Start inline JavaScript at $line\n" if $debug;
            $self->handler( text => [], '@{dtext}' );
            $have_text_handler = 1;
            
            #
            # Insert blank lines to account for the space between
            # the last </script> and this <script>.  This allows
            # line numbers of JavaScript analysis tools to match the
            # original HTML input.
            #
            for ($i = $last_script_end; $i < $line; $i++) {
                push( @{ $self->handler("text") }, "\n" );
            }
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
    my ( $self, $tagname, $line, $column, $text, $skipped_text, @attr) = @_;

    my (%attr_hash) = @attr;

    #
    # Check script tags
    #
    if ( $tagname eq "script" ) {
        Script_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
}

#***********************************************************************
#
# Name: End_Script_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end script tag.  All the text captured between the start
# and end script is saved in a global variable.
#
#***********************************************************************
sub End_Script_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($this_text, @text_list);
    my ($all_text) = "";

    #
    # Get all the text found within the script tag
    #
    if ( ! $have_text_handler ) {
        #
        # No text handler, it may have been a script tag specifying
        # a JavaScript file rather than inline code.
        #
        return;
    }
    print "Stop inline JavaScript at $line\n" if $debug;
    @text_list = @{ $self->handler("text") };

    #
    # Get the script text as a string.
    #
    $all_text = join(" ", @text_list);

    #
    # Append text to global variable
    #
    $extracted_javascript_content .= " " . $all_text;

    #
    # Destroy the text handler that was used to save the text
    # portion of the script tag.
    #
    $self->handler( "text", undef );
    $have_text_handler = 0;
    
    #
    # Save the location of this </script> tag, we need it
    # if there are more <script> tags and we want to know
    # how many HTML content lines are between them.
    #
    $last_script_end = $line;
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

    #
    # Check script tag
    #
    if ( $tagname eq "script" ) {
        End_Script_Tag_Handler($self, $line, $column, $text);
    }
}

#***********************************************************************
#
# Name: JavaScript_Validate_Extract_JavaScript_From_HTML
#
# Parameters: this_url - a URL
#             content - HTML content
#
# Description:
#
#   This function extracts any inline JavaScript scripts from the HTML text.
#
#***********************************************************************
sub JavaScript_Validate_Extract_JavaScript_From_HTML {
    my ($this_url, $content) = @_;

    my ($parser);

    #
    # Do we have any content ?
    #
    print "JavaScript_Validate_Extract_JavaScript_From_HTML: Extract JavaScript from $this_url\n" if $debug;
    $extracted_javascript_content = "";
    if ( length($content) > 0 ) {
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
        $parser->parse($content);
        print "Extracted JavaScript content\n$extracted_javascript_content\n" if $debug;
    }
    else {
        print "No content passed to JavaScript_Validate_Extract_JavaScript_From_HTML\n" if $debug;
    }

    #
    # Return extracted JavaScript content.
    #
    return ($extracted_javascript_content);
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
# Generate path the validate command.
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $validate_cmnd = "jsl.exe";
} else {
    #
    # Not Windows.
    #
    $validate_cmnd = "$program_dir/jsl";
}

#
# Check to see that the jsl program exists.
#
if ( ! -f $validate_cmnd ) {
    print "Error: jsl program not available\n";
    print " --> $validate_cmnd\n";
    exit(1);
}

#
# Add commad line arguments to eliminate unneeded output
#
$validate_cmnd .= " -nologo -nosummary -nofilelisting";

#
# Add to path for shared libraries (Solaris only)
#
if ( defined $ENV{LD_LIBRARY_PATH} ) {
    $ENV{LD_LIBRARY_PATH} .= ":/usr/local/lib:/opt/sfw/lib";
}
else {
    $ENV{LD_LIBRARY_PATH} = "/usr/local/lib:/opt/sfw/lib";
}

#
# Import required packages
#
Import_Packages;

#
# Return true to indicate we loaded successfully
#
return 1;

