#***********************************************************************
#
# Name: html_language.pm
#
# $Revision: 6709 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/HTML_Validate/Tools/html_language.pm $
# $Date: 2014-07-22 12:18:41 -0400 (Tue, 22 Jul 2014) $
#
# Description
#
#   This file contains routines to extract the default content language
# from an HTML file.
#
# Public functions:
#     HTML_Language_Debug
#     HTML_Language
#
#***********************************************************************

package html_language;

use strict;
use warnings;
use File::Basename;
use HTML::Parser 3.00 ();

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(HTML_Language_Debug
                  HTML_Language);
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);
my ($debug) = 0;

#
# Variables for HTML
#
my ($html_lang_value);

#***********************************************************************
#
# Name: HTML_Language_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub HTML_Language_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: HTML_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the html tag, it extracts the default language
# of the page, if specified.
#
#***********************************************************************
sub HTML_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    #
    # Do we have a xml:lang attribute ?
    #
    if ( defined($attr{"xml:lang"}) ) {
        #
        # Save language code.
        #
        $html_lang_value =~ s/-.*$//g;
    }
    #
    # Check for lang attribute
    #
    elsif ( defined($attr{"lang"}) ) {
        #
        # Save language code.
        #
        $html_lang_value = lc($attr{"lang"});
    }

    #
    # Strip off any dialect value
    #
    $html_lang_value =~ s/-.*$//g;

    #
    # Convert possible 2 character language code into a 3 character code.
    #
    if ( defined($language_map::iso_639_1_iso_639_2T_map{$html_lang_value}) ) {
        $html_lang_value = $language_map::iso_639_1_iso_639_2T_map{$html_lang_value};
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

    #
    # Check html tag
    #
    $tagname =~ s/\///g;
    if ( $tagname eq "html" ) {
        HTML_Tag_Handler($line, $column, $text, %attr_hash);
    }
}

#***********************************************************************
#
# Name: HTML_Language
#
# Parameters: this_url - a URL
#             profile - testcase profile
#             content - content pointer
#
# Description:
#
#   This function extracts the default language of the page from
# the <html> tag.
#
#***********************************************************************
sub HTML_Language {
    my ($this_url, $content) = @_;

    my ($parser);

    #
    # Initialize language to unknown
    #
    print "HTML_Language: URL $this_url\n" if $debug;
    $html_lang_value = "";

    #
    # Did we get any content ?
    #
    if ( length($$content) > 0 ) {
        #
        # Create a document parser
        #
        $parser = HTML::Parser->new;

        #
        # Add handlers for some of the HTML tags
        #
        $parser->handler(
            start => \&Start_Handler,
            "self,tagname,line,column,text,\@attr"
        );

        #
        # Parse the content.
        #
        $parser->parse($$content);
    }
    else {
        print "No content passed to HTML_Language\n" if $debug;
    }

    #
    # Return language
    #
    print "Language of HTML content is $html_lang_value\n" if $debug;
    return($html_lang_value);
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

