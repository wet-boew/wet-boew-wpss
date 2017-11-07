#***********************************************************************
#
# Name: extract_links.pm	
#
# $Revision: 7583 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Link_Check/Tools/extract_links.pm $
# $Date: 2016-06-03 09:10:13 -0400 (Fri, 03 Jun 2016) $
#
# Description:
#
#   This file contains routines that parse links from a block of HTML
# content. 
#
# Public functions:
#     Extract_Links
#     Extract_Links_Debug
#     Extract_Links_Subsection_Links
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

package extract_links;

use strict;
use HTML::Parser;
use URI::Escape;
use URI::URL;
use File::Basename;

#
# Use WPSS_Tool program modules
#
use content_sections;
use css_extract_links;
use css_validate;
use extract_anchors;
use language_map;
use link_object;
use pdf_extract_links;
use url_check;
use xml_extract_links;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Extract_Links
                  Extract_Links_Debug
                  Extract_Links_Subsection_Links
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my ($current_anchor_reference, @content_lines, $link_object_reference);
my ($current_lang, @lang_stack, $current_resp_base, $have_text_handler);
my ($content_section_handler, %subsection_links, @last_link_list);
my (@tag_lang_stack, $last_lang_tag, $in_head_section);
my ($last_heading_text, $current_list_level, @inside_list_item);
my (@text_handler_tag_list, @text_handler_text_list);
my ($current_text_handler_tag, $inside_anchor, $last_image_link);
my ($inside_figure, $have_figcaption, $figcaption_text, $inside_noscript);
my ($image_in_figure_with_no_alt, @object_reference_list, @list_location);
my ($last_generated_content);
my ($last_url) = "";
my (%html_tags_with_no_end_tag) = (
        "area", "area",
        "base", "base",
        "br", "br",
        "col", "col",
        "command", "command",
        "embed", "embed",
        "frame", "frame",
        "hr", "hr",
        "img", "img",
        "input", "input",
        "keygen", "keygen",
        "link", "link",
        "meta", "meta",
        "param", "param",
        "source", "source",
        "track", "track",
        "wbr", "wbr",
);


#********************************************************
#
# Name: Extract_Links_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Extract_Links_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
    
    #
    # Set debug flag of supporting packages.
    #
    Link_Object_Debug($debug);
    CSS_Extract_Links_Debug($debug);
    PDF_Extract_Links_Debug($debug);
    XML_Extract_Links_Debug($debug);
}

#***********************************************************************
#
# Name: Extract_Links_Subsection_Links
#
# Parameters: subsection - subsection name
#
# Description:
#
#   This function returns the list of links for the specified subsection.
# The subsection names match those defined in the content_section.pm module.
# The special subsection name ALL includes all links from all the subsections.
# In this case a hash table of sectionss and list of links is returned.
# The links are from the last call to Extract_Links.
#
#***********************************************************************
sub Extract_Links_Subsection_Links {
    my ($subsection) = @_;

    my (@links, %link_sets, $subsection_name, $link_addr);

    #
    # Return list of links
    #
    if ( defined($subsection_links{$subsection}) ) {
        @links = @{$subsection_links{$subsection}};

        #
        # Print list of links returned
        #
        if ( $debug ) {
            print "Extract_Links_Subsection_Links, subsection = $subsection\n";
            foreach (@links) {
                print "Anchor = \"" . $_->anchor . 
                      "\" alt = \"" . $_->alt .
                      "\" href = " . $_->abs_url . "\n";
            }
        }

        #
        # Return list of links.
        #
        return(@links);
    }
    elsif ( $subsection eq "ALL" ) {
        #
        # Get list of links from all subsections.
        #
        foreach $subsection_name (keys %subsection_links) {
            print "Extract_Links_Subsection_Links, subsection = $subsection_name\n" if $debug;
            if ( defined($subsection_links{$subsection_name}) ) {
                $link_addr = $subsection_links{$subsection_name};
                $link_sets{$subsection_name} = $link_addr;

                #
                # Print list of links returned
                #
                if ( $debug ) {
                    foreach (@$link_addr) {
                        print "Anchor = \"" . $_->anchor . 
                              "\" alt = \"" . $_->alt .
                              "\" href = " . $_->abs_url . "\n";
                    }
                }
            }
        }

        #
        # Return table of link sets
        #
        return(%link_sets);
    }
    else {
        print "Unknown subsection $subsection in call to Extract_Links_Subsection_Links\n" if $debug;
        foreach (keys %subsection_links) {
            print "key = $_\n" if $debug;
        }
        return(@links);
    }
}

#***********************************************************************
#
# Name: Initialize_Link_Parser_Variables
#
# Parameters: none
#
# Description:
#
#   This function initializes global variables used for
# parsing HTML content.
#
#***********************************************************************
sub Initialize_Link_Parser_Variables {

    #
    # Initialize variables
    #
    $current_anchor_reference = undef;
    $have_text_handler = 0;
    $current_lang = "eng";
    push(@lang_stack, $current_lang);
    push(@tag_lang_stack, "top");
    $last_lang_tag = "top";
    $in_head_section = 0;
    $last_heading_text = "";
    $current_list_level = -1;
    $current_text_handler_tag = "";
    $inside_anchor = 0;
    $inside_noscript = 0;
    undef @text_handler_tag_list;
    @object_reference_list = ();
}

#***********************************************************************
#
# Name: Clean_Text
#
# Parameters: text - text string
#
# Description:
#
#   This function eliminates leading and trailing white space from text.
# It also compresses multiple white space characters into a single space.
#
#***********************************************************************
sub Clean_Text {
    my ($text) = @_;

    #
    # Convert &nbsp; into a single space.
    # Convert newline into a space.
    # Convert return into a space.
    #
    $text =~ s/\&nbsp;/ /g;
    $text =~ s/\r\n|\r|\n/ /g;

    #
    # Convert multiple spaces into a single space
    #
    $text =~ s/\s\s+/ /g;

    #
    # Trim leading and trailing white space
    #
    $text =~ s/^\s*//g;
    $text =~ s/\s*$//g;

    #
    # Return cleaned text
    #
    return($text);
}

#***********************************************************************
#
# Name: Destroy_Text_Handler
#
# Parameters: self - reference to a HTML::Parse object
#             tag - current tag
#
# Description:
#
#   This function destroys a text handler.
#
#***********************************************************************
sub Destroy_Text_Handler {
    my ($self, $tag) = @_;
    
    my ($saved_text, $current_text);

    #
    # Destroy text handler
    #
    print "Destroy_Text_Handler for tag $tag\n" if $debug;

    #
    # Do we have a text handler ?
    #
    if ( $have_text_handler ) {
        #
        # Get the text from the handler
        #
        $current_text = Get_Text_Handler_Content($self, " ");
        
        #
        # Destroy the text handler
        #
        $self->handler( "text", undef );
        $have_text_handler = 0;
        
        #
        # Get tag name for previous tag (if there was one)
        #
        if ( @text_handler_tag_list > 0 ) {
            $current_text_handler_tag = pop(@text_handler_tag_list);
            print "Restart text handler for tag $current_text_handler_tag\n" if $debug;
            
            #
            # We have to create a new text handler top restart the
            # text collection for the previous tag.  We also have to place
            # the saved text back in the handler.
            #
            $saved_text = pop(@text_handler_text_list);
            $self->handler( text => [], '@{dtext}' );
            $have_text_handler = 1;
            print "Push \"$saved_text\" into text handler\n" if $debug;
            push(@{ $self->handler("text")}, $saved_text);
            
            #
            # Do we add the text from the just destroyed text handler to
            # the previous tag's handler ?  In most cases we do.
            #
            if ( ($tag eq "a") && ($current_text_handler_tag eq "label") ) {
                #
                # Don't add anchor tag text to a label tag.
                #
                print "Not adding <a> text to <label> text handler\n" if $debug;
            }
            else {
                #
                # Add text from this tag to the previous tag's text handler
                #
                print "Adding \"$current_text\" text to text handler\n" if $debug;
                push(@{ $self->handler("text")}, " $current_text ");
            }
        }
        else {
            #
            # No previous text handler, set current text handler tag name
            # to an empty string.
            #
            $current_text_handler_tag = "";
        }
    } else {
        #
        # No text handler to destroy.
        #
        print "No text handler to destroy\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Start_Text_Handler
#
# Parameters: self - reference to a HTML::Parse object
#             tag - current tag
#
# Description:
#
#   This function starts a text handler.  If one is already set, it
# is destroyed and recreated (to erase any existing saved text).
#
#***********************************************************************
sub Start_Text_Handler {
    my ($self, $tag) = @_;
    
    my ($current_text);
    
    #
    # Add a text handler to save text
    #
    print "Start_Text_Handler for tag $tag\n" if $debug;
    
    #
    # Do we already have a text handler ?
    #
    if ( $have_text_handler ) {
        #
        # Save any text we may have already captured.  It belongs
        # to the previous tag.  We have to start a new handler to
        # save text for this tag.
        #
        $current_text = Get_Text_Handler_Content($self, " ");
        push(@text_handler_tag_list, $current_text_handler_tag);
        print "Saving \"$current_text\" for $current_text_handler_tag tag\n" if $debug;
        push(@text_handler_text_list, $current_text);
        
        #
        # Destoy the existing text handler so we don't include text from the
        # current tag's handler for this tag.
        #
        $self->handler( "text", undef );
    }
    
    #
    # Create new text handler
    #
    $self->handler( text => [], '@{dtext}' );
    $have_text_handler = 1;
    $current_text_handler_tag = $tag;
}

#***********************************************************************
#
# Name: Get_Text_Handler_Content
#
# Parameters: self - reference to a HTML::Parse object
#             separator - text to separate content components
#
# Description:
#
#   This function gets the text from the text handler.  It
# joins all the text together and trims off whitespace.
#
#***********************************************************************
sub Get_Text_Handler_Content {
    my ($self, $separator) = @_;
    
    my ($content) = "";
    
    #
    # Add a text handler to save text
    #
    print "Get_Text_Handler_Content separator = \"$separator\"\n" if $debug;
    
    #
    # Do we have a text handler ?
    #
    if ( $have_text_handler ) {
        #
        # Get any text.
        #
        $content = join($separator, @{ $self->handler("text") });
    }
    
    #
    # Return the content
    #
    return($content);
}

#***********************************************************************
#
# Name: Get_Lang
#
# Parameters: tag - tagname
#             attr - hash table of attributes
#
# Description:
#
#   This function looks for a possible lang attribute. If found
# it converts a 2 character language code into a 3 character code.
# If no lang attribute is found, the current language code is used.
#
#***********************************************************************
sub Get_Lang {
    my ($tag, %attr) = @_;
    
    my ($lang);

    #
    # Do we have a hreflang attribute
    #
    if ( defined( $attr{"hreflang"} ) ) {
        $lang = $attr{"hreflang"};
        print "Get_Lang: Have hreflang = $lang attribute\n" if $debug;

        #
        # Convert possible 2 character code into a 3 character code.
        #
        if ( defined($language_map::iso_639_1_iso_639_2T_map{$lang}) ) {
            $lang = $language_map::iso_639_1_iso_639_2T_map{$lang};
        }
    }
    #
    # Do we have a lang attribute
    #
    elsif ( defined( $attr{"lang"} ) ) {
        $lang = lc($attr{"lang"});
        print "Get_Lang: Have lang = $lang attribute\n" if $debug;
        
        #
        # Convert possible 2 character code into a 3 character code.
        #
        if ( defined($language_map::iso_639_1_iso_639_2T_map{$lang}) ) {
            $lang = $language_map::iso_639_1_iso_639_2T_map{$lang};
        }
    }
    #
    # Do we have a xml:lang attribute
    #
    elsif ( defined( $attr{"xml:lang"} ) ) {
        $lang = lc($attr{"xml:lang"});
        print "Get_Lang: Have xml:lang = $lang attribute\n" if $debug;
        
        #
        # Convert possible 2 character code into a 3 character code.
        #
        if ( defined($language_map::iso_639_1_iso_639_2T_map{$lang}) ) {
            $lang = $language_map::iso_639_1_iso_639_2T_map{$lang};
        }
    }
    else {
        #
        # Use current language value
        #
        $lang = $current_lang;
        print "Get_Lang: Use current lang = $lang\n" if $debug;
    }
    
    #
    # Return language code
    #
    return($lang);
}

#***********************************************************************
#
# Name: Save_Link_In_Subsection_List
#
# Parameters: link - link object
#
# Description:
#
#   This function adds the list object to the list of links for the
# current document section.
#
#***********************************************************************
sub Save_Link_In_Subsection_List {
    my ($link) = @_;

    my ($subsection, @list, $subsection_link_list);

    #
    # Get current subsection
    #
    $subsection = $content_section_handler->current_content_subsection;

    #
    # If there is no subsection name, try to determine if we are in the
    # <body> or <head>.
    #
    if ( $subsection eq "" ) {
        #
        # Are we in the head section ?
        #
        if ( $in_head_section ) {
            $subsection = "HEAD";
        }
        #
        # If we are not in the <head> section and we have no subsection
        # marker (e.g. scripts in the footer), assign link to the BODY
        # subsection.
        #
        else {
            $subsection = "BODY";
        }
    }

    #
    # Are we missing a list that we can add this link object to ?
    #
    if ( ! defined($subsection_links{$subsection}) ) {
        $subsection_links{$subsection} = \@list;
    }

    #
    # Add link object to the list for the current subsection
    #
    $subsection_link_list = $subsection_links{$subsection};
    push(@$subsection_link_list, $link);
    $link->content_section($subsection);
    print "Add link object to subsection list $subsection\n" if $debug;
}

#***********************************************************************
#
# Name: Get_Absolute_URL
#
# Parameters: href - relative href value
#             onclick - onclick tag attribute
#
# Description:
#
#   This function converts the relative URL value into an absolute URL.
# If there is an onclick attribute value, and the value is not JavaScript
# code, then the onclick value is used as the absolute URL.
# If there is no onclick value, the href value and
# the base value from the HTTP::Response object are combined to generate
# the absolute URL value.
#
#***********************************************************************
sub Get_Absolute_URL {
    my ($href, $onclick) = @_;
    
    my ($abs_url);

    #
    # Do we have an onclick value ?
    #
    if ( defined($onclick) &&
        ($onclick ne "") &&
        (! ($onclick =~ /^\s*javascript:/i) ) ) {
        print "Absolute value is onclick attribute \"$onclick\"\n" if $debug;
        $abs_url = $onclick;
    }
    else {
        print "Absolute value generated from href and base\n" if $debug;
        $abs_url = URL_Check_Make_URL_Absolute($href, $current_resp_base);
    }
    
    #
    # Return absolute URL value
    #
    return($abs_url);
}

#***********************************************************************
#
# Name: Anchor_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
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
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($href, $lang, $abs_url, $subsection, $subsection_link_list);
    my ($list_heading);

    #
    # Do we have a href value ?
    #
    if ( defined($attr{"href"}) ) {
        #
        # Remove leading & trailing white space
        #
        $href = $attr{"href"};
        $href =~ s/^\s*//g;
        $href =~ s/\s*$//g;

        #
        # Do we have an href value ?
        #
        if ( $href ne "" ) {
        
            #
            # Add a text handler to save the text portion of the anchor
            # tag.
            #
            Start_Text_Handler($self, "a");
            $inside_anchor = 1;
        
            #
            # Convert href into an absolute URL
            #
            $abs_url = Get_Absolute_URL($href, $attr{"onclick"});

            #
            # Do we have a lang attribute
            #
            $lang = Get_Lang("a", %attr);
    
            #
            # Save link details and handle them in the end anchor tag.
            #
            $current_anchor_reference = link_object->new($href, $abs_url, "",
                                                         "a",
                                                         $lang, $line, $column,
                                                         $content_lines[$line - 1]);
            $current_anchor_reference->attr(%attr);
            $current_anchor_reference->noscript($inside_noscript);
            push (@$link_object_reference, $current_anchor_reference);
            print " Anchor at $line, $column href = $href\n" if $debug;

            #
            # Save link object in subsection list
            #
            Save_Link_In_Subsection_List($current_anchor_reference);

            #
            # Do we have alt text ?
            #
            if ( defined($attr{"alt"}) ) {
                $current_anchor_reference->alt($attr{"alt"});
            }

            #
            # Do we have a title ?
            #
            if ( defined($attr{"title"}) ) {
                $current_anchor_reference->title($attr{"title"});
            }

            #
            # Are we inside a list item ?
            #
            if ( ($current_list_level > -1 ) && 
                 ($inside_list_item[$current_list_level]) ) {
                $list_heading = $last_heading_text . $list_location[$current_list_level];
                print "Anchor inside a list item, list heading = $list_heading\n" if $debug;
                $current_anchor_reference->in_list(1);
                $current_anchor_reference->list_heading($list_heading);
            }
        }
        else {
            print "No href value in link at $line, $column\n" if $debug;
            undef $current_anchor_reference;
        }
    }
    else {
        print "No href attribute in link at $line, $column\n" if $debug;
        undef $current_anchor_reference;
    }
}

#***********************************************************************
#
# Name: Frame_Tag_Handler
#
# Parameters: self - reference to this parser
#             tag - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the frame/iframe tag, it looks for a src attribute.
#
#***********************************************************************
sub Frame_Tag_Handler {
    my ( $self, $tag, $line, $column, $text, %attr ) = @_;

    my ($src, $title, $lang, $link, $abs_url, $subsection, $subsection_link_list);

    #
    # Check for frame source
    #
    if ( defined( $attr{"src"} ) ) {
        $src = $attr{"src"};
        $abs_url = Get_Absolute_URL($src, $attr{"onclick"});

        #
        # Check for title
        #
        if ( defined( $attr{"title"} ) ) {
            $title = $attr{"title"};
        }
        else {
            $title = "";
        }

        #
        # Do we have a lang attribute
        #
        $lang = Get_Lang($tag, %attr);
    
        #
        # Save link details.
        #
        $link = link_object->new($src, $abs_url, $title, $tag, $lang,
                                 $line, $column,
                                 $content_lines[$line - 1]);
        $link->attr(%attr);
        $link->noscript($inside_noscript);
        push (@$link_object_reference, $link);
        print " Frame at $line, $column src = $src\n" if $debug;

        #
        # Save link object in subsection list
        #
        Save_Link_In_Subsection_List($link);

        #
        # Do we have alt text ?
        #
        if ( defined($attr{"alt"}) ) {
            $link->alt($attr{"alt"});
        }

        #
        # Do we have a title ?
        #
        if ( defined($attr{"title"}) ) {
            $link->title($attr{"title"});
        }
    }
}

#***********************************************************************
#
# Name: Embed_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the embed tag, it looks for a src attribute.
#
#***********************************************************************
sub Embed_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($src, $title, $lang, $link, $abs_url, $subsection, $subsection_link_list);

    #
    # Check for embed source
    #
    if ( defined( $attr{"src"} ) ) {
        $src = $attr{"src"};
        $abs_url = Get_Absolute_URL($src, $attr{"onclick"});

        #
        # Check for title
        #
        if ( defined( $attr{"title"} ) ) {
            $title = $attr{"title"};
        }
        else {
            $title = "";
        }

        #
        # Do we have a lang attribute
        #
        $lang = Get_Lang("embed", %attr);

        #
        # Save link details.
        #
        $link = link_object->new($src, $abs_url, $title, "embed", $lang,
                                 $line, $column,
                                 $content_lines[$line - 1]);
        $link->attr(%attr);
        $link->noscript($inside_noscript);
        push (@$link_object_reference, $link);
        print " Embed at $line, $column src = $src\n" if $debug;

        #
        # Save link object in subsection list
        #
        Save_Link_In_Subsection_List($link);

        #
        # Do we have alt text ?
        #
        if ( defined($attr{"alt"}) ) {
            $link->alt($attr{"alt"});
        }

        #
        # Do we have a title ?
        #
        if ( defined($attr{"title"}) ) {
            $link->title($attr{"title"});
        }
    }
}

#***********************************************************************
#
# Name: Area_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles area tags.
#
#***********************************************************************
sub Area_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($href, $lang, $link, $abs_url, $subsection, $subsection_link_list);

    #
    # Do we have an href attribute
    #
    if ( defined( $attr{"href"} ) ) {
        $href = $attr{"href"};
        $abs_url = Get_Absolute_URL($href, $attr{"onclick"});

        #
        # Do we have a lang attribute
        #
        $lang = Get_Lang("area", %attr);

        #
        # Save link details.
        #
        $link = link_object->new($href, $abs_url, "", "area", $lang,
                                 $line, $column,
                                 $content_lines[$line - 1]);
        $link->attr(%attr);
        $link->noscript($inside_noscript);
        push (@$link_object_reference, $link);
        print " Area at $line, $column href = $href\n" if $debug;

        #
        # Save link object in subsection list
        #
        Save_Link_In_Subsection_List($link);

        #
        # Do we have alt text ?
        #
        if ( defined($attr{"alt"}) ) {
            $link->alt($attr{"alt"});
        }
    }
}

#***********************************************************************
#
# Name: Audio_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the audio tag.
#
#***********************************************************************
sub Audio_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($src, $link, $lang, $abs_url, $subsection, $subsection_link_list);

    #
    # Do we have a src attribute
    #
    if ( defined( $attr{"src"} ) ) {
        $src = $attr{"src"};
        $abs_url = Get_Absolute_URL($src, $attr{"onclick"});

        #
        # Do we have a lang attribute
        #
        $lang = Get_Lang("audio", %attr);

        #
        # Save link details.
        #
        $link = link_object->new($src, $abs_url, "", "audio", $lang,
                                 $line, $column,
                                 $content_lines[$line - 1]);
        $link->attr(%attr);
        $link->noscript($inside_noscript);
        push (@$link_object_reference, $link);
        print " Audio at $line, $column src = $src\n" if $debug;

        #
        # Save link object in subsection list
        #
        Save_Link_In_Subsection_List($link);

        #
        # Do we have alt text ?
        #
        if ( defined($attr{"alt"}) ) {
            $link->alt($attr{"alt"});
        }

        #
        # Do we have a title ?
        #
        if ( defined($attr{"title"}) ) {
            $link->title($attr{"title"});
        }
    }
}

#***********************************************************************
#
# Name: Object_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles object tags.
#
#***********************************************************************
sub Object_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($href, $lang, $link, $abs_url, $subsection, $subsection_link_list);

    #
    # Do we have a data attribute
    #
    if ( defined( $attr{"data"} ) ) {
        $href = $attr{"data"};
        $abs_url = Get_Absolute_URL($href, $attr{"onclick"});

        #
        # Do we have a lang attribute
        #
        $lang = Get_Lang("object", %attr);

        #
        # Save link details.
        #
        $link = link_object->new($href, $abs_url, "", "object", $lang,
                                 $line, $column,
                                 $content_lines[$line - 1]);
        $link->attr(%attr);
        $link->noscript($inside_noscript);
        push (@$link_object_reference, $link);
        print " Object at $line, $column data = $href\n" if $debug;

        #
        # Save link object in subsection list
        #
        Save_Link_In_Subsection_List($link);

        #
        # Do we have alt text ?
        #
        if ( defined($attr{"alt"}) ) {
            $link->alt($attr{"alt"});
        }
    }

    #
    # Add a text handler to save the text portion of the object
    # tag.
    #
    Start_Text_Handler($self, "object");
    push(@object_reference_list, $link);
}

#***********************************************************************
#
# Name: End_Object_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end object </object> tag.
#
#***********************************************************************
sub End_Object_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($all_object_text, $current_object_reference);

    #
    # Check for text handler, if we don't have one this may be a stray
    # close object.
    #
    if ( ! $have_text_handler ) {
        print "No text handler in end object tag found at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get all the text found within the object tag
    #
    $all_object_text = Clean_Text(Get_Text_Handler_Content($self, " "));

    #
    # Save object text
    #
    $current_object_reference = pop(@object_reference_list);
    if ( defined($current_object_reference) ) {
        $current_object_reference->alt($all_object_text);
        $current_object_reference->has_alt(1);
        print "Object text = $all_object_text\n" if $debug;

        #
        # Destroy the text handler that was used to save the text
        # portion of the object tag.
        #
        Destroy_Text_Handler($self, "object");
    }
}

#***********************************************************************
#
# Name: Link_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles link tags.
#
#***********************************************************************
sub Link_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($href, $lang, $link, $abs_url, $subsection, $subsection_link_list);

    #
    # Do we have an href attribute
    #
    if ( defined( $attr{"href"} ) ) {
        $href = $attr{"href"};
        $abs_url = Get_Absolute_URL($href, $attr{"onclick"});

        #
        # Do we have a lang attribute
        #
        $lang = Get_Lang("link", %attr);

        #
        # Save link details.
        #
        $link = link_object->new($href, $abs_url, "", "link", $lang,
                                 $line, $column,
                                 $content_lines[$line - 1]);
        $link->attr(%attr);
        $link->noscript($inside_noscript);
        push (@$link_object_reference, $link);
        print " Link at $line, $column href = $href\n" if $debug;

        #
        # Save link object in subsection list
        #
        Save_Link_In_Subsection_List($link);

        #
        # Do we have alt text ?
        #
        if ( defined($attr{"alt"}) ) {
            $link->alt($attr{"alt"});
        }

        #
        # Do we have a title ?
        #
        if ( defined($attr{"title"}) ) {
            $link->title($attr{"title"});
        }
    }
}

#***********************************************************************
#
# Name: Longdesc_Attribute_Handler
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
#   This function handles longdesc attributes.
#
#***********************************************************************
sub Longdesc_Attribute_Handler {
    my ( $self, $tagname, $line, $column, $text, %attr ) = @_;

    my ($href, $lang, $link, $abs_url, $subsection, $subsection_link_list);

    #
    # Do we have an longdesc attribute
    #
    if ( defined( $attr{"longdesc"} ) ) {
        $href = $attr{"href"};
        $abs_url = Get_Absolute_URL($href, $attr{"onclick"});

        #
        # Do we have a lang attribute
        #
        $lang = Get_Lang($tagname, %attr);

        #
        # Save link details.
        #
        $link = link_object->new($href, $abs_url, "", $tagname, $lang,
                                 $line, $column,
                                 $content_lines[$line - 1]);
        $link->attr(%attr);
        $link->noscript($inside_noscript);
        push (@$link_object_reference, $link);
        print " Longdesc at $line, $column href = $href\n" if $debug;

        #
        # Save link object in subsection list
        #
        Save_Link_In_Subsection_List($link);
    }
}

#***********************************************************************
#
# Name: Cite_Attribute_Handler
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
#   This function handles cite attributes.
#
#***********************************************************************
sub Cite_Attribute_Handler {
    my ( $self, $tagname, $line, $column, $text, %attr ) = @_;

    my ($href, $lang, $link, $abs_url, $subsection, $subsection_link_list);

    #
    # Do we have a cite attribute
    #
    if ( defined( $attr{"cite"} ) ) {
        $href = $attr{"href"};
        $abs_url = Get_Absolute_URL($href, $attr{"onclick"});

        #
        # Do we have a lang attribute
        #
        $lang = Get_Lang($tagname, %attr);

        #
        # Save link details.
        #
        $link = link_object->new($href, $abs_url, "", $tagname, $lang,
                                 $line, $column,
                                 $content_lines[$line - 1]);
        $link->attr(%attr);
        $link->noscript($inside_noscript);
        push (@$link_object_reference, $link);
        print " cite at $line, $column href = $href\n" if $debug;

        #
        # Save link object in subsection list
        #
        Save_Link_In_Subsection_List($link);
    }
}

#***********************************************************************
#
# Name: Image_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the image tag.
#
#***********************************************************************
sub Image_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($src, $lang, $link, $abs_url, $subsection, $subsection_link_list);

    #
    # Do we have a src attribute
    #
    if ( defined( $attr{"src"} ) ) {
        $src = $attr{"src"};
        $abs_url = Get_Absolute_URL($src, $attr{"onclick"});

        #
        # Do we have a lang attribute
        #
        $lang = Get_Lang("img", %attr);

        #
        # Save link details.
        #
        $link = link_object->new($src, $abs_url, "", "img", $lang,
                                 $line, $column,
                                 $content_lines[$line - 1]);
        $link->attr(%attr);
        $link->noscript($inside_noscript);
        push (@$link_object_reference, $link);
        print " Image at $line, $column src = $src\n" if $debug;

        #
        # Save link object in subsection list
        #
        Save_Link_In_Subsection_List($link);

        #
        # Do we have alt text ?
        #
        if ( defined($attr{"alt"}) ) {
            $link->alt($attr{"alt"});
            
            #
            # If we have a text handler we must be inside another tag
            # (e.g. <a>).  If so, the alt text forms part of that tags
            # content.
            #
            if ( $have_text_handler ) {
                push(@{ $self->handler("text")}, $attr{"alt"});
            }
        }
        else {
            #
            # No alt attribute, are we inside a figure ? If so
            # a figcaption can act as alt text.
            #
            if ( $inside_figure ) {
                print "Image with no alt inside a figure\n" if $debug;
                $image_in_figure_with_no_alt = 1;
                $last_image_link = $link;
            }
        }

        #
        # Do we have a title ?
        #
        if ( defined($attr{"title"}) ) {
            $link->title($attr{"title"});
            
            #
            # Are we inside an <a> tag ? if so, the title text forms
            # part of that tags content.
            #
            if ( $inside_anchor ) {
                push(@{ $self->handler("text")}, $attr{"title"});
            }
        }
    }
    
    #
    # Is this image tag contained within an anchor tag ?
    #
    if ( defined($current_anchor_reference) ) {
        print "img tag inside a tag\n" if $debug;
        $current_anchor_reference->has_img(1);
        
        if ( defined($link) ) {
            $link->in_anchor(1);
        }
    }
}

#***********************************************************************
#
# Name: Input_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the input tag.
#
#***********************************************************************
sub Input_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($src, $lang, $link, $abs_url, $subsection, $subsection_link_list);

    #
    # Do we have an image type of input ?
    #
    if ( defined($attr{"type"}) && ($attr{"type"} =~ /image/i) ) {
            #
        # Do we have a src attribute
        #
        if ( defined( $attr{"src"} ) ) {
            $src = $attr{"src"};
            $abs_url = Get_Absolute_URL($src, $attr{"onclick"});

            #
            # Do we have a lang attribute
            #
            $lang = Get_Lang("input", %attr);

            #
            # Save link details.
            #
            $link = link_object->new($src, $abs_url, "", "input", $lang,
                                     $line, $column,
                                     $content_lines[$line - 1]);
            $link->attr(%attr);
            $link->noscript($inside_noscript);
            push (@$link_object_reference, $link);
            print " Image in input at $line, $column src = $src\n" if $debug;

            #
            # Save link object in subsection list
            #
            Save_Link_In_Subsection_List($link);

            #
            # Do we have alt text ?
            #
            if ( defined($attr{"alt"}) ) {
                $link->alt($attr{"alt"});
            }

            #
            # Do we have a title ?
            #
            if ( defined($attr{"title"}) ) {
                $link->title($attr{"title"});
            }
        }
    }
}

#***********************************************************************
#
# Name: Noscript_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the noscript tag.  It sets a flag to indicate
# that we are inside a <noscript> .. </noscript> tag pair.
#
#***********************************************************************
sub Noscript_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # We are inside a noscript section
    #
    $inside_noscript = 1;
}

#***********************************************************************
#
# Name: End_Noscript_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the end noscript tag.  It resets a flag to indicate
# that we are no longer inside a <noscript> .. </noscript> tag pair.
#
#***********************************************************************
sub End_Noscript_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # We are no longer inside a noscript section
    #
    $inside_noscript = 0;
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
#   This function handles the script tag.
#
#***********************************************************************
sub Script_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($src, $link, $lang, $abs_url, $subsection, $subsection_link_list);

    #
    # Do we have a src attribute
    #
    if ( defined( $attr{"src"} ) ) {
        $src = $attr{"src"};
        $abs_url = Get_Absolute_URL($src, $attr{"onclick"});

        #
        # Do we have a lang attribute
        #
        $lang = Get_Lang("script", %attr);

        #
        # Save link details.
        #
        $link = link_object->new($src, $abs_url, "", "script", $lang,
                                 $line, $column,
                                 $content_lines[$line - 1]);
        $link->attr(%attr);
        $link->noscript($inside_noscript);
        push (@$link_object_reference, $link);
        print " Script at $line, $column src = $src\n" if $debug;

        #
        # Save link object in subsection list
        #
        Save_Link_In_Subsection_List($link);

        #
        # Do we have alt text ?
        #
        if ( defined($attr{"alt"}) ) {
            $link->alt($attr{"alt"});
        }

        #
        # Do we have a title ?
        #
        if ( defined($attr{"title"}) ) {
            $link->title($attr{"title"});
        }
    }
}

#***********************************************************************
#
# Name: Source_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the source tag.
#
#***********************************************************************
sub Source_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($src, $link, $lang, $abs_url, $subsection, $subsection_link_list);

    #
    # Do we have a src attribute
    #
    if ( defined( $attr{"src"} ) ) {
        $src = $attr{"src"};
        $abs_url = Get_Absolute_URL($src, $attr{"onclick"});

        #
        # Do we have a lang attribute
        #
        $lang = Get_Lang("source", %attr);

        #
        # Save link details.
        #
        $link = link_object->new($src, $abs_url, "", "source", $lang,
                                 $line, $column,
                                 $content_lines[$line - 1]);
        $link->attr(%attr);
        $link->noscript($inside_noscript);
        push (@$link_object_reference, $link);
        print " Source at $line, $column src = $src\n" if $debug;

        #
        # Save link object in subsection list
        #
        Save_Link_In_Subsection_List($link);

        #
        # Do we have alt text ?
        #
        if ( defined($attr{"alt"}) ) {
            $link->alt($attr{"alt"});
        }

        #
        # Do we have a title ?
        #
        if ( defined($attr{"title"}) ) {
            $link->title($attr{"title"});
        }
    }
}

#***********************************************************************
#
# Name: Span_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the span tag.  It checks for a lang
# attribute, and if found, sets the current language value.
#
#***********************************************************************
sub Span_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($lang);

    #
    # Do we have a lang attribute
    #
    if ( defined($attr{"lang"}) && ($attr{"lang"} ne "") ) {
        $lang = $attr{"lang"};

        #
        # Convert possible 2 character code into a 3 character code.
        #
        if ( defined($language_map::iso_639_1_iso_639_2T_map{$lang}) ) {
            $lang = $language_map::iso_639_1_iso_639_2T_map{$lang};
        }
    }
    else {
        #
        # No lang, or lang is blank.  Use the current lang value.
        # We need to do this so we can push a value onto the
        # language stack.  We pop a value in the end span tag handler,
        # so we always have to push a value to balance the pop.
        #
        $lang = $current_lang;
    }

    #
    # Save current language on the language stack and
    # set the current language to that found in the lang
    # attribute.
    #
    print "Span tag, new current language = $lang\n" if $debug;
    push(@lang_stack, $current_lang);
    $current_lang = $lang;
}

#***********************************************************************
#
# Name: Track_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the track tag.
#
#***********************************************************************
sub Track_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($src, $link, $lang, $abs_url, $subsection, $subsection_link_list);

    #
    # Do we have a src attribute
    #
    if ( defined( $attr{"src"} ) ) {
        $src = $attr{"src"};
        $abs_url = Get_Absolute_URL($src, $attr{"onclick"});

        #
        # Do we have a lang attribute
        #
        $lang = Get_Lang("track", %attr);

        #
        # Save link details.
        #
        $link = link_object->new($src, $abs_url, "", "track", $lang,
                                 $line, $column,
                                 $content_lines[$line - 1]);
        $link->attr(%attr);
        $link->noscript($inside_noscript);
        push (@$link_object_reference, $link);
        print " Track at $line, $column src = $src\n" if $debug;

        #
        # Save link object in subsection list
        #
        Save_Link_In_Subsection_List($link);

        #
        # Do we have alt text ?
        #
        if ( defined($attr{"alt"}) ) {
            $link->alt($attr{"alt"});
        }

        #
        # Do we have a title ?
        #
        if ( defined($attr{"title"}) ) {
            $link->title($attr{"title"});
        }
    }
}

#***********************************************************************
#
# Name: Video_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the video tag.
#
#***********************************************************************
sub Video_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    my ($src, $link, $lang, $abs_url, $subsection, $subsection_link_list);
    my ($poster);

    #
    # Do we have a src attribute
    #
    if ( defined( $attr{"src"} ) ) {
        $src = $attr{"src"};
        $abs_url = Get_Absolute_URL($src, $attr{"onclick"});

        #
        # Do we have a lang attribute
        #
        $lang = Get_Lang("video", %attr);

        #
        # Save link details.
        #
        $link = link_object->new($src, $abs_url, "", "video", $lang,
                                 $line, $column,
                                 $content_lines[$line - 1]);
        $link->attr(%attr);
        $link->noscript($inside_noscript);
        push (@$link_object_reference, $link);
        print " Video at $line, $column src = $src\n" if $debug;

        #
        # Save link object in subsection list
        #
        Save_Link_In_Subsection_List($link);

        #
        # Do we have alt text ?
        #
        if ( defined($attr{"alt"}) ) {
            $link->alt($attr{"alt"});
        }

        #
        # Do we have a title ?
        #
        if ( defined($attr{"title"}) ) {
            $link->title($attr{"title"});
        }
    }

    #
    # Do we have a poster attribute
    #
    if ( defined( $attr{"poster"} ) ) {
        $poster = $attr{"poster"};
        $abs_url = Get_Absolute_URL($poster, $attr{"onclick"});

        #
        # Do we have a lang attribute
        #
        $lang = Get_Lang("video", %attr);

        #
        # Save link details.
        #
        $link = link_object->new($poster, $abs_url, "", "video", $lang,
                                 $line, $column,
                                 $content_lines[$line - 1]);
        $link->attr(%attr);
        $link->noscript($inside_noscript);
        push (@$link_object_reference, $link);
        print " Video at $line, $column poster = $poster\n" if $debug;

        #
        # Save link object in subsection list
        #
        Save_Link_In_Subsection_List($link);

        #
        # Do we have alt text ?
        #
        if ( defined($attr{"alt"}) ) {
            $link->alt($attr{"alt"});
        }

        #
        # Do we have a title ?
        #
        if ( defined($attr{"title"}) ) {
            $link->title($attr{"title"});
        }
    }
}

#***********************************************************************
#
# Name: Check_Lang_Attribute
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             attr - hash table of attributes
#
# Description:
#
#   This function checks for a lang attribute in the tag.  If found
# it updates the current language value and records the previous language
# and tag in a stack so we can revert to the previous language
# when we end this tag.
#
#***********************************************************************
sub Check_Lang_Attribute {
    my ( $tagname, $line, $column, @attr ) = @_;

    my (%attr_hash) = @attr;
    my ($lang);
    
    #
    # Check for a lang attribute
    #
    if ( defined($attr_hash{"lang"}) ) {
        $lang = lc($attr_hash{"lang"});
        
        #
        # Remove any language dialect
        #
        $lang =~ s/-.*$//g;
        print "Found lang $lang in $tagname\n" if $debug;
    }
    #
    # Check for xml:lang (ignore the possibility that there is both
    # a lang and xml:lang and that they could be different).
    #
    elsif ( defined($attr_hash{"xml:lang"})) {
        $lang = lc($attr_hash{"xml:lang"});

        #
        # Remove any language dialect
        #
        $lang =~ s/-.*$//g;
        print "Found xml:lang $lang in $tagname\n" if $debug;
    }
    
    #
    # Did we find a language attribute ?
    #
    if ( defined($lang) ) {
        #
        # Convert possible 2 character code into a 3 character code.
        #
        if ( defined($language_map::iso_639_1_iso_639_2T_map{$lang}) ) {
            $lang = $language_map::iso_639_1_iso_639_2T_map{$lang};
        }

        #
        # Does this tag have a matching end tag ?
        # 
        if ( ! defined ($html_tags_with_no_end_tag{$tagname}) ) {
            #
            # Update the current language and push this one on the language
            # stack. Save the current tag name also.
            #
            push(@lang_stack, $current_lang);
            push(@tag_lang_stack, $last_lang_tag);
            $last_lang_tag = $tagname;
            $current_lang = $lang;
            print "Push $tagname, $current_lang on language stack\n" if $debug;
        }
    }
    else {
        #
        # No language.  If this tagname is the same as the last one with a
        # language, pretend this one has a language also.  This avoids
        # premature ending of a language span when the end tag is reached
        # (and the language is popped off the stack).
        #
        if ( $tagname eq $last_lang_tag ) {
            push(@lang_stack, $current_lang);
            push(@tag_lang_stack, $tagname);
            print "Push copy of $tagname, $current_lang on language stack\n"
              if $debug;
        }
    }
}

#***********************************************************************
#
# Name: End_Tag_Lang_Attribute
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             attr - hash table of attributes
#
# Description:
#
#   This function checks to see if this tag is the end tag
# for a tag that contained a lang attribute.  If it does end
# a language span, the current language is set to the language of
# the outer span.
#
#***********************************************************************
sub End_Tag_Lang_Attribute {
    my ( $tagname, $line, $column, @attr ) = @_;

    my (%attr_hash) = @attr;
    
    #
    # Is this tag the last one that had a language ?
    #
    if ( $tagname eq $last_lang_tag ) {
        #
        # Pop the last language and tag name from the stacks
        #
        print "End $tagname found\n" if $debug;
        $current_lang = pop(@lang_stack);
        $last_lang_tag = pop(@tag_lang_stack);
        if ( ! defined($last_lang_tag) ) {
            print "last_lang_tag not defined\n" if $debug;
            $last_lang_tag = "";
            $current_lang = "eng";
        }
        print "Pop $last_lang_tag, $current_lang from language stack\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Start_H_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - heading tag name
#             line - line number
#             column - column number
#             text - text from tag
#             level - heading level
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the h tag, it checks to see if headings
# are created in order (h1, h2, h3, ...).
#
#***********************************************************************
sub Start_H_Tag_Handler {
    my ( $self, $tagname, $line, $column, $text, %attr ) = @_;

    my ($level);

    #
    # Get heading level number from the tag
    #
    $level = $tagname;
    $level =~ s/^h//g;
    print "Found heading $tagname\n" if $debug;

    #
    # Add a text handler to save the text portion of the h
    # tag.
    #
    Start_Text_Handler($self, $tagname);
}

#***********************************************************************
#
# Name: End_H_Tag_Handler
#
# Parameters: self - reference to this parser
#             tagname - heading tag name
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end h tag.
#
#***********************************************************************
sub End_H_Tag_Handler {
    my ( $self, $tagname, $line, $column, $text ) = @_;

    my ($level);

    #
    # Get all the text found within the h tag
    #
    if ( ! $have_text_handler ) {
        print "End h tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get heading level number from the tag
    #
    $level = $tagname;
    $level =~ s/^h//g;

    #
    # Get the heading text as a string
    #
    $last_heading_text = Clean_Text(Get_Text_Handler_Content($self, " "));
    print "End_H_Tag_Handler: text = \"$last_heading_text\"\n" if $debug;

    #
    # Destroy the text handler that was used to save the text
    # portion of the h tag.
    #
    Destroy_Text_Handler($self, "h$level");
}

#***********************************************************************
#
# Name: Ol_Ul_Tag_Handler
#
# Parameters: self - reference to this parser
#             tag - list tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the ol and ul tags.
#
#***********************************************************************
sub Ol_Ul_Tag_Handler {
    my ( $self, $tag, $line, $column, $text, %attr ) = @_;

    #
    # Increment list level count and set inside list item flag
    #
    $current_list_level++;
    $inside_list_item[$current_list_level] = 0;
    $list_location[$current_list_level] = "$line:$column";
    print "Start new list $tag, level $current_list_level\n" if $debug;
}

#***********************************************************************
#
# Name: End_Ol_Ul_Tag_Handler
#
# Parameters: tag - list tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end ol or ul tags.
#
#***********************************************************************
sub End_Ol_Ul_Tag_Handler {
    my ( $tag, $line, $column, $text ) = @_;

    #
    # Decrement list level count and clear inside list item flag
    #
    if ( $current_list_level > -1 ) {
        $inside_list_item[$current_list_level] = 0;
        $list_location[$current_list_level] = "";
        print "End list $tag, level $current_list_level\n" if $debug;
        $current_list_level--;
    }
}

#***********************************************************************
#
# Name: Li_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the li tag.
#
#***********************************************************************
sub Li_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Set flag to indicate we are inside a list item
    #
    if ( $current_list_level > -1 ) {
        $inside_list_item[$current_list_level] = 1;
        print "Start list item in list level $current_list_level\n" if $debug;
    }
    else {
        print "Open li outside of list, level = $current_list_level\n" if $debug;
    }
}

#***********************************************************************
#
# Name: End_Li_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end li tag.
#
#***********************************************************************
sub End_Li_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;
    
    #
    # Set flag to indicate we are no longer inside a list item
    #
    if ( $current_list_level > -1 ) {
        $inside_list_item[$current_list_level] = 0;
        print "End list item in list level $current_list_level\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Figure_Tag_Handler
#
# Parameters: self - reference to this parser
#             tag - list tag
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the figure tag.
#
#***********************************************************************
sub Figure_Tag_Handler {
    my ( $self, $tag, $line, $column, $text, %attr ) = @_;

    #
    # Set flag to indicate we are inside a figure
    #
    $inside_figure = 1;
    $have_figcaption = 0;
    $image_in_figure_with_no_alt = 0;
    $figcaption_text = "";
    print "Start figure\n" if $debug;
}

#***********************************************************************
#
# Name: End_Figure_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end figure tag.
#
#***********************************************************************
sub End_Figure_Tag_Handler {
    my ($self, $line, $column, $text ) = @_;

    #
    # Did we have a figcaption in this figure ?
    #
    if ( $have_figcaption ) {
        #
        # Did we have an image inside the figure ?
        #
        if ( $image_in_figure_with_no_alt ) {
            #
            # Set the last image's alt text to the figure caption
            #
            $last_image_link->alt($figcaption_text);
            $last_image_link->has_alt(1);
            print "Set last image's alt to the figure caption\n" if $debug;
        }
    }

    #
    # Clear flag to indicate we are inside a figure
    #
    $inside_figure = 0;
    $have_figcaption = 0;
    $image_in_figure_with_no_alt = 0;
    print "End figure\n" if $debug;
}

#***********************************************************************
#
# Name: Figcaption_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the figcaption tag.
#
#***********************************************************************
sub Figcaption_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Add a text handler to save the text portion of the figcaption
    # tag.
    #
    Start_Text_Handler($self, "figcaption");
    print "Start figcaption\n" if $debug;
}

#***********************************************************************
#
# Name: End_Figcaption_Tag_Handler
#
# Parameters: self - reference to this parser
#             tag - list tag
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the figcaption tag.
#
#***********************************************************************
sub End_Figcaption_Tag_Handler {
    my ( $self, $tag, $line, $column, $text ) = @_;

    #
    # Check for text handler, if we don't have one this may be a stray
    # close figcaption.
    #
    if ( ! $have_text_handler ) {
        print "No text handler in end figcaption tag found at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get all the text found within the figcaption tag
    #
    $figcaption_text = Clean_Text(Get_Text_Handler_Content($self, " "));
    if ( $figcaption_text ne "" ) {
        $have_figcaption = 1;
    }
    print "Figcaption text = $figcaption_text\n" if $debug;

    #
    # Destroy the text handler that was used to save the text
    # portion of the figcaption tag.
    #
    Destroy_Text_Handler($self, "figcaption");
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

    #
    # Check for start of content section
    #
    $content_section_handler->check_start_tag($tagname, $line, $column,
                                              %attr_hash);

    #
    # Check for lang attribute
    #
    Check_Lang_Attribute($tagname, $line, $column, @attr);

    #
    # Check anchor tag
    #
    if ( $tagname eq "a" ) {
        Anchor_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check area tag
    #
    elsif ( $tagname eq "area" ) {
        Area_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check audio tag
    #
    elsif ( $tagname eq "audio" ) {
        Audio_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check body tag
    #
    elsif ( $tagname eq "body" ) {
        print "Start of body, end of head section\n" if $debug;
        $in_head_section = 0;
    }
    #
    # Check br tag
    #
    elsif ( $tagname eq "br" ) {
        if ( $have_text_handler ) {
            push(@{ $self->handler("text")}, " ");
        }
    }
    #
    # Check embed tag
    #
    elsif ( $tagname eq "embed" ) {
        Embed_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check figcaption tag
    #
    elsif ( $tagname eq "figcaption" ) {
        Figcaption_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check figure tag
    #
    elsif ( $tagname eq "figure" ) {
        Figure_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check frame tag
    #
    elsif ( $tagname eq "frame" ) {
        Frame_Tag_Handler( $self, "frame", $line, $column, $text, %attr_hash );
    }
    #
    # Check h tag
    #
    elsif ( $tagname =~ /^h[0-9]?$/ ) {
        Start_H_Tag_Handler( $self, $tagname, $line, $column, $text,
                            %attr_hash );
    }
    #
    # Check head tag
    #
    elsif ( $tagname eq "head" ) {
        print "Start of head section\n" if $debug;
        $in_head_section = 1;
    }
    #
    # Check iframe tag
    #
    elsif ( $tagname eq "iframe" ) {
        Frame_Tag_Handler( $self, "iframe", $line, $column, $text, %attr_hash );
    }
    #
    # Check img tag
    #
    elsif ( $tagname eq "img" ) {
        Image_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check input tag
    #
    elsif ( $tagname eq "input" ) {
        Input_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check li tag
    #
    elsif ( $tagname eq "li" ) {
        Li_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check link tag
    #
    elsif ( $tagname eq "link" ) {
        Link_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check noscript tag
    #
    elsif ( $tagname eq "noscript" ) {
        Noscript_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check object tag
    #
    elsif ( $tagname eq "object" ) {
        Object_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check ol tag
    #
    elsif ( $tagname eq "ol" ) {
        Ol_Ul_Tag_Handler( $self, $tagname, $line, $column, $text, %attr_hash );
    }
    #
    # Check script tag
    #
    elsif ( $tagname eq "script" ) {
        Script_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check source tag
    #
    elsif ( $tagname eq "source" ) {
        Source_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check track tag
    #
    elsif ( $tagname eq "track" ) {
        Track_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check ul tag
    #
    elsif ( $tagname eq "ul" ) {
        Ol_Ul_Tag_Handler( $self, $tagname, $line, $column, $text, %attr_hash );
    }
    #
    # Check video tag
    #
    elsif ( $tagname eq "video" ) {
        Video_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Check longdesc attribute
    #
    if ( defined($attr_hash{"longdesc"}) ) {
        Longdesc_Attribute_Handler( $self, $tagname, $line, $column, $text,
                                    %attr_hash );
    }

    #
    # Check cite attribute
    #
    if ( defined($attr_hash{"cite"}) ) {
        Cite_Attribute_Handler( $self, $tagname, $line, $column, $text,
                                    %attr_hash );
    }
}

#***********************************************************************
#
# Name: End_Anchor_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end anchor </a> tag.
#
#***********************************************************************
sub End_Anchor_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($all_anchor_text);

    #
    # Check for text handler, if we don't have one this may be a stray
    # close anchor, or the open anchor did not have a href attribute.
    #
    $inside_anchor = 0;
    if ( ! $have_text_handler ) {
        print "No text handler in end anchor tag found at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Get all the text found within the anchor tag
    #
    $all_anchor_text = Clean_Text(Get_Text_Handler_Content($self, " "));

    #
    # Save anchor text
    #
    if ( defined($current_anchor_reference) ) {
        $current_anchor_reference->anchor($all_anchor_text);
        print "Anchor text = $all_anchor_text\n" if $debug;

        #
        # Destroy the text handler that was used to save the text
        # portion of the anchor tag.
        #
        Destroy_Text_Handler($self, "a");
        undef $current_anchor_reference;
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
# handles the start of HTML tags.
#
#***********************************************************************
sub End_Handler {
    my ( $self, $tagname, $line, $column, $text, @attr ) = @_;

    my (%attr_hash) = @attr;

    #
    # Check anchor tags
    #
    if ( $tagname eq "a" ) {
        End_Anchor_Tag_Handler($self, $line, $column, $text);
    }
    #
    # Check figcaption tag
    #
    elsif ( $tagname eq "figcaption" ) {
        End_Figcaption_Tag_Handler( $self, $line, $column, $text );
    }
    #
    # Check figure tag
    #
    elsif ( $tagname eq "figure" ) {
        End_Figure_Tag_Handler( $self, $line, $column, $text );
    }
    #
    # Check head tag
    #
    elsif ( $tagname eq "head" ) {
        print "End of head section\n" if $debug;
        $in_head_section = 0;
    }

    #
    # Check heading tag
    #
    elsif ( $tagname =~ /^h[0-9]?$/ ) {
        End_H_Tag_Handler($self, $tagname, $line, $column, $text);
    }
    #
    # Check li tag
    #
    elsif ( $tagname eq "li" ) {
        End_Li_Tag_Handler( $self, $line, $column, $text );
    }
    #
    # Check noscript tags
    #
    elsif ( $tagname eq "noscript" ) {
        End_Noscript_Tag_Handler($self, $line, $column, $text);
    }
    #
    # Check object tags
    #
    elsif ( $tagname eq "object" ) {
        End_Object_Tag_Handler($self, $line, $column, $text);
    }
    #
    # Check ol tag
    #
    elsif ( $tagname eq "ol" ) {
        End_Ol_Ul_Tag_Handler($tagname, $line, $column, $text);
    }
    #
    # Check ul tag
    #
    elsif ( $tagname eq "ul" ) {
        End_Ol_Ul_Tag_Handler($tagname, $line, $column, $text);
    }

    #
    # Check for the end tag for one that had a lang attribute
    #
    End_Tag_Lang_Attribute($tagname, $line, $column, @attr);

    #
    # Check for end of a document section
    #
    $content_section_handler->check_end_tag($tagname, $line, $column);
}

#***********************************************************************
#
# Name: HTML_Extract_Links
#
# Parameters: this_url - URL of document to extract links from
#             this_base - the base value from the response object (resp->base)
#             this_lang - language of URL
#             content - content pointer
#
# Description:
#
#   This function extracts links from the supplied HTML content and
# returns the details as an array of link objects.
#
#***********************************************************************
sub HTML_Extract_Links {
    my ( $this_url, $this_base, $this_lang, $content ) = @_;

    my ($parser, $i, @link_objects, $link, $link_addr, $subsection_name);

    #
    # Save addresses of link object array in a global variable.
    #
    print "HTML_Extract_Links\n" if $debug;
    $link_object_reference = \@link_objects;
    
    #
    # Save current language setting and response base value
    #
    $current_lang = $this_lang;
    $current_resp_base = $this_base;

    #
    # Initialize parser variables.
    #
    Initialize_Link_Parser_Variables;

    #
    # Split the content into lines
    #
    @content_lines = split( /\n/, $$content );

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

    #
    # Print out each sections link set
    #
    if ( $debug ) {
        foreach $subsection_name (sort(keys %subsection_links)) {
            print "Extract_Links::HTML_Extract_Links, subsection = $subsection_name\n";
            if ( defined($subsection_links{$subsection_name}) ) {
                $link_addr = $subsection_links{$subsection_name};

                #
                # Print list of links returned
                #
                foreach (@$link_addr) {
                    print "Link at Line/column: " . $_->line_no . ":" . $_->column_no .
                          " type = " . $_->link_type .
                          " lang = " . $_->lang . "\n";
                    print "  Anchor = \"" . $_->anchor .
                          "\" alt = \"" . $_->alt .
                          "\" href = " .
                          $_->abs_url . "\n";
                    print "  modified_content = " . $_->modified_content .
                          "  generated_content = " . $_->generated_content .
                          "\n";
                }
            }
        }
    }

    #
    # Return array of link objects
    #
    print "Found " . @link_objects . " links in HTML content\n" if $debug;
    return(@link_objects);
}

#***********************************************************************
#
# Name: Update_Link_Subsection_Lists
#
# Parameters: links - list of link objects
#
# Description:
#
#   This function processes a list of link objects and copies them
# into a set of subsection link lists.  The module global subsection_links
# hash table is updated.
#
#***********************************************************************
sub Update_Link_Subsection_Lists {
    my (@links) = @_;


    my ($link, $subsection, $subsection_link_list);

    #
    # Clear the existing subsection lists
    #
    %subsection_links = ();

    #
    # Process each link in the list
    #
    foreach $link (@links) {
        #
        # Get the subsection for this link
        #
        $subsection = $link->content_section();

        #
        # Are we missing a list that we can add this link object to ?
        #
        if ( ! defined($subsection_links{$subsection}) ) {
            my (@list);
            $subsection_links{$subsection} = \@list;
        }

        #
        # Add link object to the list for the current subsection
        #
        $subsection_link_list = $subsection_links{$subsection};
        push(@$subsection_link_list, $link);
        #print "Add link object to subsection list $subsection\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Extract_Links_From_HTML
#
# Parameters: url - URL of document to extract links from
#             base - the base value from the response object (resp->base)
#             lang - language of URL
#             mime_type - mime-type of content
#             content - content pointer
#             generated_content - generated content pointer
#
# Description:
#
#   This function extracts links from HTML content.  It extracts links
# from
#   - the original HTML markup,
#   - the markup with conditional control removed,
#   - the generated markup,
#   - any inline CSS markup.
# The link details are returned in an array of link objects.
#
#***********************************************************************
sub Extract_Links_From_HTML {
    my ($url, $base, $lang, $mime_type, $content, $generated_content) = @_;

    my (@links, $link, $anchor_list, $extracted_content, @other_links);
    my ($modified_content, $subsection_name, $link_addr, $orig_link);
    my (%saved_subsection_links, $mlink, $ol, $gl, $i, $j, $resp);
    my (@merged_links, $olink, $glink, $found, $mod_link);

    #
    # Did we get any content ?
    #
    print "Extract_Links_From_HTML\n" if $debug;
    %subsection_links = ();
    if ( length($$content) > 0 ) {
    
        #
        # Get links for original markup
        #
        print "Extract links from original markup\n" if $debug;
        @links = HTML_Extract_Links($url, $base, $lang, $content);
        %saved_subsection_links = %subsection_links;

        #
        # Extract any named anchors from this content.  We don't use
        # them here, but by extracting them now we get them into the
        # anchor cache.
        #
        $anchor_list = Extract_Anchors($url, $resp, $content, 0);

        #
        # Remove conditional comments from the content that control
        # IE file inclusion (conditionals found in WET template files).
        #
        $modified_content = $$content;
        $modified_content =~ s/<!--\[if[^>]*>//g;
        $modified_content =~ s/<!--if[^>]*>//g;
        $modified_content =~ s/<!--<!\[endif\]-->//g;
        $modified_content =~ s/<!--<!endif-->//g;
        $modified_content =~ s/<!\[endif\]-->//g;
        $modified_content =~ s/<!endif-->//g;
        $modified_content =~ s/<!-->//g;

        #
        # Extract links again with the above conditional code removed.
        # We don't do this the first time through in case removing
        # the conditional code fails and corrupts the HTML input.
        #
        %subsection_links = ();
        print "Extract links from modified (removed conditional comments) markup\n" if $debug;
        @other_links = HTML_Extract_Links($url, $base, $lang,
                                          \$modified_content);

        #
        # If we get more links with the conditional code removed, use
        # those links.  If we have fewer links it is possible that the
        # modified content was corrupt.
        #
        if ( @other_links > @links ) {
            print "Use links from modified content\n" if $debug;

            #
            # Set the modified_content flag for the extra links found
            # in the modified content.
            #
            $i = 0;
            foreach $mod_link (@other_links) {
                print "Check modified content link href = " .
                      $mod_link->abs_url . "\n" if $debug;

                #
                # Do we have any links left in the original link list ?
                #
                if ( $i < @links ) {
                    $orig_link = $links[$i];

                    #
                    # Do the href values match ?
                    #
                    if ( $mod_link->abs_url eq $orig_link->abs_url ) {
                        #
                        # Matching URLs, increment the counter for the original list of links
                        #
                        print "Found matching URL in original link list at position $i\n" if $debug;
                        $i++;
                    }
                    else {
                        #
                        # Modified content link found
                        #
                        print "Modified content link found before original link list link # $i\n" if $debug;
                        $mod_link->modified_content(1);
                    }
                }
                else {
                    #
                    # Link from modified content
                    #
                    print "No more original list of links, set modified content flag\n" if $debug;
                    $mod_link->modified_content(1);
                }
            }

            #
            # Save modified content list of links
            #
            @links = @other_links;
            Update_Link_Subsection_Lists(@links);

            #
            # Print out each sections link set
            #
            if ( $debug ) {
                foreach $subsection_name (sort(keys %subsection_links)) {
                    print "Extract_Links_From_HTML, after merging original and modified content links, subsection = $subsection_name\n";
                    if ( defined($subsection_links{$subsection_name}) ) {
                        $link_addr = $subsection_links{$subsection_name};

                        #
                        # Print list of links returned
                        #
                        foreach (@$link_addr) {
                            print "Link at Line/column: " . $_->line_no . ":" . $_->column_no .
                                  " type = " . $_->link_type .
                                  " lang = " . $_->lang . "\n";
                            print "  Anchor = \"" . $_->anchor .
                                  "\" alt = \"" . $_->alt .
                                  "\" href = " .
                                  $_->abs_url . "\n";
                            print "  modified_content = " . $_->modified_content .
                                  "  generated_content = " . $_->generated_content .
                                  "\n";
                        }
                    }
                }
            }
        }
        else {
            #
            # Restore the set of subsection links that were saved
            # after the first call to HTML_Extract_Links
            #
            %subsection_links = %saved_subsection_links;
        }
        
        #
        # Do we have generated markup ?
        #
        if ( defined($generated_content) &&
             (length($$generated_content) > 0) ) {
            print "Extract links from generated content\n" if $debug;
            #
            # Remove conditional comments from the content that control
            # IE file inclusion (conditionals found in WET template files).
            #
            $modified_content = $$generated_content;
            $modified_content =~ s/<!--\[if[^>]*>//g;
            $modified_content =~ s/<!--if[^>]*>//g;
            $modified_content =~ s/<!--<!\[endif\]-->//g;
            $modified_content =~ s/<!--<!endif-->//g;
            $modified_content =~ s/<!\[endif\]-->//g;
            $modified_content =~ s/<!endif-->//g;
            $modified_content =~ s/<!-->//g;

            #
            # Extract links from the generated content.  Save the
            # existing subsection link set and reinitialize it
            # before extracting link information from the generated
            # content.
            #
            %saved_subsection_links = %subsection_links;
            %subsection_links = ();
            @other_links = HTML_Extract_Links($url, $base, $lang,
                                              \$modified_content);

            #
            # Extract any named anchors from this content.  We don't use
            # them here, but by extracting them now we get them into the
            # anchor cache.
            #
            $anchor_list = Extract_Anchors($url, $resp, $generated_content, 1);

            #
            # If we get more links from the generated content, use
            # those links.  If we have fewer links it is possible that the
            # generated content was corrupt.
            #
            print "Merge links from generated content\n" if $debug;
            if ( @other_links > 0 ) {
                #
                # Create a union of the original content links and the
                # generated content links.
                #
                undef $olink;
                $ol = 0;
                if ( $ol < @links ) {
                    $olink = $links[$ol];
                }
                undef $glink;
                $gl = 0;
                if ( $gl < @other_links ) {
                    $glink = $other_links[$gl];
                }
                while ( defined($olink) && defined($glink) ) {
                    #
                    # If the links match for URL, add the generated markup list
                    # link to the merged list.
                    #
                    print "Original content link  # $ol " . $olink->abs_url . "\n" if $debug;
                    print "Generated content link # $gl " . $glink->abs_url . "\n" if $debug;
                    if ( $olink->abs_url eq $glink->abs_url ) {
                        push(@merged_links, $olink);
                        $ol++;
                        $gl++;
                        print "Add to merged list: original link\n" if $debug;
                    }
                    else {
                        #
                        # Links do not match, check to see if the original
                        # content link appears later in the generated
                        # content link (i.e. there is an extra link in the
                        # generated content list).
                        #
                        print "Link mismatch look ahead in generated content list for match\n" if $debug;
                        $found = 0;
                        for ($i = $gl; $i < @other_links; $i++) {
                            $mlink = $other_links[$i];
                            if ( $olink->abs_url eq $mlink->abs_url ) {
                                print "Found link in generated content list at index $i\n" if $debug;
                                $found = 1;
                                last;
                            }
                        }
                        
                        #
                        # Did we find the link ? If so copy all the links before
                        # the match into the merged list
                        #
                        if ( $found ) {
                            for ($j = $gl; $j < $i; $j++) {
                                $mlink = $other_links[$j];
                                $mlink->generated_content(1);
                                push(@merged_links, $mlink);
                                $gl++;
                                print "Add to merged list: generated content link # $j " . $mlink->abs_url . "\n" if $debug;
                            }
                        }
                        else {
                            #
                            # Original link does not appear in generated content links.
                            # Does the generated link appear in the original content
                            # list ?
                            #
                            print "Link mismatch look ahead in original content list for match\n" if $debug;
                            for ($i = $ol; $i < @links; $i++) {
                                $mlink = $links[$i];
                                if ( $glink->abs_url eq $mlink->abs_url ) {
                                    print "Found link in original content list at index $i\n" if $debug;
                                    $found = 1;
                                    last;
                                }
                            }

                            #
                            # Did we find the link ? If so copy all the links before
                            # the match into the merged list
                            #
                            if ( $found ) {
                                for ($j = $ol; $j < $i; $j++) {
                                    $mlink = $links[$j];
                                    push(@merged_links, $mlink);
                                    $ol++;
                                    print "Add to merged list: original content link # $j " . $mlink->abs_url . "\n" if $debug;
                                }
                            }
                            else {
                                #
                                # The 2 links are unique to their respective
                                # content.  Add both links to the merged list.
                                #
                                print "Link appears in original content only\n" if $debug;
                                push(@merged_links, $olink);
                                $ol++;
                                print "Link appears in generated content only\n" if $debug;
                                $glink->generated_content(1);
                                push(@merged_links, $glink);
                                $gl++;
                            }
                        }
                    }
                    
                    #
                    # Get next link in each list
                    #
                    undef $olink;
                    if ( $ol < @links ) {
                        $olink = $links[$ol];
                    }
                    undef $glink;
                    if ( $gl < @other_links ) {
                        $glink = $other_links[$gl];
                    }
                }
                    
                #
                # Do we have any links left in the original link list that
                # did not appear in the generated content ?
                #
                if ( $ol < @links ) {
                    print "Copy remaining links from original content\n" if $debug;
                    for ($j = $ol; $j < @links; $j++) {
                        $mlink = $links[$j];
                        print "Add original content link # $j " . $mlink->abs_url .
                              " to merged list\n" if $debug;
                        push(@merged_links, $mlink);
                    }
                }

                #
                # Do we have any links left in the original link list that
                # did not appear in the generated content ?
                #
                if ( $gl < @other_links ) {
                    print "Copy remaining links from generated content\n" if $debug;
                    for ($j = $gl; $j < @other_links; $j++) {
                        $mlink = $other_links[$j];
                        print "Add generated content link # $j " . $mlink->abs_url .
                              " to merged list\n" if $debug;
                        push(@merged_links, $mlink);
                    }
                }
                
                #
                # Save merged list of links and update the subsection lists
                #
                @links = @merged_links;
                Update_Link_Subsection_Lists(@links);

                #
                # Print out each sections link set
                #
                if ( $debug ) {
                    foreach $subsection_name (sort(keys %subsection_links)) {
                        print "Extract_Links_From_HTML, after merging original and generated content links, subsection = $subsection_name\n";
                        if ( defined($subsection_links{$subsection_name}) ) {
                            $link_addr = $subsection_links{$subsection_name};

                            #
                            # Print list of links returned
                            #
                            foreach (@$link_addr) {
                                print "Link at Line/column: " . $_->line_no . ":" . $_->column_no .
                                      " type = " . $_->link_type .
                                      " lang = " . $_->lang . "\n";
                                print "  Anchor = \"" . $_->anchor .
                                      "\" alt = \"" . $_->alt .
                                      "\" href = " .
                                      $_->abs_url . "\n";
                                print "  modified_content = " . $_->modified_content .
                                      "  generated_content = " . $_->generated_content .
                                      "\n";
                            }
                        }
                    }
                }
            }
            else {
                #
                # Restore the set of subsection links that were saved
                # after the first call to HTML_Extract_Links
                #
                print "No links found in generated content\n" if $debug;
                %subsection_links = %saved_subsection_links;
            }
        }

        #
        # Extract any inline CSS from the HTML and extracts links
        # from it.
        #
        print "Check for inline CSS\n" if $debug;
        $extracted_content = CSS_Validate_Extract_CSS_From_HTML($url, $content);
        if ( length($extracted_content) > 0 ) {
            print "CSS_Extract_Links from inline CSS\n" if $debug;
            @other_links = CSS_Extract_Links($url, $base, $lang,
                                             \$extracted_content);

            #
            # Add results from CSS link extraction to those
            # extracted from the HTML content to get all links.
            #
            foreach $link (@other_links) {
                push(@links, $link);
            }
        }
    }
        
    #
    # Return array of link objects
    #
    return(@links);
}

#***********************************************************************
#
# Name: Extract_Links
#
# Parameters: url - URL of document to extract links from
#             base - the base value from the response object (resp->base)
#             lang - language of URL
#             mime_type - mime-type of content
#             content - content pointer
#             generated_content - generated content pointer
#
# Description:
#
#   This function extracts links from the supplied content and
# returns the details as an array of link objects.
#
#***********************************************************************
sub Extract_Links {
    my ($url, $base, $lang, $mime_type, $content, $generated_content) = @_;

    my (@links, $link, $subsection_name, $link_addr);

    #
    # Did we just extract links for this URL ? Did both extractions
    # use the same generated content ?
    #
    print "Extract_Links: Checking URL $url, mime-type = $mime_type\n" if $debug;
    if ( ($url eq $last_url) && ($generated_content eq $last_generated_content) ) {
        print "Return previously extracted links\n" if $debug;
        return(@last_link_list);
    }

    #
    # Did we get any content ?
    #
    %subsection_links = ();
    if ( length($$content) > 0 ) {

        #
        # Is this HTML content ?
        #
        if ( $mime_type =~ /text\/html/ ) {
            #
            # Get link information from HTML markup
            #
            @links = Extract_Links_From_HTML($url, $base, $lang, $mime_type,
                                             $content, $generated_content);
        }
        #
        # Is this CSS content ?
        #
        elsif ( $mime_type =~ /text\/css/ ) {
            @links = CSS_Extract_Links($url, $base, $lang, $content);
        }
        #
        # Is this PDF content ?
        #
        elsif ( $mime_type =~ /application\/pdf/ ) {
            #
            # Skip PDF link extraction. The program used to extract links
            # from PDF files can fail if the PDF contains only scanned
            # pages (i.e. not text).  The failure may stop the program
            # when running on Windows when the OS presents a popup
            # window.
            #
            #@links = PDF_Extract_Links($url, $base, $lang, $content);
        }
        #
        # Is the file XML ? or does the URL end in a .xml ?
        #
        elsif ( ($mime_type =~ /application\/atom\+xml/) ||
                ($mime_type =~ /application\/ttml\+xml/) ||
                ($mime_type =~ /application\/xhtml\+xml/) ||
                ($mime_type =~ /application\/xml/) ||
                ($mime_type =~ /text\/xml/) ||
                ($url =~ /\.xml$/i) ) {
            @links = XML_Extract_Links($url, $base, $lang, $content);
        }

        #
        # Check to see if we found no document subsections
        #
        if ( keys(%subsection_links) == 0 ) {
            print "No content sections found\n" if $debug;

            #
            # Assign all links to the CONTENT section
            #
            $subsection_links{"CONTENT"} = \@links;
        }

        #
        # Add referer URL value to link objects
        #
        print "Links extracted from $url\n" if $debug;
        foreach $link (@links) {
            $link->referer_url($url);
        }

        #
        # Print out each sections link set
        #
        if ( $debug ) {
            foreach $subsection_name (keys %subsection_links) {
                print "Extract_Links, subsection = $subsection_name\n";
                if ( defined($subsection_links{$subsection_name}) ) {
                    $link_addr = $subsection_links{$subsection_name};

                    #
                    # Print list of links returned
                    #
                    foreach (@$link_addr) {
                        print "Link at Line/column: " . $_->line_no . ":" . $_->column_no .
                              " type = " . $_->link_type .
                              " lang = " . $_->lang . "\n";
                        print "  Anchor = \"" . $_->anchor .
                              "\" alt = \"" . $_->alt .
                              "\" href = " .
                              $_->abs_url . "\n";
                        print "  modified_content = " . $_->modified_content .
                              "  generated_content = " . $_->generated_content .
                              "\n";
                    }
                }
            }
        }
    }
    else {
        print "Extract_Links: no content in document\n" if $debug;
    }

    #
    # Remember this link list in case we want it again.
    #
    $last_url = $url;
    $last_generated_content = $generated_content;
    @last_link_list = @links;

    #
    # Return array of link objects
    #
    return(@links);
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

