#***********************************************************************
#
# Name:   xml_validate.pm
#
# $Revision: 7629 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/XML_Validate/Tools/xml_validate.pm $
# $Date: 2016-07-21 08:29:10 -0400 (Thu, 21 Jul 2016) $
#
# Description:
#
#   This file contains routines that validate XML content.
#
# Public functions:
#     XML_Validate_Content
#     XML_Validate_Language
#     XML_Validate_Debug
#     XML_Validate_Xerces
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
    @EXPORT  = qw(XML_Validate_Content
                  XML_Validate_Language
                  XML_Validate_Debug
                  XML_Validate_Xerces
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);

my ($have_doctype, $have_schema, $xerces_validate_cmnd);
my ($runtime_error_reported) = 0;
my ($debug) = 0;

#
# String table for error strings.
#
my %string_table_en = (
    "Failed to create temporary file", "Failed to create temporary file",
    "Runtime Error",                 "Runtime Error",
    "XML validation failed",           "XML validation failed",
    );

my %string_table_fr = (
    "Failed to create temporary file", "Impossible de créer un fichier temporaire",
    "Runtime Error",                 "Erreur D'Exécution",
    "XML validation failed",         "XML validation échouée",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

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
    
    #
    # Set debug flag in supporting modules
    #
    Feed_Validate_Debug($debug);
    XML_TTML_Validate_Debug($debug);
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
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
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
# Name: Doctype_Handler
#
# Parameters: self - reference to this parser
#             name - document type name
#             sysid - system id
#             pubid - public id
#             internal - internal subset
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles the Doctype declaration in XML.
#
#***********************************************************************
sub Doctype_Handler {
    my ($self, $name, $sysid, $pubid, $internal) = @_;

    #
    # Have doctype, set flag.
    #
    print "Doctype_Handler name = $name, system id = $sysid, public id = $pubid, internal subset = $internal\n" if $debug;
    $have_doctype = 1;
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
# handles the start of XML tags.  It checks for the presence of
# schema attribute indicating this XML file follows a specific
# tag schema.
#
#***********************************************************************
sub Start_Handler {
    my ($self, $tagname, %attr) = @_;

    #
    # Check for a possible xsi:schemaLocation attribute
    #
    print "Start_Handler tag $tagname\n" if $debug;
    if ( defined($attr{"xsi:schemaLocation"}) ) {
        #
        # Schema defined for this XML file
        #
        $have_schema = 1;
    }
    #
    # Check for a possible xsi:noNamespaceSchemaLocation attribute
    #
    if ( defined($attr{"xsi:noNamespaceSchemaLocation"}) ) {
        #
        # Schema defined for this XML file
        #
        $have_schema = 1;
    }
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
# Name: XML_Validate_Xerces
#
# Parameters: this_url - a URL
#             content - XML content pointer
#             xml_file - optional name of XML content file
#             tcid - testcase identifier
#             tc_desc - testcase description
#
# Description:
#
#   This function validates XML content using the Xerces parser.  It
# can be used to validate XML content that specifies an XSD schema or
# XML content that includes a DOCTYPE declaration.
#
#***********************************************************************
sub XML_Validate_Xerces {
    my ($this_url, $content, $xml_file, $tcid, $tc_desc) = @_;

    my ($result_object, $output, @lines, $line, $errors, $base_url);
    my ($xml_fh, $xml_filename, $validation_run, $base_filename);
    my ($protocol, $domain, $file_path, $query, $url);

    #
    # Validate XML using the Xerces parser
    #
    print "XML_Validate_Xerces url = $this_url\n" if $debug;

    #
    # Do we need to write the XML content to a file ?
    #
    if ( $xml_file eq "" ) {
        #
        # Create a local file for the XML content
        #
        ($xml_fh, $xml_filename) = tempfile("WPSS_TOOL_XXXXXXXXXX",
                                            SUFFIX => '.xml',
                                            TMPDIR => 1);
        if ( ! defined($xml_fh) ) {
            print "Error: Failed to create temporary XML file in XML_Validate_Xerces\n";
            $result_object = tqa_result_object->new($tcid, 1, $tc_desc,
                                                    -1, -1, "",
                                                    String_Value("Failed to create temporary file"),
                                                    $this_url);
            return($result_object);
        }
        binmode $xml_fh;

        #
        # Save the XML content in the file
        #
        print "Save XML content in temporary file $xml_filename\n" if $debug;
        print $xml_fh $$content;
        close($xml_fh);
    }
    else {
        print "Use existing XML file name $xml_file\n" if $debug;
        $xml_filename = $xml_file;
    }

    #
    # Run the Xerces validator
    #
    print "Run Xerces validator\n --> $xerces_validate_cmnd $xml_filename 2>\&1\n" if $debug;
    $output = `$xerces_validate_cmnd \"$xml_filename\" 2>\&1`;

    #
    # Did the file validate ?
    #
    @lines = split(/\n/, $output);
    $validation_run = 0;
    $base_filename = basename($xml_filename);
    ($protocol, $domain, $file_path, $query, $url) = URL_Check_Parse_URL($this_url);
    $base_url = basename($file_path);
    foreach $line (@lines) {
        #
        # Did we fine an Error line ?
        #
        if ( $line =~ /^\[Error\] /i ) {
            $line =~ s/ $base_filename:/ $base_url:/;
            $errors .= "$line\n";
        }
        #
        # Did we find a fatal error line ?
        #
        elsif ( $line =~ /^\[Fatal\] /i ) {
            $line =~ s/ $base_filename:/ $base_url:/;
            $errors .= "$line\n";
        }
        #
        # Do we have end of validation ? (implies that the validation
        # process ran).
        #
        elsif ( $line =~ /: \d+ ms \(\d+ elems/ ) {
            $validation_run = 1;
        }
    }

    #
    # Did we find any error messages ?
    #
    if ( defined($errors) && ($errors ne "") ) {
        print "Validation failed\n" if $debug;
        #
        # Validation failed
        #
        print "XML Xerces Validation failed\n$output\n" if $debug;
        $result_object = tqa_result_object->new($tcid, 1, $tc_desc,
                                                -1, -1, "",
                                                String_Value("XML validation failed") .
                                                " $errors", $this_url);
    }
    elsif ( ! $validation_run ) {
        #
        # An error trying to run the tool
        #
        print "Error running xerces XML validation\n" if $debug;
        print STDERR "Error running xerces XML validation\n";
        print STDERR "  $xerces_validate_cmnd \"$xml_filename\" 2>\&1\n";
        print STDERR "$output\n";

        #
        # Report runtime error only once
        #
        if ( ! $runtime_error_reported ) {
            $result_object = tqa_result_object->new($tcid, 1, $tc_desc,
                                                    -1, -1, "",
                                                    String_Value("Runtime Error") .
              " \"$xerces_validate_cmnd \"$xml_filename\"\"\n" .
                                                    " \"$output\"", $this_url);
            $runtime_error_reported = 1;
        }
    }

    #
    # Remove the temporary XML file
    #
    if ( $xml_file eq "" ) {
        unlink($xml_filename);
        print "Remove temporary XML file $xml_filename\n" if $debug;
    }

    #
    # Return result object
    #
    return($result_object);
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
    # Initialize global variables
    #
    $have_schema = 0;
    $have_doctype = 0;

    #
    # Add handlers for some of the XML tags
    #
    $parser->setHandlers(Doctype => \&Doctype_Handler);
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
    # Did we find a doctye or schema ?
    #
    elsif ( $have_schema || $have_doctype ) {
        #
        # Validate the XML against doctype or schema.
        #
        $result_object = XML_Validate_Xerces($this_url, $content, "",
                                             "XML_VALIDATION", "XML_VALIDATION");
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
#   This function determines the type of XML content (e.g. web feed)
# then runs the appropriate XML validator on the supplied content.  It
# returns the validation status result.
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
    my (@package_list) = ("crawler", "feed_validate", "tqa_result_object",
                          "url_check", "xml_ttml_validate");

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
# Set xerces validator command and options
#   -v = validate XML
#   -n = namespace processing
#   -np = namespace prefixes
#   -s = schema validation
#   -f = file to process
#
$xerces_validate_cmnd = "java -classpath \"$program_dir/lib/xercesImpl.jar;" .
                        "$program_dir/lib/xml-apis.jar;" .
                        "$program_dir/lib/xercesSamples.jar\" " .
                        "sax.Counter -v -n -np -s -f ";

#
# Check for operating system specifics
#
if ( !( $^O =~ /MSWin32/ ) ) {
    #
    # Not Windows, change ; separator to : separator in class path,
    # add LANG environment variable setting for Unix.
    #
    $xerces_validate_cmnd =~ s/;/:/g;
    $xerces_validate_cmnd = "LANG=en_US.ISO8859-1;export LANG;" . $xerces_validate_cmnd;
}

#
# Import required packages
#
Import_Packages;

#
# Return true to indicate we loaded successfully
#
return 1;

