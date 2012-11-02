#***********************************************************************
#
# Name:   url_check.pm
#
# $Revision: 6062 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/TQA_Check/Tools/url_check.pm $
# $Date: 2012-10-22 17:06:17 -0400 (Mon, 22 Oct 2012) $
#
# Description:
#
#   This file contains routines that check URL syntax and meaning.
#
# Public functions:
#     URL_Check
#     URL_Check_Debug
#     URL_Check_GET_URL_Language
#     URL_Check_Get_English_URL
#     URL_Check_Is_URL
#     URL_Check_Parse_URL
#     Set_URL_Check_Language
#     Set_URL_Check_Test_Profile
#     Set_URL_Check_Testcase_Data
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

package url_check;

use strict;
use File::Basename;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(URL_Check
                  URL_Check_Debug
                  URL_Check_GET_URL_Language
                  URL_Check_Get_English_URL
                  URL_Check_Is_URL
                  URL_Check_Parse_URL
                  Set_URL_Check_Language
                  Set_URL_Check_Test_Profile
                  Set_URL_Check_Testcase_Data
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
my ($results_list_addr, $current_url);
my (%url_check_profile_map, $current_testcase_profile, %testcase_data);

#
# Status values
#
my ($url_check_pass)       = 0;
my ($url_check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "File name language suffix is not 3 character",  "File name language suffix is not a 3 character language code",
    "Language variable is not 3 character",  "Language variable is not 3 a character language code",
    "Language variable is not one of the first three", "Language variable is not one of the first three parameter/variable pairs",
    "Directory and file suffix language mismatch", "Directory and file suffix language mismatch",
    "Directory and URL variable language mismatch", "Directory and URL variable language mismatch",
    "File suffix and URL variable language mismatch", "File suffix and URL variable language mismatch",
    "Multiple URL variable languages",  "Multiple URL variable languages",
    );

my %string_table_fr = (
    "File name language suffix is not 3 character",  "Fichier suffixe de langue le nom n'est pas un code de langue de 3 caractères",
    "Language variable is not 3 character",  "Variable de la langue n'est pas un code de langue 3 caractères",
    "Language variable is not one of the first three", "Variable de la langue n'est pas l'un des trois premiers paramètre / paires variable",
    "Directory and file suffix language mismatch", "Répertoires et des fichiers non-concordance langue suffixe",
    "Directory and URL variable language mismatch", "Répertoires et l'inadéquation des langues URL variable",
    "File suffix and URL variable language mismatch", "Fichier inadéquation suffixe et URL langue variable",
    "Multiple URL variable languages",  "Plusieurs langues variable d'URL",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#
#******************************************************************
#
# String table for testcase help URLs
#
#******************************************************************
#

my (%testcase_url_en, %testcase_url_fr);

#
# Default URLs to English
#
my ($url_table) = \%testcase_url_en;

#
# String tables for testcase ID to testcase descriptions
#
my (%testcase_description_en) = (
"TBS_P1_R2", "TBS Part 1, R2: Page addresses",
"TP_PW_URL",       "TP_PW_URL: Page addresses",
);

my (%testcase_description_fr) = (
"TBS_P1_R2", "SCT Partie 1, E2: Adresses de page",
"TP_PW_URL",        "TP_PW_URL: Adresses de page",
);

#
# Create reverse table, indexed by description
#
my (%reverse_testcase_description_en) = reverse %testcase_description_en;
my (%reverse_testcase_description_fr) = reverse %testcase_description_fr;
my ($reverse_testcase_description_table) = \%reverse_testcase_description_en;

#
# Default messages to English
#
my ($testcase_description_table) = \%testcase_description_en;

#***********************************************************************
#
# Name: URL_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub URL_Check_Debug {
    my ($this_debug) = @_;

    #
    # Set debug flag in supporting modules
    #
    TQA_Result_Object_Debug($this_debug);
    
    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: URL_Check_Parse_URL
#
# Parameters: url
#
# Description:
#
#   This function parses a URL and returns its components.  The components
# returned are the protocol, domain name, page directory/file name as 
# the query parameters.
#
# Returns:
#    URL components (protocol, domain, file path, query)
#    Reconstructed URL
#
#***********************************************************************
sub URL_Check_Parse_URL {
    my ($url) = @_;

    my ($protocol, $domain, $file_path, $query, $drive);

    #
    # Do we have a leading http or https ?
    #
    print "URL_Check_Parse_URL: $url\n" if $debug;
    if ( $url =~ /^http[s]?:\// ) {
        #
        # Get components of the URL, we expect 1 of the following
        #   http://domain/path?query
        #   http://domain/path#anchor
        #   https://domain/path?query
        #   https://domain/path#anchor
        #
        ($protocol, $domain, $file_path, $query) =
          $url =~ /^(http[s]?:)\/\/?([^\/\s]+)\/([\/\w\-\.\%]*[^#?]*)(.*)?$/io;
    }
    elsif ( $url =~ /^file:\// ) {
        #
        # Get components of the URL, we expect 1 of the following
        #   file://path
        #   file:///path
        #   file://drive:/path
        #
        ($protocol, $domain, $file_path) =
          $url =~ /^(file:)\/\/*(\w+):\/([\/\w\-\.\%]*)$/io;
        $query = "";
    }
    elsif ( $url =~ /^ftp:\// ) {
        #
        # Get components of the URL, we expect 1 of the following
        #   ftp://domain/path
        #
        ($protocol, $domain, $file_path) =
          $url =~ /^(ftp:)\/\/?([^\/\s]+)\/([\/\w\-\.\%]*)$/io;
        $query = "";
    }
    
    #
    # Did we get a domain ?
    #
    if ( ! defined($domain) ) {
        #
        # Perhaps we are missing the / after the domain ?
        #  http://domain?query
        #
        ($protocol, $domain, $query) =
          $url =~ /^(http[s]?:)\/\/?([^\/\s#?]*)(.*)?$/io;
        $file_path = "/";
    }

    #
    # Do we have a protocol ?
    #
    if ( defined($protocol) ) {
        #
        # Make sure protocol is in lowercase
        #
        $protocol =~ tr/A-Z/a-z/;

        #
        # Change double slash (//) into a single slash in the file path
        #
        while ( $file_path =~ /\/\// ) {
            $file_path =~ s/\/\//\//g;
        }

        #
        # If we again didn't get anthing, return empty strings
        #
        if ( ! defined($domain) ) {
            $protocol = "";
            $domain = "";
            $file_path = "";
            $query = "";
        }

        #
        # Reconstruct the URL properly
        #
        if ( $file_path ne "/" ) {
            $url = "$protocol//$domain/$file_path$query";
        }
        else {
            $url = "$protocol//$domain/$query";
        }
    }
    else {
        #
        # No leading http, ignore URL as we don't care about non-http
        # URLs.
        #
        $protocol = "";
        $domain = "";
        $file_path = "";
        $query = "";
        $url = "";
    }

    #
    # Return URL components and reconstructed URL
    #
    print "URL components protocol = $protocol, domain = $domain, file_path = $file_path, query = $query\n" if $debug;
    print "reconstructed URL = $url\n" if $debug;
    return ($protocol, $domain, $file_path, $query, $url);
}

#***********************************************************************
#
# Name: URL_Check_Is_URL
#
# Parameters: text
#
# Description:
#
#   This function tries to determine the supplied text is a URL.
# It looks for a leading protocol specification (http: or https:)
# followed by a domain, file path and optional query.
#
#***********************************************************************
sub URL_Check_Is_URL {
    my ($text) = @_;

    my ($protocol, $domain, $file_path, $query, $url);
    my ($is_url) = 0;

    #
    # Do we have a leading http or https ?
    #
    print "URL_Check_Is_URL, check \"$text\"\n" if $debug;
    if ( $text =~ /^http[s]?:\// ) {
        #
        # Got leading protocol, try to parse the rest of the string
        # as a URL
        #
        ($protocol, $domain, $file_path, $query, $url) =
            URL_Check_Parse_URL($text);

        #
        # If we got a domain, the the text appears to be a URL
        #
        if ( $domain ne "" ) {
            $is_url = 1;
        }
    }

    #
    # Return status
    #
    print "Is URL = $is_url\n" if $debug;
    return($is_url);
}

#***********************************************************************
#
# Name: URL_Check_GET_URL_Language
#
# Parameters: url
#
# Description:
#
#   This function tries to determine the language of the URL.  It
# looks for a language directory (e.g. /eng/), suffix (e.g. -eng, -fra)
# or a lang/language URL variable (e.g. lang=eng).  The 3 character language 
# code is returned.
#
#***********************************************************************
sub URL_Check_GET_URL_Language {
    my ($url) = @_;

    my ($protocol, $domain, $file_path, $query, $arg, $language, @dir_paths);
    my ($dir, $file_suffix, $new_url);

    #
    # Get components of the URL, we only check the file path portion
    #
    print "URL_Check_GET_URL_Language: Get language of $url\n" if $debug;
    ($protocol, $domain, $file_path, $query, $new_url) = 
        URL_Check_Parse_URL($url);

    #
    # Check for a directory matching a language
    #
    @dir_paths = split(/\//, $file_path);
    foreach $dir (@dir_paths) {
        if ( $dir ne "" ) {
            #
            # Is the directory a full language name (e.g. english) ?
            #
            if ( defined($language_map::language_iso_639_2T_map{$dir}) ) {
                $language = $language_map::language_iso_639_2T_map{$dir};
                print "Directory $dir -> $language\n" if $debug;
            }
            #
            # Is the directory a 3 character language code (e.g. eng) ?
            #
            elsif ( defined($language_map::iso_639_2T_languages{$dir}) ) {
                print "Directory $dir\n" if $debug;
                $language = $dir;
            }
        }
    }

    #
    # If we don't have a language yet, look for a language suffix in
    # the file name
    #
    if ( ! defined($language) ) {
        #
        # Check for a 1..3 letter language suffix in the file name
        # (before the file type).
        #
        ($file_suffix) = $file_path =~ /^[\w\/\-_\.]*[\-_]([a-zA-Z]{1,3})\..*/;
        $file_suffix = lc($file_suffix);

        #
        # Check for a 3 character language
        #
        if ( defined($language_map::iso_639_2T_languages{$file_suffix}) ) {
            $language = $file_suffix;
            print "3 character language suffix $file_suffix\n" if $debug;
        }
        #
        # Check for 2 character language
        #
        elsif ( defined($language_map::iso_639_1_iso_639_2T_map{$file_suffix}) ) {
            $language = $language_map::iso_639_1_iso_639_2T_map{$file_suffix};
            print "2 character language suffix $file_suffix -> $language\n" if $debug;
        }
        #
        # Check for 1 character language
        #
        elsif ( defined($language_map::one_char_iso_639_2T_map{$file_suffix}) ) {
            $language = $language_map::one_char_iso_639_2T_map{$file_suffix};
            print "1 character language suffix $file_suffix -> $language\n" if $debug;
        }
    }

    #
    # If we still don't have a language, look for a lang/language URL argument
    #
    if ( ! defined($language) ) {
        #
        # Could not determine language from URL, check for a lang 
        # or language argument.
        #
        $query =~ s/^\?//g;
        foreach $arg (split(/[&;]/, $query) ) {
            if ( ($arg =~ /^lang=/i) || ($arg =~ /^language=/i) ) {
                #
                # Got language argument, get it's value
                #
                $arg =~ s/^lang=//i;
                $arg =~ s/^language=//i;
                $arg =~ s/"//g;
                $arg =~ s/'//g;
                print "Check language $arg\n" if $debug;

                #
                # Check for a 3 character language
                #
                if ( defined($language_map::iso_639_2T_languages{$arg}) ) {
                    $language = $arg;
                    print "3 character lang value $arg\n" if $debug;
                }
                #
                # Check for 2 character language
                #
                elsif ( defined($language_map::iso_639_1_iso_639_2T_map{$arg}) ) {
                    $language = $language_map::iso_639_1_iso_639_2T_map{$arg};
                    print "2 character lang value $arg -> $language\n" if $debug;
                }
                #
                # Check for 1 character language
                #
                elsif ( defined($language_map::one_char_iso_639_2T_map{$arg}) ) {
                    $language = $language_map::one_char_iso_639_2T_map{$arg};
                    print "1 character lang value $arg -> $language\n" if $debug;
                }

                #
                # We found lang= or language=, stop looking at arguments.
                #
                last;
            }
        }
    }

    #
    # If we still dont't have a language, set it to the unknown language
    #
    if ( ! defined($language) ) {
        $language = "";
        print "Unable to determine URL language\n" if $debug;
    }
    else {
        print "URL_Check_GET_URL_Language lang = $language, language = " .
              $language_map::iso_639_2T_languages{$language} . "\n" if $debug;
    }

    #
    # Return language
    #
    return($language);
}

#***********************************************************************
#
# Name: URL_Check_Get_English_URL
#
# Parameters: url
#
# Description:
#
#   This function attempts to convert the supplied URL into an English
# URL.  This is done by replacing any language identifier with the
# corresponding English identifier (e.g. -fra becomes -eng).  If a
# translation cannot be done and empty string is returned.
#
#***********************************************************************
sub URL_Check_Get_English_URL {
    my ($url) = @_;

    my ($protocol, $domain, $file_path, $query, $arg, $lang, @dir_paths);
    my ($dir, $file_suffix, $new_url, $file_name, $language_suffix);
    my ($english_url, $english_file_path, @arg_list, $arg_name);
    my ($english_arg, $i, $delimiter);

    #
    # Get components of the URL, we only check the file path portion
    #
    print "URL_Check_Get_English_URL: Convert to English $url\n" if $debug;
    ($protocol, $domain, $file_path, $query, $new_url) =
        URL_Check_Parse_URL($url);

    #
    # Check for possible language directory paths in the URL.  If
    # these are present then it is most likely that we cannot translate
    # the URL as the file name is likely to be language specific.
    #
    @dir_paths = split(/\//, $file_path);
    foreach $dir (@dir_paths) {
        if ( $dir ne "" ) {
            #
            # Is the directory a full language name (e.g. english) ?
            #
            if ( defined($language_map::language_iso_639_2T_map{$dir}) ) {
                $english_url = "";
                print "Directory $dir\n" if $debug;
            }
            #
            # Is the directory a 3 character language code (e.g. eng) ?
            #
            elsif ( defined($language_map::iso_639_2T_languages{$dir}) ) {
                print "Directory $dir\n" if $debug;
                $english_url = "";
            }
        }
    }

    #
    # If we don't have a URL yet, look for a language suffix in
    # the file name. We will look for lower case only, if the suffix is in
    # uppercase we wont match it (too many possibilities with -ENG or -Eng)
    #
    if ( (! defined($english_url)) && ($file_path ne "/") ) {
        #
        # Check for a 1..3 letter language suffix in the file name
        # (before the file type).
        #
        ($file_name, $language_suffix, $file_suffix) = $file_path =~ /^([\w\/\-_\.]*[\-_])([a-zA-Z]{1,3})\.(.*)/;
        print "file name = $file_name, language_suffix = $language_suffix, file_suffix = $file_suffix\n" if $debug;

        #
        # Check for a 3 character language
        #
        if ( defined($language_map::iso_639_2T_languages{$language_suffix}) ) {
            $english_file_path = $file_name . "eng" . ".$file_suffix";
            print "3 character language suffix $language_suffix\n" if $debug;
        }
        #
        # Check for 2 character language
        #
        elsif ( defined($language_map::iso_639_1_iso_639_2T_map{$file_suffix}) ) {
            $english_file_path = $file_name . "en" . ".$file_suffix";
            print "2 character language suffix $language_suffix\n" if $debug;
        }
        #
        # Check for 1 character language
        #
        elsif ( defined($language_map::one_char_iso_639_2T_map{$file_suffix}) ) {
            $english_file_path = $file_name . "e" . ".$file_suffix";
            print "1 character language suffix $language_suffix\n" if $debug;
        }
        
        #
        # If we got an English file path, create the full English URL
        #
        if ( defined($english_file_path) ) {
            $english_url = "$protocol//$domain/$english_file_path$query";
        }
    }

    #
    # If we still don't have a URL, look for a lang or language URL
    # argument. Again we only consider a lower case language identifier.
    #
    if ( (! defined($english_url)) && ($query ne "") ) {
        #
        # Could not determine language from URL, check for a lang argument.
        #
        $query =~ s/^\?//g;
        @arg_list = split(/[&;]/, $query);
        for ($i = 0; $i < @arg_list; $i++) {
            $arg = $arg_list[$i];
            if ( ($arg =~ /^lang=/i) || ($arg =~ /^language=/i) ) {
                #
                # Got language argument, get it's value
                #
                ($arg_name, $lang, $delimiter) = $arg =~ /^(lang.*=['"]?)([a-zA-Z]{1,3})(.*)/i;
                
                #
                # Check for a 3 character language
                #
                if ( defined($language_map::iso_639_2T_languages{$lang}) ) {
                    $english_arg = $arg_name . "eng" . $delimiter;
                    print "3 character lang value $lang\n" if $debug;
                }
                #
                # Check for 2 character language
                #
                elsif ( defined($language_map::iso_639_1_iso_639_2T_map{$lang}) ) {
                    $english_arg = $arg_name . "en" . $delimiter;
                    print "2 character lang value $lang\n" if $debug;
                }
                #
                # Check for 1 character language
                #
                elsif ( defined($language_map::one_char_iso_639_2T_map{$lang}) ) {
                    $english_arg = $arg_name . "e" . $delimiter;
                    print "1 character lang value $lang\n" if $debug;
                }

                #
                # If we have an English argument, replace the original in
                # the argument list array.
                #
                if ( defined($english_arg) ) {
                    $arg_list[$i] = $english_arg;
                }
                
                #
                # We found lang= or language=, stop looking at arguments.
                #
                last;
            }
        }
        
        #
        # Join all arguments back into the query string.
        #
        if ( defined($english_arg) ) {
            $query = "?" . join("&", @arg_list);
            
            #
            # Reconstruct the URL properly
            #
            if ( $file_path ne "/" ) {
                $english_url = "$protocol//$domain/$file_path$query";
            }
            else {
                $english_url = "$protocol//$domain/$query";
            }
        }
    }

    #
    # If we still dont't have a URL, return empty string
    #
    if ( ! defined($english_url) ) {
        $english_url = "";
        print "Unable to translate URL\n" if $debug;
    }
    else {
        print "English URL = $english_url\n" if $debug;
    }

    #
    # Return English URL
    #
    return($english_url);
}

#***********************************************************************
#
# Name: Set_URL_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_URL_Check_Language {
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

#***********************************************************************
#
# Name: Set_URL_Check_Testcase_Data
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
sub Set_URL_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_URL_Check_Test_Profile
#
# Parameters: profile - url check test profile
#             url_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by testcase name.
#
#***********************************************************************
sub Set_URL_Check_Test_Profile {
    my ($profile, $url_checks ) = @_;

    my (%local_url_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_URL_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_url_checks = %$url_checks;
    $url_check_profile_map{$profile} = \%local_url_checks;
}

#**********************************************************************
#
# Name: Testcase_Description
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase description
# table for the specified key.  If there is no entry in the table an error
# string is returned.
#
#**********************************************************************
sub Testcase_Description {
    my ($key) = @_;

    #
    # Do we have a string table entry for this key ?
    #
    if ( defined($$testcase_description_table{$key}) ) {
        #
        # return value
        #
        return ($$testcase_description_table{$key});
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
# Name: Initialize_Test_Results
#
# Parameters: profile - testcase profile
#             local_results_list_addr - address of results list.
#
# Description:
#
#   This function initializes the test case results table.
#
#***********************************************************************
sub Initialize_Test_Results {
    my ($profile, $local_results_list_addr) = @_;

    my ($test_case); 

    #
    # Set current hash tables
    #
    $current_testcase_profile = $url_check_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;
}

#***********************************************************************
#
# Name: Record_Result
#
# Parameters: testcase - testcase identifier
#             line - line number
#             column - column number
#             text - source line
#             error_string - error message
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
    if ( defined($testcase) && defined($$current_testcase_profile{$testcase}) )
 {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $url_check_fail,
                                                Testcase_Description($testcase),
                                                $line, $column, $text,
                                                $error_string, $current_url);
        push (@$results_list_addr, $result_object);
    }
}

#***********************************************************************
#
# Name: Check_URL_Language_Consistency
#
# Parameters: url - a URL
#             dir_language - directory language
#             suffix_language - file suffix language
#             var_language - argument list language
#
# Description:
#
#   This function checks that if multiple languages are specified
# in a URL that they are consistent (e.g. one is not eng and another 
# is fra).
#
#***********************************************************************
sub Check_URL_Language_Consistency {
    my ($url, $dir_language, $suffix_language, $var_language) = @_;

    my ($tcid);

    #
    # Get testcase identifier
    #
    if ( defined($$current_testcase_profile{"TBS_P1_R2"}) ) {
        $tcid = "TBS_P1_R2";
    }
    elsif ( defined($$current_testcase_profile{"TP_PW_URL"}) ) {
        $tcid = "TP_PW_URL";
    }

    #
    # Do we have a directory language ?
    #
    if ( defined($dir_language) ) {
        #
        # If we have a suffix language, does it match ?
        #
        if ( defined($suffix_language) && 
           ($suffix_language ne $dir_language) ) {
            Record_Result($tcid, -1, 0, "",
                     String_Value("Directory and file suffix language mismatch")
                          . " ($dir_language/$suffix_language)");
        }

        #
        # If we have a URL variable language, does it match ?
        #
        if ( defined($var_language) && 
           ($var_language ne $dir_language) ) {
            Record_Result($tcid, -1, 0, "",
                     String_Value("Directory and URL variable language mismatch")
                          . " ($dir_language/$var_language)");
        }
    }

    #
    # Do we have a suffix language ?
    #
    if ( defined($suffix_language) ) {
        #
        # If we have a URL variable language, does it match ?
        #
        if ( defined($var_language) && 
           ($var_language ne $suffix_language) ) {
            Record_Result($tcid, -1, 0, "",
                     String_Value("File suffix and URL variable language mismatch")
                          . " ($suffix_language/$var_language)");
        }
    }

}

#***********************************************************************
#
# Name: Check_URL_Language
#
# Parameters: url - a URL
#
# Description:
#
#   This function checks the language of the URL.
#
#***********************************************************************
sub Check_URL_Language {
    my ($url) = @_;

    my ($protocol, $domain, $file_path, $query, $arg, @dir_paths);
    my ($dir, $file_suffix, $dir_language, $suffix_language);
    my ($var_language, $new_url, $last_var_language, $tcid);
    my ($arg_number) = 0;

    #
    # Get testcase identifier
    #
    if ( defined($$current_testcase_profile{"TBS_P1_R2"}) ) {
        $tcid = "TBS_P1_R2";
    }
    elsif ( defined($$current_testcase_profile{"TP_PW_URL"}) ) {
        $tcid = "TP_PW_URL";
    }

    #
    # Get components of the URL, we only check the file path portion
    #
    print "Check_URL_Language: $url\n" if $debug;
    ($protocol, $domain, $file_path, $query, $new_url ) = URL_Check_Parse_URL($url);

    #
    # Check for top level language directory
    #
    @dir_paths = split(/\//, $file_path);
    foreach $dir (@dir_paths) {
        if ( $dir ne "" ) {
            #
            # Is the directory a full language name (e.g. english) ?
            #
            print "Directory = $dir\n" if $debug;
            if ( defined($language_map::language_iso_639_2T_map{$dir}) ) {
                $dir_language = $language_map::language_iso_639_2T_map{$dir};
                print "Directory $dir -> $dir_language\n" if $debug;
            }
            #
            # Is the directory a 3 character language code (e.g. eng) ?
            #
            elsif ( defined($language_map::iso_639_2T_languages{$dir}) ) {
                print "Directory $dir\n" if $debug;
                $dir_language = $dir;
            }
        }
    }

    #
    # Check for a 1..3 letter language suffix in the file name
    # (before the file type).
    #
    ($file_suffix) = $file_path =~ /^[\w\/\-_\.]*[\-_]([a-zA-Z]{1,3})\..*/;
    if ( defined($file_suffix) && ($file_suffix ne "") ) {
        $file_suffix = lc($file_suffix);
        print "File suffix = $file_suffix\n" if $debug;

        #
        # Check for a 3 character language
        #
        if ( defined($language_map::iso_639_2T_languages{$file_suffix}) ) {
            $suffix_language = $file_suffix;
            print "3 character language suffix $file_suffix\n" if $debug;
        }
        #
        # Check for 2 character language
        #
        elsif ( defined($language_map::iso_639_1_iso_639_2T_map{$file_suffix}) ) {
            $suffix_language = $language_map::iso_639_1_iso_639_2T_map{$file_suffix};
            print "2 character language suffix $file_suffix -> $suffix_language\n" if $debug;
        
            #
            # Should not use 2 character language
            #
            Record_Result($tcid, -1, 0, "",
                          String_Value("File name language suffix is not 3 character"));
        }
        #
        # Check for 1 character language
        #
        elsif ( defined($language_map::one_char_iso_639_2T_map{$file_suffix}) ) {
            $suffix_language = $language_map::one_char_iso_639_2T_map{$file_suffix};
            print "1 character language suffix $file_suffix -> $suffix_language\n" if $debug;

            #
            # Should not use 1 character language
            #
            Record_Result($tcid, -1, 0, "",
                          String_Value("File name language suffix is not 3 character"));
        }
    }

    #
    # Look for a lang or language URL argument
    #
    $query =~ s/^\?//g;
    print "Query = $query\n" if $debug;
    foreach $arg (split(/[&;]/, $query) ) {
        $arg_number++;
        if ( ($arg =~ /^lang=/i) || ($arg =~ /^language=/i) ) {
            #
            # Got language argument, get it's value
            #
            $arg =~ s/^lang=//i;
            $arg =~ s/^language=//i;
            $arg =~ s/"//g;
            $arg =~ s/'//g;

            #
            # Check for a 3 character language
            #
            if ( defined($language_map::iso_639_2T_languages{$arg}) ) {
                $var_language = $arg;
                print "3 character lang value $arg\n" if $debug;
            }
            #
            # Check for greater than 3 character language
            #
            elsif ( length($arg) > 3 ) {
                print "lang length > 3\n" if $debug;

                #
                # Should not use more than 3 characters language
                #
                Record_Result($tcid, -1, 0, "",
                              String_Value("Language variable is not 3 character"));
            }
            #
            # Check for 2 character language
            #
            elsif ( defined($language_map::iso_639_1_iso_639_2T_map{$arg}) ) {
                $var_language = $language_map::iso_639_1_iso_639_2T_map{$arg};
                print "2 character lang value $arg -> $var_language\n" if $debug;

                #
                # Should not use 2 character language
                #
                Record_Result($tcid, -1, 0, "",
                              String_Value("Language variable is not 3 character"));
            }
            #
            # Check for 1 character language
            #
            elsif ( defined($language_map::one_char_iso_639_2T_map{$arg}) ) {
                $var_language = $language_map::one_char_iso_639_2T_map{$arg};
                print "1 character lang value $arg -> $var_language\n" if $debug;

                #
                # Should not use 1 character language
                #
                Record_Result($tcid, -1, 0, "",
                              String_Value("Language variable is not 3 character"));
            }
            
            #
            # Are we beyond the 3rd argument
            #
            if ( $arg_number > 3 ) {
                Record_Result($tcid, -1, 0, "",
                              String_Value("Language variable is not one of the first three"));
            }

            #
            # Have we seen a language variable already ?
            #
            if ( defined($last_var_language) ) {
                #
                # Does this language differ from the previous language ?
                #
                if ( $var_language ne $last_var_language ) {
                    Record_Result($tcid, -1, 0, "",
                                  String_Value("Multiple URL variable languages")
                                  . " ($last_var_language/$var_language)");
                } 
            }
            else {
                #
                # Save variable language in case we get another one.
                #
                $last_var_language = $var_language;
            }
        }
    }

    #
    # Check for inconsistencies in the 3 possible language 
    # codes (directory, file suffix, argument).
    #
    Check_URL_Language_Consistency($url, $dir_language, $suffix_language,
                                   $var_language);
}

#***********************************************************************
#
# Name: URL_Check
#
# Parameters: this_url - a URL
#             profile - testcase profile
#
# Description:
#
#   This function runs a number of QA checks the URL.
#
#***********************************************************************
sub URL_Check {
    my ( $this_url, $profile ) = @_;

    my (@tqa_results_list, $result_object, $testcase);

    #
    # Do we have a valid profile ?
    #
    print "URL_Check: Checking URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($url_check_profile_map{$profile}) ) {
        print "URL_Check: Unknown URL Check testcase profile passed $profile\n";
        return(@tqa_results_list);
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Save URL in global variable
    #
    if ( $this_url =~ /^http/i ) {
        $current_url = $this_url;
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of HTML
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Check the URL language
    #
    Check_URL_Language($this_url);

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "URL_Check results\n";
        foreach $result_object (@tqa_results_list) {
            print "Testcase: " . $result_object->testcase;
            print "  status   = " . $result_object->status . "\n";
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
    my (@package_list) = ("tqa_testcases", "language_map",
                          "tqa_result_object");

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

