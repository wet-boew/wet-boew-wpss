#***********************************************************************
#
# Name:   mobile_check_html.pm
#
# $Revision: 2035 $
# $URL: svn://10.36.148.185/WPSS_Tool/Mobile_Check/Tools/mobile_check_html.pm $
# $Date: 2021-05-12 10:09:02 -0400 (Wed, 12 May 2021) $
#
# Description:
#
#   This file contains routines that parse HTML files and check for
# a number of mobile optimization checkpoints.
#
# Public functions:
#     Set_Mobile_Check_HTML_Language
#     Set_Mobile_Check_HTML_Debug
#     Set_Mobile_Check_HTML_Testcase_Data
#     Set_Mobile_Check_HTML_Test_Profile
#     Mobile_Check_HTML
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

package mobile_check_html;

use strict;
use File::Basename;
use HTML::Parser;

#
# Use WPSS_Tool program modules
#
use crawler;
use css_validate;
use html_landmark;
use javascript_validate;
use mobile_check_css;
use mobile_check_image;
use mobile_testcases;
use tqa_result_object;
use tqa_tag_object;
use url_check;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Set_Mobile_Check_HTML_Language
                  Set_Mobile_Check_HTML_Debug
                  Set_Mobile_Check_HTML_Testcase_Data
                  Set_Mobile_Check_HTML_Test_Profile
                  Mobile_Check_HTML
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;

my (%testcase_data, %mobile_check_profile_map, $current_mobile_check_profile);
my ($results_list_addr, $current_url, $max_inline_css, $max_inline_js);
my ($inside_noscript, $iframe_count, $content_line_count, $inside_body);
my ($min_image_height, $min_image_width, $max_image_reduction_percent);
my (%image_dimensions_cache, $max_iframe_count);
my (@tag_order_stack);
my ($current_tag_object, $current_landmark, $landmark_marker);

#
# List of HTML tags that do not have an explicit end tag.
#
my (%html_tags_with_no_end_tag) = (
        "area", "area",
        "base", "base",
        "br", "br",
        "col", "col",
        "command", "command",
        "embed", "embed",
        "frame", "frame",
        "hr", "hr",
        "img", "img",
        "input", "input",
        "keygen", "keygen",
        "link", "link",
        "meta", "meta",
        "param", "param",
        "source", "source",
#        "track", "track",
        "wbr", "wbr",
);

#
# Status values
#
my ($check_pass)       = 0;
my ($check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "characters of inline CSS content", "characters of inline CSS content",
    "characters of inline JavaScript content", "characters of inline JavaScript content",
    "exceeds maximum acceptable value", "exceeds maximum acceptable value",
    "Found",                         "Found",
    "iframes in web page",           "<iframes> in web page",
    "Image height scaling",          "Image height scaling",
    "Image width scaling",           "Image width scaling",
    "Missing content in src attribute", "Missing content in 'src' attribute",
    );




my %string_table_fr = (
    "characters of inline CSS content", "caract�res de contenu en ligne de CSS",
    "characters of inline JavaScript content", "caract�res de contenu en ligne de JavaScript",
    "exceeds maximum acceptable value", "�passe la valeur maximale acceptable",
    "Found",                         "Trouv�",
    "iframes in web page",           "<iframes> dans la page web",
    "Image height scaling",          "Mise � l'�chelle de l'image hauteur",
    "Image width scaling",           "Image width scaling",
    "Missing content in src attribute", "Contenu manquant dans l'attribut 'src'",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_Mobile_Check_HTML_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Mobile_Check_HTML_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;

    #
    # Set debug flag for supporting modules
    #
    HTML_Landmark_Debug($debug);
}

#**********************************************************************
#
# Name: Set_Mobile_Check_HTML_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Mobile_Check_HTML_Language {
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
}

#***********************************************************************
#
# Name: Set_Mobile_Check_HTML_Testcase_Data
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
sub Set_Mobile_Check_HTML_Testcase_Data {
    my ($profile, $testcase, $data) = @_;

    my ($variable, $value);

    #
    # Get testcase specific data
    #
    if ( $testcase eq "EXTERNAL" ) {
        #
        # Get markup type and value
        #
        ($variable, $value) = split(/\s+/, $data);
        
        #
        # Save maximum character count for each markup language
        #
        if ( defined($value) && ($variable eq "MAX_CSS") ) {
            $max_inline_css = $value;
        }
        elsif ( defined($value) && ($variable eq "MAX_JS") ) {
            $max_inline_js = $value;
        }
    }
    elsif ( $testcase eq "IFRAMES" ) {
        #
        # Maximum number of iframes on a page
        #
        $max_iframe_count = $data;
    }
    elsif ( $testcase eq "NO_SCALE" ) {
        #
        # Get variable and value
        #
        ($variable, $value) = split(/\s+/, $data);

        #
        # Save minimum height and width values
        #
        if ( defined($value) && ($variable eq "MIN_HEIGHT") ) {
            $min_image_height = $value;
        }
        elsif ( defined($value) && ($variable eq "MIN_WIDTH") ) {
            $min_image_width = $value;
        }
        #
        # Get maximum allowed size reduction percentage
        elsif ( defined($value) && ($variable eq "MAX_REDUCTION") ) {
            $max_image_reduction_percent = $value;
        }
    }
    else {
        #
        # Copy the data into the table
        #
        $testcase_data{$testcase} = $data;
    }
}

#***********************************************************************
#
# Name: Set_Mobile_Check_HTML_Test_Profile
#
# Parameters: profile - profile name
#             mobile_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by testcase name.
#
#***********************************************************************
sub Set_Mobile_Check_HTML_Test_Profile {
    my ($profile, $mobile_checks ) = @_;

    my (%local_mobile_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Mobile_Check_HTML_Test_Profile, profile = $profile\n" if $debug;
    %local_mobile_checks = %$mobile_checks;
    $mobile_check_profile_map{$profile} = \%local_mobile_checks;
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
        $result_object->landmark($current_landmark);
        $result_object->landmark_marker($landmark_marker);
        push (@$results_list_addr, $result_object);

        #
        # Print error string to stdout
        #
        Print_Error($line, $column, $text, "$testcase : $error_string");
    }
}

#***********************************************************************
#
# Name: Initialize_Parser_Variables
#
# Parameters: content - content pointer
#
# Description:
#
#   This function initializes global variables used by the HTML parser.
#
#***********************************************************************
sub Initialize_Parser_Variables {
    my ($content) = @_;
    
    my (@lines);

    #
    # Initialize variables
    #
    $iframe_count = 0;
    $inside_body = 0;
    $inside_noscript = 0;
    @lines = split(/\n/, $$content);
    $content_line_count = @lines;
    @tag_order_stack = ();
    $current_landmark = "";
    $landmark_marker = "";
}

#***********************************************************************
#
# Name: Body_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the body tag.
#
#***********************************************************************
sub Body_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Set flag to indicate we are inside a <body> tag
    #
    $inside_body = 1;
}

#***********************************************************************
#
# Name: End_Body_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a handler for end body tag.
#
#***********************************************************************
sub End_Body_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    #
    # Set flag to indicate we are no longer inside a <body> tag
    #
    $inside_body = 0;
}

#***********************************************************************
#
# Name: Iframe_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the iframe tag.  It increments the iframe
# count if this iframe is not in a <noscript> tag.
#
#***********************************************************************
sub Iframe_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Are we are inside a <noscript> tag ?
    #
    if ( $inside_noscript ) {
        print "Ignore <iframe> inside <noscript>\n" if $debug;
    }
    else {
        #
        # Increment iframe count
        #
        $iframe_count++;
        print "Found <iframe>\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Check_Image_Scaling
#
# Parameters: src - img tag src attribute
#             attr_height - img tag height attribute
#             attr_width - img tag width attribute
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function checks to see if the image is being down scaled
# from its original size by height or width attributes.
#
#***********************************************************************
sub Check_Image_Scaling {
    my ($src, $attr_height, $attr_width, $line, $column, $text) = @_;
    
    my ($href, $resp_url, $resp, $image_height, $image_width, $percent);

    #
    # Get the image URL
    #
    print "Check_Image_Scaling attributes height = $attr_height, width = $attr_width\n" if $debug;
    $href = URL_Check_Make_URL_Absolute($src, $current_url);
    print "src url = $href\n" if $debug;
    
    #
    # Have we already seen this image before ?
    #
    if ( defined($image_dimensions_cache{$href}) ) {
        ($image_height, $image_width) = split(/:/, $image_dimensions_cache{$href});
    }
    else {
        #
        # Get the image URL
        #
        ($resp_url, $resp) = Crawler_Get_HTTP_Response($href, $current_url);

        #
        # Did we get the image ?
        #
        if ( defined($resp) && $resp->is_success ) {
            #
            # Get the image height and width
            #
            ($image_height, $image_width) = Mobile_Check_Image_Dimensions($href,
                                                                          $resp);

            #
            # Save dimensions in cache
            #
            $image_dimensions_cache{$href} = "$image_height:$image_width";
        }
        else {
            #
            # Image not found, save size as 0x0
            #
            $image_dimensions_cache{$href} = "0:0";
        }
    }
        
    #
    # See if the image height is reduced by the <img> height
    # attribute, and that the size is larger than the minimum size
    # to be checked.
    #
    print "Image height = $image_height, width = $image_width\n" if $debug;
    if ( defined($attr_height) &&
         ($image_height > 0) &&
         ($attr_height < $image_height) &&
         defined($min_image_height) &&
         ($image_height > $min_image_height) ) {
        #
        # Does the scaling reduce the image more than the accepted
        # percentage ?
        #
        $percent = int((($image_height - $attr_height) / $image_height) * 100);
        print "Percentage resuction = $percent\n" if $debug;
        if ( $percent > $max_image_reduction_percent ) {
            Record_Result("NO_SCALE", $line, $column, $text,
                          String_Value("Image height scaling") .
                          " $image_height --> $attr_height ($percent %) " .
                          String_Value("exceeds maximum acceptable value") .
                          " $max_image_reduction_percent %");
        }
    }

    #
    # See if the image width is reduced by the <img> width
    # attribute, and that the size is larger than the minimum size
    # to be checked.
    #
    if ( defined($attr_width) &&
         ($image_width > 0) &&
         ($attr_width < $image_width) &&
         defined($min_image_width) &&
         ($image_width > $min_image_width) ) {
        #
        # Does the scaling reduce the image more than the accepted
        # percentage ?
        #
        $percent = int((($image_width - $attr_width) / $image_width) * 100);
        print "Percentage resuction = $percent\n" if $debug;
        if ( $percent > $max_image_reduction_percent ) {
            Record_Result("NO_SCALE", $line, $column, $text,
                          String_Value("Image width scaling") .
                          " $image_width --> $attr_width ($percent %) " .
                          String_Value("exceeds maximum acceptable value") .
                          " $max_image_reduction_percent %");
        }
    }
}

#***********************************************************************
#
# Name: Image_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the image tag, it looks for alt text.
#
#***********************************************************************
sub Image_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($src, $height, $width);

    #
    # Check for src attribute
    #
    if ( defined($attr{"src"}) ) {
        $src = $attr{"src"};
        print "Image_Tag_Handler, src = $src\n" if $debug;
        
        #
        # Is the src empty ?
        #
        if ( $src =~ /^\s*$/ ) {
            Record_Result("EMPTY_SRC", $line, $column, $text,
                          String_Value("Missing content in src attribute"));
        }
        else {
            #
            # Do we have height attribute ?
            #
            if ( defined($attr{"height"}) ) {
                $height = $attr{"height"};
                print "height attribute = $height\n" if $debug;
            }
            
            #
            # Do we have a width attribute ?
            #
            if ( defined($attr{"width"}) ) {
                $width = $attr{"width"};
                print "height width = $width\n" if $debug;
            }

            #
            # If we have either height or width, check to see if we are
            # down scaling the image.
            #
            if ( defined($height) || defined($width) ) {
                Check_Image_Scaling($src, $height, $width, $line, $column, $text);
            }
        }
    }
}

#***********************************************************************
#
# Name: Noscript_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the noscript tag.
#
#***********************************************************************
sub Noscript_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;
    
    #
    # Set flag to indicate we are inside a <noscript> tag
    #
    $inside_noscript = 1;
}

#***********************************************************************
#
# Name: End_Noscript_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a handler for end noscript tag.
#
#***********************************************************************
sub End_Noscript_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    #
    # Clear flag to indicate we are no longer inside a <noscript> tag
    #
    $inside_noscript = 0;
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
    my ( $self, $tagname, $line, $column, $text, %attr_hash ) = @_;

    #
    # Create a new tag object
    #
    print "Start_Handler tag $tagname at $line:$column\n" if $debug;
    $current_tag_object = tqa_tag_object->new($tagname, $line, $column,
                                              \%attr_hash);
    push(@tag_order_stack, $current_tag_object);

    #
    # Compute the current landmark and add it to the tag object.
    #
    ($current_landmark, $landmark_marker) = HTML_Landmark($tagname, $line,
                       $column, $current_landmark, $landmark_marker,
                       \@tag_order_stack, %attr_hash);
    $current_tag_object->landmark($current_landmark);
    $current_tag_object->landmark_marker($landmark_marker);

    #
    # Check body tag
    #
    $tagname =~ s/\///g;
    if ( $tagname eq "body" ) {
        Body_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check iframe tag
    #
    elsif ( $tagname eq "iframe" ) {
        Iframe_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check img tag
    #
    elsif ( $tagname eq "img" ) {
        Image_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check noscript tag
    #
    elsif ( $tagname eq "noscript" ) {
        Noscript_Tag_Handler($self, $line, $column, $text, %attr_hash);
    }

    #
    # Is this a tag that has no end tag ? If so we must set the last tag
    # seen value here rather than in the End_Handler function.
    #
    if ( defined ($html_tags_with_no_end_tag{$tagname}) ) {
        $current_tag_object = pop(@tag_order_stack);
        $current_landmark = $current_tag_object->landmark();
        $landmark_marker = $current_tag_object->landmark_marker();
    }
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
    my ( $self, $tagname, $line, $column, $text, %attr_hash ) = @_;

    my ($popped_tag, $last_item);
    
    #
    # Check body tag
    #
    print "End_Handler tag $tagname at $line:$column\n" if $debug;
    if ( $tagname eq "body" ) {
        End_Body_Tag_Handler($self, $line, $column, $text);
    }
    
    #
    # Check noscript tag
    #
    elsif ( $tagname eq "noscript" ) {
        End_Noscript_Tag_Handler($self, $line, $column, $text);
    }

    #
    # Pop last tag of the stack
    #
    if ( @tag_order_stack > 0 ) {
        $current_tag_object = pop(@tag_order_stack);
        if ( @tag_order_stack > 0 ) {
            $last_item = @tag_order_stack - 1;
            $current_tag_object = $tag_order_stack[$last_item];
            $current_landmark = $current_tag_object->landmark();
            $landmark_marker = $current_tag_object->landmark_marker();
        }
        else {
            $current_landmark = "";
            $landmark_marker = "";
        }
    }
    else {
        $current_landmark = "";
        $landmark_marker = "";
    }
}

#***********************************************************************
#
# Name: Check_HTML
#
# Parameters: this_url - a URL
#             content - content pointer
#
# Description:
#
#   This function checks the HTML markup for mobile optimization.
#
#***********************************************************************
sub Check_HTML {
    my ($this_url, $content) = @_;
    
    my ($parser);

    #
    # Create a document parser
    #
    $parser = HTML::Parser->new;
    
    #
    # Initialize parser variables
    #
    Initialize_Parser_Variables($content);

    #
    # Add handlers for some of the HTML tags
    #
     $parser->handler(
        start => \&Start_Handler,
        "self,tagname,line,column,text,\@attr"
    );
    $parser->handler(
        end => \&End_Handler,
        "self,tagname,line,column,text,\@attr"
    );

    #
    # Parse the content.
    #
    $parser->parse($$content);
    
    #
    # Check the number of <iframe>s found
    #
    if ( defined($max_iframe_count) && ($iframe_count > $max_iframe_count) ) {
        Record_Result("IFRAMES", -1, -1, "",
                      String_Value("Found") . " $iframe_count " .
                      String_Value("iframes in web page") . ", " .
                      String_Value("exceeds maximum acceptable value") .
                          " $max_iframe_count");
    }
}

#***********************************************************************
#
# Name: Mobile_Check_HTML
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             mime_type - mime type of content
#             resp - HTTP::Response object
#             content - content pointer
#             generated_content - content pointer
#
# Description:
#
#   This function runs a number of mobile QA checks the content.
#
#***********************************************************************
sub Mobile_Check_HTML {
    my ($this_url, $language, $profile, $mime_type, $resp, $content,
        $generated_content) = @_;

    my (@tqa_results_list, $result_object, $css_content, $char_count);
    my ($js_content, @other_results);

    #
    # Check for mobile optimization
    #
    print "Mobile_Check_HTML\n" if $debug;

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);
    $current_url = $this_url;
    
    #
    # Extract inline CSS from HTML content
    #
    $css_content = CSS_Validate_Extract_CSS_From_HTML($this_url, $content);
    $char_count = length($css_content);
    
    #
    # Check to see if the CSS size exceeds the maximum
    #
    if ( defined($max_inline_css) && ($char_count > $max_inline_css) ) {
        Record_Result("EXTERNAL", -1, -1, "",
                      String_Value("Found") . " $char_count " .
                      String_Value("characters of inline CSS content"));
    }
    
    #
    # Perform some other CSS mobile checks
    #
    @other_results = Mobile_Check_CSS($this_url, $language, $profile,
                                      $mime_type, $resp, \$css_content);

    #
    # Merge results from the content type specific checks
    # into the list of all results.
    #
    foreach $result_object (@other_results) {
       push(@tqa_results_list, $result_object);
    }

    #
    # Extract inline JavaScript from HTML content
    #
    $js_content = JavaScript_Validate_Extract_JavaScript_From_HTML($this_url,
                                                                   $content);
    $char_count = length($js_content);

    #
    # Check to see if the JavaScript size exceeds the maximum
    #
    if ( defined($max_inline_js) && ($char_count > $max_inline_js) ) {
        Record_Result("EXTERNAL", -1, -1, "",
                      String_Value("Found") . " $char_count " .
                      String_Value("characters of inline JavaScript content"));
    }
    
    #
    # Check the HTML markup
    #
    Check_HTML($this_url, $generated_content);

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
# Return true to indicate we loaded successfully
#
return 1;

