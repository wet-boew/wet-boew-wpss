#***********************************************************************
#
# Name: alt_object.pm
#
# $Revision: 5461 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Content_Check/Tools/alt_object.pm $
# $Date: 2011-09-08 10:35:23 -0400 (Thu, 08 Sep 2011) $
#
# Description:
#
#   This file defines an object to handle alt text information for URLs.
# The object contains methods to set and read the object attributes.
#
# Public functions:
#     Alt_Object_Debug
#
# Class Methods
#    new - create new object instance
#    alt_title_lang_url - set alt text, title, language and url values
#    lang_list - get the list of alt text languages
#    alt_title_list - get list of alt text and title values (for a
#                     particular language)
#    url_list - get list of URL values (for a particular language,
#               alt text and title)
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

package alt_object;

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
    @EXPORT  = qw(Alt_Object_Debug);
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;

#********************************************************
#
# Name: Alt_Object_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Alt_Object_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#********************************************************
#
# Name: new
#
# Parameters: href - href of link
#             alt - alt text value
#             title - title text value
#             lang - language of alt & title
#             url - url of file containing link
#
# Description:
#
#   This function creates a new alt_object item and
# initializes it's data items.
#
#********************************************************
sub new {
    my ($class, $href, $alt, $title, $lang, $url) = @_;
    
    my ($self) = {};
    my (%lang_map, %alt_title_url_map);

    #
    # Bless the reference as a alt_object class item
    #
    bless $self, $class;

    #
    # If any of the arguments are not defined, replace them with
    # an empty string.
    #
    if ( ! defined($alt) ) {
        $alt = "";
    }
    if ( ! defined($title) ) {
        $title = "";
    }
    if ( ! defined($lang) ) {
        $lang = "";
    }

    #
    # Save language value and address of alt/title/URL map
    #
    $lang_map{"$lang"} = \%alt_title_url_map;

    #
    # Save alt text, title and URL
    #
    $alt =~ s/\n//g;
    $alt =~ s/^\s+//g;
    $title =~ s/\n//g;
    $title =~ s/^\s+//g;
    $url =~ s/\n//g;
    $alt_title_url_map{"$alt\n$title"} = "$url\n";

    #
    # Save object data items
    #
    $self->{"href"} = $href;
    $self->{"lang_map"} = \%lang_map;

    #
    # Print object details
    #
    if ( $debug ) {
        print "New alt object\n";
        print " href = $href\n";
        print " lang = $lang\n";
        print " alt text = $alt\n";
        print " title = $title\n";
        print " url = $url\n";
    }
    
    #
    # Return reference to object.
    #
    return($self);
}
    
#********************************************************
#
# Name: alt_title_lang_url
#
# Parameters: self - class reference
#             href - href of link
#             alt - alt text value
#             title - title text value
#             lang - language of alt & title
#             url - url of file containing link
#
# Description:
#
#   This function sets the language/alt/title 
# values of the alt object.  If this combination does
# not already exist, it is added to the hash table that
# manages the language, alt, title combination.
#
#********************************************************
sub alt_title_lang_url {
    my ($self, $href, $alt, $title, $lang, $url) = @_;

    my ($lang_map, $alt_title_url_map, $alt_title, $url_list);
    my (%alt_title_url_map_table);

    #
    # If any of the arguments are not defined, replace them with
    # an empty string.
    #
    if ( ! defined($alt) ) {
        $alt = "";
    }
    if ( ! defined($title) ) {
        $title = "";
    }
    if ( ! defined($lang) ) {
        $lang = "";
    }

    #
    # Get address of language map hash table
    #
    $lang_map = $self->{"lang_map"};

    #
    # Do we have a table for this language ?
    #
    if ( ! defined($$lang_map{"$lang"}) ) {
        #
        # Save language value and address of alt/title/URL map
        #
        $$lang_map{"$lang"} = \%alt_title_url_map_table;
    }

    #
    # Get address of alt text/url hash table for this language
    #
    $alt_title_url_map = $$lang_map{"$lang"};

    #
    # See if there already is an entry for this atl text/title combination
    #
    $url =~ s/\n//g;
    $alt =~ s/\n//g;
    $title =~ s/\n//g;
    $alt_title = "$alt\n$title";
    if ( defined($$alt_title_url_map{"$alt_title"}) ) {
        #
        # Add this URL to the list if it is not already there.
        #
        $url_list = $$alt_title_url_map{"$alt_title"};
        if ( index($url_list, "$url\n") == -1 )  {
            $url_list .= "$url\n";
            $$alt_title_url_map{"$alt_title"} = $url_list;
        }
    }
    else {
        #
        # Add entry to the table with this URL as the value.
        #
        $$alt_title_url_map{"$alt_title"} = "$url\n";
    }

    #
    # Print object details
    #
    if ( $debug ) {
        print "New lang/alt/title entry\n";
        print " href = $href\n";
        print " lang = $lang\n";
        print " alt text = $alt\n";
        print " title = $title\n";
        print " url = $url\n";
    }
}

#********************************************************
#
# Name: lang_list
#
# Parameters: self - class reference
#
# Description:
#
#   This function returns the list of alt text languages
# recorded for this alt object.
#
#********************************************************
sub lang_list {
    my ($self) = @_;

    my ($lang_map, @lang_list);

    #
    # Get address of language map hash table
    #
    $lang_map = $self->{"lang_map"};

    #
    # Get list of languages
    #
    @lang_list = keys(%$lang_map);
    print "alt_object->lang_list = " . join(" ", @lang_list) . "\n" if $debug;

    #
    # Return list of languages
    #
    return(@lang_list);
}

#********************************************************
#
# Name: alt_title_list
#
# Parameters: self - class reference
#             lang - language of alt text
#
# Description:
#
#   This function returns the list of alt text and title
# values for the specified language recorded for this alt object.
#
#********************************************************
sub alt_title_list {
    my ($self, $lang) = @_;

    my ($lang_map, $alt_title_url_map, @alt_title_list);

    #
    # Get address of language map hash table
    #
    $lang_map = $self->{"lang_map"};

    #
    # Get hash table of alt text/title for this language
    #
    if ( ! defined($lang) ) {
        $lang = "";
    }
    if ( defined($$lang_map{"$lang"}) ) {
        $alt_title_url_map = $$lang_map{"$lang"};
    }

    #
    # Get list of alt text/title combinations for this language
    #
    if ( defined($alt_title_url_map) ) {
        @alt_title_list = keys(%$alt_title_url_map);
        print "alt_object->alt_title_list = " . join("", @alt_title_list) . "\n" if $debug;
    }

    #
    # Return list of alt text/title combinations
    #
    return(@alt_title_list);
}

#********************************************************
#
# Name: url_list
#
# Parameters: self - class reference
#             lang - language of alt text
#             alt_title - alt text/title value
#
# Description:
#
#   This function returns the list of URLs values for the 
# specified language and alt text and title combination.
#
#********************************************************
sub url_list {
    my ($self, $lang, $alt_title) = @_;

    my ($lang_map, $alt_title_url_map, @url_list);

    #
    # Get address of language map hash table
    #
    $lang_map = $self->{"lang_map"};

    #
    # Get hash table of alt text/title for this language
    #
    if ( ! defined($lang) ) {
        $lang = "";
    }
    if ( defined($$lang_map{"$lang"}) ) {
        $alt_title_url_map = $$lang_map{"$lang"};
    }

    #
    # Get list of urls for this alt text/title combination
    #
    if ( defined($alt_title_url_map) && 
         defined($$alt_title_url_map{"$alt_title"}) ) {
        @url_list = split("\n", $$alt_title_url_map{"$alt_title"});
        print "alt_object->url_list = " . join("", @url_list) . "\n" if $debug;
    }

    #
    # Return list of urls
    #
    return(@url_list);
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


