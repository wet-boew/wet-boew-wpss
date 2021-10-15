#***********************************************************************
#
# Name:   html_validate.pm
#
# $Revision: 7631 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/HTML_Validate/Tools/html_validate.pm $
# $Date: 2016-07-22 03:04:06 -0400 (Fri, 22 Jul 2016) $
#
# Description:
#
#   This file contains routines that validate HTML content.
#
# Public functions:
#     HTML_Validate_Content
#     HTML_Validate_Language
#     HTML_Validate_Debug
#     HTML_Validate_Last_Validation_Output
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

#
# Check for module to share data structures between threads
#
my $have_threads = eval 'use threads; 1';
if ( $have_threads ) {
    $have_threads = eval 'use threads::shared; 1';
}

use strict;
use File::Basename;
use HTML::Parser;
use Encode;
use JSON::PP;
use File::Temp qw/ tempfile tempdir /;

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
    @EXPORT  = qw(HTML_Validate_Content
                  HTML_Validate_Language
                  HTML_Validate_Debug
                  HTML_Validate_Last_Validation_Output
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths );
my ($doctype_label, $doctype_version, $doctype_class);
my ($last_validation_output);
my ($runtime_error_reported) = 0;

#
# Variables shared between threads
#
my ($validate_cmnd, $html5_validate_jar, $java_options);
if ( $have_threads ) {
    share(\$validate_cmnd);
    share(\$html5_validate_jar);
    share(\$java_options);
}

my ($debug) = 0;
my ($VALID_HTML) = 1;
my ($INVALID_HTML) = 0;
my ($MAX_SOURCE_LINE_SIZE) = 100;

#
# String table for error strings.
#
my %string_table_en = (
    "Error",                 "Error: ",
    "Line",                  "Line",
    "column",                "column",
    "Runtime Error",         "Runtime Error",
    "Source line",           "Source line:",
);

my %string_table_fr = (
    "Error",                 "Erreur: ",
    "Line",                  "Ligne",
    "column",                "colonne",
    "Runtime Error",         "Erreur D'Exécution",
    "Source line",           "Ligne de la source:",
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
# Name: Get_HTML_Validate_Command_Line
#
# Parameters: None
#
# Description:
#
#   This function gets the command line for the HTML validator.
#
#***********************************************************************
sub Get_HTML_Validate_Command_Line {

    my ($perl_path, $version);

    #
    # Have we already determined the HTML validator command line?
    #
    if ( ! defined($validate_cmnd) ) {
        #
        # Generate path the to the validate command and
        # set VALIDATE_HOME environment variable
        #
        print "Get_HTML_Validate_Command_Line\n" if $debug;
        if ( $^O =~ /MSWin32/ ) {
            #
            # Windows. Get path to Perl executable
            #
            $perl_path = `where perl`;
            chomp($perl_path);

            #
            # Is Perl not in the PATH (i.e. use file type to associate
            # perl script to perl program)?
            #
            if ( $perl_path eq "" ) {
                $validate_cmnd = ".\\bin\\win_validate.pl";
            }
            else {
                #
                # This is a work around for PSPC Windows 10 PCs which do not
                # always pass on command line arguments to Perl programs.
                #
                $validate_cmnd = "perl .\\bin\\win_validate.pl";;
            }

            #
            # HTML 5 validator JAR path
            #
            $html5_validate_jar = ".\\lib\\vnu.jar";

            #
            # Is this 64 bit? if so we need a larger stack
            #
            $version = `java -version 2>\&1`;
            if ( $version =~ /64-bit/im ) {
                $java_options = "-Xss1024k";
            }
            else {
                $java_options = "-Xss512k";
            }
        } else {
            #
            # Not Windows.
            #
            $validate_cmnd = "$program_dir/bin/validate";
            $html5_validate_jar = "$program_dir/lib/vnu.jar";
            $java_options = "-Xss1024k";
        }
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
    my ($result_object, $fh, $char);
    
    #
    # Get the HTML validator command line
    #
    Get_HTML_Validate_Command_Line();

    #
    # Write the content to a temporary file
    #
    print "Validate_XHTML_Content create temporary HTML file\n" if $debug;
    ($fh, $html_file_name) = tempfile("WPSS_TOOL_HTML_XXXXXXXXXX", SUFFIX => '.htm',
                                      TMPDIR => 1);
    if ( ! defined($fh) ) {
        print "Error: Failed to create temporary file in Validate_XHTML_Content\n";
        return(@results_list);
    }
    binmode $fh;

    #
    # Remove any UTF-8 BOM from the content.  The XHTML validator
    # does not handle it.
    #
    $char = substr($$content, 0, 1);
    if ( ord($char) == 65279 ) {
        print "Skip over BOM xFEFF\n" if $debug;
        print $fh substr($$content, 1);
    }
    elsif ( $$content =~ s/^\xEF\xBB\xBF// ) {
        print "Skip over BOM xFEBBBF\n" if $debug;
        print $fh substr($$content, 3);
    }
    else {
        print $fh $$content;
    }
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
    $last_validation_output = $validator_output;

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
    elsif ( $validator_output ne "" ) {
        #
        # Some error trying to run the validator
        #
        print "XHTML validator command failed\n" if $debug;
        $last_validation_output = "";

        #
        # Report runtime error only once
        #
        if ( ! $runtime_error_reported ) {
            $result_object = tqa_result_object->new("HTML_VALIDATION",
                                                    1, "HTML_VALIDATION",
                                                    -1, -1, "",
                                                    String_Value("Runtime Error") .
                                                    " \"$validate_cmnd $charset $html_file_name\"\n" .
                                                    " \"$validator_output\"",
                                                    $this_url);

            #
            # Reset the source line value of the testcase error result.
            # The initial setting may have been truncated while in this
            # case we want the entire value.
            #
            $result_object->source_line(String_Value("Runtime Error") .
                                        " \"$validate_cmnd $charset $html_file_name\"\n" .
                                        " \"$validator_output\"");

            print STDERR "XHTML validator command failed\n";
            print STDERR "  $validate_cmnd $charset $html_file_name\n";
            print STDERR "$validator_output\n";
            push (@results_list, $result_object);
            $runtime_error_reported = 1;
        }
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
# Name: Validate_HTML5_Content
#
# Parameters: this_url - a URL
#             content - HTML content pointer
#
# Description:
#
#   This function runs the Nu Markup Checker (v.Nu) on the supplied content
# and returns the validation status result.
#
#***********************************************************************
sub Validate_HTML5_Content {
    my ($this_url, $content) = @_;

    my ($validator_output, $line, $html_file_name, @results_list);
    my ($result_object, $fh, $ref, $messages, $eval_output, $item);
    my ($ref_type, $errors, $line_no, $column_no, $message);
    my (@lines, $source_line, $start_col);
    my ($command_failed) = 0;

    #
    # Get the HTML validator command line
    #
    Get_HTML_Validate_Command_Line();

    #
    # Write the content to a temporary file
    #
    print "Validate_HTML5_Content create temporary HTML file\n" if $debug;
    ($fh, $html_file_name) = tempfile("WPSS_TOOL_HTML_XXXXXXXXXX", SUFFIX => '.html',
                                      TMPDIR => 1);
    if ( ! defined($fh) ) {
        print "Error: Failed to create temporary file in Validate_HTML5_Content\n";
        return(@results_list);
    }
    binmode $fh;
    print $fh $$content;
    close($fh);
    
    #
    # split source on new-line
    #
    @lines = split(/\n/, $$content);

    #
    # Run the Nu Markup Checker on the supplied content
    #
    print "Run Nu Markup Checker\n --> java -jar \"$html5_validate_jar\" --errors-only --format json \"$html_file_name\" 2>\&1\n" if $debug;
    $validator_output = `java $java_options -jar \"$html5_validate_jar\" --errors-only --format json \"$html_file_name\" 2>\&1`;
    print "Validator output = $validator_output\n" if $debug;
    $last_validation_output = "";

    #
    # Do we have any output ?
    #
    if ( $validator_output ne "" ) {
        #
        # Decode the JSON output
        #
        $eval_output = eval { $ref = decode_json($validator_output); 1 } ;

        #
        # Get the messages structure from the JSON object
        #
        $errors = "";
        if ( defined($$ref{"messages"}) ) {
            $messages = $$ref{"messages"};

            #
            # Is it an array ?
            #
            $ref_type = ref $messages;
            if ( $ref_type eq "ARRAY" ) {
                foreach $item (@$messages) {
                    #
                    # Ignore messages about malformed byte sequences.  This
                    # happens sometimes if there are UTF-8 characters in
                    # the HTML content.
                    #
                    if ( defined($$item{"message"})
                         && ($$item{"message"} =~ /^Malformed byte sequence/i) ) {
                        next;
                    }

                    #
                    # Get at the location and message
                    #
                    if ( defined($$item{"lastLine"}) ) {
                        $line_no = $$item{"lastLine"};
                    }
                    else {
                        $line_no = 0;
                    }
                    if ( defined($$item{"lastColumn"}) ) {
                        $column_no = $$item{"lastColumn"};
                    }
                    else {
                        $column_no = 0;
                    }
                    if ( defined($$item{"message"}) ) {
                        $message = $$item{"message"};
                        
                        #
                        # Convert windows smart quotes into quotes
                        #
                        $message =~ s/[^[:ascii:]]+/'/g;
                    }
                    else {
                        $message = "";
                    }
                    
                    #
                    # Add this message to the list of errors
                    #
                    if ( $message ne "" ) {
                        #
                        # Get HTML source line fragment substring
                        # starting position.
                        #
                        if ( length($lines[$line_no - 1]) > $MAX_SOURCE_LINE_SIZE ) {
                            if ( $column_no < $MAX_SOURCE_LINE_SIZE ) {
                                if ( $column_no < 50 ) {
                                    $start_col = 0;
                                }
                                else {
                                    $start_col = $column_no - 50;
                               }
                            }
                            else {
                                $start_col = $column_no - 50;
                            }
                        }
                        else {
                            $start_col = 0;
                        }

                        #
                        # Add to validator output sting in text format rather
                        # than JSON format.
                        #
                        $last_validation_output .= "Error: $message\n" .
                                                   "Line: $line_no column: $column_no\n" .
                                                   "Source line: $source_line\n";

                        #
                        # Get source line fragment.
                        #
                        $source_line = substr($lines[$line_no - 1], $start_col,
                                              $MAX_SOURCE_LINE_SIZE);
                                              
                        #
                        # Add this error to the error messages.
                        #
                        print "Error at $line_no:$column_no message = $message\n" if $debug;
                        $errors .= String_Value("Error") . $message . "\n" .
                                   String_Value("Line") . " $line_no, " .
                                   String_Value("column") . " $column_no\n" .
                                   String_Value("Source line") . " $source_line\n\n";
                    }
                }
            }
            else {
                print "Messages is not a array, $ref_type\n" if $debug;
                $command_failed = 1;
            }
        }
        #
        # Look from error with Java
        #
        elsif ( $validator_output =~ /is not recognized/i ) {
            print "Error, validator failed to run\n" if $debug;
            $errors .= String_Value("Error") . $validator_output . "\n";
        }
        else {
            #
            # No messages table
            #
            print "No messages table\n" if $debug;
            $command_failed = 1;
        }

        #
        # Create testcase results object for validation failure
        #
        if ( $errors ne "" ) {
            $result_object = tqa_result_object->new("HTML_VALIDATION",
                                                    1, "HTML_VALIDATION",
                                                    -1, -1, "",
                                                    $errors,
                                                    $this_url);
            push (@results_list, $result_object);
        }
        elsif ( $command_failed ) {
            #
            # Some error trying to run the validator
            #
            print "HTML5 validator command failed\n" if $debug;
            $last_validation_output = "";

            #
            # Report runtime error only once
            #
            if ( ! $runtime_error_reported ) {
                print STDERR "HTML5 validator command failed\n";
                print STDERR "java $java_options -jar \"$html5_validate_jar\" --errors-only --format json \"$html_file_name\"\n";
                print STDERR "$validator_output\n";
                $result_object = tqa_result_object->new("HTML_VALIDATION",
                                                        1, "HTML_VALIDATION",
                                                        -1, -1, "",
                                                        String_Value("Runtime Error") .
                                                        " \"java $java_options -jar \"$html5_validate_jar\" --errors-only --format json \"$html_file_name\"\"\n" .
                                                        " \"$validator_output\"",
                                                        $this_url);

                #
                # Reset the source line value of the testcase error result.
                # The initial setting may have been truncated while in this
                # case we want the entire value.
                #
                $result_object->source_line(String_Value("Runtime Error") .
                                            " \"java $java_options -jar \"$html5_validate_jar\" --errors-only --format json \"$html_file_name\"\"\n" .
                                            " \"$validator_output\"");

                $runtime_error_reported = 1;
                push (@results_list, $result_object);
            }
        }
    }
    else {
        #
        # No output from validator, either no errors or the validator failed
        #
        print "No validator output\n" if $debug;
    }

    #
    # Clean up temporary files
    #
    unlink($html_file_name);

    #
    # Return error list
    #
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
#             resp - HTTP::Response object
#             content - HTML content pointer
#
# Description:
#
#   This function runs the HTML validator on the supplied content
# and returns the validation status result.
#
#***********************************************************************
sub HTML_Validate_Content {
    my ($this_url, $resp, $content) = @_;

    my (@results_list, $result_object, $charset);

    #
    # Do we have any content ?
    #
    if ( length($$content) > 0 ) {
        #
        # Get the character set encoding, if any, that is specified in the
        # response header.
        #
        $charset = "";
        if ( defined($resp) ) {
            $charset = $resp->header('Content-Type');

            #
            # Is a charset defined in the header ?
            #
            if ( $charset =~ /charset=/i ) {
                $charset =~ s/^.*charset=//g;
                $charset =~ s/,.*//g;
                $charset =~ s/ .*//g;
                $charset =~ s/".*//g;
                $charset =~ s/\s+//g;
                $charset =~ s/\n//g;
            }
            else {
                $charset = "";
            }
        }

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
            @results_list = Validate_HTML5_Content($this_url, $content);
        }
        else {
            print "No validator for $doctype_label version $doctype_version\n" if $debug;
            $last_validation_output = "";
        }
    }
    else {
        #
        # No content
        #
        print "No content passed to HTML_Validate_Content\n" if $debug;
        $last_validation_output = "";
    }

    #
    # Return number of errors and result objects
    #
    return(@results_list);
}

#***********************************************************************
#
# Name: HTML_Validate_Last_Validation_Output
#
# Parameters: none
#
# Description:
#
#   This function returns the output of the last run of the validator.
#
#***********************************************************************
sub HTML_Validate_Last_Validation_Output {

    #
    # Return validation output
    #
    return($last_validation_output);
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
# Set the VALIDATE_HOME environment variable
#
$ENV{VALIDATE_HOME} = "$program_dir/bin";

#
# Return true to indicate we loaded successfully
#
return 1;

