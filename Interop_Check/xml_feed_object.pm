#***********************************************************************
#
# Name: xml_feed_object.pm
#
# $Revision: 5819 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Interop_Check/Tools/xml_feed_object.pm $
# $Date: 2012-05-02 16:58:31 -0400 (Wed, 02 May 2012) $
#
# Description:
#
#   This file defines an object to handle XML news feed information (e.g. type,
# title). The object contains methods to set and read attributes.
#
# Public functions:
#     XML_Feed_Object_Debug
#
# Class Methods
#    new - create new object instance
#    type - get/set feed type value
#    title - get/set title value
#    url - get/set feed URL value
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

package xml_feed_object;

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
    @EXPORT  = qw(XML_Feed_Object_Debug);
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
# Name: XML_Feed_Object_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub XML_Feed_Object_Debug {
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
# Parameters: type - type of feed
#             title - title of feed
#             url - url of feed
#
# Description:
#
#   This function creates a new xml_feed_object item and
# initializes its data items.
#
#********************************************************
sub new {
    my ($class, $type, $title, $url) = @_;
    
    my ($self) = {};

    #
    # Bless the reference as a xml_feed_object class item
    #
    bless $self, $class;
    
    #
    # Save arguments as xml feed object data items
    #
    $self->{"type"} = $type;
    $self->{"title"} = $title;
    $self->{"url"} = $url;

    #
    # Print object details
    #
    if ( $debug ) {
        print "New XML feed object";
        print " type = " . $self->type;
        print " title = " . $self->title . "\n";
    }
    
    #
    # Return reference to object.
    #
    return($self);
}
    
#********************************************************
#
# Name: type
#
# Parameters: self - class reference
#             type - feed type (optional)
#
# Description:
#
#   This function either sets or returns the type
# attribute of the xml feed object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub type {
    my ($self, $type) = @_;
    
    #
    # Was a type value supplied ?
    #
    if ( defined($type) ) {
        $self->{"type"} = $type;
    }
    else {
        return($self->{"type"});
    }
}

#********************************************************
#
# Name: title
#
# Parameters: self - class reference
#             title_value - title value (optional)
#
# Description:
#
#   This function either sets or returns the title
# attribute of the xml feed object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub title {
    my ($self, $title_value) = @_;

    #
    # Was a title value supplied ?
    #
    if ( defined($title_value) ) {
        $self->{"title"} = $title_value;
    }
    else {
        return($self->{"title"});
    }
}

#********************************************************
#
# Name: url
#
# Parameters: self - class reference
#             url - url value (optional)
#
# Description:
#
#   This function either sets or returns the url
# attribute of the xml feed object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub url {
    my ($self, $url) = @_;

    #
    # Was a url value supplied ?
    #
    if ( defined($url) ) {
        $self->{"url"} = $url;
    }
    else {
        return($self->{"url"});
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


