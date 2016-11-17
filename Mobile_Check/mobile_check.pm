#***********************************************************************
#
# Name:   mobile_check.pm
#
# $Revision: 7562 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Mobile_Check/Tools/mobile_check.pm $
# $Date: 2016-04-13 04:14:45 -0400 (Wed, 13 Apr 2016) $
#
# Description:
#
#   This file contains routines that parse HTML files and check for
# a number of mobile optimization checkpoints.
#
# Public functions:
#     Set_Mobile_Check_Language
#     Set_Mobile_Check_Debug
#     Set_Mobile_Check_Testcase_Data
#     Set_Mobile_Check_Test_Profile
#     Mobile_Check_Read_URL_Help_File
#     Mobile_Check
#     Mobile_Check_Links
#     Mobile_Check_Testcase_URL
#     Mobile_Check_Compute_Page_Size
#     Mobile_Check_Save_Web_Page_Size
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

package mobile_check;

use strict;
use File::Basename;
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
    @EXPORT  = qw(Set_Mobile_Check_Language
                  Set_Mobile_Check_Debug
                  Set_Mobile_Check_Testcase_Data
                  Set_Mobile_Check_Test_Profile
                  Mobile_Check_Read_URL_Help_File
                  Mobile_Check
                  Mobile_Check_Links
                  Mobile_Check_Testcase_URL
                  Mobile_Check_Compute_Page_Size
                  Mobile_Check_Save_Web_Page_Size
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

my (%testcase_data, %mobile_check_profile_map, $current_mobile_check_profile);
my ($results_list_addr, $current_url, $max_allowed_css, $max_allowed_js);
my ($max_hostname_count, $favicon_size, %favicon_urls, $max_allowed_image);
my (@redirect_ignore_text_patterns, @redirect_ignore_url_patterns);
my (%style_count, %supporting_file_size);

#
# Status values
#
my ($check_pass)       = 0;
my ($check_fail)       = 1;

#
# List of tags which contribute to the "OTHER" catagory of a web page
# size (i.e. not CSS, Javascript, Images, etc).
#
my (%other_type_link_tags) = (
    "frame", 1,
    "iframe", 1,
    "object", 1,
    );

#
# String table for error strings.
#
my %string_table_en = (
    "Broken link",                   "Broken link",
    "Broken link to favicon",        "Broken link to favicon",
    "Content is not compressed",     "Content is not compressed.",
    "Cookies set for supporting file", "Cookies set for supporting file",
    "CSS link found outside of <head>", "CSS link found outside of <head>",
    "Duplicate JS link found",       "Duplicate JavaScript link found",
    "exceeds maximum acceptable value", "exceeds maximum acceptable value",
    "Favicon image size",            "Favicon image size",
    "Favicon URL",                   "Favicon URL",
    "for",                           "for",
    "Found",                         "Found",
    "greater than expected maximum of", "greater than expected maximum of",
    "Hostname count for supporting files", "Hostname count for supporting files",
    "JS link found in <head>",       "JavaScript link found in <head>",
    "JS link not near end of <body>",   "JavaScript link not near end of <body>",
    "link count",                    "link count",
    "No content in supporting file", "No content in supporting file",
    "No Etag or Last-Modified header field", "No Etag or Last-Modified header field",
    "No Expires or Cache-Control header field", "No Expires or Cache-Control header field.",
    "No styles in stylesheet file",  "No styles in stylesheet file",
    "Previous instance found at",    "Previous instance found at (line:column) ",
    "Redirected link",               "Redirected link",
    );

my %string_table_fr = (
    "Broken link",                   "Lien brisé",
    "Broken link to favicon",        "Lien brisé au favicon",
    "Content is not compressed",     "Contenu ne est pas compressé.",
    "Cookies set for supporting file", "Cookies set for supporting file",
    "CSS link found outside of <head>", "lien CSS qui se trouve à l'extérieur de la balise <head>",
    "Duplicate JS link found",       "Dupliquer lien JavaScript trouvé",
    "exceeds maximum acceptable value", "dépasse la valeur maximale acceptable",
    "Favicon image size",            "Taille de l'image favicon",
    "Favicon URL",                   "Favicon URL",
    "for",                           "pour",
    "Found",                         "Trouvé",
    "greater than expected maximum of", "plus que le maximum prévu de",
    "Hostname count for supporting files", "Nombre de nom d'hôte pour supporter les fichiers",
    "JS link found in <head>",       "lien JavaScript qui se trouve dans la balise <head>",
    "JS link not near end of <body>",   "lien javascript pas vers la fin de la balise <body>",
    "link count",                    "nombre de liens",
    "No content in supporting file", "Aucun contenu dans le fichier de support",
    "No Etag or Last-Modified header field", "Aucune Etag ou un champ d'en-tête de Last-Modified",
    "No Expires or Cache-Control header field", "Aucune Expire ou un champ d'en-tête de Cache-Control.",
    "No styles in stylesheet file",  "Pas de styles dans un fichier de style",
    "Previous instance found at",    "Instance précédente trouvée à (la ligne:colonne) ",
    "Redirected link",               "Lien Réorienter",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_Mobile_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Mobile_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
    
    #
    # Set debug flag for supporting modules
    #
    Set_Mobile_Testcase_Debug($debug);
    Set_Mobile_Check_CSS_Debug($debug);
    Set_Mobile_Check_HTML_Debug($debug);
    Set_Mobile_Check_Image_Debug($debug);
    Set_Mobile_Check_JS_Debug($debug);
}

#**********************************************************************
#
# Name: Set_Mobile_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Mobile_Check_Language {
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
    
    #
    # Set language in supporting modules
    #
    Mobile_Testcase_Language($language);
    Set_Mobile_Check_CSS_Language($language);
    Set_Mobile_Check_HTML_Language($language);
    Set_Mobile_Check_Image_Language($language);
    Set_Mobile_Check_JS_Language($language);
}

#**********************************************************************
#
# Name: Mobile_Check_Read_URL_Help_File
#
# Parameters: filename - path to help file
#
# Description:
#
#   This function reads a testcase help file.  The file contains
# a list of testcases and the URL of a help page or standard that
# relates to the testcase.  A language field allows for English & French
# URLs for the testcase.
#
#**********************************************************************
sub Mobile_Check_Read_URL_Help_File {
    my ($filename) = @_;
    
    #
    # Read URL help file
    #
    Mobile_Testcase_Read_URL_Help_File($filename);
}

#**********************************************************************
#
# Name: Mobile_Check_Testcase_URL
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase URL
# table for the specified key.
#
#**********************************************************************
sub Mobile_Check_Testcase_URL {
    my ($key) = @_;

    my ($help_url);

    #
    # Return URL value
    #
    $help_url = Mobile_Testcase_URL($key);
    return($help_url);
}

#***********************************************************************
#
# Name: Set_Mobile_Check_Testcase_Data
#
# Parameters: profile - testcase profile
#             testcase - testcase identifier
#             data - string of data
#
# Description:
#
#   This function copies the passed data into a hash table
# for the specified testcase identifier.
#
#***********************************************************************
sub Set_Mobile_Check_Testcase_Data {
    my ($profile, $testcase, $data) = @_;

    my ($variable, $value);
    
    #
    # Check the testcase id
    #
    if ( $testcase eq "DNS_LOOKUPS" ) {
        #
        # Set maximum number of hostnames for supporting files
        #
        $max_hostname_count = $data;
    }
    elsif ( $testcase eq "FAVICON" ) {
        #
        # Set maximum favicon image size
        #
        $favicon_size = $data;
    }
    elsif ( $testcase eq "NUM_HTTP" ) {
        #
        # Get the variable and value portions from the data
        #
        ($variable, $value) = split(/\s+/, $data);
        
        #
        # Do we have the maximum number of CSS, JS or image files ?
        #
        if ( defined($value) && ($variable eq "MAX_CSS") ) {
            $max_allowed_css = $value;
        }
        elsif ( defined($value) && ($variable eq "MAX_JS") ) {
            $max_allowed_js = $value;
        }
        elsif ( defined($value) && ($variable eq "MAX_IMAGE") ) {
            $max_allowed_image = $value;
        }
    }
    elsif ( $testcase eq "REDIRECTS" ) {
        #
        # Get the variable and value portions from the data
        #
        ($variable, $value) = split(/\s+/, $data);

        #
        # Do we have values for URL text or URL href ?
        #
        if ( defined($value) && ($variable eq "TEXT") ) {
            push(@redirect_ignore_text_patterns, $value);
        }
        elsif ( defined($value) && ($variable eq "URL") ) {
            push(@redirect_ignore_url_patterns, $value);
        }
    }
    else {
        #
        # Copy the data into the table
        #
        $testcase_data{$testcase} = $data;
    }

    #
    # Set testcase data in supporting modules
    #
    Set_Mobile_Check_CSS_Testcase_Data($profile, $testcase, $data);
    Set_Mobile_Check_HTML_Testcase_Data($profile, $testcase, $data);
    Set_Mobile_Check_Image_Testcase_Data($profile, $testcase, $data);
    Set_Mobile_Check_JS_Testcase_Data($profile, $testcase, $data);
}

#***********************************************************************
#
# Name: Set_Mobile_Check_Test_Profile
#
# Parameters: profile - profile name
#             mobile_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by TQA testcase name.
#
#***********************************************************************
sub Set_Mobile_Check_Test_Profile {
    my ($profile, $mobile_checks) = @_;

    my (%local_mobile_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Mobile_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_mobile_checks = %$mobile_checks;
    $mobile_check_profile_map{$profile} = \%local_mobile_checks;
    
    #
    # Set testcase profile in supporting modules
    #
    Set_Mobile_Check_CSS_Test_Profile($profile, $mobile_checks);
    Set_Mobile_Check_HTML_Test_Profile($profile, $mobile_checks);
    Set_Mobile_Check_Image_Test_Profile($profile, $mobile_checks);
    Set_Mobile_Check_JS_Test_Profile($profile, $mobile_checks);
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - Mobile check test profile
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
    $current_mobile_check_profile = $mobile_check_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;

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
    if ( defined($testcase) && defined($$current_mobile_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $check_fail,
                                                Mobile_Testcase_Description($testcase),
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
# Name: Check_Compressed_Content
#
# Parameters: this_url - a URL
#             mime_type - mime type of content
#             resp - HTTP::Response object
#
# Description:
#
#   This function checks to see if the content of the HTTP::Response
# is compressed or not.  Certain content types (text based ones) should
# be compressed.
#
#***********************************************************************
sub Check_Compressed_Content {
    my ($this_url, $mime_type, $resp) = @_;

    my (@tqa_results_list, $result_object);

    #
    # Check for mobile optimization
    #
    print "Check_Compressed_Content mime-type = $mime_type\n" if $debug;

    #
    # Check mime-type to see if this content should be compressed
    #
    if ( ($mime_type =~ /text\//) ||
         ($mime_type =~ /application\/x\-javascript/) ||
         ($mime_type =~ /application\/atom\+xml/) ||
         ($mime_type =~ /application\/rss\+xml/) ||
         ($mime_type =~ /application\/ttml\+xml/) ||
         ($mime_type =~ /application\/xhtml\+xml/) ||
         ($mime_type =~ /application\/xml/) ) {

        #
        # Does the HTTP::Response have a content encoding with the
        # value gzip ?
        #
        print "Check for Content-Encoding header\n" if $debug;
        if ( defined($resp) &&
             defined($resp->header('Content-Encoding') &&
             ($resp->header('Content-Encoding') =~ /gzip/i)) ) {
            print "Content is compressed with gzip\n" if $debug;
        }
        else {
            #
            # Content is not compressed
            #
            Record_Result("GZIP", -1, -1, "",
                          String_Value("Content is not compressed"));
        }
    }
}

#***********************************************************************
#
# Name: Check_Expires_Cache_Control_Header
#
# Parameters: this_url - a URL
#             tcid - testcase identifier
#             message - message to add to error
#             resp - HTTP::Response object
#
# Description:
#
#   This function checks to see if the HTTP::Response contains
# an expires header or some other cache control attribute.
#
#***********************************************************************
sub Check_Expires_Cache_Control_Header {
    my ($this_url, $tcid, $message, $resp) = @_;
    
    my ($header, $field);
    
    #
    # Get at the header object
    #
    print "Check_Expires_Cache_Control_Header\n" if $debug;
    $header = $resp->headers;
    
    #
    # Check for an Expires header
    #
    print "Check for Expires header\n" if $debug;
    $field = $header->header("Expires");
    if ( defined($field) ) {
        print "Have Expires header \"$field\"\n" if $debug;
    }

    #
    # Check for a ExpiresDefault header
    #
    if ( ! defined($field) ) {
        print "Check for ExpiresDefault header\n" if $debug;
        $field = $header->header("ExpiresDefault");
        if ( defined($field) ) {
            print "Have Expires ExpiresDefault \"$field\"\n" if $debug;
        }
    }
    
    #
    # Check for a Cache-Control header
    #
    if ( ! defined($field) ) {
        print "Check for Cache-Control header\n" if $debug;
        $field = $header->header("Cache-Control");
        if ( defined($field) ) {
            print "Have Expires Cache-Control \"$field\"\n" if $debug;
        }
    }

    #
    # Did we find any cache control or expires header ?
    #
    if ( ! defined($field) ) {
        print "No Expires or Cache-Control header found\n" if $debug;
        Record_Result($tcid, -1, -1, "",
                      String_Value("No Expires or Cache-Control header field") .
                      $message);
    }
}

#***********************************************************************
#
# Name: Check_Etag_Last_Modified_Header
#
# Parameters: this_url - a URL
#             resp - HTTP::Response object
#
# Description:
#
#   This function checks to see if the HTTP::Response contains
# an Etag or Last-Modified header attribute.
#
#***********************************************************************
sub Check_Etag_Last_Modified_Header {
    my ($this_url, $resp) = @_;

    my ($header, $field);

    #
    # Get at the header object
    #
    print "Check_Etag_Last_Modified_Header\n" if $debug;
    $header = $resp->headers;

    #
    # Check for an Etag header
    #
    print "Check for Etag header\n" if $debug;
    $field = $header->header("Etag");
    if ( defined($field) ) {
        print "Have Etag header \"$field\"\n" if $debug;
    }

    #
    # Check for a Last-Modified header
    #
    if ( ! defined($field) ) {
        print "Check for Last-Modified header\n" if $debug;
        $field = $header->header("Last-Modified");
        if ( defined($field) ) {
            print "Have Expires Last-Modified \"$field\"\n" if $debug;
        }
    }

    #
    # Did we find any etag or last-modified header ?
    #
    if ( ! defined($field) ) {
        print "No Etag or Last-Modified header found\n" if $debug;
        Record_Result("ETAGS", -1, -1, "",
                      String_Value("No Etag or Last-Modified header field"));
    }
}

#***********************************************************************
#
# Name: Check_Cookies
#
# Parameters: this_url - a URL
#             resp - HTTP::Response object
#
# Description:
#
#   This function checks to see if the HTTP::Response contains
# any cookie settings.
#
#***********************************************************************
sub Check_Cookies {
    my ($this_url, $resp) = @_;

    my ($header, $field);

    #
    # Get at the header object
    #
    print "Check_Cookies\n" if $debug;
    $header = $resp->headers;

    #
    # Check for an Set-Cookie header
    #
    print "Check for Set-Cookie header\n" if $debug;
    $field = $header->header("Set-Cookie");
    if ( defined($field) ) {
        print "Have Set-Cookie header \"$field\"\n" if $debug;
        Record_Result("COOKIE_FREE", -1, -1, "",
                      String_Value("Cookies set for supporting file"));
    }
}

#***********************************************************************
#
# Name: Mobile_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             mime_type - mime type of content
#             resp - HTTP::Response object
#             content - content pointer
#
# Description:
#
#   This function runs a number of mobile QA checks the content.
#
#***********************************************************************
sub Mobile_Check {
    my ($this_url, $language, $profile, $mime_type, $resp, $content) = @_;

    my (@tqa_results_list, $result_object, @other_tqa_results_list, $tcid);

    #
    # Check for mobile optimization
    #
    print "Mobile_Check URL $this_url, mime-type = $mime_type, lanugage = $language, profile = $profile\n" if $debug;

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);
    $current_url = $this_url;

    #
    # Are any of the testcases defined in this testcase profile ?
    #
    if ( keys(%$current_mobile_check_profile) == 0 ) {
        #
        # No tests handled by this module
        #
        print "No tests handled by this module\n" if $debug;
        return(@tqa_results_list);
    }
    
    #
    # Perform content type specific checks.
    #
    if ( $mime_type =~ /text\/html/ ) {
        @other_tqa_results_list = Mobile_Check_HTML($this_url, $language,
                                                    $profile, $mime_type,
                                                    $resp, $content);
    }
    elsif ( $mime_type =~ /text\/css/ ) {
        #
        # Check for expires or cache control in the header
        #
        Check_Expires_Cache_Control_Header($this_url, "EXPIRES", "", $resp);
        
        #
        # Check for Etag or Last-Modified field in the header
        #
        Check_Etag_Last_Modified_Header($this_url, $resp);
        
        #
        # Check for cookies in the header
        #
        Check_Cookies($this_url, $resp);

        #
        # CSS specific mobile checks.
        #
        @other_tqa_results_list = Mobile_Check_CSS($this_url, $language,
                                                   $profile, $mime_type,
                                                   $resp, $content);
    }
    elsif ( ($mime_type =~ /application\/x\-javascript/) ||
            ($mime_type =~ /text\/javascript/) ||
            ($this_url =~ /\.js$/i) ) {
        #
        # Check for expires or cache control in the header
        #
        Check_Expires_Cache_Control_Header($this_url, "EXPIRES", "", $resp);

        #
        # Check for Etag or Last-Modified field in the header
        #
        Check_Etag_Last_Modified_Header($this_url, $resp);

        #
        # Check for cookies in the header
        #
        Check_Cookies($this_url, $resp);

        #
        # JavaScript specific mobile checks
        #
        @other_tqa_results_list = Mobile_Check_JS($this_url, $language,
                                                  $profile, $mime_type,
                                                  $resp, $content);
    }
    elsif ( $mime_type =~ /image\//i ) {
        #
        # Check for expires or cache control in the header
        #
        Check_Expires_Cache_Control_Header($this_url, "EXPIRES", "", $resp);

        #
        # Check for Etag or Last-Modified field in the header
        #
        Check_Etag_Last_Modified_Header($this_url, $resp);

        #
        # Check for cookies in the header
        #
        Check_Cookies($this_url, $resp);

        #
        # Image specific mobile checks
        #
        @other_tqa_results_list = Mobile_Check_Image($this_url, $language,
                                                     $profile, $mime_type,
                                                     $resp, $content);
    }
    elsif ( $mime_type =~ /video\//i ) {
        #
        # Check for expires or cache control in the header
        #
        Check_Expires_Cache_Control_Header($this_url, "EXPIRES", "", $resp);

        #
        # Check for Etag or Last-Modified field in the header
        #
        Check_Etag_Last_Modified_Header($this_url, $resp);
    }

    #
    # Merge results from the content type specific checks
    # into the list of all results.
    #
    foreach $result_object (@other_tqa_results_list) {
       push(@tqa_results_list, $result_object);
    }

    #
    # Check for compressed content where appropriate
    #
    Check_Compressed_Content($this_url, $mime_type, $resp);
    
    #
    # Add help URL to result
    #
    foreach $result_object (@tqa_results_list) {
        $tcid = $result_object->testcase();
        if ( defined(Mobile_Check_Testcase_URL($tcid)) ) {
            $result_object->help_url(Mobile_Check_Testcase_URL($tcid));
        }
    }

    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Check_Favicon_Link
#
# Parameters: url - URL of page
#             link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function checks for a favicon link in the <head>.
#
#***********************************************************************
sub Check_Favicon_Link {
    my ($url, $link_sets) = @_;

    my ($section, $list_addr, $link, $resp, %attr, $favicon_url);
    my ($protocol, $domain, $file_path, $query, $new_url, $size);

    #
    # Check links in head section for a favicon/shortcut icon
    #
    print "Check_Favicon_Link\n" if $debug;
    if ( defined($$link_sets{"HEAD"}) ) {
        $list_addr= $$link_sets{"HEAD"};
        print "Check links in section HEAD\n" if $debug;
        foreach $link (@$list_addr) {
            #
            # Exclude <noscript> links and links from
            # conditional includes.
            #
            print "Check link " . $link->abs_url . "\n" if $debug;
            if ( $link->noscript || $link->modified_content ) {
                print "Skip noscript or modified content link\n" if $debug;
            }
            #
            # Look for <link> type only.
            #
            elsif ( $link->link_type eq "link" ){
                #
                # Get the <link> tag attributes
                #
                %attr = $link->attr();

                #
                # Is there a rel attribute with the value shortcut icon ?
                #
                print "Found link, rel = \"" . $attr{"rel"} . "\"\n" if $debug;
                if ( defined($attr{"rel"}) &&
                     (($attr{"rel"} =~ /^shortcut icon$/i) ||
                      ($attr{"rel"} =~ /^icon$/i))  ) {
                    print "Found favicon\n" if $debug;
                    $favicon_url = $link->abs_url;
                    last;
                }
            }
        }
    }
    
    #
    # Did we find a favicon URL ?
    #
    if ( ! defined($favicon_url) ) {
        #
        # No favicon specified, use domain/favicon.ico as the default
        #
        ($protocol, $domain, $file_path, $query, $new_url) = URL_Check_Parse_URL($url);
        $favicon_url = $protocol . $domain . "/favicon.ico";
    }
        
    #
    # Get the favicon URL if we have not already seen it
    #
    print "Check favicon $favicon_url\n" if $debug;
    if ( ! defined($favicon_urls{$favicon_url}) ) {
        ($new_url, $resp) = Crawler_Get_HTTP_Response($favicon_url, $url);
        $favicon_urls{$favicon_url} = $favicon_url;
        
        #
        # Is this a broken link ?
        #
        print "Check favicon $favicon_url\n" if $debug;
        if ( defined($resp) && ($resp->code == 404) ) {
            Record_Result("FAVICON", -1, -1, "",
                          String_Value("Broken link to favicon") .
                          " \"$favicon_url\"");
        }
        elsif ( defined($resp) ) {
            #
            # Is the favicon cacheable ?
            #
            Check_Expires_Cache_Control_Header($favicon_url, "FAVICON",
                                               " " . String_Value("Favicon URL") .
                                               " $favicon_url",
                                               $resp);
        
            #
            # Check size of favicon
            #
            $size = length($resp->content);
            if ( defined($favicon_size) && ($size > $favicon_size) ) {
                    Record_Result("FAVICON", -1, -1, "",
                                  String_Value("Favicon image size") .
                                  " $size " .
                                  String_Value("for") . " $favicon_url " .
                                  String_Value("exceeds maximum acceptable value") .
                                  " $favicon_size");
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Broken_Redirect_Links
#
# Parameters: link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function checks for broken or redirected links.
#
#***********************************************************************
sub Check_Broken_Redirect_Links {
    my ($link_sets) = @_;

    my ($section, $list_addr, $link, $resp, $pattern, $match_pattern);
    my (%styles, $content, $mime_type, $header, $resp_url, %attr);

    #
    # Check links in all sections of the page
    #
    print "Check_Broken_Redirect_Links\n" if $debug;
    while ( ($section, $list_addr) = each %$link_sets ) {
        print "Check links in section $section\n" if $debug;
        foreach $link (@$list_addr) {
            #
            # Exclude <noscript> links and links from
            # conditional includes.
            #
            print "Check link " . $link->abs_url . "\n" if $debug;
            if ( $link->noscript || $link->modified_content ) {
                print "Skip noscript or modified content link\n" if $debug;
            }
            else {
                #
                # Get the status of the link
                #
                ($link, $resp) = Link_Checker_Get_Link_Status($current_url, $link);

                #
                # Is this a broken link ?
                #
                if ( defined($resp) && ($resp->code == 404) ) {
                    Record_Result("NO_404", $link->line_no,
                                  $link->column_no, $link->source_line,
                                  String_Value("Broken link") .
                                  " \"" . $link->abs_url . "\"");
                }
                #
                # Is this a redirected link ?
                #
                elsif ( $link->is_redirected ) {
                    #
                    # Is this a redirect we ignore (e.g. language switching)
                    #
                    $match_pattern = 0;
                    foreach $pattern (@redirect_ignore_text_patterns) {
                        if ( $link->anchor =~ /$pattern/i ) {
                            $match_pattern = 1;
                            print "Link text matches pattern $pattern\n" if $debug;
                            last;
                        }
                    }
                    if ( ! $match_pattern ) {
                        foreach $pattern (@redirect_ignore_url_patterns) {
                            if ( $link->abs_url =~ /$pattern/i ) {
                                $match_pattern = 1;
                                print "Link URL matches pattern $pattern\n" if $debug;
                                last;
                            }
                        }
                    }
                    
                    #
                    # Do we record this redirect ?
                    #
                    if ( ! $match_pattern ) {
                        Record_Result("REDIRECTS", $link->line_no,
                                      $link->column_no, $link->source_line,
                                      String_Value("Redirected link") .
                                      " \"" . $link->abs_url . "\" -> \"" .
                                      $link->redirect_url . "\"");
                    }
                }
                
                #
                # If this is a supporting file (CSS, JS, image, ...) ?
                #
                if ( ($link->link_type eq "image") ||
                     ($link->link_type eq "link")  ||
                     ($link->link_type eq "script") ) {
                     
                    #
                    # Do we have a size for this file ?
                    #
                    if ( ! defined($supporting_file_size{$link->abs_url}) ) {
                        ($resp_url, $resp) = Crawler_Get_HTTP_Response($link->abs_url, "");
                        
                        #
                        # Get content size (eliminate leading whitespace
                        # in case the file only contains whitespace)
                        #
                        if ( defined($resp) && ($resp->is_success) ) {
                            $content = Crawler_Decode_Content($resp);
                            $content =~ s/^\s*//g;
                        }
                        else {
                            $content = "";
                        }
                        $supporting_file_size{$link->abs_url} = length($content);
                        print "Supporting file " . $link->abs_url .
                                  " length = " . length($content) . "\n" if $debug;
                    }

                    #
                    # Is there any content in the supporting file
                    #
                    if ( $supporting_file_size{$link->abs_url} == 0 ) {
                        Record_Result("NUM_HTTP", $link->line_no,
                                      $link->column_no, $link->source_line,
                                      String_Value("No content in supporting file") .
                                      " \"" . $link->abs_url . "\"");
                    }
                    
                    #
                    # Check stylesheets to see they contain styles
                    #
                    if ( ($link->link_type eq "link") &&
                         ($supporting_file_size{$link->abs_url} > 0) ) {
                         
                        #
                        # Is this a link to a stylesheet ?
                        #
                        %attr = $link->attr;
                        if ( defined($attr{"rel"}) &&
                             ($attr{"rel"} eq "stylesheet") ) {
                            #
                            # Do we already have a style count ?
                            #
                            if ( ! defined($style_count{$link->abs_url}) ) {
                                $header = $resp->headers;
                                $mime_type = $header->content_type;
                                %styles = CSS_Check_Get_Styles_From_Content($link->abs_url,
                                                                            $content,
                                                                            $mime_type);

                                $style_count{$link->abs_url} = scalar(keys %styles);
                                print "Have " . $style_count{$link->abs_url} .
                                      " styles in CSS file " . $link->abs_url . "\n" if $debug;
                            }

                            #
                            # Is the style count 0 ?
                            #
                            if ( $style_count{$link->abs_url} == 0 ) {
                                Record_Result("NUM_HTTP", $link->line_no,
                                              $link->column_no, $link->source_line,
                                              String_Value("No styles in stylesheet file") .
                                              " \"" . $link->abs_url . "\"");
                            }
                        }
                    }
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_CSS_Links
#
# Parameters: link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function checks CSS links on the page.  It checks the number of
# CSS links.
#
#***********************************************************************
sub Check_CSS_Links {
    my ($link_sets) = @_;

    my ($section, $list_addr, $link, $css_count, %attr, %css_urls);

    #
    # Check links in all sections of the page
    #
    print "Check_CSS_Links\n" if $debug;
    $css_count = 0;
    while ( ($section, $list_addr) = each %$link_sets ) {
        print "Check links in section $section\n" if $debug;
        foreach $link (@$list_addr) {
            #
            # Exclude <noscript> links, links from
            # conditional includes or generated content.
            #
            print "Check link " . $link->abs_url . "\n" if $debug;
            if ( $link->noscript ||
                 $link->modified_content ||
                 $link->generated_content ) {
                print "Skip noscript, modified content or generated content link\n" if $debug;
            }
            #
            # Is this link from a <link> tag ?
            #
            elsif ( $link->link_type eq "link" ){
                #
                # Get the <link> tag attributes
                #
                %attr = $link->attr();

                #
                # Is there a rel attribute with the value stylesheet ?
                #
                if ( defined($attr{"rel"}) &&
                     ($attr{"rel"} =~ /^stylesheet$/i) ) {
                    print "Found stylesheet\n" if $debug;
                    $css_count++;
                    $css_urls{$link->abs_url} = 1;
                }
                
                #
                # Are we outside the HEAD section ? We should not find CSS
                # files outside the <head>.
                #
                if ( $section ne "HEAD" ) {
                    Record_Result("CSS_TOP", $link->line_no,
                                  $link->column_no, $link->source_line,
                                  String_Value("CSS link found outside of <head>"));
                }
            }
        }
    }
    
    #
    # Did we find too many CSS links ?
    #
    if ( defined($max_allowed_css) && ($css_count > $max_allowed_css) ) {
        Record_Result("NUM_HTTP", -1, -1, "",
                      "CSS " . String_Value("link count") .
                      " $css_count " . String_Value("greater than expected maximum of") .
                      " $max_allowed_css");
    }
}

#***********************************************************************
#
# Name: Check_JS_Links
#
# Parameters: link_sets - table of lists of link objects (1 list per
#               document section)
#             content - content pointer
#
# Description:
#
#    This function checks JS links on the page.  It checks the number of
# JS links.
#
#***********************************************************************
sub Check_JS_Links {
    my ($link_sets, $content) = @_;

    my ($section, $list_addr, $link, $js_count, %attr, %urls, $src);
    my ($line_no, $content_line_count, @lines);

    #
    # Get a count of the number of lines of content.  We need the count
    # to see if <script> tags appear near the beginning or end of the
    # web page.
    #
    @lines = split(/\n/, $$content);
    $content_line_count = @lines;

    #
    # Check links in all sections of the page
    #
    print "Check_JS_Links\n" if $debug;
    $js_count = 0;
    while ( ($section, $list_addr) = each %$link_sets ) {
        print "Check links in section $section\n" if $debug;
        foreach $link (@$list_addr) {
            #
            # Exclude <noscript> links and links from
            # conditional includes or generated content.
            #
            print "Check link " . $link->abs_url . "\n" if $debug;
            if ( $link->noscript ||
                 $link->modified_content ||
                 $link->generated_content ) {
                print "Skip noscript, modified content or generated content link\n" if $debug;
            }
            #
            # Is this link from a <script> tag ?
            #
            elsif ( $link->link_type eq "script" ){
                #
                # Get the <script> tag attributes
                #
                %attr = $link->attr();

                #
                # Is there a src attribute ?
                #
                if ( defined($attr{"src"}) ) {
                    print "Found script\n" if $debug;
                    $js_count++;
                    $src = $link->abs_url;
                    
                    #
                    # Have we seen this URL before ?
                    #
                    if ( defined($urls{$src}) ) {
                        Record_Result("JS_DUPES", $link->line_no, $link->column_no,
                                      $link->source_line,
                                      String_Value("Duplicate JS link found") .
                                      " $src " .
                                      String_Value("Previous instance found at") .
                                      " " . $urls{$src});
                    }
                    else {
                        #
                        # Save location of this URL
                        #
                        $urls{$src} = $link->line_no . ":" . $link->column_no;
                    }
                }

                #
                # Does this <script> tag have a defer attribute ?
                # (instructing the browser to load the script when the page
                # finishes loading).
                #
                if ( defined($attr{"defer"}) ) {
                    print "Skip script tag with defer attribute\n" if $debug;
                }
                #
                # Is the <script> tag inside the HEAD section ?
                #
                elsif ( $section eq "HEAD" ) {
                    Record_Result("JS_BOTTOM", $link->line_no,
                                  $link->column_no, $link->source_line,
                                  String_Value("JS link found in <head>"));
                }
                #
                # Is the <script> tag near the bottom of the web page ?
                #
                else {
                    $line_no = $link->line_no;

                    #
                    # Do we have at least 100 lines of content ?
                    #
                    if ( $content_line_count > 100 ) {
                        #
                        # Is the <script> tag within the last 10% of the
                        # content ?
                        #
                        print "Link line number $line_no, content line count = $content_line_count\n" if $debug;
                        if ( $line_no < (int($content_line_count * 0.90)) ) {
                            Record_Result("JS_BOTTOM", $link->line_no,
                                          $link->column_no, $link->source_line,
                                          String_Value("JS link not near end of <body>"));
                        }
                        else {
                            print "Skip script tag in bottom 10% of content\n" if $debug;
                        }
                    }
                }
            }
        }
    }

    #
    # Did we find too many JS links ?
    #
    if ( defined($max_allowed_js) && ($js_count > $max_allowed_js) ) {
        Record_Result("NUM_HTTP", -1, -1, "",
                      "JS " . String_Value("link count") .
                      " $js_count " . String_Value("greater than expected maximum of") .
                      " $max_allowed_js");
    }
}

#***********************************************************************
#
# Name: Check_Image_Links
#
# Parameters: link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function checks image links on the page.  It checks the number of
# image links.
#
#***********************************************************************
sub Check_Image_Links {
    my ($link_sets) = @_;

    my ($section, $list_addr, $link, $image_count, %attr, %img_urls);

    #
    # Check links in all sections of the page
    #
    print "Check_Image_Links\n" if $debug;
    $image_count = 0;
    while ( ($section, $list_addr) = each %$link_sets ) {
        print "Check links in section $section\n" if $debug;
        foreach $link (@$list_addr) {
            #
            # Exclude <noscript> links, links from conditional
            # includes and generated content links.
            #
            print "Check link " . $link->abs_url . "\n" if $debug;
            if ( $link->noscript ||
                 $link->modified_content ||
                 $link->generated_content ) {
                print "Skip noscript, modified content or generated content link\n" if $debug;
            }
            #
            # Is this link from a <img> tag ?
            #
            elsif ( $link->link_type eq "img" ){
                print "Found image\n" if $debug;
                if ( ! defined($img_urls{$link->abs_url}) ) {
                    $image_count++;
                    $img_urls{$link->abs_url} = 1;
                }
            }
            #
            # Is this link from a <video> tag ?
            #
            elsif ( $link->link_type eq "video" ){
                #
                # Get the <video> tag attributes
                #
                %attr = $link->attr();

                #
                # Is there a poster attribute ?
                #
                if ( defined($attr{"poster"}) ) {
                    print "Found video poster\n" if $debug;
                    if ( ! defined($img_urls{$link->abs_url}) ) {
                        $image_count++;
                        $img_urls{$link->abs_url} = 1;
                    }
                }
            }
        }
    }

    #
    # Did we find too many image links ?
    #
    if ( defined($max_allowed_image) && ($image_count > $max_allowed_image) ) {
        Record_Result("NUM_HTTP", -1, -1, "",
                      "Image " . String_Value("link count") .
                      " $image_count " . String_Value("greater than expected maximum of") .
                      " $max_allowed_image");
    }
}

#***********************************************************************
#
# Name: Check_Hostnames
#
# Parameters: url - URL
#             link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function checks the hostname for all supporting files
# (e.g. CSS, JavaScript, images, etc) to see how many different
# hostnames are used.
#
#***********************************************************************
sub Check_Hostnames {
    my ($url, $link_sets) = @_;
    
    my ($link, $section, $list_addr, %attr, $link_to_check);
    my ($protocol, $domain, $file_path, $query, $new_url);
    my (%hostname_map, $hostname_count);
    
    #
    # Get the hostname for the source URL
    #
    ($protocol, $domain, $file_path, $query, $new_url) = URL_Check_Parse_URL($url);
    
    #
    # Strip any port number from the domain portion
    #
    if ( defined($domain) ) {
        $domain =~ s/:.*//g;
        $hostname_map{$domain} = $domain;
    }
    
    #
    # Check links in all sections of the page
    #
    print "Check_Hostnames\n" if $debug;
    while ( ($section, $list_addr) = each %$link_sets ) {
        print "Check links in section $section\n" if $debug;
        foreach $link (@$list_addr) {
            #
            # Get the link attributes
            #
            %attr = $link->attr();

            #
            # Exclude <noscript> links and links from
            # conditional includes.
            #
            print "Check link " . $link->abs_url . "\n" if $debug;
            $link_to_check = "";
            if ( $link->noscript || $link->modified_content ) {
                print "Skip noscript or modified content link\n" if $debug;
            }
            #
            # Is this an img link ?
            #
            elsif ( $link->link_type eq "img" ) {
                print "Found image\n" if $debug;
                $link_to_check = $link->abs_url;
            }
            #
            # Is this a CSS link ?
            #
            elsif ( ($link->link_type eq "link") &&
                    defined($attr{"rel"}) &&
                    ($attr{"rel"} =~ /^stylesheet$/i) ){
                print "Found stylesheet\n" if $debug;
                $link_to_check = $link->abs_url;
            }
            #
            # Is this an object link ?
            #
            elsif ( $link->link_type eq "object" ) {
                print "Found object\n" if $debug;
                $link_to_check = $link->abs_url;
            }
            #
            # Is this link from a <script> tag ?
            #
            elsif ( $link->link_type eq "script" ) {
                print "Found script\n" if $debug;
                $link_to_check = $link->abs_url;
            }
            
            #
            # Did we find a link to check ?
            #
            if ( $link_to_check ne "" ) {
                #
                # Get the hostname component of the URL
                #
                ($protocol, $domain, $file_path, $query, $new_url) =
                        URL_Check_Parse_URL($link_to_check);

                #
                # Strip any port number from the domain portion
                #
                if ( defined($domain) ) {
                    $domain =~ s/:.*//g;
                    $hostname_map{$domain} = $domain;
                }
            }
        }
    }
    
    #
    # Get count of unique hostnames
    #
    $hostname_count = keys %hostname_map;
    print "Have $hostname_count unique hostnames\n" if $debug;
    if ( defined($max_hostname_count) &&
         ($hostname_count > $max_hostname_count) ) {
        Record_Result("DNS_LOOKUPS", -1, -1, "",
                      String_Value("Hostname count for supporting files") .
                      ", $hostname_count, " .
                      String_Value("greater than expected maximum of") .
                      " $max_hostname_count");
    }
}

#***********************************************************************
#
# Name: Mobile_Check_Links
#
# Parameters: tqa_results_list - address of hash table results
#             url - URL
#             profile - testcase profile
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#             content - content pointer
#
# Description:
#
#    This function performs a number of checks on links found within a
# document.
#
#***********************************************************************
sub Mobile_Check_Links {
    my ($tqa_results_list, $url, $profile, $language, $link_sets,
        $content) = @_;

    my ($result_object, $section, $list_addr, $link, $tcid);
    
    #
    # Perform Mobile link checks.
    #
    print "Mobile_Check_Links: profile = $profile\n" if $debug;

    #
    # Initialize the test case pass/fail table.
    #
    $current_mobile_check_profile = $mobile_check_profile_map{$profile};
    $results_list_addr = $tqa_results_list;
    $current_url = $url;

    #
    # Are any of the testcases defined in this testcase profile ?
    #
    if ( keys(%$current_mobile_check_profile) == 0 ) {
        #
        # No tests handled by this module
        #
        print "No tests handled by this module\n" if $debug;
        return();
    }
    
    #
    # Check for favicon link
    #
    Check_Favicon_Link($url, $link_sets);
    
    #
    # Check for broken or redirected links
    #
    Check_Broken_Redirect_Links($link_sets);
    
    #
    # Check the number of CSS files in the page
    #
    Check_CSS_Links($link_sets);
    
    #
    # Check the number of JS files in the page
    #
    Check_JS_Links($link_sets, $content);
    
    #
    # Check the number of image files in the page
    #
    Check_Image_Links($link_sets);

    #
    # Check the hostnames for components (CSS, JavaScript, Images, etc)
    #
    Check_Hostnames($url, $link_sets);

    #
    # Add help URL to result
    #
    foreach $result_object (@$tqa_results_list) {
        $tcid = $result_object->testcase();
        if ( defined(Mobile_Check_Testcase_URL($tcid)) ) {
            $result_object->help_url(Mobile_Check_Testcase_URL($tcid));
        }
    }
}

#***********************************************************************
#
# Name: Mobile_Check_Compute_Page_Size
#
# Parameters: url - URL
#             resp - HTTP Response object
#             link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function computes a number of size values of a web page.
# The sizes include the overall page size as well as the size of
# a number of components (e.g. images, CSS, etc).
#
#***********************************************************************
sub Mobile_Check_Compute_Page_Size {
    my ($url, $resp, $link_sets) = @_;

    my ($size, $html_size, $link, $section, $links_addr, $link_type);
    my ($size_string);
    my ($css_size) = 0;
    my ($js_size) = 0;
    my ($img_size) = 0;
    my ($other_size) = 0;
    my ($css_count) = 0;
    my ($js_count) = 0;
    my ($img_count) = 0;
    my ($other_count) = 0;

    #
    # Get total document size
    #
    print "Mobile_Check_Compute_Page_Size\n" if $debug;
    $html_size = length($resp->content);

    #
    # Check the links in each document section
    #
    foreach $section (keys(%$link_sets)) {
        print "Check lists in section $section\n" if $debug;
        $links_addr = $$link_sets{$section};
        foreach $link (@$links_addr) {
            #
            # Ignore links in modified code (IE conditional code),
            # in <noscript> tags and generated content.
            #
            $link_type = $link->link_type;
            if ( (! $link->modified_content) &&
                 (! $link->noscript) &&
                 (! $link->generated_content) ) {
                #
                # Check for <img> tag
                #
                if ( $link->link_type eq "img" ) {
                    $img_size += $link->content_length;
                    $img_count++;
                    print "Add IMG " . $link->abs_url . " content length " .
                          $link->content_length . " total = $img_size\n" if $debug;
                }
                #
                # Check for other type tags e.g. frame/iframe, object
                #
                elsif ( defined($other_type_link_tags{$link_type}) ) {
                    $other_size += $link->content_length;
                    $other_count++;
                    print "Add $link_type " .
                          $link->abs_url . " content length " .
                          $link->content_length . " total = $other_size\n" if $debug;
                }
                #
                # Check for <link> to CSS
                #
                elsif ( ($link_type eq "link") && ($link->mime_type eq "text/css") ) {
                    $css_size += $link->content_length;
                    $css_count++;
                    print "Add CSS " . $link->abs_url . " content length " .
                          $link->content_length . " total = $css_size\n" if $debug;
                }
                #
                # Check for <script> and JavaScript
                #
                elsif ( ($link_type eq "script") &&
                        (($link->mime_type =~ /application\/x\-javascript/) ||
                         ($link->mime_type =~ /text\/javascript/) ||
                         ($link->abs_url =~ /\.js$/i) ) )  {
                    $js_size += $link->content_length;
                    $js_count++;
                    print "Add JavaScript " . $link->abs_url . " content length " .
                          $link->content_length . " total = $js_size\n" if $debug;
                }
            }
        }
    }

    #
    # Compute overall size
    #
    $size = $html_size + $css_size + $js_size + $img_size + $other_size;
    print "Total page size = $size\n" if $debug;
    $size_string = "$size,$html_size,$css_count,$css_size,$js_count,$js_size,$img_count,$img_size,$other_count,$other_size";
    print "Total page size = $size HTML = $html_size, CSS = $css_size, JS = $js_size, IMG = $img_size, OTHER = $other_size\n" if $debug;
    print "Link type count CSS = $css_count, JS = $js_count, IMG = $img_count, OTHER = $other_count\n" if $debug;
    
    #
    # Return sizes as a string
    #
    return($size_string);
}

#***********************************************************************
#
# Name: Mobile_Check_Save_Web_Page_Size
#
# Parameters: file_handle - a file handle
#             file_name - name of file
#             url - a URL
#             size_string - string os sizes
#
# Description:
#
#   This function saves web page size details as a CSV file.  If
# the file_handle variable is undefind, a temporary file is created.
#
#***********************************************************************
sub Mobile_Check_Save_Web_Page_Size {
    my ($file_handle, $file_name, $url, $size_string) = @_;

    #
    # Do we have a file handle ? or do we create a temporary file ?
    #
    print "Mobile_Check_Save_Web_Page_Size_Details\n" if $debug;
    if ( ! defined($file_handle) ) {
        print "Create temporary CSV file\n" if $debug;
        ($file_handle, $file_name) = tempfile("WPSS_TOOL_XXXXXXXXXX",
                                              SUFFIX => '.csv',
                                              TMPDIR => 1);
        if ( ! defined($file_handle) ) {
            print "Error: Failed to create temporary file in Mobile_Check_Save_Web_Page_Size\n";
            return;
        }
        print "CSV file name = $file_name\n" if $debug;
        binmode $file_handle;

        #
        # Print header row for CSV file
        #
        print $file_handle "url,size,html_size,css_count,css_size,js_count,js_size,img_count,img_size,other_count,other_size\r\n";
    }

    #
    # print size string to file
    #
    print $file_handle "$url,$size_string\r\n";

    #
    # Return file handle and file name
    #
    return($file_handle, $file_name);
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
    my (@package_list) = ("tqa_result_object", "mobile_testcases",
                          "link_checker", "mobile_check_css",
                          "mobile_check_html", "mobile_check_js",
                          "mobile_check_image", "url_check",
                          "crawler", "css_check");

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

