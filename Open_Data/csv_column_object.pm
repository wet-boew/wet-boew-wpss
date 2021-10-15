#***********************************************************************
#
# Name: csv_column_object.pm
#
# $Revision: 1940 $
# $URL: svn://10.36.148.185/WPSS_Tool/Open_Data/Tools/csv_column_object.pm $
# $Date: 2021-02-10 13:06:40 -0500 (Wed, 10 Feb 2021) $
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
#    check_consistent_value - check for consistent values
#    dictionary_object - set/get data dictionary object value
#    first_data - set/get the first data cell value
#    get_data_type_details - get the details for a specific data type
#    get_data_types_list - get the list of data types
#    heading - get/set csv column heading
#    increment_data_type_count - increment count of cells containing a
#      specific data type (e.g. numeric, date, text, etc.)
#    increment_non_blank_cell_count - increment non_blank_cell_count value
#    max - get/set maximum value (for numeric and date columns only)
#    min - get/set minimum value (for numeric and date columns only)
#    non_blank_cell_count - get/set non_blank_cell_count value
#    sum - get or add to the column sum (for numeric and date columns only)
#    type - get/set column content type value
#    valid_heading - get/set flag if this column has a valid
#      data dictionary heading
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
use utf8;
use Unicode::Normalize;

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
my ($MIN_DATA_LENGTH) = 10;
my ($MAX_DATA_LENGTH) = 100;

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

#***********************************************************************
#
# Name: Cleanse_Value
#
# Parameters: data - a string
#
# Description:
#
#   This function cleanses a string by
#    - removing punctuation
#    - converting the string to lower case
#    - remove pluralization (i.e. trailing s in words)
#    - removing white space
#  Cleansed strings are used to detect inconsistent presentations of
# otherwise identical values.  If a cleansed string has fewer than 10
# or greater than 100 characters, an empty string is returned.  Strings
# that are shorter or longer than these limits are not likely to be
# proper names or values from a controlled vocabulary.  By returning
# an empty string, further checking of these strings can be avoided
# (to avoid storage and performance problems).
#
#***********************************************************************
sub Cleanse_Value {
    my ($data) =@_;

    #
    # Remove punctuation characters that
    #  - follows a letter or whitespace
    #  - preceeds a letter or whitespace
    #
    $data =~ s/([a-z\s])[[:punct:]]/$1/gi;
    $data =~ s/[[:punct:]]([a-z\s])/$1/gi;

    #
    # Convert to lower case
    #
    $data = lc($data);
    
    #
    # Replace accented characters with unaccented equivalents.
    # The function NFKD returns the Normalization Form KD (formed by
    # compatibility decomposition) of the string. The substitution that
    # follows removes any accent symbols (diacritical marks).
    #
    $data = NFKD($data);
    $data =~ s/\p{NonspacingMark}//g;

    #
    # Remove trailing 's' characters (pluralisation)
    #
    $data .= " ";
    $data =~ s/s\s/ /g;

    #
    # Remove all whitespace characters
    #
    $data =~ s/\s+//g;

    #
    # Is the cleansed string too short or too long?
    #
    if ( (length($data) < $MIN_DATA_LENGTH) || (length($data) > $MAX_DATA_LENGTH) ) {
        $data = "";
    }

    #
    # Return the cleansed string
    #
    return($data);
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
    my (%consistent_value_table, %data_type_count, %data_type_line);
    my (%data_type_data, %multi_cell_consistent_value_table);
    my (%consistent_multi_cell_value_table);

    #
    # Bless the reference as a csv_column_object class item
    #
    bless $self, $class;
    
    #
    # Save arguments as object data items and initialize
    # other object data.
    #
    $self->{"consistent_multi_cell_value_table"} = \%consistent_multi_cell_value_table;
    $self->{"consistent_value_table"} = \%consistent_value_table;
    $self->{"data_type_count"} = \%data_type_count;
    $self->{"data_type_data"} = \%data_type_data;
    $self->{"data_type_line"} = \%data_type_line;
    $self->{"dictionary_object"} = undef;
    $self->{"first_data"} = 1;
    $self->{"heading"} = $heading;
    $self->{"max"} = undef;
    $self->{"min"} = undef;
    $self->{"multi_cell_consistent_value_table"} = \%multi_cell_consistent_value_table;
    $self->{"non_blank_cell_count"} = 0;
    $self->{"sum"} = 0;
    $self->{"type"} = "";
    $self->{"valid_heading"} = 1;
    
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
# Name: check_consistent_multi_cell_value
#
# Parameters: self - class reference
#             data - data value to check
#             line_no - line number for this data
#             other_heading - other column heading label
#             other_data - other column's data value
#
# Description:
#
#   This function checks to see if the data values passed
# for 2 columns contain a consistent values.  The values
# is converted to lowercase to check it against previous
# data values. If the lowercase values match but the original
# values do not match, the values are deemed inconsistent.
#
#********************************************************
sub check_consistent_multi_cell_value {
    my ($self, $data, $line_no, $other_heading, $other_data) = @_;

    my ($table_addr, $key, $col_table_addr, %col_table);
    my ($lc_data, $lc_other_data);
    my ($first_line, $first_data, $first_other_data);
    my ($match) = 1;

    #
    # Is the length of the 2 data values less than the maximum?
    #
    if ( (length($data) + length($other_data)) < $MAX_DATA_LENGTH  ) {
        #
        # Get table for multi-column values
        #
        $table_addr = $self->{"consistent_multi_cell_value_table"};
        
        #
        # Generate key by concatenating the 2 column headings
        #
        $key = $self->{"heading"} . "\n$other_heading";
        
        #
        # Remove newlines and convert data to lower case.
        #
        $data =~ s/\n/ /g;
        $other_data =~ s/\n/ /g;
        $lc_data = lc($data);
        $lc_other_data = lc($other_data);

        #
        # Do we have a table for this column combination?
        #
        if ( defined($$table_addr{$key}) ) {
            #
            # Get the table for this column combination
            #
            $col_table_addr = $$table_addr{$key};
            
            #
            # Do we have an entry for this data pair?
            #
            if ( defined($$col_table_addr{$lc_data}) ) {
                ($first_line, $first_data, $first_other_data) = split(/\n/, $$col_table_addr{$lc_data}, 3);

                #
                # Do the mixed case values match?
                #
                if ( $data ne $first_data ) {
                    print "Mismatch in first field \"$data\" versus \"$first_data\"\n" if $debug;
                    $match = 0;
                }
                elsif ( $other_data ne $first_other_data ) {
                    print "Mismatch in second field \"$other_data\" versus \"$first_other_data\"\n" if $debug;
                    $match = 0;
                }
            }
            else {
                #
                # Add table entry for this data pair
                #
                $$col_table_addr{$lc_data} = "$line_no\n$data\n$other_data";
            }
        }
        else {
            #
            # Create a table for this column pair and save the
            # data values and line number.
            #
            print "New column combination table table\n" if $debug;
            $$table_addr{$key} = \%col_table;
            $col_table{$lc_data} = "$line_no\n$data\n$other_data";
        }
    }

    #
    # Return status and initial data values and line number
    #
    return($match, $first_data, $first_other_data, $first_line);
}

#********************************************************
#
# Name: check_consistent_value
#
# Parameters: self - class reference
#             data - data value to check
#             line_no - line number for this data
#
# Description:
#
#   This function checks to see if the data value passed
# contains a consistent value.  The value is stripped of
# punctuation, pluralizations and whitespace and converted
# to lowercase to check it against previous data values.
# If the stripped version match but the original versions
# do not match, the values are deemed inconsistent.
#
#********************************************************
sub check_consistent_value {
    my ($self, $data, $line_no) = @_;

    my ($cleansed_value, $table_addr, $other_data, $lc_data);
    my ($match) = 1;
    my ($other_line_no) = -1;
    
    #
    # Did we get a data value?
    #
    if ( defined($data) ) {
        #
        # Cleanse the value to remove punctuation, pluralizations
        # and whitespace.
        #
        $cleansed_value = Cleanse_Value($data);
        $table_addr = $self->{"consistent_value_table"};

        #
        # Did we get a cleansed value? We won't get one if the data
        # is either too long or too short.
        #
        if ( $cleansed_value ne "" ) {
            #
            # Does this cleansed value appear in the table?
            #
            print "Cleansed value is \"$cleansed_value\"\n" if $debug;
            if ( defined($$table_addr{$cleansed_value}) ) {
                #
                # Get the uncleansed values and line number
                #
                ($other_line_no, $other_data) = split(/:/, $$table_addr{$cleansed_value}, 2);

                #
                # Do the uncleansed values match?
                #
                if ( $data ne $other_data ) {
                    $match = 0;
                }
            }
            else {
                #
                # Save this cleansed value in the table.
                # Include the row number in the value.
                #
                print "New value for consistent value table\n" if $debug;
                $$table_addr{$cleansed_value} = "$line_no:$data";
            }
        }
        #
        # Is the value short (i.e. less than MIN_DATA_LENGTH)?
        # If so we only check case of value.
        #
        elsif ( length($data) < $MIN_DATA_LENGTH ) {
            #
            # Get lowercase value for data
            #
            $lc_data = lc($data);
            print "Lower case value is \"$lc_data\"\n" if $debug;

            #
            # Does this lowercase value appear in the table?
            #
            if ( defined($$table_addr{$lc_data}) ) {
                #
                # Get the mixed case values and line number
                #
                ($other_line_no, $other_data) = split(/:/, $$table_addr{$lc_data}, 2);

                #
                # Do the mixed case values match?
                #
                if ( $data ne $other_data ) {
                    $match = 0;
                }
            }
            else {
                #
                # Save this lowercase value in the table.
                # Include the row number in the value.
                #
                print "New value for consistent value table\n" if $debug;
                $$table_addr{$lc_data} = "$line_no:$data";
            }
        }
    }
    
    #
    # Return status and initial data value and line number
    #
    return($match, $other_data, $other_line_no);
}

#********************************************************
#
# Name: consistent_multi_cell_value_table
#
# Parameters: self - class reference
#             label - the combined header labels for the cells
#
# Description:
#
#   This function returns the address of the consistent value
# table for a set of cells.  The set is identified by the
# combined header label.
#
#********************************************************
sub consistent_multi_cell_value_table {
    my ($self, $label) = @_;
    
    my ($table_addr);

    #
    # Was a label supplied ?
    #
    if ( defined($label) ) {
        #
        # Get addresses of the multi-cell consistent value table
        #
        $table_addr = $self->{"multi_cell_consistent_value_table"};
        
        #
        # Do we have an entry for this label?
        #
        if ( defined($$table_addr{$label}) ) {
        }
    }
}

#********************************************************
#
# Name: dictionary_object
#
# Parameters: self - class reference
#             value - value (optional)
#
# Description:
#
#   This function either sets or returns the dictionary_object
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub dictionary_object {
    my ($self, $value) = @_;
   
    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $self->{"dictionary_object"} = $value;
    }
    else {
        return($self->{"dictionary_object"});
    }
}

#********************************************************
#
# Name: first_data
#
# Parameters: self - class reference
#             value - value (optional)
#
# Description:
#
#   This function either sets or returns the first_data
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub first_data {
    my ($self, $value) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $self->{"first_data"} = $value;
    }
    else {
        return($self->{"first_data"});
    }
}

#********************************************************
#
# Name: get_data_type_details
#
# Parameters: self - class reference
#             data_type - data type (e.g. numeric, date, text)
#
# Description:
#
#   This function returns the details for the specified
# data type.  The details are the count of occurances, the
# first line the data type first_data
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub get_data_type_details {
    my ($self, $data_type) = @_;
    
    my ($count_addr, $data_addr, $line_addr);
    my ($count, $data, $line) = (0, "", -1);

    #
    # Was a data type supplied ?
    #
    if ( defined($data_type) ) {
        #
        # Get addresses of the data type hash tables
        #
        $count_addr = $self->{"data_type_count"};
        $data_addr = $self->{"data_type_data"};
        $line_addr = $self->{"data_type_line"};
        
        #
        # Do we have this data type?
        #
        if ( defined($$count_addr{$data_type}) ) {
            $count = $$count_addr{$data_type};
            $data = $$data_addr{$data_type};
            $line = $$line_addr{$data_type};
        }
    }

    #
    # Return the details
    #
    return($count, $data, $line);
}

#********************************************************
#
# Name: get_data_types_list
#
# Parameters: self - class reference
#
# Description:
#
#   This function returns the list of data types for
# the column object.
#
#********************************************************
sub get_data_types_list {
    my ($self) = @_;

    my (@data_types, $count_addr);

    #
    # Get the list of data types, the keys of the data_type_count
    # hash table
    #
    $count_addr = $self->{"data_type_count"};
    @data_types = keys(%$count_addr);

    #
    # Return the lost of types
    #
    return(@data_types);
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
# Name: increment_data_type_count
#
# Parameters: self - class reference
#             data_type - data type (e.g. numeric, date, text)
#             value - the value of the data
#             line - the row or line number of the data
#
# Description:
#
#   This function increments the count of cells for a
# specified data type.  If there is no count, the count
# is set to 1 and the data value and line number are recorded
# as the first instance of the data type.
#
#********************************************************
sub increment_data_type_count {
    my ($self, $data_type, $value, $line) = @_;

    my ($count_addr, $data_addr, $line_addr);

    #
    # Was a data type supplied ?
    #
    if ( defined($data_type) ) {
        #
        # Get addresses of the data type hash tables
        #
        $count_addr = $self->{"data_type_count"};
        $data_addr = $self->{"data_type_data"};
        $line_addr = $self->{"data_type_line"};

        #
        # Is this the first instance for this data type?
        #
        if ( ! defined($$count_addr{$data_type}) ) {
            $$count_addr{$data_type} = 1;
            $$data_addr{$data_type} = $value;
            $$line_addr{$data_type} = $line;
        }
        else {
            #
            # Increment the count for this data type
            #
            $$count_addr{$data_type}++;
        }
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
# Name: max
#
# Parameters: self - class reference
#             value - cell value (optional)
#
# Description:
#
#   This function either sets or returns the maximum column
# value attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub max {
    my ($self, $value) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $self->{"max"} = $value;
    }
    else {
        return($self->{"max"});
    }
}

#********************************************************
#
# Name: min
#
# Parameters: self - class reference
#             value - cell value (optional)
#
# Description:
#
#   This function either sets or returns the minimum column
# value attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub min {
    my ($self, $value) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $self->{"min"} = $value;
    }
    else {
        return($self->{"min"});
    }
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

#********************************************************
#
# Name: valid_heading
#
# Parameters: self - class reference
#             value - value (optional)
#
# Description:
#
#   This function either sets or returns the valid_heading
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub valid_heading {
    my ($self, $value) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $self->{"valid_heading"} = $value;
    }
    else {
        return($self->{"valid_heading"});
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

