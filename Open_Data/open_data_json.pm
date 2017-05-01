#***********************************************************************
#
# Name:   open_data_json.pm
#
# $Revision: 356 $
# $URL: svn://10.36.20.203/Open_Data/Tools/open_data_json.pm $
# $Date: 2017-04-28 10:47:23 -0400 (Fri, 28 Apr 2017) $
#
# Description:
#
#   This file contains routines that parse JSON APIs and data files to
# check for a number of open data check points.
#
# Public functions:
#     Set_Open_Data_JSON_Language
#     Set_Open_Data_JSON_Debug
#     Set_Open_Data_JSON_Testcase_Data
#     Set_Open_Data_JSON_Test_Profile
#     Open_Data_JSON_Check_API
#     Open_Data_JSON_Check_Data
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

package open_data_json;

use strict;
use URI::URL;
use File::Basename;
use JSON;
use File::Temp qw/ tempfile tempdir /;
use Digest::MD5 qw(md5_hex);
use Encode;

#
# Use WPSS_Tool program modules
#
use crawler;
use csv_column_object;
use open_data_testcases;
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
    @EXPORT  = qw(Set_Open_Data_JSON_Language
                  Set_Open_Data_JSON_Debug
                  Set_Open_Data_JSON_Testcase_Data
                  Set_Open_Data_JSON_Test_Profile
                  Open_Data_JSON_Check_API
                  Open_Data_JSON_Check_Data
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (@paths, $this_path, $program_dir, $program_name, $paths);
my (%testcase_data, $results_list_addr, $dictionary_ptr);
my (%open_data_profile_map, $current_open_data_profile, $current_url);
my ($tag_count, $python_path, $json_schema_validator);
my ($filename, $python_file, $python_output);

#
# Data file object attribute names (use the same names as used for
# CSV data files as in some cases we compare attributes between CSV
# and JSON data files)
#
my ($column_count_attribute) = "Column Count";
my ($row_count_attribute) = "Row Count";
my ($column_list_attribute) = "Column List";

my ($max_error_message_string)= 2048;
my ($runtime_error_reported) = 0;

#
# Status values
#
my ($check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "Broken link in Schema",       "Broken link in \"\$Schema\":",
    "Data pattern",                "Data pattern",
    "Duplicate data array content, first instance at", "Duplicate data array content, first instance at index",
    "expecting",                   "expecting",
    "Fails validation",            "Fails validation",
    "failed for value",            "failed for value",
    "Field",                       "Field",
    "Inconsistent number of fields, found", "Inconsistent number of fields, found",
    "Invalid Schema specification in JSON file", "Invalid Schema specification in JSON file",
    "Invalid URL in Schema",       "Invalid URL in \"\$Schema\":",
    "json_schema_validator failed", "json_schema_validator failed",
    "Missing Schema value",        "Missing Schema value",
    "Missing UTF-8 BOM or charset=utf-8", "Missing UTF-8 BOM or charset=utf-8",
    "No content in API",           "No content in API",
    "No content in file",          "No content in file",
    "No Schema found in JSON file", "No Schema found in JSON file",
    "Runtime Error",               "Runtime Error",
    );

my %string_table_fr = (
    "Broken link in Schema",       "Lien brisé dans \"\$Schema\":",
    "Data pattern",                "Modèle de données",
    "Duplicate data array content, first instance at", "Dupliquer le contenu du tableau de données, première instance à l'index",
    "expecting",                   "expectant",
    "Fails validation",            "Échoue la validation",
    "failed for value",            "a échoué pour la valeur",
    "Field",                       "Champ",
    "Inconsistent number of fields, found", "Numéro incohérente des champs, a constaté",
    "Invalid Schema specification in JSON file", "Spécification de schéma non valide dans le fichier JSON",
    "Invalid URL in Schema",       "URL non valide dans \"\$Schema\":",
    "json_schema_validator failed", "json_schema_validator a échoué",
    "Missing Schema value",        "Valeur du schéma manquant",
    "Missing UTF-8 BOM or charset=utf-8", "Manquant UTF-8 BOM ou charset=utf-8",
    "No content in API",           "Aucun contenu dans API",
    "No content in file",          "Aucun contenu dans fichier",
    "No Schema found in JSON file", "Non schéma trouvé dans le fichier JSON",
    "Runtime Error",               "Erreur D'Exécution",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_Open_Data_JSON_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Open_Data_JSON_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_Open_Data_JSON_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Open_Data_JSON_Language {
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
# Name: Set_Open_Data_JSON_Testcase_Data
#
# Parameters: testcase - testcase identifier
#             data - string of data
#
# Description:
#
#   This function copies the passed data into a hash table
# for the specified testcase identifier.
#
#***********************************************************************
sub Set_Open_Data_JSON_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_Open_Data_JSON_Test_Profile
#
# Parameters: profile - open data check test profile
#             testcase_names - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by open data testcase name.
#
#***********************************************************************
sub Set_Open_Data_JSON_Test_Profile {
    my ($profile, $testcase_names) = @_;

    my (%local_testcase_names);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Open_Data_JSON_Test_Profile, profile = $profile\n" if $debug;
    %local_testcase_names = %$testcase_names;
    $open_data_profile_map{$profile} = \%local_testcase_names;
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - open data check test profile
#             local_results_list_addr - address of results list.
#
# Description:
#
#   This function initializes the test case results table.
#
#***********************************************************************
sub Initialize_Test_Results {
    my ($profile, $local_results_list_addr) = @_;

    #
    # Set current hash tables
    #
    $current_open_data_profile = $open_data_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;
}

#***********************************************************************
#
# Name: Print_Error
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             error_string - error string
#
# Description:
#
#   This function prints error messages if debugging is enabled..
#
#***********************************************************************
sub Print_Error {
    my ( $line, $column, $text, $error_string ) = @_;

    #
    # Print error message if we are in debug mode
    #
    if ( $debug ) {
        print "$error_string\n";
    }
}

#***********************************************************************
#
# Name: Record_Result
#
# Parameters: testcase - testcase identifier
#             line - line number
#             column - column number
#             text - text from tag
#             error_string - error string
#
# Description:
#
#   This function records the testcase result.
#
#***********************************************************************
sub Record_Result {
    my ( $testcase, $line, $column, $text, $error_string ) = @_;

    my ($result_object);

    #
    # Is this testcase included in the profile
    #
    if ( defined($testcase) && defined($$current_open_data_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $check_fail,
                                                Open_Data_Testcase_Description($testcase),
                                                $line, $column, $text,
                                                $error_string, $current_url);
        push (@$results_list_addr, $result_object);

        #
        # Print error string to stdout
        #
        Print_Error($line, $column, $text, "$testcase : $error_string");
    }
}

#***********************************************************************
#
# Name: Check_UTF8_BOM
#
# Parameters: json_file - JSON file object
#             data_file_object - a data file object pointer
#
# Description:
#
#   This function reads the passed file object and checks to see
# if a UTF-8 BOM is present.  If one is, the current reading position
# is set to just after the BOM.  The avoids parsing errors with the
# file.
#
# UTF-8 BOM = $EF $BB $BF
# Byte Order Mark - http://en.wikipedia.org/wiki/Byte_order_mark
#
# Note: The JSON specification https://tools.ietf.org/html/rfc7159
# states:
#
#  Implementations MUST NOT add a byte order mark to the beginning of a
#  JSON text.  In the interests of interoperability, implementations
#  that parse JSON texts MAY ignore the presence of a byte order mark
#  rather than treating it as an error.
#
# So while the BOM MUST NOT be included, we check for it and report it
# missing if it is not present.  If JSON data files are viewed in a web
# browser, special or accented characters may not be displayed properly
# if there is no BOM and the web server does not set the character encoding.
#
#***********************************************************************
sub Check_UTF8_BOM {
    my ($json_file, $data_file_object) = @_;

    my ($line, $char, $have_bom);

    #
    # Get a line of content from the file
    #
    print "Check_UTF8_BOM\n" if $debug;
    $line = $json_file->getline();

    #
    # Check first character of line for character 65279 (xFEFF)
    #
    print "line = \"$line\"\n" if $debug;
    $char = substr($line, 0, 1);
    if ( ord($char) == 65279 ) {
        #
        # Set reading position at character 3
        #
        print "Skip over BOM xFEFF\n" if $debug;
        seek($json_file, 3, 0);
        $line = $json_file->getline();
        print "line = \"$line\"\n" if $debug;
        seek($json_file, 3, 0);
        $have_bom = 1;
    }
    elsif ( $line =~ s/^\xEF\xBB\xBF// ) {
        #
        # Set reading position at character 3
        #
        print "Skip over BOM xEFBBBF\n" if $debug;
        seek($json_file, 3, 0);
        $line = $json_file->getline();
        print "line = \"$line\"\n" if $debug;
        seek($json_file, 3, 0);
        $have_bom = 1;
    }
    else {
        #
        # Reposition to the beginning of the file
        #
        print "Reset reading position to beginning of the file\n" if $debug;
        seek($json_file, 0, 0);
        $have_bom = 0;
    }
    
    #
    # Did we find a BOM? if so set the encoding of the data file.
    #
    if ( $have_bom && defined($data_file_object) ) {
        $data_file_object->encoding("UTF-8");
    }

    #
    # Are we missing the encoding for the data file (either from the
    # HTTP::Response object or by the presence of a BOM).
    #
    if ( (! defined($data_file_object)) ||
         ($data_file_object->encoding() ne "UTF-8") ) {
        #
        # No data file object or encoding is not UTF-8 in the HTTP::Response
        # object.  Are we missing a UTF-8 BOM in the content?
        #
        if ( ! $have_bom ) {
            Record_Result("OD_ENC", 1, 0, $line,
                          String_Value("Missing UTF-8 BOM or charset=utf-8"));
        }
    }
    
    #
    # Return flag to indicate if we found a BOM or not
    #
    return($have_bom);
}

#***********************************************************************
#
# Name: Open_Data_JSON_Check_API
#
# Parameters: this_url - a URL
#             data_file_object - a data file object pointer
#             profile - testcase profile
#             filename - JSON content filename
#
# Description:
#
#   This function runs a number of open data checks on JSON API content.
#
#***********************************************************************
sub Open_Data_JSON_Check_API {
    my ( $this_url, $data_file_object, $profile, $filename) = @_;

    my (@tqa_results_list, $result_object, $testcase, $eval_output, $ref);
    my ($content, $line, $fh, $have_bom);

    #
    # Do we have a valid profile ?
    #
    print "Open_Data_JSON_Check_API: Checking URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($open_data_profile_map{$profile}) ) {
        print "Open_Data_JSON_Check_API: Unknown testcase profile passed $profile\n";
        return(@tqa_results_list);
    }

    #
    # Save URL in global variable
    #
    if ( ($this_url =~ /^http/i) || ($this_url =~ /^file/i) ) {
        $current_url = $this_url;
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of JSON
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Open the API content file
    #
    open($fh, "$filename") ||
        die "Open_Data_JSON_Check_API: Failed to open $filename for reading\n";
    binmode $fh;

    #
    # Check for UTF-8 BOM (Byte Order Mark) at the top of the
    # file
    #
    $have_bom = Check_UTF8_BOM($fh, $data_file_object);

    #
    # Read the content
    #
    $content = "";
    while ( $line = <$fh> ) {
        $content .= $line;
    }
    close($fh);
    
    #
    # Replace the file contents with the same contents minus any BOM
    #
    if ( $have_bom ) {
        unlink($filename);
        open($fh, "> $filename") ||
           die "Open_Data_JSON_Check_API: Failed to open $filename for writing\n";
        binmode $fh;
        print $fh $content;
        close($fh);
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Did we get any content ?
    #
    if ( length($content) == 0 ) {
        print "No content passed to Open_Data_JSON_Check_API\n" if $debug;
        Record_Result("OD_VAL", -1, 0, "",
                      String_Value("No content in API"));
    }
    else {
        #
        # Parse the content.
        #
        if ( ! eval { $ref = decode_json($content); 1 } ) {
            $eval_output = $@;
            $eval_output =~ s/ at \S* line \d*\.$//g;
            Record_Result("OD_VAL", -1, 0, "",
                          String_Value("Fails validation") . " $eval_output");
        }
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "Open_Data_JSON_Check_API results\n";
        foreach $result_object (@tqa_results_list) {
            print "Testcase: " . $result_object->testcase;
            print "  message  = " . $result_object->message . "\n";
        }
    }

    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Validate_JSON_Against_Schema
#
# Parameters: this_url - a URL
#             json_filename - JSON content file
#             schema_url - URL of JSON schema
#
# Description:
#
#   This function retrieves the JSON schema using the specified URL.
# It them validates the JSON data file against the schema.
#
#***********************************************************************
sub Validate_JSON_Against_Schema {
    my ($this_url, $json_filename, $schema_url) = @_;

    my ($resp_url, $resp, $schema_filename, $output);
    
    #
    # Do we have a schema URL
    #
    if ( $schema_url eq "" ) {
        Record_Result("OD_VAL", -1, 0, "",
                      String_Value("Missing Schema value"));
        return;
    }

    #
    # Get the JSON schema file
    #
    print "Validate_JSON_Against_Schema schema URL = $schema_url\n" if $debug;
    ($resp_url, $resp) = Crawler_Get_HTTP_Response($schema_url, "");

    #
    # Is this a valid URI ?
    #
    if ( ! defined($resp) ) {
        Record_Result("OD_VAL", "", "", "",
                      String_Value("Invalid URL in Schema") .
                      " \"$schema_url\"");
    }
    #
    # Is it a broken link ?
    #
    elsif ( ! $resp->is_success ) {
        Record_Result("OD_VAL", "", "", "",
                      String_Value("Broken link in Schema") .
                      " \"$schema_url\"");
    }
    else {
        #
        # Get the schema file name from the HTTP::Response object
        #
        if ( defined($resp->header("WPSS-Content-File")) ) {
            $schema_filename = $resp->header("WPSS-Content-File");
            print "JSON Schema file name = $schema_filename\n" if $debug;
        }
    }
    
    #
    # If we have a schema file, validate the JSON data against the schema
    #
    if ( defined($schema_filename) ) {
        #
        # Run the schema validator
        #
        print "$json_schema_validator \"$schema_filename\" \"$json_filename\"\n" if $debug;
        $output = `$json_schema_validator \"$schema_filename\" \"$json_filename\" 2>\&1`;
        
        #
        # Did the validator pass ?
        #
        if ( $output =~ /Validation Passed/i ) {
            print "Validation passed\n" if $debug;
        }
        elsif ( $output =~ /Schema Error/i ) {
            print "Schema Error\n" if $debug;
            Record_Result("OD_VAL", -1, -1, "",
                          String_Value("json_schema_validator failed") .
                          " Schema: $schema_url\n" .
                          " \"$output\"");
        }
        elsif ( $output =~ /Validation Error/i ) {
            print "Validation Error\n" if $debug;
            Record_Result("OD_VAL", -1, -1, "",
                          String_Value("json_schema_validator failed") .
                          " Schema: $schema_url\n" .
                          " \"$output\"");
        }
        else {
            #
            # Runtime error with JSON schema validator
            #
            print "Runtime error, output = \"$output\"\n" if $debug;
            print STDERR "json_schema_validator command failed\n";
            print STDERR "  $json_schema_validator $schema_filename $json_filename\n";
            print STDERR "$output\n";

            #
            # Report runtime error only once
            #
            if ( ! $runtime_error_reported ) {
                Record_Result("OD_VAL", -1, -1, "",
                              String_Value("Runtime Error") .
                              " Schema: $schema_url\n" .
                              " \"$json_schema_validator $schema_filename $json_filename\"\n" .
                              " \"$output\"");
                $runtime_error_reported = 1;
            }
        }
        
        #
        # Clean up the schema file
        #
        unlink($schema_filename);
    }
}

#***********************************************************************
#
# Name: Check_JSON_Schema
#
# Parameters: this_url - a URL
#             filename - JSON content file
#             ref - reference to the decoded JSON
#
# Description:
#
#   This function checks for a schema specification in the JSON data.
# A primary schema must be specified with a "$schema" object.  Optional
# extension schemas may be specified with a "$schemaExtension" object.
# The data is validated against all schemas specified.
#
#***********************************************************************
sub Check_JSON_Schema {
    my ($this_url, $filename, $ref) = @_;

    my ($schema, $ref_type, @schema_urls, $schema_url);

    #
    # Check for a $schema name/value object in the JSON data
    #
    print "Check_JSON_Schema\n" if $debug;
    if ( ! defined($$ref{'$schema'}) ) {
        #
        # No schema specified
        #
        Record_Result("OD_VAL", -1, 0, "",
                      String_Value("No Schema found in JSON file"));
    }
    else {
        #
        # Found a schema specification
        #
        $schema = $$ref{'$schema'};

        #
        # Is this a single schema (variable is not a reference) or
        # an array of schemas
        #
        $ref_type = ref $schema;
        print "Schema ref type = $ref_type\n" if $debug;
        if ( $ref_type eq "" ) {
            Validate_JSON_Against_Schema($this_url, $filename, $schema);
        }
        else {
            Record_Result("OD_VAL", -1, 0, "",
              String_Value("Invalid Schema specification in JSON file") .
                           " ref = $ref_type");
        }
    }

    #
    # Check for a $schemaExtension name/value object in the JSON data
    #
    print "Check for schema extensions\n" if $debug;
    if ( defined($$ref{'$schemaExtension'}) ) {
        #
        # Found a schema extension specification
        #
        $schema = $$ref{'$schemaExtension'};

        #
        # Is this a single schema (variable is not a reference) or
        # an array of schemas
        #
        $ref_type = ref $schema;
        print "Schema ref type = $ref_type\n" if $debug;
        if ( $ref_type eq "" ) {
            Validate_JSON_Against_Schema($this_url, $filename, $schema);
        }
        elsif ( $ref_type eq "ARRAY" ) {
            #
            # Do we have schema values?
            #
            if ( @$schema == 0 ) {
                Record_Result("OD_VAL", -1, 0, "",
                      String_Value("Missing Schema value"));
            }

            #
            # Validate the JSON data against all schemas specified.
            #
            foreach $schema_url (@$schema) {
                Validate_JSON_Against_Schema($this_url, $filename, $schema_url);
            }
        }
        else {
            Record_Result("OD_VAL", -1, 0, "",
              String_Value("Invalid Schema specification in JSON file") .
                           " ref = $ref_type");
        }
    }
}

#***********************************************************************
#
# Name: Check_JSON_Data
#
# Parameters: this_url - a URL
#             data_file_object - a data file object pointer
#             filename - JSON content file
#             ref - reference to the decoded JSON
#
# Description:
#
#   This function checks to see if the data appears to be a
# JSON CSV file (i.e. contains a data array of objects).
#
#  { "$schema": "<schema url>",
#    "data": [{
#              "field 1": "Value 1",
#              "field 2": "Value 2",
#                ....
#              "field n": "Value n"
#             }
#             ...
#            ]
#  }
#
# If it is a JSON CSV, it checks each of the data array items.
# The items are expected to contain objects that have fields that
# match data dictionary entries. The field values are checked
# against any regular expressions specified for data dictionary
# headings.
#
#***********************************************************************
sub Check_JSON_Data {
    my ($this_url, $data_file_object, $filename, $ref) = @_;

    my ($data, $ref_type, $heading, $regex, $item, $i);
    my ($key, $value, $field_count, $expected_field_count);
    my (%data_checksum, $checksum);

    #
    # Check for a "data" name/value object in the JSON data
    #
    print "Check_JSON_Data\n" if $debug;
    if ( ! defined($$ref{'data'}) ) {
        #
        # No data field, does not appear to be a JSON CSV file
        #
        print "No data field found, skip JSON data checks\n" if $debug;
        return;
    }
    
    #
    # Found a data field
    #
    $data = $$ref{'data'};

    #
    # Is this an array object?
    #
    $ref_type = ref $data;
    if ( $ref_type eq "ARRAY" ) {
        #
        # Found a data array, are each of the items in the array
        # an object (Perl hash)?
        #
        $item = $$data[0];
        $ref_type = ref $item;
        print "Data ref type = $ref_type\n" if $debug;
        if ( $ref_type eq "HASH" ) {
            #
            # Appears to be a JSON-CSV file, that is CSV data encoded in
            # JSON syntax.
            #
            print "Found data array field, assuming content is JSON-CSV format\n" if $debug;
            $data_file_object->format("JSON-CSV");
        }
        else {
            #
            # Not a JSON-CSV data file
            #
            print "data array items are not objects (hash) type = $ref_type, skip JSON-CSV data checks\n" if $debug;
            return;
        }
    }
    else {
        #
        # Not a JSON-CSV data file
        #
        print "data is not an array type = $ref_type, skip JSON-CSV data checks\n" if $debug;
        return;
    }

    #
    # Check each item in the array for field/value pairs
    #
    for ($i = 0; $i < @$data; $i++) {
        $item = $$data[$i];
        
        #
        # Is the item an object (hash reference)?
        #
        $ref_type = ref $item;
        print "Data ref type = $ref_type\n" if $debug;
        if ( $ref_type eq "HASH" ) {
            #
            # Check for a consistent number of fields in each array element.
            # If this is the first array element, use it's field count
            # as the expected field count.
            #
            $field_count = keys(%$item);
            if ( $i == 0 ) {
                $expected_field_count = $field_count;
                $data_file_object->attribute($column_count_attribute, $field_count);
            }
            elsif ( $field_count != $expected_field_count ) {
                Record_Result("OD_DATA", ($i + 1), 0, "",
                              String_Value("Inconsistent number of fields, found") .
                              " $field_count " . String_Value("expecting") .
                              " $expected_field_count");
            }

            #
            # Check each item in the hash for a match with a data
            # dictionary term.
            #
            while ( ($key, $value) = each %$item ) {
                #
                # Does this key match a data dictionary heading ?
                #
                if ( defined($$dictionary_ptr{$key}) ) {
                    print "Found field for dictionary heading tag $key, value \"$value\"\n" if $debug;

                    #
                    # Do we have a regular expression for this heading ?
                    #
                    $heading = $$dictionary_ptr{$key};
                    $regex = $heading->regex();

                    if ( $regex ne "" ) {
                        #
                        # Run the regular expression against the content
                        #
                        if ( ! ($value =~ qr/$regex/) ) {
                            #
                            # Regular expression pattern fails
                            #
                            print "Regular expression failed for heading $key, regex = $regex, data = $value\n" if $debug;
                            Record_Result("OD_DATA", ($i + 1), -1, "",
                                          String_Value("Data pattern") .
                                          " \"$regex\" " .
                                          String_Value("failed for value") .
                                          " \"$value\" " .
                                          String_Value("Field") . " \"" .
                                          $heading->term() . "\"");
                        }
                    }
                }
            }

            #
            # Generate a checksum of the row content.
            #
            $checksum = md5_hex(encode_utf8(to_json($item)));

            #
            # Have we seen this checksum before ? If so we have a duplicate
            # row of content.
            #
            print "Check for duplicate row, checksum = $checksum\n" if $debug;
            if ( defined($data_checksum{$checksum}) ) {
                Record_Result("OD_DATA", ($i + 1), 0, encode_utf8(to_json($item)),
                              String_Value("Duplicate data array content, first instance at") .
                              " " . $data_checksum{$checksum});
            }
            else {
                #
                # Record this checksum and row number
                #
                $data_checksum{$checksum} = ($i + 1);
            }
        }
        else {
            print "data item is not a hash table, skip JSON data checks\n" if $debug;
            last;
        }
    }

    #
    # Save the data array item count
    #
    $data_file_object->attribute($row_count_attribute, scalar(@$data));
}

#***********************************************************************
#
# Name: Open_Data_JSON_Check_Data
#
# Parameters: this_url - a URL
#             data_file_object - a data file object pointer
#             profile - testcase profile
#             filename - JSON content file
#             dictionary - address of a hash table for data dictionary
#
# Description:
#
#   This function runs a number of open data checks on JSON data file content.
#
#***********************************************************************
sub Open_Data_JSON_Check_Data {
    my ($this_url, $data_file_object, $profile, $filename, $dictionary) = @_;
    
    my (@tqa_results_list, $result_object, $testcase, $eval_output, $ref);
    my ($content, $line, $json_file, $schema, $ref_type, @schema_urls);
    my ($schema_url, $fh, $have_bom);

    #
    # Do we have a valid profile ?
    #
    print "Open_Data_JSON_Check_Data Checking URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($open_data_profile_map{$profile}) ) {
        print "Open_Data_JSON_Check_Data Unknown testcase profile passed $profile\n";
        return(@tqa_results_list);
    }

    #
    # Save URL in global variable
    #
    if ( ($this_url =~ /^http/i) || ($this_url =~ /^file/i) ) {
        $current_url = $this_url;
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of JSON
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Save data dictionary pointer
    #
    $dictionary_ptr = $dictionary;

    #
    # Open the JSON file for reading.
    #
    print "Open JSON file $filename\n" if $debug;
    open($fh, "$filename") ||
        die "Open_Data_JSON_Check_Data Failed to open $filename for reading\n";
    binmode $fh;

    #
    # Check for UTF-8 BOM (Byte Order Mark) at the top of the
    # file.
    #
    $have_bom = Check_UTF8_BOM($fh, $data_file_object);

    #
    # Read the content
    #
    $content = "";
    while ( $line = <$fh> ) {
        $content .= $line;
    }
    close($fh);
    
    #
    # Replace the file contents with the same contents minus any BOM
    #
    if ( $have_bom ) {
        unlink($filename);
        open($fh, "> $filename") ||
           die "Open_Data_JSON_Check_Data Failed to open $filename for writing\n";
        binmode $fh;
        print $fh $content;
        close($fh);
    }
    
    #
    # Did we get any content ?
    #
    if ( length($content) == 0 ) {
        print "No content passed to Open_Data_JSON_Check_Data\n" if $debug;
        Record_Result("OD_VAL", -1, 0, "", String_Value("No content in file"));
    }
    else {
        #
        # Parse the content.
        #
        print " Content length = " . length($content) . "\n" if $debug;
        if ( ! eval { $ref = decode_json($content); 1 } ) {
            $eval_output = $@;
            $eval_output =~ s/ at \S* line \d*\.$//g;
            Record_Result("OD_VAL", -1, 0, "",
                          String_Value("Fails validation") . " $eval_output");
        }
        else {
            #
            # Check for a $schema and validate against it
            #
            Check_JSON_Schema($this_url, $filename, $ref);
            
            #
            # Check JSON data
            #
            Check_JSON_Data($this_url, $data_file_object, $filename, $ref);
        }
    }

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "Open_Data_JSON_Check_Data results\n";
        foreach $result_object (@tqa_results_list) {
            print "Testcase: " . $result_object->testcase;
            print "  message  = " . $result_object->message . "\n";
        }
    }

    #
    # Return list of results
    #
    return(@tqa_results_list);
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
# Get the directory path that python is installed in
#
($python_file, $filename) = tempfile("WPSS_TOOL_XXXXXXXXXX",
                              SUFFIX => '.py',
                              TMPDIR => 1);
print $python_file "import os\n";
print $python_file "import sys\n";
print $python_file "print os.path.dirname(sys.executable)\n";
close($python_file);

#
# Generate path the the JSON schema validator
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $python_output = `$filename 2>\&1`;
    $python_output =~ s/^[A-Z]://ig;
    chop($python_output);
    $python_path = "$program_dir\\python" . "$python_output\\Lib\\site-packages";
    $json_schema_validator = ".\\bin\\json_schema_validator.py";
} else {
    #
    # Not Windows.
    #
    $python_output = `python $filename 2>\&1`;
    chop($python_output);
    $python_path = "$program_dir/python/usr/local/lib/python2.7/dist-packages";
    $json_schema_validator = "python bin/json_schema_validator.py";
}
unlink($filename);

#
# Set PYTHONPATH environment variable
#
if ( defined($ENV{"PYTHONPATH"}) ) {
    $ENV{"PYTHONPATH"} .= ";$python_path";
}
else {
    $ENV{"PYTHONPATH"} = "$python_path";
}

#
# Return true to indicate we loaded successfully
#
return 1;

