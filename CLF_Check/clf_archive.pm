#***********************************************************************
#
# Name:   clf_archive.pm
#
# $Revision: 6703 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/CLF_Check/Tools/clf_archive.pm $
# $Date: 2014-07-22 12:15:54 -0400 (Tue, 22 Jul 2014) $
#
# Description:
#
#   This file contains routines that parse HTML files and checks for
# "Archived on the Web" markers.
#
# Public functions:
#     CLF_Archive_Debug
#     Set_Archive_Check_Language
#     CLF_Archive_Set_Archive_Markers
#     CLF_Archive_Is_Archived
#     CLF_Archive_Archive_Check
#     CLF_Archive_Check_Links
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

package clf_archive;

use strict;
use HTML::Entities;
use URI::URL;
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
    @EXPORT  = qw(CLF_Archive_Debug
                  Set_Archive_Check_Language
                  CLF_Archive_Is_Archived
                  CLF_Archive_Set_Archive_Markers
                  CLF_Archive_Archive_Check
                  CLF_Archive_Check_Links
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
my (%archive_markers, %have_archive_markers, $results_list_addr);

#
# String table for error strings.
#
my %string_table_en = (
    "Missing metadata tag",         "Missing metadata tag ",
    "Missing text",                 "Missing text ",
    "in",                           " in ",
    "Missing archive marker in link to archived document", "Missing archive marker in link to archived document",
);

#
# String table for error strings (French).
#
my %string_table_fr = (
    "Missing metadata tag",         "Manquants balise de métadonnées ",
    "Missing text",                 "Texte manquants ",
    "in",                           " dans ",
    "Missing archive marker in link to archived document", "Manquant marqueur archive en lien au document archivé",
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#***********************************************************************
#
# Name: CLF_Archive_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub CLF_Archive_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_Archive_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Archive_Check_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_Archive_Check_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_Archive_Check_Language, language = English\n" if $debug;
        $string_table = \%string_table_en;
    }
}

#***********************************************************************
#
# Name: CLF_Archive_Set_Archive_Markers
#
# Parameters: profile - archived markers profile
#             marker_type - archive marker type
#             data - string of data
#
# Description:
#
#   This function copies the passed data into a hash table
# for the specified archived marker type.  Valid marker types
# include:
#    metadata
#    title
#
#***********************************************************************
sub CLF_Archive_Set_Archive_Markers {
    my ($profile, $marker_type, $data) = @_;
    
    my ($markers_addr, $lang_addr, %lang_markers, %markers, $lang, $value);

    #
    # Split the data on language and value
    #
    ($lang, $value) = split(/\s+/, $data, 2);

    #
    # Do we have a value portion ?
    #
    if ( defined($value) ) {
        #
        # Get address of markers for this profile
        #
        if ( ! defined($archive_markers{$profile}) ) {
            $archive_markers{$profile} = \%lang_markers;
        }
        $lang_addr = $archive_markers{$profile};

        #
        # Get the address of the language specific markers
        #
        if ( ! defined($$lang_addr{$lang}) ) {
            $$lang_addr{$lang} = \%markers;
        }
        $markers_addr = $$lang_addr{$lang};

        #
        # Do we already have a marker type value ? if so append
        # this new data to it with a new line separator.
        #
        if ( defined($$markers_addr{$marker_type}) ) {
            $$markers_addr{$marker_type} .= "\n$value";
        }
        else {
            $$markers_addr{$marker_type} .= $value;
        }
        $have_archive_markers{$profile} = 1;
    }
}

#***********************************************************************
#
# Name: Check_Metadata_Marker
#
# Parameters: tag_list - list of metadata tags
#             metadata - metadata content from document
#
# Description:
#
#    This function checks that any metadata tags that acts as an archived
# marker are present.
#
#***********************************************************************
sub Check_Metadata_Marker {
    my ($tag_list, %metadata) = @_;

    my ($is_archived) = 0;
    my ($tag);
    
    #
    # Split tag list on new line to get individual tags.
    #
    print "Check_Metadata_Marker marker tag list = $tag_list\n" if $debug;
    foreach $tag (split(/\n/, $tag_list)) {
        #
        # Check for archived metadata marker tag
        #
        print "Check marker tag = $tag\n" if $debug;
        if ( defined($metadata{$tag}) &&
             ($metadata{$tag} ne "") ) {
            print "Found archived metadata marker $tag with value " .
                  $metadata{$tag} . "\n" if $debug;
            $is_archived = 1;
            last;
        }
        else {
            print "Archived metadata marker $tag not found\n" if $debug;
        }
    }
    
    #
    # Return archived status
    #
    return($is_archived);
}

#***********************************************************************
#
# Name: Check_String_For_Marker_At_Beginning
#
# Parameters: marker_strings - set of marker string values
#             string_type - type of string (e.g. title)
#             string_value - value of string
#
# Description:
#
#    This function checks a string to see if it starts with any of a set of
# string values.
#
#***********************************************************************
sub Check_String_For_Marker_At_Beginning {
    my ($marker_strings, $string_type, $string_value) = @_;

    my ($found_string) = 0;
    my ($marker);

    #
    # Remove any leading white space from the string value.
    #
    $string_value = decode_entities($string_value);
    $string_value = encode_entities($string_value);
    $string_value =~ s/\&nbsp;/ /g;
    $string_value =~ s/^[\s\t\n\r]+//g;

    #
    # Split the marker string on new line and check until we have a match
    #
    print "Check_String_For_Marker_At_Beginning markers = $marker_strings, type = $string_type, value = $string_value\n" if $debug;
    foreach $marker (split(/\n/, $marker_strings)) {
        if ( $string_value =~ /^$marker/i ) {
            print "Found \"$marker\" value in $string_value\n" if $debug;
            $found_string = 1;
            last;
        }
    }
    
    #
    # Did we find a marker string ?
    #
    if ( ! $found_string ) {
        print "No marker in $string_type\n" if $debug;
    }

    #
    # Return archived status
    #
    return($found_string);
}

#***********************************************************************
#
# Name: Check_String_For_Marker
#
# Parameters: marker_strings - set of marker string values
#             string_type - type of string (e.g. title)
#             string_value - value of string
#
# Description:
#
#    This function checks a string to see if it contains with any of a set of
# string values.
#
#***********************************************************************
sub Check_String_For_Marker {
    my ($marker_strings, $string_type, $string_value) = @_;

    my ($found_string) = 0;
    my ($marker);

    #
    # Convert any newline, tab or return into space characters.
    # Eliminate all whitespace to make check easier.
    #
    $string_value = encode_entities($string_value);
    $string_value =~ s/\&nbsp;/ /g;
    $string_value =~ s/[\t\n\r]/ /g;
    $string_value =~ s/\s*//g;

    #
    # Split the marker string on new line and check until we have a match.
    # Eliminate all white space from the marker before checking.
    #
    #print "Check_String_For_Marker markers = $marker_strings, type = $string_type, string value = $string_value\n" if $debug;
    print "Check_String_For_Marker markers = $marker_strings, type = $string_type\n" if $debug;
    foreach $marker (split(/\n/, $marker_strings)) {
        $marker =~ s/\s*//g;
        if ( $string_value =~ /$marker/i ) {
            print "Found \"$marker\" value\n" if $debug;
            $found_string = 1;
            last;
        }
    }
    
    #
    # Did we find a marker string ?
    #
    if ( ! $found_string ) {
        print "No marker in $string_type\n" if $debug;
    }

    #
    # Return archived status
    #
    return($found_string);
}

#***********************************************************************
#
# Name: Check_Headings_Marker
#
# Parameters: h_strings - set of H1 heading string values
#             h_level - heading level (e.g. 1 = h1)
#             headings - list of headings from document
#
# Description:
#
#    This function checks the list of headings to see if an heading
# contains any of the heading string values.
#
#***********************************************************************
sub Check_Headings_Marker {
    my ($h_strings, $h_level, @headings) = @_;

    my ($is_archived) = 0;
    my ($h_marker, $heading, $heading_level, $heading_value);

    #
    # Check each heading in the list
    #
    print "Check_Headings_Marker level $h_level heading list = $h_strings\n" if $debug;
    foreach $heading (@headings) {
        #
        # Split heading item to get level and value
        #
        ($heading_level, $heading_value) = split(/:/, $heading);
        print "Check heading h$heading_level $heading_value\n" if $debug;

        #
        # Only look at headings that match the requested level
        #
        if ( $heading_level == $h_level ) {
            #
            # Remove any leading white space from the string value.
            #
            $heading_value = encode_entities($heading_value);
            $heading_value =~ s/\&nbsp;/ /g;
            $heading_value =~ s/^[\s\t\n\r]+//g;

            #
            # Split the heading string on new line and check until
            # we have a match
            #
            foreach $h_marker (split(/\n/, $h_strings)) {
                #
                # Do we have the marker ?
                #
                if ( $heading_value =~ /^$h_marker/i ) {
                    print "Found \"$h_marker\" value in $heading_value\n" if $debug;

                    #
                    # Return status of archived
                    #
                    return(1);
                }
            }
        }
    }

    #
    # If we got here, we did not find a heading at the appropriate level
    # with the marker text ?
    #
    print "No heading marker found\n" if $debug;

    #
    # Return status of not archived
    #
    return(0);
}

#***********************************************************************
#
# Name: CLF_Archive_Is_Archived
#
# Parameters: profile - archived markers profile
#             url - URL
#             content - content pointer
#
# Description:
#
#    This function checks the content and metadata to see if
# there are "Archived on the web" markers. It looks for
#   a possible metadata item (e.g. pwgsc.date.archived)
#   marker text in the title (e.g. ARCHIVED)
#   archive notice
#
#***********************************************************************
sub CLF_Archive_Is_Archived {
    my ($profile, $url, $content) = @_;

    my (%metadata, $metadata_tag, $title_marker, $archived_markers_found);
    my (@content_results_list, @content_headings, $metadata_object);
    my ($markers_addr, $lang, $lang_addr, $extracted_content);
    my ($possible_marker_count, $archived_marker_text_found);
    my ($language, $status);
    my ($is_archived) = 0;

    #
    # Do we have any archived on the web markers ?
    #
    if ( (! defined($have_archive_markers{$profile})) ||
         (! $have_archive_markers{$profile}) ) {
        print "CLF_Archive_Is_Archived no archived on the web markers for profile $profile\n" if $debug;
        return(0);
    }
    $lang_addr = $archive_markers{$profile};

    #
    # Get metadata from the document
    #
    print "CLF_Archive_Is_Archived profile = $profile, url = $url\n" if $debug;
    %metadata = Extract_Metadata($url, $content);

    #
    # Perform a content check, this will get the list of
    # headings in the document.  We don't care about the
    # content check results.
    #
    @content_results_list = Content_Check($url, "", "text/html", $content);

    #
    #
    # Get the content headings
    #
    @content_headings = Content_Check_Get_Headings();

    #
    # Check for archive markers in each language we have markers for.
    # This catches the case when the wrong language marker is used.
    #
    foreach $lang (keys(%$lang_addr)) {
        #
        # Get the markers for this language
        #
        print "Check archive markers for language $lang\n" if $debug;
        $markers_addr = $$lang_addr{$lang};

        #
        # Get the number of possible archive markers
        #
        $possible_marker_count = keys(%$markers_addr);
        $archived_markers_found = 0;

        #
        # Do we have a metadata tags as an archive marker ?
        #
        if ( defined($$markers_addr{"metadata"}) &&
             ($$markers_addr{"metadata"} ne "") ) {
            #
            # Check for archived metadata markers
            #
            if ( Check_Metadata_Marker($$markers_addr{"metadata"}, %metadata) ) {
                $archived_markers_found++;
            }
        }

        #
        # Do we have some title markers and title text to check ?
        #
        if ( defined($$markers_addr{"title"}) &&
             ($$markers_addr{"title"} ne "") &&
             defined($metadata{"title"}) ) {
            #
            # Check to see if the marker text is in the title
            #
            $metadata_object = $metadata{"title"};
            if ( Check_String_For_Marker_At_Beginning($$markers_addr{"title"}, "<title>",
                                         $metadata_object->content) ) {
                $archived_markers_found++;
            }
        }

        #
        # Do we have some dc.title metadata content markers and
        # text to check ?
        #
        if ( defined($$markers_addr{"dc.title"}) &&
             ($$markers_addr{"dc.title"} ne "") &&
             defined($metadata{"dc.title"}) ) {
            #
            # Check to see if the marker text is in the dc.title
            #
            $metadata_object = $metadata{"dc.title"};
            if ( Check_String_For_Marker_At_Beginning($$markers_addr{"dc.title"}, "dc.title",
                                         $metadata_object->content) ) {
                $archived_markers_found++;
            }
        }

        #
        # Do we have some dcterms.title metadata content markers and
        # text to check ?
        #
        if ( defined($$markers_addr{"dcterms.title"}) &&
             ($$markers_addr{"dcterms.title"} ne "") &&
             defined($metadata{"dcterms.title"}) ) {
            #
            # Check to see if the marker text is in the dcterms.title
            #
            $metadata_object = $metadata{"dcterms.title"};
            if ( Check_String_For_Marker_At_Beginning($$markers_addr{"dcterms.title"}, "dcterms.title",
                                         $metadata_object->content) ) {
                $archived_markers_found++;
            }
        }

        #
        # Do we have some description metadata content markers and
        # text to check ?
        #
        if ( defined($$markers_addr{"description"}) &&
             ($$markers_addr{"description"} ne "") &&
             defined($metadata{"description"}) ) {
            #
            # Check to see if the marker text is in the description
            #
            $metadata_object = $metadata{"description"};
            if ( Check_String_For_Marker_At_Beginning($$markers_addr{"description"}, "description",
                                         $metadata_object->content) ) {
                $archived_markers_found++;
            }
        }

        #
        # Do we have some H1 marker text ?
        #
        if ( defined($$markers_addr{"h1_text"}) &&
             ($$markers_addr{"h1_text"} ne "") ) {
            #
            # Check to see if the marker text is in the heading
            #
            if ( Check_Headings_Marker($$markers_addr{"h1_text"}, 1,
                                       @content_headings) ) {
                $archived_markers_found++;
            }
        }

        #
        # Do we have some H2 marker text ?
        #
        if ( defined($$markers_addr{"h2_text"}) &&
             ($$markers_addr{"h2_text"} ne "") ) {
            #
            # Check to see if the marker text is in the heading
            #
            if ( Check_Headings_Marker($$markers_addr{"h2_text"}, 2,
                                       @content_headings) ) {
                $archived_markers_found++;
            }
        }

        #
        # Do we have any content marker text ?
        #
        $archived_marker_text_found = 0;
        if ( defined($$markers_addr{"text"}) &&
             ($$markers_addr{"text"} ne "") ) {
            #
            # Get the text contents of the page.
            #
            $extracted_content = Content_Check_Extract_Content_From_HTML($$content);

            #
            # Check to see if the marker text is in the content
            #
            if ( Check_String_For_Marker($$markers_addr{"text"}, "text", 
                                         $extracted_content) ) {
                $archived_markers_found++;
                $archived_marker_text_found = 1;
                print "Found archive notice text\n" if $debug;
            }
        }

        #
        # Do we have any link marker text ?
        #
        if ( defined($$markers_addr{"link_text"}) &&
             ($$markers_addr{"link_text"} ne "") ) {
            #
            # The text that must appear in a link to an archived document.
            # We don't actually expect to see this in an archived document so
            # we decrement the possible archive marker count to discount
            # this marker.
            #
            if ( $possible_marker_count > 0 ) {
                $possible_marker_count--;
            }
        }

        #
        # Did we find the archive notice text or did we find atleast
        # half of the archive markers ?
        #
        print "Have $archived_markers_found markers out of $possible_marker_count \n" if $debug;
        if ( $archived_marker_text_found || 
             ($archived_markers_found >= ($possible_marker_count / 2)) ) {
            $is_archived = 1;
            last;
        }
    }

    #
    # Return archived flag
    #
    print "CLF_Archive_Is_Archived $is_archived\n" if $debug;
    return($is_archived);
}

#**********************************************************************
#
# Name: String_Value
#
# Parameters: key - string table key
#
# Description:
#
#   This function returns the value in the string table for the
# specified key.  If there is no entry in the table an error string
# is returned.
#
#**********************************************************************
sub String_Value {
    my ($key) = @_;

    #
    # Do we have a string table entry for this key ?
    #
    if ( defined($$string_table{$key}) ) {
        #
        # return value
        #
        return ($$string_table{$key});
    }
    else {
        #
        # No string table entry, either we are missing a string or
        # we have a typo in the key name.
        #
        return ("*** No string for $key ***");
    }
}

#***********************************************************************
#
# Name: Check_Metadata_Content
#
# Parameters: metadata_tag - name of metadata tag
#             markers_addr - address of archive markers content
#             metadata - metadata values
#
# Description:
#
#    This function checks that the named metadata tag exist and its
# content begins with the required text.
#
#***********************************************************************
sub Check_Metadata_Content {
    my ($metadata_tag, $markers_addr, %metadata) = @_;

    my ($metadata_object);
    my ($message) = "";

    #
    # Do we have some metadata content markers and content text to check ?
    #
    if ( defined($$markers_addr{$metadata_tag}) &&
         ($$markers_addr{$metadata_tag} ne "") ) {
        #
        # Do we have this metadata tag ?
        #
        if ( defined($metadata{$metadata_tag}) ) {
            #
            # Check to see if the marker text is in the content
            #
            $metadata_object = $metadata{$metadata_tag};
            if ( ! Check_String_For_Marker_At_Beginning($$markers_addr{$metadata_tag}, 
                               $metadata_tag, $metadata_object->content) ) {
                $message = String_Value("Missing text") . "\"" .
                           $$markers_addr{$metadata_tag} . "\"" .
                           String_Value("in") ."<meta name=\"$metadata_tag\" content=\"" . $metadata_object->content . "\">\n";
            }
        }
        else {
            #
            # Missing content text
            #
            $message = String_Value("Missing text") .
                       $$markers_addr{$metadata_tag} .
                       String_Value("in") ."<meta name=\"$metadata_tag\">\n";
        }
    }

    #
    # Return the message
    #
    return($message);
}

#***********************************************************************
#
# Name: CLF_Archive_Archive_Check
#
# Parameters: profile - archived markers profile
#             url - URL
#             content - content pointer
#
# Description:
#
#    This function checks the content and metadata to see if
# all "Archived on the web" markers are present. It looks for
#   a possible metadata item (e.g. pwgsc.date.archived)
#   marker text in the title (e.g. ARCHIVED:)
#
#***********************************************************************
sub CLF_Archive_Archive_Check {
    my ($profile, $url, $content) = @_;

    my ($archived_markers_found) = 0;
    my (%metadata, $metadata_tag, $title_marker, $is_archived);
    my (@content_results_list, @content_headings, $metadata_object);
    my ($markers_addr, $lang, $lang_addr, $extracted_content);
    my ($language, $status);
    my ($message) = "";

    #
    # Do we have any archived on the web markers ?
    #
    if ( (! defined($have_archive_markers{$profile})) ||
         (! $have_archive_markers{$profile}) ) {
        print "CLF_Archive_Archive_Check no archived on the web markers for profile $profile\n" if $debug;
        return(0);
    }
    $lang_addr = $archive_markers{$profile};

    #
    # Get language of the URL
    #
    $lang = URL_Check_GET_URL_Language($url);

    #
    # If the language cannot be determined from the URL, check
    # the language of the content
    #
    if ( $lang eq "" ) {
        ($lang, $language, $status) = TextCat_HTML_Language($content);
    }

    #
    # Do we have markers for this language ?
    #
    if ( ! defined($$lang_addr{$lang}) ) {
        print "CLF_Archive_Archive_Check no archived on the web markers for profile $profile, language $lang\n" if $debug;
        return(0);
    }
    $markers_addr = $$lang_addr{$lang};

    #
    # Get metadata from the document
    #
    print "CLF_Archive_Archive_Check profile = $profile, url = $url\n" if $debug;
    %metadata = Extract_Metadata($url, $content);

    #
    # Do we have a metadata tags as an archive marker ?
    #
    if ( defined($$markers_addr{"metadata"}) &&
         ($$markers_addr{"metadata"} ne "") ) {
        #
        # Check for archived metadata markers
        #
        if ( ! Check_Metadata_Marker($$markers_addr{"metadata"}, %metadata) ) {
            $message .= String_Value("Missing metadata tag") . "\"" .
                        $$markers_addr{"metadata"} . "\"\n";
        }
    }

    #
    # Do we have some title markers and title text to check ?
    #
    if ( defined($$markers_addr{"title"}) &&
         ($$markers_addr{"title"} ne "") ) {
        #
        # Do we have a title ?
        #
        if ( defined($metadata{"title"}) ) {
            #
            # Check to see if the marker text is in the title
            #
            $metadata_object = $metadata{"title"};
            if ( ! Check_String_For_Marker_At_Beginning($$markers_addr{"title"}, "<title>",
                                         $metadata_object->content) ) {
                $message .= String_Value("Missing text") . "\"" .
                            $$markers_addr{"title"} . "\"" .
                            String_Value("in") ."<title>" . $metadata_object->content . "</title>\n";
            }
        }
        else {
            #
            # Missing title text
            #
            $message .= String_Value("Missing text") .
                        $$markers_addr{"title"} .
                        String_Value("in") ."<title></title>\n";
        }
    }

    #
    # Do we have some dc.title metadata content markers and
    # content text to check ?
    #
    $message .= Check_Metadata_Content("dc.title", $markers_addr, %metadata);

    #
    # Do we have some dcterms.title metadata content markers and
    # content text to check ?
    #
    $message .= Check_Metadata_Content("dcterms.title", $markers_addr, %metadata);

    #
    # Do we have some description metadata content markers and
    # content text to check ?
    #
    $message .= Check_Metadata_Content("description", $markers_addr, %metadata);

    #
    # Perform a content check, this will get the list of
    # headings in the document.  We don't care about the
    # content check results.
    #
    @content_results_list = Content_Check($url, "", "text/html", $content);

    #
    #
    # Get the content headings
    #
    @content_headings = Content_Check_Get_Headings();

    #
    # Do we have some H1 marker text ?
    #
    if ( defined($$markers_addr{"h1_text"}) &&
         ($$markers_addr{"h1_text"} ne "") ) {
        #
        # Check to see if the marker text is in the heading
        #
        if ( ! Check_Headings_Marker($$markers_addr{"h1_text"}, 1,
                                   @content_headings) ) {
            $message .= String_Value("Missing text") . "\"" .
                        $$markers_addr{"h1_text"} . "\"" .
                        String_Value("in") ."<h1>\n";
        }
    }

    #
    # Do we have some H2 marker text ?
    #
    if ( defined($$markers_addr{"h2_text"}) &&
         ($$markers_addr{"h2_text"} ne "") ) {
        #
        # Check to see if the marker text is in the heading
        #
        if ( ! Check_Headings_Marker($$markers_addr{"h2_text"}, 2,
                                   @content_headings) ) {
            $message .= String_Value("Missing text") . "\"" .
                        $$markers_addr{"h2_text"} . "\"" .
                        String_Value("in") ."<h2>\n";        }
    }

    #
    # Do we have any content marker text ?
    #
    if ( defined($$markers_addr{"text"}) &&
         ($$markers_addr{"text"} ne "") ) {
        #
        # Get the text contents of the page.
        #
        $extracted_content = Content_Check_Extract_Content_From_HTML($$content);

        #
        # Check to see if the marker text is in the content
        #
        if ( ! Check_String_For_Marker($$markers_addr{"text"}, "text", 
                                       $extracted_content) ) {
            $message .= String_Value("Missing text") .
                        " \"" . $$markers_addr{"text"} . "\"";
        }
    }

    #
    # Return messages
    #
    print "Messages = $message\n" if $debug;
    return($message);
}

#***********************************************************************
#
# Name: Record_Result
#
# Parameters: testcase - testcase identifier
#             description - testcase description
#             url - URL
#             line - line number
#             column - column number
#             text - text from tag
#             error_string - error string
#
# Description:
#
#   This function records the testcase result.
#
#***********************************************************************
sub Record_Result {
    my ( $testcase, $description, $url, $line, $column, $text, $error_string ) = @_;

    my ($result_object);

    #
    # Create result object and save details
    #
    $result_object = tqa_result_object->new($testcase, 1,
                                            $description,
                                            $line, $column, $text,
                                            $error_string, $url);
    push (@$results_list_addr, $result_object)
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
    # Encode entities.
    #
    $text = encode_entities($text);

    #
    # Convert &nbsp; into a single space.
    # Convert newline into a space.
    # Convert return into a space.
    #
    $text =~ s/\&nbsp;/ /g;
    $text =~ s/\n/ /g;
    $text =~ s/\r/ /g;

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
# Name: CLF_Archive_Check_Links
#
# Parameters: url - URL
#             profile - archived markers profile
#             tcid - testcase id
#             description - testcase description
#             link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function checks the links from a document. It checks that any
# link to an "Archived on the Web" document has the appropriate
# text in the anchor text (e.g. Archived).
#
#***********************************************************************
sub CLF_Archive_Check_Links {
    my ($url, $profile, $tcid, $description, $link_sets) = @_;

    my ($result_object, @local_tqa_results_list, $list_addr, $section);
    my ($link, $found_marker, $lang_addr, $marker);
    my ($link_archive_markers) = "";

    #
    # Do we have any archived on the web markers ?
    #
    if ( (! defined($have_archive_markers{$profile})) ||
         (! $have_archive_markers{$profile}) ) {
        print "CLF_Archive_Check_Links no archived on the web markers for profile $profile\n" if $debug;
        return(@local_tqa_results_list);
    }
    $list_addr = $archive_markers{$profile};

    #
    # Get the complete list of archive markers by getting all the markers
    # for each language.  We don't know the language of the link text
    # so we cannot just look at 1 language's marker text.
    #
    foreach $lang_addr (values(%$list_addr)) {
        if ( defined($$lang_addr{"link_text"}) ) {
            $marker = $$lang_addr{"link_text"};
            $link_archive_markers .= "$marker\n";
            print "Possible link archive marker $marker\n" if $debug;
        }
    }

    #
    # Remove any trailing newline from marker set.
    #
    $link_archive_markers =~ s/\n$//g;

    #
    # Do we have any link marker text ?
    #
    if ( $link_archive_markers eq "" ) {
        print "No link archive markers\n" if $debug;
        return(\@local_tqa_results_list);
    }

    #
    # Check each document section
    #
    $results_list_addr = \@local_tqa_results_list;
    print "CLF_Archive_Check_Links, tcid = $tcid\n" if $debug;
    foreach $section (keys(%$link_sets)) {
        $list_addr = $$link_sets{$section};
        print "Check document section $section\n" if $debug;

        #
        # Check each link in this section
        #
        foreach $link (@$list_addr) {
            #
            # Is this a link to an archived document ?
            #
            if ( $link->is_archived ) {
                #
                # Does the anchor text begin with an archive marker ?
                #
                print "Archived link, anchor text = " . $link->anchor . "\n"
                      if $debug;

                #
                # Get anchor text for this link anc check if it starts with
                # one of the markers.
                #
                if ( ! Check_String_For_Marker_At_Beginning($link_archive_markers,
                                                            "link",
                                                            $link->anchor) ) {
                    print "Did not find link archive marker\n" if $debug;
                    Record_Result($tcid, $description, $url,
                                  $link->line_no, $link->column_no,
                                  $link->source_line,
                                  String_Value("Missing archive marker in link to archived document") . 
                                  " \"" . $link->anchor . "\"");
                }
            }
        }
    }

    #
    # Return results list.
    #
    return(@local_tqa_results_list);
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
    my (@package_list) = ("metadata", "content_check",
                          "metadata_result_object", "url_check",
                          "tqa_result_object", "textcat");

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

