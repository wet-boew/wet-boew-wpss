#***********************************************************************
#
# Name:   validate_markup.pm
#
# $Revision: 7417 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/HTML_Validate/Tools/validate_markup.pm $
# $Date: 2015-12-24 05:45:03 -0500 (Thu, 24 Dec 2015) $
#
# Description:
#
#   This file contains routines that validate content markup.
#
# Public functions:
#     Validate_Markup
#     Validate_Markup_Debug
#     Validate_Markup_Language
#     Validate_Markup_Last_Validation_Output
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

package validate_markup;

use strict;
use File::Basename;

#
# Use WPSS_Tool program modules
#
use css_validate;
use epub_validate;
use feed_validate;
use html_validate;
use javascript_validate;
use marc_validate;
use robots_check;
use tqa_result_object;
use xml_validate;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Validate_Markup
                  Validate_Markup_Debug
                  Validate_Markup_Language
                  Set_Validate_Markup_Test_Profile
                  Validate_Markup_Last_Validation_Output
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************
my (%markup_validate_profile_map, $last_url, $last_validation_output);
my ($debug) = 0;

#
# String table for error strings.
#
my %string_table_en = (
    "Fails validation",      "Fails validation",
);

my %string_table_fr = (
    "Fails validation",      "Échoue la validation",
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#
# Default language is English
#
my ($language) = "eng";

#********************************************************
#
# Name: Validate_Markup_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Validate_Markup_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;

    #
    # Set debug flag in supporting modules
    #
    CSS_Validate_Debug($debug);
    EPUB_Validate_Debug($debug);
    HTML_Validate_Debug($debug);
    JavaScript_Validate_Debug($debug);
    MARC_Validate_Debug($debug);
    Feed_Validate_Debug($debug);
    XML_Validate_Debug($debug);
}

#********************************************************
#
# Name: Validate_Markup_Language
#
# Parameters: this_language - language value
#
# Description:
#
#   This function sets the package language value.
#
#********************************************************
sub Validate_Markup_Language {
    my ($this_language) = @_;

    #
    # Set global language
    #
    if ( $this_language =~ /^fr/i ) {
        $language = "fra";
        $string_table = \%string_table_fr;
    }
    else {
        $language = "eng";
        $string_table = \%string_table_en;
    }

    #
    # Set language for supporting packages
    #
    CSS_Validate_Language($this_language);
    EPUB_Validate_Language($this_language);
    HTML_Validate_Language($this_language);
    MARC_Validate_Language($this_language);
    Robots_Check_Language($this_language);
    Feed_Validate_Language($this_language);
}

#***********************************************************************
#
# Name: Set_Validate_Markup_Test_Profile
#
# Parameters: profile - testcase profile
#             checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by testcase name.
#
#***********************************************************************
sub Set_Validate_Markup_Test_Profile {
    my ($profile, $checks ) = @_;

    my (%local_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Validate_Markup_Test_Profile, profile = $profile\n" if $debug;
    %local_checks = %$checks;
    $markup_validate_profile_map{$profile} = \%local_checks;
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
# Name: Validate_Markup
#
# Parameters: this_url - a URL
#             profile - testcase profile
#             mime_type - mime type of content
#             resp - HTTP::Response object
#             content - content pointer
#
# Description:
#
#   This function runs a content specific validator on the supplied content
# and returns the validation status result.
#
#***********************************************************************
sub Validate_Markup {
    my ($this_url, $profile, $mime_type, $resp, $content) = @_;

    my (@results_list, $result_object, $other_content, @other_results_list);
    my ($testcase_profile);

    #
    # Do we have a valid testcase profile ?
    #
    print "Validate_Markup: profile = $profile\n" if $debug;
    if ( ! defined($markup_validate_profile_map{$profile}) ) {
        print "Unknown testcase profile passed $profile\n" if $debug;
        return;
    }
    $testcase_profile = $markup_validate_profile_map{$profile};
    $last_url = $this_url;
    $last_validation_output = "";

    #
    # Do we have any content ?
    #
    if ( length($$content) > 0 ) {
        #
        # Select the validator that is appropriate for the content type
        #
        print "Validate_Markup URL $this_url, mime_type = $mime_type\n" if $debug;
        if ( $mime_type =~ /text\/css/ ) {
            #
            # Validate the CSS content.
            #
            if ( defined($$testcase_profile{"CSS_VALIDATION"}) ) {
                print "Validate CSS content\n" if $debug;
                @results_list = CSS_Validate_Content($this_url, $content);
                $last_validation_output = CSS_Validate_Last_Validation_Output();
            }
        }
        elsif ( ($mime_type =~ /application\/epub\+zip/) ||
                ($this_url =~ /\.epub$/i) ) {
            #
            # Validate the EPUB content.  We do this whether or not we want the
            # actual validation results.  A by product of the validation is
            # to save the EPUB content in a local file for easy access to
            # the component files.
            #
            print "Validate EPUB content\n" if $debug;
            @results_list = EPUB_Validate_Content($this_url, $resp, $content);
            $last_validation_output = EPUB_Validate_Last_Validation_Output();

            #
            # Do we discard the validation results ?
            #
            if ( ! defined($$testcase_profile{"EPUB_VALIDATION"}) ) {
                print "Ignore epub validation result\n" if $debug;
                @results_list = ();
                $last_validation_output = "";
            }
        }
        elsif ( $mime_type =~ /text\/html/ ) {
            #
            # Validate the HTML content.
            #
            if ( defined($$testcase_profile{"HTML_VALIDATION"}) ) {
                print "Validate HTML content\n" if $debug;
                @results_list = HTML_Validate_Content($this_url, $resp,
                                                      $content);
                $last_validation_output = HTML_Validate_Last_Validation_Output();
             }

            #
            # HTML documents may have inline CSS code, extract any CSS
            # code for validation.
            #
            if ( defined($$testcase_profile{"CSS_VALIDATION"}) ) {
                $other_content = CSS_Validate_Extract_CSS_From_HTML($this_url,
                                                                    $content);
                if (  length($other_content) > 0 ) {
                    #
                    # Validate CSS content
                    #
                    print "Validate inline CSS content\n" if $debug;
                    @other_results_list = CSS_Validate_Content($this_url,
                                                               \$other_content);

                    #
                    # Merge CSS validation results into HTML validation results
                    #
                    foreach $result_object (@other_results_list) {
                        push (@results_list, $result_object);
                    }
                }
            }
        }
        elsif ( ($mime_type =~ /application\/marc/) ||
                ($this_url =~ /\.mrc$/i) ) {
            #
            # Validate the MARC 21 content.
            #
            if ( defined($$testcase_profile{"MARC_VALIDATION"}) ) {
                print "Validate MARC content\n" if $debug;
                @results_list = MARC_Validate_Content($this_url, $content, "", "MARC_VALIDATION",
                                          "MARC_VALIDATION:" . String_Value("Fails validation"));
            }
        }
        elsif ( $this_url =~ /\/robots\.txt$/ ) {
            #
            # Validate the robots.txt content.
            #
            if ( defined($$testcase_profile{"ROBOTS_VALIDATION"}) ) {
                print "Validate robots.txt content\n" if $debug;
                @results_list = Robots_Check($this_url, $content);
            }
        }
        elsif ( ($mime_type =~ /application\/x-javascript/) ||
                ($mime_type =~ /text\/javascript/) ||
                ($this_url =~ /\.js$/i) ) {
            #
            # Validate the JavaScript content.
            #
            if ( defined($$testcase_profile{"JAVASCRIPT_VALIDATION"}) ) {
                print "Validate JavaScript content\n" if $debug;
                @results_list = JavaScript_Validate_Content($this_url, "error",
                                                            $content);
            }
        }
        #
        # Is this XML content
        #
        elsif ( ($mime_type =~ /application\/atom\+xml/) ||
                ($mime_type =~ /application\/ttml\+xml/) ||
                ($mime_type =~ /application\/xhtml\+xml/) ||
                ($mime_type =~ /application\/xml/) ||
                ($mime_type =~ /text\/xml/) ||
                ($this_url =~ /\.xml$/i) ) {
            #
            # Validate the XML content.
            #
            if ( defined($$testcase_profile{"XML_VALIDATION"}) ) {
                print "Validate XML content\n" if $debug;
                @results_list = XML_Validate_Content($this_url, $content);
            }
        }
    }
    else {
        #
        # No content
        #
        print "No content passed to Validate_Markup\n" if $debug;
    }

    #
    # Return result objects
    #
    return(@results_list);
}

#***********************************************************************
#
# Name: Validate_Markup_Last_Validation_Output
#
# Parameters: url - URL value
#
# Description:
#
#   This function returns the output of the last run of the validator.
#
#***********************************************************************
sub Validate_Markup_Last_Validation_Output {
    my ($url) = @_;
    
    #
    # Does the URL match the last URL that was validated?
    #
    if ( $url eq $last_url ) {
        #
        # Return validation output
        #
        return($last_validation_output);
    }
    else {
        #
        # Return empty string
        #
        return("");
    }
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

