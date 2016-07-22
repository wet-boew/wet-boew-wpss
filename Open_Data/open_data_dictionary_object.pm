#***********************************************************************
#
# Name: open_data_dictionary_object.pm
#
# $Revision: 7618 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Open_Data/Tools/open_data_dictionary_object.pm $
# $Date: 2016-07-06 06:03:15 -0400 (Wed, 06 Jul 2016) $
#
# Description:
#
#   This file defines an object to handle Open Data dictionary information
# (e.g. label, description, type, pattern, etc). The object contains methods
# to set and read attributes.
#
# Public functions:
#     Open_Data_Dictionary_Object_Debug
#
# Class Methods
#    new - create new object instance
#    condition - get/set data condition value
#    regex - get/set data regex value
#    term - get/set term value
#
# Terms and Conditions of Use
# 
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is 
# distributed under the MIT License.
# 
# MIT License
# 
# Copyright (c) 2016 Government of Canada
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

package open_data_dictionary_object;

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
    @EXPORT  = qw(Open_Data_Dictionary_Object_Debug);
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
# Name: Open_Data_Dictionary_Object_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Open_Data_Dictionary_Object_Debug {
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
# Parameters: href - href of link
#             term - term for dictionary
#
# Description:
#
#   This function creates a new open_data_dictionary_object item and
# initializes its data items.
#
#********************************************************
sub new {
    my ($class, $term) = @_;
    
    my ($self) = {};

    #
    # Bless the reference as a open_data_dictionary_object class item
    #
    bless $self, $class;
    
    #
    # Save arguments as object fields
    #
    $self->{"term"} = $term;

    #
    # Initialize object fields
    #
    $self->{"condition"} = "";
    $self->{"regex"} = "";

    #
    # Print object details
    #
    print "New open data dictionary object, $term\n" if $debug;

    #
    # Return reference to object.
    #
    return($self);
}
    
#********************************************************
#
# Name: condition
#
# Parameters: self - class reference
#             value - value (optional)
#
# Description:
#
#   This function either sets or returns the condition
# attribute of the data dictionary object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub condition {
    my ($self, $value) = @_;

    #
    # Was a condition value supplied ?
    #
    if ( defined($value) ) {
        $self->{"condition"} = $value;
    }
    else {
        return($self->{"condition"});
    }
}

#********************************************************
#
# Name: regex
#
# Parameters: self - class reference
#             value - value (optional)
#
# Description:
#
#   This function either sets or returns the regex
# attribute of the data dictionary object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub regex {
    my ($self, $value) = @_;

    #
    # Was a regex value supplied ?
    #
    if ( defined($value) ) {
        $self->{"regex"} = $value;
    }
    else {
        return($self->{"regex"});
    }
}

#********************************************************
#
# Name: term
#
# Parameters: self - class reference
#             value - value (optional)
#
# Description:
#
#   This function either sets or returns the term
# attribute of the data dictionary object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub term {
    my ($self, $value) = @_;
   
    #
    # Was a term value supplied ?
    #
    if ( defined($value) ) {
        $self->{"term"} = $value;
    }
    else {
        return($self->{"term"});
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


