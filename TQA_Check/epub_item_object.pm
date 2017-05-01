#***********************************************************************
#
# Name: epub_item_object.pm
#
# $Revision: 358 $
# $URL: svn://10.36.20.203/TQA_Check/Tools/epub_item_object.pm $
# $Date: 2017-04-28 10:49:15 -0400 (Fri, 28 Apr 2017) $
#
# Description:
#
#   This file defines an object to handle an EPUB manifest item files
# (e.g. href, media-type, etc.). The object contains methods
# to set and read the object attributes.
#
# Public functions:
#     Set_EPUB_Item_Object_Debug
#
# Class Methods
#    new - create new object instance
#    id - get/set the id value
#    href - get/set the href value
#    media_type - get/set the media type of data file (e.g. image/jpeg,
#                 text/html)
#
# Terms and Conditions of Use
#
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is
# distributed under the MIT License.
#
# MIT License
#
# Copyright (c) 2017 Government of Canada
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

package epub_item_object;

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
    @EXPORT  = qw(Set_EPUB_Item_Object_Debug);
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
# Name: Set_EPUB_Item_Object_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Set_EPUB_Item_Object_Debug {
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
# Parameters: id - item identifier
#             href - href of file
#             media_type - media type of file
#
# Description:
#
#   This function creates a new epub_item_object
# item and initializes its data items.
#
#********************************************************
sub new {
    my ($class, $id, $href, $media_type) = @_;

    my ($self) = {};

    #
    # Bless the reference as a epub_item_object class item
    #
    bless $self, $class;

    #
    # Save arguments as object data items
    #
    $self->{"id"} = $id;
    $self->{"href"} = $href;
    $self->{"media_type"} = $media_type;

    #
    # Print object details
    #
    print "New EPUB manifest item file object, ID $id\n" if $debug;

    #
    # Return reference to object.
    #
    return($self);
}

#********************************************************
#
# Name: href
#
# Parameters: self - class reference
#             href - file href (optional)
#
# Description:
#
#   This function either sets or returns the href
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub href {
    my ($self, $href) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($href) ) {
        $self->{"href"} = $href;
    }
    else {
        return($self->{"href"});
    }
}

#********************************************************
#
# Name: id
#
# Parameters: self - class reference
#             id - item id (optional)
#
# Description:
#
#   This function either sets or returns the id
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub id {
    my ($self, $id) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($id) ) {
        $self->{"id"} = $id;
    }
    else {
        return($self->{"id"});
    }
}

#********************************************************
#
# Name: media_type
#
# Parameters: self - class reference
#             media_type - media type (optional)
#
# Description:
#
#   This function either sets or returns the media_type
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub media_type {
    my ($self, $media_type) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($media_type) ) {
        $self->{"media_type"} = $media_type;
    }
    else {
        return($self->{"media_type"});
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


