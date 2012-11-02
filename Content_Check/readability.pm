#***********************************************************************
#
# Name:   readability.pm
#
# $Revision: 5461 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Content_Check/Tools/readability.pm $
# $Date: 2011-09-08 10:35:23 -0400 (Thu, 08 Sep 2011) $
#
# Description:
#
#   This file contains routines that grade the readability of content.
#
# Fog index
#
# The Fog index, developed by Robert Gunning, is a well known
# and simple formula for measuring readability. The index indicates
# the number of years of formal education a reader of average
# intelligence would need to read the text once and understand
# that piece of writing with its word sentence workload.
#
#    18 unreadable
#    14 difficult
#    12 ideal
#    10 acceptable
#     8 childish
#
#
# Flesch-Kincaid grade score
#
# This score rates text on U.S. grade school level. So a score
# of 8.0 means that the document can be understood by an eighth
# grader. A score of 7.0 to 8.0 is considered to be optimal.
#
# Public functions:
#     Readability_Grade_HTML
#     Readability_Grade_Text
#     Set_Readability_Debug
#     Set_Readability_Content_End
#     Set_Readability_Content_Start
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

package readability;

use strict;
use HTML::Parser;
use File::Basename;
use Lingua::EN::Fathom;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Readability_Grade_HTML
                  Readability_Grade_Text
                  Set_Readability_Debug
                  Set_Readability_Content_End
                  Set_Readability_Content_Start
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (@paths, $this_path, $program_dir, $program_name, $paths);
my ($fathom_object);

#
# Minimum number of characters needed to analyse
#
my ($MINIMUM_INPUT_LENGTH) = 500;

#***********************************************************************
#
# Name: Set_Readability_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Readability_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: Analyse_Text
#
# Parameters: content - content
#
# Description:
#
#   This function writes the supplied content to a temporary file
# then analyses the content.  Once the analysis is complete the
# temporary file is removed.
#
# Returns
#   fog - Fog index for the text.
#   flesch_kincaid - Flesch-Kincaid grade level score for the text.
#
#***********************************************************************
sub Analyse_Text {
    my ($content) = @_;

    my ($temp_file_name);

    #
    # Get rid of non-ASCII characters
    #
    $content =~ s/[^[:ascii:]]+//g;

    #
    # Create temporary file for content.
    #
    print "Text to analyse = \n$content\n" if $debug;
    $temp_file_name = "temp_txt$$.txt";
    unlink($temp_file_name);
    open(TXT_FILE, "> $temp_file_name");
    print TXT_FILE $content;
    close(TXT_FILE);

    #
    # Do we need to create the Lingua::EN::Fathom handler ?
    # We only have to create it once and reuse it for all
    # analyses.
    #
    if ( ! defined($fathom_object) ) {
        $fathom_object = new Lingua::EN::Fathom;
    }

    #
    # Analyse the text in the file.
    #
    $fathom_object->analyse_file("$temp_file_name");

    #
    # Remove temporary file as we no longer need it.
    #
    unlink($temp_file_name);
}

#***********************************************************************
#
# Name: Readability_Grade_Text
#
# Parameters: content - content
#
# Description:
#
#   This function determines the readability level of a block of text.
# If there is insufficient text to analyse, this function returns -1 for
# both the fog and flesch-kincaid values.
#
# Returns
#   fog - Fog index for the text.
#   flesch_kincaid - Flesch-Kincaid grade level score for the text.
#
#***********************************************************************
sub Readability_Grade_Text {
    my ($content) = @_;

    #
    # Initial values for scores. A -1 value indicates no score.
    #
    my (%readability_scores);
    my ($fog, $flesch_kincaid) = (-1, -1);

    #
    # Is there enough text to analyse ?
    #
    if ( length($content) > $MINIMUM_INPUT_LENGTH ) {
        #
        # Analyse the text to compute readability metrics.
        #
        Analyse_Text($content);

        #
        # Get the Fog index value.
        #
        # The Fog index, developed by Robert Gunning, is a well known
        # and simple formula for measuring readability. The index indicates 
        # the number of years of formal education a reader of average 
        # intelligence would need to read the text once and understand 
        # that piece of writing with its word sentence workload.
        #
        #    18 unreadable
        #    14 difficult
        #    12 ideal
        #    10 acceptable
        #     8 childish
        #
        $fog = int($fathom_object->fog + 0.5);

        #
        # Get the Flesch-Kincaid grade score
        #
        # This score rates text on U.S. grade school level. So a score 
        # of 8.0 means that the document can be understood by an eighth 
        # grader. A score of 7.0 to 8.0 is considered to be optimal.
        #
        $flesch_kincaid = int($fathom_object->kincaid + 0.5);
    }
    else {
        print "Not enough content, length = " . length($content) . "\n" if $debug;
    }

    #
    # Return readability scores
    #
    print "Readability_Grade_Text Fog = $fog, Flesch-Kincaid = $flesch_kincaid\n" if $debug;
    $readability_scores{"Fog"} = $fog;
    $readability_scores{"Flesch-Kincaid"} = $flesch_kincaid;
    return(%readability_scores);
}

#***********************************************************************
#
# Name: Readability_Grade_HTML
#
# Parameters: content - content
#
# Description:
#
#   This function determines the readability level of text with 
# the content area of a text document.  The content area is delimited
# with marker comments.  If the content area cannot be located, or if
# there is insufficient text to analyse, this function returns -1 for
# both the fog and flesch-kincaid values.
#
# Returns
#   fog - Fog index for the text.
#   flesch_kincaid - Flesch-Kincaid grade level score for the text.
#
#***********************************************************************
sub Readability_Grade_HTML {
    my ($content) = @_;

    my ($content_text, %readability_scores);

    #
    # Extract the content area from the HTML.
    #
    $content_text = Extract_Content_From_HTML($content);

    #
    # Get readability grade level
    #
    %readability_scores = Readability_Grade_Text($content_text);

    #
    # Return readability scores
    #
    return(%readability_scores);
}

#***********************************************************************
#
# Name: Import_Packages
#
# Parameters: none
#
# Description:
#
#   This function imports any required packages that cannot
# be handled via use statements.
#
#***********************************************************************
sub Import_Packages {

    my ($package);
    my (@package_list) = ("crawler", "css_check", "image_details");

    #
    # Import packages, we don't use a 'use' statement as these packages
    # may not be in the INC path.
    #
    foreach $package (@package_list) {
        #
        # Import the package routines.
        #
        if ( ! defined($INC{$package}) ) {
            require "$package.pm";
        }
        $package->import();
    }
}

#***********************************************************************
#
# Mainline
#
#***********************************************************************

#
# Get our program directory, where we find supporting files
#
$program_dir  = dirname($0);
$program_name = basename($0);

#
# If directory is '.', search the PATH to see where we were found
#
if ( $program_dir eq "." ) {
    $paths = $ENV{"PATH"};
    @paths = split( /:/, $paths );

    #
    # Loop through path until we find ourselves
    #
    foreach $this_path (@paths) {
        if ( -x "$this_path/$program_name" ) {
            $program_dir = $this_path;
            last;
        }
    }
}

#
# Import required packages
#
#Import_Packages;

#
# Return true to indicate we loaded successfully
#
return 1;

