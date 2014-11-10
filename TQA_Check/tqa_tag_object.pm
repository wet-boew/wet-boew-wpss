#***********************************************************************
#
# Name: tqa_tag_object.pm
#
# $Revision: 6813 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/TQA_Check/Tools/tqa_tag_object.pm $
# $Date: 2014-10-28 15:19:55 -0400 (Tue, 28 Oct 2014) $
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
#    attr - hash table of attributes
#    column_no - source column number
#    is_hidden - tag is hidden
#    is_visible - tag is visible
#    line_no - source line number
#    styles - computed style selectors
#    tag - tag name
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

    #
    # Bless the reference as a tqa_tag_object class item
    #
    bless $self, $class;

    #
    # Save arguments as object data items
    #
    $self->{"attr"} = $attr;
    $self->{"column_no"} = $column_no;
    $self->{"is_hidden"} = 0;
    $self->{"is_visible"} = 1;
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

