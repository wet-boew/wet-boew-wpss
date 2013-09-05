#***********************************************************************
#
# Name: testcase_data_object.pm
#
# $Revision: 6302 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/CLF_Check/Tools/testcase_data_object.pm $
# $Date: 2013-06-25 14:08:36 -0400 (Tue, 25 Jun 2013) $
#
# Description:
#
#   This file defines an object to handle testcase data information. It
# provides methods to add/set/get field values.  The object can store
# fields of the following types
#    scalar
#    array
#    hash
#
# Public functions:
#     Testcase_Data_Object_Debug
#
# Class Methods
#    new - create new object instance
#    add_field - add a new data field
#    get_field - get field value
#    has_field - check if object has a named field
#    set_scalar_field - set scalar field value
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

package testcase_data_object;

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
    @EXPORT  = qw(Testcase_Data_Object_Debug);
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
# Name: Testcase_Data_Object_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Testcase_Data_Object_Debug {
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
# Parameters: none
#
# Description:
#
#   This function creates a new testcase_data object item and
# initializes its data items.
#
#********************************************************
sub new {
    my ($class) = @_;
    
    my ($self) = {};
    my (%field_types);

    #
    # Bless the reference as a testcase_data_object class item
    #
    bless $self, $class;
    $self->{"field_types"} = \%field_types;
    print "New testcase_data_object\n" if $debug;

    #
    # Return reference to object.
    #
    return($self);
}
    
#********************************************************
#
# Name: add_field
#
# Parameters: self - class reference
#             name - field name
#             type - field type
#
# Description:
#
#   This function adds a new field to the testcase_data object.
#
#********************************************************
sub add_field {
    my ($self, $name, $type) = @_;
    
    my ($field_types);
    
    #
    # Do we already have a field with this name ?
    #
    if ( defined($self->{"$name"}) ) {
        print "Error, duplicate testcase_data_object field name $name\n";
        exit(1);
    }
    #
    # Do we want a scalar ?
    #
    elsif ( $type eq "scalar" ) {
        $self->{"$name"} = "";
    }
    #
    # Do we want an array ?
    #
    elsif ( $type eq "array" ) {
        my (@array);
        $self->{"$name"} = \@array;
    }
    #
    # Do we want a hash ?
    #
    elsif ( $type eq "hash" ) {
        my (%hash);
        $self->{"$name"} = \%hash;
    }
    #
    # Unknown type
    #
    else {
        print "Error, Unknown type $type in testcase_data_object->add_field\n";
        exit(1);
    }
    
    #
    # Set field type
    #
    $field_types = $self->{"field_types"};
    $$field_types{"$name"} = $type;
    print "Add field $name, type = $type to testcase_data_object\n" if $debug;
    
    #
    # Return the field
    #
    return($self->{"$name"});
}

#********************************************************
#
# Name: get_field
#
# Parameters: self - class reference
#             name - field name
#
# Description:
#
#   This function returns the value of the named field.
#
#********************************************************
sub get_field {
    my ($self, $name) = @_;
   
    #
    # Do we have a field with this name ?
    #
    if ( defined($self->{"$name"}) ) {
        print "Get field $name from testcase_data_object\n" if $debug;
        return($self->{"$name"});
    }
    else {
        print "Error, unknown field name $name\n" if $debug;
        return;
    }
}

#********************************************************
#
# Name: has_field
#
# Parameters: self - class reference
#             name - field name
#
# Description:
#
#   This function returns true of false whether the object has
# the field.
#
#********************************************************
sub has_field {
    my ($self, $name) = @_;

    #
    # Do we have a field with this name ?
    #
    if ( defined($self->{"$name"}) ) {
        return(1);
    }
    else {
        return(0);
    }
}

#********************************************************
#
# Name: set_scalar_field
#
# Parameters: self - class reference
#             name - field name
#             value - new value
#
# Description:
#
#   This function sets the value for scalar field types.
#
#********************************************************
sub set_scalar_field {
    my ($self, $name, $value) = @_;
    
    my ($field_types, $type);
    
    #
    # Do we have a field with this name ?
    #
    if ( defined($self->{"$name"}) ) {
        #
        # Get field types
        #
        $field_types = $self->{"field_types"};
        $type = $$field_types{"$name"};
        
        #
        # Is this a scalar field type ?
        #
        if ( $type eq "scalar" ) {
            $self->{"$name"} = $value;
            print "Set field $name vale $value\n" if $debug;
        }
        else {
            print "Error, Field $name is not of type scalar ($type)\n";
        }
    }
    else {
        print "Error, unknown field name $name\n" if $debug;
        return;
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


