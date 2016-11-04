#***********************************************************************
#
# Name: csv_parser.pm
#
# $Revision$
# $URL$
# $Date$
#
# Description:
#
#   This file defines an object for CSV file parsing. The Text::CSV module
# is not being used as it has a limitation when attempting to parse very
# large data cells.  If a data cell contains more than 32K characters in
# a quoted string, the cell parsing regular expression fails.  This
# implementation manually parses and matches quotes in data cells .
#
# Public functions:
#     CSV_Parser_Debug
#     CSV_Parser_Language
#
# Class Methods
#    new - create new object instance
#    eof - return end of file status
#    error_diag - diagnostic of error
#    error_input - input line that resulted in error
#    getrow - parse a row from CSV file
#    status - status of  last operation
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

package csv_parser;

use Encode;
use IO::Handle;
use strict;
use warnings;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(CSV_Parser_Debug
                  CSV_Parser_Language);
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;

#
# String table for error strings.
#
my %string_table_en = (
    "Character position",            "Character position",
    "Double quote found in non-quoted field", "Double quote found in non-quoted field",
    "Field number",                  "Field number",
    "Invalid character following quoted field", "Invalid character following quoted field. Expecting comma or end of line, found",
    "Line",                          "Line",
    "Quoted field not closed before end-of-file", "Quoted field not closed before end-of-file",
    "Quoted field started at",       "Quoted field started at",
    "Row",                           "Row",
    );

my %string_table_fr = (
    "Character position",            "Position de caractère",
    "Double quote found in non-quoted field", "Double citation trouvée dans le champ non-cité",
    "Field number",                  "Numéro de champ",
    "Invalid character following quoted field", "Caractère non valide qui suit champ cité. Expecting virgule ou fin de ligne, a trouvé",
    "Line",                          "Ligne",
    "Quoted field not closed before end-of-file", "Champ Cité pas fermé avant la fin de fichier",
    "Quoted field started at",       "Chaîne entre guillemets a commencé à",
    "Row",                           "Rangée",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#********************************************************
#
# Name: CSV_Parser_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub CSV_Parser_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#********************************************************
#
# Name: CSV_Parser_Language
#
# Parameters: language - language value
#
# Description:
#
#   This function sets the package language value.
#
#********************************************************
sub CSV_Parser_Language {
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

#**********************************************************************
#
# Name: _is_valid_utf8
#
# Parameters: line - string of text
#
# Description:
#
#   This function checks to see if there are any UTF-8 characters in
# the text string.  Code taken from Text::CSV_PP.pm
#
#**********************************************************************
sub _is_valid_utf8 {
    return ( $_[0] =~ /^(?:
         [\x00-\x7F]
        |[\xC2-\xDF][\x80-\xBF]
        |[\xE0][\xA0-\xBF][\x80-\xBF]
        |[\xE1-\xEC][\x80-\xBF][\x80-\xBF]
        |[\xED][\x80-\x9F][\x80-\xBF]
        |[\xEE-\xEF][\x80-\xBF][\x80-\xBF]
        |[\xF0][\x90-\xBF][\x80-\xBF][\x80-\xBF]
        |[\xF1-\xF3][\x80-\xBF][\x80-\xBF][\x80-\xBF]
        |[\xF4][\x80-\x8F][\x80-\xBF][\x80-\xBF]
    )+$/x )  ? 1 : 0;
}

#********************************************************
#
# Name: new
#
# Parameters: attr - hash table of attributes
#
# Description:
#
#   This function creates a new csv_parser object and
# initializes it's data items.
#
#********************************************************
sub new {
    my ($class, %attr) = @_;

    my ($self) = {};

    #
    # Bless the reference as a csv_parser class item
    #
    bless $self, $class;

    #
    # Initialize object variables
    #
    $self->{"eof"} = 0;
    $self->{"error_diag"} = "";
    $self->{"error_input"} = "";
    $self->{"line_no"} = -1;
    $self->{"row_no"} = 0;
    $self->{"status"} = 1;
    
    #
    # Return reference to object.
    #
    return($self);
}

#********************************************************
#
# Name: eof
#
# Parameters: self - class reference
#
# Description:
#
#   This function returns true if the last getline operation
# reached the end of the CSV file.
#
#********************************************************
sub eof {
    my ($self) = @_;

    #
    # Return end of file status
    #
    return($self->{"eof"});
}

#********************************************************
#
# Name: error_diag
#
# Parameters: self - class reference
#
# Description:
#
#   This function returns the error diagnostic message
# from the last error.
#
#********************************************************
sub error_diag {
    my ($self) = @_;

    #
    # Return error diagnostic message
    #
    return($self->{"error_diag"});
}

#********************************************************
#
# Name: error_input
#
# Parameters: self - class reference
#
# Description:
#
#   This function returns the input being processed when
# the last error occured.
#
#********************************************************
sub error_input {
    my ($self) = @_;

    #
    # Return input related to the last error
    #
    return($self->{"error_input"});
}

#********************************************************
#
# Name: getrow
#
# Parameters: self - class reference
#             io - file handle
#
# Description:
#
#   This function reads lines from the file handle and parses them
# into a CSV data file row. A reference
# to the array is returned. If an error occurs, undef is returned.
#
#********************************************************
sub getrow {
    my ($self, $io) = @_;

    my (@fields, $line, $last_character_index, $i, $char, $next_char);
    my ($message);
    my ($in_field) = 1;
    my ($in_quoted_field) = 0;
    my ($end_of_row) = 0;
    my ($field_value) = "";
    my ($quoted_field_start) = "";
    my ($utf8) = 0;

    #
    # Set status to true, assume we get a valid row
    #
    $self->{"status"} = 1;
    
    #
    # Increment row number
    #
    $self->{"row_no"}++;
    
    #
    # Get next line from file until we get to the end of
    # this row or we get to the end of the file or we find an error.
    #
    while ( ($self->{"status"} == 1) && (! $end_of_row) && ($line = $io->getline()) ) {
        #
        # Increment line number and get the index of the last
        # character in the line.
        #
        $self->{"line_no"}++;
        $last_character_index = length($line) - 1;
        
        #
        # Is the line UTF-8 ?
        #
        $utf8 = 1 if utf8::is_utf8( $line );

        #
        # Check each character in the input line for a comma
        # or a quote.
        #
        foreach ($i = 0; $i < length($line); $i++) {
            #
            # Get next character
            #
            $char = substr($line, $i, 1);

            #
            # Is this a double quote ?
            #
            if ( $char eq '"' ) {
                #
                # Is this the first character of a field value ? If so it
                # indicates that it is a quoted field value.
                #
                if ( ($field_value eq "") && (! $in_quoted_field) ) {
                    $in_quoted_field = 1;
                    $quoted_field_start = $self->{"line_no"} . ":" . $i;
                }
                #
                # Are we inside a field ? this could be a quoted double quote or
                # a double quote to end the field.
                #
                elsif ( $in_quoted_field ) {
                    #
                    # Is there a next character ?
                    #
                    if ( $i < $last_character_index ) {
                        $next_char = $char = substr($line, $i + 1, 1);
                    }
                    else {
                        $next_char = "";
                    }

                    #
                    # Is the next character a double quote ?
                    #
                    if ( $next_char eq '"' ) {
                        #
                        # Skip over the first double quote character
                        #
                        $i++;
                        $field_value .= '"';
                    }
                    #
                    # If the next character is a comma, it is the end of the
                    # quoted field.
                    #
                    elsif ( $next_char eq "," ) {
                        #
                        # End of quoted field
                        #
                        $in_quoted_field = 0;
                    }
                    #
                    # If the next 2 characters are
                    #   carriage return (character 13)
                    #   line feed (character 10)
                    # we are at the end of the line and finished the field.
                    #
                    elsif ( ord($next_char) == 13 ) {
                        if ( ($i + 1) < $last_character_index ) {
                            $next_char = substr($line, $i + 2, 1);
                        }
                        else {
                            $next_char = "";
                        }

                        #
                        # Do we have line feed ?
                        #
                        if ( ord($next_char) == 10 ) {
                            $in_quoted_field = 0;
                            $next_char = "\n";
                        }
                        else {
                            #
                            # Construct error message for invalid character
                            #
                            $message = String_Value("Invalid character following quoted field") .
                                       " \"$next_char\", ord(" . ord($next_char) . ")\n";
                            $message .= String_Value("Row") . " = " . $self->{"row_no"} . " " .
                                        String_Value("Line") . " = " . $self->{"line_no"} . " " .
                                        String_Value("Character position") . " = $i\n";
                            $message .= String_Value("Field number") . " " .
                                        (scalar(@fields) + 1) . "\n";
                            $message .= String_Value("Quoted field started at") . " $quoted_field_start\n";

                            $self->{"status"} = 0;
                            $self->{"error_diag"} = $message;
                            $self->{"error_input"} = substr($line, $i - 25, 50);
                            last;
                        }
                    }
                    #
                    # Invalid character following quoted field value
                    #
                    else {
                        if ( ord($next_char) == 10 ) {
                            $message = String_Value("Invalid character following quoted field") .
                                       " \"Line Feed\", ord(" . ord($next_char) . ")\n";
                        }
                        else {
                            $message = String_Value("Invalid character following quoted field") .
                                       "\"$next_char\", ord(" . ord($next_char) . ")\n";

                        }
                        $message .= String_Value("Row") . " = " . $self->{"row_no"} . " " .
                                    String_Value("Line") . " = " . $self->{"line_no"} . " " .
                                    String_Value("Character position") . " = $i\n";
                        $message .= String_Value("Field number") . " " .
                                    (scalar(@fields) + 1) . "\n";
                        $message .= String_Value("Quoted field started at") . " $quoted_field_start\n";
                        $self->{"status"} = 0;
                        $self->{"error_diag"} = $message;
                        $self->{"error_input"} = substr($line, $i - 25, 50);
                        last;
                    }
                }
                #
                # Are we in a non quoted field ?
                #
                elsif ( $in_field ) {
                    #
                    # Must not have a double quote in a field that is
                    # not enclosed in double quotes.
                    #
                    $message = String_Value("Double quote found in non-quoted field") . "\n";
                    $message .= String_Value("Row") . " = " . $self->{"row_no"} . " " .
                                String_Value("Line") . " = " . $self->{"line_no"} . " " .
                                String_Value("Character position") . " = $i\n";
                    $message .= String_Value("Field number") . " " .
                                (scalar(@fields) + 1) . "\n";
                    $self->{"status"} = 0;
                    $self->{"error_diag"} = $message;
                    $self->{"error_input"} = substr($line, $i - 25, 50);
                    last;
                }
            }
            #
            # Is this a comma ?
            #
            elsif ( $char eq "," ) {
                #
                # Are we inside a double quoted field ? If so, this is
                # just content of the field
                #
                if ( $in_quoted_field ) {
                    $field_value .= ',';
                }
                #
                # Are we inside a non quoted field ? If so, this is the end
                # of the field.  Save the field value from the previous field.
                # Start the next field.
                #
                elsif ( $in_field ) {
                    #
                    # Encode field if this line is UTF-8
                    #
                    if ( $utf8 ) {
                        utf8::encode($field_value);
                    }
                    if ( defined($field_value) && _is_valid_utf8($field_value) ) {
                        utf8::decode($field_value);
                    }

                    #
                    # Save field in the array of field values.
                    # Clear in quoted field flag and reinitialize field value.
                    #
                    push(@fields, $field_value);
                    $in_quoted_field = 0;
                    $field_value = "";
                }
            }
            #
            # Is this the second last character and are these characters
            # a carriage return line feed combination? If so this may be the
            # end of a row.
            #
            elsif ( ord($char) == 13 ) {
                #
                # Are we not in a quoted field?
                #
                if ( ! $in_quoted_field ) {
                    print "Found carriage return outside a quoted field\n" if $debug;
                    #
                    # Is this the 2nd last character ?
                    #
                    if ( ($i + 1) == $last_character_index ) {
                        $next_char = substr($line, $i + 1, 1);
                        print "Last character in line is " . ord($next_char) . "\n" if $debug;
                    }
                    #
                    # If there are no more characters, treat it as a line feed
                    #
                    elsif ( $i == $last_character_index ) {
                        $end_of_row = 1;
                        print "No more characters in line, end of row found\n" if $debug;
                        last;
                    }
                    else {
                        $next_char = "";
                    }

                    #
                    # Do we have line feed ? If so we are at the end of
                    # a row.
                    #
                    if ( ord($next_char) == 10 ) {
                        $end_of_row = 1;
                        print "End of row found\n" if $debug;
                        last;
                    }
                }

                #
                # If we got here we are either in a quoted field or we
                # found a carriage return without a line feed.
                # Append character to current field value
                #
                $field_value .= $char;
            }
            #
            # Append it to the current field value
            #
            else {
                $field_value .= $char;
            }
        }

        #
        # End of line.  If we are not inside a quoted field, the end of line
        # ends this field and ends this row.
        #
        if ( ! $in_quoted_field ) {
            #
            # Encode field if this line is UTF-8
            #
            if ( $utf8 ) {
                utf8::encode($field_value);
            }
            if ( defined($field_value) && _is_valid_utf8($field_value) ) {
                utf8::decode($field_value);
            }

            #
            # Strip any trailing carriage return
            #
            # Save field in the array of field values.
            #
            chomp($field_value);
            push(@fields, $field_value);
            $end_of_row = 1;
        }
    }

    #
    # Check for end of file
    #
    if ( CORE::eof($io) ) {
        $self->{"eof"} = 1;
        print "At end of file in getrow\n" if $debug;

        #
        # End of file, do we have an open quoted field ?
        #
        if ( $in_quoted_field ) {
            #
            # Was the last character a double quote ? If so the end-of-file
            # is a valid character to close off the quoted field.
            #
            if ( $char eq '"' ) {
                #
                # Encode field if this line is UTF-8
                #
                if ( $utf8 ) {
                    utf8::encode($field_value);
                }
                if ( defined($field_value) && _is_valid_utf8($field_value) ) {
                    utf8::decode($field_value);
                }

                #
                # Save field in the array of field values.
                #
                push(@fields, $field_value);
            }
            else {
                $message = String_Value("Quoted field not closed before end-of-file") . "\n";
                $message .= String_Value("Row") . " = " . $self->{"row_no"} . " " .
                            String_Value("Line") . " = " . $self->{"line_no"} . " " .
                            String_Value("Character position") . " = $i\n";
                $message .= String_Value("Field number") . " " .
                            (scalar(@fields) + 1) . "\n";
                $self->{"status"} = 0;
                    $self->{"error_diag"} = $message;
                    $self->{"error_input"} = "";
            }
        }
    }

    #
    # Return reference to field array
    #
    return(\@fields);
}

#********************************************************
#
# Name: status
#
# Parameters: self - class reference
#
# Description:
#
#   This function returns the current parser status.
#
#********************************************************
sub status {
    my ($self) = @_;

    #
    # Return the current parser status
    #
    return($self->{"status"});
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


