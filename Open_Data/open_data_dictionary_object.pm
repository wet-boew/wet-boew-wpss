#***********************************************************************
#
# Name: open_data_dictionary_object.pm
#
# $Revision: 1886 $
# $URL: svn://10.36.148.185/WPSS_Tool/Open_Data/Tools/open_data_dictionary_object.pm $
# $Date: 2020-12-16 11:33:14 -0500 (Wed, 16 Dec 2020) $
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
#    get_consistent_data_headings - returns list of consistent
#      data value headings.
#    id - get/set the id value
#    in_dictionary - get/set the in dictionary value
#    regex - get/set data regex value
#    related_resource - get/set related resource value
#    set_consistent_data_heading - set headings that require consistent
#      data value pairs with this heading.
#    type - get/set the type value
#    term - get/set term value
#    term_lang - get/set term language value
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
#
# Description:
#
#   This function creates a new open_data_dictionary_object item and
# initializes its data items. Object attributes are:
#    condition - conditions for CVS data cells.
#    id - id value from the XML data dictionary for this term
#    in_dictionary - flag to indicate if the term is in a dictionary.
#    regex - regular expression to be applied to data values
#    related_resource - related resources such as controlled vocabularies
#    term - dictionary term
#    type - data type of values (e.g. numeric, date, text, etc.)
#
#********************************************************
sub new {
    my ($class) = @_;
    
    my ($self) = {};
    my (%consistent_data_headings);

    #
    # Bless the reference as a open_data_dictionary_object class item
    #
    bless $self, $class;

    #
    # Initialize object fields
    #
    $self->{"condition"} = "";
    $self->{"consistent_data_heading"} = \%consistent_data_headings;
    $self->{"id"} = "";
    $self->{"in_dictionary"} = 1;
    $self->{"regex"} = "";
    $self->{"related_resource"} = "";
    $self->{"term"} = "";
    $self->{"term_lang"} = "";
    $self->{"type"} = "";
    
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
# Name: get_consistent_data_headings
#
# Parameters: self - class reference
#
# Description:
#
#   This function returns the list of headings must have
# consistent data values with this heading.
#
#********************************************************
sub get_consistent_data_headings {
    my ($self) = @_;

    my (@headings_list, $table_addr);

    #
    # Return the list of headings
    #
    $table_addr = $self->{"consistent_data_heading"};
    @headings_list = keys(%$table_addr);
    return(@headings_list);
}

#********************************************************
#
# Name: id
#
# Parameters: self - class reference
#             value - value (optional)
#
# Description:
#
#   This function either sets or returns the id
# attribute of the data dictionary object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub id {
    my ($self, $value) = @_;

    #
    # Was an id value supplied ?
    #
    if ( defined($value) ) {
        $self->{"id"} = $value;
    }
    else {
        return($self->{"id"});
    }
}

#********************************************************
#
# Name: in_dictionary
#
# Parameters: self - class reference
#             value - value (optional)
#
# Description:
#
#   This function either sets or returns the in_dictionary
# attribute of the data dictionary object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub in_dictionary {
    my ($self, $value) = @_;

    #
    # Was an in_dictionary value supplied ?
    #
    if ( defined($value) ) {
        $self->{"in_dictionary"} = $value;
    }
    else {
        return($self->{"in_dictionary"});
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
# Name: related_resource
#
# Parameters: self - class reference
#             value - value (optional)
#
# Description:
#
#   This function either sets or returns the related_resource
# attribute of the data dictionary object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub related_resource {
    my ($self, $value) = @_;

    #
    # Was a regex related_resource supplied ?
    #
    if ( defined($value) ) {
        $self->{"related_resource"} = $value;
    }
    else {
        return($self->{"related_resource"});
    }
}

#********************************************************
#
# Name: set_consistent_data_heading
#
# Parameters: self - class reference
#             value - list of headings
#
# Description:
#
#   This function sets a list of headings that this
# heading must have consistent data values with.
#
#********************************************************
sub set_consistent_data_heading {
    my ($self, $value) = @_;

    my ($table_addr, @headings_list);

    #
    # Was a heading list supplied ?
    #
    if ( defined($value) && ($value ne "") ) {
        $table_addr = $self->{"consistent_data_heading"};
        $$table_addr{$value} = 1;
        @headings_list = keys(%$table_addr);
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

#********************************************************
#
# Name: term_lang
#
# Parameters: self - class reference
#             value - value (optional)
#
# Description:
#
#   This function either sets or returns the term_lang
# attribute of the data dictionary object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub term_lang {
    my ($self, $value) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $self->{"term_lang"} = $value;
    }
    else {
        return($self->{"term_lang"});
    }
}

#********************************************************
#
# Name: type
#
# Parameters: self - class reference
#             value - value (optional)
#
# Description:
#
#   This function either sets or returns the type
# attribute of the data dictionary object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub type {
    my ($self, $value) = @_;

    #
    # Was a type value supplied ?
    #
    if ( defined($value) ) {
        $self->{"type"} = $value;
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


