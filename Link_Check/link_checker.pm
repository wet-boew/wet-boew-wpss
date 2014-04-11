#***********************************************************************
#
# Name: link_checker.pm	
#
# $Revision: 6609 $
# $URL: svn://10.36.20.226/trunk/Web_Checks/Link_Check/Tools/link_checker.pm $
# $Date: 2014-04-02 11:44:42 -0400 (Wed, 02 Apr 2014) $
#
# Description:
#
#   This file contains routines that check links for a number of quality
# checks.  These checks include
#   broken links (404 response)
#   cross language links (English page linking to a French page)
#   redirected links
#   bad network scope (Internet page linking to an Intranet document)
#
# Public functions:
#     Get_Link_Checker_Status_Messages
#     Link_Checker
#     Link_Check_Site_Titles
#     Link_Checker_Config
#     Link_Checker_Debug
#     Link_Checker_Set_Proxy
#     Set_Link_Checker_Domain_Alias_Map
#     Set_Link_Checker_Domain_Networkscope_Map
#     Set_Link_Checker_Ignore_Patterns
#     Set_Link_Check_Test_Profile
#     Set_Link_Check_CLF_Profile
#     Set_Link_Checker_Redirect_Ignore_Patterns
#     Set_Link_Checker_Site_Vanity_Domains
#     Set_Link_Checker_Language
#     Link_Checker_Get_Link_Status
#     Link_Check_Has_Rel_Alternate
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

package link_checker;

use Sys::Hostname;
use LWP::RobotUA;
use HTTP::Cookies;
use File::Basename;
use Encode;
use strict;
use URI::Escape;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Get_Link_Checker_Status_Messages
                  Link_Checker
                  Link_Check_Site_Titles
                  Link_Checker_Config 
                  Link_Checker_Debug
                  Link_Checker_Set_Proxy
                  Set_Link_Checker_Domain_Alias_Map
                  Set_Link_Checker_Domain_Networkscope_Map
                  Set_Link_Checker_Ignore_Patterns
                  Set_Link_Check_Test_Profile
                  Set_Link_Check_CLF_Profile
                  Set_Link_Checker_Redirect_Ignore_Patterns
                  Set_Link_Checker_Site_Vanity_Domains
                  Set_Link_Checker_Language
                  Link_Checker_Get_Link_Status
                  Link_Check_Has_Rel_Alternate);
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my ($user_agent, %visited_url_status, %visited_url_hits);
my (%domain_networkscope_map, %domain_alias_map, $firewall_block_pattern);
my ($firewall_user, $firewall_password, @redirect_ignore_patterns);
my (@link_ignore_patterns, %site_vanity_domains);
my (@paths, $this_path, $program_dir, $program_name, $paths);
my (%url_content_language, %url_content_language_hits);
my (%visited_link_object_cache, %visited_url_http_status);
my (%visited_url_http_resp, $results_list_addr, $current_url);
my (%link_check_profile_map, $current_link_check_profile);
my (%site_title_lang_map);

my ($max_redirects) = 10;
my ($debug) = 0;
my ($visited_url_count) = 0;
my ($MAX_visited_url_count)   = 10000;
my ($Clean_visited_url_count) =  7500;
my ($MAXIMUM_CONTENT_SIZE) = 25000000; # approx 25 Mb
my ($url_language_count) = 0;
my ($MAX_url_language_count)   = 10000;
my ($Clean_url_language_count) =  7500;
my ($clf_profile) =  "";
my ($site_title_count) = 0;
my ($MAX_site_title_count)   = 10000;
my ($Clean_site_title_count) =  7500;

my ($link_check_success)          = 0;
my ($link_check_fail)             = 1;
my ($link_check_broken)           = 1;
my ($link_check_cross_language)   = 2;
my ($link_check_bad_networkscope) = 3;
my ($link_check_redirect)         = 4;
my ($link_check_blocked)          = 5;
my ($link_check_broken_anchor)    = 6;
my ($link_check_ipv4_link)        = 7;
my ($link_check_soft_404)         = 8;

#
# String table for error strings.
#
my %string_table_en = (
    "Valid",               "Valid",
    "Broken",              "Broken",
    "Cross language",      "Cross language",
    "Bad networkscope",    "Bad networkscope",
    "Redirect",            "Redirect",
    "Firewall blocked",    "Firewall blocked",
    "Broken anchor",       "Broken anchor",
    "source URL language", " source URL language ",
    "target URL language", " target URL language ",
    "404 not found page with 200 (Ok) code", "404 not found page with 200 (Ok) code", 
    );


#
# String table for error strings (French).
#
my %string_table_fr = (
    "Valid",               "Valide",
    "Broken",              "Brisé",
    "Cross language",      "Interlangues",
    "Bad networkscope",    "Portée de réseau erronée",
    "Redirect",            "Réorienter",
    "Firewall blocked",    "Pare-feu bloqués",
    "Broken anchor",       "Point d'ancrage brisé",
    "source URL language", " la langue source URL ",
    "target URL language", " la langue URL cible ",
    "404 not found page with 200 (Ok) code", "404 page non trouvée avec le code 200 (Ok)", 
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#
# May link check status to the above messages.
#
my (%link_status_message_map) = (
    $link_check_success, "Valid",
    $link_check_broken, "BROKEN",
    $link_check_cross_language, "CROSS_LANGUAGE",
    $link_check_bad_networkscope, "BAD_NETWORKSCOPE",
    $link_check_redirect, "REDIRECT",
    $link_check_blocked, "FIREWALL_BLOCKED",
    $link_check_broken_anchor, "BROKEN_ANCHOR",
    $link_check_ipv4_link, "IPV4_LINK",
    $link_check_soft_404, "SOFT_404",
);

#
# String tables for testcase ID to testcase descriptions
#
my (%testcase_description_en) = (
    "BROKEN",             "Broken link",
    "CROSS_LANGUAGE",     "Cross language link",
    "BAD_NETWORKSCOPE",   "Bad networkscope link",
    "REDIRECT",           "Redirect link",
    "FIREWALL_BLOCKED",   "Firewall blocked link",
    "BROKEN_ANCHOR",      "Broken anchor",
    "IPV4_LINK",          "IPV4 Link",
    "SOFT_404",           "Soft 404 broken link",
);

my (%testcase_description_fr) = (
    "BROKEN",             "Lien brisé",
    "CROSS_LANGUAGE",     "Lien interlangues",
    "BAD_NETWORKSCOPE",   "Lien portée de réseau erronée",
    "REDIRECT",           "Lien réorienter",
    "FIREWALL_BLOCKED",   "Lien pare-feu bloqués",
    "BROKEN_ANCHOR",      "Point d'ancrage brisé",
    "IPV4_LINK",          "Lien IPV4",
    "SOFT_404",           "Soft 404 lien brisé",
);

#
# Default to English testcase descriptions
#
my ($testcase_description) = \%testcase_description_en;

#********************************************************
#
# Name: Link_Checker_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Link_Checker_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;

    #
    # Set debug flag in supporting modules
    #
    Extract_Anchors_Debug($debug);
}

#**********************************************************************
#
# Name: Set_Link_Checker_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Link_Checker_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_Link_Checker_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
        $testcase_description = \%testcase_description_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_Link_Checker_Language, language = English\n" if $debug;
        $string_table = \%string_table_en;
        $testcase_description = \%testcase_description_en;
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
# Name: Link_Checker_Config
#
# Parameters: config_vars
#
# Description:
#
#   This function sets a number of package configuration values.
# The values are passed in as a hash table.
#
#***********************************************************************
sub Link_Checker_Config {
    my (%config_vars) = @_;

    my ($key, $value);

    #
    # Check for known configuration values
    #
    while ( ($key, $value) = each %config_vars ) {
        #
        # Check for known configuration variables
        #
        if ( $key =~ /max_redirects/i ) {
            $max_redirects = $value;
        }
        elsif ( $key =~ /firewall_block_pattern/i ) {
            $firewall_block_pattern = $value;
        }
        elsif ( $key =~ /firewall_user/i ) {
            $firewall_user = $value;
        }
        elsif ( $key =~ /firewall_password/i ) {
            $firewall_password = $value;
        }
    }
}

#***********************************************************************
#
# Name: Set_Link_Checker_Domain_Networkscope_Map
#
# Parameters: local_domain_networkscope_map
#
# Description:
#
#   This function sets the domain networkscope map.  This map provides a
# translation between a domain and its networkscope.
#
#***********************************************************************
sub Set_Link_Checker_Domain_Networkscope_Map {
    my (%local_domain_networkscope_map) = @_;

    #
    # Save domain networkscope map
    #
    %domain_networkscope_map = %local_domain_networkscope_map;

}

#***********************************************************************
#
# Name: Set_Link_Checker_Domain_Alias_Map
#
# Parameters: local_domain_alias_map
#
# Description: 
#   
#   This function sets the domain alias map.  This map provides a
# translation between an alias domain and its primary domain.  This
# allows the crawler to detect URLs that are part of the crawled
# site that use a domain name other than the primary domain (e.g.
# www.pwgsc.gc.ca is an alias for www.tpsgc-pwgsc.gc.ca).
#
#***********************************************************************
sub Set_Link_Checker_Domain_Alias_Map {
    my (%local_domain_alias_map) = @_;

    #
    # Save domain alias map
    #
    %domain_alias_map = %local_domain_alias_map;

}

#***********************************************************************
#
# Name: Set_Link_Checker_Site_Vanity_Domains
#
# Parameters: local_site_vanity_domains
#
# Description: 
#   
#   This function sets the site vanity domain map.  This map provides a
# translation between a site domain and the target site.  This
# allows the the link checker to detect site domains in links and
# not believe they are redirected links (e.g. compensation.pwgsc.gc.ca
# is an alias for www.tpsgc-pwgsc.gc.ca/remuneration-compensation).
#
#***********************************************************************
sub Set_Link_Checker_Site_Vanity_Domains {
    my (%local_site_vanity_domains) = @_;

    #
    # Save domain alias map
    #
    %site_vanity_domains = %local_site_vanity_domains;

}

#***********************************************************************
#
# Name: Set_Link_Checker_Ignore_Patterns
#
# Parameters: local_link_ignore_patterns
#
# Description: 
#   
#   This function sets the list of patterns to ignore when checking
# links.
#
#***********************************************************************
sub Set_Link_Checker_Ignore_Patterns {
    my (@local_link_ignore_patterns) = @_;

    #
    # Save redirect ignore paths
    #
    @link_ignore_patterns = ();
    foreach (@local_link_ignore_patterns) {
        push(@link_ignore_patterns, $_);
    }
}
#***********************************************************************
#
# Name: Set_Link_Checker_Redirect_Ignore_Patterns
#
# Parameters: local_redirect_ignore_patterns
#
# Description: 
#   
#   This function sets the list of patterns to ignore when looking
# for possible redirects.  These would be paths that result in
# redirects that are expected, e.g. language.pl.
#
#***********************************************************************
sub Set_Link_Checker_Redirect_Ignore_Patterns {
    my (@local_redirect_ignore_patterns) = @_;

    #
    # Save redirect ignore patterns
    #
    @redirect_ignore_patterns = ();
        foreach (@local_redirect_ignore_patterns) {
        push(@redirect_ignore_patterns, $_);
    }
}

#***********************************************************************
#
# Name: Set_Link_Check_Test_Profile
#
# Parameters: profile - link check test profile
#             link_checks - hash table of testcase name
#
# Description:
#
#   This function copies the passed table to unit global variables.
# The hash table is indexed by testcase name.
#
#***********************************************************************
sub Set_Link_Check_Test_Profile {
    my ($profile, $link_checks ) = @_;

    my (%local_link_checks);
    my ($key, $value);

    #
    # Make a local copy of the hash table as we will be storing the address
    # of the hash.
    #
    print "Set_Link_Check_Test_Profile, profile = $profile\n" if $debug;
    %local_link_checks = %$link_checks;
    $link_check_profile_map{$profile} = \%local_link_checks;
}

#***********************************************************************
#
# Name: Set_Link_Check_CLF_Profile
#
# Parameters: profile - CLF check test profile
#
# Description:
#
#   This function copies the passed profile name into a unit global
# variable.
#
#***********************************************************************
sub Set_Link_Check_CLF_Profile {
    my ($profile) = @_;

    $clf_profile = $profile;
}

#***********************************************************************
#
# Name: Link_Checker_Set_Proxy
#
# Parameters: proxy
#
# Description:
#
#   This function sets or clears the proxy server value for the user
# agent.
#
#***********************************************************************
sub Link_Checker_Set_Proxy {
    my ($proxy) = @_;

    #
    # Create user agent
    #
    if ( ! defined($user_agent) ) {
        $user_agent = Crawler_Get_User_Agent();
    }

    #
    # Add proxy setting if we have one.
    #
    Crawler_Set_Proxy($proxy);
}

#***********************************************************************
#
# Name: Initialize_Link_Checker_Variables
#
# Parameters: profile - link check test profile
#             list_addr - address of results list
#
# Description:
#
#   This function initializes the test case results table.
#
#***********************************************************************
sub Initialize_Link_Checker_Variables {
    my ($profile, $list_addr) = @_;

    #
    # Save results list address in a global variable
    #
    $results_list_addr = $list_addr;
    $current_link_check_profile = $link_check_profile_map{$profile};

    #
    # Create user agent
    #
    if ( ! defined($user_agent) ) {
        $user_agent = Crawler_Get_User_Agent();
    }
}

#***********************************************************************
#
# Name: Redirected_To_New_Site
#
# Parameters: domain - domain of original URL
#             file_path - file path of original URL
#             url - new URL
#
# Description:
#
#   This function checks to see of the new URL is a new site redirect
# for the original domain & file path.  If the domain of the new URL
# is not an alias of the original domain, the redirect is to a new site.
# If the file paths are different it is a redirect to a new site.
#
# Returns:
#  1 - URL is a from a new site
#  0 - URL is not from a new site or redirects are ignored for this URL
#      (e.g. go.pl)
#
#***********************************************************************
sub Redirected_To_New_Site {
    my ($domain, $file_path, $url) = @_;

    my ($protocol, $new_domain, $new_file_path, $query, $new_url);
    my ($domain_minus_www, $new_domain_minus_www);
    my ($rc) = 0;

    #
    # Get the domain and file path components from the new URL
    #
    ($protocol, $new_domain, $new_file_path, $query, $new_url) = 
        URL_Check_Parse_URL($url);

    #
    # Did we get a domain ?
    #
    if ( $new_domain eq "" ) {
        return(0);
    }

    #
    # Add query to the end of the file path
    #
    $new_file_path .= $query;
    print "Redirected_To_New_Site old: $domain, $file_path\n" if $debug;
    print "                       new: $new_domain, $new_file_path\n" if $debug;

    #
    # Does file path match a redirect ignore path (e.g. language.pl) ?
    #
    if ( Link_Matches_Ignore_Pattern($file_path, @redirect_ignore_patterns) ) {
        print "Matches redirect ignore path, skip redirect checking\n" if $debug;
        return(0);
    }

    #
    # Was there a change in domain name ?
    #
    if ( $new_domain ne $domain ) {
        #
        # Remove any possible leading www. from the domain names.
        # Domains are equivalent if they one has www. and the other doesn't
        #
        $domain_minus_www = $domain;
        $domain_minus_www =~ s/^www\.//g;
        $new_domain_minus_www = $new_domain;
        $new_domain_minus_www =~ s/^www\.//g;

        #
        # Do we have a site vanity domain ?
        #
        if ( defined($site_vanity_domains{$domain}) ) {
            #
            # Site vanity domain, the file path portion of the URL
            # is allowed to change, so return from here stating it is
            # not a new site redirect.
            #
            print "Found site vanity domain $domain\n" if $debug;
            return(0);
        }
        #
        # Do the domains differ by the presence of a leading www ?
        # (e.g. www.tpsgc-pwgsc.gc.ca vs tpsgc-pwgsc.gc.ca)
        #
        elsif ( $domain_minus_www eq $new_domain_minus_www ) {
            print "Found www vs non-www version of domain\n" if $debug;
            return(0);
        }
        #
        # Is the original domain an alias for the new domain ?
        #
        elsif ( ! defined($domain_alias_map{$domain}) ||
             ($domain_alias_map{$domain} ne $new_domain) ) {
            #
            # Original domain is not an alias of the new domain. This
            # is a redirect to a new site.
            #
            print "New domain $new_domain is NOT alias of old domain $domain\n" if $debug;
            $rc = 1;
        }
        else {
            print "New domain $new_domain is an alias of old domain $domain\n" if $debug;
        }
    }

    #
    # If we passed the domain check, look at the file path
    #
    if ( $rc == 0 ) {
        #
        # Is the new path simply the old path plus a trailing / ?
        #
        if ( $new_file_path eq "$file_path/" ) {
            print "Old path plus trailing /\n" if $debug;
        }

        #
        # Are the file paths the same ?
        #
        elsif ( $new_file_path ne $file_path ) {
            #
            # File paths are different, this is a redirect to a
            # new site/subsite.
            #
            $rc = 1;
            print "New file path\n Old: \"$file_path\"\n New: \"$new_file_path\"\n" if $debug;
        }
        else {
            #
            # Same file path, not a site redirect
            #
            print "No change in file path\n" if $debug;
        }
    }

    #
    # Return status
    #
    return($rc);
}

#***********************************************************************
#
# Name: Get_URL_Title
#
# Parameters: url - URL
#             link - pointer to a link object
#             resp - HTTP::Response object
#
# Description:
#
#   This function gets the title of the URL and stores it in the link object.
#
#***********************************************************************
sub Get_URL_Title {
    my ($url, $link, $resp) = @_;

    my ($metadata_object, %metadata, $header, %pdf_properties);
    my ($title, $status);
    
    #
    # Get response header, it tells us the content type
    #
    $header = $resp->headers;
    print "Get_URL_Title, Content type = " . $header->content_type . "\n" if $debug;

    #
    # Get the title of the target URL, it will be used later in
    # Interoperability checking.
    #
    if ( $header->content_type =~ /text\/html/ ) {
        print "Extract metadata from HTML content\n" if $debug;
        %metadata = Extract_Metadata($url, Crawler_Decode_Content($resp));

        #
        # Get title, if one was found
        #
        if ( defined($metadata{"title"}) ) {
            $metadata_object = $metadata{"title"};
            $title = $metadata_object->content;
        }
    }
    elsif ( $header->content_type =~ /application\/pdf/ ) {
        print "Extract properties from PDF content\n" if $debug;
        ($status, %pdf_properties) = PDF_Files_Get_Properties_From_Content(Crawler_Decode_Content($resp));

        #
        # Get Title property, if there was one.
        #
        if ( $status && defined($pdf_properties{"Title"}) ) {
            $title = $pdf_properties{"Title"};
        }
    }

    #
    # Set link object url_title attribute.
    #
    if ( defined($title) ) {
        print "Set URL title to $title\n" if $debug;
        $link->url_title($title);
    }
}

#***********************************************************************
#
# Name: Link_Check_Site_Titles
#
# Parameters: domain - site domain name
#
# Description:
#
#   This function returns a list of site titles for the supplied domain.
# The returned list is in the form of a hash table, indexed by language.
#
#***********************************************************************
sub Link_Check_Site_Titles {
    my ($domain) = @_;

    my (%site_titles, $site_title_addr);

    #
    # Do we have a site title set for this domain ?
    #
    print "Link_Check_Site_Titles, domain = $domain\n" if $debug;
    if ( ($domain ne "") && defined($site_title_lang_map{$domain}) ) {
        $site_title_addr = $site_title_lang_map{$domain};
        %site_titles = %$site_title_addr;
    }

    #
    # Return the list of titles
    #
    return(%site_titles);
}

#***********************************************************************
#
# Name: Get_Site_Title
#
# Parameters: url - URL
#             resp - HTTP::Response object
#             lang - language of content
#
# Description:
#
#   This function gets the site title of the URL.  It attempts to extract
# the site title from the site banner portion of the content (provided
# the URL uses the GC Usability layout).
#
#***********************************************************************
sub Get_Site_Title {
    my ($url, $resp, $lang) = @_;

    my ($protocol, $domain, $new_url, $file_path, $query, $list_addr);
    my ($site_title_addr, %site_title_hash, $base, %link_sets, $header);
    my ($this_link, @links, $content, $mime_type);

    #
    # Get the domain name of the URL
    #
    ($protocol, $domain, $file_path, $query, $new_url) =
            URL_Check_Parse_URL($url);

    #
    # Do we already have a site title for this domain ?
    #
    print "Get_Site_Title, domain = $domain, language = $lang\n" if $debug;
    if ( ($domain ne "") && defined($site_title_lang_map{$domain}) ) {
        $site_title_addr = $site_title_lang_map{$domain};
    }
    elsif ( $domain ne "" ) {
        #
        # Create a domain site title map entry
        #
        $site_title_lang_map{$domain} = \%site_title_hash;
        $site_title_addr = $site_title_lang_map{$domain};
    }
    else {
        #
        # No domain
        #
        print "No domain found in URL $url\n" if $debug;
        return;
    }

    #
    # Ae we missing a site title for this language ?
    #
    if ( ! defined($$site_title_addr{$lang}) ) {
        #
        # Determine the abse URL for any relative URLs.  Usually this is
        # the base field from the HTTP Response object (Location field
        # in HTTP packet).  If the response code is 200 (OK), we don't use the
        # the base field in case the Location field is set (which it should
        # not be).
        #
        if ( $resp->code == 200 ) {
            $base = $url;
        }
        else {
            $base = $resp->base;
        }

        #
        # Extract links from the page
        #
        $header = $resp->headers;
        $mime_type = $header->content_type;
        #$content = Crawler_Decode_Content($resp);
        print "Extract links from document\n  --> $url\n" if $debug;
        @links = Extract_Links($url, $base, $lang, $mime_type, Crawler_Decode_Content($resp));

        #
        # Get all the links, this includes any Site Banner links.
        # The Site Banner link's text is the site name.
        #
        %link_sets = Extract_Links_Subsection_Links("ALL");
        if ( defined($link_sets{"SITE_BANNER"}) ) {
            $list_addr = $link_sets{"SITE_BANNER"};
        
            #
            # Get the first anchor link in the banner portion
            #
            foreach $this_link (@$list_addr) {
                #
                # Is this an anchor link ?
                #
                if ( $this_link->link_type eq "a" ) {
                    #
                    # The anchor text is the site title
                    #
                    $$site_title_addr{$lang} = $this_link->anchor;
                    print "Site title is " . $this_link->anchor . "\n" if $debug;
                }
            }

            #
            # Did we set the site title ?
            #
            if ( ! defined($$site_title_addr{$lang}) ) {
                #
                # No links, cannot set the site title
                #
                print "No links in site banner\n" if $debug;
            }
        }
        else {
            #
            # No site banner links
            #
            print "No site banner section links\n" if $debug;
        }
    }
    else {
        #
        # We already have the site title.
        #
        print "Existing Site title for $domain in language $lang is " .
              $$site_title_addr{$lang} . "\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Link_Status
#
# Parameters: referer_url - the refering URL
#             this_link - URL to check
#             link - pointer to a link object
#
# Description:
#
#   This function tries to GET the passed URL in order to determine
# whether or not it is a valid link. It returns the link status 
# (broken link or not) and whether or not the link gets
# redirected and whether or not it is blocked by the firewall.
#
#***********************************************************************
sub Link_Status {
    my ($referer_url, $this_link, $link) = @_;

    my ($is_broken_link, $is_redirected_link, $req, $resp, $header);
    my ($domain, $file_path, $url, $is_firewall_blocked);
    my ($protocol, $query, $new_url, $redirect_dir, $lang);
    my ($redirect_protocol, $redirect_domain, $redirect_file_path, $redirect_query);
    my ($redirect_count) = 0;
    my ($done) = 0;

    #
    # Create user agent
    #
    if ( ! defined($user_agent) ) {
        $user_agent = Crawler_Get_User_Agent();
    }

    #
    # Do any necessary URL encoding to convert special characters to URL
    # safe characters.
    #
    $this_link =~ s/,/%2C/g;
    $this_link =~ s/ /%20/g;

    #
    # Get the domain and file path components from the new URL
    #
    ($protocol, $domain, $file_path, $query, $new_url) = 
        URL_Check_Parse_URL($this_link);
    $redirect_dir = dirname($file_path);
    if ( $redirect_dir eq "." ) {
        $redirect_dir = "";
    }

    #
    # Did we get all the components ?
    #
    if ( ! defined($domain) ) {
        $domain = "";
    }
    if ( ! defined($file_path) ) {
        $file_path = "";
    }
    print "Link_Status: $this_link\n" if $debug;
    print "             $domain, $file_path\n" if $debug;
    print "  redirect_dir = $redirect_dir\n" if $debug;
    $redirect_protocol = $protocol;
    $redirect_domain = $domain;

    #
    # Attempt to GET the link, keep redirects under the limit
    #
    $is_redirected_link = 0;
    $is_firewall_blocked = 0;
    $url = $this_link;
    print "GET url = $url, Referrer = $referer_url\n" if $debug;
    while ( ! $done ) {
        #
        # Get URL
        #
        print "Redirect # $redirect_count, url = $url\n" if $debug;
        print "GET $url\n" if $debug;
        $req = new HTTP::Request( GET => $url );
        $req->header(Accept => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
        $req->referrer("$referer_url");
        $user_agent->prepare_request($req);

        #
        # Perform a simple request, this prevents automatic redirecting
        #
        print "Request = " . $req->as_string . "\n" if $debug;
        $resp = $user_agent->simple_request($req);
        print "Response code = " . $resp->code . "\n" if $debug;
        $header = $resp->headers;
        print "Response header = " . $header->as_string . "\n" if $debug;

        #
        # Check for a 401 (Not Authorized) response code
        #
        if ( $resp->code == 401 ) {
            #
            # Set firewall credentials and try get again
            #
            print "Got 401, add firewall credentials\n" if $debug;

            #
            # Set firewall credentials
            #
            if ( defined($firewall_user) ) {
                $req->authorization_basic($firewall_user, $firewall_password);
                $user_agent->prepare_request($req);
                $resp = $user_agent->simple_request($req);
                print "Response code after firewall credentials = " . 
                      $resp->code . "\n" if $debug;
            }
        }

        #
        # Was the request forbidden by robots (status code = 403) ?
        #
        if ( (!$resp->is_success) && ($resp->code == 403) ) {
            print "Forbidden by robots, try GET after clearing robots\n" if $debug;
            ($url, $resp) = Crawler_Get_HTTP_Response($url, $referer_url);
        }

        #
        # Check for success on GET operation
        #   
        if ( !$resp->is_success ) {
            #
            # Is there a redirect ?
            #
            if ( $resp->is_redirect ) {
                #
                # Get new target for redirect
                $redirect_count++;
                $header = $resp->headers;
                $url = $header->header("Location");

                #
                # Does URL have a leading http ? 
                # 
                if ( ! ($url =~ /^http/) ) {
                    #
                    # If we have a leading //, use protocol from
                    # previous request.
                    #
                    if ( $url =~ /^\/\// ) {
                        print "Add protocol to received URL\n" if $debug;
                        $url = "$redirect_protocol$url";
                    }
                    #
                    # Check for leading /
                    #
                    elsif ( $url =~ /^\// ) {
                        #
                        # Add protocol and domain from previous request.
                        #
                        print "Add protocol & domain to received URL\n" if $debug;
                        $url = "$redirect_protocol//$redirect_domain$url";
                    }
                    else {
                        #
                        # Add protocol, domain and directory from
                        # previous request.
                        #
                        print "Add protocol, domain & directory to received URL\n" if $debug;
                        if ( $redirect_dir ne "" ) {
                            $url = "$redirect_protocol//$redirect_domain/$redirect_dir/$url";
                        }
                        else {
                            $url = "$redirect_protocol//$redirect_domain/$url";
                        }

                    }
                }
                print "Redirect to \"$url\"\n" if $debug;

                #
                # Get components of redirected URL
                #
                ($redirect_protocol, $redirect_domain, $redirect_file_path, $redirect_query, $new_url) = 
                    URL_Check_Parse_URL($url);
                $redirect_dir = dirname($redirect_file_path);
                if ( $redirect_dir eq "." ) {
                    $redirect_dir = "";
                }

                #
                # Is redirect URL valid ?
                #
                if ( $redirect_domain eq "" ) {
                    $done = 1;
                    print "No domain in redirect\n" if $debug;
                }

                #
                # Have we seen too many redirects ?
                #
                elsif ( $redirect_count >= $max_redirects ) {
                    $done = 1;
                    print "Aborting GET, too many redirects\n" if $debug;
                }

                #
                # Check new URL to see if we are redirected to the
                # firewall blockage page.
                #
                elsif ( defined($firewall_block_pattern) &&
                        ($resp->code == 302) &&
                        ($url =~ /$firewall_block_pattern/) ) {
                    print "Redirected to firewall block page $url\n" if $debug;
                    $is_firewall_blocked = 1;
                    $done = 1;
                }

                #
                # Check new URL to see if we are just redirecting the domain
                # portion from an alias to the primary domain or are
                # we redirecting to a new site. We only have to check
                # if it is a 301 (Moved Permanently) code.  If it is a
                # 302 (Moved temporarily) we can ignore it for now.
                #
                elsif ( ($resp->code == 301) &&
                     Redirected_To_New_Site($domain, $file_path, $url) ) {
                    $is_redirected_link = 1;
                }
            }

            #
            # Check for a 403 (Forbidden by robots) response code
            #
            elsif ( $resp->code == 403 ) {
                $done = 1;
                print "Forbidden by robots\n" if $debug;
            }
            #
            # Check for a 404 (Not Found) response code
            #
            elsif ( $resp->code == 404 ) {
                #
                # Broken link
                #
                $is_broken_link = 1;
                $done = 1;
                print "Broken link\n" if $debug;
            }
            else {
                #
                # Some other response code (e.g. 500 - Server Error).
                # Ignore it as we don't know if it is broken or not.
                #
                print "Error in GET, code = " . $resp->code . "\n" if $debug;
                $done = 1;
            }     
        }
        else {
            #
            # GET was successful
            #
            print "GET successful of $url\n" if $debug;

            #
            # Get the title of the target URL, it will be used later in
            # Interoperability checking.
            #
            Get_URL_Title($url, $link, $resp);

            #
            # We will want to check the language of the content
            # in a later check.  Since we already have the content here
            # we will determine its language so the value can be cached.
            # This will save a 2nd GET operation on this URL.
            #
            $lang = Get_Content_Language($url, $referer_url, $resp);
            
            #
            # Did we get a language ? If so try to get the site title.
            #
            if ( $lang ne "" ) {
                Get_Site_Title($url, $resp, $lang);
            }

            #
            # Set done flag to exit loop
            #
            $done = 1;
        }
    }
    print "GET url response = $url, Referrer = $referer_url\n" if $debug;

    #
    # Return status values
    #
    return($is_broken_link, $is_redirected_link, $is_firewall_blocked, $url,
           $resp);
}

#***********************************************************************
#
# Name: Clean_URL_Content_Language_List
#
# Parameters: none
#
# Description:
#
#   This function updates the global url language hash tables.  It
# goes through the tables, removing URLs with the lowest hit
# count, until there is sufficient room for new URL additions.
#
# Returns:
#   Nothing
#
#***********************************************************************
sub Clean_URL_Content_Language_List {
    my ( $url, $hits );
    my ($current_hit_count) = 1;

    #
    # Loop until the URL count is below the threshold
    #
    while ( $url_language_count > $Clean_url_language_count ) {

        #
        # Loop through the URL list looking for URLs with a hit count
        # less than or equal to the current hit count
        #
        while ( ( $url, $hits ) = each %url_content_language ) {
            if ( $hits <= $current_hit_count ) {

                #
                # Remove this URL from the hash tables and decrement the
                # number of URLs in the list.
                #
                delete $url_content_language{$url};
                delete $url_content_language_hits{$url};
            }
        }

        #
        # Increment the hit counter for the next pass
        #
        $current_hit_count++;
        $url_language_count = keys(%url_content_language);
    }
}

#***********************************************************************
#
# Name: Get_Content_Language
#
# Parameters: this_link - URL to check
#             referer_url - url of refering link
#             resp - optional HTTP::Response object
#
# Description:
#
#   This function trys to  determine the language of the content.
# If no content is provided, it will GET the URL to get the content.
#
# Returns:
#   language type
#
#***********************************************************************
sub Get_Content_Language {
    my ($this_link, $referer_url, $resp) = @_;

    my ($req, $content, $lang, $resp_url, $status);
    my ($lang_code) = "";;

    #
    # Remove any named anchors from the URL, this avoids getting
    # the same link for each named anchor
    #
    $this_link =~ s/#.*//g;

    #
    # Have we seen this URL before ?
    #
    print "Get_Content_Language url = $this_link\n" if $debug;
    if ( ! defined($url_content_language{$this_link}) ) {
        #
        # A URL we have not seen yet.  Before we get its
        # language, check the number of checked URLs to see that
        # we don't have too many.  If we do we must clean up
        # the hash table to control our memory usage.
        #
        if ( $url_language_count > $MAX_url_language_count ) {
            Clean_URL_Content_Language_List;
        }

        #
        # Get URL
        #
        if ( ! defined($resp) ) {
            ($resp_url, $resp) = Crawler_Get_HTTP_Response($this_link,
                                                           $referer_url);
        }
        else {
            #
            # Already have the resp object.
            #
            $resp_url = $this_link;
        }

        #
        # Was the GET successful ?
        #
        if ( defined($resp) && ($resp->is_success) ) {
            #
            # Check for UTF-8 content
            #
            $content = Crawler_Decode_Content($resp);

            #
            # Is content text/html ?
            #
            print "Content type = " . $resp->content_type . "\n" if $debug;
            if ( $resp->content_type =~ /text\/html/ ) {
                #
                # Determine language of HTML page
                #
                ($lang_code, $lang, $status) = TextCat_HTML_Language($content);
            }

            #
            # Is content text/plain ?
            #
            elsif ( $resp->content_type =~ /text\/plain/ ) {
                #
                # Determine language of text page
                #
                ($lang_code, $lang, $status) = TextCat_Text_Language($content);
            }

            #
            # Is content application/pdf ?
            #
            elsif ( $resp->content_type =~ /application\/pdf/ ) {
                #
                # Extract text from PDF document
                #
                $content = PDF_Files_PDF_Content_To_Text($content);

                #
                # Determine language of PDF page
                #
                ($lang_code, $lang, $status) = TextCat_Text_Language($content);
            }
            else {
                #
                # Document type we can't handle, set language to unknown
                #
                $lang = "unknown";
                $lang_code = "";
            }

            #
            # Save language in global hash table for easy access.
            #
            $url_content_language{$resp_url} = $lang_code;
            $url_content_language_hits{$resp_url} = 1;

            #
            # If the response URL is not the same as the original URL,
            # save the language code under the original one also.
            #
            if ( $this_link ne $resp_url ) {
                $url_content_language{$this_link} = $lang_code;
                $url_content_language_hits{$this_link} = 1;
            }
        }
        else {
            print "Failed to get URL in language check\n" if $debug;
        }
    }
    else {
        #
        # Already retrieved this URL, get language and increment hit count
        #
        $lang_code = $url_content_language{$this_link};
        $url_content_language_hits{$this_link}++;
    }

    #
    # Return language
    #
    print "Get_Content_Language: language = $lang_code\n" if $debug;
    return($lang_code);
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
    # Create result object and save details
    #
    if ( defined($testcase) && (defined($$current_link_check_profile{$testcase}))) {
        $result_object = tqa_result_object->new($testcase, $link_check_fail,
                                                $$testcase_description{$testcase},
                                                $line, $column, $text,
                                                $error_string, $current_url);
        push (@$results_list_addr, $result_object);

        #
        # Print error string to stdout
        #
        print "$testcase : $error_string\n" if $debug;
    }
}

#***********************************************************************
#
# Name: Cross_Language_Link
#
# Parameters: this_link - URL to check
#             link_anchor - link anchor text
#             referer_url - url of refering link
#             language - language of referrer URL
#             link - link result object
#             resp - HTTP::Response object
#
# Description:
#
#   This function checks the language of the specified link against
# the language of the referer URL.  The link language is determined
# from the file name.
#
# Returns:
#   0 - no link violation
#   1 - link violation
#
#***********************************************************************
sub Cross_Language_Link {
    my ($this_link, $link_anchor, $language, $referer_url, $link, $resp) = @_;

    my ($rc, $link_language);

    #
    # Do we have a language value for the referer ?
    #
    if ( $language ne "" ) {
        #
        # Get the language of the content of the document referenced by the
        # link.
        #
        $link_language = Get_Content_Language($this_link, $referer_url,
                                              $resp);

        #
        # If the language of the content cannot be determined,
        # get language from the URL (e.g. -eng.html)
        #
        if ( $link_language eq "" ) {
            $link_language = URL_Check_GET_URL_Language($this_link);
        }
        print "Cross_Language_Link referer language = $language, link language = $link_language, anchor = $link_anchor\n" if $debug;

        #
        # If the link language is known and does not match the referer
        # language, we may have a violation
        #
        if ( ($link_language ne "") && 
             ($link_language ne $language) ) {

            #
            # Languages don't match, do we have anchor text for the link ?
            #
            if ( ! defined($link_anchor) ) {
                #
                # Language mismatch
                #
                $rc = 1;
            }
            #
            # Check the anchor text, if the text is one of
            # English, Francais, Espanol, Portugues, Nederlands or Italiano 
            # then assume this is the language switch button.
            #
            elsif ( ( $link_anchor =~ /english/i ) ||
                    ( $link_anchor =~ /français/i ) || 
                    ( $link_anchor =~ /fran?ais/i ) || 
                    ( $link_anchor =~ /Fran&ccedil;ais/i ) ||
                    ( $link_anchor =~ /español/i ) || 
                    ( $link_anchor =~ /espa?ol/i ) || 
                    ( $link_anchor =~ /espa&ntilde;ol/i ) || 
                    ( $link_anchor =~ /Italiano/i ) || 
                    ( $link_anchor =~ /Nederlands/i ) || 
                    ( $link_anchor =~ /português/i ) || 
                    ( $link_anchor =~ /portugu?s/i ) || 
                    ( $link_anchor =~ /portugu&ecirc;s/i ) ) {
                #
                # Valid cross language link
                #
                print "Cross_Language_Link: Language switching link $link_anchor\n" if $debug;
                $rc = 0;
            }
            else {
                #
                # Language mismatch
                #
                $rc = 1;
            }
        }
        else {
            #
            # Either link language is unknown or the languages match.
            #
            $rc = 0;
        }
    }
    else {
        #
        # We don't know the language of the referer, so the link
        # can be in any language.
        #
        $rc = 0;
        $link_language = "";
    }

    #
    # If there is a cross language link, include languages in the
    # testcase message.
    #
    if ( $rc == 1 ) {
        Record_Result("CROSS_LANGUAGE", $link->line_no, $link->column_no,
                      $link->source_line,
                      "href= " . $link->href . "\n" .
                      String_Value("source URL language") . "'$language'" .
                      String_Value("target URL language") . "'$link_language'");
    }

    #
    # Return status of check
    #
    print "Cross_Language_Link: rc = $rc, referer language = $language, link language = $link_language\n" if $debug;
    return($rc);
}

#***********************************************************************
#
# Name: Bad_Networkscope_Link
#
# Parameters: referer_networkscope - the refering URL networkscope
#             this_link - URL to check
#
# Description:
#
#   This function checks the networkscope of both the referer and
# the target link.  If the networkscope of the target link is less
# than the referer it is a bad networkscope link.
#
# Returns:
#   0 - no link violation
#   1 - link violation
#
#***********************************************************************
sub Bad_Networkscope_Link {
    my ($referer_networkscope, $this_link) = @_;

    my ($rc, $protocol, $domain, $file_path, $query, $new_url);

    #
    # Get the domain and file path components from the URL
    #
    ($protocol, $domain, $file_path, $query, $new_url) =
        URL_Check_Parse_URL($this_link);

    #
    # Do we have a networkscope value for this domain ?
    # and is it less than that for the referer ?
    #
    if ( (defined($domain_networkscope_map{$domain})) &&
         ($domain_networkscope_map{$domain} < $referer_networkscope) ) {
        #
        # Bad networkscope
        #
        $rc = 1;
    }
    else {
        #
        # Either networkscope is not defined or it is not
        # less than the referer's value.
        #
        $rc = 0;
    }

    #
    # Return status
    #
    return($rc);
}

#***********************************************************************
#
# Name: Link_Matches_Ignore_Pattern
#
# Parameters: this_link - URL of link to check
#             patterns - list of patterns
#
# Description:
#
#   This function checks to see if this URL matches any of the
# ignore patterns.
#
# Returns:
#   1 - Link matches ignore pattern
#   0 - Link does not match ignore patterns
#
#***********************************************************************
sub Link_Matches_Ignore_Pattern {
    my ($this_link, @patterns) = @_;

    my ($link_pattern);

    #
    # Check each ignore pattern
    #
    foreach $link_pattern (@patterns) {
        if ( index($this_link, $link_pattern) >= 0 ) {

            #
            # Found a match, return TRUE
            #
            print "Matches ignore pattern: $link_pattern\n"
              if $debug;
            return 1;
        }
    }

    #
    # If we got here the URL failed all pattern matches
    #
    print "Does not match ignore patterns\n" if $debug;
    return 0;
}

#***********************************************************************
#
# Name: Clean_Visited_URL_List
#
# Parameters: none
#
# Description:
#
#   This function updates the global visited url hash tables.  It
# goes through the tables, removing URLs with the lowest hit
# count, until there is sufficient room for new URL additions.
#
# Returns:
#   Nothing
#
#***********************************************************************
sub Clean_Visited_URL_List {
    my ( $url, $hits );
    my ($current_hit_count) = 1;

    #
    # Loop until the URL count is below the threshold
    #
    while ( $visited_url_count > $Clean_visited_url_count ) {

        #
        # Loop through the URL list looking for URLs with a hit count
        # less than or equal to the current hit count
        #
        while ( ( $url, $hits ) = each %visited_url_hits ) {
            if ( $hits <= $current_hit_count ) {

                #
                # Remove this URL from the hash tables and decrement the
                # number of URLs in the list.
                #
                delete $visited_url_hits{$url};
                delete $visited_url_status{$url};
                delete $visited_url_http_status{$url};
                delete $visited_url_http_resp{$url};
                delete $visited_link_object_cache{$url};
            }
        }

        #
        # Increment the hit counter for the next pass
        #
        $current_hit_count++;
        $visited_url_count = keys(%visited_url_hits);
    }
}

#***********************************************************************
#
# Name: Anchor_In_HTML
#
# Parameters: resp - HTTP::Response object
#             url - URL of link target
#             anchor - name of anchor
#
# Description:
#
#   This function checks to see if the named anchor appears in the
# specified HTML document.  It checks to see if the anchors have already
# been retrieved, and if not it extracts them from the content.  The
# HTTP::Response object supplied is that from a GET of the link's URL.
# 
# Returns:
#   1 - anchor is in HTML document
#   0 - anchor is not in HTML document
#
#***********************************************************************
sub Anchor_In_HTML {
    my ($resp, $url, $anchor) = @_;

    my ($anchor_found) = 1;
    my ($content, $header, $anchor_list);

    #
    # Is this HTML content ?
    #
    print "Anchor_In_HTML: Check for $anchor in $url\n" if $debug;
    $header = $resp->headers;
    if ( $header->content_type =~ /text\/html/ ) {
        #
        # Check for UTF-8 content
        #
        $content = Crawler_Decode_Content($resp);

        #
        # Check to see if this anchor is in the list of anchors in the
        # document.
        #
        $anchor_list = Extract_Anchors($url, $content);
        $anchor =~ s/^.*#//g;
        if ( ($anchor ne "" ) &&
             (index($anchor_list, " $anchor ") == -1) ) {
            #
            # Anchor not found in document
            #
            print "Anchor \"$anchor\" not found\n" if $debug;
            print "List of anchors is $anchor_list\n" if $debug;
            $anchor_found = 0;
        }
        else {
            print "Anchor \"$anchor\" found\n" if $debug;
        }
    }
    else {
        #
        # Not text/html content, return success.
        #
        print "Not text/html content " . $header->content_type . "\n" if $debug;
    }

    #
    # Return anchor found status
    #
    return($anchor_found);
}

#***********************************************************************
#
# Name: Link_Checker_Get_Link_Status
#
# Parameters: referrer_url - URL of document containing link
#             link - pointer to a link object
#
# Description:
#
#   This function checks gets the status of a link and records
# some link details (e.g. target document mime-type).
#
#***********************************************************************
sub Link_Checker_Get_Link_Status {
    my ( $referrer_url, $link ) = @_;

    my ($this_link, $is_broken_link, $is_redirected_link, $request_url );
    my ($is_firewall_blocked, $resp, $header, $cache_link, $resp_url);
    my ($title);

    #
    # Get absolute URL for link.
    #
    $this_link = $link->abs_url;
    print "Link_Checker_Get_Link_Status: URL $this_link\n" if $debug;
    
    #
    # Initialise link status to broken, it will be corrected later
    #
    $link->link_status($link_check_broken);

    #
    # Is this an empty link ? (no href value)
    #
    if ( $this_link =~ /^\s*$/ ) {
        print "Skip empty href\n" if $debug;
        return($link, $resp);
    }
    #
    # If this is a mailto link, ignore it.
    #
    elsif ( $this_link =~ /^mailto:/ ) {
        print "Ignore mailto link\n" if $debug;
        return($link, $resp);
    }
    #
    # Does the URL have a leading http for file ?
    # If not it may be a JavaScript link, which we ignore
    #
    elsif ( ! (($this_link =~ /^http[s]?:/i) || ($this_link =~ /^file:/i)) ) {
        print "Skip non http or file: link\n" if $debug;
        return($link, $resp);
    }
    #
    # Does this link match any of the link ignore patterns ?
    #
    elsif ( Link_Matches_Ignore_Pattern($this_link,
                                        @link_ignore_patterns) ) {
        return($link, $resp);
    }

    #
    # Is this a new link, one that we have not seen before ?
    #
    if ( ! defined($visited_url_status{$this_link}) ) {
        #
        # Check to see if there is a named anchor on the URL.  We can
        # remove it as the HTTP status is the same whether the anchor
        # is included or not.  This saves trying to GET <url>#andchor1
        # and <url>#anchor2 (1 get versus 2).
        #
        $request_url = $this_link;
        if ( defined($link->query) && ($link->query =~ /#/) ) {
            $request_url =~ s/#.*//g;
        }

        #
        # A URL we have not seen yet.  Before we record its
        # status, check the number of visited URLs to see that
        # we don't have too many.  If we do we must clean up
        # the hash table to control our memory usage.
        #
        if ( $visited_url_count > $MAX_visited_url_count ) {
            Clean_Visited_URL_List;
        }

        #
        # Have we seen this URL before (it may be different than
        # the one we checked earlier).
        #
        if ( ! defined($visited_url_http_status{$request_url}) ) {
            #
            # Get link status
            #
            print "Get link $request_url\n" if $debug;
            ($is_broken_link, $is_redirected_link, $is_firewall_blocked,
             $resp_url, $resp) = Link_Status($referrer_url, $request_url, $link);

            #
            # If the link is valid, save the mime type and length
            # of the content
            #
            if ( $resp->is_success ) {
                $header = $resp->headers;
                $link->mime_type($header->content_type);
                if ( defined($header->content_length) ) {
                    $link->content_length($header->content_length);
                }
                else {
                    $link->content_length(length($resp->content));
                }
                print "Target URL length " . $link->content_length . "\n" if $debug;

                #
                # If the mime type is text/html, check to see if the 
                # target document is archived on the web.
                #
                if ( $header->content_type =~ /text\/html/ ) {
                    $link->is_archived(CLF_Check_Is_Archived($clf_profile,
                                                             $request_url,
                                                             $resp->content));
                }
            }

            #
            # Check for broken link
            #
            $visited_url_http_status{$request_url} = $link_check_success;
            $visited_url_http_resp{$request_url} = $resp;
            if ( $is_broken_link ) {
                $visited_url_status{$this_link} = $link_check_broken;
                $visited_url_http_status{$request_url} = $link_check_broken;
            }

            #
            # Check for a firewall blocked link
            #
            elsif ( $is_firewall_blocked ) {
                $visited_url_status{$this_link} = $link_check_blocked;
                $visited_url_http_status{$request_url} = $link_check_blocked;
            }

            #
            # Check for a redirected link
            #
            elsif ( $is_redirected_link ) {
                $visited_url_status{$this_link} = $link_check_redirect;
                $visited_url_http_status{$request_url} = $link_check_redirect;
            }
            #
            # Check for soft 404 page, a page whose content looks like
            # a 404 Not Found page but with a 200(Ok) status code
            #
            else {
                #
                # Look for 404 type of message in title
                #
                $title =  $link->url_title;
                if ( ($title =~ /Error 404/i) ||
                     ($title =~ /Erreur 404/i) ||
                     ($title =~ /Page Not Found/i) ||
                     ($title =~ /Page non trouv/i) ) {
                    #
                    # Looks like a 404 error message page
                    #
                    print "Soft 404 page found\n" if $debug;
                    $visited_url_status{$this_link} = $link_check_soft_404;
                    $visited_url_http_status{$request_url} = $link_check_soft_404;
                }
            }
        }
        else {
            #
            # Use cached HTTP table status
            #
            $visited_url_status{$this_link} =
                $visited_url_http_status{$request_url};
            $resp = $visited_url_http_resp{$request_url};
            $resp_url = $request_url;
            print "Use cached URL HTTP status " . $visited_url_status{$this_link} . "\n" if $debug;
        }

        #
        # If we don't already have a status or if status is
        # success, perform other checks (e.g. anchors)
        #
        if ( (! defined($visited_url_status{$this_link}) ) ||
             ($visited_url_status{$this_link} == $link_check_success) ||
             ($visited_url_status{$this_link} == $link_check_broken_anchor) ) {
            #
            # Now check to see if there is a named anchor in the
            # URL (e.g. http://domain/document.html#section.
            # If the document exists but the anchor does not, the
            # GET operation is still a success (browser places
            # user at the top of the document).
            #
            if ( defined($link->query) && ($link->query =~ /#/) ) {
                #
                # Is this named anchor in the document ?
                #
                if ( Anchor_In_HTML($resp, $this_link, $link->query) ) {
                    $visited_url_status{$this_link} = $link_check_success;
                }
                else {
                    #
                    # Anchor not found
                    #
                    $visited_url_status{$this_link} = $link_check_broken_anchor;
                }
            }
            else {
                $visited_url_status{$this_link} = $link_check_success;
            }
        }

        #
        # Increment URL counter and set the number of hits for
        # this URL.
        #
        $visited_url_count++;
        $visited_url_hits{$this_link} = 1;
        $visited_link_object_cache{$this_link} = $link;

        #
        # If the response URL is different from the original one,
        # save the status under that URL path too.
        #
        if ( $resp_url ne $this_link ) {
            $visited_url_count++;
            $visited_url_hits{$resp_url} = 1;
            $visited_link_object_cache{$resp_url} = $link;

            #
            # If the link status is not a broken anchor, set the
            # resp_url status to that of this link. If the status
            # is a broken anchor, set status to success.  The value of
            # resp_url may be this_link minus an anchor name.  Just because
            # 1 named anchor on a page is broken, not all of them may
            # be broken.
            #
            if ( $visited_url_status{$this_link} == $link_check_broken_anchor ) {
       
                $visited_url_status{$resp_url} = $link_check_success;
            }
            #
            # If this link is a redirect, the response URL is a valid link
            #
            elsif ( $visited_url_status{$this_link} == $link_check_redirect ) {
       
                $visited_url_status{$resp_url} = $link_check_success;
            }
            else {
                $visited_url_status{$resp_url} = $visited_url_status{$this_link};
            }
        }
    }
    else {
        print "Previously checked link\n" if $debug;
        $visited_url_hits{$this_link}++;

        #
        # Copy link object information from cache
        #
        $cache_link = $visited_link_object_cache{$this_link};
        $link->mime_type($cache_link->mime_type);
    }

    #
    # Update link status.
    #
    $link->link_status($visited_url_status{$this_link});

    #
    # Return updated link object
    #
    return($link, $resp);
}

#***********************************************************************
#
# Name: IPV4_Link
#
# Parameters: this_link - URL to check
#
# Description:
#
#   This function checks to see  if the link contains an IP version 4
# address instead of a domain name.
#
# Returns:
#   0 - no link violation
#   1 - link violation
#
#***********************************************************************
sub IPV4_Link {
    my ($this_link) = @_;

    my ($rc, $protocol, $domain, $file_path, $query, $new_url);

    #
    # Get the domain and file path components from the URL
    #
    ($protocol, $domain, $file_path, $query, $new_url) =
        URL_Check_Parse_URL($this_link);
    print "IPV4_Link, domain = $domain\n" if $debug;

    #
    # Does the domain portion look like an IP address
    #  (ddd.ddd.ddd.ddd) ?
    #
    if ( $domain =~ /^\d+\.\d+\.\d+\.\d+$/ ) {
        #
        # IP address
        #
        $rc = 1;
        print "Found IP version 4 domain in $this_link\n" if $debug;
    }
    else {
        #
        # Not an IPV4 address
        #
        $rc = 0;
    }

    #
    # Return status
    #
    return($rc);
}

#***********************************************************************
#
# Name: Link_Checker
#
# Parameters: this_url - a URL
#             language - URL language
#             profile - testcase profile
#             links - pointer to a list of link objects
#
# Description:
#
#   This function checks the list of links for a number of violations.
#
#***********************************************************************
sub Link_Checker {
    my ( $this_url, $language, $profile, $links ) = @_;

    my ($i, $n_links, $this_link, $is_broken_link, $is_redirected_link );
    my ($domain, $referer_networkscope, $is_firewall_blocked);
    my ($link_check_status, $link, $resp, $header, $cache_link, $resp_url);
    my ($request_url, @link_results_list, $do_tests, $tcid, $do_ipv4_check);

    #
    # Do we have a valid profile ?
    #
    print "Link_Checker: URL $this_url, language = $language, profile = $profile\n" if $debug;
    if ( ! defined($link_check_profile_map{$profile}) ) {
        print "Unknown testcase profile passed $profile\n" if $debug;
        return(@link_results_list);
    }

    #
    # Initialize variables.
    #
    Initialize_Link_Checker_Variables($profile, \@link_results_list);

    #
    # Are any of the testcases defined in this module
    # in the testcase profile ?
    #
    $do_tests = 0;
    foreach $tcid (keys(%testcase_description_en)) {
        if ( defined($$current_link_check_profile{$tcid}) ) {
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
        return(@link_results_list);
    }

    #
    # Save URL in global variable
    #
    if ( ($this_url =~ /^http/i) || ($this_url =~ /^file/i) ) {
        $current_url = $this_url;
    }
    else {
        #
        # Doesn't look like a URL.  Could be just a block of HTML
        # from the standalone validator which does not have a URL.
        #
        $current_url = "";
    }

    #
    # get networkscope of this URL
    #
    $domain = $this_url;
    $domain =~ s/^http(s)?:\/\///g;
    $domain =~ s/\/.*//g;
    if ( defined($domain_networkscope_map{$domain}) ) {
        $referer_networkscope = $domain_networkscope_map{$domain};
    }
    else {
        #
        # Unknown networkscope, use the lowest scope to avoid 
        # false bad networkscope link violations
        #
        $referer_networkscope = 0;
    }

    #
    # Check to see if the current page has an IPV4 domain name.
    # If it does we will skip IPV4 link checking as any relative 
    # link on this page would be an IPV4 link.
    #
    if ( IPV4_Link($this_url) ) {
        $do_ipv4_check = 0;
    }
    else {
        $do_ipv4_check = 1;
    }

    #
    # Check each link in the set
    #
    foreach $link (@$links) {
        $this_link = $link->abs_url;
        print "Check new link $this_link, anchor = " . $link->anchor . "\n" if $debug;

        #
        # Does this link match any of the link ignore patterns ?
        #
        if ( Link_Matches_Ignore_Pattern($this_link, @link_ignore_patterns) ) {
            print "Ignore link $this_link\n" if $debug;
            next;
        }

        #
        # Get the link status
        #
        ($link, $resp) = Link_Checker_Get_Link_Status($this_url, $link);

        #
        # Start with the status of the link from the above presistent checks.
        #
        $link_check_status = $visited_url_status{$this_link};

        #
        # Is this an IPV4 link (domain name is an ipv4 address) ?
        #
        if ( $do_ipv4_check && IPV4_Link($this_link) ) {
            $link_check_status = $link_check_ipv4_link;
        }

        #
        # Additional checks on the link, these checks must be done even
        # if we have seen the link before as they are checks in the 
        # context of the referer URL.
        #
        if ( $link_check_status == $link_check_success ) {
            #
            # Check for a cross language link, use the lang
            # attribute of the link to see if it is a cross language
            # link.
            #
            if ( Cross_Language_Link($this_link, $link->anchor,
                                     $link->lang, $this_url, $link, $resp) ) {
                $link_check_status = $link_check_cross_language;
            }

            #
            # Check for bad network scope (e.g. internet document linking
            # to an intranet document).
            #
            elsif ( Bad_Networkscope_Link($referer_networkscope, $this_link) ) {
                $link_check_status = $link_check_bad_networkscope;
                Record_Result("BAD_NETWORKSCOPE", $link->line_no,
                              $link->column_no, $link->source_line,
                              "href= " . $link->href);
            }
        }
        else {
            #
            # Link check failed, save result
            #
            Record_Result($link_status_message_map{$link_check_status},
                          $link->line_no, $link->column_no,
                          $link->source_line,
                          "href= " . $link->href);
        }

        #
        # Save status
        #
        $link->link_status($link_check_status);
        print "Link_Checker, link = $this_link status = " . $link_check_status
            . "\n" if $debug;
    }

    #
    # Return list of link results
    #
    return(@link_results_list);
}

#***********************************************************************
#
# Name: Link_Check_Has_Rel_Alternate
#
# Parameters: url - URL
#
# Description:
#
#   This function checks the set of visited links to see if this URL's
# tag  (<a>, <link>, ...) contains a rel="alternate" attribute.
#
#***********************************************************************
sub Link_Check_Has_Rel_Alternate {
    my ($url) = @_;

    my ($link, %attr, $rel, $rel_value);

    #
    # Have we seen this URL ?
    #
    print "Link_Check_Has_Rel_Alternate, url = $url\n" if $debug;
    if ( defined($visited_link_object_cache{$url}) ) {
        #
        # Get the tag attributes.
        #
        $link = $visited_link_object_cache{$url};
        %attr = $link->attr;

        #
        # Is this an anchor <a> link ?
        #
        if ( $link->link_type eq "a" ) {
            #
            # Do we have a rel attribute ?
            #
            if ( defined($attr{"rel"}) ) {
                $rel = lc($attr{"rel"});
                print "Link has rel=\"$rel\"\n" if $debug;

                #
                # Do we have an "alternate' value ?
                #
                foreach $rel_value (split(/\s+/, $rel)) {
                    if ( $rel_value eq "alternate" ) {
                        #
                        # Got alternate, return true
                        #
                        print "Link has rel=\"alternate\"\n" if $debug;
                        return(1);
                    }
                }
            }
        }
    }

    #
    # If we got here we did not find rel="alternate"
    #
    return(0);
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
    my (@package_list) = ("url_check", "textcat", "pdf_files", "crawler",
                          "extract_anchors", "tqa_result_object",
                          "clf_check", "metadata", "extract_links");

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

