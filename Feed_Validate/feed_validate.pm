#***********************************************************************
#
# Name:   feed_validate.pm
#
# $Revision: 7634 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Feed_Validate/Tools/feed_validate.pm $
# $Date: 2016-07-22 03:29:00 -0400 (Fri, 22 Jul 2016) $
#
# Description:
#
#   This file contains routines that validate Web feed (RSS & ATOM) content.
#
# Public functions:
#     Feed_Validate_Content
#     Feed_Validate_Language
#     Feed_Validate_Debug
#     Feed_Validate_Is_Web_Feed
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
use File::Temp qw/ tempfile tempdir /;
use XML::Parser;

#
# Use WPSS_Tool program modules
#
use tqa_result_object;

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
                  Feed_Validate_Is_Web_Feed
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths, $validate_cmnd);
my ($feed_type, $in_feed, $python_version, $is_windows);
my ($runtime_error_reported) = 0;

my ($debug) = 0;

my ($VALID_FEED) = 1;
my ($INVALID_FEED) = 0;

#
# String table for error strings.
#
my %string_table_en = (
    "Runtime Error",         "Runtime Error",
);

my %string_table_fr = (
    "Runtime Error",         "Erreur D'Ex�cution",
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

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
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Feed_Validate_Language, language = English\n" if $debug;
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
# Name: Check_Python_Version
#
# Parameters: None
#
# Description:
#
#   This function checks the version of Python installed.  The Web Feed
# Validator tool only runs in Python 2.
#
#***********************************************************************
sub Check_Python_Version {

    my ($python_file, $filename, $python_output, $output, $major, $minor);
    my ($linux_python);

    #
    # Have we already determined the Python version?
    #
    if ( ! defined($python_version) ) {
        #
        # Get python command.
        #
        if ( ! $is_windows ) {
            #
            # Check for python executable
            #
            $output = `which python 2>&1`;
            if ( $output =~ /no python in/i ) {
                #
                # No python, check for python3
                #
                $output = `which python3 2>&1`;
                if ( $output =~ /no python3 in/i ) {
                    print STDERR "Could not find python or python3\n";
                    $python_version = "Not installed";
                    return($python_version);
                }
                else {
                    $linux_python = "python3";
                }
            }
            else {
                #
                # Have python executable
                #
                $linux_python = "python";
            }
        }

        #
        # Write temporary program to get the python version
        #
        print "Check_Python_Version\n" if $debug;
        ($python_file, $filename) = tempfile("WPSS_TOOL_FEED_VALIDATE_XXXXXXXXXX",
                                             SUFFIX => '.py',
                                             TMPDIR => 1);
        print $python_file "import sys\n";
        print $python_file "print(sys.version_info)\n";
        print $python_file "print('Version: major:'+str(sys.version_info[0])+' minor:'+str(sys.version_info[1]))\n";
        close($python_file);

        #
        # Run the program
        #
        if ( $is_windows ) {
            $python_output = `$filename 2>\&1`;
        }
        else {
            $python_output = `$linux_python $filename 2>\&1`;
        }
        unlink($filename);

        #
        # Get major and minor release numbers
        #
        print "Version check output $python_output\n" if $debug;
        ($major) = $python_output =~ /major:\s*(\d).*/im;
        ($minor) = $python_output =~ /minor:\s*(\d).*/im;

        #
        # Check version
        #
        if ( defined($major) && defined($minor) ) {
            $python_version = "$major.$minor";
        }
        else {
            $python_version = "Unknown";
        }
        print "Found python version $python_version\n" if $debug;
    }

    #
    # Return the python version string
    #
    return($python_version);
}

#***********************************************************************
#
# Name: Run_Web_Feed_Validator
#
# Parameters: this_url - a URL
#
# Description:
#
#   This function runs the Feed validator on the supplied url
# and returns the validation status result.
#
#***********************************************************************
sub Run_Web_Feed_Validator {
    my ($this_url) = @_;

    my ($status) = $VALID_FEED;
    my ($validator_output, $line, $result_object, @results_list, $version);

    #
    # Check the version of Python, the PDF check tool only runs in
    # Python 2.
    #
    $version = Check_Python_Version();
    if ( ($version > 2.0) && ($version < 3.0) ) {
        #
        # Valid python version
        #
        print "Valid python version for Web Feed Validator\n" if $debug;
    }
    else {
        #
        # Runtime error, no valid Python version
        #
        if ( ! $runtime_error_reported ) {
            #
            # Create testcase result object
            #
            $result_object = tqa_result_object->new("XML_VALIDATION",
                                                    1, "XML_VALIDATION",
                                                    -1, -1, "",
                                                    String_Value("Runtime Error") .
                                                    " Invalid python version ($version) for Web Feed Validator",
                                                    $this_url);
            push (@results_list, $result_object);
            print STDERR "Runtime error, Invalid python version ($version) for Web Feed Validator\n";

            #
            # Suppress further errors
            #
            $runtime_error_reported = 1;
        }
        return(@results_list);
    }
    #
    # Run the validator on the supplied URL
    #
    print "Run validator\n --> $validate_cmnd $this_url 2>\&1\n" if $debug;
    $validator_output = `$validate_cmnd \"$this_url\" 2>\&1`;
    print "Validator output\n$validator_output\n" if $debug;

    #
    # Do we have no errors or warnings ?
    #
    if ( ! defined($validator_output) ||
        ($validator_output =~ /No errors or warnings/i) ) {
        print "Validation successful\n" if $debug;
    }
    #
    # Do we have validation errors ?
    #
    elsif ( $validator_output =~ /Validation failed/im ) {
        $status = $INVALID_FEED;
        $result_object = tqa_result_object->new("XML_VALIDATION",
                                                1, "XML_VALIDATION",
                                                -1, -1, "",
                                                $validator_output,
                                                $this_url);
        push (@results_list, $result_object);
    }
    else {
        #
        # An error trying to run the tool
        #
        print "Error running feedvalidator.py\n" if $debug;

        #
        # Report runtime error only once
        #
        if ( ! $runtime_error_reported ) {
            print STDERR "Error running feedvalidator.py\n";
            print STDERR "  $validate_cmnd $this_url 2>\&1\n";
            print STDERR "$validator_output\n";
            $result_object = tqa_result_object->new("XML_VALIDATION",
                                                    1, "XML_VALIDATION",
                                                    -1, -1, "",
                                                    String_Value("Runtime Error") .
                                                    " \"$validate_cmnd $this_url\"\n" .
                                                    " \"$validator_output\"",
                                                    $this_url);

            #
            # Reset the source line value of the testcase error result.
            # The initial setting may have been truncated while in this
            # case we want the entire value.
            #
            $result_object->source_line(String_Value("Runtime Error") .
                                        " \"$validate_cmnd $this_url\"\n" .
                                        " \"$validator_output\"");

            push (@results_list, $result_object);
            $runtime_error_reported = 1;
        }
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
#   This function handles the <feed> tag.  It sets the feed type.
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
# Name: Feed_Validate_Is_Web_Feed
#
# Parameters: this_url - a URL
#             content - content pointer
#
# Description:
#
#   This function checks to see if the suppliedt XML
# content is a web feed (RSS or Atom) or not.
#
#***********************************************************************
sub Feed_Validate_Is_Web_Feed {
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
    $eval_output = eval { $parser->parse($$content); } ;

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
#             content - XML content pointer
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
    if ( length($$content) > 0 ) {
        #
        # Run the web feed validator.
        #
        @results_list = Run_Web_Feed_Validator($this_url);
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
    $validate_cmnd = ".\\bin\\feedvalidator.py";
    $is_windows = 1;
} else {
    #
    # Not Windows.
    #
    $validate_cmnd = "$program_dir/bin/feedvalidator.py";
    $is_windows = 0;
}

#
# Return true to indicate we loaded successfully
#
return 1;

