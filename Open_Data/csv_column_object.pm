#***********************************************************************
#
# Name: csv_column_object.pm
#
# $Revision: 888 $
# $URL: svn://10.36.148.185/Open_Data/Tools/csv_column_object.pm $
# $Date: 2018-07-09 10:53:57 -0400 (Mon, 09 Jul 2018) $
#
# Description:
#
#   This file defines an object to handle a CSV file column information
# (e.g. heading, content type, row counts). The object contains methods
# to set and read the object attributes.
#
# Public functions:
#     Set_CSV_Column_Object_Debug
#
# Class Methods
#    new - create new object instance
#    cleansed_value_table - get the cleansed value table
#    heading - get/set csv column heading
#    increment_non_blank_cell_count - increment non_blank_cell_count value
#    non_blank_cell_count - get/set non_blank_cell_count value
#    sum - get or add to the column sum (for numeric columns only)
#    type - get/set column content type value
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

package csv_column_object;

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
    @EXPORT  = qw(Set_CSV_Column_Object_Debug);
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
# Name: Set_CSV_Column_Object_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Set_CSV_Column_Object_Debug {
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
# Parameters: heading - column heading
#
# Description:
#
#   This function creates a new csv_column_object item and
# initializes its data items.
#
#********************************************************
sub new {
    my ($class, $heading) = @_;
    
    my ($self) = {};
    my (%cleansed_value_table);

    #
    # Bless the reference as a csv_column_object class item
    #
    bless $self, $class;
    
    #
    # Save arguments as object data items and initialize
    # other object data.
    #
    $self->{"cleansed_value_table"} = \%cleansed_value_table;
    $self->{"heading"} = $heading;
    $self->{"non_blank_cell_count"} = 0;
    $self->{"sum"} = 0;
    $self->{"type"} = "";
    
    #
    # Print object details
    #
    print "New CSV column object, Heading: $heading\n" if $debug;

    #
    # Return reference to object.
    #
    return($self);
}
    
#********************************************************
#
# Name: cleansed_value_table
#
# Parameters: self - class reference
#
# Description:
#
#   This function returns the address of the cleansed value
# table for this column object.
#
#********************************************************
sub cleansed_value_table {
    my ($self) = @_;

    #
    # Return address of hash table
    #
    return($self->{"cleansed_value_table"});
}

#********************************************************
#
# Name: heading
#
# Parameters: self - class reference
#             heading - column heading (optional)
#
# Description:
#
#   This function either sets or returns the heading
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub heading {
    my ($self, $heading) = @_;
   
    #
    # Was a value supplied ?
    #
    if ( defined($heading) ) {
        $self->{"heading"} = $heading;
    }
    else {
        return($self->{"heading"});
    }
}

#********************************************************
#
# Name: increment_non_blank_cell_count
#
# Parameters: self - class reference
#
# Description:
#
#   This function increments the non-blank cell
# count attribute of the object.
#
#********************************************************
sub increment_non_blank_cell_count {
    my ($self) = @_;

    #
    # Increment the value
    #
    $self->{"non_blank_cell_count"}++;
}


#********************************************************
#
# Name: non_blank_cell_count
#
# Parameters: self - class reference
#             non_blank_cell_count - cell count (optional)
#
# Description:
#
#   This function either sets or returns the non-blank cell
# count attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub non_blank_cell_count {
    my ($self, $non_blank_cell_count) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($non_blank_cell_count) ) {
        $self->{"non_blank_cell_count"} = $non_blank_cell_count;
    }
    else {
        return($self->{"non_blank_cell_count"});
    }
}

#********************************************************
#
# Name: sum
#
# Parameters: self - class reference
#             value - number (optional)
#
# Description:
#
#   This function either adds to the column sumation value
# or returns the column sum attribute of the object. This
# method only applies to numeric column types, if the type
# is not numeric, no action is taken.
# If a value is supplied, it is added to the current sum.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub sum {
    my ($self, $value) = @_;

    #
    # Is the column type numeric?
    #
    if ( $self->{"type"} eq "numeric" ) {
        #
        # Was a value supplied ?
        #
        if ( defined($value) ) {
            $self->{"sum"} += $value;
        }
        else {
            return($self->{"sum"});
        }
    }
    else {
        return(0);
    }
}

#********************************************************
#
# Name: type
#
# Parameters: self - class reference
#             type - column type (optional)
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

#***********************************************************************
#
# Mainline
#
#***********************************************************************

#
# Return true to indicate we loaded successfully
#
return 1;

