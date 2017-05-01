#***********************************************************************
#
# Name: epub_opf_object.pm
#
# $Revision: 358 $
# $URL: svn://10.36.20.203/TQA_Check/Tools/epub_opf_object.pm $
# $Date: 2017-04-28 10:49:15 -0400 (Fri, 28 Apr 2017) $
#
# Description:
#
#   This file defines an object to handle an EPUB OPF file information
# (e.g. version). The object contains methods to set and read the
# object attributes.
#
# Public functions:
#     Set_EPUB_OPF_Object_Debug
#
# Class Methods
#    new - create new object instance
#    add_to_manifest - add an item object to the manifest list
#    identifier - get/set the EPUB identifier
#    language - get/set the EPUB file content language
#    manifest - get/set the list of files in the EPUB manifest
#    title - get/set the EPUB file title
#    version - get/set the EPUB file version
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

package epub_opf_object;

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
    @EXPORT  = qw(Set_EPUB_OPF_Object_Debug);
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
# Name: Set_EPUB_OPF_Object_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Set_EPUB_OPF_Object_Debug {
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
# Parameters: filename - name of EPUB opf file
#             directory - path of directory for the EPUB file
#
# Description:
#
#   This function creates a new epub_opf_object item and
# initializes its data items.
#
#********************************************************
sub new {
    my ($class, $filename, $directory) = @_;

    my ($self) = {};
    my (@empty_list);

    #
    # Bless the reference as a epub_opf_object class item
    #
    bless $self, $class;

    #
    # Save arguments as object data items
    #
    $self->{"filename"} = $filename;
    $self->{"directory"} = $directory;

    #
    # Initialize other object properties
    #
    $self->{"identifier"} = "";
    $self->{"language"} = "";
    $self->{"manifest"} = \@empty_list;
    $self->{"title"} = "";
    $self->{"version"} = "";

    #
    # Print object details
    #
    print "New EPUB OPF object, file name $filename\n" if $debug;

    #
    # Return reference to object.
    #
    return($self);
}

#********************************************************
#
# Name: add_to_manifest
#
# Parameters: self - class reference
#             item - EPUB item object
#
# Description:
#
#   This function adds an item object to the manifest list.
#
#********************************************************
sub add_to_manifest {
    my ($self, $item) = @_;
    
    my ($addr);

    #
    # Was a value supplied ?
    #
    if ( defined($item) ) {
        print "Add item to manifest array\n" if $debug;
        $addr = $self->{"manifest"};
        push(@$addr, $item);
    }
}

#********************************************************
#
# Name: identifier
#
# Parameters: self - class reference
#             identifier - EPUB file identifier (optional)
#
# Description:
#
#   This function either sets or returns the EPUB identifier
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub identifier {
    my ($self, $identifier) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($identifier) ) {
        $self->{"identifier"} = $identifier;
    }
    else {
        return($self->{"identifier"});
    }
}

#********************************************************
#
# Name: language
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
sub language {
    my ($self, $lang) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($lang) ) {
        $self->{"language"} = $lang;
    }
    else {
        return($self->{"language"});
    }
}

#********************************************************
#
# Name: manifest
#
# Parameters: self - class reference
#             manifest - list of epub manifest objects (optional)
#
# Description:
#
#   This function either sets or returns the address of
# a list of manifest file objects attribute of the object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub manifest {
    my ($self, $manifest) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($manifest) ) {
        $self->{"manifest"} = $manifest;
    }
    else {
        return($self->{"manifest"});
    }
}

#********************************************************
#
# Name: title
#
# Parameters: self - class reference
#             title - file title (optional)
#
# Description:
#
#   This function either sets or returns the file title
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub title {
    my ($self, $title) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($title) ) {
        $self->{"title"} = $title;
    }
    else {
        return($self->{"title"});
    }
}

#********************************************************
#
# Name: version
#
# Parameters: self - class reference
#             version - epub version (optional)
#
# Description:
#
#   This function either sets or returns the EPUB version
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub version {
    my ($self, $version) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($version) ) {
        $self->{"version"} = $version;
    }
    else {
        return($self->{"version"});
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


