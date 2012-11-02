#***********************************************************************
#
# Name: metadata_result_object.pm
#
# $Revision$
# $URL$
# $Date$
#
# Description:
#
#   This file defines an object to handle Metadata results information
# (e.g. testcase, status, error message, source location, ...).
# The object contains methods to set and read the attributes.
#
# Public functions:
#     Metadata_Result_Object_Debug
#
# Class Methods
#    new - create new object instance
#    tag - tag id
#    status - status (pass/fail)
#    content - metadata content
#    attributes - metadata attributes
#    message - test case message
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

package metadata_result_object;

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
    @EXPORT  = qw(Metadata_Result_Object_Debug);
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
# Name: Metadata_Result_Object_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Metadata_Result_Object_Debug {
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
# Parameters: tag - tag identifier
#             status - tag status (pass/fail)
#             content - tag content
#             attributes - tag attributes
#             message - test case message
#
# Description:
#
#   This function creates a new metadata_result_object item and
# initializes its data items.
#
#********************************************************
sub new {
    my ($class, $tag, $status, $content, $attributes, $message) = @_;
    
    my ($self) = {};

    #
    # Bless the reference as a metadata_result_object class item
    #
    bless $self, $class;
    
    #
    # Save arguments as result object data items
    #
    $self->{"tag"} = $tag;
    $self->{"status"} = $status;
    $self->{"content"} = $content;
    $self->{"attributes"} = $attributes;
    $self->{"message"} = $message;

    #
    # Print result object details
    #
    if ( $debug ) {
        print "New Metadata Result object, tag: " . $self->tag ;
        print " status = " . $self->status . "\n";
        print " Description = " . $self->content . "\n";
        print " message = " . $self->message . "\n";
    }
    
    #
    # Return reference to object.
    #
    return($self);
}
    
#********************************************************
#
# Name: tag
#
# Parameters: self - class reference
#             tag - tag id (optional)
#
# Description:
#
#   This function either sets or returns the tag
# attribute of the result object. If a value is supplied,
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

#********************************************************
#
# Name: content
#
# Parameters: self - class reference
#             content - tag content (optional)
#
# Description:
#
#   This function either sets or returns the content
# attribute of the result object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub content {
    my ($self, $content) = @_;

    #
    # Was a content value supplied ?
    #
    if ( defined($content) ) {
        $self->{"content"} = $content;
    }
    else {
        return($self->{"content"});
    }
}

#********************************************************
#
# Name: attributes
#
# Parameters: self - class reference
#             attributes - tag attributes (optional)
#
# Description:
#
#   This function either sets or returns the attributes
# of the result object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub attributes {
    my ($self, $attributes) = @_;

    #
    # Was a content value supplied ?
    #
    if ( defined($attributes) ) {
        $self->{"attributes"} = $attributes;
    }
    else {
        return($self->{"attributes"});
    }
}

#********************************************************
#
# Name: message
#
# Parameters: self - class reference
#             message - message (optional)
#
# Description:
#
#   This function either sets or returns the message
# attribute of the result object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub message {
    my ($self, $message) = @_;

    #
    # Was a message value supplied ?
    #
    if ( defined($message) ) {
        $self->{"message"} = $message;
    }
    else {
        return($self->{"message"});
    }
}

#********************************************************
#
# Name: status
#
# Parameters: self - class reference
#             status - status flag (optional)
#
# Description:
#
#   This function either sets or returns the status
# attribute of the result object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub status {
    my ($self, $status) = @_;

    #
    # Was a status value supplied ?
    #
    if ( defined($status) ) {
        $self->{"status"} = $status;
    }
    else {
        return($self->{"status"});
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


