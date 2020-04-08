#***********************************************************************
#
# Name:   css_check.pm
#
# $Revision: 6821 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/TQA_Check/Tools/css_check.pm $
# $Date: 2014-10-31 10:37:14 -0400 (Fri, 31 Oct 2014) $
#
# Description:
#
#   This file contains routines that parse CSS files and check for
# a number of technical quality assurance check points.
#
# Public functions:
#     Set_CSS_Check_Language
#     Set_CSS_Check_Debug
#     Set_CSS_Check_Testcase_Data
#     Set_CSS_Check_Test_Profile
#     Set_CSS_Check_Valid_Markup
#     CSS_Check
#     CSS_Check_Get_All_Styles
#     CSS_Check_Get_Styles_From_Content
#     CSS_Check_Does_Style_Have_Emphasis
#     CSS_Check_Style_Has_Property_Value
#     CSS_Check_Style_Get_Property_Value
#     CSS_Check_Check_Styled_Text
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

package css_check;

use strict;
use URI::URL;
use File::Basename;
use CSS;

#
# Use WPSS_Tool program modules
#
use css_extract_links;
use image_details;
use tqa_result_object;
use tqa_testcases;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Set_CSS_Check_Language
                  Set_CSS_Check_Debug
                  Set_CSS_Check_Testcase_Data
                  Set_CSS_Check_Test_Profile
                  Set_CSS_Check_Valid_Markup
                  CSS_Check
                  CSS_Check_Get_All_Styles
                  CSS_Check_Get_Styles_From_Content
                  CSS_Check_Does_Style_Have_Emphasis
                  CSS_Check_Style_Has_Property_Value
                  CSS_Check_Style_Get_Property_Value
                  CSS_Check_Check_Styled_Text
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (%testcase_data, $foreground_color, $background_color);

my (%css_check_profile_map, $current_css_check_profile, $current_url);
my ($results_list_addr, %url_css_styles_cache, %url_css_styles_hits);
my ($url_css_styles_count) = 0;

my ($relative_font_sizes) = " xx-small x-small small medium large x-large xx-large xsmaller larger ";

my ($is_valid_markup) = -1;

#
# Color keyword to RGB value map
#
my (%color_keyword_rgb_map) = (
     "aqua", "00ffff",
     "black", "000000",
     "blue", "0000ff",
     "fuchsia", "ff00ff",
     "gray", "808080",
     "green", "008000",
     "lime", "00ff00",
     "maroon", "800000",
     "navy", "000080",
     "olive", "808000",
     "orange", "ffA500",
     "purple", "800080",
     "red", "ff0000",
     "silver", "c0c0c0",
     "teal", "008080",
     "white", "ffffff",
     "yellow", "ffff00"
);

#
# String table for error strings.
#
my %string_table_en = (
    "Fails validation",              "Fails validation, see validation results for details.",
    "Required testcase not executed","Required testcase not executed",
    "No scalable font",             "No scalable font for (class : font-size) ",
    "blink text decoration in class", "'blink' text decoration in class ",
    "GIF animation exceeds 5 seconds",  "GIF animation exceeds 5 seconds",
    "GIF flashes more than 3 times in 1 second", "GIF flashes more than 3 times in 1 second",
    "The luminosity contrast",      "The luminosity contrast ratio",
    "for styles",                   "for styles",
    "The color contrast",           "The color contrast difference",
    "The color brightness",         "The color brightness difference",
    "is too low for",               "is too low for colours",
    "non-decorative content in class", "non-decorative content in class ",
    "not specified in em units",    "not specified in 'em' units for (class : value) ",
    "Loaded in style",              "Loaded in style",
    "from CSS in",                  "from CSS in",
    );

my %string_table_fr = (
    "Fails validation",             "Échoue la validation, voir les résultats de validation pour plus de détails.",
    "Required testcase not executed","Cas de test requis pas exécuté",
    "No scalable font",             "pas de polices vectorielles pour (classe : font-size) ",
    "blink text decoration in class", "'blink' décoration de texte dans classe ",
    "GIF animation exceeds 5 seconds",  "Clignotement de l'image GIF supérieur à 5 secondes",
    "GIF flashes more than 3 times in 1 second", "Clignotement de l'image GIF supérieur à 3 par seconde",
    "The luminosity contrast",      "Le contraste de luminosité
",
    "for styles",                   "pour les styles",
    "The color contrast",           "La différence entre les couleurs",
    "The color brightness",         "La différence de luminosité",
    "is too low for",               "ne suffit pas pour les couleurs choisies",
    "non-decorative content in class", "contenu non décoratif de la classe ",
    "not specified in em units",    "n'est pas exprimé en unités 'em' pour (classe : valeur) ",
    "Loaded in style",              "Chargé dans le style",
    "from CSS in",                  "de css dans",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Set_CSS_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_CSS_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;

    #
    # Set debug flag of supporting module
    #
    Image_Details_Debug($debug);
    CSS_Extract_Links_Debug($debug);
}

#**********************************************************************
#
# Name: Set_CSS_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_CSS_Check_Language {
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
# Name: Set_CSS_Check_Testcase_Data
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
sub Set_CSS_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;
}

#***********************************************************************
#
# Name: Set_CSS_Check_Test_Profile
#
# Parameters: profile - CSS check test profile
#             css_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by CSS testcase name.
#
#***********************************************************************
sub Set_CSS_Check_Test_Profile {
    my ($profile, $css_checks ) = @_;

    my (%local_css_checks);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_CSS_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_css_checks = %$css_checks;
    $css_check_profile_map{$profile} = \%local_css_checks;
}

#***********************************************************************
#
# Name: Set_CSS_Check_Valid_Markup
#
# Parameters: valid_markup - flag
#
# Description:
#
#   This function copies the passed flag into the global
# variable is_valid_markup.  The possible values are
#    1 - valid markup
#    0 - not valid markup
#   -1 - unknown validity.
# This value is used when assessing WCAG 2.0 technique G134
#
#***********************************************************************
sub Set_CSS_Check_Valid_Markup {
    my ($valid_markup) = @_;

    #
    # Copy the data into global variable
    #
    if ( defined($valid_markup) ) {
        $is_valid_markup = $valid_markup;
    }
    else {
        $is_valid_markup = -1;
    } 
    print "Set_CSS_Check_Valid_Markup, validity = $is_valid_markup\n" if $debug;
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - CSS check test profile
#             local_results_list_addr - address of results list.
#
# Description:
#
#   This function initializes the test case results table.
#
#***********************************************************************
sub Initialize_Test_Results {
    my ($profile, $local_results_list_addr) = @_;

    my ($test_case, $tcid);

    #
    # Set current hash tables
    #
    $current_css_check_profile = $css_check_profile_map{$profile};
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

    my ($result_object, $impact);

    #
    # Is this testcase included in the profile
    #
    if ( defined($testcase) && defined($$current_css_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, 1,
                                                TQA_Testcase_Description($testcase),
                                                $line, $column, $text,
                                                $error_string, $current_url);
        $result_object->testcase_groups(TQA_Testcase_Groups($testcase));
        push (@$results_list_addr, $result_object);

        #
        # Add impact if it is not blank.
        #
        $impact = TQA_Testcase_Impact($testcase);
        if ( $impact ne "" ) {
            $result_object->impact($impact);
        }

        #
        # Print error string to stdout
        #
        Print_Error($line, $column, $text, "$testcase : $error_string");
    }
}

#***********************************************************************
#
# Name: Convert_Pergentage_Color_To_Absolute
#
# Parameters: color -  percentage color value
#
# Description:
#
#   This function converts a oercentage color value (e.g. 50%) into
# an integer one in the range of 0 to 255 (0$ to 100%).
#
#***********************************************************************
sub Convert_Pergentage_Color_To_Absolute {
    my($color) = @_;

    #
    # Remove trailing % character
    #
    $color =~ s/%//g;

    #
    # Convert number from 0..100 into 0..255 range
    #
    $color = int($color * 2.55);
    return($color);
}

#***********************************************************************
#
# Name: Convert_Integer_Color_To_Hex
#
# Parameters: color - integer color value
#
# Description:
#
#   This function converts an integer color value (in the range 0 to
# 255) into a corresponding Hex value.  If the color is out of the 0 to
# 255 range, it is clipped (less than 0 becoms 0, greater than 255 becomes
# 255).  It returns a 2 digit hex value.
#
#***********************************************************************
sub Convert_Integer_Color_To_Hex {
    my ($color) = @_;

    #
    # Check range of number befre conversion, it should be 0..255
    #
    if ( $color < 0 ) {
        $color = 0;
    }
    elsif ( $color > 255 ) {
        $color = 255;
    }

    #
    # Convert to hex
    #
    $color = sprintf("%02x", $color);
    return($color);
}

#***********************************************************************
#
# Name: Get_Color
#
# Parameters: value - property value
#
# Description:
#
#   This function parses any color specification from the property value.
# It converts any color value into a uniform format for color contrast
# analysis.
#
#***********************************************************************
sub Get_Color {
    my ($value) = @_;
    
    my (@fields, $field, $color, $c1, $c2, $c3);
    
    #
    # Split value on whitespace
    #
    print "Get_Color: value = $value\n" if $debug;
    @fields = split(/\s+/, $value);
    
    #
    # Look for named color or hex color value
    #
    foreach $field (@fields) {
        #
        # Check for a named color value (e.g. white).
        #
        if ( defined($color_keyword_rgb_map{$field}) ) {
            $color = $color_keyword_rgb_map{$field};
            print "Named color $field converted to $color\n" if $debug;
        }
        #
        # Check for leading # and either 4 or 7 characters
        #
        elsif ( $field =~ /^#/) {
            $field =~ s/^#//;
            
            #
            # Do we have a 3 digit color
            #
            if ( length($field) == 3 ) {
                #
                # Convert 3 digit to 6 digits by doubling each digit
                #
                ($c1, $c2, $c3) = $field =~ /(.)(.)(.)$/;
                $color = lc("$c1$c1$c2$c2$c3$c3");
                print "3 digit color $field converted to $color\n" if $debug;
            }
            #
            # Do we have 6 digits ?
            #
            elsif ( length($field) == 6 ) {
                $color = lc($field);
                print "6 digit color $field converted to $color\n" if $debug;
            }
        }
        #
        # Check for rgb function call
        #
        elsif ( $field =~ /rgb\(/ ) {
            #
            # We have to look at the entire property value, not
            # just this field.  This field may only contain the
            # first color if spaces are in the rbg function call.
            #
            ($c1, $c2, $c3) = $value =~ /^.*rgb\s*\(\s*([-]?\d+[%]?)\s*,\s*([-]?\d+[%]?)\s*,\s*([-]?\d+[%]?)\s*\)/i;
            
            #
            # Did we get color values ?
            #
            if ( defined($c1) &&
                 defined($c2) &&
                 defined($c3) ) {
                print "RGB color spcification  r = $c1, g = $c2, b = $c3\n" if $debug;

                #
                # Are we dealing with percentage or absolute values ?
                #
                if ( $c1 =~ /%$/ ) {
                    $c1 = Convert_Pergentage_Color_To_Absolute($c1);
                }
                if ( $c2 =~ /%$/ ) {
                    $c2 = Convert_Pergentage_Color_To_Absolute($c2);
                }
                if ( $c3 =~ /%$/ ) {
                    $c3 = Convert_Pergentage_Color_To_Absolute($c3);
                }

                #
                # Make Convert integer numbers into Hex codes
                #
                $c1 = Convert_Integer_Color_To_Hex($c1);
                $c2 = Convert_Integer_Color_To_Hex($c2);
                $c3 = Convert_Integer_Color_To_Hex($c3);
                $color = "$c1$c1$c2$c2$c3$c3";
                print "RGB color converted to $color\n" if $debug;
            }
        }
    }

    #
    # Return color value
    #
    return($color);
}

#***********************************************************************
#
# Name: Relative_Luminance
#
# Parameters: color - color value
#
# Description:
#
#   This function computes the relative luminance value for the specified
# color.  The algorithm is described in the Check_Color_Contrast
# function.
#
#***********************************************************************
sub Relative_Luminance {
    my ($color) = @_;

    my ($r, $g, $b, $Rs, $Gs, $Bs, $R, $G, $B, $L);

    #
    # Get the R, G, B hex color values from the color
    #
    ($r, $g, $b) = $color =~ /^(..)(..)(..)$/;

    #
    # Convert Hex color values into decimal
    #
    $r = hex($r);
    $g = hex($g);
    $b = hex($b);

    #
    # Calculate Rs, Gs, Bs values as <color>/255
    #
    $Rs = $r / 255;
    $Gs = $g / 255;
    $Bs = $b / 255;

    #
    # Get R, G, B values as 
    # RsRGB <= 0.03928 then R = RsRGB/12.92 else R = ((RsRGB+0.055)/1.055) ^ 2.4
    #
    if ( $Rs <= 0.03928 ) {
        $R = $Rs / 12.92;
    }
    else {
        $R = (($Rs + 0.055) / 1.055) ** 2.4;
    }
    if ( $Gs <= 0.03928 ) {
        $G = $Gs / 12.92;
    }
    else {
        $G = (($Gs + 0.055) / 1.055) ** 2.4;
    }
    if ( $Bs <= 0.03928 ) {
        $B = $Bs / 12.92;
    }
    else {
        $B = (($Bs + 0.055) / 1.055) ** 2.4;
    }

    #
    # Calculate relative luminance
    #
    $L = 0.2126 * $R + 0.7152 * $G + 0.0722 * $B;
    print "Relative_Luminance of $color is $L\n" if $debug;
    return($L);
}

#***********************************************************************
#
# Name: Luminosity_Color_Contrast_Ratio_Check
#
# Parameters: color1 - a color value
#             color2 - a color value
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function performs a luminosity color contrast ratio check on
# the specified colour values.  The algorithm is defined in WCAG 2.0
# as follows
#
#
#   Measure the relative luminance of each letter (unless they are all
# uniform) using the formula:
#
# L = 0.2126 * R + 0.7152 * G + 0.0722 * B where R, G and B are defined as:
#     if RsRGB <= 0.03928 then R = RsRGB/12.92 
#                         else R = ((RsRGB+0.055)/1.055) ^ 2.4
#     if GsRGB <= 0.03928 then G = GsRGB/12.92 
#                         else G = ((GsRGB+0.055)/1.055) ^ 2.4
#     if BsRGB <= 0.03928 then B = BsRGB/12.92 
#                         else B = ((BsRGB+0.055)/1.055) ^ 2.4
# and RsRGB, GsRGB, and BsRGB are defined as:
#     RsRGB = R8bit/255
#     GsRGB = G8bit/255
#     BsRGB = B8bit/255
# The "^" character is the exponentiation operator. 
#
# Calculate the contrast ratio using the following formula.
#
# (L1 + 0.05) / (L2 + 0.05), where
#     L1 is the relative luminance of the lighter of the foreground 
#        or background colors, and
#     L2 is the relative luminance of the darker of the foreground 
#        or background colors.
#
# See http://juicystudio.com/services/luminositycontrastratio.php for
# an online implementation of this algorithm.
#
#***********************************************************************
sub Luminosity_Color_Contrast_Ratio_Check {
    my ($color1, $color2, $line, $column, $text) = @_;

    my ($L1, $L2, $contrast);

    #
    # Get relative luminance values of the 2 colors
    #
    print "Luminosity_Color_Contrast_Ratio_Check: foreground $color1, background $color2\n" if $debug;
    $L1 = Relative_Luminance($color1);
    $L2 = Relative_Luminance($color2);

    #
    # Calculate ratio (L1 + 0.05) / (L2 + 0.05)
    #
    $contrast = ($L1 + 0.05) / ($L2 + 0.05);
    if ( $contrast < 1.0 ) {
        $contrast = ($L2 + 0.05) / ($L1 + 0.05);
    }
    print "Color contrast is $contrast\n" if $debug;

    #
    # Is the contrast sufficient for the more stringent check ?
    #
    if ( $contrast < 3.0 ) {
        $contrast = sprintf("%4.2f", $contrast);
        Record_Result("WCAG_2.0-G145", $line, $column, $text,
                      String_Value("The luminosity contrast") .
                      " ($contrast) " .
                      String_Value("is too low for") .
                      " (#$color1, #$color2)");
    }
    #
    # Is the contrast sufficient for the less stringent check ?
    #
    elsif ( $contrast < 4.5 ) {
        $contrast = sprintf("%4.2f", $contrast);
        Record_Result("WCAG_2.0-G18", $line, $column, $text,
                      String_Value("The luminosity contrast") .
                      " ($contrast) " .
                      String_Value("is too low for") .
                      " (#$color1, #$color2)");
    }
}

#***********************************************************************
#
# Name: Check_Color_Contrast
#
# Parameters: color1 - a color value
#             color2 - a color value
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function performs a color contrast analysis on the specified
# colour values.  The algorthim used depends on the testcases
# in the testcase profile.
#
#***********************************************************************
sub Check_Color_Contrast {
    my ($color1, $color2, $line, $column, $text) = @_;

    #
    # Check if WCAG 2.0 algorithm is to be used.
    #
    if ( defined($$current_css_check_profile{"WCAG_2.0-G18"})  ||
         defined($$current_css_check_profile{"WCAG_2.0-G145"}) ) {
        Luminosity_Color_Contrast_Ratio_Check($color1, $color2,
                                              $line, $column, $text);
    }
}

#***********************************************************************
#
# Name: Text_Decoration_Property
#
# Parameters: name - selector (class) name
#             value - text decoration property value
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function checks the value of a text-decoration property
#
#***********************************************************************
sub Text_Decoration_Property {
    my ($name, $value, $line, $column, $text) = @_;

    #
    # Does the value include blink ?
    #
    print "Class $name, text-decoration value $value\n" if $debug;
    if ( $value =~ /blink/i ) {
        Record_Result("WCAG_2.0-F4", $line, $column, $text,
                      String_Value("blink text decoration in class") . 
                      $name);
    }
}

#***********************************************************************
#
# Name: Content_Property
#
# Parameters: name - selector (class) name
#             value - content property value
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function checks the content property. It checks to see if
# it is a string, and if the style name include either a :before or
# :after qualifier.
#
#***********************************************************************
sub Content_Property {
    my ($name, $value, $line, $column, $text) = @_;

    #
    # Check for :before or :after qualifier in the style name.
    #
    print "Check content property of $name, value = $value\n" if $debug;
    if ( ($name =~ /:before/i) || ($name =~ /:after/i) ) {
        print "Found :before or :after style qualifier\n" if $debug;

        #
        # Is the content a string ? (i.e. look for quotes)
        #
        if ( (length($value) > 2) && 
             (($value =~ /^'/) || ($value =~ /^"/)) ) {

            #
            # Remove any character encodings
            #
            $value =~ s/\\[0-9a-z]*//gi;

            #
            # Remove any calls to the attr function to get
            # tag attributes.
            #
            $value =~ s/attr\s*\([a-z]*\)//gi;

            #
            # Remove all non alphanumeric characters (e.g. punctuation,
            # white space)
            #
            $value =~ s/\W//g;

            #
            # Do we have any remaining text ?
            #
            if ( length($value) > 0 ) {
                print "Quoted string in content\n" if $debug;

                #
                # Record failure
                #
                Record_Result("WCAG_2.0-F87", $line, $column, $text,
                              String_Value("non-decorative content in class") .
                              $name . " content: \"$value\"");
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Flickering_Image
#
# Parameters: url - url of image to check
#             style - name of CSS style
#             css_url - URL of CSS file with style
#
# Description:
#
#   This function checks to see if the supplied URL is
# for an image file.  It then checks to see if the image flickers.
#
#***********************************************************************
sub Check_Flickering_Image {
    my ($url, $style, $css_url) = @_;

    my ($resp, %image_details, $abs_url);

    #
    # Convert possible relative URL into a absolute URL
    # for the image.
    #
    $abs_url = url($url)->abs($current_url);

    #
    # Get image details
    #
    %image_details = Image_Details($abs_url);

    #
    # Is this a GIF image ?
    #
    if ( defined($image_details{"file_media_type"}) &&
         $image_details{"file_media_type"} eq "image/gif" ) {

        #
        # Is the image animated for 5 or more seconds ?
        #
        if ( $image_details{"animation_time"} > 5 ) {
            #
            # Animated image with animation time greater than 5 seconds.
            #
            Record_Result("WCAG_2.0-G152", -1, 0, "", 
                        String_Value("GIF animation exceeds 5 seconds") .
                        " \"$url\". " .
                        String_Value("Loaded in style") . " \"$style\" " .
                        String_Value("from CSS in") . " \"$css_url\"");
        }

        #
        # Does the image flash more than 3 times in any 1 second
        # time period ?
        #
        if ( $image_details{"most_frames_per_sec"} > 3 ) {
            #
            # Animated image that flashes more than 3 times in 1 second
            #
            Record_Result("WCAG_2.0-G19", -1, 0, "",
                        String_Value("GIF flashes more than 3 times in 1 second")
                        . " \"$url\". " .
                        String_Value("Loaded in style") . " \"$style\" " .
                        String_Value("from CSS in") . " \"$css_url\"");
        }
    }
}

#***********************************************************************
#
# Name: CSS_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             content - CSS content pointer
#
# Description:
#
#   This function runs a number of technical QA checks CSS content.
#
#***********************************************************************
sub CSS_Check {
    my ($this_url, $language, $profile, $content) = @_;

    my ($parser, @urls, $url, @tqa_results_list, $result_object, $testcase );

    #
    # Do we have a valid profile ?
    #
    print "CSS_Check: Checking URL $this_url, lanugage = $language, profile = $profile\n" if $debug;
    if ( ! defined($css_check_profile_map{$profile}) ) {
        print "CSS_Check: Unknown CSS testcase profile passed $profile\n";
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
        # Doesn't look like a URL.  Could be just a block of CSS
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Nothing to check for, checks moved to CSS_Check_Check_Styled_Text
    # function.  Leave this function here for possible future use if there
    # are checks that apply to the whole of a CSS file.
    #

    #
    # Reset valid markup flag to unknown before we are called again
    #
    $is_valid_markup = -1;

    #
    # Print testcase information
    #
    if ( $debug ) {
        print "CSS_Check results\n";
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
# Name: CSS_Check_Get_All_Styles
#
# Parameters: links - a list of link objects
#
# Description:
#
#   This function scan the list of links provided to find all <link>
# tags the reference CSS code.  It then gets the style information for
# each CSS reference to generate a single table of merged style information.
# If the same selector appears in multiple CSS files, the last one is
# used.
#
#***********************************************************************
sub CSS_Check_Get_All_Styles {
    my ($links) = @_;

    my (%styles, $link, $selector, $style, $addr);

    #
    # Check each link to see if the tag is <link> and it is
    # not in a <noscript> tag nor in modified content.
    #
    foreach $link (@$links) {
        if (    ($link->link_type eq "link")
             && (! $link->noscript)
             && (! $link->modified_content) ) {
            #
            # Is the link to CSS content ?
            #
            if ( $link->mime_type =~ /text\/css/ ) {
                #
                # Get the CSS style information from the styles cache
                #
                if ( defined($url_css_styles_cache{$link->abs_url}) ) {
                    print "cached style information for " . $link->abs_url .
                          "\n" if $debug;
                    $addr = $url_css_styles_cache{$link->abs_url};
                    
                    #
                    # Merge these styles with those we already have
                    #
                    while ( ($selector, $style) = each %$addr ) {
                        $styles{$selector} = $style;
                    }
                }
                else {
                    print "No cached style information for " .
                          $link->abs_url . "\n" if $debug;
                }
            }
        }
    }

    #
    # Return all the styles
    #
    return(%styles);
}

#***********************************************************************
#
# Name: CSS_Check_Get_Styles_From_Content
#
# Parameters: this_url - a URL
#             content - CSS content
#             mime_type - mime type of content
#
# Description:
#
#   This function extracts the styles from CSS content.  It returns
# a hash table of style objects, indexed by the style name.
#
#***********************************************************************
sub CSS_Check_Get_Styles_From_Content {
    my ($this_url, $content, $mime_type) = @_;

    my ($parser, %style_hash, $style, $css, $selector, $name, $addr);
    my (@properties, $this_prop, $property, $value, $hash, @values);
    my ($first_style, $previous_prop, $previous_hash, $previous_value);

    #
    # Do we already have style information for this URL ?
    #
    if ( defined($url_css_styles_cache{$this_url}) ) {
        print "CSS_Check_Get_Styles_From_Content: Return cached style information\n" if $debug;
        $addr = $url_css_styles_cache{$this_url};
        $url_css_styles_hits{$this_url}++;
        return(%$addr);
    }

    #
    # Did we get any content ?
    #
    print "CSS_Check_Get_Styles_From_Content\n" if $debug;
    if ( length($content) > 0 ) {
        #
        # Remove any comments from the CSS content
        #
        $content =~ s/<!--.+?-->//gs;
        $content =~ s!/\*.+?\*/!!gs;

        #
        # Create a CSS parser object and set the output adaptor.
        #
        $css = CSS->new({ 'parser' => 'CSS::Parse::Lite' });
        $css->set_adaptor('CSS::Adaptor::Objects');

        #
        # Parse the CSS content
        #
        $css->read_string($content);

        #
        # Check each style in the list of styles
        #
        for $style (@{$css->{styles}}){
            #
            # Process each selector within the style
            #
            for $selector (@{$style->{selectors}}) {
                $name = $selector->{name};
                print "Processing selector $name\n" if $debug;
                
                #
                # Does this style have a media property ?
                #
                $property = $style->get_property_by_name("media");
                if ( $property != 0 ) {
                    $hash = $$property{"options"};
                    $value = $$hash{"value"};
                    print "Media property value = $value\n" if $debug;
                    
                    #
                    # Is the media type screen ?
                    #
                    if ( ! ($value =~ /screen/i) ) {
                        print "Did not find screen media value\n" if $debug;
                        next;
                    }
                }

                #
                # Save the style object in the style_hash
                #
                if ( ! defined($style_hash{"$name"}) ) {
                    $style_hash{"$name"} = $style;
                    
                    #
                    # Add a property to the style object to record the URL
                    # this style is found in.
                    #
                    $property = $style->get_property_by_name("WPSS_CSS_URL");
                    if ( $property == 0 ) {
                        $property = CSS::Property->new({property => "WPSS_CSS_URL",
                                                        value => $this_url});
                        $style->add_property($property);
                                        }
                }
                else {
                    #
                    # Duplicate selector name
                    #
                    print "Duplicate selector name\n" if $debug;
                    
                    #
                    # Get style object of first instance of this
                    # named selector.
                    #
                    $first_style = $style_hash{"$name"};

                    #
                    # Copy properties from this selector into the one
                    # we previously found to get all properties in one selector.
                    #
                    @properties = $style->properties;
                    for $this_prop (@properties) {
                        #
                        # Get the property name and its value
                        #
                        $hash = $$this_prop{"options"};
                        $property = $$hash{"property"};
                        $value = $$hash{"value"};
                        print "Property $property, value $value\n" if $debug;
                        
                        #
                        # Do we already have this property from a previous
                        # instance of this style ?
                        #
                        if ( $property ne "WPSS_CSS_URL" ) {
                            $previous_prop = $first_style->get_property_by_name($property);
                            if ( $previous_prop != 0 ) {
                                #
                                # Is the value different ?
                                #
                                $previous_hash = $$previous_prop{"options"};
                                $previous_value = $$previous_hash{"value"};
                                if ( $value ne $previous_value ) {
                                    print "Style $name already has property $property\n" if $debug;
                                    print "  Previous $property: $previous_value\n" if $debug;
                                    print "  new      $property: $value\n" if $debug;
                                }
                            }
                            else {
                                #
                                # Add this property to the first instance of
                                # the style
                                #
                                print "Add property to first instance of style\n" if $debug;
                                $first_style->add_property($this_prop);
                            }
                        }
                    }
                }
            }
        }
        
        #
        # Dump out style information
        #
        if ( $debug ) {
            print "Styles and properties\n";
            foreach $name (sort(keys(%style_hash))) {
                print "Style $name\n";
                $style = $style_hash{"$name"};
                
                #
                # Get properties for this style
                #
                @properties = $style->properties;
                for $this_prop (@properties) {
                    #
                    # Get the property name and its value
                    #
                    $hash = $$this_prop{"options"};
                    $property = $$hash{"property"};
                    $value = $$hash{"value"};
                    print "  $property: $value\n";
                }
                print "\n";
            }
        }
    }
    else {
        print "No content passed to CSS_Check_Get_Styles_From_Content\n" if $debug;
    }

    #
    # Save style information in cache in case we need it again.
    #
    if ( $mime_type =~ /text\/css/ ) {
        $url_css_styles_cache{$this_url} = \%style_hash;
        $url_css_styles_count++;
        $url_css_styles_hits{$this_url} = 1;
    }

    #
    # Return table of styles
    #
    return(%style_hash);
}

#***********************************************************************
#
# Name: CSS_Check_Does_Style_Have_Emphasis
#
# Parameters: style_name - name of style
#             style_object - style object reference
#
# Description:
#
#   This function checks the properties of the style object to see
# if it has emphasis (e.g. bold, increased size, etc).
#
#***********************************************************************
sub CSS_Check_Does_Style_Have_Emphasis {
    my ( $style_name, $style_object ) = @_;

    my (@properties, $this_prop, $hash, $property, $value);
    my ($has_emphasis) = 0;

    #
    # Get properties for this style
    #
    print "CSS_Check_Does_Style_Have_Emphasis for style $style_name\n" if $debug;
    @properties = $style_object->properties;
    for $this_prop (@properties) {
        #
        # Get the property name and its value
        #
        $hash = $$this_prop{"options"};
        $property = $$hash{"property"};
        $value = $$hash{"value"};
        print "  $property: $value\n" if $debug;

        #
        # Check for font-weight: 
        #   bold (or higher) 
        #   700 (or higher)
        #
        if ( $property eq "font-weight" ) {
            if ( ($value eq "bold") || ($value eq "bolder") ||
                 ($value eq "700") || ($value eq "800") || ($value eq "900")) {
                $has_emphasis = 1;
                print "Found font-weight emphasis\n" if $debug;
            }
        }

        #
        # Check for font-size: 
        #   absolute size: large (or higher)
        #   relative size: larger
        #   percentage: 100% (or higher), 1.1em (or higher)
        #
        if ( $property eq "font-size" ) {
            #
            # Check absolute or relative values
            #
            if ( ($value eq "large") || ($value eq "x-large") || 
                 ($value eq "xx-large") || ($value eq "larger") ) {
                $has_emphasis = 1;
                print "Found font-size absolute or relative emphasis\n" if $debug;
            }
            #
            # Check for percentage
            #
            elsif ( $value =~ /%$/ ) {
                $value =~ s/%//g;
                if ( $value > 100 ) {
                    $has_emphasis = 1;
                    print "Found font-size percentage emphasis\n" if $debug;
                } 
            } 
            #
            # Check for em units
            #
            elsif ( $value =~ /em$/ ) {
                $value =~ s/em//g;
                if ( $value > 1.1 ) {
                    $has_emphasis = 1;
                    print "Found font-size em emphasis\n" if $debug;
                } 
            } 
        }
    }

    #
    # Return emphasis indicator
    #
    print "Style has emphasis = $has_emphasis\n" if $debug;
    return($has_emphasis);
}

#***********************************************************************
#
# Name: CSS_Check_Style_Has_Property_Value
#
# Parameters: style_name - name of style
#             style_object - style object refernce
#             property_name - name of property to check
#             property_value - value to check for in property
#
# Description:
#
#   This function checks the properties of the style object to see
# if the specified property exists and checks to see if the expected
# value is present.
#
#***********************************************************************
sub CSS_Check_Style_Has_Property_Value {
    my ($style_name, $style_object, $property_name, $property_value) = @_;

    my (@properties, $this_prop, $hash, $property, $value);
    my ($has_value) = 0;

    #
    # Get properties for this style
    #
    print "CSS_Check_Style_Has_Property_Value style $style_name, for property $property_name with value $property_value\n" if $debug;
    @properties = $style_object->properties;
    for $this_prop (@properties) {
        #
        # Get the property name and its value
        #
        $hash = $$this_prop{"options"};
        $property = $$hash{"property"};
        $value = $$hash{"value"};
        print "  $property: $value\n" if $debug;

        #
        # Is this the property name we want ?
        #
        if ( $property eq $property_name ) {
            #
            # Is the expected value in the property value ?
            #
            if ( $value eq $property_value ) {
                $has_value = 1;
                print "Found value in property\n" if $debug;
            }
        }
    }

    #
    # Return status
    #
    print "Style has property and value = $has_value\n" if $debug;
    return($has_value);
}

#***********************************************************************
#
# Name: CSS_Check_Style_Get_Property_Value
#
# Parameters: style_name - name of style
#             style_object - style object refernce
#             property_name - name of property to check
#
# Description:
#
#   This function checks the properties of the style object to see
# if the specified property exists.  If it does the value of the property
# is returned.
#
#***********************************************************************
sub CSS_Check_Style_Get_Property_Value {
    my ($style_name, $style_object, $property_name) = @_;

    my (@properties, $this_prop, $hash, $property, $value);
    my ($has_value) = 0;

    #
    # Get properties for this style
    #
    print "CSS_Check_Style_Get_Property_Value style $style_name, for property $property_name\n" if $debug;
    @properties = $style_object->properties;
    for $this_prop (@properties) {
        #
        # Get the property name
        #
        $hash = $$this_prop{"options"};
        $property = $$hash{"property"};
        print "  Property: $property\n" if $debug;

        #
        # Is this the property name we want ?
        #
        if ( $property eq $property_name ) {
            #
            # Get the property value
            #
            $value = $$hash{"value"};
            print "  Value: $value\n" if $debug;
            last;
        }
    }

    #
    # Return property value
    #
    return($value);
}

#***********************************************************************
#
# Name: CSS_Check_Check_Styled_Text
#
# Parameters: this_url - page URL
#             profile - testcase profile
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             style_list - a list of CSS style names for this tag
#             css_styles - address of a table of CSS styles for the web page
#
# Description:
#
#   This function checks for possible foreground and background colour
# specifications for this tag. If colours are found, a check of the contrast
# is performed and the results of the check are returned.
#
#***********************************************************************
sub CSS_Check_Check_Styled_Text {
    my ($this_url, $profile, $tagname, $line, $column, $text, 
        $style_list, $css_styles) = @_;

    my ($style, $style_object, $important, @tqa_results_list);
    my (@properties, $property, $value, $hash, $this_prop);
    my ($foreground, $background, $tag_foreground, $tag_background);
    my ($css_url, @style_urls, $url);

    #
    # Save URL in global variable
    #
    if ( ($this_url =~ /^http/i) || ($this_url =~ /^file/i) ) {
        $current_url = $this_url;
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of CSS
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Do we have a CSS style for the style name ?
    #
    print "CSS_Check_Check_Styled_Text tag $tagname, styles $style_list, profile $profile\n" if $debug;
    foreach $style (split(/\s+/, $style_list)) {
        if ( defined($$css_styles{$style}) ) {
            $style_object = $$css_styles{$style};
            
            #
            # Get the URL for this CSS style
            #
            $property = $style_object->get_property_by_name("WPSS_CSS_URL");
            if ( $property != 0 ) {
                $hash = $$property{"options"};
                $value = $$hash{"value"};
                $css_url = $value;
            }
            else {
                $css_url = "";
            }

            #
            # Check for flickering images in in the style
            #
            @style_urls = CSS_Extract_Links_From_CSS_Style($css_url, $style,
                                                           $style_object);
            foreach $url (@style_urls) {
                #
                # Is this a flickering image ?
                #
                Check_Flickering_Image($url->abs_url, $style, $css_url);
            }

            #
            # Get the list of properties for this selector/class name.
            # Process each one.
            #
            @properties = $style_object->properties;
            for $this_prop (@properties) {
                #
                # Get the property name and its value
                #
                $hash = $$this_prop{"options"};
                $property = $$hash{"property"};
                $value = $$hash{"value"};

                #
                # Is this an important style ?
                #
                if ( $value =~ /!important/i ) {
                    #
                    # Remove any !important qualifier
                    #
                    $value =~ s/!important//gi;
                    $important = 1;
                }
                else {
                    $important = 0;
                }

                #
                # Look for background, or background-color property
                #
                print "Check property $property, value $value\n" if $debug;
                if ( ($property eq "background") ||
                     ($property eq "background-color") ) {
                    $background = Get_Color($value);
                    print "Property $property, value $background\n" if $debug;

                    #
                    # Do we already have a background colour ?
                    #
                    if ( (! defined($tag_background)) || $important ) {
                        #
                        # Use this style's colour
                        #
                        $tag_background = $background;
                    }
                    else {
                        #
                        # Use this colour if it is darker
                        #
                        if ( hex($background) > hex($tag_background) ) {
                            print "Use darker background colour\n" if $debug;
                            $tag_background = $background;
                        }
                    }
                }
                #
                # Look for color property
                #
                elsif ( $property eq "color" ) {
                    $foreground = Get_Color($value);
                    print "Property $property, value $foreground\n" if $debug;

                    #
                    # Do we already have a foreground colour ?
                    #
                    if ( (! defined($tag_foreground)) || $important ) {
                        #
                        # Use this style's colour
                        #
                        $tag_foreground = $foreground;
                    }
                    else {
                        #
                        # Use this colour if it is lighter
                        #
                        if ( hex($foreground) < hex($tag_foreground) ) {
                            print "Use lighter foreground colour\n" if $debug;
                            $tag_foreground = $foreground;
                        }
                    }
                }
                #
                # Look for content property
                #
                elsif ( $property eq "content" ) {
                    Content_Property($style, $value, $line, $column, $text);
                }
                #
                # Look for text-decoration property
                #
                elsif ( $property eq "text-decoration" ) {
                    Text_Decoration_Property($style, $value, $line,
                                             $column, $text);
                }
            }
        }
    }

    #
    #
    # Do we have both foreground and background color
    #
    if ( defined($tag_background) && defined($tag_foreground) ) {
        #
        # Check colour contrast
        #
#
# Disable this check as unnamed styles may specify colours that
# override the named styles.
#
        #
        #Check_Color_Contrast($tag_foreground, $tag_background,
        #                     $line, $column, $text);
    }

    #
    # Return testcase results
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

