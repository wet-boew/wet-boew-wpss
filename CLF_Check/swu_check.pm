#***********************************************************************
#
# Name:   swu_check.pm
#
# $Revision: 5267 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/TQA_Check/Tools/tqa_check.pm $
# $Date: 2011-05-17 12:00:03 -0400 (Tue, 17 May 2011) $
#
# Description:
#
#   This file contains routines that parse HTML files and check for
# a number of Standard on Web Usability check points.
#
# Public functions:
#     Set_CLF_Check_Language
#     Set_SWU_Check_Debug
#     Set_SWU_Check_Testcase_Data
#     Set_SWU_Check_Test_Profile
#     SWU_Check_Read_URL_Help_File
#     SWU_Check_Testcase_URL
#     SWU_Check
#     SWU_Check_Links
#     SWU_Check_Archive_Check
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

package swu_check;

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
    @EXPORT  = qw(Set_SWU_Check_Language
                  Set_SWU_Check_Debug
                  Set_SWU_Check_Testcase_Data
                  Set_SWU_Check_Test_Profile
                  SWU_Check_Read_URL_Help_File
                  SWU_Check_Testcase_URL
                  SWU_Check
                  SWU_Check_Links
                  SWU_Check_Archive_Check
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($debug) = 0;
my (%testcase_data, %required_template_sections);
my (@paths, $this_path, $program_dir, $program_name, $paths);

my ($current_clf_check_profile);
my ($results_list_addr, $content_section_handler, @content_lines);
my ($favicon_count, $in_head_section, $found_date_modified_label);
my (%content_subsection_found, $current_url, $found_date_modified_value);
my ($favicon_resp, $have_text_handler, @text_handler_tag_list);
my ($current_text_handler_tag, @text_handler_text_list);
my ($current_url_language, $found_form, $found_search_button);
my ($found_search_field, %subsection_text, $inside_li);
my ($favicon_url) = "";

#
my (%initialize_testcase_profile) = (
    "SWU_TEMPLATE", 1,
);
my (%clf_check_profile_map) = (
    "", \%initialize_testcase_profile,
);

my ($max_error_message_string) = 2048;

#
# Document section testcase data
#
my (@skip_links_hrefs);
my (%gc_nav_links, %gc_nav_link_hrefs, 
    %gc_nav_optional_links, %gc_nav_optional_link_hrefs,
    %gc_nav_images);
my (%breadcrumb_links, %breadcrumb_link_hrefs, 
    %breadcrumb_optional_links, %breadcrumb_optional_link_hrefs);
my (%site_banner_images, %search_button_values);
my (%date_modified_labels, %date_modified_format,
    $date_modified_metadata_tag, $date_modified_metadata_value);
my (%terms_cond_footer_links, %terms_cond_footer_link_hrefs);
my (%site_footer_links, %site_footer_link_hrefs, 
    %site_footer_optional_links, %site_footer_optional_link_hrefs,
    %site_footer_link_set);
my (%gc_footer_links, %gc_footer_link_hrefs, 
    %gc_footer_optional_links, %gc_footer_optional_link_hrefs);
my (%splash_header_images, %splash_lang_images,
    %splash_lang_links, %splash_lang_hrefs,
    %splash_footer_links, %splash_footer_hrefs);
my (%server_header_images,
    %server_content_links, %server_content_hrefs,
    %server_footer_links, %server_footer_hrefs);

#
# Status values
#
my ($clf_check_pass)       = 0;
my ($clf_check_fail)       = 1;

#
# String table for error strings.
#
my %string_table_en = (
    "at line:column",                 " at (line:column) ",
    "Missing links in",               "Missing links in",
    "Missing images in",              "Missing images in",
    "Found",                          "Found ",
    "links",                          "links",
    "link",                           "link",
    "images",                         "images",
    "image",                          "image",
    "in",                             " in ",
    "in URL",                         " in URL ",
    "Missing content section markers for", "Missing content section markers for ",
    "GC navigation bar",              "GC navigation bar",
    "Breadcrumb",                     "Breadcrumb",
    "GC footer",                      "GC footer",
    "Invalid anchor text",            "Invalid anchor text ",
    "Invalid href",                   "Invalid 'href' ",
    "expecting",                      "expecting ",
    "expecting one of",               "expecting one of ",
    "New heading level",              "New heading level ",
    "is not equal to last level",     " is not equal to last level ",
    "Displayed e-mail address does not match mailto",  "Displayed e-mail address does not match 'mailto'",
    "Multiple <h1> tags found in section", "Multiple <h1> tags found in section",
    "Missing favicon",                 "Missing 'favicon'",
    "Missing URL in href for favicon", "Missing URL in href for 'favicon'",
    "Invalid URL in href for favicon", "Invalid URL in href for 'favicon'",
    "Broken link in href for favicon", "Broken link in href for 'favicon'",
    "Multiple favicons on web page",   "Multiple favicons on web page",
    "favicon is not an image",         "favicon is not an image",
    "First breadcrumb URL",            "First breadcrumb URL",
    "does not match site banner URL",  "does not match site banner URL",
    "Missing link in site title",      "Missing link in site title",
    "Site footer",                     "Site footer",
    "Multiple Date Modified found",    "Multiple \"Date Modified\" found",
    "Date Modified not found",         "Date Modified not found. ",
    "Expecting one of",                "Expecting one of",
    "Missing content for date modified",     "Missing content for \"Date Modified\"",
    "Year",                            "Year ",
    "out of range 1900-2100",          " out of range 1900-2100",
    "Month",                           "Month ",
    "out of range 1-12",               " out of range 1-12",
    "Date",                            "Date ",
    "out of range 1-31",               " out of range 1-31",
    "Invalid date modified value",     "Invalid \"Date Modified\" value ",
    "not in YYYY-MM-DD format",        " not in YYYY-MM-DD format",
    "Site banner",                     "Site banner",
    "Site navigation",                 "Site navigation bar",
    "Invalid alt text",                "Invalid alt text",
    "Multiple search input fields found", "Multiple search input fields found",
    "Multiple search buttons found",   "Multiple search buttons found",
    "Incorrect search button found",   "Incorrect search button found",
    "Missing search input field",      "Missing search input field",
    "Missing search button",           "Missing search button",
    "Missing link",                    "Missing link",
    "Language selection links",        "Language selection links",
    "Terms and conditions",            "Terms and conditions link",
    "Server page title links",         "Server page title links",
    "Body links",                      "Body links",
    "Body images",                     "Body images",
    "Missing site title",              "Missing site title",
    "Missing site title link",         "Missing site title link",
    "Splash page header",              "Splash page: Header",
    "Server message page header",      "Server message page: Header",
    "Extra links in",                  "Extra links in",
    "Extra input field found in Search form", "Extra input field found in Search form",
    "Missing size in search text input field", "Missing size in search text input field",
    "Incorrect size in search text input field", "Incorrect size in search text input field",
    "Breadcrumb link found outside li",  "Breadcrumb link found outside <li>",
    "Missing required link",           "Missing required link",
    "Image link found in",             "Image link found in",
    "Missing content from metadata tag", "Missing content from metadata tag",
    "Date modified metadata tag",      "Date modified metadata tag",
    "value",                           "value",
    "does not match",                  "does not match",
    "not found",                       "not found",
    "Missing skip links",              "Missing skip links",
    );

#
# String table for error strings (French).
#
my %string_table_fr = (
    "at line:column",                 " à (la ligne:colonne) ",
    "Missing links in",               "Manquantes liens dans",
    "Missing images in",              "Manquantes images dans",
    "Found",                          "Trouvé ",
    "links",                          "liens",
    "link",                           "lien",
    "images",                         "images",
    "image",                          "image",
    "in",                             " dans ",
    "in URL",                         " dans URL ",
    "Missing content section markers for", "Manquantes marqueurs section de contenu pour les ",
    "GC navigation bar",              "la barre de navigation du GC",
    "Breadcrumb",                     "Pistes de navigation",
    "GC footer",                      "pied de page du gouvernement du Canada",
    "Invalid anchor text",            "Invalide le texte d'ancre ",
    "Invalid href",                   "Invalide 'href' ",
    "expecting",                      "expectant ",
    "expecting one of",               "expectant un des ",
    "New heading level",              "Nouveau niveau d'en-tête ",
    "is not equal to last level",    " n'est pas égal à au dernier niveau ",
    "Displayed e-mail address does not match mailto", "L'adresse courriel affichée ne correspond pas au 'mailto'",
    "Multiple <h1> tags found in section", "Plusieurs balises <h1> trouvé dans la section",
    "Missing favicon",                "Manquantes 'favoricône'",
    "Missing URL in href for favicon", "Manquantes URL dans 'href' pour 'favoricône'",
    "Invalid URL in href for favicon", "URL non valide dans 'href' pour 'favoricône'",
    "Broken link in href for favicon", "Lien brisé dans 'href' pour 'favoricône'",
    "Multiple favicons on web page",   "'favoricône' multiples dans la page web",
    "favicon is not an image",         "'favoricône' n'est pas une image",
    "First breadcrumb URL",            "Première URL du pistes de navigation",
    "does not match site banner URL",  "ne correspond pas à URL bannière du site",
    "Missing link in site title",      "Manquantes lien dans le titre du site",
    "Site footer",                     "Pied de page du site",
    "Multiple Date Modified found",    "Trouvés multiples \"Date de modification\"",
    "Date Modified not found",         "Ne pas trouvée Date de modification. ",
    "Expecting one of",                "Expectant une de",
    "Missing content for date modified",     "Contenu manquant pour \"Date Modified\"",
    "Year",                            "Année ",
    "out of range 1900-2100",          " hors de portée 1900-2000",
    "Month",                           "Mois ",
    "out of range 1-12",               " hors de portée 1-12",
    "Date",                            "Date ",
    "out of range 1-31",               " hors de portée 1-31",
    "Invalid date modified value",     "Invalide \"Date de modification\" ",
    "not in YYYY-MM-DD format",        " pas au format AAAA-MM-DD",
    "Site banner",                     "Bannière du site",
    "Site navigation",                 "Barre de navigation du site",
    "Invalid alt text",                "Invalide le texte 'alt'",
    "Multiple search input fields found", "Trouvés plusieurs champs de recherche",
    "Multiple search buttons found",   "Trouvés plusieurs boutons de recherche",
    "Incorrect search button found",   "trouve le bouton de recherche incorrect",
    "Missing search input field",      "Manquantes champs de recherche",
    "Missing search button",           "Manquantes bouton de recherche",
    "Missing link",                    "Manquantes lien",
    "Language selection links",        "Liens de sélection de la langue d'affichage",
    "Terms and conditions",            "Lien 'Avis'",
    "Server page title links",         "Liens dans le titre du pages de messages du serveur",
    "Body links",                      "Liens dans le corps",
    "Body images",                     "Images dans le corps",
    "Missing site title",              "Titre de site manquantes",
    "Missing site title link",         "Lien pour le titre de site manquantes",
    "Splash page header",              "Pages d'entrée: En-tête",
    "Server message page header",      "Pages de messages du serveur: En-tête",
    "Extra links in",                  "Liens supplémentaires dans",
    "Extra input field found in Search form", "Champ de saisie supplémentaire dans formulaire de recherche",
    "Missing size in search text input field", "La taille manquante dans le champ de saisie de recherche de texte",
    "Incorrect size in search text input field", "La taille incorrecte dans le champ de saisie de recherche de texte",
    "Breadcrumb link found outside li",  "Trouvé piste de navigation en dedors de <li>",
    "Missing required link",           "Lien requis manquant",
    "Image link found in",             "Lien contenant une image dans",
    "Missing content from metadata tag", "Contenu manquant de balise de métadonnées",
    "Date modified metadata tag",      "Balise de métadonnées pour Date de modification",
    "value",                           "valeur",
    "does not match",                  "ne correspondent pas",
    "not found",                       "ne pas trouvée",
    "Missing skip links",              "skip links manquant",
    );

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

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
# Standard on Web Usability checkpoints
#
"SWU_6.1.5",     "SWU_6.1.5: Archived Web page notice",
"SWU_E2.1",      "SWU_E2.1: Displays the favicon prescribed by the Federal Identity Program",
"SWU_E2.2.2",    "SWU_E2.2.2: Content pages, Federal Identity Program signature",
"SWU_E2.2.3",    "SWU_E2.2.3: Content pages, Canada Wordmark",
"SWU_E2.2.4",    "SWU_E2.2.4: Content pages, Official language selection link",
"SWU_E2.2.5",    "SWU_E2.2.5: Content pages, Header",
"SWU_E2.2.6",    "SWU_E2.2.6: Content pages, Body",
"SWU_E2.2.7",    "SWU_E2.2.7: Content pages, Footer",
"SWU_E2.4",      "SWU_E2.4: Splash Pages",
"SWU_E2.5",      "SWU_E2.5: Server Message Pages",
"SWU_TEMPLATE",  "SWU_TEMPLATE: Template markers",
);

my (%testcase_description_fr) = (
#
# Standard on Web Usability checkpoints
#
"SWU_6.1.5",     "SWU_6.1.5: Avis de page Web archivée",
"SWU_E2.1",      "SWU_E2.1: Affiche le favoricône prescrit par le Programme de coordination de l'image de marque",
"SWU_E2.2.2",    "SWU_E2.2.2: Pages de contenu, Signature visuelle prescrite par le Programme de coordination de l'image de marque",
"SWU_E2.2.3",    "SWU_E2.2.3: Pages de contenu, Mot-symbole Canada",
"SWU_E2.2.4",    "SWU_E2.2.4: Pages de contenu, Lien de sélection de la langue d'affichage",
"SWU_E2.2.5",    "SWU_E2.2.5: Pages de contenu, Header",
"SWU_E2.2.6",    "SWU_E2.2.6: Pages de contenu, Corps",
"SWU_E2.2.7",    "SWU_E2.2.7: Pages de contenu, Pied de page",
"SWU_E2.4",      "SWU_E2.4: Pages d'entrée",
"SWU_E2.5",      "SWU_E2.5: Pages de messages du serveur",
"SWU_TEMPLATE",  "SWU_TEMPLATE: Marqueurs du gabarit",
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
# Name: Set_SWU_Check_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_SWU_Check_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#**********************************************************************
#
# Name: Set_SWU_Check_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_SWU_Check_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_SWU_Check_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
        $testcase_description_table = \%testcase_description_fr;
        $reverse_testcase_description_table = \%reverse_testcase_description_fr;
        $url_table = \%testcase_url_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_SWU_Check_Language, language = English\n" if $debug;
        $string_table = \%string_table_en;
        $testcase_description_table = \%testcase_description_en;
        $reverse_testcase_description_table = \%reverse_testcase_description_en;
        $url_table = \%testcase_url_en;
    }
}

#**********************************************************************
#
# Name: SWU_Check_Read_URL_Help_File
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
sub SWU_Check_Read_URL_Help_File {
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
    print "SWU_Check_Read_URL_Help_File Openning file $filename\n" if $debug;
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
# Name: SWU_Check_Testcase_URL
#
# Parameters: key - testcase id
#
# Description:
#
#   This function returns the value in the testcase URL
# table for the specified key.
#
#**********************************************************************
sub SWU_Check_Testcase_URL {
    my ($key) = @_;

    #
    # Do we have a string table entry for this key ?
    #
    print "SWU_Check_Testcase_URL, key = $key\n" if $debug;
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
        # No string table entry, either we are missing a string or
        # we have a typo in the key name.
        #
        return;
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
# Name: Header_Section_Testcase_Data
#
# Parameters: testcase - testcase identifier
#             data - string of data
#
# Description:
#
#   This function copies the passed header section testcase data into
# global data structures.
#
#***********************************************************************
sub Header_Section_Testcase_Data {
    my ($testcase, $data) = @_;

    my (@empty_list, $lang, $type, $list_addr, $subsection, $text);
    my (@href_list);

    #
    # Extract the language, subsection type and text from the data
    #
    ($lang, $subsection, $type, $text) = split(/\s+/, $data, 4);

    #
    # Is this a link href ?
    #
    if ( defined($text) && ($type eq "HREF") ) {
        #
        # Is this the GC Navigation subsection
        #
        if ( $subsection eq "GC_NAV" ) {
            #
            # Do we have a list of hrefs yet ?
            #
            if ( ! defined($gc_nav_link_hrefs{$lang}) ) {
                $gc_nav_link_hrefs{$lang} = \@empty_list;
            }

            #
            # Split text into a list of possible href values
            #
            @href_list = split(/\s+/, $text);

            #
            # Save link text details
            #
            $list_addr = $gc_nav_link_hrefs{$lang};
            push(@$list_addr, \@href_list);
        }
    }
    #
    # Is this link text ?
    #
    elsif ( defined($text) && ($type eq "LINK") ) {
        #
        # Is this the GC Navigation subsection
        #
        if ( $subsection eq "GC_NAV" ) {
            if ( ! defined($gc_nav_links{$lang}) ) {
                $gc_nav_links{$lang} = \@empty_list;
            }

            #
            # Save link text details
            #
            $list_addr = $gc_nav_links{$lang};
            push(@$list_addr, $text);
        }
        #
        # Breadcrumb links
        #
        elsif ( $subsection eq "BREADCRUMB" ) {
            if ( ! defined($breadcrumb_links{$lang}) ) {
                $breadcrumb_links{$lang} = \@empty_list;
            }

            #
            # Save link text details
            #
            $list_addr = $breadcrumb_links{$lang};
            push(@$list_addr, $text);
        }
    }
    #
    # Is this the language link text ?
    #
    elsif ( defined($text) && ($type eq "LANGUAGE_LINK") ) {
        #
        # Is this the GC Navigation subsection
        #
        if ( $subsection eq "GC_NAV" ) {
            if ( ! defined($gc_nav_optional_links{$lang}) ) {
                $gc_nav_optional_links{$lang} = \@empty_list;
            }

            #
            # Save link text details
            #
            $list_addr = $gc_nav_optional_links{$lang};
            push(@$list_addr, $text);
        }
    }
    #
    # Is this image alt text ?
    #
    elsif ( defined($text) && ($type eq "IMAGE_ALT") ) {
        #
        # Is this the GC Navigation subsection
        #
        if ( $subsection eq "GC_NAV" ) {
            if ( ! defined($gc_nav_images{$lang}) ) {
                $gc_nav_images{$lang} = \@empty_list;
            }

            #
            # Save image alt text details
            #
            $list_addr = $gc_nav_images{$lang};
            push(@$list_addr, $text);
        }
        #
        # Site Banner images
        #
        elsif ( $subsection eq "SITE_BANNER" ) {
            if ( ! defined($site_banner_images{$lang}) ) {
                $site_banner_images{$lang} = \@empty_list;
            }

            #
            # Save image alt text details
            #
            $list_addr = $site_banner_images{$lang};
            push(@$list_addr, $text);
        }
    }
    #
    # Is this search button text ?
    #
    elsif ( defined($text) && ($type eq "BUTTON") ) {
        #
        # Is this the Site Banner subsection
        #
        if ( $subsection eq "SITE_BANNER" ) {
            if ( ! defined($search_button_values{$lang}) ) {
                $search_button_values{$lang} = \@empty_list;
            }

            #
            # Save image search button label details
            #
            $list_addr = $search_button_values{$lang};
            push(@$list_addr, $text);
        }
    }
}

#***********************************************************************
#
# Name: Content_Section_Testcase_Data
#
# Parameters: testcase - testcase identifier
#             data - string of data
#
# Description:
#
#   This function copies the passed content section testcase data into
# global data structures.
#
#***********************************************************************
sub Content_Section_Testcase_Data {
    my ($testcase, $data) = @_;

    my (@empty_list, $lang, $format, $list_addr, $subsection, $text);

    #
    # Extract the language, subsection format and text from the data
    #
    ($lang, $subsection, $format, $text) = split(/\s+/, $data, 4);

    #
    # Check for a possible metadata testcase setting.  The usual testcase
    # data entry consists of language, subsection, format, label, the
    # metadata tag entry does not have a language it starts with
    # DATE_MODIFIED
    #
    if ( defined($format) && ($lang eq "DATE_MODIFIED") &&
         ($subsection eq "METADATA") ) {
        $date_modified_metadata_tag = $format;
        print "Date modified metadata tag = $date_modified_metadata_tag\n" if $debug;
    }
    #
    # Do we have a label for the Date Modified subsection ?
    #
    elsif ( defined($text) && ($subsection eq "DATE_MODIFIED") ) {
        #
        # Do we have a language specific list already ?
        #
        if ( ! defined($date_modified_labels{$lang}) ) {
            $date_modified_labels{$lang} = \@empty_list;
        }

        #
        # Save format and label
        #
        $date_modified_format{$text} = $format;
        $list_addr = $date_modified_labels{$lang};
        push(@$list_addr, $text);
    }
}

#***********************************************************************
#
# Name: Footer_Section_Testcase_Data
#
# Parameters: testcase - testcase identifier
#             data - string of data
#
# Description:
#
#   This function copies the passed footer section testcase data into
# global data structures.
#
#***********************************************************************
sub Footer_Section_Testcase_Data {
    my ($testcase, $data) = @_;

    my (@empty_list, $lang, $type, $list_addr, $subsection, $text);
    my (@href_list);

    #
    # Extract the language, subsection type and text from the data
    #
    ($lang, $subsection, $type, $text) = split(/\s+/, $data, 4);

    #
    # Is this a link href ?
    #
    if ( defined($text) && ($type eq "HREF") ) {
        #
        # Is this the GC footer subsection
        #
        if ( $subsection eq "GC_FOOTER" ) {
            if ( ! defined($gc_footer_link_hrefs{$lang}) ) {
                $gc_footer_link_hrefs{$lang} = \@empty_list;
            }

            #
            # Split text into a list of possible href values
            #
            @href_list = split(/\s+/, $text);

            #
            # Save link text details
            #
            $list_addr = $gc_footer_link_hrefs{$lang};
            push(@$list_addr, \@href_list);
        }
    }
    #
    # Is this link text ?
    #
    if ( defined($text) && ($type eq "LINK") ) {
        #
        # Is this the terms and conditions subsection
        #
        if ( $subsection eq "TERMS_CONDITIONS_FOOTER" ) {
            if ( ! defined($terms_cond_footer_links{$lang}) ) {
                $terms_cond_footer_links{$lang} = \@empty_list;
            }

            #
            # Save link text details
            #
            $list_addr = $terms_cond_footer_links{$lang};
            push(@$list_addr, $text);
        }
        #
        # Is this the Site footer subsection
        #
        elsif ( $subsection eq "SITE_FOOTER" ) {
            if ( ! defined($site_footer_links{$lang}) ) {
                $site_footer_links{$lang} = \@empty_list;
            }

            #
            # Save link text details
            #
            $list_addr = $site_footer_links{$lang};
            push(@$list_addr, $text);
        }
        #
        # GC Footer links
        #
        elsif ( $subsection eq "GC_FOOTER" ) {
            if ( ! defined($gc_footer_links{$lang}) ) {
                $gc_footer_links{$lang} = \@empty_list;
            }

            #
            # Save link text details
            #
            $list_addr = $gc_footer_links{$lang};
            push(@$list_addr, $text);
        }
    }
    #
    # Is this link text for links that must appear even though we don't
    # have a fixed order ?
    #
    if ( defined($text) && ($type eq "LINK_SET") ) {
        #
        # Is this the Site footer subsection
        #
        if ( $subsection eq "SITE_FOOTER" ) {
            if ( ! defined($site_footer_link_set{$lang}) ) {
                $site_footer_link_set{$lang} = \@empty_list;
            }

            #
            # Save link text details
            #
            $list_addr = $site_footer_link_set{$lang};
            push(@$list_addr, $text);
        }
    }
}

#***********************************************************************
#
# Name: Splash_Page_Testcase_Data
#
# Parameters: testcase - testcase identifier
#             data - string of data
#
# Description:
#
#   This function copies the passed splash page testcase data into
# global data structures.
#
#***********************************************************************
sub Splash_Page_Testcase_Data {
    my ($testcase, $data) = @_;

    my (@empty_list, $lang, $type, $list_addr, $subsection, $text);
    my (@href_list);

    #
    # Extract the language, subsection type and text from the data
    #
    ($lang, $subsection, $type, $text) = split(/\s+/, $data, 4);

    #
    # Is this the page header subsection ?
    #
    if ( defined($text) && ($subsection eq "HEADER") ) {
        #
        # Is this image alt text ?
        #
        if ( $type eq "IMAGE_ALT" ) {
            if ( ! defined($splash_header_images{$lang}) ) {
                $splash_header_images{$lang} = \@empty_list;
            }

            #
            # Save alt text details
            #
            $list_addr = $splash_header_images{$lang};
            push(@$list_addr, $text);
        }
    }
    #
    # Is this the language links subsection ?
    #
    elsif ( defined($text) && ($subsection eq "SPLASH_LANG_LINKS") ) {
        #
        # Is this a language link ?
        #
        if ( $type eq "LINK" ) {
            if ( ! defined($splash_lang_links{$lang}) ) {
                $splash_lang_links{$lang} = \@empty_list;
            }

            #
            # Save link text details
            #
            $list_addr = $splash_lang_links{$lang};
            push(@$list_addr, $text);
        }
        #
        # Is this an href value ?
        #
        elsif ( $type eq "HREF" ) {
            if ( ! defined($splash_lang_hrefs{$lang}) ) {
                $splash_lang_hrefs{$lang} = \@empty_list;
            }

            #
            # Split text into a list of possible href values
            #
            @href_list = split(/\s+/, $text);

            #
            # Save link text details
            #
            $list_addr = $splash_lang_hrefs{$lang};
            push(@$list_addr, \@href_list);
        }
        #
        # Is this image alt text ?
        #
        elsif ( $type eq "IMAGE_ALT" ) {
            if ( ! defined($splash_lang_images{$lang}) ) {
                $splash_lang_images{$lang} = \@empty_list;
            }

            #
            # Save alt text details
            #
            $list_addr = $splash_lang_images{$lang};
            push(@$list_addr, $text);
        }
    }
    #
    # Is this the splash footer subsection ?
    #
    if ( defined($text) && ($subsection eq "TERMS_CONDITIONS_FOOTER") ) {
        #
        # Is this link text ?
        #
        if ( $type eq "LINK" ) {
            if ( ! defined($splash_footer_links{$lang}) ) {
                $splash_footer_links{$lang} = \@empty_list;
            }

            #
            # Save link text details
            #
            $list_addr = $splash_footer_links{$lang};
            push(@$list_addr, $text);
        }
        #
        # Is this an href value ?
        #
        elsif ( $type eq "HREF" ) {
            if ( ! defined($splash_footer_hrefs{$lang}) ) {
                $splash_footer_hrefs{$lang} = \@empty_list;
            }

            #
            # Split text into a list of possible href values
            #
            @href_list = split(/\s+/, $text);

            #
            # Save link text details
            #
            $list_addr = $splash_footer_hrefs{$lang};
            push(@$list_addr, \@href_list);
        }
    }
}

#***********************************************************************
#
# Name: Server_Page_Testcase_Data
#
# Parameters: testcase - testcase identifier
#             data - string of data
#
# Description:
#
#   This function copies the passed server message page testcase data into
# global data structures.
#
#***********************************************************************
sub Server_Page_Testcase_Data {
    my ($testcase, $data) = @_;

    my (@empty_list, $lang, $type, $list_addr, $subsection, $text);
    my (@href_list);

    #
    # Extract the language, subsection type and text from the data
    #
    ($lang, $subsection, $type, $text) = split(/\s+/, $data, 4);

    #
    # Is this the page header subsection ?
    #
    if ( defined($text) && ($subsection eq "HEADER") ) {
        #
        # Is this image alt text ?
        #
        if ( $type eq "IMAGE_ALT" ) {
            if ( ! defined($server_header_images{$lang}) ) {
                $server_header_images{$lang} = \@empty_list;
            }

            #
            # Save alt text details
            #
            $list_addr = $server_header_images{$lang};
            push(@$list_addr, $text);
        }
    }
    #
    # Is this the content links subsection ?
    #
    elsif ( defined($text) && ($subsection eq "CONTENT") ) {
        #
        # Is this a language link ?
        #
        if ( $type eq "LINK" ) {
            if ( ! defined($server_content_links{$lang}) ) {
                $server_content_links{$lang} = \@empty_list;
            }

            #
            # Save link text details
            #
            $list_addr = $server_content_links{$lang};
            push(@$list_addr, $text);
        }
        #
        # Is this an href value ?
        #
        elsif ( $type eq "HREF" ) {
            if ( ! defined($server_content_hrefs{$lang}) ) {
                $server_content_hrefs{$lang} = \@empty_list;
            }

            #
            # Split text into a list of possible href values
            #
            @href_list = split(/\s+/, $text);

            #
            # Save link text details
            #
            $list_addr = $server_content_hrefs{$lang};
            push(@$list_addr, \@href_list);
        }
    }
    #
    # Is this the server footer subsection ?
    #
    if ( defined($text) && ($subsection eq "TERMS_CONDITIONS_FOOTER") ) {
        #
        # Is this link text ?
        #
        if ( $type eq "LINK" ) {
            if ( ! defined($server_footer_links{$lang}) ) {
                $server_footer_links{$lang} = \@empty_list;
            }

            #
            # Save link text details
            #
            $list_addr = $server_footer_links{$lang};
            push(@$list_addr, $text);
        }
        #
        # Is this an href value ?
        #
        elsif ( $type eq "HREF" ) {
            if ( ! defined($server_footer_hrefs{$lang}) ) {
                $server_footer_hrefs{$lang} = \@empty_list;
            }

            #
            # Split text into a list of possible href values
            #
            @href_list = split(/\s+/, $text);

            #
            # Save link text details
            #
            $list_addr = $server_footer_hrefs{$lang};
            push(@$list_addr, \@href_list);
        }
    }
}

#***********************************************************************
#
# Name: Template_Testcase_Data
#
# Parameters: testcase - testcase identifier
#             data - string of data
#
# Description:
#
#   This function copies the passed template testcase data into
# global data structures.
#
#***********************************************************************
sub Template_Testcase_Data {
    my ($testcase, $data) = @_;

    my (@subsection_list, $type, $text);

    #
    # Extract the type and text from the data
    #
    ($type, $text) = split(/\s+/, $data, 2);
    print "Template data, type = $type, text = $text\n" if $debug;

    #
    # Is this a page type ?
    #
    if ( defined($text) && (($type eq "CONTENT_PAGE") ||
                            ($type eq "SPLASH_PAGE") ||
                            ($type eq "SERVER_PAGE")) ) {
        #
        # Get the subsection list
        #
        @subsection_list = split(/\s+/, $text);
        if ( @subsection_list > 0 ) {
            $required_template_sections{$type} = \@subsection_list;
        }
    }
    #
    # Is this a skip links href value ?
    #
    elsif ( defined($text) && ($type eq "SKIP_LINKS") ) {
        #
        # Save link text details
        #
        push(@skip_links_hrefs, $text);
        print "Add $text to skip link href values\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Set_SWU_Check_Testcase_Data
#
# Parameters: testcase - testcase identifier
#             data - string of data
#
# Description:
#
#   This function copies the passed data into a hash table
# for the specified testcase identifier.
#
#***********************************************************************
sub Set_SWU_Check_Testcase_Data {
    my ($testcase, $data) = @_;

    my ($page_type, @subsection_list);

    #
    # Copy the data into the table
    #
    $testcase_data{$testcase} = $data;

    #
    # Break out specific testcase data
    #
    if ( $testcase eq "SWU_TEMPLATE" ) {
        #
        # Save template testcase data
        #
        Template_Testcase_Data($testcase, $data);
    }
    #
    # Content Page Header
    #
    elsif ( ($testcase eq "SWU_E2.2.2") ||
            ($testcase eq "SWU_E2.2.3") ||
            ($testcase eq "SWU_E2.2.4") ||
            ($testcase eq "SWU_E2.2.5") ) {
        #
        # Save Header section testcase data
        #
        Header_Section_Testcase_Data($testcase, $data);
    }
    #
    # Content page content section
    #
    elsif ( $testcase eq "SWU_E2.2.6" ) {
        #
        # Save Content section testcase data
        #
        Content_Section_Testcase_Data($testcase, $data);
    }
    #
    # Content Page Footer
    #
    elsif ( $testcase eq "SWU_E2.2.7" ) {
        #
        # Save Footer section testcase data
        #
        Footer_Section_Testcase_Data($testcase, $data);
    }
    #
    # Splash Page
    #
    elsif ( $testcase eq "SWU_E2.4" ) {
        #
        # Save splash page testcase data
        #
        Splash_Page_Testcase_Data($testcase, $data);
    }
    #
    # Server Message Page
    #
    elsif ( $testcase eq "SWU_E2.5" ) {
        #
        # Save server message page testcase data
        #
        Server_Page_Testcase_Data($testcase, $data);
    }
}

#***********************************************************************
#
# Name: Set_SWU_Check_Test_Profile
#
# Parameters: profile - TQA check test profile
#             clf_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by testcase name.
#
#***********************************************************************
sub Set_SWU_Check_Test_Profile {
    my ($profile, $clf_checks ) = @_;

    my (%local_clf_checks);
    my ($key, $value);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_SWU_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_clf_checks = %$clf_checks;
    $clf_check_profile_map{$profile} = \%local_clf_checks;
}

#**********************************************************************
#
# Name: Testcase_Description
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
sub Testcase_Description {
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
# Name: Initialize_Test_Results
#
# Parameters: profile - TQA check test profile
#             local_results_list_addr - address of results list.
#
# Description:
#
#   This function initializes the test case results table.
#
#***********************************************************************
sub Initialize_Test_Results {
    my ($profile, $local_results_list_addr) = @_;

    #
    # Set current hash tables
    #
    $current_clf_check_profile = $clf_check_profile_map{$profile};
    $results_list_addr = $local_results_list_addr;
    
    #
    # Initialize flags and counters
    #
    $favicon_count = 0;
    $in_head_section = 0;
    %content_subsection_found = ();
    $found_date_modified_label = "";
    $found_date_modified_value = 0;
    $have_text_handler = 0;
    @text_handler_tag_list = ();
    $current_text_handler_tag = "";
    $found_form = 0;
    $found_search_button = 0;
    $inside_li = 0;
    undef $date_modified_metadata_value;
}

#***********************************************************************
#
# Name: Print_Error
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             error_string - error string
#
# Description:
#
#   This function prints error messages if debugging is enabled..
#
#***********************************************************************
sub Print_Error {
    my ( $line, $column, $text, $error_string ) = @_;

    #
    # Print error message if we are in debug mode
    #
    if ( $debug ) {
        print "$error_string\n";
    }
}

#***********************************************************************
#
# Name: Record_Result
#
# Parameters: testcase - testcase identifier
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
    my ( $testcase, $line, $column, $text, $error_string ) = @_;

    my ($result_object);

    #
    # Is this testcase included in the profile
    #
    if ( defined($testcase) && defined($$current_clf_check_profile{$testcase}) ) {
        #
        # Create result object and save details
        #
        $result_object = tqa_result_object->new($testcase, $clf_check_fail,
                                                Testcase_Description($testcase),
                                                $line, $column, $text,
                                                $error_string, $current_url);
        push (@$results_list_addr, $result_object);

        #
        # Print error string to stdout
        #
        Print_Error($line, $column, $text, "$testcase : $error_string");
    }
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
# Name: Dt_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the dt tag.
#
#***********************************************************************
sub Dt_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Are we in the Date Modified subsection ?
    #
    if ( $content_section_handler->current_content_subsection() eq "DATE_MODIFIED" ) {
        #
        # We expect to find a date modified or version label, start
        # text handler.
        #
        print "Found <dt> inside Date Modified subsection, starting text handler\n" if $debug;
        Start_Text_Handler($self, "dt");
    }
}

#***********************************************************************
#
# Name: End_Dt_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end dt tag.
#
#***********************************************************************
sub End_Dt_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($clean_text, $list_addr, $found_label, $label, $message);
    my ($found_this_label);

    #
    # Get all the text found within the dt tag
    #
    if ( ! $have_text_handler ) {
        print "End dt tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Are we in the Date Modified subsection ?
    #
    if ( $content_section_handler->current_content_subsection() eq "DATE_MODIFIED" ) {
        #
        # Get the dt text as a string, remove excess white space
        #
        $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
        print "End_Dt_Tag_Handler: text = \"$clean_text\"\n" if $debug;

        #
        # Do we have date modified labels for this language ?
        #
        if ( defined($date_modified_labels{$current_url_language}) ) {
            $list_addr = $date_modified_labels{$current_url_language};
            
            #
            # Check the <dt> text against each possible label
            #
            $found_label = 0;
            foreach $label (@$list_addr) {
                if ( lc($clean_text) eq lc($label) ) {
                    print "Found Date Modified label $label\n" if $debug;
                    $found_label = 1;
                    $found_this_label = $label;
                    last;
                }
            }
            
            #
            # Did we find a label when we already have one (i.e. multiple
            # date modified fields) ?
            #
            if ( $found_label && ($found_date_modified_label ne "") ) {
                print "Found multiple date modified labels\n" if $debug;
                Record_Result("SWU_E2.2.6", $line, $column, $text,
                              String_Value("Multiple Date Modified found"));
            }
            #
            # Did we find a date modified label ?
            #
            elsif ( $found_label ) {
                $found_date_modified_label = $found_this_label;
            }
            #
            # Did not find date modified label
            #
            else {
                print "Did not find modified label\n" if $debug;
                $message = " ";
                foreach $label (@$list_addr) {
                    $message .= "\"$label\" ";
                }
                Record_Result("SWU_E2.2.6", $line, $column, $text,
                              String_Value("Date Modified not found") .
                              String_Value("Expecting one of") . $message);
            }
        }

        #
        # Destroy the text handler that was used to save the text
        # portion of the dt tag.
        #
        Destroy_Text_Handler($self, "dt");
    }
}

#***********************************************************************
#
# Name: Dd_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the dd tag.
#
#***********************************************************************
sub Dd_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Are we in the Date Modified subsection ?
    #
    if ( $content_section_handler->current_content_subsection() eq "DATE_MODIFIED" ) {
        #
        # We expect to find a date modified or version value, start
        # text handler.
        #
        print "Found <dd> inside Date Modified subsection, starting text handler\n" if $debug;
        Start_Text_Handler($self, "dd");
    }
}

#***********************************************************************
#
# Name: Check_YYYY_MM_DD_Format
#
# Parameters: content - content to check
#
# Description:
#
#   This function checks the validity of a date value.  It checks specifically
# for a YYYY-MM-DD format.
#
# Returns:
#    status - status value
#    message - error message (if applicable)
#
#***********************************************************************
sub Check_YYYY_MM_DD_Format {
    my ($content) = @_;

    my ($status, @fields, $message);

    #
    # Check for valid date format, ie dddd-dd-dd
    #
    if ( $content =~ /^\d\d\d\d-\d\d-\d\d$/ ) {
        #
        # We have the right pattern of digits and dashes, now do a
        # check on the values.
        #
        @fields = split(/-/, $content);

        #
        # Check that the year portion is in a reasonable range.
        # 1900 to 2100.  I am making the assumption that this
        # code wont still be running in 2200 and that we
        # aren't still writing HTML documents.
        #
        if ( ( $fields[0] < 1900 ) || ( $fields[0] > 2100 ) ) {
            $status = 1;
            $message = String_Value("Invalid date modified value") .
                       String_Value("Year") . $fields[0] .
                       String_Value("out of range 1900-2100");
            print "$message\n" if $debug;
        }

        #
        # Check that the month is in the 01 to 12 range
        #
        elsif ( ( $fields[1] < 1 ) || ( $fields[1] > 12 ) ) {
            $status = 1;
            $message = String_Value("Invalid date modified value") .
                       String_Value("Month") . $fields[1] .
                       String_Value("out of range 1-12");
            print "$message\n" if $debug;

        }

        #
        # Check that the date is in the 01 to 31 range.  We won't
        # bother checking the month to further limit the date.
        #
        elsif ( ( $fields[2] < 1 ) || ( $fields[2] > 31 ) ) {
            $status = 1;
            $message = String_Value("Invalid date modified value") .
                       String_Value("Date") . $fields[0] .
                       String_Value("out of range 1-31");
            print "$message\n" if $debug;
        }

        #
        # Must have a well formed date.
        #
        else {
            $status = 0;
            $message= "";
        }
    }
    else {
        #
        # Invalid format
        #
        $status = 1;
        $message = String_Value("Invalid date modified value") .
                   "\"" . $content . "\"" .
                   String_Value("not in YYYY-MM-DD format");
        print "$message\n" if $debug;
    }

    #
    # Return status and message
    #
    return($status, $message);
}

#***********************************************************************
#
# Name: End_Dd_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the end dd tag.
#
#***********************************************************************
sub End_Dd_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($clean_text, $format, $found_label, $label, $yyyy, $mm, $dd);
    my ($status, $message);

    #
    # Get all the text found within the dt tag
    #
    if ( ! $have_text_handler ) {
        print "End dd tag found without corresponding open tag at line $line, column $column\n" if $debug;
        return;
    }

    #
    # Are we in the Date Modified subsection ?
    #
    if ( $content_section_handler->current_content_subsection() eq "DATE_MODIFIED" ) {
        #
        # Get the dt text as a string, remove excess white space
        #
        $clean_text = Clean_Text(Get_Text_Handler_Content($self, ""));
        print "End_Dd_Tag_Handler: text = \"$clean_text\"\n" if $debug;

        #
        # Did we find a label when we already have one (i.e. multiple
        # date modified fields) ?
        #
        if ( $found_date_modified_value ) {
            print "Found multiple date modified values\n" if $debug;
            Record_Result("SWU_E2.2.6", $line, $column, $text,
                          String_Value("Multiple Date Modified found"));
        }
        #
        # Did we find a date modified value ?
        #
        if ( $clean_text eq "" ) {
            print "Did not find modified value\n" if $debug;
            Record_Result("SWU_E2.2.6", $line, $column, $text,
                          String_Value("Missing content for date modified"));
        }
        else {
            #
            # Have a value, check possible format
            #
            print "Date modified value = $clean_text\n" if $debug;
            $found_date_modified_value = 1;

            #
            # Do we have date modified format for the date modified label ?
            #
            if ( ($found_date_modified_label ne "") &&
                  defined($date_modified_format{$found_date_modified_label}) ) {
                $format = $date_modified_format{$found_date_modified_label};

                #
                # Check format of date modified value
                #
                if ( $format =~ /^YYYY-MM-DD/i ) {
                    #
                    # Year, month, day format expected
                    #
                    ($status, $message) = Check_YYYY_MM_DD_Format($clean_text);
                    if ( $status == 1 ) {
                        Record_Result("SWU_E2.2.6", $line, $column, $text,
                                      $message);
                    }
                    else {
                        #
                        # Did we find a metadata value for the date modified ?
                        #
                        if ( defined($date_modified_metadata_value) ) {
                            #
                            # Do the values match ?
                            #
                            if ( $clean_text ne $date_modified_metadata_value ) {
                                #
                                # Mismatch in date modifiec values.
                                #
                                $message = String_Value("Date modified metadata tag") .
                                           " \"$date_modified_metadata_tag\" " .
                                           String_Value("value") .
                                           " \"$date_modified_metadata_value\" " .
                                           String_Value("does not match") .
                                           " \"$clean_text\"";
                                Record_Result("SWU_E2.2.6", $line, $column,
                                              $text, $message);
                            }
                        }
                    }
                }
                else {
                    #
                    # Assume free format text value
                    #
                    print "Free text format for date modified value\n" if $debug;
                }
            }
        }

        #
        # Destroy the text handler that was used to save the text
        # portion of the dd tag.
        #
        Destroy_Text_Handler($self, "dd");
    }
}

#***********************************************************************
#
# Name: Link_Tag_Handler
#
# Parameters: line - line number
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
    my ( $line, $column, $text, %attr ) = @_;

    my ($href, $resp_url, $header);

    #
    # Are we
    #  1) in the head section
    #  2) have an href
    #  3) have a rel attribute with the value "shortcut icon"
    #
    if ( $in_head_section && defined($attr{"href"}) && defined($attr{"rel"}) ) {
        if ( $attr{"rel"} =~ /^shortcut icon$/i ) {
            #
            # We have a favicon, make sure we don't have more than one
            #
            $favicon_count++;
            print "Found favicon at $line:$column\n" if $debug;
            if ( $favicon_count > 1 ) {
                print "Multiple favicons on web page\n" if $debug;
                Record_Result("SWU_E2.1", $line, $column, $text,
                              String_Value("Multiple favicons on web page"));
            }

            #
            # Get href value and check that it contains a URL
            #
            $href = $attr{"href"};
            if ( $href =~ /^\s*$/ ) {
                Record_Result("SWU_E2.1", $line, $column, $text,
                              String_Value("Missing URL in href for favicon"));
            }
            #
            # Convert possible relative url into an absolute one based
            # on the URL of the current document.  If we don't have
            # a current URL, then SWU_Check was called with just a block
            # of HTML text rather than the result of a GET.
            #
            elsif ( $current_url ne "" ) {
                $href = url($href)->abs($current_url);
                print "favicon url = $href\n" if $debug;

                #
                # Get the favicon if it is different from the last one we saw.
                #
                if ( $href ne $favicon_url ) {
                    print "Get favicon URL $href\n" if $debug;
                    ($resp_url, $favicon_resp) = Crawler_Get_HTTP_Response($href,
                                                                   $current_url);
                }

                #
                # Is this a valid URL ?
                #
                if ( ! defined($favicon_resp) ) {
                    Record_Result("SWU_E2.1", $line, $column, $text,
                                  String_Value("Invalid URL in href for favicon"));
                }
                #
                # Is it a broken link ?
                #
                elsif ( ! $favicon_resp->is_success ) {
                    Record_Result("SWU_E2.1", $line, $column, $text,
                                  String_Value("Broken link in href for favicon"));
                }
                else {
                    #
                    # Is this a link to an image ?
                    #
                    $header = $favicon_resp->headers;
                    if ( !($header->content_type =~ /^image/i) ) {
                        Record_Result("SWU_E2.1", $line, $column, $text,
                                      String_Value("favicon is not an image"));
                    }
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Meta_Tag_Handler
#
# Parameters: line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles meta tags.
#
#***********************************************************************
sub Meta_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    #
    # Do we have a metadata tag for the date modified value,
    # do we have a name attribute in the meta tag and
    # does that name match the one we are looking for ?
    #
    if ( $date_modified_metadata_tag ne "" && defined($attr{"name"}) &&
          ($date_modified_metadata_tag eq $attr{"name"}) ) {
        print "Meta_Tag_Handler: Found metadata tag ". $attr{"name"} . "\n" if $debug;
        
        #
        # Check for a content attribute
        #
        if ( (! defined($attr{"content"})) || ($attr{"content"} eq "") ) {
                        Record_Result("SWU_E2.2.6", $line, $column, $text,
                                      String_Value("Missing content from metadata tag") .
                                      " $date_modified_metadata_tag");
        }
        else {
            #
            # Record content for a later check with the date modified
            # value in the content area.
            #
            $date_modified_metadata_value = $attr{"content"};
            print "Found date midified metadata content $date_modified_metadata_value\n" if $debug;
        }
    }
}

#***********************************************************************
#
# Name: Input_Tag_Handler
#
# Parameters: self - reference to object
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

    my ($input_type, $value, $input_tag_type, $expected_value);
    my ($list_addr, $found_a_matching_button, $expected_value_list);

    #
    # Are we in the Site Banner subsection and inside a form ?
    #
    if ( $found_form &&
         ($content_section_handler->current_content_subsection() eq "SITE_BANNER") ) {
        print "Found <input> inside Site Banner subsection\n" if $debug;
        
        #
        # Is this a read only or hidden input ?
        #
        if ( defined($attr{"readonly"}) ||
             (defined($attr{"type"}) && ($attr{"type"} eq "hidden") ) ) {
            print "Hidden or readonly input\n" if $debug;
            return;
        }

        #
        # Check the type attribute
        #
        if ( defined( $attr{"type"} ) ) {
            $input_type = lc($attr{"type"});
            print "Input type = $input_type\n" if $debug;
        }
        else {
            #
            # No type field, assume it defaults to type text
            #
            $input_type = "text";
            print "No input type specified, assuming text\n" if $debug;
        }
        
        #
        # If this is a text input (assume it is the search field) or
        # a search input (HTML 5 input type) ?
        #
        if ( ($input_type eq "text") || ($input_type eq "search") ) {
            #
            # If we don't already have a text field, set flag indicating
            # we found it.
            #
            if ( ! $found_search_field ) {
                $found_search_field = 1;

                #
                # Check for default field size.
                #
                if ( ! defined($attr{"size"}) ) {
                    Record_Result("SWU_E2.2.5", $line, $column, $text,
                                  String_Value("Missing size in search text input field"));
                }
                elsif ( $attr{"size"} != 27 ) {
                    Record_Result("SWU_E2.2.5", $line, $column, $text,
                                  String_Value("Incorrect size in search text input field"));
                } 
            }
            else {
                #
                # Multiple text input fields, only expecting 1.
                #
                print "Multiple text input fields in search form\n" if $debug;
                Record_Result("SWU_E2.2.5", $line, $column, $text,
                              String_Value("Multiple search input fields found"));
            }
        }
        #
        # Is this a submit type or image ?
        #
        elsif ( ($input_type eq "submit") || ($input_type eq "image") ) {
            #
            # Get the input value (button label) ?
            #
            if ( defined( $attr{"value"} ) ) {
                $value = encode_entities($attr{"value"});
            }
            else {
                $value = "";
            }

            #
            # Do we have an expected value for this language ?
            #
            if ( defined($search_button_values{$current_url_language}) ) {
                $list_addr = $search_button_values{$current_url_language};
                
                #
                # Check each possible expected button value
                #
                $found_a_matching_button = 0;
                $expected_value_list = "";
                foreach $expected_value (@$list_addr) {
                    #
                    # Does the value match the expected search button value ?
                    #
                    $expected_value_list .= "\"$expected_value\" ";
                    if ( lc($value) eq lc($expected_value) ) {
                        #
                        # If we don't already have a search button, set flag
                        # indicating we found it.
                        #
                        if ( ! $found_search_button ) {
                            print "Found search button $expected_value\n" if $debug;
                            $found_a_matching_button = 1;
                            last;
                        }
                    }
                }

                #
                # Did we found a matching button label ?
                #
                if ( $found_a_matching_button ) {
                    #
                    # Do we already have a button ?
                    #
                    if  ( $found_search_button ) {
                         #
                         # Multiple search buttons, only expecting 1.
                         #
                         print "Multiple search buttons in search form\n" if $debug;
                         Record_Result("SWU_E2.2.5", $line, $column, $text,
                               String_Value("Multiple search buttons found"));
                    }

                    #
                    # We have a search button
                    #
                    $found_search_button = 1;
                }
                else {
                    #
                    # Button does not have correct label
                    #
                    print "Incorrect search button in search form\n" if $debug;
                    Record_Result("SWU_E2.2.5", $line, $column, $text,
                          String_Value("Incorrect search button found") .
                          " $value " . String_Value("expecting") .
                          $expected_value_list);
                }
            }
            else {
                print "No expected search button label\n" if $debug;
                $found_search_button = 1;
            }
        }
        #
        # Additional input type that is not hidden.
        #
        else {
            print "Unexpected input field $input_type in search form\n" if $debug;
            Record_Result("SWU_E2.2.5", $line, $column, $text,
                        String_Value("Extra input field found in Search form") .
                        " \"$input_type\"");
        }
    }
}

#***********************************************************************
#
# Name: Start_Form_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the form tag.
#
#***********************************************************************
sub Start_Form_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Are we in the Site Banner subsection ?
    #
    if ( $content_section_handler->current_content_subsection() eq "SITE_BANNER" ) {
        #
        # This form should be the search form.
        #
        print "Found <form> inside Site Banner subsection\n" if $debug;
        $found_form = 1;
    }
}

#***********************************************************************
#
# Name: End_Form_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#
# Description:
#
#   This function handles the end form tag.
#
#***********************************************************************
sub End_Form_Tag_Handler {
    my ( $self, $line, $column, $text ) = @_;

    my ($tcid, @tcids);

    #
    # Are we in the Site Banner subsection ?
    #
    if ( $content_section_handler->current_content_subsection() eq "SITE_BANNER" ) {
        #
        # This form should be the end of the search form.
        #
        print "Found </form> inside Site Banner subsection\n" if $debug;

        #
        # Did we get a text field and search button ?
        #
        if ( ! $found_search_field ) {
            print "Missing search input field\n" if $debug;
            Record_Result("SWU_E2.2.5", $line, $column, $text,
                          String_Value("Missing search input field"));
        }
        elsif ( ! $found_search_button ) {
            print "Missing search button\n" if $debug;
            Record_Result("SWU_E2.2.5", $line, $column, $text,
                          String_Value("Missing search button"));
        }

        #
        # Clear form, input and button flags.
        #
        $found_form = 0;
        $found_search_button = 0;
        $found_search_field = 0;
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
    # Set flag to indicate we are inside an <li>
    #
    $inside_li = 1;
}

#***********************************************************************
#
# Name: End_Li_Tag_Handler
#
# Parameters: self - reference to this parser
#             line - line number
#             column - column number
#             text - text from tag
#             attr - hash table of attributes
#
# Description:
#
#   This function handles the end li tag.
#
#***********************************************************************
sub End_Li_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Clear flag to indicate we are no longer inside an <li>
    #
    $inside_li = 0;
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
#   This function handles the <a> tag.
#
#***********************************************************************
sub Anchor_Tag_Handler {
    my ( $self, $line, $column, $text, %attr ) = @_;

    #
    # Are we in the Breadcrumb subsection ?
    #
    if ( $content_section_handler->current_content_subsection() eq "BREADCRUMB" ) {
        #
        # We expect the breadcrumb links to be inside a list
        #
        if ( ! $inside_li ) {
            Record_Result("SWU_E2.2.5", $line, $column, $text,
                          String_Value("Breadcrumb link found outside li"));
        }
    }
}

#***********************************************************************
#
# Name: Start_Handler
#
# Parameters: self - reference to this parser
#             language - url language
#             tagname - name of tag
#             line - line number
#             column - column number
#             text - text from tag
#             skipped_text - text since the last tag
#             attrseq - reference to an array of attributes
#             attr - hash table of attributes
#
# Description:
#
#   This function is a callback handler for HTML parsing that
# handles the start of HTML tags.
#
#***********************************************************************
sub Start_Handler {
    my ( $self, $language, $tagname, $line, $column, $text, $skipped_text,
         $attrseq, @attr ) = @_;

    my (%attr_hash) = @attr;

    #
    # Check for start of content section
    #
    $content_section_handler->check_start_tag($tagname, $line, $column,
                                              %attr_hash);

    #
    # See which content subsection we are in
    #
    if ( $content_section_handler->current_content_subsection() ne "" ) {
        $content_subsection_found{$content_section_handler->current_content_subsection()} = 1;
    }

    #
    # Check anchor tag
    #
    $tagname =~ s/\///g;
    if ( $tagname eq "a" ) {
        Anchor_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check body tag
    #
    elsif ( $tagname eq "body" ) {
        print "Start of body, end of head section\n" if $debug;
        $in_head_section = 0;
    }
    #
    # Check dd tag
    #
    elsif ( $tagname eq "dd" ) {
        Dd_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check dt tag
    #
    elsif ( $tagname eq "dt" ) {
        Dt_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check form tag
    #
    elsif ( $tagname eq "form" ) {
        Start_Form_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }
    #
    # Check head tag
    #
    elsif ( $tagname eq "head" ) {
        print "Start of head section\n" if $debug;
        $in_head_section = 1;
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
        Link_Tag_Handler($line, $column, $text, %attr_hash );
    }
    #
    # Check for meta tag
    #
    elsif ( $tagname eq "meta" ) {
        Meta_Tag_Handler( $line, $column, $text, %attr_hash );
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
    # Check dd tag
    #
    if ( $tagname eq "dd" ) {
        End_Dd_Tag_Handler( $self, $line, $column, $text );
    }
    #
    # Check dt tag
    #
    elsif ( $tagname eq "dt" ) {
        End_Dt_Tag_Handler( $self, $line, $column, $text );
    }
    #
    # Check form tag
    #
    elsif ( $tagname eq "form" ) {
        End_Form_Tag_Handler( $self, $line, $column, $text );
    }
    #
    # Check head tag
    #
    elsif ( $tagname eq "head" ) {
        print "End of head section\n" if $debug;
        $in_head_section = 0;
    }
    #
    # Check li tag
    #
    elsif ( $tagname eq "li" ) {
        End_Li_Tag_Handler( $self, $line, $column, $text, %attr_hash );
    }

    #
    # Is this the end of a content area ?
    #
    $content_section_handler->check_end_tag($tagname, $line, $column);
}

#***********************************************************************
#
# Name: Check_Site_Title_Subsections
#
# Parameters: tcid - testcase id
#             subsection - subsection name
#             required - flag to indicate if subsection is required
#
# Description:
#
#   This function checks the to see if the named site title subsection
# exists in the subsection text data structure.  If is required and is
# either not present or empty, a failure is generated.  If it is not
# required, but present and empty, a failure is generated.
#
#***********************************************************************
sub Check_Site_Title_Subsections {
    my ($tcid, $subsection, $required) = @_;

    my ($text);
    
    #
    # Did we get content for the site title ?
    #
    print "Check_Site_Title_Subsections tcid = $tcid, subsection = $subsection, required = $required\n" if $debug;
    if ( defined($subsection_text{$subsection}) ) {
        $text = $subsection_text{$subsection};
        
        #
        # Do we have non-white space content ?
        #
        $text = Trim_Whitespace($text);
    }
    else {
        print "No $subsection subsection content\n" if $debug;
        
        #
        # Is this a required subsection ?
        #
        if ( $required ) {
            #
            # Set it to an empty string, it will generate a
            # failure on the subsequest check.
            #
            $text = "";
        }
        else {
            #
            # An optional subsection, no failure is generated
            #
            return();
        }
    }
    
    #
    # Did we get content for the site title ?
    #
    print "$subsection subsection content = $text\n" if $debug;
    if ( $text eq "" ) {
        Record_Result($tcid, -1, -1, "",
                      String_Value("Missing site title"));
    }
}

#***********************************************************************
#
# Name: Check_Splash_Page_Content
#
# Parameters: none
#
# Description:
#
#   This function checks content subsections of splash pages.
#
#***********************************************************************
sub Check_Splash_Page_Content {

    #
    # Check for left site title subsections
    #
    Check_Site_Title_Subsections("SWU_E2.4", "SITE_TITLE_LEFT", 1);

    #
    # Check for right site title subsections
    #
    Check_Site_Title_Subsections("SWU_E2.4", "SITE_TITLE_RIGHT", 1);
}

#***********************************************************************
#
# Name: Check_Server_Message_Page_Content
#
# Parameters: none
#
# Description:
#
#   This function checks content subsections of server message pages.
#
#***********************************************************************
sub Check_Server_Message_Page_Content {

    #
    # Check for left site title subsections
    #
    Check_Site_Title_Subsections("SWU_E2.5", "SITE_TITLE_LEFT", 1);

    #
    # Check for optional right site title subsections
    #
    Check_Site_Title_Subsections("SWU_E2.5", "SITE_TITLE_RIGHT", 0);
}

#***********************************************************************
#
# Name: Check_Document_Errors
#
# Parameters: none
#
# Description:
#
#   This function checks test cases that act on the document as a whole.
#
#***********************************************************************
sub Check_Document_Errors {

    my ($name, $page_type, $subsection_list_addr);
    my ($all_content_sections_found) = 1;
    my ($missing_content_sections) = "";

    #
    # Determine the testcase ID
    #
    print "SWU_Check: Check_Document_Errors\n" if $debug;

    #
    # Determine the page type
    #
    if ( defined($content_subsection_found{"SPLASH_LANG_LINKS"}) ) {
        $page_type = "SPLASH_PAGE";
        
        #
        # Check splash page content
        #
        Check_Splash_Page_Content();
    }
    elsif ( defined($content_subsection_found{"SERVER_DECORATION"}) ) {
        $page_type = "SERVER_PAGE";

        #
        # Check Server message page content
        #
        Check_Server_Message_Page_Content();
    }
    elsif ( defined($content_subsection_found{"PRIORITIES"}) ) {
        $page_type = "HOME_PAGE";
    }
    else {
        $page_type = "CONTENT_PAGE";
    }

    #
    # Do we have required template sections for this page type ?
    #
    if ( defined($required_template_sections{$page_type}) ) {
        $subsection_list_addr = $required_template_sections{$page_type};
    }

    #
    # Check for missing content subsections, we use this to determine if
    # the proper HTML template was used.
    #
    if ( defined($subsection_list_addr) ) {
        foreach $name (@$subsection_list_addr) {
            if ( ! defined($content_subsection_found{$name}) ) {
                $all_content_sections_found = 0;
                $missing_content_sections .= "$name ";
            }
        }
    }

    #
    # Did we find all the content sections ?
    #
    if ( ! $all_content_sections_found ) {
        Record_Result("SWU_TEMPLATE", -1, 0, "",
                      String_Value("Missing content section markers for") .
                      $missing_content_sections);
    }

    #
    # Did we find a favicon ?
    #
    if ( $favicon_count == 0 ) {
        Record_Result("SWU_E2.1", -1, 0, "", String_Value("Missing favicon"));
    }
    
    #
    # Did we find a date modified ?
    #
    if ( ($current_url_language ne "") && ($page_type eq "CONTENT_PAGE") ) {
        if ( $found_date_modified_label eq "" ) {
            print "Missing date modified label\n" if $debug;
            Record_Result("SWU_E2.2.6", -1, -1, "",
                          String_Value("Date Modified not found"));
        }
        else {
            #
            # Have date modified label, do we have a value ?
            #
            if ( ! $found_date_modified_value ) {
                print "Missing date modified value\n" if $debug;
                Record_Result("SWU_E2.2.6", -1, -1, "",
                              String_Value("Missing content for date modified"));
            }
        }
    }
    
    #
    # Did we find a date modified metadata tag ?
    #
    if ( ($date_modified_metadata_value ne "") && ( !defined($date_modified_metadata_value) ) ) {
        print "Missing date modified metadata\n" if $debug;
        Record_Result("SWU_E2.2.6", -1, -1, "",
                      String_Value("Date Modified metadata tag") .
                      " \"$date_modified_metadata_value\" " .
                      String_Value("not found"));
    }
}

#***********************************************************************
#
# Name: SWU_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             mime_type - mime type of content
#             resp - HTTP::Response object
#             content - content
#
# Description:
#
#   This function runs a number of technical QA checks the content.
#
#***********************************************************************
sub SWU_Check {
    my ( $this_url, $language, $profile, $mime_type, $resp, $content ) = @_;

    my (@tqa_results_list, $parser, $result_object, @other_tqa_results_list);
    my ($content_subsection, $tcid, $do_tests);

    #
    # Call the appropriate TQA check function based on the mime type
    #
    print "SWU_Check: URL $this_url, mime-type = $mime_type, lanugage = $language, profile = $profile\n" if $debug;

    #
    # Initialize the test case pass/fail table.
    #
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Are any of the testcases defined in this module
    # in the testcase profile ?
    #
    $do_tests = 0;
    foreach $tcid (keys(%testcase_description_en)) {
        if ( defined($$current_clf_check_profile{$tcid}) ) {
            $do_tests = 1;
            print "Testcase $tcid found in current testcase profile\n" if $debug;
            last;
        }
    }
    if ( ! $do_tests ) {
        #
        # No tests handled by this module
        #
        print "No tests handled by this module\n" if $debug;
        return(@tqa_results_list);
    }

    #
    # Save URL in global variable
    #
    if ( $this_url =~ /^http/i ) {
        $current_url = $this_url;
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of HTML
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }
    $current_url_language = $language;

    #
    # Did we get any content ?
    #
    if ( length($content) > 0 ) {
        #
        # Split the content into lines
        #
        @content_lines = split( /\n/, $content );

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
            "self,\"$language\",tagname,line,column,text,skipped_text,attrseq,\@attr"
        );
        $parser->handler(
            end => \&End_Handler,
            "self,tagname,line,column,text,\@attr"
        );

        #
        # Parse the content.
        #
        $parser->parse($content);
    }
    else {
        print "No content passed to SWU_Check\n" if $debug;
        return(@tqa_results_list);
    }

    #
    # Extract subsection text from HTML
    #
    $content_subsection = Content_Check_Extract_Content_From_HTML($content);
    %subsection_text = Content_Check_All_Extracted_Content();
    
    #
    # Check for errors that are detected one we analyse the entire document.
    #
    Check_Document_Errors();

    #
    # Return list of results
    #
    return(@tqa_results_list);
}

#***********************************************************************
#
# Name: Trim_Whitespace
#
# Parameters: string
#
# Description:
#
#   This function removes leading and trailing whitespace from a string.
# It also collapses multiple whitespace sequences into a single
# white space.
#
#***********************************************************************
sub Trim_Whitespace {
    my ($string) = @_;

    #
    # Remove leading & trailing whitespace
    #
    $string =~ s/\r*$/ /g;
    $string =~ s/\n*$/ /g;
    $string =~ s/\&nbsp;/ /g;
    $string =~ s/^\s*//g;
    $string =~ s/\s*$//g;

    #
    # Compress whitespace
    #
    $string =~ s/\s+/ /g;

    #
    # Return trimmed string.
    #
    return($string);
}

#***********************************************************************
#
# Name: Check_Link_Anchor_and_Href
#
# Parameters: link - a link object
#             link_no - link number (from a list of links)
#             expected_anchor - expected anchor text
#             expected_href - list of expected href values
#             tcid - testcase identifier
#             section - document section
#
# Description:
#
#   This function checks the anchor text and href values of a link
# against expected values. If the links do not match, a testcase
# failure is generated.
#
#***********************************************************************
sub Check_Link_Anchor_and_Href {
    my ($link, $link_no, $expected_anchor, $expected_href, $tcid,
        $section) = @_;

    my ($anchor_text, $href, $message, $href_value, $href_match);

    #
    # Trim anchor text and encode any entities
    #
    $anchor_text = Trim_Whitespace($link->anchor);
    $anchor_text = encode_entities($anchor_text);

    #
    # Does the anchor text match what is expected ?
    #
    print "Check link anchor text \"" . $anchor_text .
          "\" versus \"$expected_anchor\"\n" if $debug;
    if ( defined($expected_anchor) && (lc($anchor_text) ne lc($expected_anchor)) ) {
        $message = String_Value("Invalid anchor text") .
                    "'" . $link->anchor . "'" .
                    String_Value("in") . "$section " .
                    String_Value("link") . " # " . $link_no .
                    " " . String_Value("expecting") .
                    "'" . $expected_anchor . 
                    "'";
        Record_Result($tcid, $link->line_no, $link->column_no,
                      $link->source_line, $message);
    }

    #
    # Does the href text match what is expected ?
    #
    $href = $link->abs_url;
    $href_match = 0;
    foreach $href_value (@$expected_href) {
        print "Check link href \"" . $href .
              "\" versus \"$href_value\"\n" if $debug;
        if ( defined($href) && ($href eq $href_value) ) {
            $href_match = 1;
            print "Match href value\n" if $debug;
            last;
        }
    }

    #
    # Did we match href value
    #
    if ( ! $href_match ) {
        $message = String_Value("Invalid href") .
                    "'" . $href . "'" .
                    String_Value("in") . "$section " .
                    String_Value("link") . " # " . $link_no;

        #
        # Add expected HREF values to the message.
        #
        if ( @$expected_href == 1 ) {
            $message .= " " . String_Value("expecting") .
                        "'" . join(", ", @$expected_href) . "'";
        }
        else {
            $message .= " " . String_Value("expecting one of") .
                        "'" . join(", ", @$expected_href) . "'";
        }
        Record_Result($tcid, $link->line_no, $link->column_no,
                      $link->source_line, $message);
    }
}

#***********************************************************************
#
# Name: Check_Required_Link_Set
#
# Parameters: url - URL
#             link_list_addr - address of a list of link objects
#             link_set_list_addr - address of a set of
#               required links
#             tcid - testcase identifier
#             section - section string (e.g. GC Navigation)
#
# Description:
#
#    This function checks a set of links to see that all links are present
# in the actual link set.  The order of the links does not matter, only
# that they are present.
#
#***********************************************************************
sub Check_Required_Link_Set {
    my ($url, $link_list_addr, $link_set_list_addr, $tcid, $section) = @_;

    my ($link, $anchor_text, $expected_anchor, $found_match);

    #
    # Check for all required links
    #
    print "Check all required links in section $section\n" if $debug;
    foreach $expected_anchor (@$link_set_list_addr) {
        #
        # Check each link in the actual link set for a match on the anchor
        # text.
        #
        $found_match = 0;
        foreach $link (@$link_list_addr) {
            #
            # Trim anchor text and encode any entities
            #
            $anchor_text = Trim_Whitespace($link->anchor);
            $anchor_text = encode_entities($anchor_text);

            #
            # Does the anchor text match what is expected ?
            #
            print "Check link anchor text \"" . $anchor_text .
                  "\" versus \"$expected_anchor\"\n" if $debug;
            if ( lc($anchor_text) eq lc($expected_anchor) ) {
                #
                # Found a match on anchor text.
                #
                $found_match = 1;
                last;
            }
        }

        #
        # Did we not find the link ?
        #
        if ( ! $found_match ) {
            Record_Result($tcid, -1, -1, "",
                          String_Value("Missing required link") .
                          " \"$expected_anchor\" " .
                          String_Value("in") . "$section");
        }
    }
}

#***********************************************************************
#
# Name: Check_Expected_Links
#
# Parameters: url - URL
#             link_list_addr - address of a list of link objects
#             expected_link_list_addr - address of a list of
#               expected links
#             expected_href_list_addr - address of a list of
#               expected href values
#             optional_link_list_addr - address of a list of
#               optional links
#             optional_href_list_addr - address of a list of
#               optional href values
#             tcid - testcase identifier
#             optional_tcid - testcase identifier for optional link violations
#             section - section string (e.g. GC Navigation)
#
# Description:
#
#    This function checks a set of links to see that it matches a set of
# expected links.  It checks both the link text as well as the link href
# value. If there are any optional links provided, they are checked also.
#
#***********************************************************************
sub Check_Expected_Links {
    my ($url, $link_list_addr, $expected_link_list_addr,
        $expected_href_list_addr, $optional_link_list_addr, 
        $optional_href_list_addr, $tcid, $optional_tcid, $section) = @_;

    my ($link, $link_count, $link_no, @links, $expected_link_count);
    my ($link_text, $message, $optional_link_count, $optional_link_no);
    my ($anchor, $href, $href_list);

    #
    # Check that a set of links appear with the correct
    # anchor text and in the correct order.
    #
    print "Check_Expected_Links tcid = $tcid\n" if $debug;
    if ( defined($$current_clf_check_profile{$tcid}) ) {
        #
        # Go through the link list and only include links that are
        # in anchor tags (e.g. remove image links).
        #
        foreach $link (@$link_list_addr) {
            if ( $link->link_type eq "a" ) {
                push(@links, $link);
            }
        } 

        #
        # Get number of links in actual list as well as the expected
        # link list
        #
        $link_count = @links;
        $expected_link_count = @$expected_link_list_addr;
        print "Expecting $expected_link_count links\n" if $debug;

        #
        # Did we find at least the expected number links ?
        # (there may be optional links e.g. the language link)
        #
        print "Have $link_count, expecting $expected_link_count links\n" if $debug;
        if ( $link_count < $expected_link_count ) {
            Record_Result($tcid, -1, -1, "",
                          String_Value("Missing links in") . " $section. " .
                          String_Value("Found") . " $link_count " .
                          String_Value("links") . " " . 
                          String_Value("expecting") . $expected_link_count);
        }
        else {

            #
            # Check values of the anchor text for each expected item.
            #
            for ($link_no = 0; $link_no < $expected_link_count; $link_no++) {
                #
                # Get anchor and href values
                #
                $link = $links[$link_no];
                $anchor = $$expected_link_list_addr[$link_no];
                if ( defined($expected_href_list_addr) &&
                     defined($$expected_href_list_addr[$link_no]) )  {
                    $href_list = $$expected_href_list_addr[$link_no];
                }
                else {
                    #
                    # No expected href value, use actual value from the link.
                    #
                    my (@new_list);
                    push(@new_list, $link->abs_url);
                    $href_list = \@new_list;
                }

                #
                # Check anchor and href values
                #
                Check_Link_Anchor_and_Href($link, ($link_no + 1), $anchor,
                                           $href_list, $tcid, $section);
            }

            #
            # Do we have any optional links ?
            #
            if ( defined($optional_link_list_addr) ) {
                $optional_link_count = @$optional_link_list_addr;
            }
            else {
                $optional_link_count = 0;
                print "No optional link list address defined\n" if $debug;
            }
            if ( $optional_link_count > 0 ) {
                print "Have $optional_link_count optional links\n" if $debug;

                #
                # Do we have enough actual links for the optional links ?
                #
                if ( $link_count > $expected_link_count ) {
                    print "Have more than $expected_link_count links, checking optional links\n" if $debug;

                    #
                    # Check values of the anchor text for each optional item.
                    #
                    $optional_link_no = 0;
                    for ($link_no = $expected_link_count; $link_no < $link_count; $link_no++) {
                        #
                        # Get anchor and href values
                        #
                        $link = $links[$link_no];
                        $anchor = $$optional_link_list_addr[$optional_link_no];
                        if ( defined($optional_href_list_addr) &&
                             defined($$optional_href_list_addr[$optional_link_no]) )  {
                            $href_list = $$optional_href_list_addr[$optional_link_no];
                        }
                        else {
                            #
                            # No expected href value, use actual value
                            # from the link.
                            #
                            my (@new_list);
                            push(@new_list, $link->abs_url);
                            $href_list = \@new_list;
                        }

                        #
                        # Check anchor and href values
                        #
                        Check_Link_Anchor_and_Href($link, ($link_no + 1), 
                                                   $anchor, $href_list,
                                                   $optional_tcid, $section);

                        #
                        # Have we reached the end of the optional link list ?
                        #
                        $optional_link_no++;
                        if ( $optional_link_no >= $optional_link_count ) {
                            last;
                        }
                    }
                }
            }
            else {
                print "No optional link provided\n" if $debug;
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Expected_Link_Count
#
# Parameters: url - URL
#             link_list_addr - address of a list of link objects
#             expected_link_list_addr - address of a list of
#               expected links
#             expected_href_list_addr - address of a list of
#               expected href values
#             optional_link_list_addr - address of a list of
#               optional links
#             optional_href_list_addr - address of a list of
#               optional href values
#             tcid - testcase identifier
#             optional_tcid - testcase identifier for optional link violations
#             section - section string (e.g. GC Navigation)
#
# Description:
#
#    This function checks if the number of links in a link set exceeds the
# number of expected plus optional links.
#
#***********************************************************************
sub Check_Expected_Link_Count {
    my ($url, $link_list_addr, $expected_link_list_addr,
        $expected_href_list_addr, $optional_link_list_addr,
        $optional_href_list_addr, $tcid, $optional_tcid, $section) = @_;

    my ($link, $link_count, $expected_link_count, $optional_link_count);

    #
    # Check that a set of links appear with the correct
    # anchor text and in the correct order.
    #
    print "Check_Expected_Link_Count tcid = $tcid\n" if $debug;
    if ( defined($$current_clf_check_profile{$tcid}) ) {
        #
        # Go through the link list and only include links that are
        # in anchor tags (e.g. remove image links) to get the number
        # of links in the content subsection.
        #
        $link_count = 0;
        foreach $link (@$link_list_addr) {
            if ( $link->link_type eq "a" ) {
                $link_count++;
            }
        }
        print "Actual link count = $link_count\n" if $debug;

        #
        # Get number of links in the expected link list
        #
        $expected_link_count = @$expected_link_list_addr;

        #
        # Do we have any optional links ?
        #
        if ( defined($optional_link_list_addr) ) {
            $optional_link_count = @$optional_link_list_addr;
        }
        else {
            $optional_link_count = 0;
            print "No optional link list address defined\n" if $debug;
        }
        print "Expected link count = $expected_link_count, optional link count = $optional_link_count\n" if $debug;
        
        #
        # Does the actual link count exceed the expected plus optional
        # links ?
        #
        if ( $link_count > ($expected_link_count + $optional_link_count) ) {
            Record_Result($tcid, -1, -1, "",
                          String_Value("Extra links in") . " $section. " .
                          String_Value("Found") . " $link_count " .
                          String_Value("expecting") . 
                          ($expected_link_count + $optional_link_count));
        }
    }
}

#***********************************************************************
#
# Name: Check_Expected_Images
#
# Parameters: url - URL
#             link_list_addr - address of a list of link objects
#             expected_link_list_addr - address list of a list of
#               expected links
#             tcid - testcase identifier
#             section - section string (e.g. GC Navigation)
#
# Description:
#
#    This function checks a set of links to see image alt text matches
# the list of expected image alt text.
#
#***********************************************************************
sub Check_Expected_Images {
    my ($url, $link_list_addr, $expected_link_list_addr, $tcid, $section) = @_;

    my ($link, $link_count, $link_no, @links, $expected_link_count);
    my ($alt_text, $message);

    #
    # Check that a set of image links appear with the correct
    # alt text and in the correct order.
    #
    print "Check_Expected_Images tcid = $tcid\n" if $debug;
    if ( defined($$current_clf_check_profile{$tcid}) ) {
        #
        # Go through the link list and only include links that are
        # in img tags (e.g. remove anchor links).
        #
        foreach $link (@$link_list_addr) {
            if ( $link->link_type eq "img" ) {
                push(@links, $link);
            }
        } 

        #
        # Get number of links in actual list as well as the expected
        # link list
        #
        $link_count = @links;
        $expected_link_count = @$expected_link_list_addr;
        print "Expecting $expected_link_count links " .
              join(", ", @$expected_link_list_addr) . "\n" if $debug;

        #
        # Did we find at least the expected number links ?
        # (there may be optional links e.g. the language link)
        #
        print "Have $link_count, expecting $expected_link_count links\n" if $debug;
        if ( $link_count < $expected_link_count ) {
            Record_Result($tcid, -1, -1, "",
                          String_Value("Missing images in") . " $section. " .
                          String_Value("Found") . " $link_count " .
                          String_Value("images"));
        }
        else {

            #
            # Check values of the alt text for each item.
            #
            for ($link_no = 0; $link_no < $expected_link_count; $link_no++) {
                $link = $links[$link_no];
                print "Check image # $link_no, have " . $link->alt .
                      " expecting " . $$expected_link_list_addr[$link_no] . "\n" if $debug;

                #
                # Does the alt text match what is expected ?
                #
                $alt_text = Trim_Whitespace($link->alt);
                $alt_text = encode_entities($alt_text);
                if ( lc($alt_text) ne
                     lc($$expected_link_list_addr[$link_no]) ) {
                    $message = String_Value("Invalid alt text") .
                                " '" . $link->alt . "'" .
                                String_Value("in") . " $section " .
                                String_Value("image") . " # " . ($link_no + 1) .
                                " " . String_Value("expecting") .
                                "'" . $$expected_link_list_addr[$link_no] . 
                                "'";
                    Record_Result($tcid, $link->line_no, $link->column_no,
                                  $link->source_line, $message);
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_For_Image_Links
#
# Parameters: url - URL
#             link_list_addr - address of a list of link objects
#             tcid - testcase identifier
#             section - section string (e.g. GC Navigation)
#
# Description:
#
#    This function checks a set of links to if there are any links
# containing images.  Some sections of the web page msy contain text
# only links, if a link is found to contain an image a failure is recorded.
#
#***********************************************************************
sub Check_For_Image_Links {
    my ($url, $link_list_addr, $tcid, $section) = @_;

    my ($link);

    #
    # Check the set of links to see if they contain an image.
    #
    print "Check_For_Image_Links tcid = $tcid\n" if $debug;
    if ( defined($$current_clf_check_profile{$tcid}) ) {
        #
        # Go through the link list and only check links that are
        # in anchor tags.
        #
        foreach $link (@$link_list_addr) {
            if ( $link->link_type eq "a" ) {
                #
                # Have an anchor link, does it contain an image ?
                #
                if ( $link->has_img ) {
                    #
                    # Link contains an image when it is not expected to
                    # contain one.
                    #
                    Record_Result($tcid, $link->line_no, $link->column_no,
                                  $link->source_line,
                                  String_Value("Image link found in") .
                                  " $section");
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Compare_Link_Lists
#
# Parameters: url - URL
#             actual_links - address of a list of link objects
#             expected_links - address of a list of link objects
#             tcid - testcase identifier
#             section - section string (e.g. GC Navigation)
#
# Description:
#
#    This function compares 2 lists of links to see they are the same.
# It goes through the expected link set, looking for anchor links
# (skipping image links) and compares the anchor text and href values
# with those of the actual link list.  If an entry does not match a
# failure is recorded.  If there are more or fewer links a failure is
# recorded.  This function stops after the first failure is encountered.
#
#***********************************************************************
sub Compare_Link_Lists {
    my ($url, $actual_links, $expected_links, $tcid, $section) = @_;
    
    my ($link, $link1, $actual_count, $expected_count, $expected_index);
    my ($actual_text, $expected_text, $message);
    
    #
    # Get the number of expected links
    #
    $expected_count = @$expected_links;
    print "Compare_Link_Lists, expect link count = $expected_count\n" if $debug;
    
    #
    # Go through the actual link list and check each anchor link
    #
    $expected_index = 0;
    $actual_count = 0;
    foreach $link (@$actual_links) {
        #
        # Is this is an anchor?
        #
        if ( $link->link_type eq "a" ) {
            $actual_count++;
            
            #
            # Have we exceeded the expected link count ?
            #
            if ( $actual_count > $expected_count ) {
                Record_Result($tcid, $link->line_no, $link->column_no,
                              $link->source_line,
                              String_Value("Extra links in") . " $section. " .
                              String_Value("Found") . " $actual_count " .
                              String_Value("expecting") . $expected_count);
                return;
            }
            
            #
            # Do the link text values match ?
            #
            $actual_text = Trim_Whitespace($link->anchor);
            $actual_text = encode_entities($actual_text);
            $link1 = $$expected_links[$expected_index];
            $expected_text = Trim_Whitespace($link1->anchor);
            $expected_text = encode_entities($expected_text);
            print "Check link anchor text \"" . $actual_text .
                  "\" versus \"$expected_text\"\n" if $debug;
            if ( lc($actual_text) ne lc($expected_text) ) {
                #
                # Link text differs
                #
                $message = String_Value("Invalid anchor text") .
                           "'" . $link->anchor . "'" .
                           String_Value("in") . "$section " .
                           String_Value("link") . " # " . ($expected_index + 1) .
                           " " . String_Value("expecting") .
                           "'" . $link1->anchor . "'";
                Record_Result($tcid, $link->line_no, $link->column_no,
                              $link->source_line, $message);
                return;
            }
            
            #
            # Do the href values match ?
            #
            $actual_text = $link->abs_url;
            $expected_text = $link1->abs_url;
            print "Check link href \"" . $actual_text .
                  "\" versus \"$expected_text\"\n" if $debug;
            if ( $actual_text ne $expected_text ) {
                #
                # Link href differs
                #
                $message = String_Value("Invalid href") .
                            "'" . $actual_text . "'" .
                            String_Value("in") . "$section " .
                            String_Value("link") . " # " . ($expected_index + 1) .
                            " " . String_Value("expecting") .
                            "'" . $expected_text . "'";
                Record_Result($tcid, $link->line_no, $link->column_no,
                              $link->source_line, $message);
                return;
            }

            #
            # Found an expected link, increment expect link index to the
            # next one.
            #
            $expected_index++;
        }
    }
    
    #
    # Did we find all the expected links ?
    #
    if ( $actual_count < $expected_count ) {
        Record_Result($tcid, -1, -1, "",
                      String_Value("Missing links in") . " $section. " .
                      String_Value("Found") . " $actual_count " .
                      String_Value("links") . " " . String_Value("expecting") .
                      $expected_count);
    }
}

#***********************************************************************
#
# Name: Check_GC_Navigation_Links
#
# Parameters: url - URL
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function performs a number of checks on the GC
# Navigation section links.  It checks to see if expected links
# are present.
#***********************************************************************
sub Check_GC_Navigation_Links {
    my ($url, $language, $link_sets) = @_;

    my ($list_addr, $expected_link_list_addr, @empty_list);
    my ($expected_href_list_addr, $optional_link_list_addr);
    my ($optional_href_list_addr);

    #
    # Do we have GC Navigation links ?
    #
    print "Check GC Navigation links\n" if $debug;
    if ( defined($$link_sets{"GC_NAV"}) ) {
        $list_addr = $$link_sets{"GC_NAV"};
    }
    else {
        print "No GC_NAV section links\n" if $debug;
        $list_addr = \@empty_list;
    }

    #
    # Get list of expected links
    #
    if ( defined($gc_nav_links{$language}) ) {
        $expected_link_list_addr = $gc_nav_links{$language};
    }

    #
    # Get list of expected link href values
    #
    if ( defined($gc_nav_link_hrefs{$language}) ) {
        $expected_href_list_addr = $gc_nav_link_hrefs{$language};
    }

    #
    # Get list of optional links (i.e. language link)
    #
    if ( defined($gc_nav_optional_links{$language}) ) {
        $optional_link_list_addr = $gc_nav_optional_links{$language};
    }

    #
    # Get list of optional link href values (i.e. language link)
    #
    if ( defined($gc_nav_optional_link_hrefs{$language}) ) {
        $optional_href_list_addr = $gc_nav_optional_link_hrefs{$language};
    }

    #
    # Check GC Navigation links if we have a set of expected links
    #
    if ( defined($gc_nav_links{$language}) ) {
        #
        # Check for expected and optional links
        #
        Check_Expected_Links($url, $list_addr, $expected_link_list_addr,
                             $expected_href_list_addr, $optional_link_list_addr,
                             $optional_href_list_addr, "SWU_E2.2.5", "SWU_E2.2.4",
                             String_Value("GC navigation bar"));
                             
        #
        # Check the number of links
        #
        Check_Expected_Link_Count($url, $list_addr, $expected_link_list_addr,
                             $expected_href_list_addr, $optional_link_list_addr,
                             $optional_href_list_addr, "SWU_E2.2.5", "SWU_E2.2.4",
                             String_Value("GC navigation bar"));
    }

    #
    # Check GC Navigation images if we have a set of expected images
    #
    if ( defined($gc_nav_images{$language}) ) {
        $expected_link_list_addr = $gc_nav_images{$language};
        Check_Expected_Images($url, $list_addr, $expected_link_list_addr,
                              "SWU_E2.2.2", String_Value("GC navigation bar"));
    }
    else {
        print "No expected GC_NAV section images\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Check_Site_Banner_Links
#
# Parameters: url - URL
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function performs a number of checks on the site banner
# section links.  It checks to see if expected links
# are present.
#***********************************************************************
sub Check_Site_Banner_Links {
    my ($url, $language, $link_sets) = @_;

    my ($list_addr, $expected_link_list_addr, @empty_list);
    my ($site_title_link, $link, $link_count);

    #
    # Check Site Banner links
    #
    print "Check site banner links\n" if $debug;
    if ( defined($$link_sets{"SITE_BANNER"}) ) {
        $list_addr = $$link_sets{"SITE_BANNER"};

        #
        # Go through the site banner link list to find the first anchor
        # link (i.e. skip over images). This is the Site Title link
        # which should be a link to the home page.
        #
        $link_count = 0;
        foreach $link (@$list_addr) {
            if ( $link->link_type eq "a" ) {
                if ( ! defined($site_title_link) ) {
                    $site_title_link = $link;
                }
                $link_count++;
            }
        }
        
        #
        # Does the actual link count exceed the expected one site title
        # link ?
        #
        if ( $link_count > 1 ) {
            Record_Result("SWU_E2.2.5", -1, -1, "",
                          String_Value("Extra links in") . " " .
                          String_Value("Site banner") . " " .
                          String_Value("Found") . " $link_count " .
                          String_Value("expecting") . "1");
        }
    }
    else {
        print "No SITE_BANNER section links\n" if $debug;
    }
    
    #
    # Did we find a site title URL ?
    #
    if ( ! defined($site_title_link) ) {
        Record_Result("SWU_E2.2.5", -1, -1, "",
                      String_Value("Missing link in site title"));
    }

    #
    # Check Site Banner images if we have a set of expected images
    #
    if ( defined($site_banner_images{$language}) ) {
        $expected_link_list_addr = $site_banner_images{$language};
        Check_Expected_Images($url, $list_addr, $expected_link_list_addr,
                              "SWU_E2.2.3", String_Value("Site banner"));
    }
    else {
        print "No expected SITE_BANNER section images\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Check_Site_Navigation_Links
#
# Parameters: url - URL
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#             site_links - hash table of site links
#
# Description:
#
#    This function performs a number of checks on the site navigation
# section links.  It checks to see if expected links
# are present.
#***********************************************************************
sub Check_Site_Navigation_Links {
    my ($url, $language, $link_sets, $site_links) = @_;

    my ($list_addr, %empty_section_hash, @empty_list);
    my ($section_hash, $lang_list_addr, $link);

    #
    # Check Site Navigation links
    #
    print "Check Site Navigation links\n" if $debug;
    if ( defined($$link_sets{"SITE_NAV"}) ) {
        $list_addr = $$link_sets{"SITE_NAV"};
        
        #
        # Site navigation links are text only links, check for
        # any image links.
        #
        Check_For_Image_Links($url, $list_addr, "SWU_E2.2.5",
                              String_Value("Site navigation"));

        #
        # Do we have a set of site links for this section and language ?
        #
        if ( defined($site_links) && ($language ne "") ) {
            #
            # Get language hash for this section
            #
            if ( ! defined($$site_links{"SITE_NAV"}) ) {
                $$site_links{"SITE_NAV"} = \%empty_section_hash;
            }
            $section_hash = $$site_links{"SITE_NAV"};
            
            #
            # Get language specific link list
            #
            #
            if ( ! defined($$section_hash{$language}) ) {
                $$section_hash{$language} = \@empty_list;
                $lang_list_addr = \@empty_list;
                
                #
                # Since we dont have a language specific set of
                # site links, use this page's set as the default set.
                #
                print "Create new expected list of navigation links for language $language\n" if $debug;
                foreach $link (@$list_addr) {
                    #
                    # If this is an anchor, save the link object.
                    #
                    if ( $link->link_type eq "a" ) {
                        push(@$lang_list_addr, $link);
                        print "Add link \"" . $link->anchor . "\" href = " .
                              $link->abs_url . " to list\n" if $debug;
                    }
                }
            }
            else {
                #
                # Check this page's link list against the stored
                # list.
                #
                $lang_list_addr = $$section_hash{$language};
                Compare_Link_Lists($url, $list_addr, $lang_list_addr,
                                   "SWU_E2.2.5",
                                   String_Value("Site navigation"));
            }
        }
    }
}

#***********************************************************************
#
# Name: Check_Breadcrumb_Links
#
# Parameters: url - URL
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function performs a number of checks on the breadcrumb
# section links.  It checks to see if expected links
# are present.
#***********************************************************************
sub Check_Breadcrumb_Links {
    my ($url, $language, $link_sets) = @_;

    my ($site_title_link, $first_breadcrumb, $link);
    my ($site_title_url, $first_breadcrumb_url, $message);
    my ($list_addr, $expected_link_list_addr, @empty_list);
    my ($expected_href_list_addr, $optional_link_list_addr);
    my ($optional_href_list_addr);

    #
    # Check Breadcrumb links
    #
    print "Check breadcrumb links\n" if $debug;
    if ( defined($$link_sets{"BREADCRUMB"}) ) {
        $list_addr = $$link_sets{"BREADCRUMB"};

        #
        # Get list of expected links
        #
        if ( defined($breadcrumb_links{$language}) ) {
            $expected_link_list_addr = $breadcrumb_links{$language};
        }

        #
        # Get list of expected link href values
        #
        if ( defined($breadcrumb_link_hrefs{$language}) ) {
            $expected_href_list_addr = $breadcrumb_link_hrefs{$language};
        }

        #
        # Get list of optional links
        #
        if ( defined($breadcrumb_optional_links{$language}) ) {
            $optional_link_list_addr = $breadcrumb_optional_links{$language};
        }

        #
        # Get list of optional link href values
        #
        if ( defined($breadcrumb_optional_link_hrefs{$language}) ) {
            $optional_href_list_addr = $breadcrumb_optional_link_hrefs{$language};
        }

        #
        # Do we have a set of expected links ?
        #
        if ( defined($breadcrumb_links{$language}) ) {
            $expected_link_list_addr = $breadcrumb_links{$language};
            Check_Expected_Links($url, $list_addr, $expected_link_list_addr,
                                 $expected_href_list_addr, 
                                 $optional_link_list_addr,
                                 $optional_href_list_addr, "SWU_E2.2.5",
                                 "SWU_E2.2.5", String_Value("Breadcrumb"));

            #
            # Check that all links are text based (i.e. no image links)
            #
            Check_For_Image_Links($url, $list_addr, "SWU_E2.2.5",
                                  String_Value("Breadcrumb"));


            #
            # Check if the Home breadcrumb matches the Site Title link
            # in the Site Banner
            #
            if ( defined($$link_sets{"SITE_BANNER"}) ) {
                #
                # Go through the breadcrumb link list to find the first anchor
                # link (i.e. skip over images). This is the Home link
                # which should be a link to the home page.
                #
                foreach $link (@$list_addr) {
                    if ( $link->link_type eq "a" ) {
                        $first_breadcrumb = $link;
                        last;
                    }
                }

                #
                # Go through the site banner link list to find the first anchor
                # link (i.e. skip over images). This is the Site Title link
                # which should be a link to the home page.
                #
                $list_addr = $$link_sets{"SITE_BANNER"};
                foreach $link (@$list_addr) {
                    if ( $link->link_type eq "a" ) {
                        $site_title_link = $link;
                        last;
                    }
                }
                
                #
                # Did we get home breadcrumb and site title links ?
                #
                if ( defined($first_breadcrumb) && defined($site_title_link)) {
                    #
                    # Do the URL values match ?
                    #
                    $first_breadcrumb_url = $first_breadcrumb->abs_url;
                    $site_title_url = $site_title_link->abs_url;
                    if ( lc($first_breadcrumb_url) ne lc($site_title_url) ) {
                        $message = String_Value("First breadcrumb URL") .
                                   " '" . $first_breadcrumb_url . "' " .
                                   String_Value("does not match site banner URL") .
                                   " '" . $site_title_url . "' ";
                        Record_Result("SWU_E2.2.5", $first_breadcrumb->line_no,
                                      $first_breadcrumb->column_no,
                                      $first_breadcrumb->source_line, $message);

                    }
                }
            }
        }
    }
    else {
        print "No BREADCRUMB section links\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Check_Terms_and_Conditions_Links
#
# Parameters: url - URL
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#             site_links - hash table of site links
#
# Description:
#
#    This function performs a number of checks on the terms and conditions
# section links.  It checks to see if expected links are present.
#***********************************************************************
sub Check_Terms_and_Conditions_Links {
    my ($url, $language, $link_sets, $site_links) = @_;

    my ($list_addr, $expected_link_list_addr, @empty_list);
    my ($expected_href_list_addr, $optional_link_list_addr);
    my ($optional_href_list_addr, $link_set_list_addr);

    #
    # Do we have Terms and Conditions Footer links ?
    #
    print "Check Terms and Conditions Footer links\n" if $debug;
    if ( defined($$link_sets{"TERMS_CONDITIONS_FOOTER"}) ) {
        $list_addr = $$link_sets{"TERMS_CONDITIONS_FOOTER"};

        #
        # Site footer links are text only links, check for
        # any image links.
        #
        Check_For_Image_Links($url, $list_addr, "SWU_E2.2.7",
                              String_Value("Site footer"));
    }
    else {
        print "No TERMS_CONDITIONS_FOOTER section links\n" if $debug;
        $list_addr = \@empty_list;
    }

    #
    # Get list of expected footer links
    #
    if ( defined($terms_cond_footer_links{$language}) ) {
        $expected_link_list_addr = $terms_cond_footer_links{$language};
    }

    #
    # Get list of expected footer link href values
    #
    if ( defined($terms_cond_footer_link_hrefs{$language}) ) {
        $expected_href_list_addr = $terms_cond_footer_link_hrefs{$language};
    }

    #
    # Get list of optional footer links
    #
    $optional_link_list_addr = \@empty_list;

    #
    # Get list of optional footer link href values
    #
    $optional_href_list_addr = \@empty_list;

    #
    # Check Terms and Conditions Footer links if we have a set of expected links
    #
    if ( defined($terms_cond_footer_links{$language}) ) {
        Check_Expected_Links($url, $list_addr, $expected_link_list_addr,
                             $expected_href_list_addr, $optional_link_list_addr,
                             $optional_href_list_addr, "SWU_E2.2.7",
                             "SWU_E2.2.7", String_Value("Site footer"));
    }
}

#***********************************************************************
#
# Name: Check_Site_Footer_Links
#
# Parameters: url - URL
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#             site_links - hash table of site links
#
# Description:
#
#    This function performs a number of checks on the site footer
# section links.  It checks to see if expected links
# are present.
#***********************************************************************
sub Check_Site_Footer_Links {
    my ($url, $language, $link_sets, $site_links) = @_;

    my ($list_addr, $expected_link_list_addr, @empty_list);
    my ($expected_href_list_addr, $optional_link_list_addr);
    my ($optional_href_list_addr, $link_set_list_addr);

    #
    # Do we have Site Footer links ?
    #
    print "Check Site Footer links\n" if $debug;
    if ( defined($$link_sets{"SITE_FOOTER"}) ) {
        $list_addr = $$link_sets{"SITE_FOOTER"};

        #
        # Site footer links are text only links, check for
        # any image links.
        #
        Check_For_Image_Links($url, $list_addr, "SWU_E2.2.7",
                              String_Value("Site footer"));
    }
    else {
        print "No SITE_FOOTER section links\n" if $debug;
        $list_addr = \@empty_list;
    }

    #
    # Get list of expected footer links
    #
    if ( defined($site_footer_links{$language}) ) {
        $expected_link_list_addr = $site_footer_links{$language};
    }

    #
    # Get list of expected footer link href values
    #
    if ( defined($site_footer_link_hrefs{$language}) ) {
        $expected_href_list_addr = $site_footer_link_hrefs{$language};
    }

    #
    # Get list of optional footer links
    #
    if ( defined($site_footer_optional_links{$language}) ) {
        $optional_link_list_addr = $site_footer_optional_links{$language};
    }

    #
    # Get list of optional footer link href values
    #
    if ( defined($site_footer_optional_link_hrefs{$language}) ) {
        $optional_href_list_addr = $site_footer_optional_link_hrefs{$language};
    }

    #
    # Check Site Footer links if we have a set of expected links
    #
    if ( defined($site_footer_links{$language}) ) {
        Check_Expected_Links($url, $list_addr, $expected_link_list_addr,
                             $expected_href_list_addr, $optional_link_list_addr,
                             $optional_href_list_addr, "SWU_E2.2.7",
                             "SWU_E2.2.7", String_Value("Site footer"));
    }

    #
    # Get list of required footer links that don't have any particular
    # ordering.
    #
    if ( defined($site_footer_link_set{$language}) ) {
        $link_set_list_addr = $site_footer_link_set{$language};
    }

    #
    # Check required Site Footer links if we have a set of expected links
    #
    if ( defined($link_set_list_addr) ) {
        Check_Required_Link_Set($url, $list_addr, $link_set_list_addr,
                                "SWU_E2.2.7", String_Value("Site footer"));
    }
}

#***********************************************************************
#
# Name: Check_GC_Footer_Links
#
# Parameters: url - URL
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function performs a number of checks on the GC Footer
# section links.  It checks to see if expected links
# are present.
#***********************************************************************
sub Check_GC_Footer_Links {
    my ($url, $language, $link_sets) = @_;

    my ($list_addr, $expected_link_list_addr, @empty_list);
    my ($expected_href_list_addr, $optional_link_list_addr);
    my ($optional_href_list_addr);

    #
    # Do we have GC Footer links ?
    #
    print "Check GC Footer links\n" if $debug;
    if ( defined($$link_sets{"GC_FOOTER"}) ) {
        $list_addr = $$link_sets{"GC_FOOTER"};
    }
    else {
        print "No GC_FOOTER section links\n" if $debug;
        $list_addr = \@empty_list;
    }

    #
    # Get list of expected footer links
    #
    if ( defined($gc_footer_links{$language}) ) {
        $expected_link_list_addr = $gc_footer_links{$language};
    }

    #
    # Get list of expected footer link href values
    #
    if ( defined($gc_footer_link_hrefs{$language}) ) {
        $expected_href_list_addr = $gc_footer_link_hrefs{$language};
    }

    #
    # Get list of optional footer links
    #
    if ( defined($gc_footer_optional_links{$language}) ) {
        $optional_link_list_addr = $gc_footer_optional_links{$language};
    }

    #
    # Get list of optional footer link href values
    #
    if ( defined($gc_footer_optional_link_hrefs{$language}) ) {
        $optional_href_list_addr = $gc_footer_optional_link_hrefs{$language};
    }

    #
    # Check GC Footer links if we have a set of expected links
    #
    if ( defined($gc_footer_links{$language}) ) {
        Check_Expected_Links($url, $list_addr, $expected_link_list_addr,
                             $expected_href_list_addr, $optional_link_list_addr,
                             $optional_href_list_addr, "SWU_E2.2.7",
                             "SWU_E2.2.7", String_Value("GC footer"));

        #
        # Check the number of links
        #
        Check_Expected_Link_Count($url, $list_addr, $expected_link_list_addr,
                             $expected_href_list_addr, $optional_link_list_addr,
                             $optional_href_list_addr, "SWU_E2.2.7",
                             "SWU_E2.2.7", String_Value("GC footer"));
    }
}

#***********************************************************************
#
# Name: Match_Link_Anchor_and_Href
#
# Parameters: link - a link object
#             expected_anchor - expected anchor text
#             expected_href - expected href value
#             tcid - testcase identifier
#             section - document section
#
# Description:
#
#   This function checks the anchor text and href values of a link
# against expected values. If the anchor values match, and the href
# value does not match, a failure is generated.
#
#***********************************************************************
sub Match_Link_Anchor_and_Href {
    my ($link, $expected_anchor, $expected_href, $tcid, $section) = @_;

    my ($anchor_text, $href, $message);

    #
    # Trim anchor text and encode any entities
    #
    $anchor_text = Trim_Whitespace($link->anchor);
    $anchor_text = encode_entities($anchor_text);

    #
    # Does the anchor text match what is expected ?
    #
    print "Check link anchor text \"" . $anchor_text .
          "\" versus \"$expected_anchor\"\n" if $debug;
    if ( lc($anchor_text) eq lc($expected_anchor) ) {
        #
        # Does the href text match what is expected ?
        #
        $href = $link->abs_url;
        print "Check link href \"" . $href .
              "\" versus \"$expected_href\"\n" if $debug;
        if ( ($expected_href ne "") && ($href ne $expected_href) ) {
            $message = String_Value("Invalid href") .
                        "'" . $href . "'" .
                        String_Value("in") . " $section " . " " . 
                        String_Value("expecting") . "'" . $expected_href . "'";
            Record_Result($tcid, $link->line_no, $link->column_no,
                          $link->source_line, $message);
        }

        #
        # We found a match on the anchor portion.
        #
        return(1);
    }

    #
    # We did not find a match on the anchor portion.
    #
    return(0);
}

#***********************************************************************
#
# Name: Check_Expected_Link_Set
#
# Parameters: url - URL
#             link_list_addr - address of a list of link objects
#             expected_link_list_addr - address of a list of
#               expected links
#             expected_href_list_addr - address of a list of
#               expected href values
#             tcid - testcase identifier
#             section - section string (e.g. GC Navigation)
#
# Description:
#
#    This function checks a set of links to see that it contains a set
# of expected links.  The actual order of the links is not important, 
# only that all expected links are present.  If an expected link
# is not present, a testcase failure is generated.
#
#***********************************************************************
sub Check_Expected_Link_Set {
    my ($url, $link_list_addr, $expected_link_list_addr,
        $expected_href_list_addr, $tcid, $section) = @_;

    my ($link, $link_count, $link_no, @links, $expected_link_count);
    my ($link_text, $message, $anchor, $href, %expected_link_set);
    my ($expected_href_count);
    my (@actual_link_order) = ();

    #
    # Check that all the links appear in the set, we don't care about
    # the order.
    #
    print "Check_Expected_Link_Set tcid = $tcid\n" if $debug;
    if ( defined($$current_clf_check_profile{$tcid}) ) {
        #
        # Go through the link list and only include links that are
        # in anchor tags (e.g. remove image links).
        #
        foreach $link (@$link_list_addr) {
            if ( $link->link_type eq "a" ) {
                push(@links, $link);
            }
        } 

        #
        # Get number of links in actual list as well as the expected
        # link list
        #
        $link_count = @links;
        if ( defined($expected_link_list_addr) ) {
            $expected_link_count = @$expected_link_list_addr;
        }
        else {
            $expected_link_count = 0;
        }
        if ( defined($expected_href_list_addr) ) {
            $expected_href_count = @$expected_href_list_addr;
        }
        else {
            $expected_href_count = 0;
        }
        print "Expecting $expected_link_count links " .
              join(", ", @$expected_link_list_addr) . "\n" if $debug;

        #
        # Did we find at least the expected number links ?
        # (there may be optional links e.g. the language link)
        #
        print "Have $link_count, expecting $expected_link_count links\n" if $debug;
        if ( $link_count < $expected_link_count ) {
            Record_Result($tcid, -1, -1, "",
                          String_Value("Missing links in") . " $section. " .
                          String_Value("Found") . " $link_count " .
                          String_Value("links"));
        }
        else {

            #
            # Initialize data structure for expected link anchor text.
            #
            for ($link_no = 0; $link_no < $expected_link_count; $link_no++) {
                $anchor = $$expected_link_list_addr[$link_no];
                $expected_link_set{$anchor} = 0;
            }

            #
            # Check each link in the link set for a match on the
            # anchor text and href values.
            #
            foreach $link (@$link_list_addr) {
                #
                # Check values of the anchor text and href for each expected item.
                #
                for ($link_no = 0; $link_no < $expected_link_count; $link_no++) {
                    #
                    # Get expected anchor and href values
                    #
                    $anchor = $$expected_link_list_addr[$link_no];
                    if ( defined($expected_href_list_addr) &&
                         defined($$expected_href_list_addr[$link_no]) )  {
                        $href = $$expected_href_list_addr[$link_no];
                    }
                    else {
                        #
                        # No expected href set it to an empty string
                        #
                        $href = "";
                    }

                    #
                    # Check anchor and href values
                    #
                    print "Check for link with anchor = $anchor, href = $href\n" if $debug;
                    if ( Match_Link_Anchor_and_Href($link, $anchor, $href,
                                                    $tcid, $section) ) {
                        $expected_link_set{$anchor} = 1;
                        
                        #
                        # Save link refernce in actual link order list
                        #
                        push(@actual_link_order, $link);
                    }
                }
            }

            #
            # Did we find all of the expected links ?
            #
            foreach $anchor (@$expected_link_list_addr) {
                if ( ! $expected_link_set{$anchor} ) {
                    Record_Result($tcid, -1, -1, "",
                                  String_Value("Missing link") . " '$anchor' " .
                                  String_Value("in") . " $section");
                }
            }
        }
    }
    
    #
    # Return list of links in the order they were found.
    #
    return(@actual_link_order);
}

#***********************************************************************
#
# Name: Check_Splash_Page_Links
#
# Parameters: url - URL
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function performs checks on splash page links.
# document.  Checks are performed on the language links and the footer links.
#
#***********************************************************************
sub Check_Splash_Page_Links {
    my ($url, $language, $link_sets) = @_;

    my ($list_addr, $expected_link_list_addr, @empty_list);
    my ($expected_href_list_addr, $optional_link_list_addr);
    my ($optional_href_list_addr, @links, @hrefs);
    my ($anchor, $lang, $href, @actual_links, $link, $list);

    #
    # Do we have language links ?
    #
    print "Check Splash language links\n" if $debug;
    if ( defined($$link_sets{"SPLASH_LANG_LINKS"}) ) {
        $list_addr = $$link_sets{"SPLASH_LANG_LINKS"};
    }
    else {
        print "No SPLASH_LANG_LINKS section links\n" if $debug;
        $list_addr = \@empty_list;
    }
    
    #
    # Create a list of the splash page links and href values.
    # We don't care about the order.
    #
    while ( ($lang, $anchor) = each %splash_lang_links ) {
        push(@links, $$anchor[0]);
    }
    while ( ($lang, $href) = each %splash_lang_hrefs ) {
        push(@hrefs, $$href[0]);
    }

    #
    # Check Splash page language links
    #
    @actual_links = Check_Expected_Link_Set($url, $list_addr, \@links,
                                            \@hrefs, "SWU_E2.4",
                                     String_Value("Language selection links"));

    #
    # Get language of first language link.  It is used to determine the
    # language of the header image (e.g. FIP) alt text.
    #
    $lang = "unknown";
    if ( @actual_links > 0 ) {
        $link = $actual_links[0];
        
        if ( defined($link->lang) ) {
            $lang = $link->lang;
            print "First language link is $lang\n" if $debug;
        }
    }
    
    #
    # Check header links/images
    #
    if ( defined($$link_sets{"HEADER"}) ) {
        $list_addr = $$link_sets{"HEADER"};
    }
    else {
        print "No HEADER section links\n" if $debug;
    }

    #
    # Check header images if we have a set of expected images
    #
    if ( defined($splash_header_images{$lang}) ) {
            print "Check header images\n" if $debug;
        $expected_link_list_addr = $splash_header_images{$lang};
        Check_Expected_Images($url, $list_addr, $expected_link_list_addr,
                              "SWU_E2.4", String_Value("Splash page header"));
    }
    else {
        print "No expected HEADER section images\n" if $debug;
    }

    #
    # Check language selection links/images
    #
    if ( defined($$link_sets{"SPLASH_LANG_LINKS"}) ) {
        $list_addr = $$link_sets{"SPLASH_LANG_LINKS"};
    }
    else {
        print "No SPLASH_LANG_LINKS section links\n" if $debug;
    }

    #
    # Check language selection images if we have a set of expected images
    #
    if ( defined($splash_lang_images{$lang}) ) {
            print "Check language selection images\n" if $debug;
        $expected_link_list_addr = $splash_lang_images{$lang};
        Check_Expected_Images($url, $list_addr, $expected_link_list_addr,
                              "SWU_E2.4", String_Value("Body images"));
    }
    else {
        print "No expected SPLASH_LANG_LINKS section images\n" if $debug;
    }

    #
    # Do we have footer links ?
    #
    print "Check Splash footer links\n" if $debug;
    if ( defined($$link_sets{"TERMS_CONDITIONS_FOOTER"}) ) {
        $list_addr = $$link_sets{"TERMS_CONDITIONS_FOOTER"};
    }
    else {
        print "No TERMS_CONDITIONS_FOOTER section links\n" if $debug;
        $list_addr = \@empty_list;
    }
    
    #
    # Get the list of footer links in the language order determined from
    # the language links.
    #
    @links = ();
    @hrefs = ();
    foreach $link (@actual_links) {
        print "Link language order, lang = " . $link->lang .
              "\n" if $debug;
        if ( defined($splash_footer_links{$link->lang}) ) {
            $list = $splash_footer_links{$link->lang};
            foreach (@$list) {
                print "Add to footer links " . $_ . "\n" if $debug;
                push(@links, $_);
            }
        }
        if ( defined($splash_footer_hrefs{$link->lang}) ) {
            $list = $splash_footer_hrefs{$link->lang};
            foreach (@$list) {
                print "Add to footer hrefs " . $_ . "\n" if $debug;
                push(@hrefs, $_);
            }
        }
    }


    #
    # Check Splash page footer links
    #
    Check_Expected_Links($url, $list_addr, \@links, \@hrefs,
                         \@empty_list, \@empty_list, "SWU_E2.4",
                         "SWU_E2.4", String_Value("Terms and conditions"));
}

#***********************************************************************
#
# Name: Check_Server_Page_Links
#
# Parameters: url - URL
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function performs checks on server page links.
# document.  Checks are performed on the title, body and footer links.
#
#***********************************************************************
sub Check_Server_Page_Links {
    my ($url, $language, $link_sets) = @_;

    my ($list_addr, $expected_link_list_addr, @empty_list);
    my ($expected_href_list_addr, $optional_link_list_addr);
    my ($optional_href_list_addr, @links, @hrefs, @language_order);
    my ($anchor, $lang, $href, @actual_links, $link, $list);

    #
    # Do we have a left site title link ? This is mandatory.
    #
    print "Check Server Message page site title links\n" if $debug;
    if ( defined($$link_sets{"SITE_TITLE_LEFT"}) ) {
        $list_addr = $$link_sets{"SITE_TITLE_LEFT"};
        $lang = "";
        
        #
        # Look for first anchor link, it should be the site title
        # link.
        #
        foreach $link (@$list_addr) {
            if ( ($link->link_type eq "a") && defined($link->lang) ) {
                push(@language_order, $link->lang);
                $lang = $link->lang;
                last;
            }
        }
        
        #
        # If lang is not set, we did not find a site title link
        #
        if ( $lang eq "" ) {
            print "No left site title link\n" if $debug;
            Record_Result("SWU_E2.5", -1, -1, "",
                          String_Value("Missing site title link"));
        }
    }
    else {
        #
        # Missing left site title link
        #
        print "No SITE_TITLE_LEFT section links\n" if $debug;
        Record_Result("SWU_E2.5", -1, -1, "",
                      String_Value("Missing site title link"));
        $list_addr = \@empty_list;
    }

    #
    # Do we have a right site title link ? This is optional.
    #
    if ( defined($$link_sets{"SITE_TITLE_RIGHT"}) ) {
        $list_addr = $$link_sets{"SITE_TITLE_RIGHT"};
        $link = $$list_addr[0];
        if ( defined($link->lang) ) {
            push(@language_order, $link->lang);
            $lang .= $link->lang;
        }
    }
    else {
        print "No SITE_TITLE_RIGHT section links\n" if $debug;
    }
    print "Server message page language order " .
          join(" ", @language_order) . "\n" if $debug;
          
    #
    # Check header links/images
    #
    if ( defined($$link_sets{"HEADER"}) ) {
        $list_addr = $$link_sets{"HEADER"};
    }
    else {
        print "No HEADER section links\n" if $debug;
    }

    #
    # Check header images if we have a set of expected images
    #
    if ( defined($server_header_images{$lang}) ) {
            print "Check header images\n" if $debug;
        $expected_link_list_addr = $server_header_images{$lang};
        Check_Expected_Images($url, $list_addr, $expected_link_list_addr,
                              "SWU_E2.5", String_Value("Server message page header"));
    }
    else {
        print "No expected HEADER section images\n" if $debug;
    }

    #
    # Do we have content links ?
    #
    print "Check Server page content links\n" if $debug;
    if ( defined($$link_sets{"CONTENT"}) ) {
        $list_addr = $$link_sets{"CONTENT"};
    }
    else {
        print "No CONTENT section links\n" if $debug;
        $list_addr = \@empty_list;
    }

    #
    # Get the list of content links in the language order determined from
    # the title links.
    #
    @links = ();
    @hrefs = ();
    foreach $lang (@language_order) {
        if ( defined($server_content_links{$lang}) ) {
            print "Add $lang server content links\n" if $debug;
            $list = $server_content_links{$lang};
            foreach (@$list) {
                print "Add to content links " . $_ . "\n" if $debug;
                push(@links, $_);
            }
        }
        if ( defined($server_content_hrefs{$lang}) ) {
            $list = $server_content_hrefs{$lang};
            foreach (@$list) {
                print "Add to content hrefs " . $_ . "\n" if $debug;
                push(@hrefs, $_);
            }
        }
    }

    #
    # Check server page footer links
    #
    Check_Expected_Links($url, $list_addr, \@links, \@hrefs,
                         \@empty_list, \@empty_list, "SWU_E2.5",
                         "SWU_E2.5", String_Value("Body links"));

    #
    # Do we have footer links ?
    #
    print "Check Server page footer links\n" if $debug;
    if ( defined($$link_sets{"TERMS_CONDITIONS_FOOTER"}) ) {
        $list_addr = $$link_sets{"TERMS_CONDITIONS_FOOTER"};
    }
    else {
        print "No TERMS_CONDITIONS_FOOTER section links\n" if $debug;
        $list_addr = \@empty_list;
    }

    #
    # Get the list of footer links in the language order determined from
    # the title links.
    #
    @links = ();
    @hrefs = ();
    foreach $lang (@language_order) {
        if ( defined($server_footer_links{$lang}) ) {
            print "Add $lang server footer links\n" if $debug;
            $list = $server_footer_links{$lang};
            foreach (@$list) {
                print "Add to footer links " . $_ . "\n" if $debug;
                push(@links, $_);
            }
        }
        if ( defined($server_footer_hrefs{$lang}) ) {
            $list = $server_footer_hrefs{$lang};
            foreach (@$list) {
                print "Add to footer hrefs " . $_ . "\n" if $debug;
                push(@hrefs, $_);
            }
        }
    }

    #
    # Check server page footer links
    #
    Check_Expected_Links($url, $list_addr, \@links, \@hrefs,
                         \@empty_list, \@empty_list, "SWU_E2.5",
                         "SWU_E2.5", String_Value("Terms and conditions"));
}

#***********************************************************************
#
# Name: Check_Content_Page_Links
#
# Parameters: url - URL
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#             site_links - hash table of site links
#
# Description:
#
#    This function performs checks on content page links.
# document.  Checks are performed on the GC navigation bar, left
# navigation and footer.
#
#***********************************************************************
sub Check_Content_Page_Links {
    my ($url, $language, $link_sets, $site_links) = @_;

    #
    # Check GC Navigation Links
    #
    print "Check content page links\n" if $debug;
    Check_GC_Navigation_Links($url, $language, $link_sets);

    #
    # Check Site Banner Links
    #
    Check_Site_Banner_Links($url, $language, $link_sets);

    #
    # Check Site Navigation Links
    #
    Check_Site_Navigation_Links($url, $language, $link_sets, $site_links);
    
    #
    # Check Breadcrumb Links
    #
    Check_Breadcrumb_Links($url, $language, $link_sets);

    #
    # Check Terms and Conditions Links
    #
    Check_Terms_and_Conditions_Links($url, $language, $link_sets, $site_links);

    #
    # Check Site Footer Links
    #
    Check_Site_Footer_Links($url, $language, $link_sets, $site_links);

    #
    # Check GC Footer Links
    #
    Check_GC_Footer_Links($url, $language, $link_sets);
}

#***********************************************************************
#
# Name: Check_Common_Page_Links
#
# Parameters: url - URL
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#
# Description:
#
#    This function performs checks on links that are common to all pages.
#
#***********************************************************************
sub Check_Common_Page_Links {
    my ($url, $language, $link_sets) = @_;

    my ($list_addr, $href, $link, @links, $link_count, $href_count, $i);
    my ($message, $this_href, $match_href);

    #
    # Do we have links in the SKIP_LINKS section ? This is mandatory.
    #
    print "Check common page links\n" if $debug;
    if ( defined($$link_sets{"SKIP_LINKS"}) ) {
        $list_addr = $$link_sets{"SKIP_LINKS"};

        #
        # Get the number of expected links
        #
        $href_count = @skip_links_hrefs;

        #
        # Get a list of all the anchor links in this section (i.e. skip
        # over image links).
        #
        foreach $link (@$list_addr) {
            if ( $link->link_type eq "a" ) {
                push(@links, $link);
            }
        }
        $link_count = @links;
        print "Have $link_count, expect $href_count\n" if $debug;

        #
        # Do we have the expected number of links ?
        #
        if ( $link_count != $href_count ) {
            Record_Result("SWU_TEMPLATE", -1, -1, "",
                          String_Value("Missing links in") . " SKIP_LINKS. " .
                          String_Value("Found") . " $link_count " .
                          String_Value("links") . " " .
                          String_Value("expecting") . $href_count);
        }
        else {
            #
            # Check each link to see that the href values match, we may
            # have a list of possible href values (the named anchors changed
            # between WET 2.3 and 3.0).
            #
            $i = 0;
            foreach $link (@links) {
                $href = $skip_links_hrefs[$i];

                #
                # Split href value on white space in case there are several
                # possible href values.
                #
                $match_href = 0;
                foreach $this_href (split(/\s+/, $href)) {
                    print "Check " . $link->href . " for match with $this_href\n" if $debug;
                    if ( $link->href eq $this_href ) {
                        #
                        # Found match on href value, stop checking.
                        #
                        $match_href = 1;
                        last;
                    }
                }

                #
                # Did we find a match on one of the possible href values ?
                #
                if ( ! $match_href ) {
                    $message = String_Value("Invalid href") .
                               "'" . $link->href . "'" .
                               String_Value("in") . "SKIP_LINKS " .
                               String_Value("link") . " # " . ($i + 1) .
                               " " . String_Value("expecting one of") .
                               "'" . $href . "'";
                    Record_Result("SWU_TEMPLATE", $link->line_no,
                                  $link->column_no, $link->source_line,
                                  $message);
                }

                #
                # increment expected href counter
                #
                $i++;
            }
        }
    }
    else {
        #
        # Missing SKIP_LINKS section links
        #
        print "No SKIP_LINKS section links\n" if $debug;
        Record_Result("SWU_TEMPLATE", -1, -1, "",
                      String_Value("Missing skip links"));
    }
}

#***********************************************************************
#
# Name: SWU_Check_Links
#
# Parameters: tqa_results_list - address of hash table results
#             url - URL
#             profile - testcase profile
#             language - URL language
#             link_sets - table of lists of link objects (1 list per
#               document section)
#             site_links - hash table of site links
#
# Description:
#
#    This function performs a number of checks on links found within a
# document.  Checks are performed on the GC navigation bar, left
# navigation and footer. The checks include verifying the correct
# links appear with the proper href values. It also checks that
# links are consistent between pages.
#
#***********************************************************************
sub SWU_Check_Links {
    my ($tqa_results_list, $url, $profile, $language, $link_sets,
        $site_links) = @_;

    my ($result_object, @local_tqa_results_list, $list_addr);
    my ($expected_link_list_addr, @empty_list, $tcid, $do_tests);
    my (@local_archive_tqa_results_list);

    #
    # Do we have a valid profile ?
    #
    print "SWU_Check_Links: profile = $profile, language = $language\n" if $debug;
    if ( ! defined($clf_check_profile_map{$profile}) ) {
        print "Unknown testcase profile passed $profile\n" if $debug;
        return;
    }

    #
    # Initialize the test case pass/fail table.
    #
    $current_clf_check_profile = $clf_check_profile_map{$profile};
    $results_list_addr = \@local_tqa_results_list;

    #
    # Are any of the testcases defined in this module
    # in the testcase profile ?
    #
    $do_tests = 0;
    foreach $tcid (keys(%testcase_description_en)) {
        if ( defined($$current_clf_check_profile{$tcid}) ) {
            $do_tests = 1;
            print "Testcase $tcid found in current testcase profile\n" if $debug;
            last;
        }
    }
    if ( ! $do_tests ) {
        #
        # No tests handled by this module
        #
        print "No tests handled by this module\n" if $debug;
        return();
    }

    #
    # Save URL in global variable
    #
    if ( $url =~ /^http/i ) {
        $current_url = $url;
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of HTML
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # Check for a splash page language links section
    #
    if ( defined($$link_sets{"SPLASH_LANG_LINKS"}) ) {
        #
        # Check splash page links
        #
        Check_Splash_Page_Links($url, $language, $link_sets);
    }
    elsif ( defined($content_subsection_found{"SERVER_DECORATION"}) ) {
        #
        # Check server page links
        #
        Check_Server_Page_Links($url, $language, $link_sets);
    }
    else {
        #
        # Check content page links.
        #
        Check_Content_Page_Links($url, $language, $link_sets, $site_links);
    }
    
    #
    # Check for links common to all pages
    #
    Check_Common_Page_Links($url, $language, $link_sets);

    #
    # Add our results to previous results
    #
    foreach $result_object (@local_tqa_results_list) {
        push(@$tqa_results_list, $result_object);
    }

    #
    # Check Archived links
    #
    if ( defined($$current_clf_check_profile{"SWU_6.1.5"}) ) {
        @local_archive_tqa_results_list = CLF_Archive_Check_Links($url,
                                              $profile, "SWU_6.1.5",
                                              Testcase_Description("SWU_6.1.5"),
                                              $link_sets);
    }

    #
    # Add our results to previous results
    #
    foreach $result_object (@local_archive_tqa_results_list) {
        push(@$tqa_results_list, $result_object);
    }
}

#***********************************************************************
#
# Name: SWU_Check_Archive_Check
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             mime_type - mime type of content
#             resp - HTTP::Response object
#             content - content
#
# Description:
#
#   This function runs a number of technical QA checks on content that
# is marked as archived on the web.
#
#***********************************************************************
sub SWU_Check_Archive_Check {
    my ( $this_url, $language, $profile, $mime_type, $resp, $content ) = @_;

    my (@tqa_results_list, $result_object, $message);

    #
    # Initialize the test case pass/fail table.
    #
    print "SWU_Check_Archive_Check URL $this_url, mime-type = $mime_type, lanugage = $language, profile = $profile\n" if $debug;
    Initialize_Test_Results($profile, \@tqa_results_list);

    #
    # Are we doing archived on the web checking ?
    #
    if ( defined($$current_clf_check_profile{"SWU_6.1.5"}) ) {
        #
        # Check for archived on the web markers
        #
        $message = CLF_Archive_Archive_Check($profile, $this_url, $content);
        
        #
        # Did we get messages (implying the check failed) ?
        #
        if ( $message ne "" ) {
            Record_Result("SWU_6.1.5", -1, -1, "", $message);
        }
    }

    #
    # Return list of results
    #
    return(@tqa_results_list);
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
    my (@package_list) = ("tqa_result_object", "url_check", "crawler",
                          "clf_archive", "content_check");

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

