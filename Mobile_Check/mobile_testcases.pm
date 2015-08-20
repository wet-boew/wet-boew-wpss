#***********************************************************************
#
# Name:   mobile_testcases.pm
#
# $Revision: 7155 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Mobile_Check/Tools/mobile_testcases.pm $
# $Date: 2015-05-21 15:15:54 -0400 (Thu, 21 May 2015) $
#
# Description:
#
#   This file contains routines that handle Mobile check
# testcase descriptions.
#
# Public functions:
#     Mobile_Testcase_Language
#     Set_Mobile_Testcase_Debug
#     Mobile_Testcase_Description
#     Mobile_Testcase_Read_URL_Help_File
#     Mobile_Testcase_URL
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

package mobile_testcases;

use strict;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Mobile_Testcase_Language
                  Set_Mobile_Testcase_Debug
                  Mobile_Testcase_Description
                  Mobile_Testcase_Read_URL_Help_File
                  Mobile_Testcase_URL
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
#******************************************************************
#
# String table for testcase help URLs
#
#******************************************************************
#

my (%testcase_url_en, %testcase_url_fr);

#
# Default URLs to English
#
my ($url_table) = \%testcase_url_en;

#
# String tables for testcase ID to testcase descriptions
#
my (%testcase_description_en) = (
#
# Yahoo best practices checkpoints
#    https://developer.yahoo.com/performance/rules.html
#
"COOKIE_FREE",  "COOKIE_FREE: Use Cookie-free Domains for Components",
"COOKIE_SIZE",  "COOKIE_SIZE: Reduce Cookie Size",
"CSS_LINK",     "CSS_LINK: Choose <link> over \@import",
"CSS_TOP",      "CSS_TOP: Put Stylesheets at the Top",
"DNS_LOOKUPS",  "DNS_LOOKUPS: Reduce DNS Lookups",
"EMPTY_SRC",    "EMPTY_SRC: Avoid Empty Image src",
"ETAGS",        "ETAGS: Configure ETags",
"EXPIRES",      "EXPIRES: Add an Expires or a Cache-Control Header",
"EXTERNAL",     "EXTERNAL: Make JavaScript and CSS External",
"FAVICON",      "FAVICON: Make favicon.ico Small and Cacheable",
"GZIP",         "GZIP: Compress Components",
"IFRAMES",      "IFRAMES: Minimize the Number of iframes",
"JS_BOTTOM",    "JS_BOTTOM: Put Scripts at the Bottom",
"JS_DUPES",     "JS_DUPES: Remove Duplicate Scripts",
"MINIFY",       "MINIFY: Minify JavaScript and CSS",
"NO_404",       "NO_404: No 404s",
"NO_SCALE",     "NO_SCALE: Don't Scale Images in HTML",
"NUM_HTTP",     "NUM_HTTP: Minimize HTTP Requests",
"OPT_IMAGES",   "OPT_IMAGES: Optimize Images",
"REDIRECTS",    "REDIRECTS: Avoid Redirects",
);

my (%testcase_description_fr) = (
#
# Yahoo best practices checkpoints
#    https://developer.yahoo.com/performance/rules.html
#
"COOKIE_FREE",  "COOKIE_FREE: Utilisez Domaines Cookie-libres pour les composants",
"COOKIE_SIZE",  "COOKIE_SIZE: Réduire la taille des témoins",
"CSS_LINK",     "CSS_LINK: Utiliser des balises d’hyperliens (<link>) plutôt que des directives d’importation (\@import)",
"CSS_TOP",      "CSS_TOP: Insérer les feuilles de style au haut de la page",
"DNS_LOOKUPS",  "DNS_LOOKUPS: Réduire Recherches DNS",
"EMPTY_SRC",    "EMPTY_SRC: Éviter les attributs « src » vides",
"ETAGS",        "ETAGS: Configurer ETags",
"EXPIRES",      "EXPIRES: Ajouter Expires ou Cache-Control Header",
"EXTERNAL",     "EXTERNAL: Insérer les styles CSS et les objets JavaScript dans des fichiers externes",
"FAVICON",      "FAVICON: Réduire les fichiers « favicon.ico » et les rendre antémémorisables",
"GZIP",         "GZIP: Comprimer les éléments",
"IFRAMES",      "IFRAMES: Minimiser le nombre de iframes",
"JS_BOTTOM",    "JS_BOTTOM: Insérer les scripts au bas de la page",
"JS_DUPES",     "JS_DUPES: Supprimer les scripts redondants",
"MINIFY",       "MINIFY: Minimiser les codes JavaScript et CSS",
"NO_404",       "NO_404: Éviter les codes d’erreur 404",
"NO_SCALE",     "NO_SCALE: Éviter de réduire l’échelle des images en HTML",
"NUM_HTTP",     "NUM_HTTP: Minimiser les requêtes HTTP",
"OPT_IMAGES",   "OPT_IMAGES: Optimiser les fichiers d’images",
"REDIRECTS",    "REDIRECTS: Éviter les réacheminements",
);

#
# Create reverse table, indexed by description
#
my (%reverse_testcase_description_en) = reverse %testcase_description_en;
my (%reverse_testcase_description_fr) = reverse %testcase_description_fr;
my ($reverse_testcase_description_table) = \%reverse_testcase_description_en;

#
# Default messages to English
#
my ($testcase_description_table) = \%testcase_description_en;

#***********************************************************************
#
# Name: Set_Mobile_Testcase_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Mobile_Testcase_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Mobile_Testcase_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Mobile_Testcase_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Mobile_Testcase_Language, language = French\n" if $debug;
        $testcase_description_table = \%testcase_description_fr;
        $reverse_testcase_description_table = \%reverse_testcase_description_fr;
        $url_table = \%testcase_url_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Mobile_Testcase_Language, language = English\n" if $debug;
        $testcase_description_table = \%testcase_description_en;
        $reverse_testcase_description_table = \%reverse_testcase_description_en;
        $url_table = \%testcase_url_en;
    }
}

#**********************************************************************
#
# Name: Mobile_Testcase_Read_URL_Help_File
#
# Parameters: filename - path to help file
#
# Description:
#
#   This function reads a testcase help file.  The file contains
# a list of testcases and the URL of a help page or standard that
# relates to the testcase.  A language field allows for English & French
# URLs for the testcase.
#
#**********************************************************************
sub Mobile_Testcase_Read_URL_Help_File {
    my ($filename) = @_;

    my (@fields, $tcid, $lang, $url);

    #
    # Clear out any existing testcase/url information
    #
    %testcase_url_en = ();
    %testcase_url_fr = ();

    #
    # Check to see that the help file exists
    #
    if ( !-f "$filename" ) {
        print "Error: Missing URL help file\n" if $debug;
        print " --> $filename\n" if $debug;
        return;
    }

    #
    # Open configuration file at specified path
    #
    print "Mobile_Testcase_Read_URL_Help_File Openning file $filename\n" if $debug;
    if ( ! open(HELP_FILE, "$filename") ) {
        print "Failed to open file\n" if $debug;
        return;
    }

    #
    # Read file looking for testcase, language and URL
    #
    while (<HELP_FILE>) {
        #
        # Ignore comment and blank lines.
        #
        chop;
        if ( /^#/ ) {
            next;
        }
        elsif ( /^$/ ) {
            next;
        }

        #
        # Split the line into fields.
        #
        @fields = split(/\s+/, $_, 3);

        #
        # Did we get 3 fields ?
        #
        if ( @fields == 3 ) {
            $tcid = $fields[0];
            $lang = $fields[1];
            $url  = $fields[2];

            #
            # Do we have a testcase to match the ID ?
            #
            if ( defined($testcase_description_en{$tcid}) ) {
                print "Add Testcase/URL mapping $tcid, $lang, $url\n" if $debug;

                #
                # Do we have an English URL ?
                #
                if ( $lang =~ /eng/i ) {
                    $testcase_url_en{$tcid} = $url;
                    $reverse_testcase_description_en{$url} = $tcid;
                }
                #
                # Do we have a French URL ?
                #
                elsif ( $lang =~ /fra/i ) {
                    $testcase_url_fr{$tcid} = $url;
                    $reverse_testcase_description_fr{$url} = $tcid;
                }
                else {
                    print "Unknown language $lang\n" if $debug;
                }
            }
        }
        else {
            print "Line does not contain 3 fields, ignored: \"$_\"\n" if $debug;
        }
    }

    #
    # Close configuration file
    #
    close(HELP_FILE);
}

#**********************************************************************
#
# Name: Mobile_Testcase_URL
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase URL
# table for the specified key.
#
#**********************************************************************
sub Mobile_Testcase_URL {
    my ($key) = @_;

    #
    # Do we have a url table entry for this key ?
    #
    print "Mobile_Testcase_URL, key = $key\n" if $debug;
    if ( defined($$url_table{$key}) ) {
        #
        # return value
        #
        print "value = " . $$url_table{$key} . "\n" if $debug;
        return ($$url_table{$key});
    }
    #
    # Was the testcase description provided rather than the testcase
    # identifier ?
    #
    elsif ( defined($$reverse_testcase_description_table{$key}) ) {
        #
        # return value
        #
        $key = $$reverse_testcase_description_table{$key};
        print "value = " . $$url_table{$key} . "\n" if $debug;
        return ($$url_table{$key});
    }
    else {
        #
        # No url table entry, either we are missing a url or
        # we have a typo in the key name.
        #
        return;
    }
}

#**********************************************************************
#
# Name: Mobile_Testcase_Description
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase description
# table for the specified key.  If there is no entry in the table an error
# string is returned.
#
#**********************************************************************
sub Mobile_Testcase_Description {
    my ($key) = @_;

    #
    # Do we have a string table entry for this key ?
    #
    if ( defined($$testcase_description_table{$key}) ) {
        #
        # return value
        #
        return ($$testcase_description_table{$key});
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
# Mainline
#
#***********************************************************************

#
# Return true to indicate we loaded successfully
#
return 1;


