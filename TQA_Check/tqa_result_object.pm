#***********************************************************************
#
# Name: tqa_result_object.pm
#
# $Revision: 7491 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/TQA_Check/Tools/tqa_result_object.pm $
# $Date: 2016-02-08 08:39:51 -0500 (Mon, 08 Feb 2016) $
#
# Description:
#
#   This file defines an object to handle TQA results information
# (e.g. testcase, status, error message, source location, ...).
# The object contains methods to set and read the attributes.
#
# Public functions:
#     TQA_Result_Object_Debug
#
# Public variables
#    TQA_Result_Object_Maximum_Errors - maximum number of errors to report
#                                       per URL or file. Default is unlimited.
#
# Class Methods
#    new - create new object instance
#    column_no - source column number
#    description - testcase description
#    help_url - testcase help URL
#    impact - get/set impact
#    landmark - get/set landmark
#    landmark_marker - get/set landmark marker
#    line_no - source line number
#    message - test case message
#    page_no - source page number
#    source_line - source line
#    status - testcase status (pass/fail)
#    tags - get/set tags
#    testcase - testcase id
#    testcase_groups - testcase_groups list for testcase
#    url - URL of document
#    xpath - get/set tag xpath
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

package tqa_result_object;

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
    @EXPORT  = qw(TQA_Result_Object_Debug
                  $TQA_Result_Object_Maximum_Errors);
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my ($MAX_SOURCE_LINE_SIZE) = 200;

#
# Set maximum error count to 0, which means unlimited
#
my ($TQA_Result_Object_Maximum_Errors) = 0;

#********************************************************
#
# Name: TQA_Result_Object_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub TQA_Result_Object_Debug {
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
# Parameters: testcase - testcase identifier
#             status - testcase status (pass/fail)
#             description - testcase description
#             line_no - source line number
#             column_no - source column number
#             source_line - source line
#             message - test case message
#             url - URL of document
#
# Description:
#
#   This function creates a new tqa_result_object item and
# initializes it's data items.
#
#********************************************************
sub new {
    my ($class, $testcase, $status, $description, $line_no,
        $column_no, $source_line, $message, $url) = @_;
    
    my ($self) = {};
    my ($start_col);

    #
    # Bless the reference as a tqa_result_object class item
    #
    bless $self, $class;
    
    #
    # Save arguments as result object data items
    #
    $self->{"description"} = $description;
    $self->{"column_no"} = $column_no;
    $self->{"help_url"} = "";
    $self->{"impact"} = "";
    $self->{"landmark"} = "";
    $self->{"landmark_marker"} = "";
    $self->{"line_no"} = $line_no;
    $self->{"page_no"} = -1;
    $self->{"status"} = $status;
    $self->{"tags"} = "";
    $self->{"testcase"} = $testcase;
    $self->{"testcase_groups"} = "";
    $self->{"url"} = $url;
    $self->{"xpath"} = "";

    #
    # Check length of source line
    #
    if ( ! defined($source_line) ) {
        $self->{"source_line"} = "";
    }
    elsif ( length($source_line) < $MAX_SOURCE_LINE_SIZE ) {
        $self->{"source_line"} = $source_line;
    }
    elsif ( $column_no > length($source_line) ) {
        #
        # Source consists of start/end tag content only, while column
        # number is relative to the beginning of the entire line.
        # Take MAX_SOURCE_LINE_SIZE characters from the source
        # fragment.
        #
        $self->{"source_line"} = substr($source_line, 0,
                                        $MAX_SOURCE_LINE_SIZE);
    }
    else {
        #
        # Source line is too long, save the portion around the error
        # (column number)
        #
        if ( $column_no < $MAX_SOURCE_LINE_SIZE ) {
            if ( $column_no < 25 ) {
                $start_col = 0;
            }
            else {
                $start_col = 25;
            }
        }
        else {
            $start_col = $column_no - 50;
        }

        #
        # Get substring from source line
        #
        $self->{"source_line"} = substr($source_line, $start_col,
                                        $MAX_SOURCE_LINE_SIZE);
    }

    if ( defined($message) ) {
        $self->{"message"} = $message;
    }
    else {
          $self->{"message"} = "";
    }

    #
    # Print result object details
    #
    if ( $debug ) {
        print "New TQA Result object, testcase: " . $self->testcase ;
        print " status = " . $self->status . "\n";
        print " Description = " . $self->description . "\n";
        print " Line/column: " . $self->line_no . ":" . $self->column_no;
        print " message = " . $self->message . "\n";
    }
    
    #
    # Return reference to object.
    #
    return($self);
}
    
#********************************************************
#
# Name: column_no
#
# Parameters: self - class reference
#             column_no - column number (optional)
#
# Description:
#
#   This function either sets or returns the column_no
# attribute of the result object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub column_no {
    my ($self, $column_no) = @_;

    #
    # Was a column_no value supplied ?
    #
    if ( defined($column_no) ) {
        $self->{"column_no"} = $column_no;
    }
    else {
        return($self->{"column_no"});
    }
}

#********************************************************
#
# Name: description
#
# Parameters: self - class reference
#             description - testcase description (optional)
#
# Description:
#
#   This function either sets or returns the description
# attribute of the result object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub description {
    my ($self, $description) = @_;

    #
    # Was a description value supplied ?
    #
    if ( defined($description) ) {
        $self->{"description"} = $description;
    }
    else {
        return($self->{"description"});
    }
}

#********************************************************
#
# Name: help_url
#
# Parameters: self - class reference
#             help_url - URL of help page (optional)
#
# Description:
#
#   This function either sets or returns the help_url
# attribute of the result object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub help_url {
    my ($self, $help_url) = @_;

    #
    # Was a help_url value supplied ?
    #
    if ( defined($help_url) ) {
        $self->{"help_url"} = $help_url;
    }
    else {
        return($self->{"help_url"});
    }
}

#********************************************************
#
# Name: impact
#
# Parameters: self - class reference
#             impact - impact (optional)
#
# Description:
#
#   This function either sets or returns the impact
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub impact {
    my ($self, $impact) = @_;

    #
    # Was a impact value supplied ?
    #
    if ( defined($impact) ) {
        $self->{"impact"} = $impact;
    }
    else {
        return($self->{"impact"});
    }
}

#********************************************************
#
# Name: landmark
#
# Parameters: self - class reference
#             landmark - landmark name (optional)
#
# Description:
#
#   This function either sets or returns the landmark
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub landmark {
    my ($self, $landmark) = @_;

    #
    # Was a landmark value supplied ?
    #
    if ( defined($landmark) ) {
        $self->{"landmark"} = $landmark;
    }
    else {
        return($self->{"landmark"});
    }
}

#********************************************************
#
# Name: landmark_marker
#
# Parameters: self - class reference
#             landmark_marker - landmark marker (optional)
#
# Description:
#
#   This function either sets or returns the landmark
# marker attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub landmark_marker {
    my ($self, $landmark_marker) = @_;

    #
    # Was a landmark marker value supplied ?
    #
    if ( defined($landmark_marker) ) {
        $self->{"landmark_marker"} = $landmark_marker;
    }
    else {
        return($self->{"landmark_marker"});
    }
}

#********************************************************
#
# Name: line_no
#
# Parameters: self - class reference
#             line_no - line number (optional)
#
# Description:
#
#   This function either sets or returns the line_no
# attribute of the result object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub line_no {
    my ($self, $line_no) = @_;

    #
    # Was a line_no value supplied ?
    #
    if ( defined($line_no) ) {
        $self->{"line_no"} = $line_no;
    }
    else {
        return($self->{"line_no"});
    }
}

#********************************************************
#
# Name: page_no
#
# Parameters: self - class reference
#             page_no - page number (optional)
#
# Description:
#
#   This function either sets or returns the page_no
# attribute of the result object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub page_no {
    my ($self, $page_no) = @_;

    #
    # Was a page_no value supplied ?
    #
    if ( defined($page_no) ) {
        $self->{"page_no"} = $page_no;
    }
    else {
        return($self->{"page_no"});
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
# Name: source_line
#
# Parameters: self - class reference
#             source_line - source line (optional)
#
# Description:
#
#   This function either sets or returns the source_line
# attribute of the result object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub source_line {
    my ($self, $source_line) = @_;

    #
    # Was a source_line value supplied ?
    #
    if ( defined($source_line) ) {
        $self->{"source_line"} = $source_line;
    }
    else {
        return($self->{"source_line"});
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

#********************************************************
#
# Name: tags
#
# Parameters: self - class reference
#             tags - tags (optional)
#
# Description:
#
#   This function either sets or returns the tags
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub tags {
    my ($self, $tags) = @_;

    #
    # Was a tags value supplied ?
    #
    if ( defined($tags) ) {
        $self->{"tags"} = $tags;
    }
    else {
        return($self->{"tags"});
    }
}

#********************************************************
#
# Name: testcase
#
# Parameters: self - class reference
#             testcase - testcase id (optional)
#
# Description:
#
#   This function either sets or returns the testcase
# attribute of the result object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub testcase {
    my ($self, $testcase) = @_;

    #
    # Was a testcase value supplied ?
    #
    if ( defined($testcase) ) {
        $self->{"testcase"} = $testcase;
    }
    else {
        return($self->{"testcase"});
    }
}

#********************************************************
#
# Name: testcase_groups
#
# Parameters: self - class reference
#             testcase_groups - list of testcase groups (optional)
#
# Description:
#
#   This function either sets or returns the testcase_groups
# attribute of the result object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub testcase_groups {
    my ($self, $testcase_groups) = @_;

    #
    # Was a testcase_groups value supplied ?
    #
    if ( defined($testcase_groups) ) {

        #
        # Save contents
        #
        $self->{"testcase_groups"} = $testcase_groups;
    }
    else {
        return($self->{"testcase_groups"});
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
# attribute of the result object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
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

#********************************************************
#
# Name: xpath
#
# Parameters: self - class reference
#             path - path for tags (optional)
#
# Description:
#
#   This function either sets or returns the tag_path
# attribute of the object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub xpath {
    my ($self, $path) = @_;

    #
    # Was a path value supplied ?
    #
    if ( defined($path) ) {
        $self->{"xpath"} = $path;
    }
    else {
        return($self->{"xpath"});
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


