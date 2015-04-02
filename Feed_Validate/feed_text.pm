#***********************************************************************
#
# Name: feed_text.pm
#
# $Revision: 7003 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Feed_Validate/Tools/feed_text.pm $
# $Date: 2015-01-19 09:53:34 -0500 (Mon, 19 Jan 2015) $
#
# Description
#
#   This file contains routines to extract text from web feeds.
#
# Public functions:
#     Feed_Text_Debug
#     Feed_Text_Extract_Text
#     Feed_Text_All_Language_Spans
#
#***********************************************************************

package feed_text;

use strict;
use warnings;
use File::Basename;
use XML::Parser;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Feed_Text_Debug
                  Feed_Text_Extract_Text
                  Feed_Text_All_Language_Spans
                 );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);
my ($save_text);

my ($debug) = 0;

#
# Variables for XML text parsing
#
my (%language_text, $current_tag, $current_lang, $all_text);
my (@lang_stack, @tag_lang_stack, $last_lang_tag);
my ($feed_lang_value);

my (%xml_tags_with_no_end_tag) = (
        "link",  "link",
);

#***********************************************************************
#
# Name: Start_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles the start of XML tags.
#
#***********************************************************************
sub Start_Handler {
    my ($self, $tagname, %attr_hash) = @_;

    my ($lang);

    #
    # Check for entry tag.
    #
    print "Start_Handler tag $tagname\n" if $debug;

    #
    # Update current tag name.  It doesn't matter if the tag
    # has an end (e.g <a> ... </a> or not, we really only care
    # about the <script> and <style> tags, which do have an end.
    #
    $current_tag = $tagname;

    #
    # Check for xml:lang
    #
    if ( defined($attr_hash{"xml:lang"})) {
        $lang = lc($attr_hash{"xml:lang"});

        #
        # Remove any language dialect
        #
        $lang =~ s/-.*$//g;
        #print "Found xml:lang $lang in $tagname at $line:$column\n" if $debug;

        #
        # Convert possible 2 character code into a 3 character code.
        #
        if ( defined($language_map::iso_639_1_iso_639_2T_map{$lang}) ) {
            $lang = $language_map::iso_639_1_iso_639_2T_map{$lang};
        }

        #
        # Does this tag have a matching end tag ?
        #
        if ( ! defined ($xml_tags_with_no_end_tag{$tagname}) ) {
            #
            # Update the current language and push this one on the language
            # stack. Save the current tag name also.
            #
            push(@lang_stack, $current_lang);
            push(@tag_lang_stack, $last_lang_tag);
            $last_lang_tag = $tagname;
            print "Push language $current_lang on language stack for $tagname\n" if $debug;
            $current_lang = $lang;
            print "Current language = $lang\n" if $debug;
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
            print "Push copy of language  $current_lang on language stack for $tagname\n" if $debug;
        }
    }

    #
    # Is this the <feed> tag ? If so remember it's language value
    #
    if ( $tagname eq "feed" ) {
        $feed_lang_value = $current_lang;
    }
    #
    # If this is an icon tag, don't save its text
    #
    elsif ( $tagname eq "icon" ) {
        $save_text = 0;
    }
    #
    # If this is an id tag, don't save its text
    #
    elsif ( $tagname eq "id" ) {
        $save_text = 0;
    }
    #
    # If this is a logo tag, don't save its text
    #
    elsif ( $tagname eq "logo" ) {
        $save_text = 0;
    }
    #
    # If this is a published tag, don't save its text
    #
    elsif ( $tagname eq "published" ) {
        $save_text = 0;
    }
    #
    # If this is an updated tag, don't save its text
    #
    elsif ( $tagname eq "updated" ) {
        $save_text = 0;
    }
    #
    # If this is an uri tag, don't save its text
    #
    elsif ( $tagname eq "uri" ) {
        $save_text = 0;
    }
}

#***********************************************************************
#
# Name: End_Handler
#
# Parameters: self - reference to this parser
#             tagname - name of tag
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles end tags.
#
#***********************************************************************
sub End_Handler {
    my ($self, $tagname) = @_;

    #
    # Check for entry tag
    #
    print "End_Handler tag $tagname\n" if $debug;
    $current_tag = "";

    #
    # Is this tag the last one that had a language ?
    #
    if ( $tagname eq $last_lang_tag ) {
        #
        # Pop the last language and tag name from the stacks
        #
        $current_lang = pop(@lang_stack);
        $last_lang_tag = pop(@tag_lang_stack);
        if ( ! defined($last_lang_tag) ) {
            print "last_lang_tag not defined\n" if $debug;
        }
        print "Pop language $current_lang from language stack for $tagname\n" if $debug;
    }

    #
    # If this is an icon tag, restart text saving
    #
    if ( $tagname eq "icon" ) {
        $save_text = 1;
    }
    #
    # If this is an id tag, restart text saving
    #
    elsif ( $tagname eq "id" ) {
        $save_text = 1;
    }
    #
    # If this is a logo tag, restart text saving
    #
    elsif ( $tagname eq "logo" ) {
        $save_text = 1;
    }
    #
    # If this is a published tag, restart text saving
    #
    elsif ( $tagname eq "published" ) {
        $save_text = 1;
    }
    #
    # If this is an updated tag, restart text saving
    #
    elsif ( $tagname eq "updated" ) {
        $save_text = 1;
    }
    #
    # If this is an uri tag, restart text saving
    #
    elsif ( $tagname eq "uri" ) {
        $save_text = 1;
    }
}

#***********************************************************************
#
# Name: Char_Handler
#
# Parameters: self - reference to this parser
#             string - text
#
# Description:
#
#   This function is a callback handler for XML parsing that
# handles text content between tags.
#
#***********************************************************************
sub Char_Handler {
    my ($self, $string) = @_;

    #
    # Are we saving text ?
    #
    if ( $save_text ) {
        $language_text{$current_lang} .= $string;
        $all_text .= $string;
        #print "Current language = $current_lang text = $string\n" if $debug;
    }
}

#********************************************************
#
# Name: Feed_Text_Extract_Text
#
# Parameters: input - block of XML text
#
# Description:
#
#   This function extracts text from a block of XML markup.
#
# Returns:
#  language - feed's primary language
#  text - primary language text
#
#********************************************************
sub Feed_Text_Extract_Text {
    my ($input) = @_;

    my ($parser, $lang, $content, $eval_output);

    #
    # Do we have any content ?
    #
    if ( ! defined($input) || ($input eq "") ) {
        print "Feed_Text_Extract_Text No content\n" if $debug;
    }
    print "Feed_Text_Extract_Text_From_XML, content length = " . length($input) .
          "\n" if $debug;

    #
    # Initialize global variables
    #
    %language_text = ();
    $all_text = "";
    $current_lang = "eng";
    push(@lang_stack, $current_lang);
    push(@tag_lang_stack, "top");
    $current_tag = "";
    $last_lang_tag = "top";
    $save_text = 1;
    $feed_lang_value = "eng";

    #
    # Did we get any content ?
    #
    if ( length($input) > 0 ) {
        #
        # Create a parser to parse the XML content.
        #
        print "Create parser object\n" if $debug;
        $parser = XML::Parser->new;

        #
        # Add handlers for some of the XML tags
        #
        $parser->setHandlers(Start => \&Start_Handler);
        $parser->setHandlers(End => \&End_Handler);
        $parser->setHandlers(Char => \&Char_Handler);

        #
        # Parse the content.
        #
        print "Parse the XML content\n" if $debug;
        eval { $parser->parse($input); } ;
        $eval_output = $@ if $@;

        #
        # Do we have any parsing errors ?
        #
        if ( defined($eval_output) ) {
            $language_text{$feed_lang_value} = "***** XML PARSE FAILED *****";
        }
    }

    #
    # Print content by language
    #
    if ( $debug ) {
        while ( ($lang, $content) = each %language_text ) {
            print "Language = $lang Content length = " . length($content) . "\n";
        }
    }

    #
    # Return the content that matches the <feed> tag's lang attribute
    #
    $content = $language_text{$feed_lang_value};
    print "Feed_Text_Extract_Text_From_XML, returned language = $feed_lang_value, length = " .
          length($content) . "\n" if $debug;
    return($feed_lang_value, $content);
}

#********************************************************
#
# Name: Feed_Text_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Feed_Text_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#********************************************************
#
# Name: Feed_Text_All_Language_Spans
#
# Parameters: none
#
# Description:
#
#   This function returns the hash table of language code and
# text content from the previous call to Feed_Text_Extract_Text.
#
# Returns:
#  language/text hash table
#
#********************************************************
sub Feed_Text_All_Language_Spans {

    #
    # Return language/text table
    #
    return(%language_text);
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
    my (@package_list) = ("language_map");

    #
    # Import packages, we don't use a 'use' statement as these packages
    # may not be in the INC path.
    #
    push @INC, "$program_dir";
    foreach $package (@package_list) {
        #
        # Import the package routines.
        #
        require "$package.pm";
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

