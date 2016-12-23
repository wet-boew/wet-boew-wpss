#***********************************************************************
#
# Name: link_object.pm
#
# $Revision: 7637 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Link_Check/Tools/link_object.pm $
# $Date: 2016-07-22 07:50:26 -0400 (Fri, 22 Jul 2016) $
#
# Description:
#
#   This file defines an object to handle link information (e.g. href,
# source location). The object contains methods to set and read the
# link attributes.
#
# Public functions:
#     Link_Object_Debug
#
# Class Methods
#    new - create new object instance
#    href - get/set href value
#    abs_url - get/set absolute url value
#    alt - get/set alt text
#    anchor - get/set anchor value
#    attr - get/set the set of link attributes
#    column_no - get/set column number value
#    content_length - get/set link content length value
#    content_section - get/set the name of the content section
#    domain_path - get/set the protocol/domain/path portion of the URL
#    generated_content - get/set the generated content value
#    has_alt - get/set the has_alt attribute
#    has_img - get/set the has_img attribute
#    in_anchor - get/set the in_anchor attribute
#    in_list - get/set the in_list attribute
#    is_archived - get/set the is_archived attribute
#    is_redirected - get/set the is_redirected attribute
#    lang - get/set lang value
#    line_no - get/set line number value
#    link_status - get/set link status value
#    link_type - get/set link type value
#    list_heading - get/set the list_heading attribute
#    message - get/set the testcase message
#    mime_type - get/set mime-type value
#    modified_content - get/set the modified content value
#    noscript - get/set the noscript value
#    on_page_id_reference - return the on_page_id_reference value
#    query - get/set the query portion of the URL
#    referer_url - get/set the referer URL
#    source_line - get/set source value
#    title - get/set title
#    url_title - get/set the title of the target URL
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

package link_object;

use strict;
use warnings;
use File::Basename;

#
# Use WPSS_Tool program modules
#
use url_check;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Link_Object_Debug);
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my ($MAX_SOURCE_LINE_SIZE) = 200;

#********************************************************
#
# Name: Link_Object_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Link_Object_Debug {
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
#             abs_url - absolute url
#             anchor - anchor or title text
#             link_type - type of link (e.g. anchor, image,...)
#             lang - language of link (eng, fra, ...)
#             line_no - source line number
#             column_no - source column number
#             source_line - source line
#
# Description:
#
#   This function creates a new link_object item and
# initializes its data items.
#
#********************************************************
sub new {
    my ($class, $href, $abs_url, $anchor, $link_type, $lang,
        $line_no, $column_no, $source_line) = @_;
    
    my ($self) = {};
    my ($protocol, $domain, $dir, $query, $new_url, $start_col);
    my (%attr);

    #
    # Bless the reference as a link_object class item
    #
    bless $self, $class;
    
    #
    # Save arguments as link object data items
    #
    $self->{"abs_url"} = $abs_url;
    $self->{"alt"} = "";
    $self->{"anchor"} = $anchor;
    $self->{"attr"} = \%attr;
    $self->{"column_no"} = $column_no;
    $self->{"content_length"} = 0;
    $self->{"content_section"} = "BODY";
    $self->{"generated_content"} = 0;
    $self->{"has_alt"} = 0;
    $self->{"has_img"} = 0;
    $self->{"href"} = $href;
    $self->{"in_anchor"} = 0;
    $self->{"in_list"} = 0;
    $self->{"is_archived"} = 0;
    $self->{"is_redirected"} = 0;
    $self->{"link_type"} = $link_type;
    $self->{"lang"} = $lang;
    $self->{"line_no"} = $line_no;
    $self->{"list_heading"} = "";
    $self->{"message"} = "";
    $self->{"modified_content"} = 0;
    $self->{"noscript"} = 0;
    $self->{"redirect_url"} = 0;
    
    #
    # Extract components of the URL, we save some pieces seperately
    # for easy access later.
    #
    if ( $abs_url =~ /^http/ ) {
        ($protocol, $domain, $dir, $query, $new_url) = 
            URL_Check_Parse_URL($abs_url);
        $self->{"domain_path"} = "$protocol//$domain/$dir";
        $self->{"query"} = $query;
    }
    else {
        $self->{"domain_path"} = "";
        $self->{"query"} = "";
    }
    
    #
    # Is the href value just an anchor on the same page ?
    #
    if ( defined($href) && ($href =~ /^#.*/) ) {
        $self->{"on_page_id_reference"} = 1;
    }
    elsif ( defined($href) && ($href =~ /^\?.*/) ) {
        $self->{"on_page_id_reference"} = 1;
    }
    else {
        $self->{"on_page_id_reference"} = 0;
    }

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
        # Source line is too long, save the portion around the link
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

    #
    # Print link object details
    #
    if ( $debug ) {
        print "New link object, Line/column: " . $self->line_no . ":" . $self->column_no;
        print " type = " . $self->link_type;
        print " lang = " . $self->lang . "\n";
        print " href    = " . $self->href .
              " anchor = " . $self->anchor . "\n";
        print " abs_url = " . $self->abs_url . "\n";
        print " domain_path = " . $self->domain_path . "\n";
        print " query = " . $self->query . "\n";
    }

    #
    # Return reference to object.
    #
    return($self);
}
    
#********************************************************
#
# Name: abs_url
#
# Parameters: self - class reference
#             abs_url - url (optional)
#
# Description:
#
#   This function either sets or returns the abs_url
# attribute of the link object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub abs_url {
    my ($self, $abs_url) = @_;
   
    #
    # Was a abs_url value supplied ?
    #
    if ( defined($abs_url) ) {
        $self->{"abs_url"} = $abs_url;
    }
    else {
        return($self->{"abs_url"});
    }
}

#********************************************************
#
# Name: alt
#
# Parameters: self - class reference
#             alt_value - alt text value (optional)
#
# Description:
#
#   This function either sets or returns the alt text
# attribute of the link object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub alt {
    my ($self, $alt_value) = @_;

    #
    # Was a alt text value supplied ?
    #
    if ( defined($alt_value) ) {
        $self->{"alt"} = $alt_value;
        $self->{"has_alt"} = 1;
    }
    else {
        return($self->{"alt"});
    }
}

#********************************************************
#
# Name: anchor
#
# Parameters: self - class reference
#             anchor - anchor text for link (optional)
#
# Description:
#
#   This function either sets or returns the anchor
# attribute of the link object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub anchor {
    my ($self, $anchor) = @_;
    
    #
    # Was an anchor value supplied ?
    #
    if ( defined($anchor) ) {
        $self->{"anchor"} = $anchor;
    }
    else {
        return($self->{"anchor"});
    }
}

#********************************************************
#
# Name: attr
#
# Parameters: self - class reference
#             attr_values - list of attribute values (optional)
#
# Description:
#
#   This function either sets or returns the list of
# attributes values of the link object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub attr {
    my ($self, %attr_values) = @_;
    my ($attr_addr);

    #
    # Were attribute list values supplied ?
    #
    if ( keys(%attr_values) > 0 ) {
        $attr_addr = $self->{"attr"};
        %$attr_addr = %attr_values;
    }
    else {
        $attr_addr = $self->{"attr"};
        return(%$attr_addr);
    }
}

#********************************************************
#
# Name: column_no
#
# Parameters: self - class reference
#             column_no - column number of link in source(optional)
#
# Description:
#
#   This function either sets or returns the column number
# attribute of the link object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub column_no {
    my ($self, $column_no) = @_;

    #
    # Was a column number value supplied ?
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
# Name: content_length
#
# Parameters: self - class reference
#             content_length - content length(optional)
#
# Description:
#
#   This function either sets or returns the content length
# attribute of the link object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub content_length {
    my ($self, $content_length) = @_;

    #
    # Was a content length value supplied ?
    #
    if ( defined($content_length) ) {
        $self->{"content_length"} = $content_length;
    }
    else {
        return($self->{"content_length"});
    }
}

#********************************************************
#
# Name: content_section
#
# Parameters: self - class reference
#             content_section - content section(optional)
#
# Description:
#
#   This function either sets or returns the content section
# attribute of the link object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub content_section {
    my ($self, $content_section) = @_;

    #
    # Was a content section value supplied ?
    #
    if ( defined($content_section) ) {
        $self->{"content_section"} = $content_section;
    }
    else {
        return($self->{"content_section"});
    }
}

#********************************************************
#
# Name: domain_path
#
# Parameters: self - class reference
#             domain_path_value - protocol, domain & path portion
#               of a URL (optional)
#
# Description:
#
#   This function either sets or returns the domain_path
# attribute of the link object. The domain_path of an URL is the portion
# preceeding any anchor reference or query arguments.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub domain_path {
    my ($self, $domain_path_value) = @_;

    #
    # Was a protocol/domain/path value supplied ?
    #
    if ( defined($domain_path_value) ) {
        $self->{"domain_path"} = $domain_path_value;
    }
    else {
        return($self->{"domain_path"});
    }
}

#********************************************************
#
# Name: generated_content
#
# Parameters: self - class reference
#             value - generated_content value (optional)
#
# Description:
#
#   This function either sets or returns the generated_content
# attribute of the link object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub generated_content {
    my ($self, $value) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $self->{"generated_content"} = $value;
    }
    else {
        return($self->{"generated_content"});
    }
}

#********************************************************
#
# Name: has_alt
#
# Parameters: self - class reference
#             has_alt_value - has_alt value (optional)
#
# Description:
#
#   This function either sets or returns the has_alt
# attribute of the link object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub has_alt {
    my ($self, $has_alt_value) = @_;

    #
    # Was a has_alt value supplied ?
    #
    if ( defined($has_alt_value) ) {
        $self->{"has_alt"} = $has_alt_value;
    }
    else {
        return($self->{"has_alt"});
    }
}

#********************************************************
#
# Name: has_img
#
# Parameters: self - class reference
#             has_img_value - has_img value (optional)
#
# Description:
#
#   This function either sets or returns the has_img
# attribute of the link object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub has_img {
    my ($self, $has_img_value) = @_;

    #
    # Was a has_img value supplied ?
    #
    if ( defined($has_img_value) ) {
        $self->{"has_img"} = $has_img_value;
    }
    else {
        return($self->{"has_img"});
    }
}

#********************************************************
#
# Name: href
#
# Parameters: self - class reference
#             href - link href (optional)
#
# Description:
#
#   This function either sets or returns the href
# attribute of the link object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub href {
    my ($self, $href) = @_;

    #
    # Was a href value supplied ?
    #
    if ( defined($href) ) {
        $self->{"href"} = $href;
    }
    else {
        return($self->{"href"});
    }
}

#********************************************************
#
# Name: in_anchor
#
# Parameters: self - class reference
#             in_anchor_value - in_anchor value (optional)
#
# Description:
#
#   This function either sets or returns the in_anchor
# attribute of the link object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub in_anchor {
    my ($self, $in_anchor_value) = @_;

    #
    # Was a in_anchor value supplied ?
    #
    if ( defined($in_anchor_value) ) {
        $self->{"in_anchor"} = $in_anchor_value;
    }
    else {
        return($self->{"in_anchor"});
    }
}

#********************************************************
#
# Name: in_list
#
# Parameters: self - class reference
#             in_list_value - in_list value (optional)
#
# Description:
#
#   This function either sets or returns the in_list
# attribute of the link object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub in_list {
    my ($self, $in_list_value) = @_;

    #
    # Was a in_list value supplied ?
    #
    if ( defined($in_list_value) ) {
        $self->{"in_list"} = $in_list_value;
    }
    else {
        return($self->{"in_list"});
    }
}

#********************************************************
#
# Name: is_archived
#
# Parameters: self - class reference
#             is_archived_value - is_archived value (optional)
#
# Description:
#
#   This function either sets or returns the is_archived
# attribute of the link object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub is_archived {
    my ($self, $is_archived_value) = @_;

    #
    # Was a is_archived value supplied ?
    #
    if ( defined($is_archived_value) ) {
        $self->{"is_archived"} = $is_archived_value;
    }
    else {
        return($self->{"is_archived"});
    }
}

#********************************************************
#
# Name: is_redirected
#
# Parameters: self - class reference
#             is_redirected_value - is_redirected value (optional)
#
# Description:
#
#   This function either sets or returns the is_redirected
# attribute of the link object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub is_redirected {
    my ($self, $is_redirected_value) = @_;

    #
    # Was a is_redirected value supplied ?
    #
    if ( defined($is_redirected_value) ) {
        $self->{"is_redirected"} = $is_redirected_value;
    }
    else {
        return($self->{"is_redirected"});
    }
}

#********************************************************
#
# Name: lang
#
# Parameters: self - class reference
#             lang - language of link (optional)
#
# Description:
#
#   This function either sets or returns the language
# attribute of the link object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub lang {
    my ($self, $lang) = @_;

    #
    # Was a language value supplied ?
    #
    if ( defined($lang) ) {
        $self->{"lang"} = $lang;
    }
    else {
        return($self->{"lang"});
    }
}

#********************************************************
#
# Name: line_no
#
# Parameters: self - class reference
#             line_no - line number of link in source(optional)
#
# Description:
#
#   This function either sets or returns the line number
# attribute of the link object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub line_no {
    my ($self, $line_no) = @_;

    #
    # Was a line number value supplied ?
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
# Name: link_status
#
# Parameters: self - class reference
#             link_status - status of link (optional)
#
# Description:
#
#   This function either sets or returns the status
# attribute of the link object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub link_status {
    my ($self, $link_status) = @_;

    #
    # Was a status value supplied ?
    #
    if ( defined($link_status) ) {
        $self->{"link_status"} = $link_status;
    }
    else {
        return($self->{"link_status"});
    }
}

#********************************************************
#
# Name: link_type
#
# Parameters: self - class reference
#             link_type - link type of link (optional)
#
# Description:
#
#   This function either sets or returns the link type
# attribute of the link object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub link_type {
    my ($self, $link_type) = @_;

    #
    # Was a link type value supplied ?
    #
    if ( defined($link_type) ) {
        $self->{"link_type"} = $link_type;
    }
    else {
        return($self->{"link_type"});
    }
}

#********************************************************
#
# Name: list_heading
#
# Parameters: self - class reference
#             list_heading_value - list_heading value (optional)
#
# Description:
#
#   This function either sets or returns the list_heading
# attribute of the link object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub list_heading {
    my ($self, $list_heading_value) = @_;

    #
    # Was a list_heading value supplied ?
    #
    if ( defined($list_heading_value) ) {
        $self->{"list_heading"} = $list_heading_value;
    }
    else {
        return($self->{"list_heading"});
    }
}

#********************************************************
#
# Name: message
#
# Parameters: self - class reference
#             message_value - referer url value (optional)
#
# Description:
#
#   This function either sets or returns the message
# attribute of the link object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub message {
    my ($self, $message_value) = @_;

    #
    # Was a message value supplied ?
    #
    if ( defined($message_value) ) {
        $self->{"message"} = $message_value;
    }
    else {
        return($self->{"message"});
    }
}

#********************************************************
#
# Name: mime_type
#
# Parameters: self - class reference
#             mime_type - mime type of link (optional)
#
# Description:
#
#   This function either sets or returns the mime type
# attribute of the link object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub mime_type {
    my ($self, $mime_type) = @_;

    #
    # Was a mime type value supplied ?
    #
    if ( defined($mime_type) ) {
        $self->{"mime_type"} = $mime_type;
    }
    else {
        return($self->{"mime_type"});
    }
}

#********************************************************
#
# Name: modified_content
#
# Parameters: self - class reference
#             value - modified_content value (optional)
#
# Description:
#
#   This function either sets or returns the modified_content
# attribute of the link object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub modified_content {
    my ($self, $value) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $self->{"modified_content"} = $value;
    }
    else {
        return($self->{"modified_content"});
    }
}

#********************************************************
#
# Name: noscript
#
# Parameters: self - class reference
#             value - noscript value (optional)
#
# Description:
#
#   This function either sets or returns the noscript
# attribute of the link object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub noscript {
    my ($self, $value) = @_;

    #
    # Was a value supplied ?
    #
    if ( defined($value) ) {
        $self->{"noscript"} = $value;
    }
    else {
        return($self->{"noscript"});
    }
}

#********************************************************
#
# Name: on_page_id_reference
#
# Parameters: self - class reference
#
# Description:
#
#   This function returns the on_page_id_reference value.
#
#********************************************************
sub on_page_id_reference {
    my ($self) = @_;

    #
    # Return field value
    #
    return($self->{"on_page_id_reference"});
}

#********************************************************
#
# Name: query
#
# Parameters: self - class reference
#             query_value - query portion of a URL (optional)
#
# Description:
#
#   This function either sets or returns the query
# attribute of the link object. The query of an URL is the portion
# following the file name, either an anchor reference or the URL
# argument. If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub query {
    my ($self, $query_value) = @_;

    #
    # Was a query value supplied ?
    #
    if ( defined($query_value) ) {
        $self->{"query"} = $query_value;
    }
    else {
        return($self->{"query"});
    }
}

#********************************************************
#
# Name: redirect_url
#
# Parameters: self - class reference
#             redirect_url_value - redirect_url value (optional)
#
# Description:
#
#   This function either sets or returns the redirect_url
# attribute of the link object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub redirect_url {
    my ($self, $redirect_url_value) = @_;

    #
    # Was a redirect_url value supplied ?
    #
    if ( defined($redirect_url_value) ) {
        $self->{"redirect_url"} = $redirect_url_value;
    }
    else {
        return($self->{"redirect_url"});
    }
}

#********************************************************
#
# Name: referer_url
#
# Parameters: self - class reference
#             referer_url_value - referer url value (optional)
#
# Description:
#
#   This function either sets or returns the referer
# url attribute of the link object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub referer_url {
    my ($self, $referer_url_value) = @_;

    #
    # Was a referer url value supplied ?
    #
    if ( defined($referer_url_value) ) {
        $self->{"referer_url"} = $referer_url_value;
    }
    else {
        return($self->{"referer_url"});
    }
}

#********************************************************
#
# Name: source_line
#
# Parameters: self - class reference
#             source_line - source line of link (optional)
#
# Description:
#
#   This function either sets or returns the source line
# attribute of the link object. If a value is supplied,
# it is saved in the object. If no value is supplied,
# the current value is returned.
#
#********************************************************
sub source_line {
    my ($self, $source_line) = @_;

    #
    # Was a source line value supplied ?
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
# Name: title
#
# Parameters: self - class reference
#             title_value - title value (optional)
#
# Description:
#
#   This function either sets or returns the title
# attribute of the link object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub title {
    my ($self, $title_value) = @_;

    #
    # Was a title value supplied ?
    #
    if ( defined($title_value) ) {
        $self->{"title"} = $title_value;
    }
    else {
        return($self->{"title"});
    }
}

#********************************************************
#
# Name: url_title
#
# Parameters: self - class reference
#             title_value - title of URL value (optional)
#
# Description:
#
#   This function either sets or returns the title
# of the target URL of the link object.
# If a value is supplied, it is saved in the object.
# If no value is supplied, the current value is returned.
#
#********************************************************
sub url_title {
    my ($self, $title_value) = @_;

    #
    # Was a title value supplied ?
    #
    if ( defined($title_value) ) {
        $self->{"url_title"} = $title_value;
    }
    else {
        return($self->{"url_title"});
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


