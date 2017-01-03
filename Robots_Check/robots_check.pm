#***********************************************************************
#
# Name: robots_check.pm
#
# $Revision: 6721 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Robots_Check/Tools/robots_check.pm $
# $Date: 2014-07-22 12:35:20 -0400 (Tue, 22 Jul 2014) $
#
# Description:
#
#   This file contains routines that validate a robots.txt file.
#
# Public functions:
#     Robots_Check
#     Robots_Check_Debug
#     Robots_Check_Language
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

package robots_check;

use strict;
use URI;
use File::Basename;

#
# Use WPSS_Tool program modules
#
use tqa_result_object;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Robots_Check
                  Robots_Check_Debug
                  Robots_Check_Language
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************
my ($debug) = 0;

#
# String table for UI strings.
#
my %string_table_en = (
    "Line",        "Line: ",
    "without preceding User-agent","without preceding User-agent",
    "Warning: Path name should start with slash", "Warning: Path name should start with slash (/)",
    "Wild card character not allowed", "Wild card character not allowed in path name",
    "Unexpected line", "Unexpected line",
    );

my %string_table_fr = (
    "Line",        "La ligne : ",
    "without preceding User-agent", "sans agent utilisateur précédent",
    "Warning: Path name should start with slash", "Attention : Le nom du chemin d'accès doit commencer pas une barre oblique",
    "Wild card character not allowed", "Caractères de remplacement pas autorisés",
    "Unexpected line", "ligne inattendue",
    );

my ($string_table) = \%string_table_en;


#********************************************************
#
# Name: Robots_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Robots_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Robots_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Robots_Check_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Robots_Check_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Robots_Check_Language, language = English\n" if $debug;
        $string_table = \%string_table_en;
    }
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
# Name: Add_To_Error
#
# Parameters: error_string - existing error string
#             new_error - new error string
#             input_line - line from robots.txt file
#
# Description:
#
#   This function appends an error message and the robots.txt input
# line to string of all errors.
#
#***********************************************************************
sub Add_To_Error {
    my ($error_string, $new_error, $input_line) = @_;

    #
    # Print error if in debug mode
    #
    print $new_error if $debug;
    print $input_line if $debug;

    #
    # Add error to exist string of errors
    #
    $error_string .= $new_error . $input_line;

    #
    # Return new error string
    #
    return($error_string);
}

#***********************************************************************
#
# Name: Robots_Check
#
# Parameters: this_url - URL of robots.txt file
#             txt - pointer to content of robots.txt file
#
# Description:
#
#   This function validates the content of a robots.txt file.
#
#    Implementation based on RobotRules.pm with enhancements.
#
#***********************************************************************
sub Robots_Check {
    my($this_url, $txt) = @_;

    my ($result_object, @results_list, $robot_txt_uri);

    $robot_txt_uri = URI->new("$this_url");

    my $ua;
    my $is_me = 0;		# 1 iff this record is for me
    my $is_anon = 0;		# 1 iff this record is for *
    my $seen_disallow = 0;      # watch for missing record separators
    my $seen_allow = 0;         # watch for missing record separators
    my @me_disallowed = ();	# rules disallowed for me
    my @anon_disallowed = ();	# rules disallowed for *
    my ($line_no) = 0;
    my ($error_string) = "";

    #
    # blank lines are significant, so turn CRLF into LF to avoid generating
    # false ones
    #
    $$txt =~ s/\015\012/\012/g;

    #
    # split at \012 (LF) or \015 (CR) (Mac text files have just CR for EOL)
    #
    for(split(/[\012\015]/, $$txt)) {
        $line_no++;

        #
        # Lines containing only a comment are discarded completely, and
        # therefore do not indicate a record boundary.
        #
	next if /^\s*\#/;

        #
        # remove comments at end-of-line
        #
	s/\s*\#.*//;

        #
        # Is this a blank line ? which is a rule set seperator
        #
	if (/^\s*$/) {	    # blank line
	    $is_anon = 0;
	    $seen_disallow = 0;
	    $seen_allow = 0;
	}

        #
        # Allow directive
        #
        # Some major crawlers support an Allow directive which can
        # counteract a following Disallow directive. This is useful
        # when you disallow an entire directory but still want some
        # HTML documents in that directory crawled and indexed. While
        # by standard implementation the first matching robots.txt
        # pattern always wins.
        #
        elsif (/^\s*Allow\s*:\s*(.*)/i) {
	    unless (defined $ua) {
                $error_string = Add_To_Error($error_string,
                                   String_Value("Line") . 
                                   " $line_no Allow " . 
                                   String_Value("without preceding User-agent") . 
                                   "\n",
                                   " --> $_\n");
		$is_anon = 1;  # assume that User-agent: * was intended
	    }
	    my $allow = $1;
	    $allow =~ s/\s+$//;
	    $seen_allow = 1;
	    if (length $allow) {
		my $ignore;
		eval {
		    my $u = URI->new_abs($allow, $robot_txt_uri);
		    $ignore++ if $u->scheme ne $robot_txt_uri->scheme;
		    $ignore++ if lc($u->host) ne lc($robot_txt_uri->host);
		    $ignore++ if $u->port ne $robot_txt_uri->port;
		    $allow = $u->path_query;
		    $allow = "/" unless length $allow;
		};
		next if $@;
		next if $ignore;

                #
                # Do we have a leading slash character
                #
                if ( !( $allow =~ /^\//) ) {
                    $error_string = Add_To_Error($error_string,
                                       String_Value("Line") .
                                       " $line_no " .
                                       String_Value("Warning: Path name should start with slash") .
                                       "\n",
                                       " --> $_\n");
                    next;
                }
	    }
        }

        #
        # Crawl-delay directive
        #
        # Several major crawlers support a Crawl-delay parameter, set
        # to the number of seconds to wait between successive requests
        # to the same server:
        #
        elsif (/^\s*Crawl-delay\s*:/i) {
	    unless (defined $ua) {
                $error_string = Add_To_Error($error_string,
                                   String_Value("Line") . 
                                   " $line_no Crawl-delay " . 
                                   String_Value("without preceding User-agent") . 
                                   "\n",
                                   " --> $_\n");
		$is_anon = 1;  # assume that User-agent: * was intended
	    }
        }

        #
        # Is this a Disallow line ?
        #
	elsif (/^\s*Disallow\s*:\s*(.*)/i) {
	    unless (defined $ua) {
                $error_string = Add_To_Error($error_string,
                                   String_Value("Line") . 
                                   " $line_no Disallow " . 
                                   String_Value("without preceding User-agent") . 
                                   "\n",
                                   " --> $_\n");
		$is_anon = 1;  # assume that User-agent: * was intended
	    }
	    my $disallow = $1;
	    $disallow =~ s/\s+$//;
	    $seen_disallow = 1;
	    if (length $disallow) {
		my $ignore;
		eval {
		    my $u = URI->new_abs($disallow, $robot_txt_uri);
		    $ignore++ if $u->scheme ne $robot_txt_uri->scheme;
		    $ignore++ if lc($u->host) ne lc($robot_txt_uri->host);
		    $ignore++ if $u->port ne $robot_txt_uri->port;
		    $disallow = $u->path_query;
		    $disallow = "/" unless length $disallow;
		};
		next if $@;
		next if $ignore;

                #
                # Check for wild card character
                #
                if ( $disallow =~ /\*/ ) {
                    $error_string = Add_To_Error($error_string,
                                       String_Value("Line") .
                                       " $line_no " .
                                       String_Value("Wild card character not allowed") .
                                       "\n",
                                       " --> $_\n");
                    next;
                }

                #
                # Do we have a leading slash character
                #
                if ( !( $disallow =~ /^\//) ) {
                    $error_string = Add_To_Error($error_string,
                                       String_Value("Line") .
                                       " $line_no " .
                                       String_Value("Warning: Path name should start with slash") .
                                       "\n",
                                       " --> $_\n");
                    next;
                }
	    }
	}

        #
        # Request-rate directive
        #
        elsif (/^\s*Request-rate\s*:/i) {
            unless (defined $ua) {
                $error_string = Add_To_Error($error_string,
                                   String_Value("Line") . 
                                   " $line_no Request-rate " . 
                                   String_Value("without preceding User-agent") . 
                                   "\n",
                                   " --> $_\n");
                $is_anon = 1;  # assume that User-agent: * was intended
            }
        }

        #
        # Is this a Sitemap line ?
        #
        elsif (/^\s*Sitemap\s*:/i) {
             # ignore
        }

        #
        # Is this a UserAgent line ?
        #
        elsif (/^\s*User-Agent\s*:\s*(.*)/i) {
            $ua = $1;
            $ua =~ s/\s+$//;

            if ($seen_disallow) {
                # treat as start of a new record
                $seen_disallow = 0;
                $is_anon = 0;
            }

            if ($seen_allow) {
                # treat as start of a new record
                $seen_allow = 0;
                $is_anon = 0;
            }

            if ($ua eq '*') {
                $is_anon = 1;
            }
        }

        #
        # Visit-time directive
        #
        elsif (/^\s*Visit-time\s*:/i) {
            unless (defined $ua) {
                $error_string = Add_To_Error($error_string,
                                   String_Value("Line") . 
                                   " $line_no Visit-time " . 
                                   String_Value("without preceding User-agent") . 
                                   "\n",
                                   " --> $_\n");
                $is_anon = 1;  # assume that User-agent: * was intended
            }
        }

        #
        # Unrecognized line
        #
	else {
            $error_string = Add_To_Error($error_string,
                               String_Value("Line") . 
                               " $line_no " . 
                               String_Value("Unexpected line") . 
                               "\n",
                               " --> $_\n");
	}
    }

    #
    # Did we get any error messages ?
    #
    if ( $error_string ne "" ) {
        $result_object = tqa_result_object->new("ROBOTS_VALIDATION",
                                                1,
                                                "ROBOTS_VALIDATION",
                                                -1, -1, "",
                                                $error_string,
                                                $this_url);
        push (@results_list, $result_object);
    }

    #
    # Return status
    #
    return(@results_list);
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

