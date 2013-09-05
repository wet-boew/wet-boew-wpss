#***********************************************************************
#
# Name: content_section_object.pm
#
# $Revision: 6303 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Content_Check/Tools/content_section_object.pm $
# $Date: 2013-06-25 14:14:21 -0400 (Tue, 25 Jun 2013) $
#
# Description:
#
#   This file defines an object to handle content section marker
# information (marker, section, sub section, type). The object
# contains methods to set and read the object attributes.
#
# Public functions:
#     Content_Section_Object_Debug
#
# Class Methods
#    new - create new object instance
#    section - get/set section value
#    subsection - get/set subsection value
#    marker - get/set marker value
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

package content_section_object;

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
    @EXPORT  = qw(Content_Section_Object_Debug);
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
# Name: Content_Section_Object_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Content_Section_Object_Debug {
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
# Parameters: section - section value
#             subsection - subsection value
#             marker - marker value
#
# Description:
#
#   This function creates a new content_section_object item and
# initializes its data items.
#
#********************************************************
sub new {
    my ($class, $section, $subsection, $marker) = @_;
    
    my ($self) = {};

    #
    # Bless the reference as a content_section_object class item
    #
    bless $self, $class;
    
    #
    # Save arguments as link object data items
    #
    $self->{"section"} = $section;
    $self->{"subsection"} = $subsection;
    $self->{"marker"} = $marker;

    #
    # Print object details
    #
    if ( $debug ) {
        print "New content section object ";
        print " section = " . $self->section;
        print " subsection = " . $self->subsection;
        print " marker = " . $self->marker . "\n";
    }
    
    #
    # Return reference to object.
    #
    return($self);
}
    
#********************************************************
#
# Name: section
#
# Parameters: self - class reference
#             section - section value (optional)
#
# Description:
#
#   This function either sets or returns the section
# attribute of the content section object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub section {
    my ($self, $section) = @_;
    
    #
    # Was a section value supplied ?
    #
    if ( defined($section) ) {
        $self->{"section"} = $section;
    }
    else {
        return($self->{"section"});
    }
}

#********************************************************
#
# Name: subsection
#
# Parameters: self - class reference
#             subsection - subsection (optional)
#
# Description:
#
#   This function either sets or returns the subsection
# attribute of the content section object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub subsection {
    my ($self, $subsection) = @_;
   
    #
    # Was a subsection value supplied ?
    #
    if ( defined($subsection) ) {
        $self->{"subsection"} = $subsection;
    }
    else {
        return($self->{"subsection"});
    }
}

#********************************************************
#
# Name: marker
#
# Parameters: self - class reference
#             marker - marker value (optional)
#
# Description:
#
#   This function either sets or returns the marker
# attribute of the content section object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub marker {
    my ($self, $marker) = @_;

    #
    # Was a marker value supplied ?
    #
    if ( defined($marker) ) {
        $self->{"marker"} = $marker;
    }
    else {
        return($self->{"marker"});
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


