#***********************************************************************
#
# Name: tqa_tag_object.pm
#
# $Revision: 1936 $
# $URL: svn://10.36.148.185/WPSS_Tool/TQA_Check/Tools/tqa_tag_object.pm $
# $Date: 2021-02-01 08:36:31 -0500 (Mon, 01 Feb 2021) $
#
# Description:
#
#   This file defines an object to handle HTML tag attributes
# (e.g. tag name, location, attributes, styles, etc).
# The object contains methods to set and read the attributes.
#
# Public functions:
#     TQA_Tag_Object_Debug
#
# Class Methods
#    new - create new object instance
#    accessible_name_content - get/set attribute value
#    add_children_role - add role to list of children roles
#    attr - get/set hash table of attributes
#    attr_value - get attribute value
#    children_roles - get the list of children roles
#    column_no - get/set source column number
#    content - get/set current tag content
#    explicit_role - get/set the explicit role value
#    implicit_role - get/set the implicit role value
#    interactive - get/set flag if tag is interactive
#    is_aria_hidden - get/set tag is aria-hidden flag
#    is_hidden - get/set tag is hidden flag
#    is_visible - get/set tag is visible flag
#    landmark - get/set landmark
#    landmark_marker - get/set landmark marker
#    line_no - get/set source line number
#    styles - get/set computed style selectors
#    tag - get/set tag name
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

package tqa_tag_object;

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
    @EXPORT  = qw(TQA_Tag_Object_Debug);
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
# Name: TQA_Tag_Object_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub TQA_Tag_Object_Debug {
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
# Parameters: tag - tag name
#             line_no - source line number
#             column_no - source column number
#             attr - address of hash table of attributes
#
# Description:
#
#   This function creates a new tqa_tag_object item and
# initializes it's data items.
#
#********************************************************
sub new {
    my ($class, $tag, $line_no, $column_no, $attr) = @_;

    my ($self) = {};
    
    my (%children_roles);

    #
    # Bless the reference as a tqa_tag_object class item
    #
    bless $self, $class;

    #
    # Save arguments as object data items
    #
    $self->{"accessible_name_content"} = 0;
    $self->{"attr"} = $attr;
    $self->{"children_roles"} = \%children_roles;
    $self->{"column_no"} = $column_no;
    $self->{"content"} = "";
    $self->{"explicit_role"} = "";
    $self->{"implicit_role"} = "";
    $self->{"interactive"} = 0;
    $self->{"is_aria_hidden"} = 0;
    $self->{"is_hidden"} = 0;
    $self->{"is_visible"} = 1;
    $self->{"landmark"} = "";
    $self->{"landmark_marker"} = "";
    $self->{"line_no"} = $line_no;
    $self->{"styles"} = "";
    $self->{"tag"} = $tag;

    #
    # Print object details
    #
    if ( $debug ) {
        print "New TQA Tag object, tag: " . $self->tag ;
        print " Line/column: " . $self->line_no . ":" . $self->column_no . "\n";
    }

    #
    # Return reference to object.
    #
    return($self);
}

#********************************************************
#
# Name: accessible_name_content
#
# Parameters: self - class reference
#             value - content (optional)
#
# Description:
#
#   This function either sets or returns the accessible_name_content
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub accessible_name_content {
    my ($self, $value) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $self->{"accessible_name_content"} = $value;
    }
    else {
        return($self->{"accessible_name_content"});
    }
}


#********************************************************
#
# Name: add_children_role
#
# Parameters: self - class reference
#             value - role value
#
# Description:
#
#   This function either add a role to the list of children_roles.

#
#********************************************************
sub add_children_role {
    my ($self, $value) = @_;
    
    my ($children_roles_addr, $child_role);

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $children_roles_addr = $self->{"children_roles"};
        foreach $child_role (split(/\s+/, $value)) {
            $$children_roles_addr{"$child_role"} = 1;
        }
    }
}

#********************************************************
#
# Name: attr
#
# Parameters: self - class reference
#             attr - attr reference (optional)
#
# Description:
#
#   This function either sets or returns the attribute
# hash table address attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub attr {
    my ($self, $attr) = @_;

    #
    # Was a attr value supplied ?
    #
    if ( defined($attr) ) {
        $self->{"attr"} = $attr;
    }
    else {
        return($self->{"attr"});
    }
}

#********************************************************
#
# Name: attr_value
#
# Parameters: self - class reference
#             attr_name - attribute name
#
# Description:
#
#   This function returns the value of the named attribute.
# If the attribute does not exist, null is returned.
#
#********************************************************
sub attr_value {
    my ($self, $attr_name) = @_;
    
    my ($attr, $value);

    #
    # Do we have table of attribute name/values?
    #
    $attr = $self->{"attr"};
    if ( defined($attr) && defined($$attr{$attr_name}) ) {
        $value = $$attr{$attr_name};
    }
    
    #
    # Return the attribute value (if there is one)
    #
    return($value);
}

#********************************************************
#
# Name: children_roles
#
# Parameters: self - class reference
#
# Description:
#
#   This function either returns the list of children_roles.
#
#********************************************************
sub children_roles {
    my ($self, $value) = @_;

    my ($children_roles_addr);

    #
    # Get the table of children roles and return the list
    # of keys.
    #
    $children_roles_addr = $self->{"children_roles"};
    return(keys(%$children_roles_addr));
}

#********************************************************
#
# Name: column_no
#
# Parameters: self - class reference
#             column_no - column number (optional)
#
# Description:
#
#   This function either sets or returns the column_no
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub column_no {
    my ($self, $column_no) = @_;

    #
    # Was a column_no value supplied ?
    #
    if ( defined($column_no) ) {
        $self->{"column_no"} = $column_no;
    }
    else {
        return($self->{"column_no"});
    }
}

#********************************************************
#
# Name: content
#
# Parameters: self - class reference
#             value - content (optional)
#
# Description:
#
#   This function either sets or returns the content
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub content {
    my ($self, $value) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $self->{"content"} = $value;
    }
    else {
        return($self->{"content"});
    }
}

#********************************************************
#
# Name: explicit_role
#
# Parameters: self - class reference
#             role - role value (optional)
#
# Description:
#
#   This function either sets or returns the explicit_role
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub explicit_role {
    my ($self, $role) = @_;

    #
    # Was a role value supplied ?
    #
    if ( defined($role) ) {
        $self->{"explicit_role"} = $role;
    }
    else {
        return($self->{"explicit_role"});
    }
}

#********************************************************
#
# Name: implicit_role
#
# Parameters: self - class reference
#             role - role value (optional)
#
# Description:
#
#   This function either sets or returns the implicit_role
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub implicit_role {
    my ($self, $role) = @_;

    #
    # Was a role value supplied ?
    #
    if ( defined($role) ) {
        $self->{"implicit_role"} = $role;
    }
    else {
        return($self->{"implicit_role"});
    }
}

#********************************************************
#
# Name: interactive
#
# Parameters: self - class reference
#             value - value (optional)
#
# Description:
#
#   This function either sets or returns the interactive
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub interactive {
    my ($self, $value) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $self->{"interactive"} = $value;
    }
    else {
        return($self->{"interactive"});
    }
}

#********************************************************
#
# Name: is_aria_hidden
#
# Parameters: self - class reference
#             is_hidden - aria-hidden status (optional)
#
# Description:
#
#   This function either sets or returns the is_aria_hidden
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub is_aria_hidden {
    my ($self, $is_hidden) = @_;

    #
    # Was a is_hidden value supplied ?
    #
    if ( defined($is_hidden) ) {
        $self->{"is_aria_hidden"} = $is_hidden;
    }
    else {
        return($self->{"is_aria_hidden"});
    }
}

#********************************************************
#
# Name: is_hidden
#
# Parameters: self - class reference
#             is_hidden - is hidden status (optional)
#
# Description:
#
#   This function either sets or returns the is_hidden
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub is_hidden {
    my ($self, $is_hidden) = @_;

    #
    # Was a is_hidden value supplied ?
    #
    if ( defined($is_hidden) ) {
        $self->{"is_hidden"} = $is_hidden;
    }
    else {
        return($self->{"is_hidden"});
    }
}

#********************************************************
#
# Name: is_visible
#
# Parameters: self - class reference
#             is_visible - is visible status (optional)
#
# Description:
#
#   This function either sets or returns the is_visible
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub is_visible {
    my ($self, $is_visible) = @_;

    #
    # Was a is_visible value supplied ?
    #
    if ( defined($is_visible) ) {
        $self->{"is_visible"} = $is_visible;
    }
    else {
        return($self->{"is_visible"});
    }
}

#********************************************************
#
# Name: landmark
#
# Parameters: self - class reference
#             landmark - landmark name (optional)
#
# Description:
#
#   This function either sets or returns the landmark
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub landmark {
    my ($self, $landmark) = @_;

    #
    # Was a landmark value supplied ?
    #
    if ( defined($landmark) ) {
        $self->{"landmark"} = $landmark;
    }
    else {
        return($self->{"landmark"});
    }
}

#********************************************************
#
# Name: landmark_marker
#
# Parameters: self - class reference
#             landmark_marker - landmark marker (optional)
#
# Description:
#
#   This function either sets or returns the landmark
# marker attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub landmark_marker {
    my ($self, $landmark_marker) = @_;

    #
    # Was a landmark marker value supplied ?
    #
    if ( defined($landmark_marker) ) {
        $self->{"landmark_marker"} = $landmark_marker;
    }
    else {
        return($self->{"landmark_marker"});
    }
}

#********************************************************
#
# Name: line_no
#
# Parameters: self - class reference
#             line_no - line number (optional)
#
# Description:
#
#   This function either sets or returns the line_no
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub line_no {
    my ($self, $line_no) = @_;

    #
    # Was a line_no value supplied ?
    #
    if ( defined($line_no) ) {
        $self->{"line_no"} = $line_no;
    }
    else {
        return($self->{"line_no"});
    }
}


#********************************************************
#
# Name: styles
#
# Parameters: self - class reference
#             styles - computed styles (optional)
#
# Description:
#
#   This function either sets or returns the list of
# computed styles attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub styles {
    my ($self, $styles) = @_;

    #
    # Was a styles value supplied ?
    #
    if ( defined($styles) ) {
        $self->{"styles"} = $styles;
    }
    else {
        return($self->{"styles"});
    }
}

#********************************************************
#
# Name: tag
#
# Parameters: self - class reference
#             tag - tag name (optional)
#
# Description:
#
#   This function either sets or returns the tag
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub tag {
    my ($self, $tag) = @_;

    #
    # Was a tag value supplied ?
    #
    if ( defined($tag) ) {
        $self->{"tag"} = $tag;
    }
    else {
        return($self->{"tag"});
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

