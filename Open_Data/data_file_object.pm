#***********************************************************************
#
# Name: data_file_object.pm
#
# $Revision: 523 $
# $URL: svn://10.36.148.185/Open_Data/Tools/data_file_object.pm $
# $Date: 2017-10-18 11:45:32 -0400 (Wed, 18 Oct 2017) $
#
# Description:
#
#   This file defines an object to handle a Open Data data file information
# (e.g. type, rows of data, etc.). The object contains methods
# to set and read the object attributes.
#
# Public functions:
#     Set_Data_File_Object_Debug
#
# Class Methods
#    new - create new object instance
#    attribute - get/set an attribute value (attributes vary by file type)
#    checksum - get/set the content checksum
#    encoding - get/set the encoding (e.g. UTF-8)
#    format - get/set the format of the data file (e.g. JSON-CSV)
#    lang - get/set the data file content language
#    type - get/set the type of data file (e.g. CSV, JSON, XML)
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

package data_file_object;

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
    @EXPORT  = qw(Set_Data_File_Object_Debug);
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
# Name: Set_Data_File_Object_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Set_Data_File_Object_Debug {
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
# Parameters: url - url of data file
#             type - type of data file
#
# Description:
#
#   This function creates a new data_file_object item and
# initializes its data items.
#
#********************************************************
sub new {
    my ($class, $url, $type) = @_;

    my ($self) = {};

    #
    # Bless the reference as a data_file_object class item
    #
    bless $self, $class;

    #
    # Save arguments as object data items and initialize fields values.
    #
    $self->{"checksum"} = "";
    $self->{"encoding"} = "";
    $self->{"format"} = "";
    $self->{"type"} = $type;
    $self->{"url"} = $url;

    #
    # Print object details
    #
    print "New Data File object, url $url\n" if $debug;

    #
    # Return reference to object.
    #
    return($self);
}

#********************************************************
#
# Name: attribute
#
# Parameters: self - class reference
#             key - attribute key
#             value - attribute value (optional)
#
# Description:
#
#   This function either sets or returns the named
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub attribute {
    my ($self, $key, $value) = @_;

    #
    # Was a key provided ?
    #
    if ( defined($key) ) {
        #
        # Was a value supplied ?
        #
        if ( defined($value) ) {
            $self->{"$key"} = $value;
        }
        elsif ( defined($self->{"$key"}) ) {
            return($self->{"$key"});
        }
        else {
            return("");
        }
    }
    else {
        return("");
    }
}

#********************************************************
#
# Name: checksum
#
# Parameters: self - class reference
#             checksum - file content checksum (optional)
#
# Description:
#
#   This function either sets or returns the file content
# checksum attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub checksum {
    my ($self, $checksum) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($checksum) ) {
        $self->{"checksum"} = $checksum;
    }
    else {
        return($self->{"checksum"});
    }
}

#********************************************************
#
# Name: encoding
#
# Parameters: self - class reference
#             encoding - content encoding (optional)
#
# Description:
#
#   This function either sets or returns the content encoding
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub encoding {
    my ($self, $encoding) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($encoding) ) {
        $self->{"encoding"} = $encoding;
    }
    else {
        return($self->{"encoding"});
    }
}

#********************************************************
#
# Name: format
#
# Parameters: self - class reference
#             format - content format (optional)
#
# Description:
#
#   This function either sets or returns the content format
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub format {
    my ($self, $format) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($format) ) {
        $self->{"format"} = $format;
    }
    else {
        return($self->{"format"});
    }
}

#********************************************************
#
# Name: lang
#
# Parameters: self - class reference
#             lang - content language (optional)
#
# Description:
#
#   This function either sets or returns the content language
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub lang {
    my ($self, $lang) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($lang) ) {
        $self->{"lang"} = $lang;
    }
    else {
        return($self->{"lang"});
    }
}

#********************************************************
#
# Name: type
#
# Parameters: self - class reference
#             type - content type (optional)
#
# Description:
#
#   This function either sets or returns the content type
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub type {
    my ($self, $type) = @_;

    #
    # Was a value supplied ?
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
# Name: url
#
# Parameters: self - class reference
#             url - data file url (optional)
#
# Description:
#
#   This function either sets or returns the data file url
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub url {
    my ($self, $url) = @_;

    #
    # Was a value supplied ?
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


