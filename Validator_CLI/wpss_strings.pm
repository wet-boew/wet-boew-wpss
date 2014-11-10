#***********************************************************************
#
# Name: wpss_strings.pm
#
# $Revision: 5477 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Validator_CLI/Tools/wpss_strings.pm $
# $Date: 2011-09-08 12:43:38 -0400 (Thu, 08 Sep 2011) $
#
# Description:
#
#   This module contains functions to provide text strings for labels
# and messages for the WPSS Tool.  It provides them in the language
# specified.
#
# Public functions:
#     Set_String_Table_Language
#     String_Value
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

package wpss_strings;

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
    @EXPORT  = qw(Set_String_Table_Language
                  String_Value);
    $VERSION = "1.0";
}

my %string_table_en = (
    "Crawled URL report header",	"The following is a list of crawled URLs from your site.

Site:
",
    "Validation report header",	"The following is a list of web documents from your site that contain validation errors.

Site:
",
    "Metadata report header",	"The following is a list of web documents from your site that contain Metadata Check errors.

Site:
",
    "TQA report header", "The following is a list of web documents from your site that contain TQA Check errors.

Site:
",
    "Link report header", "The following is a list of web documents from your site that contain Link Check violations.

Site:
",
    "Content report header", "The following is a list of web documents from your site that contain Content Check violations.

Site:
",
    "HTML Features report header", "The following is a list of web documents from your site that contain HTML document features.

Site:
",
    "Document List report header",	"The following is a sorted list of web documents from your site.

Site:
",
    "Entry page",	"Entry page ",
    "rewritten to",		" rewritten to ",
    "Analysis terminated",	"Analysis terminated",
    "Analysis completed",	"Analysis completed at (hh:mm:ss yyyy/mm/dd) ",
    "Analysis started",		"Analysis started at (hh:mm:ss yyyy/mm/dd) ",
    "Crawled URLs",		"Crawled URLs",
    "Validation",		"Validation",
    "Metadata",			"Metadata",
    "Document List",		"Document List",
    "Metadata Profile",		"Metadata Profile",
    "PDF Property Profile",	"PDF Property Profile",
    "TQA Testcase Profile",	"TQA Testcase Profile",
    "Content Check Testcase Profile",	"Content Check Testcase Profile",
    "TQA",  			"TQA",
    "Link", 			"Link",
    "Content", 			"Content",
    "HTML Features",		"HTML Features",
    "HTML Features Profile",	"HTML Features Profile",
    "pass", 			"pass",
    "fail", 			"fail",
    "referer",  		"referer",
    "Failed to get url",  	"Failed to get url ",
    "error is", 		",error is ",
    "List of URLs with HTML Feature",  "List of URLs with HTML Feature: ",
    "Line", 			"Line: ",
    "Column", 			"Column: ",
    "Source line", 			"Source line: ",
    "date checked", 			"date checked ",
    "Error",	 			"Error: ",
    "Testcase",				"Testcase: ",
    "failed",				"failed",
    "warning",				"warning",
    "Metadata Tag",			"Metadata Tag",
    "Property",				"Property",
    "Link at", 				"Link at ",
    "href", 				"href ",
    "Crawl stopped after", 		"Crawl stopped after ",
    "HTML url",				"HTML url ",
    "PDF url",				"PDF url ",
    "HTML Title",			"HTML Title ",
    "PDF Title",			"PDF Title ",
    "DC Title",				"dc.title   ",
    "Title",				"Title ",
    "Documents Checked",		"Documents Checked: ",
    "Documents with errors",		"Documents with errors: ",
    "2 spaces",				"  ",
    "4 spaces",				"    ",
    "Content violations",               "Content violations",
);

my %string_table_fr = (
    "Crawled URL report header",	"Ce qui suit est une liste de URL explorés de votre site.

Site:
",
    "Validation report header",	"Ce qui suit est une liste de documents Web de votre site qui contient des erreurs de validation.

Site:
",
    "Metadata report header",	"Ce qui suit est une liste de documents Web de votre site qui contient des erreurs de métadonnées.

Site:
",
    "TQA report header", "Ce qui suit est une liste de documents Web de votre site qui contient des erreurs AQT.

Site:
",
    "Link report header", "Ce qui suit est une liste de documents Web de votre site qui contient des erreurs de liens.

Site:
",
    "Content report header", "Ce qui suit est une liste de documents Web de votre site qui contient des erreurs de contenu.

Site:
",
    "HTML Features report header", " Ce qui suit est une liste de documents Web de votre site qui contient des fonctions HTML.

Site:
",
    "Document List report header",	"Ce qui suit est une liste triée des documents Web de votre site. 

Site :
",
    "Entry page",		"Page d'entrée ",
    "rewritten to",		"réécrit pour ",
    "Analysis terminated",	"Analyse a terminé",
    "Analysis completed",	"Analyse completée le (hh:mm:ss aaaa/mm/dd) ",
    "Analysis started",		"Analyse commencée le (hh:mm:ss aaaa/mm/dd) ",
    "Crawled URLs",		"URL explorés",
    "Validation",		"Validation",
    "Metadata",			"Métadonnées",
    "Document List",		"Liste des documents",
    "Metadata Profile",		"Profil de métadonnées ",
    "PDF Property Profile",	"Profil de propriété de PDF",
    "TQA Testcase Profile",	"Profil des cas de test de AQT ",
    "Content Check Testcase Profile",	"Profil des cas de test de contenu ",
    "Yes",			"Oui",
    "No",			"Non",
    "Report testcases that pass","Rapporter les cas de test qui passent",
    "TQA",  			"AQT",
    "Link", 			"Lien",
    "Content",  		"Contenu",
    "HTML Features",		"Fonctions HTML",
    "HTML Features Profile",	"Profil des fonctions HTML",
    "pass", 			"succès",
    "fail", 			"échec",
    "referer",  		"recommandataire",
    "Failed to get url",  	"Impossible d'obtenir le url ",
    "error is", 		",l'erreur est ",
    "List of URLs with HTML Feature",  "Liste des URL avec des fonctions HTML: ",
    "Line", 			"la ligne : ",
    "Column", 			"Colonne : ",
    "Source line", 			"Ligne de la source",
    "date checked", 			"date vérifiée ",
    "Error", 			"Erreur : ",
    "Testcase",   "Cas de test : ",
    "failed", 			"échouer ",
    "warning",				"avertissement",
    "Metadata Tag", "balise de métadonnées",
    "Property", "Propriété",
    "Link at", "Lien à ",
    "href", "href ",
    "Crawl stopped after", "L'exploration s'est arrêté après ",
    "HTML url",				"URL de HTML ",
    "PDF url",				"URL de PDF ",
    "HTML Title",			"Titre de HTML ",
    "PDF Title",			"Titre de PDF ",
    "DC Title",				"dc.title   ",
    "Title",				"Titre",
    "Documents Checked",		"Document Évalué: ",
    "Documents with errors",		"Documents avec des erreurs: ",
    "2 spaces",				"  ",
    "4 spaces",				"    ",
    "Content violations",               "Erreurs de contenu",
);

#
# Default language is English
#
my ($string_table) = \%string_table_en;

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

#**********************************************************************
#
# Name: Set_String_Table_Language
#
# Parameters: lang - language
#
# Description:
#
#   This function sets the string table to use for string translations
# to the specified language.
#
#**********************************************************************
sub Set_String_Table_Language {
    my ($lang) = @_;

    #
    # Do we want French ?
    #
    if ( $lang =~ /fra/i ) {
        $string_table = \%string_table_fr;
    }
    else {
        $string_table = \%string_table_en;
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

