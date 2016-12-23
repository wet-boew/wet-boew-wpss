#***********************************************************************
#
# Name: textcat.pm
#
# $Revision: 6992 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Content_Check/Tools/textcat.pm $
# $Date: 2015-01-19 09:42:14 -0500 (Mon, 19 Jan 2015) $
#
# Description
#
#   This file contains routines to determine the language of a block
# of text.  
#
# The language catagorization code is a modification of the program
# text_cat written by
#       Gertjan van Noord, 1997.
#	mailto:vannoord@let.rug.nl
#	http://www.let.rug.nl/vannoord/TextCat/
#
#	Distributed under GPL 2.1
#
# Public functions:
#     TextCat_Debug
#     TextCat_Extract_Text_From_HTML
#     TextCat_HTML_Language
#     TextCat_Text_Language
#     TextCat_Supported_Language
#     TextCat_Verbose
#     TextCat_All_Language_Spans
#     TextCat_Too_Close_Languages
#
#***********************************************************************

package textcat;

use strict;
use warnings;
use File::Basename;
use HTML::Parser 3.00 ();
use XML::Parser;

#
# Use WPSS_Tool program modules
#
use language_map;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(TextCat_Debug
                  TextCat_Extract_Text_From_HTML
                  TextCat_HTML_Language
                  TextCat_Text_Language
                  TextCat_Supported_Language
                  TextCat_Verbose
                  TextCat_All_Language_Spans
                  TextCat_Too_Close_Languages);
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
# Set to defaults used for n-grams algorithm implemented in textcat
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);
my (@languages, %language_model, %language_code_map, $save_text);
my ($table_depth, %supported_languages, @last_too_close_languages);

my $non_word_characters = '0-9\s';
my $directory           = 'LM';     #default directory to .lm files

#
# opt_f    Before sorting is performed the Ngrams which occur this number 
#          of times or less are removed. This can be used to speed up
#          the program for longer inputs.
#
my $opt_f               = 0;

#
# opt_t    indicates the topmost number of ngrams that should be used. 
#          If used in combination with -n this determines the size of the 
#          output. If used with categorization this determines
#          the number of ngrams that are compared with each of the language
#          models (but each of those models is used completely). 
#
my $opt_t               = 400;

#
# opt_u    determines how much worse result must be in order not to be 
#          mentioned as an alternative. Typical value: 1.05 or 1.1. 
#
my $opt_u               = 1.05;

my ($debug) = 0;
my ($verbose) = 0;

#
# Minimum and maximum number of characters to analyse
#
my ($MINIMUM_INPUT_LENGTH) = 1000;
my ($MAXIMUM_INPUT_LENGTH) = 25000;

#
# Status values from text catagorization
#
my ($NOT_ENOUGH_TEXT) = -1;
my ($LANGUAGES_TOO_CLOSE) = -2;
my ($INVALID_CONTENT) = -3;
my ($CATAGORIZATION_OK) = 0;

#
# Variables for HTML text parsing
#
my (%inside_html_tag, %language_text, $current_tag, $current_lang, $all_text);
my (@lang_stack, @tag_lang_stack, $last_lang_tag, $html_lang_value);
my ($feed_lang_value);
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
# Name: HTML_Text_Handler
#
# Parameters: text - text string
#
# Description:
#
#   This appends the supplied text to the content string
# unless we are within a script or style tag.
#
#********************************************************
sub HTML_Text_Handler {
    my ($text) = @_;

    #
    # Are we saving text ?
    #
    if ( $save_text ) {
        $language_text{$current_lang} .= $text;
        $all_text .= $text;
        #print "Current language = $current_lang text = $text\n" if $debug;
    }
}

#***********************************************************************
#
# Name: HTML_Start_Handler
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the start of HTML tags.
#
#***********************************************************************
sub HTML_Start_Handler {
    my ( $tagname, $line, $column, @attr ) = @_;

    my (%attr_hash) = @attr;
    my ($lang);
    
    #
    # Update current tag name.  It doesn't matter if the tag
    # has an end (e.g <a> ... </a> or not, we really only care
    # about the <script> and <style> tags, which do have an end.
    #
    $current_tag = $tagname;
    
    #
    # Check for a lang attribute
    #
    if ( defined($attr_hash{"lang"}) ) {
        $lang = lc($attr_hash{"lang"});
        
        #
        # Remove any language dialect
        #
        $lang =~ s/-.*$//g;
        #print "Found lang $lang in $tagname at $line:$column\n" if $debug;
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
        #print "Found xml:lang $lang in $tagname at $line:$column\n" if $debug;
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
            print "Push language $current_lang on language stack for $tagname at $line:$column\n" if $debug;
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
            print "Push copy of language  $current_lang on language stack for $tagname at $line:$column\n" if $debug;
        }
    }

    #
    # Is this the <html> tag ? If so remember it's language value
    #
    if ( $tagname eq "html" ) {
        $html_lang_value = $current_lang;
    }
    #
    # Is this the start of a script ?
    #
    elsif ( $tagname eq "script" ) {
        #
        # Turn off text saving.
        #
        $save_text = 0;
        print "Start of <script> at $line:$column, turn off text saving\n" if $debug;
    }
    #
    # Is this the start of a CSS style ?
    #
    elsif ( $tagname eq "style" ) {
        #
        # Turn off text saving.
        #
        $save_text = 0;
        print "Start of <style> at $line:$column, turn off text saving\n" if $debug;
    }
    #
    # Is this the start of a table ?
    #
    elsif ( $tagname eq "table" ) {
        #
        # Turn off text saving and increment the table depth
        #
        $save_text = 0;
        $table_depth++;
        print "Start of <table> at $line:$column, depth $table_depth, turn off text saving\n" if $debug;
    }
}

#***********************************************************************
#
# Name: HTML_End_Handler
#
# Parameters: tagname - name of tag
#             line - line number
#             column - column number
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end of HTML tags.
#
#***********************************************************************
sub HTML_End_Handler {
    my ( $tagname, $line, $column, @attr ) = @_;

    my (%attr_hash) = @attr;
    
    #
    # Clear current tag name
    #
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
        print "Pop language $current_lang from language stack for $tagname at $line:$column\n" if $debug;
    }

    #
    # Is this the end of a script ?
    #
    if ( $tagname eq "script" ) {
        #
        # Turn on text saving.
        #
        $save_text = 1;
        print "End of <script> at $line:$column, turn on text saving\n" if $debug;
    }
    #
    # Is this the end of a CSS style ?
    #
    elsif ( $tagname eq "style" ) {
        #
        # Turn on text saving.
        #
        $save_text = 1;
        print "End of <style> at $line:$column, turn on text saving\n" if $debug;
    }
    #
    # Is this the end of a table ?
    #
    elsif ( $tagname eq "table" ) {
        #
        # Decrement table depth, if we reach 0 we turn on text saving.
        #
        $table_depth--;
        print "End of <table> at $line:$column, depth $table_depth\n" if $debug;
        if ( $table_depth == 0 ) {
            $save_text = 1;
            print "Turn off text saving\n" if $debug;
        }
    }
}

#********************************************************
#
# Name: TextCat_Extract_Text_From_HTML
#
# Parameters: html_input - pointer to block of HTML text
#
# Description:
#
#   This function extracts text from a block of HTML markup.
#
# Returns:
#  text
#
#********************************************************
sub TextCat_Extract_Text_From_HTML {
    my ($html_input) = @_;

    my ($parser, $lang, $content);

    #
    # Initialize global variables
    #
    %language_text = ();
    $all_text = "";
    %inside_html_tag = ();
    $current_lang = "eng";
    $html_lang_value = "eng";
    push(@lang_stack, $current_lang);
    push(@tag_lang_stack, "top");
    $current_tag = "";
    $last_lang_tag = "top";
    $save_text = 1;
    $table_depth = 0;

    #
    # Do we have any content ?
    #
    if ( (! defined($html_input))
         || (! defined($$html_input))
         || ($$html_input eq "") ) {
        print "TextCat_Extract_Text_From_HTML: No content\n" if $debug;
        return($all_text);
    }
    print "TextCat_Extract_Text_From_HTML, content length = " . length($$html_input) .
          "\n" if $debug;

    #
    # Create a parser to parse the HTML content.
    #
    print "Create parser object\n" if $debug;
    $parser = HTML::Parser->new(api_version => 3,
                                marked_sections => 1);

    #
    # Add handlers for some of the HTML tags
    #
    $parser->handler(
        start => \&HTML_Start_Handler, "tagname,line,column,\@attr"
    );
    $parser->handler(
        end => \&HTML_End_Handler, "tagname,line,column,\@attr"
    );
    $parser->handler(
        text => \&HTML_Text_Handler, "dtext"
    );

    #
    # Parse the HTML to extract the text
    #
    print "Parse the HTML content\n" if $debug;
    $parser->parse($$html_input);

    #
    # Print content by language
    #
    if ( $debug ) {
        while ( ($lang, $content) = each %language_text ) {
            print "Language = $lang Content length = " . length($content) . "\n";
        }
    }

    #
    # Return all the content.
    #
    #print "TextCat_Extract_Text_From_HTML, returned length = " .
    #      length($all_text) . " text = $all_text\n" if $debug;
    return($all_text);
}

#********************************************************
#
# Name: TextCat_All_Language_Spans
#
# Parameters: none
#
# Description:
#
#   This function returns the hash table of language code and
# text content from the previous call to TextCat_Extract_Text_From_HTML.
#
# Returns:
#  language/text hash table
#
#********************************************************
sub TextCat_All_Language_Spans {

    #
    # Return language/text table
    #
    return(%language_text);
}

#********************************************************
#
# Name: TextCat_HTML_Language
#
# Parameters: html_input - pointer to block of HTML text
#
# Description:
#
#   This function determines the language of the input string that
# contains HTML markup.  The text is extracted from the markup and
# the language of the text that is not in a language specific span
# (e.g. <span lang="..">some text</span>) is returned.
#
# Returns:
#
#  language_code - ISO 639 3 letter language code
#  language
#
#********************************************************
sub TextCat_HTML_Language {
    my ($html_input) = @_;

    my ($content);

    #
    # Extract the text from the HTML markup.
    #
    $content = TextCat_Extract_Text_From_HTML($html_input);
    
    #
    # Get the content that matches the <html> tag's lang attribute
    #
    $content = $language_text{$html_lang_value};

    #
    # Return the language of this text
    #
    return(TextCat_Text_Language(\$content));
}

#********************************************************
#
# Name: TextCat_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub TextCat_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#********************************************************
#
# Name: TextCat_Verbose
#
# Parameters: this_verbose - verbose flag
#
# Description:
#
#   This function sets the package verbose flag.
#
#********************************************************
sub TextCat_Verbose {
    my ($this_verbose) = @_;

    #
    # Copy verbose flag to global
    #
    $verbose = $this_verbose;
}

#********************************************************
#
# Name: TextCat_Text_Language
#
# Parameters: content - pointer to a block of text
#
# Description:
#
#   This function determines the language of the input string.
#
# Returns:
#
#  language_code
#  language
#
#********************************************************
sub TextCat_Text_Language {
    my ($content) = @_;

    my (%results, @unknown, $language, @results, $i, $p, $ngram);
    my (@answers, $lang1, $lang2, $text_input, $rc, $input);
    my $maxp    = $opt_t;

    #
    # Check content length, if it is too short, return unknown language
    # (we run the risk of guessing the wrong language).
    #
    if ( defined($content) && (defined($$content)) ) {
        #
        # Get rid of non-ASCII characters. Leaving them has strange 
        # side effects on later text catagorizations.  Execute the
        # cleaning in an eval block to prevent this thread from exiting
        # if there are malformed characters in the string.
        #
        $input = $$content;
        print "TextCat_Text_Language original content length= " . length($input) . "\n" if $debug;
        eval { $input =~ s/[^[:ascii:]]+//g; };
        $rc = $@;
        if ( defined($rc) && ($rc =~ /fatal/i) ) {
            print "Failed to cleanse string of non ascii characters, error = $rc\n" if $debug;
            return("", "unknown", $INVALID_CONTENT);
        }

        #
        # Compress multiple spaces into a single space.
        #
        $input =~ s/\s\s+/ /g;

        #
        # Limit the length of the string to check, if we can't determine the
        # language in a reasonable number or characters, we aren't likely to
        # determine it in the full content length either.
        #
        $input = substr($input, 0, $MAXIMUM_INPUT_LENGTH);

        #
        # Before checking the length of the input, remove any digits.
        # If the content consists of a lot of numbers (e.g. financial
        # statements), it may have enough characters but not enough text.
        #
        $text_input = $input;
        $text_input =~ s/\d//g;
        print "                       trimmed content length= " . length($text_input) . "\n" if $debug;
    }
    else {
        $input = "";
        $text_input = "";
    }

    #
    # Check length of text
    #
    if ( length($text_input) < $MINIMUM_INPUT_LENGTH ) {
        printf("%20s\n", "unknown Not enough text to analyse, length = " .
               length($text_input)) if $debug;
        return("", "unknown", $NOT_ENOUGH_TEXT);
    }
    #print "TextCat_Text_Language content length= " . length($input) . 
    #      "\n$input\n" if $debug;

    #
    # create ngrams for input.
    #
    @unknown = Create_LM(\$input);

    #
    # scan each language model and count matches
    #
    foreach $language (@languages) {
        print "TextCat_Text_Language: Checking language $language\n" if $debug;

        #
        # Get ngram table for this language
        #
        $ngram = $language_model{$language};

        #
        # compare the language model with input ngrams list
        #
        ( $i, $p ) = ( 0, 0 );
        while ( $i < @unknown ) {

            if ( $$ngram{ $unknown[$i] } ) {
                $p = $p + abs( $$ngram{ $unknown[$i] } - $i );
            }
            else {

                $p = $p + $maxp;
            }

            ++$i;
        }
        $results{$language} = $p;
    }

    #
    # Sort results
    #
    @results = sort { $results{$a} <=> $results{$b} } keys %results;

    #
    # Print first 10 results in debug mode
    #
    if ( $debug ) {
        print "Results\n";
        for ($i = 0; $i < 10; $i++) {
            if ( defined($results[$i]) ) {
                $p = $results[$i];
                printf("%20s %6d\n", $p, $results{$p});
            }
        }
    }

    #
    # Check scores for languages to see when we discard poor
    # scoring languages.
    #
    $a = $results{ $results[0] };
    @answers = ( shift(@results) );
    while ( @results && $results{ $results[0] } < ( $opt_u * $a ) ) {
        @answers = ( @answers, shift(@results) );
    }

    #
    # Print first 10 languages in verbose mode
    #
    if ( $verbose ) {
        print "Languages\n";
        for ($i = 0; $i < 10; $i++) {
            if ( defined($answers[$i]) ) {
                $p = $answers[$i];
                printf("%20s %6d\n", $p, $results{$p});
            }
            else {
                last;
            }
        }
    }

    #
    # Compare the results for the top 2 languages, if they are too
    # close in value return unknown rather than selecting the wrong one.
    #
    @last_too_close_languages = ();
    $lang1 = $answers[0];
    if ( @answers > 1 ) {
        $lang2 = $answers[1];
        if ( ($results{$lang2} / $results{$lang1}) < 1.02 ) {
            print "Top 2 languages too close, return unknown language\n" if $debug;

            #
            # Save top 2 languages incase the caller wants to get them
            #
            @last_too_close_languages = ($language_code_map{$lang1},
                                         $language_code_map{$lang2});
            return("", "unknown", $LANGUAGES_TOO_CLOSE);
        }
    }

    #
    # Take the first element of the answers array, that is the language
    # of the content.
    #
    $language = $answers[0];
    print "TextCat_Text_Language $language, " . $language_code_map{$language} .
          "\n" if $debug;
    return($language_code_map{$language}, $language, $CATAGORIZATION_OK);
}

#********************************************************
#
# Name: TextCat_Supported_Language
#
# Parameters: lang - language code
#
# Description:
#
#   This function checks to see if the supplied language is
# supported.
#
#********************************************************
sub TextCat_Supported_Language {
    my ($lang) = @_;

    #
    # Is the language specified supported ?
    #
    if ( defined($supported_languages{$lang}) ) {
        return(1);
    }
    else {
        return(0);
    }
}

#******************************************************************
#
# Name: Create_LM
#
# Parameters: content pointer
#
# Description:
#
#   This function implements the text categorization algorithm 
# presented in Cavnar, W. B. and J. M. Trenkle, 
# "N-Gram-Based Text Categorization"
#
#******************************************************************
sub Create_LM {
    my ($content) = @_;
    my (%ngram, $word, $len, $flen, $i, @sorted);

    #
    # Split content into words
    #
    foreach $word ( split("[$non_word_characters]+", $$content) ) {
        $word = "_" . $word . "_";
        $len  = length($word);
        $flen = $len;

        #
        # Skip words that have more than 25 characters
        #
        if ( $len > 25 ) {
            next;
        }
        for ( $i = 0 ; $i < $flen ; $i++ ) {
            $ngram{ substr( $word, $i, 5 ) }++ if $len > 4;
            $ngram{ substr( $word, $i, 4 ) }++ if $len > 3;
            $ngram{ substr( $word, $i, 3 ) }++ if $len > 2;
            $ngram{ substr( $word, $i, 2 ) }++ if $len > 1;
            $ngram{ substr( $word, $i, 1 ) }++;
            $len--;
        }
    }

    #
    # as suggested by Karel P. de Vos, k.vos@elsevier.nl, we speed up
    # sorting by removing singletons
    #
    map {
        my $key = $_;
        if ( $ngram{$key} <= $opt_f ) { delete $ngram{$key}; }
    } keys %ngram;

    #
    # however I have very bad results for short inputs, this way
    #
    # sort the ngrams, and spit out the $opt_t frequent ones.
    # adding  `or $a cmp $b' in the sort block makes sorting five
    # times slower..., although it would be somewhat nicer (unique result)
    #
    # Sort the keys of %ngram so we get consistent behaviour 
    # for hash elements with the same value but different keys.
    #
    @sorted = sort { $ngram{$b} <=> $ngram{$a} } sort(keys %ngram);
    splice( @sorted, $opt_t ) if ( @sorted > $opt_t );

    #
    # Return list
    #
    return @sorted;
}

#******************************************************************
#
# Name: Load_Language_Model_File
#
# Parameters: language - language
#             filename - name of language model file
#
# Description:
#
#   Read in the language model file lines into an array;
#
#******************************************************************
sub Load_Language_Model_File {
    my ($language, $filename) = @_;

    my (%ngram);
    my ($rang)  = 1;

    #
    # Open the language file
    #
    print "TextCat: Read language model file $program_dir/$directory/$filename\n" if $debug;
    open( LM, "$program_dir/$directory/$filename" )
          || die "cannot open $filename: $!\n";

    #
    # Read the file and fill in the ngram table
    #
    while ( <LM> ) {
        chomp;

        #
        # only use lines starting with appropriate character. Others are
        # ignored.
        #
        if (/^[^$non_word_characters]+/o) {
            $ngram{$&} = $rang++;
        }
    }
    close(LM);

    #
    # Save address of the ngram table in global language model hash table
    #
    $language_model{$language} = \%ngram;
}

#******************************************************************
#
# Name: Load_Language_Models
#
# Parameters: none
#
# Description:
#
#   Loads the language model files into memory if they are 
# not already loaded.
#
#******************************************************************
sub Load_Language_Models {

    my ($lang_code, $filename, $line, $language);

    #
    # Look for language mapping file.
    #
    if ( ! -f "$program_dir/$directory/language_map.txt" ) {
        print "Error: Missing language mapping file\n";
        print " --> $program_dir/$directory/language_map.txt\n";
        exit(1);
    }

    #
    # Open language mapping file to get language code and
    # language file name.
    #
    open(LANG_MAP, "$program_dir/$directory/language_map.txt") ||
        die "Error: Failed to open language mapping file\n -->$program_dir/$directory/language_map.txt\n";

    #
    # Read lines from language mapping file
    #
    while ( $line = <LANG_MAP> ) {
        #
        # Remove leading white space
        #
        chop($line);
        $line =~ s/^\s+//g;

        #
        # Ignore blank lines
        #
        if ( $line =~ /^$/ ) {
            next;
        }

        #
        # Ignore comment lines
        #
        elsif ( $line =~ /^#/ ) {
            next;
        }

        #
        # Split line on white space, we only expect 2 fields
        #
        ($lang_code, $filename) = split(/\s+/, $line, 2);

        #
        # If we are missing a file name, ignore the line
        #
        if ( defined($filename) && ($filename ne "") ) {
            #
            # Strip off trailing .lm to get langauge name.
            #
            $language = $filename;
            $language =~ s/.lm$//g;

            #
            # Add language to list of languages
            #
            push(@languages, $language);

            #
            # Read in the language model
            #
            Load_Language_Model_File($language, $filename);

            #
            # Save language code/language filename mapping
            #
            $language_code_map{$language} = $lang_code;
            $supported_languages{$lang_code} = 1;
        }
    }

    #
    # Close the language map file
    #
    close(LANG_MAP);

    #
    # Did we find any languages ?
    #
    if ( @languages == 0 ) {
        print "Error: No language files specified in language map\n";
        print " --> $program_dir/$directory/language_map.txt\n";
        exit(1);
    }

    #
    # Add an entry in the language code/language filename mapping
    # for an unknown language.  The language code is an empty string.
    #
    $language_code_map{"unknown"} = "";
}

#***********************************************************************
#
# Name: TextCat_Too_Close_Languages
#
# Parameters: none
#
# Description:
#
#   This function returns the list of languages from the last text
# catagorization that resulted in a "too close languages" status.
#
#***********************************************************************
sub TextCat_Too_Close_Languages {

    return(@last_too_close_languages);
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
# Load language models
#
Load_Language_Models();

#
# Return true to indicate we loaded successfully
#
return 1;

