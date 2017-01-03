#***********************************************************************
#
# Name:   html_features.pm
#
# $Revision: 6741 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/TQA_Check/Tools/html_features.pm $
# $Date: 2014-07-25 14:55:37 -0400 (Fri, 25 Jul 2014) $
#
# Description:
#
#   This file contains routines that parse HTML files and reports
# where a number of features (e.g. tables) are found.
#
# Public functions:
#     HTML_Feature_Check
#     HTML_Feature_Metadata_Check
#     HTML_Features_Check_Links
#     HTML_Features_Debug
#     Set_HTML_Feature_Profile
#     Set_HTML_Feature_Metadata_Profile
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

package html_features;

use strict;
use HTML::Parser;
use File::Basename;

#
# Use WPSS_Tool program modules
#
use content_section_object;
use metadata;
use metadata_result_object;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(HTML_Feature_Check
                  HTML_Feature_Metadata_Check
                  HTML_Features_Check_Links
                  HTML_Features_Debug
                  Set_HTML_Feature_Profile
                  Set_HTML_Feature_Metadata_Profile
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (%html_feature_line_no, %html_feature_column_no, %html_feature_count);
my ($current_html_feature_profile, %html_feature_profile_map);
my (%html_feature_metadata_profile_map, $script_tag_type, $have_text_handler);
my ($content_section_handler, $html_features);

#
# Mime types for multimedia
#
my (%multimedia_mime_type) = (
#    "application/x-shockwave-flash", "flash", # Handled seperately
    "audio/mid", "mid",
    "audio/mpeg", "mp3",
    "audio/x-pn-realaudio", "ra",
    "audio/x-wav", "wav",
    "video/mpeg", "mpeg",
    "video/quicktime", "movie",
);

#
# File suffixes for multimedia types
#
my (@multimedia_file_suffixes) = ("avi", "flv", "mov", "swf", "wmv");

#***********************************************************************
#
# Name: HTML_Features_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub HTML_Features_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#***************************************************
#
# Name: Set_HTML_Feature_Profile
#
# Parameters: profile - HTML feature profile
#             html_features - hash table of feature name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by HTML feature name.
#
#***********************************************************************
sub Set_HTML_Feature_Profile {
    my ($profile, $html_features) = @_;

    my (%local_html_features);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    %local_html_features = %$html_features;
    $html_feature_profile_map{$profile} = \%local_html_features;
}

#***************************************************
#
# Name: Set_HTML_Feature_Metadata_Profile
#
# Parameters: profile - HTML feature profile
#             html_features - hash table of feature name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by HTML feature name.
#
#***********************************************************************
sub Set_HTML_Feature_Metadata_Profile {
    my ($profile, $html_features) = @_;

    my (%local_html_features);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    %local_html_features = %$html_features;
    $html_feature_metadata_profile_map{$profile} = \%local_html_features;
}

#***********************************************************************
#
# Name: Initialize_Test_Results
#
# Parameters: profile - HTML features profile
#
# Description:
#
#   This function initializes the HTML features table.
#
#***********************************************************************
sub Initialize_Test_Results {
    my ($profile) = @_;

    my (%hash1, %hash2, %hash3);

    #
    # Set current hash tables
    #
    $current_html_feature_profile = $html_feature_profile_map{$profile};

    #
    # Set other module globals
    #
    $script_tag_type = "";
    $have_text_handler = 0;
    %html_feature_line_no = ();
    %html_feature_column_no = ();
    %html_feature_count = ();

    #
    # Create page section entries
    #
    $html_feature_line_no{"PAGE"} = \%hash1;
    $html_feature_column_no{"PAGE"} = \%hash2;
    $html_feature_count{"PAGE"} = \%hash3;
}

#***********************************************************************
#
# Name: Record_HTML_Feature
#
# Parameters: feature - HTML feature
#             line - line number
#             column - column number
#
# Description:
#
#   This function records the HTML feature details
#
#***********************************************************************
sub Record_HTML_Feature {
    my ( $feature, $line, $column ) = @_;

    my ($section, $line_no_hash, $column_no_hash, $count_hash);

    #
    # Is this feature included in the profile
    #
    if ( defined($$current_html_feature_profile{$feature}) ) {

        #
        # Get current document section
        #
        if ( defined($content_section_handler) ) {
            $section = $content_section_handler->current_content_section();

            #
            # If we don't have a section name, assign the feature to the
            # entire page.
            #
            if ( $section eq "" ) {
                $section = "PAGE";
            }
        }
        else {
            $section = "PAGE";
        }

        #
        # Do we have a html features table for this section ?
        #
        if ( ! defined($html_feature_line_no{$section}) ) {
            my (%hash1, %hash2, %hash3);
            print "Create new HTML feature hash tables for section $section\n" if $debug;
            $html_feature_line_no{$section} = \%hash1;
            $html_feature_column_no{$section} = \%hash2;
            $html_feature_count{$section} = \%hash3;
        }
        $line_no_hash = $html_feature_line_no{$section};
        $column_no_hash = $html_feature_column_no{$section};
        $count_hash = $html_feature_count{$section};

        #
        # If we have not seen this feature before, record its location
        #
        if ( ! defined($$count_hash{$feature}) ) {
            $$line_no_hash{$feature} = $line;
            $$column_no_hash{$feature} = $column;
            $$count_hash{$feature} = 1;
        }
        else {
            #
            # Increment the count for this feature
            #
            $$count_hash{$feature}++;
        }

        #
        # Record feature as being found
        #
        print "HTML feature $feature found at line: $line, column: $column in section $section\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Anchor_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles anchor tags.
#
#***********************************************************************
sub Anchor_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    my ($href);

    #
    # Do we have an href attribute
    #
    print "Anchor_Tag_Handler tag at $line:$column\n" if $debug;
    if ( defined( $attr{"href"} ) ) {

        #
        # Check link target for some special document types
        #
        $href = $attr{"href"};
        if ( $href =~ /\.pdf$/ ) {
            #
            # Link to a PDF document.
            #
            Record_HTML_Feature("PDF href", $line, $column);
        }
    }
}

#***********************************************************************
#
# Name: Script_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles script tags.
#
#***********************************************************************
sub Script_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($href);

    #
    # Do we have an type attribute
    #
    print "Script_Tag_Handler tag at $line:$column\n" if $debug;
    if ( defined( $attr{"type"} ) ) {
        #
        # Save script type
        #
        $script_tag_type = $attr{"type"};

        #
        # Add a text handler to save the text portion of the script
        # tag.
        #
        $self->handler( text => [], '@{dtext}' );
        $have_text_handler = 1;
    }
    else {
        #
        # No type attribute, clear any old type value.
        #
        $script_tag_type = "";
    }
}

#***********************************************************************
#
# Name: Start_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the start of HTML tags.
#
#***********************************************************************
sub Start_Handler {
    my ( $self, $tagname, $line, $column, $text, @attr ) = @_;

    my (%attr_hash) = @attr;
    my ($attribute);

    #
    # Check for start of content section
    #
    $content_section_handler->check_start_tag($tagname, $line, $column,
                                              %attr_hash);

    #
    # Found HTML feature
    #
    Record_HTML_Feature($tagname, $line, $column);

    #
    # Does this tag have an attribute we want to record ?
    #
    foreach $attribute (keys %attr_hash) {
        #
        # Found HTML feature
        #
        Record_HTML_Feature($attribute, $line, $column);
    }

    #
    # Does this tag have an attribute=<value> combination we want to record ?
    #
    foreach $attribute (keys %attr_hash) {
        #
        # Add value portion
        #
        $attribute = "$attribute=\"". $attr_hash{$attribute} . "\"";

        #
        # Found HTML feature
        #
        Record_HTML_Feature($attribute, $line, $column);
    }

    #
    # Check anchor tags
    #
    if ( $tagname eq "a" ) {
        Anchor_Tag_Handler($line, $column, $text, %attr_hash);
    }
    #
    # Check script tag
    #
    elsif ( $tagname eq "script" ) {
        Script_Tag_Handler($self, $line, $column, $text, %attr_hash);
    }
    
    #
    # Check for new windows via the target attribute
    #
    if ( defined($attr_hash{"target"}) &&
         ($attr_hash{"target"} =~ /_blank/i) ) {
        Record_HTML_Feature("New window", $line, $column);
    }
}

#***********************************************************************
#
# Name: End_Script_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end script tag.
#
#***********************************************************************
sub End_Script_Tag_Handler {
    my ( $self, $line, $column, $text) = @_;

    my ($suffix, $script_text);

    #
    # Are we looking for multimedia that may be loaded via JavaScript ?
    #
    print "End_Script_Tag_Handler tag at $line:$column\n" if $debug;
    if ( defined($$current_html_feature_profile{"multimedia"}) ) {
        #
        # Is this script of type JavaScript ?
        #
        print "Check script type $script_tag_type\n" if $debug;
        if ( $script_tag_type =~ /text\/javascript/i ) {
            #
            # Get script text
            #
            if ( ! $have_text_handler ) {
                print "End script tag found without corresponding open tag at line $line, column $column\n" if $debug;
                return;
            }
            $script_text = join("", @{ $self->handler("text") });

            #
            # Check for various file types in the text between the
            # start and end script tags.
            #
            print "Check file types in script text $script_text\n" if $debug;
            foreach $suffix (@multimedia_file_suffixes) {
                if ( $script_text =~ /\.$suffix['"]/ ) {
                    print "Found file suffix $suffix\n" if $debug;
                    Record_HTML_Feature("multimedia", $line, $column);
                    last;
                }
            }

            #
            # Destroy the text handler that was used to save the text
            # portion of the script tag.
            #
            $self->handler( "text", undef );
            $have_text_handler = 0;
        }
    }
}

#***********************************************************************
#
# Name: End_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end of HTML tags.
#
#***********************************************************************
sub End_Handler {
    my ( $self, $tagname, $line, $column, $text, @attr ) = @_;

    my (%attr_hash) = @attr;

    #
    # Check tag names
    #
    if ( $tagname eq "script" ) {
        #
        # Check script end tag
        #
        End_Script_Tag_Handler($self, $line, $column, $text);
    }
    #
    # Is this the end of a content area ?
    #
    $content_section_handler->check_end_tag($tagname, $line, $column);
}

#***********************************************************************
#
# Name: HTML_Feature_Check
#
# Parameters: this_url - a URL
#             profile - html feature profile
#             this_html_feature_line_no - reference to list containing 
#               source line numbers
#             this_html_feature_column_no - reference to list containing
#               source column numbers
#             this_html_feature_count - reference to hash to contain HTML
#                feature counts
#             content - HTML content pointer
#
# Description:
#
#   This function parses HTML text looking for a number of HTML 
# features (e.g. tables).
#
#***********************************************************************
sub HTML_Feature_Check {
    my ( $this_url, $profile,
         $this_html_feature_line_no, $this_html_feature_column_no,
         $this_html_feature_count, $content ) = @_;

    my ($parser, $feature, $section, $addr, $key, $value);

    #
    # Do we have a valid profile ?
    #
    print "HTML_Feature_Check: Checking URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($html_feature_profile_map{$profile}) ) {
        print "HTML_Feature_Check: Unknown HTML Feature profile passed $profile\n";
        return;
    }

    #
    # Initialize the tables.
    #
    Initialize_Test_Results($profile);

    #
    # Did we get any content ?
    #
    if ( length($$content) > 0 ) {
        #
        # Create a document parser
        #
        $parser = HTML::Parser->new;

        #
        # Create a content section object
        #
        $content_section_handler = content_sections->new;

        #
        # Add handlers for some of the HTML tags
        #
        $parser->handler(
            start => \&Start_Handler,
            "self,tagname,line,column,text,\@attr"
        );
        $parser->handler(
            end => \&End_Handler,
            "self,tagname,line,column,text,\@attr"
        );

        #
        # Parse the content.
        #
        $parser->parse($$content);
        undef $content_section_handler;

        #
        # If we found a content section, return features from
        # that section. If there was no recognized content section
        # return features from the entire web page
        #
        if ( defined($html_feature_line_no{"CONTENT"}) ) {
            $section = "CONTENT";
            print "Found $section section features\n" if $debug;
        }
        elsif ( defined($html_feature_line_no{"PAGE"}) ) {
            $section = "PAGE";
            print "Found $section section features\n" if $debug;
        }

        #
        # If we have a section, copy results into user supplied
        # hash tables.
        #
        if ( defined($section) ) {
            $addr = $html_feature_line_no{$section};
            while ( ($key, $value) = each %$addr ) {
                $$this_html_feature_line_no{$key} = $value;
            }
            $addr = $html_feature_column_no{$section};
            while ( ($key, $value) = each %$addr ) {
                $$this_html_feature_column_no{$key} = $value;
            }
            $addr = $html_feature_count{$section};
            while ( ($key, $value) = each %$addr ) {
                $$this_html_feature_count{$key} = $value;
            }
        }

        #
        # Print out feature counts
        #
        if ( $debug ) {
            print "HTML Features for $this_url\n";
            foreach $feature (keys(%$this_html_feature_count)) {
                print "  Feature = $feature, count = " .
                      $$this_html_feature_count{$feature} . "\n";
            }
        }
    }
    else {
        print "No content passed to HTML_Feature_Check\n" if $debug;
        return;
    }
}

#***********************************************************************
#
# Name: Check_Metadata_Expression
#
# Parameters: tag - Metadata tag
#             expression - expression test
#             metadata_object - metadata result object
#
# Description:
#
#   This function checks the metadata item content against the supplied
# expression.  If the expression passes, the metadata feature is set.
#
#***********************************************************************
sub Check_Metadata_Expression {
    my ($tag, $expression, $metadata_object) = @_;
    
    my ($type, $operator, $value, $orig_value, $content);
    my ($section, $line_no_hash, $column_no_hash, $count_hash);

    #
    # Get the page level section
    #
    $line_no_hash = $html_feature_line_no{"PAGE"};
    $column_no_hash = $html_feature_column_no{"PAGE"};
    $count_hash = $html_feature_count{"PAGE"};

    #
    # Parse out the components of the expression
    #
    ($type, $operator, $value) = split(/\s+/, $expression, 3);
    print "Check_Metadata_Expression type = $type, operator = $operator value = $value\n" if $debug;

    #
    # If we have a value we have a valid expression
    #
    if ( defined($value) ) {
        #
        # Get metadata content
        #
        $content = $metadata_object->content;
        print "Metadata content = $content\n" if $debug;
        
        #
        # Check the type, we may have to modify the content
        #
        if ( $type =~ /^date$/i ) {
            #
            # Strip out - and space separators from date values
            #
            $content =~ s/[-\s]//g;
            $orig_value = $value;
            $value =~ s/[-\s]//g;
            
            #
            # Check the operator
            #
            if ( $operator eq ">" ) {
                #
                # Is content greater (or newer) than the value ?
                #
                print "Compare $content > $value\n" if $debug;
                if ( $content > $value ) {
                    #
                    # Record feature. We can't use the Record_HTML_Feature
                    # routine as it will check if the feature is part
                    # of the profile. We are constructing the feature
                    # id here so it is not part of the profile.
                    #
                    print "Metadata tag $tag content " .
                          $metadata_object->content . " newer than $orig_value\n" if $debug;
                    $$line_no_hash{"$tag > $orig_value"} = -1;
                    $$column_no_hash{"$tag > $orig_value"} = -1;
                    $$count_hash{"$tag > $orig_value"} = 1;
                }
            }
            elsif ( $operator eq "<" ) {
                #
                # Is content less (or older) than the value ?
                #
                print "Compare $content < $value\n" if $debug;
                if ( $content < $value ) {
                    #
                    # Record feature. We can't use the Record_HTML_Feature
                    # routine as it will check if the feature is part
                    # of the profile. We are constructing the feature
                    # id here so it is not part of the profile.
                    #
                    print "Metadata tag $tag content " .
                          $metadata_object->content . " older than $orig_value\n" if $debug;
                    $$line_no_hash{"$tag < $orig_value"} = -1;
                    $$column_no_hash{"$tag < $orig_value"} = -1;
                    $$count_hash{"$tag < $orig_value"} = 1;
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: HTML_Feature_Metadata_Check
#
# Parameters: this_url - a URL
#             profile - html feature profile
#             this_html_feature_line_no - reference to list containing
#               source line numbers
#             this_html_feature_column_no - reference to list containing
#               source column numbers
#             this_html_feature_count - reference to hash to contain HTML
#                feature counts
#             content - HTML content pointer
#
# Description:
#
#   This function parses HTML text looking for a number of metadata
# features (e.g. dcterms.issued after a certain date).
#
#***********************************************************************
sub HTML_Feature_Metadata_Check {
    my ( $this_url, $profile,
         $this_html_feature_line_no, $this_html_feature_column_no,
         $this_html_feature_count, $content ) = @_;

    my ($feature, %metadata, $tag, $expression, $addr, $key, $value, $section);

    #
    # Do we have a valid profile ?
    #
    print "HTML_Feature_Metadata_Check Checking URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($html_feature_metadata_profile_map{$profile}) ) {
        print "HTML_Feature_Metadata_Check Unknown HTML Feature profile passed $profile\n";
        return;
    }

    #
    # Initialize module global variables.
    #
    Initialize_Test_Results($profile);

    #
    # Did we get any content ?
    #
    if ( length($$content) > 0 ) {
        #
        # Get metadata from the document
        #
        %metadata = Extract_Metadata($this_url, $content);
        
        #
        # Check each HTML feature metadata entry to see if we have metadata
        # for it.
        #
        while ( ($tag, $expression) = each %$current_html_feature_profile ) {
            print "Check for $tag and test $expression\n" if $debug;
            
            #
            # Do we have the metadata tag and are we testing it?
            #
            if ( defined($metadata{$tag}) &&
                 defined($$current_html_feature_profile{$tag}) ) {
                #
                # Test the metadata content against the expression
                #
                print "Have metadata tag $tag\n" if $debug;
                Check_Metadata_Expression($tag, $expression, $metadata{$tag});
            }
        }

        #
        # If we found a content section, return features from
        # that section. If there was no recognized content section
        # return features from the entire web page
        #
        if ( defined($html_feature_line_no{"PAGE"}) ) {
            $section = "PAGE";
        }

        #
        # If we have a section, copy results into user supplied
        # hash tables.
        #
        if ( defined($section) ) {
            $addr = $html_feature_line_no{"PAGE"};
            while ( ($key, $value) = each %$addr ) {
                $$this_html_feature_line_no{$key} = $value;
            }
            $addr = $html_feature_column_no{"PAGE"};
            while ( ($key, $value) = each %$addr ) {
                $$this_html_feature_column_no{$key} = $value;
            }
            $addr = $html_feature_count{"PAGE"};
            while ( ($key, $value) = each %$addr ) {
                $$this_html_feature_count{$key} = $value;
            }
        }

        #
        # Print out feature counts
        #
        if ( $debug ) {
            print "HTML Features for $this_url\n";
            foreach $feature (keys(%$this_html_feature_count)) {
                print "  Feature = $feature, count = " .
                      $$this_html_feature_count{$feature} . "\n";
            }
        }
    }
    else {
        print "No content passed to HTML_Feature_Metadata_Check\n" if $debug;
        return;
    }
}

#***********************************************************************
#
# Name: HTML_Features_Check_Links
#
# Parameters: this_url - a URL
#             profile - html feature profile
#             this_html_feature_line_no - reference to list containing
#               source line numbers
#             this_html_feature_column_no - reference to list containing
#               source column numbers
#             this_html_feature_count - reference to hash to contain HTML
#                feature counts
#             links - list of link objects
#
# Description:
#
#   This function scans the list of links looking for particular
# link mime-types (e.g. multimedia)
#
#***********************************************************************
sub HTML_Features_Check_Links {
    my ( $this_url, $profile,
         $this_html_feature_line_no, $this_html_feature_column_no,
         $this_html_feature_count, @links ) = @_;

    my ($link, $addr, $key, $value, $section);

    #
    # Do we have a valid profile ?
    #
    print "HTML_Features_Check_Links: URL $this_url, profile = $profile\n" if $debug;
    if ( ! defined($html_feature_profile_map{$profile}) ) {
        print "HTML_Features_Check_Links: Unknown HTML Feature profile passed $profile\n";
        return;
    }

    #
    # Initialize module global variables.
    #
    Initialize_Test_Results($profile);

    #
    # Are we looking for multimedia or non HTML links ?
    #
    if ( defined($$current_html_feature_profile{"multimedia"}) ||
         defined($$current_html_feature_profile{"non-html link/lien"})  ) {
        #
        # Check all links
        #
        foreach $link (@links) {
            #
            # Do we have a mime-type (we wont if it is a broken link
            # or an ignored link).
            #
            if ( ! defined($link->mime_type) || ($link->mime_type eq "") ) {
                next;
            }
            
            #
            # Is this 'regular' link (anchor) that references a non HTML
            # document ?
            #
            print "Check link type " . $link->link_type . " mime-type " .
                  $link->mime_type . " href " . $link->href . "\n" if $debug;
            if ( ($link->link_type eq "a") &&
                 ($link->mime_type ne "text/html") ) {
                #
                # Found non-HTML link
                #
                print "Found non-html link, mime-type " .
                      $link->mime_type . " href " . $link->href .
                      "\n" if $debug;
                Record_HTML_Feature("non-html link/lien", $link->line_no,
                                    $link->column_no);
            }
            #
            # Is the link loaded within the page, e.g. an applet ?
            #
            elsif ( ($link->link_type eq "applet") ||
                    ($link->link_type eq "embed") ||
                    ($link->link_type eq "object") ) {

                #
                # Is this a Flash file ?
                #
                if ( $link->mime_type eq "application/x-shockwave-flash" ) {
                    #
                    # Found flash link
                    #
                    print "Found flash link, mime-type " .
                          $link->mime_type . " href " . $link->href .
                          "\n" if $debug;
                    Record_HTML_Feature("flash", $link->line_no,
                                        $link->column_no);
                }
                #
                # Does the mime-type match a multimedia mime-type ?
                #
                elsif ( defined($multimedia_mime_type{$link->mime_type}) ) {
                    #
                    # Found multimedia link
                    #
                    print "Found multimedia link, mime-type " .
                          $link->mime_type . " href " . $link->href .
                          "\n" if $debug;
                    Record_HTML_Feature("multimedia", $link->line_no,
                                        $link->column_no);
                }
            }
        }

        #
        # If we found a content section, return features from
        # that section. If there was no recognized content section
        # return features from the entire web page
        #
        if ( defined($html_feature_line_no{"PAGE"}) ) {
            $section = "PAGE";
        }

        #
        # If we have a section, copy results into user supplied
        # hash tables.
        #
        if ( defined($section) ) {
            $addr = $html_feature_line_no{"PAGE"};
            while ( ($key, $value) = each %$addr ) {
                $$this_html_feature_line_no{$key} = $value;
            }
            $addr = $html_feature_column_no{"PAGE"};
            while ( ($key, $value) = each %$addr ) {
                $$this_html_feature_column_no{$key} = $value;
            }
            $addr = $html_feature_count{"PAGE"};
            while ( ($key, $value) = each %$addr ) {
                $$this_html_feature_count{$key} = $value;
            }
        }
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

