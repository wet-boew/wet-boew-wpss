#***********************************************************************
#
# Name: html_landmark.pm
#
# $Revision: 1352 $
# $URL: svn://10.36.148.185/TQA_Check/Tools/html_landmark.pm $
# $Date: 2019-06-12 12:55:10 -0400 (Wed, 12 Jun 2019) $
#
# Description:
#
#   This file contains routines that determine the WAI-ARIA landmark for
# an HTML tag.
#
# Public functions:
#     HTML_Landmark
#     HTML_Landmark_Debug
#
# Terms and Conditions of Use
#
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is
# distributed under the MIT License.
#
# MIT License
#
# Copyright (c) 2018 Government of Canada
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

package html_landmark;

use strict;

#
# Use WPSS_Tool program modules
#

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(HTML_Landmark
                  HTML_Landmark_Debug
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
# Mapping of HTML tags to ARIA landmarks
#  https://www.w3.org/TR/wai-aria-practices/#aria_landmark
#
my (%html_tag_aria_landmark) = (
    "aside",   "complementary",
    "body",    "body",  # Note: This is not an official landmark, it
                        # is included to report errors in the <body> section
                        # outside of any other landmark.
    "footer",  "contentinfo",
    "head",    "head",  # Note: This is not an official landmark, it
                        # is included to report errors in the <head> section
    "header",  "banner",
    "main",    "main",
    "nav",     "navigation",
    "section", "region",
);

#
# Some ARIA landmarks are conditional on the HTML tag not being
# a child of another tag. The following table lists the tags
# that must not be in context of a tag in order to take
# on a landmark. The list of disallowed tags is separated by
# colons.
#
my (%html_tag_aria_landmark_context) = (
    "banner",     "article:aside:main:nav:section",
    "header",     "article:aside:main:nav:section",
    "footer",     "article:aside:main:nav:section",
    "navigation", "footer:header",
    "region",     "footer:header",
);

#
# Some ARIA landmarks are conditional on the ARIA attributes
# being present. The following table lists the attributes
# that must present on the tag in order to take
# on a landmark. The list of attributes is separated by
# colons.
#
my (%html_attribute_aria_landmark_context) = (
    "region",     "aria-labelledby:aria-label",
);

#
# Mapping of ARIA roles to ARIA landmarks
#  https://www.w3.org/TR/wai-aria-practices/#aria_landmark
#
my (%aria_role_landmark) = (
    "banner",         "banner",
    "complementary",  "complementary",
    "contentinfo",    "contentinfo",
    "form",           "form",
    "main",           "main",
    "navigation",     "navigation",
    "region",         "region",
    "search",         "search",
);

#
# Mapping of ID values to ARIA landmarks
#
my (%id_landmark) = (
    "header",         "banner",
    "footer",         "contentinfo",
    "main",           "main",
    "main-content",   "main",
    "nav",            "navigation",
    "navigation",     "navigation",
);


#********************************************************
#
# Name: HTML_Landmark_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub HTML_Landmark_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: HTML_Landmark
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             current_landmark - current landmark value
#             landmark_marker - current landmark marker
#             tag_order_stack - pointer to tag order stack
#             attr - hash table of attributes
#
# Description:
#
#   This function computes the current WAI-ARIA landmark value. It checks
# the tag name and any role attributes.  If no landmark is found, the
# previous landmark value it retained.
#
# Returns:
#             current_landmark - new landmark value
#             landmark_marker - new landmark marker
#
#***********************************************************************
sub HTML_Landmark {
    my ($tagname, $line, $column, $current_landmark, $landmark_marker,
        $tag_order_stack, %attr_hash) = @_;

    my ($possible_landmark) = "";
    my ($role, $tag_context, @context_list, $tag, $tag_item);
    my ($required_attributes, @attributes, $item, $id);
    my ($found_condition_tag) = 0;
    my ($found_condition_attribute) = 0;

    #
    # Check tag name for landmark value
    #
    print "HTML_Landmark for tag $tagname\n" if $debug;
    if ( defined($html_tag_aria_landmark{$tagname}) ) {
        #
        # Possible landmark based on tag name.
        #
        $possible_landmark = $html_tag_aria_landmark{$tagname};
        print "Found possible tag based landmark $possible_landmark\n" if $debug;

        #
        # Check to see if we have conditions on the tag. Some landmarks are
        # only defined if the current tag is not in the context of another
        # tag (e.g. a header tag inside a section is not the banner for
        # the entire page).
        #
        if ( defined($html_tag_aria_landmark_context{$possible_landmark}) ) {
            #
            # Found conditions on tag based landmark
            #
            $tag_context = $html_tag_aria_landmark_context{$possible_landmark};
            @context_list = split(/:/, $tag_context);
            print "Check context tags \"$tag_context\" for possible change in landmark role\n" if $debug;

            #
            # Are any of the conditions tags in the context for this tag?
            #
            foreach $tag (@context_list) {
                foreach $tag_item (@$tag_order_stack) {
                    if ( $tag_item->tag eq $tag ) {
                        #
                        # Found conditional tag, this is not a landmark
                        #
                        print "Found condition tag " . $tag_item->tag . " in tag stack\n" if $debug;
                        $found_condition_tag = 1;
                        $possible_landmark = "";
                        last;
                    }
                }

                #
                # Did we find a conditional tag ?
                #
                if ( $found_condition_tag ) {
                    last;
                }
            }
        }

        #
        # If we still have the possible landmark, check to see if there are
        # any requires ARIA attributes.
        #
        if ( $possible_landmark ne "" ) {
            if ( defined($html_attribute_aria_landmark_context{$possible_landmark}) ) {
                print "Check for requires aria attributes\n" if $debug;
                $required_attributes = $html_attribute_aria_landmark_context{$possible_landmark};
                @attributes = split(/:/, $required_attributes);

                #
                # Do we have any of the required attributes?
                #
                foreach $item (@attributes) {
                    if ( defined($attr_hash{$item}) &&
                         ($attr_hash{$item} ne "") ) {
                        #
                        # Found attribute, this is a valid landmark
                        #
                        print "Found condition attribute $item on tag\n" if $debug;
                        $found_condition_attribute = 1;
                        last;
                    }
                }

                #
                # Did we find any of the conditions attributes?
                #
                if ( ! $found_condition_attribute ) {
                    #
                    # Missing conditions, this tag is not a landmark
                    #
                    print "Required attributes not found\n" if $debug;
                    $possible_landmark = "";
                }
            }
        }

        #
        # If we still have the possible landmark, set the current landmark
        #
        if ( $possible_landmark ne "" ) {
            print "Set current landmark to $possible_landmark\n" if $debug;
            $current_landmark = $possible_landmark;
            $landmark_marker = "<$tagname>";
        }
        else {
            #
            # We must have found a tag in the context that excludes this
            # tag's native role/landmark
            #
            print "Ignore this tag's landmark\n" if $debug;
        }
    }

    #
    # If we don't have a possible landmark from the tag name, and we didn't
    # ignore the tag due to a tag in context, then check for a role attribute.
    #
    if ( (! $found_condition_tag) &&
         ($possible_landmark eq "") &&
         defined($attr_hash{"role"}) ) {
        #
        # Does the role value match any landmark?
        #
        $role = $attr_hash{"role"};
        if ( defined($aria_role_landmark{$role}) ) {
            $current_landmark = $aria_role_landmark{$role};
            $possible_landmark = $current_landmark;
            $landmark_marker = "role=\"$role\"";
            print "Found role based landmark $current_landmark\n" if $debug;
        }
    }

    #
    # If we don't have a possible landmark from the tag name or the role
    # attribute, then check for an id attribute.
    #
    if ( (! $found_condition_tag) &&
         ($possible_landmark eq "") &&
         defined($attr_hash{"id"}) ) {
        #
        # Does the id value match any landmark?
        #
        $id = $attr_hash{"id"};
        if ( defined($id_landmark{$id}) ) {
            $current_landmark = $id_landmark{$id};
            $landmark_marker = "id=\"$id\"";
            print "Found id based landmark $current_landmark\n" if $debug;
        }
    }
    
    #
    # Return the landmark and landmark marker
    #
    return($current_landmark, $landmark_marker);
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

