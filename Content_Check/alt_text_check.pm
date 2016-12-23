#***********************************************************************
#
# Name:   alt_text_check.pm
#
# $Revision: 5461 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Content_Check/Tools/alt_text_check.pm $
# $Date: 2011-09-08 10:35:23 -0400 (Thu, 08 Sep 2011) $
#
# Description:
#
#   This file contains routines that deal with alt text reporting.
#
# Public functions:
#     Alt_Text_Check_Record_Image_Details
#     Alt_Text_Check_Generate_Report
#     Alt_Text_Check_Debug
#     Alt_Text_Check_Language
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

package alt_text_check;

use strict;
use File::Basename;
use HTML::Entities;

#
# Use WPSS_Tool program modules
#
use alt_object;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Alt_Text_Check_Record_Image_Details
                  Alt_Text_Check_Generate_Report
                  Alt_Text_Check_Debug
                  Alt_Text_Check_Language
                  );
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
    "Content language",			"Content language ",
    "Image at",             "Image at",
    "URLs that contain the image", "URLs that contain the image",
    );

my %string_table_fr = (
    "Content language",			"La langue du contenu ",
    "Image at",             "L'image à",
    "URLs that contain the image", "Les URL qui contiennent de l'image",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: Alt_Text_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Alt_Text_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;

    #
    # Set debug flag of supporting modules
    #
    Alt_Object_Debug($debug);
}

#***********************************************************************
#
# Name: Alt_Text_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Alt_Text_Check_Language {
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
# Name: Alt_Text_Check_Record_Image_Details
#
# Parameters: alt_objects - address of hash table of image objects
#             href - URL of document containing links
#             link_objects - list of link objects
#
# Description:
#
#   This function scans the list of link objects to find all
# image links (e.g. <img>).  If the URL for the image link does
# not exist in the alt_objects hash table, a new alt_object is created
# to record its details.  If the image link already exists, the
# alt_object is updated with the image link details (i.e. language,
# alt text, title).
#
#**********************************************************************
sub Alt_Text_Check_Record_Image_Details {
    my ($alt_objects, $href, @link_objects) = @_;

    my ($link, $alt_object, $image_href);

    #
    # Loop through the link object array looking for image links
    #
    print "Alt_Text_Check_Record_Image_Details for $href link count " .
          @link_objects . "\n" if $debug;
    foreach $link (@link_objects) {
        #
        # Is this link from an <img> tag (HTML) or from a url function (CSS) ?
        # Is the mime-type an image ?
        #
        print "Type = " . $link->link_type . " mime-type = " . $link->mime_type . "\n" if $debug;
        if ( (($link->link_type eq "img") ||
              ($link->link_type eq "url")) &&
              ($link->mime_type =~ /^image/i) ) {
            #
            # Does this image href exist in the alt_objects table ?
            #
            $image_href = $link->abs_url;
            if ( defined($$alt_objects{$image_href}) ) {
                #
                # URL already in table, add details
                #
                print "Add to existing alt_object\n" if $debug;
                $alt_object = $$alt_objects{$image_href};
                $alt_object->alt_title_lang_url($image_href, $link->alt,
                                                $link->title, $link->lang,
                                                $href);
            }
            else {
                #
                # Create new alt object to store image details
                #
                print "Create new alt_object\n" if $debug;
                $alt_object = alt_object->new($image_href, $link->alt,
                                              $link->title, $link->lang,
                                              $href);

                #
                # Save alt_object in hash table, indexed by image
                # URL
                #
                $$alt_objects{$image_href} = $alt_object;
            }
        }
    }
}

#***********************************************************************
#
# Name: Alt_Text_Check_Generate_Report
#
# Parameters: alt_objects - address of hash table of image objects
#
# Description:
#
#   This function generates a report of alt text objects.  The report
# is sorted by
#    image file URL, language, alt text, title, url of document containing
#                                               link to image
#***********************************************************************
sub Alt_Text_Check_Generate_Report {
    my ($alt_objects) = @_;

    my ($alt_object, @image_url_list, @lang_list, @alt_title_list);
    my (@url_list, $image_url, $lang, $alt_title, $alt, $title, $url);
    my ($report) = "";

    #
    # Get list of URLs in the alt_object hash table
    #
    print "Alt_Text_Check_Generate_Report\n" if $debug;
    @image_url_list = sort(keys(%$alt_objects));

    #
    # Process each image URL in turn.
    #
    foreach $image_url (@image_url_list) {
        #
        # Get list of languages for this image URL
        #
        $alt_object = $$alt_objects{$image_url};
        @lang_list = $alt_object->lang_list;

        #
        # Add URL to the report
        #
        print "Image URL: $image_url\n" if $debug;
        $report .= "
<h2>$image_url</h2>
<p><img src=\"$image_url\" alt=\"" . encode_entities(String_Value("Image at")) .
" $image_url\" /></p>
<table width=\"75%\" border=\"1\">
  <tr>
    <th width=\"5%\">lang</th>
    <th width=\"15%\">alt</th>
    <th width=\"10%\">title</th>
    <th width=\"70%\">" . encode_entities(String_Value("URLs that contain the image")) .
" </th>
  </tr>
";

        #
        # Process each language
        #
        foreach $lang (sort(@lang_list)) {
            #
            # Get list of alt text/title combinations
            #
            @alt_title_list = $alt_object->alt_title_list($lang);

            #
            # Process each alt text/title combination
            #
            foreach $alt_title (sort(@alt_title_list)) {
                #
                # Split alt text & title on new-line
                #
                ($alt, $title) = split("\n", $alt_title);

                #
                # Get list of URLs that reference this image
                #
                @url_list = $alt_object->url_list($lang, $alt_title);

                #
                # Print Alt text and title
                #
                print "  Alt: $alt\n" if $debug;
                print "  Title: $title\n" if $debug;
                $report .= "
<tr>
    <td valign=\"top\">$lang</td>
    <td valign=\"top\">\"" . encode_entities($alt) . "\"</td>
    <td valign=\"top\">\"" . encode_entities($title) . "\"</td>
    <td>
        <ul>
";

                #
                # Print URL list
                #
                foreach $url (sort(@url_list)) {
                    print "      $url\n" if $debug;
                    $report .= "<li><a href=\"$url\">$url</a></li>\n";
                }

                #
                # Finish off list
                #
                $report .= "
        </ul>
    </td>
</tr>
";
            }
        }

        #
        # Separate each image URL block
        #
        print "\n" if $debug;
        $report .= "
</table>
<br />
";
    }

    #
    # Return report
    #
    return($report);
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

