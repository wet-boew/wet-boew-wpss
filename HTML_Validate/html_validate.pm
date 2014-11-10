#***********************************************************************
#
# Name:   html_validate.pm
#
# $Revision: 6785 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/HTML_Validate/Tools/html_validate.pm $
# $Date: 2014-10-02 13:46:58 -0400 (Thu, 02 Oct 2014) $
#
# Description:
#
#   This file contains routines that validate HTML content.
#
# Public functions:
#     HTML_Validate_Content
#     HTML_Validate_Language
#     HTML_Validate_Debug
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

package html_validate;

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
    @EXPORT  = qw(HTML_Validate_Content
                  HTML_Validate_Language
                  HTML_Validate_Debug
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths, $validate_cmnd);
my ($doctype_label, $doctype_version, $doctype_class);

my ($debug) = 0;
my ($html5_validation_error_reported) = 0;

my ($VALID_HTML) = 1;
my ($INVALID_HTML) = 0;

#
# String table for error strings.
#
my %string_table_en = (
    "No HTML5 validator",    "No HTML5 validator, use W3C validator",
);

my %string_table_fr = (
    "No HTML5 validator",    "Pas un validateur HTML5, utiliser le validateur du W3C",
,
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#********************************************************
#
# Name: HTML_Validate_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub HTML_Validate_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#********************************************************
#
# Name: HTML_Validate_Language
#
# Parameters: language - language value
#
# Description:
#
#   This function sets the package language value.
#
#********************************************************
sub HTML_Validate_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "HTML_Validate_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "HTML_Validate_Language, language = English\n" if $debug;
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
# Name: Validate_XHTML_Content
#
# Parameters: this_url - a URL
#             charset - character set of content
#             content - HTML content pointer
#
# Description:
#
#   This function runs the HTML validator on the supplied content
# and returns the validation status result.
#
#***********************************************************************
sub Validate_XHTML_Content {
    my ($this_url, $charset, $content) = @_;

    my ($status) = $VALID_HTML;
    my ($validator_output, $line, $html_file_name, @results_list);
    my ($result_object, $fh);

    #
    # Write the content to a temporary file
    #
    print "Validate_XHTML_Content create temporary HTML file\n" if $debug;
    ($fh, $html_file_name) = tempfile( SUFFIX => '.htm');
    if ( ! defined($fh) ) {
        print "Error: Failed to create temporary file in Validate_XHTML_Content\n";
        return(@results_list);
    }
    binmode $fh;
    print $fh $$content;
    close($fh);

    #
    # Do we have a charset ?
    #
    if ( $charset ne "" ) {
        $charset = "--charset=$charset";
    }

    #
    # Run the validator on the supplied content
    #
    print "Run validator\n --> $validate_cmnd $charset $html_file_name 2>\&1\n" if $debug;
    $validator_output = `$validate_cmnd $charset $html_file_name 2>\&1`;

    #
    # Do we have an error ? ('Error at' in the output line)
    #
    if ( $validator_output =~ /Error at line/ ) {
        $status = $INVALID_HTML;
        $result_object = tqa_result_object->new("HTML_VALIDATION",
                                                1, "HTML_VALIDATION",
                                                -1, -1, "",
                                                $validator_output,
                                                $this_url);
        push (@results_list, $result_object);
    }

    #
    # Clean up temporary files
    #
    unlink($html_file_name);

    #
    # Return number of errors and result objects
    #
    print "Validate_XHTML_Content status = $status\n" if $debug;
    return(@results_list);
}

#***********************************************************************
#
# Name: Declaration_Handler
#
# Parameters: text - declaration text
#             line - line number
#             column - column number
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the declaration line in an HTML document.
#
#***********************************************************************
sub Declaration_Handler {
    my ( $text, $line, $column ) = @_;

    my ($this_dtd, @dtd_lines, $language, $url);
    my ($top, $availability, $registration, $organization, $type, $label);

    #
    # Convert any newline or return characters into whitespace
    #
    $text =~ s/\r/ /g;
    $text =~ s/\n/ /g;

    #
    # Parse the declaration line to get its fields, we only care about the FPI
    # (Formal Public Identifier) field.
    #
    #  <!DOCTYPE root-element PUBLIC "FPI" ["URI"]
    #    [ <!-- internal subset declarations --> ]>
    #
    ($top, $availability, $registration, $organization, $type, $label, $language, $url) =
         $text =~ /^\s*\<!DOCTYPE\s+(\w+)\s+(\w+)\s+"(.)\/\/(\w+)\/\/(\w+)\s+([\w\s\.\d]*)\/\/(\w*)".*>\s*$/io;

    #
    # Did we get an FPI ?
    #
    if ( defined($label) ) {
        #
        # Parse out the language (HTML vs XHTML), the version number
        # and the class (e.g. strict)
        #
        $doctype_label = $label;
        ($language, $doctype_version, $doctype_class) =
            $doctype_label =~ /^([\w\s]+)\s+(\d+\.\d+)\s*(\w*)\s*.*$/io;
    }
    #
    # No Formal Public Identifier, perhaps this is a HTML 5 document ?
    #
    elsif ( $text =~ /\s*<!DOCTYPE\s+html>\s*/i ) {
        $doctype_label = "HTML";
        $doctype_version = 5.0;
        $doctype_class = "";
    }
}

#***********************************************************************
#
# Name: Get_Doctype
#
# Parameters: content - HTML content pointer
#
# Description:
#
#   This function gets the doctype (XHTML, HTML) and version from
# the HTML content.
#
#***********************************************************************
sub Get_Doctype {
    my ($content) = @_;

    my ($parser);

    #
    # Initialize doctype values
    #
    print "Get_Doctype\n" if $debug;
    $doctype_label = "";
    $doctype_version = 0;
    $doctype_class = "";

    #
    # Create a document parser
    #
    $parser = HTML::Parser->new;

    #
    # Add handlers for some of the HTML tags
    #
    $parser->handler(
        declaration => \&Declaration_Handler,
        "text,line,column"
    );

    #
    # Parse the content.
    #
    $parser->parse($$content);
    print "DOCTYPE label = $doctype_label, version = $doctype_version, class = $doctype_class\n" if $debug;
}

#***********************************************************************
#
# Name: HTML_Validate_Content
#
# Parameters: this_url - a URL
#             charset - character set of content
#             content - HTML content pointer
#
# Description:
#
#   This function runs the HTML validator on the supplied content
# and returns the validation status result.
#
#***********************************************************************
sub HTML_Validate_Content {
    my ($this_url, $charset, $content) = @_;

    my (@results_list, $result_object);

    #
    # Do we have any content ?
    #
    if ( length($$content) > 0 ) {

        #
        # Determine the HTML/XHTML language of the content.
        #
        Get_Doctype($content);

        #
        # Run the appropriate validator for the doctype
        #
        if ( $doctype_label =~ /xhtml/i ) {
            @results_list = Validate_XHTML_Content($this_url, $charset,
                                                   $content);
        }
        elsif ( ($doctype_label =~ /html/i ) && ($doctype_version < 5) ) {
            @results_list = Validate_XHTML_Content($this_url, $charset,
                                                   $content);
        }
        elsif ( ($doctype_label =~ /html/i ) && ($doctype_version == 5) ) {
            #
            # Can't do HTML 5 validation, report error only once
            # per tool run.
            #
            if ( ! $html5_validation_error_reported ) {
                $result_object = tqa_result_object->new("HTML_VALIDATION",
                                                        1,
                                                        "HTML_VALIDATION",
                                                        -1, -1, "",
                                            String_Value("No HTML5 validator"),
                                                        $this_url);
                push (@results_list, $result_object);
                $html5_validation_error_reported = 1;
            }
        }
        else {
            print "No validator for $doctype_label version $doctype_version\n" if $debug;
        }
    }
    else {
        #
        # No content
        #
        print "No content passed to HTML_Validate_Content\n" if $debug;
    }

    #
    # Return number of errors and result objects
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
# Generate path the validate command and set VALIDATE_HOME environment
# variable
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $validate_cmnd = "win_validate.pl";
} else {
    #
    # Not Windows.
    #
    $validate_cmnd = "$program_dir/validate";
}
$ENV{VALIDATE_HOME} = $program_dir;

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

