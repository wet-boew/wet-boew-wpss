#***********************************************************************
#
# Name: content_sections.pm
#
# $Revision: 6303 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Content_Check/Tools/content_sections.pm $
# $Date: 2013-06-25 14:14:21 -0400 (Tue, 25 Jun 2013) $
#
# Description:
#
#   This file defines an object to handle HTML content sections
# (e.g. navigation, content) and subsections (e.g. breadcrumb,
# left navigation). The object contains methods to detect
# content section/subsection start and end.
#
# Public functions:
#     Content_Section_Debug
#     Content_Section_Markers
#     Content_Section_Names
#     Content_Subsection_Names
#
# Class Methods
#    new - create new object instance
#    check_start_tag - checks class, id or role in start tags
#    check_end_tag - checks for section end tags
#    in_content_section - get value of 'inside section' flag
#    in_content_subsection - get value of 'inside subsection' flag
#    current_content_section - get name of current content section
#    current_content_subsection - get name of current content subsection
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

package content_sections;

use strict;
use warnings;
use File::Basename;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Content_Section_Debug
                  Content_Section_Markers
                  Content_Section_Names
                  Content_Subsection_Names
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
my (%subsection_markers, %section_subsection_list);
my (%subsection_name_list, %section_name_list, %section_subsection_map);

#********************************************************
#
# Name: Content_Section_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Content_Section_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;

    #
    # Set debug in supporting modules
    #
    Content_Section_Object_Debug($this_debug);
}

#********************************************************
#
# Name: Content_Section_Names
#
# Parameters: none
#
# Description:
#
#   This function returns the list of content section names.
#
#********************************************************
sub Content_Section_Names {

    #
    # Return list of names
    #
    return(keys(%section_subsection_list));
}

#********************************************************
#
# Name: Content_Subsection_Names
#
# Parameters: section - name of section
#
# Description:
#
#   This function returns the list of content subsection names
# that are part of the named section.
#
#********************************************************
sub Content_Subsection_Names {
    my ($section) = @_;

    my ($section_list);

    #
    # Return list of names
    #
    if ( defined($section_subsection_list{$section}) ) {
        $section_list = $section_subsection_list{$section};
        return(@$section_list);
    }
    else {
        return();
    }
}

#***********************************************************************
#
# Name: Content_Section_Marker
#
# Parameters: section - section name
#             subsection - subsection name
#             marker - marker value
#
# Description:
#
#   This function copies the supplied list of section marker objects
# into a global variable.  
#
#***********************************************************************
sub Content_Section_Markers {
    my ($section, $subsection, $marker) = @_;

    my ($section_object, $section_list);

    #
    # Do we have a valid content section marker ?
    #
    if ( ((! defined($section)) || ($section =~ /^\s*$/)) ||
         ((! defined($subsection)) || ($subsection =~ /^\s*$/)) ||
         ((! defined($marker)) || ($marker =~ /^\s*$/)) ) {
        print "Invalid content section marker\n" if $debug;
        return;
    }

    #
    # If we already have this marker, ignore it.
    #
    print "Content_Section_Markers section = $section, subsection = $subsection, marker = $marker\n" if $debug;
    if ( ! defined($subsection_markers{$marker}) ) {
        #
        # Create a new content section object.
        #
        $section_object = content_section_object->new($section, $subsection,
                                                      $marker);

        #
        # Save section marker in a hash table for easier access
        #
        $subsection_markers{$marker} = $section_object;

        #
        # Save subsection name in a list
        #
        $subsection_name_list{$subsection} = $subsection;

        #
        # Save subsection in a section specific list
        #
        if ( ! defined($section_subsection_list{$section}) ) {
            $section_name_list{$section} = $section;
            my (@section_list_array);
            $section_subsection_list{$section} = \@section_list_array;
        }
        $section_list = $section_subsection_list{$section};
        if ( ! defined($section_subsection_map{"$section:$subsection"}) ) {
            print "Add subsection $subsection to section list $section\n" if $debug;
            push (@$section_list, $subsection);
        }
        $section_subsection_map{"$section:$subsection"} = "$section:$subsection";
    }
}

#********************************************************
#
# Name: new
#
# Parameters: none
#
# Description:
#
#   This function creates a new content_sections item and
# initializes its data items.
#
#********************************************************
sub new {
    my ($class)= @_;
    
    my ($self) = {};
    my (@content_subsection_stack, %subsection_tag_name, %subsection_tag_count);
    my ($subsection, %inside_subsection, %inside_section, $section);

    #
    # Bless the reference as a content_sections class item
    #
    bless $self, $class;

    #
    # Initialize other object variables
    #
    $self->{"subsection_tag_name"} = \%subsection_tag_name;
    $self->{"subsection_tag_count"} = \%subsection_tag_count;
    $self->{"inside_subsection"} = \%inside_subsection;
    $self->{"inside_section"} = \%inside_section;
    $self->{"current_content_section"} = "";
    $self->{"current_content_subsection"} = "";
    $self->{"content_subsection_stack"} = \@content_subsection_stack;

    #
    # Initialize subsection tag name and tag count values
    #
    foreach $subsection (keys %subsection_name_list) {
        $subsection_tag_name{$subsection} = "";
        $subsection_tag_count{$subsection} = 0;
        $inside_subsection{$subsection} = 0;
    }

    #
    # Initialize section table values.
    #
    foreach $section (keys %section_name_list) {
        $inside_section{$section} = 0;
    }

    #
    # Return reference to object.
    #
    return($self);
}
    
#********************************************************
#
# Name: check_start_tag
#
# Parameters: self - class reference
#             tag - tag name
#             line - line number
#             column - column number
#             attr - hash table of tag attributes
#
# Description:
#
#   This function checks to see if the tag has a class, id
# or role attribute value that matches the marker of
# a content section.
#
#********************************************************
sub check_start_tag {
    my ($self, $tag, $line, $column, %attr) = @_;
    
    my ($content_subsection_stack, $inside_subsection, $subsection);
    my ($subsection_tag_name, $subsection_tag_count, $section_object);
    my ($inside_section, $section, $marker_value);
    my ($marker_list) = "";

    #
    # Get list of class, id and role values
    #
    print "check_start_tag, tag = $tag\n" if $debug;
    if ( defined($attr{"class"}) && ($attr{"class"} ne "") ) {
        print "Found class attribute " . $attr{"class"} . "\n" if $debug;
        $marker_list = $attr{"class"};
    }
    if ( defined($attr{"id"}) && ($attr{"id"} ne "") ) {
        print "Found id attribute " . $attr{"id"} . "\n" if $debug;
        $marker_list .= " " . $attr{"id"};
    }
    if ( defined($attr{"role"}) && ($attr{"role"} ne "") ) {
        print "Found role attribute " . $attr{"role"} . "\n" if $debug;
        $marker_list .= " " . $attr{"role"};
    }
    $marker_list =~ s/^\s*//g;

    #
    # Get address of section stacks and tables.
    #
    $content_subsection_stack = $self->{"content_subsection_stack"};
    $inside_subsection = $self->{"inside_subsection"};
    $inside_section = $self->{"inside_section"};
    $subsection_tag_name = $self->{"subsection_tag_name"};
    $subsection_tag_count = $self->{"subsection_tag_count"};

    #
    # Check each marker for the start of a subsection
    #
    print "Check marker list $marker_list\n" if $debug;
    foreach $marker_value (split(/\s+/, $marker_list)) {
        #
        # Is this a subsection marker ?
        #
        if ( defined($subsection_markers{$marker_value}) ) {
            $section_object = $subsection_markers{$marker_value};
            $subsection = $section_object->subsection;
            $section = $section_object->section;
            print "Found subsection marker $marker_value, subsection = $subsection section = $section tag = $tag\n" if $debug;

            #
            # If we are not already inside this subsection, set current
            # section to this one (otherwise we ignore this marker).
            #
            if ( ! $$inside_subsection{$subsection} ) {
                $$inside_subsection{$subsection} = 1;
                $$subsection_tag_count{$subsection} = 0;
                $$subsection_tag_name{$subsection} = $tag;

                #
                # Save existing section/subsection values so we can
                # resume them after this new section/subsection
                #
                push(@$content_subsection_stack,
                     $self->{"current_content_section"} . ":" .
                     $self->{"current_content_subsection"});
                print "Push " .
                      $self->{"current_content_section"} . ":" .
                      $self->{"current_content_subsection"} .
                      " onto content_subsection_stack stack\n" if $debug;

                #
                # Set the section and subsection values
                #
                $$inside_section{$section} = 1;
                $self->{"current_content_section"} = $section;
                $self->{"current_content_subsection"} = $subsection;
                print "Start of subsection $subsection in section $section at $line:$column\n" if $debug;
            }

            #
            # Exit loop
            #
            last;
        }
    }

    #
    # We are inside this section, does this tag
    # match the section start tag ? If so we have to
    # increment the tag count to get the right close
    # tag to end the section.
    #
    $subsection = $self->{"current_content_subsection"};
    if ( defined($subsection) && ($subsection ne "") &&
         ($tag eq $$subsection_tag_name{$subsection}) ) {
        $$subsection_tag_count{$subsection}++;
        print "$subsection tag count = " .
              $$subsection_tag_count{$subsection} . "\n" if $debug;
    }
}

#********************************************************
#
# Name: check_end_tag
#
# Parameters: self - class reference
#             tag - tag name
#             line - line number
#             column - column number
#
# Description:
#
#   This function checks to see if the named tag is the
# close tag for a document section.
#
#********************************************************
sub check_end_tag {
    my ($self, $tag, $line, $column) = @_;

    my ($content_subsection_stack, $inside_subsection, $subsection);
    my ($subsection_tag_name, $subsection_tag_count, $section_object);
    my ($new_subsection, $inside_section, $section, $new_section);

    #
    # Get address of section stacks and tables.
    #
    $content_subsection_stack = $self->{"content_subsection_stack"};
    $inside_subsection = $self->{"inside_subsection"};
    $inside_section = $self->{"inside_section"};
    $subsection_tag_name = $self->{"subsection_tag_name"};
    $subsection_tag_count = $self->{"subsection_tag_count"};
    $subsection = $self->{"current_content_subsection"};
    $section_object = $subsection_markers{$subsection};
    $section = $self->{"current_content_section"};

    #
    # Check for the end of the section areas
    # Does this tag match the start tag for this section ?
    #
    print "check_end_tag, tag = $tag, current subsection = $subsection, current section = $section\n" if $debug;
    if ( ($subsection ne "" ) && 
         ($tag eq $$subsection_tag_name{$subsection}) ) {
        #
        # Decrement the tag count
        #
        $$subsection_tag_count{$subsection}--;
        print "$subsection tag count = " .
              $$subsection_tag_count{$subsection} . "\n" if $debug;

        #
        # If the count is zero, we have found the end of the subsection
        # and possibly the section.
        #
        if ( $$subsection_tag_count{$subsection} <= 0 ) {
            $$inside_subsection{$subsection} = 0;
            $$subsection_tag_count{$subsection} = 0;
            $$subsection_tag_name{$subsection} = "";
            $$inside_section{$section} = 0;
            $self->{"current_content_subsection"} = "";
            $self->{"current_content_section"} = "";
            print "End of subsection $subsection at $line:$column\n" if $debug;

            #
            # Check subsection stack to get previous subsection
            # (if there is one).
            #
            if ( @$content_subsection_stack > 0 ) {
                ($new_section, $new_subsection) = split(/:/, pop(@$content_subsection_stack));
                print "Pop $new_section:$new_subsection from content_subsection_stack\n" if $debug;
                $self->{"current_content_subsection"} = $new_subsection;
                $self->{"current_content_section"} = $new_section;

                print "Restart subsection $new_subsection in section $new_section\n" if $debug;
                $$inside_section{$new_section} = 1;
            }
        }
    }
}

#********************************************************
#
# Name: in_content_section
#
# Parameters: self - class reference
#             section - section label
#
# Description:
#
#   This function returns a flag to indicate whether or not
# the parser is inside a particular content section.
#
#********************************************************
sub in_content_section {
    my ($self, $section) = @_;

    my ($inside_section, $section_object);

    #
    # Get address of section stacks and tables.
    #
    $inside_section = $self->{"inside_section"};

    #
    # Return 'inside section' flag
    #
    if ( defined($$inside_section{$section}) ) {
        $section_object = $$inside_section{$section};
        return($$inside_section{$section});
    }
    else {
        #
        # Unknown content section
        #
        print "in_content_section: Unknown content section '$section'\n"
          if $debug;
        return(0);
    }
}

#********************************************************
#
# Name: in_content_subsection
#
# Parameters: self - class reference
#             subsection - subsection label
#
# Description:
#
#   This function returns a flag to indicate whether or not
# the parser is inside a particular content subsection.
#
#********************************************************
sub in_content_subsection {
    my ($self, $subsection) = @_;

    my ($inside_subsection);

    #
    # Get address of subsection stacks and tables.
    #
    $inside_subsection = $self->{"inside_subsection"};

    #
    # Return 'inside subsection' flag
    #
    if ( defined($$inside_subsection{$subsection}) ) {
        return($$inside_subsection{$subsection});
    }
    else {
        #
        # Unknown content subsection
        #
        print "in_content_subsection: Unknown content subsection '$subsection'\n"
          if $debug;
        return(0);
    }
}

#********************************************************
#
# Name: current_content_section
#
# Parameters: self - class reference
#
# Description:
#
#   This function returns the name of the current content section.
#
#********************************************************
sub current_content_section {
    my ($self) = @_;

    #
    # Return section name
    #
    print "current_content_section: " . $self->{"current_content_section"} .
          "\n" if $debug;
    return($self->{"current_content_section"});
}

#********************************************************
#
# Name: current_content_subsection
#
# Parameters: self - class reference
#
# Description:
#
#   This function returns the name of the current content section.
#
#********************************************************
sub current_content_subsection {
    my ($self) = @_;

    #
    # Return subsection name
    #
    #print "current_content_subsection: " .
    #      $self->{"current_content_subsection"} . "\n" if $debug;
    return($self->{"current_content_subsection"});
}

#********************************************************
#
# Name: Check_Subsection_Start_Attribute_Markers
#
# Parameters: tag - tag class list is from
#             marker_list - list of markers names from tag
#             section_type - type of section to check
#
# Description:
#
#   This function checks for the beginning of a document section
# (e.g. content,footer).  It checks all the marker values from
# the tag against those of the named section.
#
#********************************************************
sub Check_Subsection_Start_Attribute_Markers {
    my ($tag, $marker_list, $subsection_type) = @_;

    my ($marker_value, $subsection_div, $marker_list_addr);

    #
    # Do we have any section markers ?
    #
    #print "Check_Subsection_Start_Attribute_Markers check tag = $tag, marker list = $marker_list for marker type = $subsection_type\n" if $debug;
    if ( defined($subsection_markers{$subsection_type}) ) {
        $marker_list_addr = $subsection_markers{$subsection_type};

        #
        # Check each marker in the list against those defined
        # for the section beginning.
        #
        foreach $marker_value (split(/\s+/, $marker_list)) {
            foreach $subsection_div (@$marker_list_addr) {
                if ( $marker_value eq $subsection_div ) {
                    #
                    # Section Start marker
                    #
                    print "Content area type $subsection_type found \"$subsection_div\" in tag $tag\n" if $debug;
                    return(1);
                }
            }
        }
    }
    else {
        print "No marker list for subsection $subsection_type\n" if $debug;
    }

    #
    # Did not find marker or we have no markers
    #
    return(0);
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
    my (@package_list) = ("content_section_object");

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
Import_Packages;

#
# Return true to indicate we loaded successfully
#
return 1;


