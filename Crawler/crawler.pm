#***********************************************************************
#
# Name: crawler.pm
#
# $Revision: 7184 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Crawler/Tools/crawler.pm $
# $Date: 2015-06-29 03:02:50 -0400 (Mon, 29 Jun 2015) $
#
# Description:
#
#   This file contains routines that crawl a site by following links from
# the entry points.
#
# Public functions:
#     Crawler_Decode_Content
#     Crawler_Uncompress_Content_File
#     Crawler_Read_Content_File
#     Crawler_Abort_Crawl
#     Crawler_Abort_Crawl_Status
#     Crawler_Config
#     Crawl_Site
#     Crawler_Get_HTTP_Response
#     Crawler_Get_User_Agent
#     Crawler_Robots_Handling
#     Crawler_Set_Proxy
#     Set_Crawler_Content_Callback
#     Set_Crawler_Debug
#     Set_Crawler_Domain_Alias_Map
#     Set_Crawler_Domain_Prod_Dev_Map
#     Crawler_Get_Prod_Dev_Domain
#     Set_Crawler_HTTP_Response_Callback
#     Set_Crawler_HTTP_401_Callback
#     Set_Crawler_Login_Logout
#     Set_Crawler_URL_Ignore_Patterns
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

package crawler;

use strict;
use Sys::Hostname;
use LWP::RobotUA;
use LWP::UserAgent;
use HTTP::Cookies;
use URI::URL;
use File::Basename;
use HTML::Form;
use Encode;
use URI::Escape;
use Digest::MD5 qw(md5_hex);
use HTML::Parser;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError) ;
my $have_threads = eval 'use threads; 1';
if ( $have_threads ) {
    $have_threads = eval 'use threads::shared; 1';
}
use File::Temp qw/ tempfile tempdir /;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Crawler_Decode_Content
                  Crawler_Uncompress_Content_File
                  Crawler_Read_Content_File
                  Crawler_Abort_Crawl
                  Crawler_Abort_Crawl_Status
                  Crawler_Config
                  Crawl_Site
                  Crawler_Get_HTTP_Response
                  Crawler_Get_User_Agent
                  Crawler_Robots_Handling
                  Set_Crawler_Content_Callback
                  Set_Crawler_Debug
                  Set_Crawler_Domain_Alias_Map
                  Set_Crawler_Domain_Prod_Dev_Map
                  Crawler_Get_Prod_Dev_Domain
                  Set_Crawler_HTTP_Response_Callback
                  Set_Crawler_HTTP_401_Callback
                  Set_Crawler_Login_Logout
                  Crawler_Set_Proxy
                  Set_Crawler_URL_Ignore_Patterns);
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);
my (%domain_alias_map, $user_agent, $yyyy_mm_dd_today, @site_url_patterns);
my ($domain_e, $domain_f, $content_callback_function, @site_ignore_patterns);
my ($http_response_callback_function, $login_callback_function);
my ($loginpagee, $logoutpagee, $loginpagef, $logoutpagef, @login_url_patterns);
my ($login_form_name, $http_401_callback_function, %http_401_credentials);
my ($login_domain_e, $login_domain_f, $accepted_content_encodings);
my (%domain_prod_dev_map, %domain_dev_prod_map);
my ($login_interstitial_count, $logout_interstitial_count, $user_agent_hostname);
my ($charset, $lwp_user_agent, $content_length);

#
# Shared variables for use between treads
#
my ($abort_crawl);
if ( $have_threads ) {
    share(\$abort_crawl);
}

my ($user_agent_name) = "Crawler";
my ($user_agent_max_size) = 10000000;
my ($user_agent_content_file) = 0;
my ($debug) = 0;
my ($max_urls_to_return) = 0;
my ($max_redirects) = 10;
my ($max_401s) = 2;
my ($respect_robots_txt) = 1;
my ($max_crawl_depth) = 0;

#***********************************************************************
#
# Name: Set_Crawler_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package global debug flag.
#
#***********************************************************************
sub Set_Crawler_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug value to global variable
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: Crawler_Abort_Crawl
#
# Parameters: status - abort status (1 = abort)
#
# Description:
#
#   This function sets the package global abort_crawl flag to stop
# the crawler.
#
#***********************************************************************
sub Crawler_Abort_Crawl {
    my ($status) = @_;

    $abort_crawl = $status;
}

#***********************************************************************
#
# Name: Crawler_Abort_Crawl_Status
#
# Parameters: none
#
# Description:
#
#   This function gets the package global abort_crawl flag.
#
#***********************************************************************
sub Crawler_Abort_Crawl_Status {

    return($abort_crawl);
}

#***********************************************************************
#
# Name: Crawler_Robots_Handling
#
# Parameters: respect - flag to respect robots.txt
#
# Description:
#
#   This function sets the package global flag to respect or
# ignore robots.txt directives.
#
#***********************************************************************
sub Crawler_Robots_Handling {
    my ($respect) = @_;

    #
    # Copy value to global variable
    #
    $respect_robots_txt = $respect;
}

#***********************************************************************
#
# Name: Crawler_Get_User_Agent
#
# Parameters: none
#
# Description:
#
#   This function returns a reference to a User Agent.  This can be used
# by other modules, e.g. link_checker, to perform GET operations.
#
#***********************************************************************
sub Crawler_Get_User_Agent {

    #
    # Do we have a user agent ?
    #
    if ( ! defined($user_agent) ) {
        Create_User_Agents();
    }

    #
    # Return user agent
    #
    return($user_agent);
}

#***********************************************************************
#
# Name: Crawler_Config
#
# Parameters: config_vars
#
# Description:
#
#   This function sets a number of package configuration values.
# The values are passed in as a hash table.
#
#***********************************************************************
sub Crawler_Config {
    my (%config_vars) = @_;

    my ($key, $value);

    #
    # Check for known configuration values
    #
    while ( ($key, $value) = each %config_vars ) {
        #
        # Check for known configuration variables
        #
        if ( $key eq "user_agent_name" ) {
            $user_agent_name = $value;
        }
        elsif ( $key eq "user_agent_max_size" ) {
            $user_agent_max_size = $value;
        }
        elsif ( $key eq "user_agent_hostname" ) {
            $user_agent_hostname = $value;
        }
        elsif ( $key eq "content_file" ) {
            $user_agent_content_file = $value;
        }
    }
}

#***********************************************************************
#
# Name: Set_Crawler_Content_Callback
#
# Parameters: local_content_callback_function
#
# Description:
#
#   This function sets the crawler content callback function.  This
# callback function is called for each document that is found durring
# the crawl.  The callback can be used by clients to process the content
# of a document as it is found.  The callback prototype is
#
#  callback(url, referer_url, mime_type, content)
#    where url is the document URL
#          referer_url is referer URL
#          mime_type is the document mime type
#          content is the content
#
#***********************************************************************
sub Set_Crawler_Content_Callback {
    my ($local_content_callback_function) = @_;

    #
    # Save the callback function
    #
    $content_callback_function = $local_content_callback_function;

}

#***********************************************************************
#
# Name: Set_Crawler_Domain_Alias_Map
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
sub Set_Crawler_Domain_Alias_Map {
    my (%local_domain_alias_map) = @_;

    #
    # Save domain alias map
    #
    %domain_alias_map = %local_domain_alias_map;

}

#***********************************************************************
#
# Name: Crawler_Get_Prod_Dev_Domain
#
# Parameters: domain
#
# Description:
#
#   This function returns the production or development domain that
# matches the supplied domain.  It check the prod/dev table first,
# if not match is found it checks the dev/prod table.
#
#***********************************************************************
sub Crawler_Get_Prod_Dev_Domain {
    my ($domain) = @_;

    #
    # Check domain production/development map
    #
    if ( defined($domain_prod_dev_map{$domain}) ) {
        return($domain_prod_dev_map{$domain});
    }
    elsif ( defined($domain_dev_prod_map{$domain}) ) {
        return($domain_dev_prod_map{$domain});
    }
    else {
        return("");
    }
}

#***********************************************************************
#
# Name: Set_Crawler_Domain_Prod_Dev_Map
#
# Parameters: local_domain_map
#
# Description:
#
#   This function sets the domain production/development map.  This 
# map provides a translation between a production and a development
# domain.
#
#***********************************************************************
sub Set_Crawler_Domain_Prod_Dev_Map {
    my (%local_domain_map) = @_;

    my ($prod, $dev);

    #
    # Save domain production/development map
    #
    %domain_prod_dev_map = %local_domain_map;

    #
    # Create a reverse map for development to production
    #
    while ( ($prod, $dev) = each %local_domain_map ) {
        $domain_dev_prod_map{$dev} = $prod;
    }
}

#***********************************************************************
#
# Name: Set_Crawler_HTTP_Response_Callback
#
# Parameters: local_http_response_callback_function
#
# Description:
#
#   This function sets the crawler http response callback function.  This
# callback function is called for each document that is found durring
# the crawl.  The callback can be used by clients that need the http response
# object.  The callback prototype is
#
#  callback(url, referer_url, mime_type, resp)
#    where url is the document URL
#          referer_url is referer URL
#          mime_type is the document mime type
#          resp is the HTTP::Response object
#
#***********************************************************************
sub Set_Crawler_HTTP_Response_Callback {
    my ($local_http_response_callback_function) = @_;

    #
    # Save the callback function
    #
    $http_response_callback_function = $local_http_response_callback_function;

}

#***********************************************************************
#
# Name: Set_Crawler_HTTP_401_Callback
#
# Parameters: local_http_401_callback_function
#
# Description:
#
#   This function sets the crawler http error 401 (Not Authorized)
# callback function.  This callback function is called whenever a 401
# response is received when crawling the site. The callback can
# be used by clients to provide the user and password needed to 
# access the document. The callback prototype is
#
#  callback(url, realm)
#    where url is the document URL
#          realm is the text displayed in the login prompt
#  The callback is expected to return a
#    (user, password) list.
#
#***********************************************************************
sub Set_Crawler_HTTP_401_Callback {
    my ($local_http_401_callback_function) = @_;

    #
    # Save the callback function
    #
    $http_401_callback_function = $local_http_401_callback_function;

}

#***********************************************************************
#
# Name: Set_Crawler_Login_Logout
#
# Parameters: local_loginpagee - English login page
#             local_logoutpagee - English logout page
#             local_loginpagef - French login page
#             local_logoutpagef - French logout page
#             local_login_form_name - name of login form
#             local_login_callback_function - callback function
#             local_login_interstitial_count - number of interstitial
#               pages after login page
#             local_logout_interstitial_count - number of interstitial
#               pages after logout page
#
# Description:
#
#   This function sets the crawler login/logout pages.  When the login
# page is encountered, the crawler calls the client to fill in the
# login credentials in order to enter the site. The callback prototype is
#
#  callback(url, form)
#    where url is the document URL
#          form is a HTML::Form object
#
# The callback is expected to return the form object with the input
# values set.
#
#***********************************************************************
sub Set_Crawler_Login_Logout {
    my ($local_loginpagee, $local_logoutpagee, $local_loginpagef,
        $local_logoutpagef, $local_login_form_name,
        $local_login_callback_function,
        $local_login_interstitial_count,
        $local_logout_interstitial_count) = @_;

    #
    # Save login & logout pages.
    #
    $loginpagee = $local_loginpagee;
    $logoutpagee = $local_logoutpagee;
    $loginpagef = $local_loginpagef;
    $logoutpagef = $local_logoutpagef;

    #
    # Save login form name
    #
    $login_form_name = $local_login_form_name;

    #
    # Save interstitial login/logout page counts
    #
    $login_interstitial_count = $local_login_interstitial_count;
    $logout_interstitial_count = $local_logout_interstitial_count;

    #
    # Save the callback function
    #
    $login_callback_function = $local_login_callback_function;
    if ( $debug ) {
        print "Set_Crawler_Login_Logout\n";
        print "  loginpagee              = $loginpagee\n";
        print "  logoutpagee             = $logoutpagee\n";
        print "  loginpagef              = $loginpagef\n";
        print "  logoutpagef             = $logoutpagef\n";
        print "  login_form_name         = $login_form_name\n";
        print "  login_callback_function = $login_callback_function\n";
        print "  login_interstitial_count = $login_interstitial_count\n";
        print "  logout_interstitial_count = $logout_interstitial_count\n";
    }
}

#***********************************************************************
#
# Name: Set_Crawler_URL_Ignore_Patterns
#
# Parameters: local_site_ignore_patterns
#
# Description:
#
#   This function sets the crawler URL ignore patterns.  These are
# patterns for URLs that are to be ignored (i.e. not crawled). This
# can be used to eliminate URLs that cause server side processing
# (e.g. PMRVIEW on the servicemanagement site).
#
#***********************************************************************
sub Set_Crawler_URL_Ignore_Patterns {
    my (@local_site_ignore_patterns) = @_;

    #
    # Save the URL ignore patterns
    #
    @site_ignore_patterns = @local_site_ignore_patterns;
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
#   This function handles the meta tag, it looks to see if it is used
# for specifying the page character set.
#
#***********************************************************************
sub Meta_Tag_Handler {
    my ( $line, $column, $text, %attr ) = @_;

    my ($content, @values, $value);

    #
    # Do we have a charset attribute (HTML 5 syntax)?
    #
    print "Meta tag found\n" if $debug;
    if ( defined($attr{"charset"}) ) {
        $charset = $attr{"charset"};
        print "Found meta charset = $charset\n" if $debug;
    }

    #
    # Do we have http-equiv="Content-Type"
    #
    elsif ( defined($attr{"http-equiv"}) &&
            ($attr{"http-equiv"} =~ /Content-Type/i) ) {
        #
        # Check for content
        #
        if ( defined($attr{"content"}) ) {
            $content = $attr{"content"};

            #
            # Split content on ';'
            #
            @values = split(/;/, $content);

            #
            # Look for a 'charset=' value
            #
            foreach $value (@values) {
                if ( $value =~ /^\s*charset=/i ) {
                    ($value, $charset) = split(/=/, $value);
                    print "Found meta http-equiv=Content-Type, charset = $charset\n" if $debug;
                    last;
                }
            }
        }
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
    # Check meta tags
    #
    $tagname =~ s/\///g;
    if ( $tagname eq "meta" ) {
        Meta_Tag_Handler( $line, $column, $text, %attr_hash );
    }
}

#***********************************************************************
#
# Name: HTML_Charset
#
# Parameters: content - HTML content
#
# Description:
#
#   This function parses the HTML content looking for a <meta charset
# setting.
#
#***********************************************************************
sub HTML_Charset {
    my ($content) = @_;

    my ($parser);

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
    $charset = "";
    $parser->parse($content);

    #
    # Return the charset, if one was found.
    #
    print "HTML_Charset charset = $charset\n" if $debug;
    return($charset);
}

#***********************************************************************
#
# Name: Crawler_Decode_Content
#
# Parameters: resp - HTTP::Response object
#
# Description:
#
#   This function checks whether or not the HTTP reponse content is UTF8.
# If the content is UTF-8, it is decoded before being returned to
# the caller.
#
#***********************************************************************
sub Crawler_Decode_Content {
    my ($resp) = @_;

    my ($content, $header);

    #
    # Get content with no charset decoding.
    #
    print "Crawler_Decode_Content\n" if $debug;
    if ( ! defined($resp) ) {
        return("");
    }
    $content = $resp->decoded_content(charset => 'none');

    #
    # Check for UTF-8 content type in the header
    #
    if ( (defined($resp->header('Content-Type')) &&
           ($resp->header('Content-Type') =~ /charset=UTF-8/i)) ||
         (defined($resp->header('X-Meta-Charset')) &&
           ($resp->header('X-Meta-Charset') =~ /UTF-8/i)) ) {
        print "Header content type = UTF-8, decode content\n" if $debug;
        $content = decode("utf8", $content, Encode::FB_HTMLCREF);
    }
    else {
        #
        # If the content type is HTML, check for a <meta charset
        #
        $header = $resp->headers;
        if ( $header->content_type =~ /text\/html/ ) {
            if ( HTML_Charset($content) =~ /utf-8/i ) {
                print "HTML charset = UTF-8, decode content\n" if $debug;
                $content = decode("utf8", $content, Encode::FB_HTMLCREF);
            }
        }
    }

    #
    # Return content
    #
    return($content);
}

#***********************************************************************
#
# Name: Crawler_Uncompress_Content_File
#
# Parameters: resp - HTTP::Response object
#
# Description:
#
#   This function checks whether or not the HTTP reponse content is
# compressed.  If it is, the content file is uncompressed.
#
#***********************************************************************
sub Crawler_Uncompress_Content_File {
    my ($resp) = @_;

    my ($filename, $new_filename, $header);

    #
    # Check for GZIP content encoding in the header
    #
    print "Crawler_Uncompress_Content_File\n" if $debug;
    if ( defined($resp) &&
         defined($resp->header('Content-Encoding') &&
         ($resp->header('Content-Encoding') =~ /gzip/i)) ) {
        print "Content is compressed with gzip\n" if $debug;
        
        #
        # Get content file name
        #
        $filename = $resp->header("WPSS-Content-File");
        
        #
        # Get a new temporary file
        #
        (undef, $new_filename) = tempfile(OPEN => 0);
        
        #
        # Uncompress the content
        #
        print "Uncompressed with gunzip, $filename => $new_filename\n" if $debug;
        if ( gunzip($filename => $new_filename) ) {
            print "Gunzip successful\n" if $debug;
            $header = $resp->headers;
            $header->header("WPSS-Content-File" => $new_filename);
            unlink($filename);
        }
        else {
            print "Error: Crawler_Uncompress_Content_File failed to gunzip $filename, error = $GunzipError\n";
        }
    }

    #
    # Return
    #
    return();
}

#***********************************************************************
#
# Name: Crawler_Read_Content_File
#
# Parameters: resp - HTTP::Response object
#
# Description:
#
#   This function reads the content file and returns the content as
# a string.
#
#***********************************************************************
sub Crawler_Read_Content_File {
    my ($resp) = @_;

    my ($filename, $content, $header, $line);

    #
    # Read content from content file
    #
    print "Crawler_Read_Content_File\n" if $debug;
    if ( defined($resp) ) {
        #
        # Get content file name
        #
        $filename = $resp->header("WPSS-Content-File");

        #
        # Open the file for reading
        #
        open(FH, $filename) ||
            die "Error: Failed to open file $filename in Crawler_Read_Content_File\n";

        #
        # Read in the content
        #
        $content = "";
        while ( $line = <FH> ) {
            $content .= $line;
        }

        #
        # Close the file
        #
        close(FH);
    }

    #
    # Return the content
    #
    return($content);
}

#***********************************************************************
#
# Name: Create_User_Agents
#
# Parameters: none
#
# Description:
#
#   This function creates user agent objects to be used in http
# requests.  Two user agents are created, one LWP::UserAgent and
# one LWP::RobotUA.
#
#***********************************************************************
sub Create_User_Agents {

    #
    # Local variables
    #
    my ($cookie_jar, $host);

    #
    # Get hostname if we were not given one in the configuration options.
    #
    if ( ! defined($user_agent_hostname) ) {
        $host = hostname;
    }
    else {
        $host = $user_agent_hostname;
    }

    #
    # Setup user agent to handle HTTP requests
    #
    print "Create LWP::RobotUA user agent $user_agent_name\n" if $debug;
    $user_agent = LWP::RobotUA->new("$user_agent_name", "$user_agent_name\@$host");
    $user_agent->ssl_opts(verify_hostname => 0);
    $user_agent->timeout("60");
    $user_agent->delay(1/120);

    #
    # Set maximum document size
    #
    if ( $user_agent_max_size > 0 ) {
        $user_agent->max_size($user_agent_max_size);
    }

    #
    # Create a temporary cookie jar for the user agent.
    #
    $cookie_jar = HTTP::Cookies->new;
    $user_agent->cookie_jar( $cookie_jar );

    #
    # Get list of acceptable encodings that this Perl installation
    # can accept.
    #
    eval {$accepted_content_encodings = HTTP::Message::decodable; };
    print "HTTP::Message::decodable = $accepted_content_encodings\n" if $debug;
    
    #
    # Create a LWP::UserAgent object
    #
    print "Create LWP::UserAgent user agent $user_agent_name\n" if $debug;
    $lwp_user_agent = LWP::UserAgent->new("$user_agent_name");
    $lwp_user_agent->ssl_opts(verify_hostname => 0);
    $lwp_user_agent->timeout("60");

    #
    # Set maximum document size
    #
    if ( $user_agent_max_size > 0 ) {
        $lwp_user_agent->max_size($user_agent_max_size);
    }

    #
    # Create a temporary cookie jar for the user agent.
    #
    $cookie_jar = HTTP::Cookies->new;
    $lwp_user_agent->cookie_jar( $cookie_jar );


}

#***********************************************************************
#
# Name: Crawler_Set_Proxy
#
# Parameters: proxy - proxy server
#
# Description:
#
#   This function sets or clears the proxy server value for the user
# agent.
#
#***********************************************************************
sub Crawler_Set_Proxy {
    my ($proxy) = @_;

    #
    # Do we have a  user agent ?
    #
    if ( ! defined($user_agent) ) {
        Create_User_Agents();
    }

    #
    # Check for leading http on proxy setting
    #
    if ( ($proxy ne "" ) && ! ($proxy =~ /^http[s]?:\/\//) ) {
        print "Add http to proxy setting\n" if $debug;
        $proxy = "http://$proxy";
    }

    #
    # Do we have a proxy value ?
    #
    if ( defined($proxy) && ($proxy ne "") ) {
        print "Crawler_Set_Proxy: Set proxy to $proxy\n" if $debug;
        $user_agent->proxy("http", $proxy);
    }
    else {
        print "Crawler_Set_Proxy: Clear proxy settings\n" if $debug;
        $user_agent->no_proxy();
    }
}

#***********************************************************************
#
# Name: Set_Login_URL_Patterns
#
# Parameters: domain_e - English site domain
#             domain_f - French site domain
#             dir_e - English site directory
#             dir_f - French site directory
#
# Description:
#
#   This function generates the URL patterns for login pages.
#
#***********************************************************************
sub Set_Login_URL_Patterns {
    my ($domain_e, $domain_f, $dir_e, $dir_f) = @_;

    my ($page);

    #
    # Save login page patterns
    #
    if ( defined($loginpagee) ) {
        #
        # Do we have an absolute URL for login ?
        #
        if ( $loginpagee =~ /^http[s]?:/i ){
            $page = $loginpagee;
            $page =~ s/^http[s]?:\/\///i;
            push(@login_url_patterns, "$page");
        }
        else {
            #
            # Save login page patterns with all combinations of English & French
            # domains along with English & French directories.
            #
            push(@login_url_patterns, "$domain_e/$dir_e$loginpagee");
            if ( $dir_f ne $dir_e ) {
                push(@login_url_patterns, "$domain_e/$dir_f$loginpagee");
            }
            if ( $domain_f ne $domain_e ) {
                push(@login_url_patterns, "$domain_f/$dir_e$loginpagee");
                if ( $dir_f ne $dir_e ) {
                    push(@login_url_patterns, "$domain_f/$dir_f$loginpagee");
                }
            }
        }
    }
    if ( defined($loginpagef) && ($loginpagef ne $loginpagee) ) {
        #
        # Do we have an absolute URL for login ?
        #
        if ( $loginpagef =~ /^http[s]?:/i ){
            $page = $loginpagef;
            $page =~ s/^http[s]?:\/\///i;
            push(@login_url_patterns, "$page");
        }
        else {
            #
            # Save login page patterns with all combinations of English & French
            # domains along with English & French directories.
            #
            push(@login_url_patterns, "$domain_e/$dir_e$loginpagef");
            if ( $dir_f ne $dir_e ) {
                push(@login_url_patterns, "$domain_e/$dir_f$loginpagef");
            }
            if ( $domain_f ne $domain_e ) {
                push(@login_url_patterns, "$domain_f/$dir_e$loginpagef");
                if ( $dir_f ne $dir_e ) {
                    push(@login_url_patterns, "$domain_f/$dir_f$loginpagef");
                }
            }
        }
    }

    if ( $debug ) {
        print "Set_Login_URL_Patterns List of login URLs\n";
        foreach (@login_url_patterns) {
            print "  $_\n";
        }
    }
}

#***********************************************************************
#
# Name: Set_Site_URL_Patterns
#
# Parameters: site_dir_e - English site domain & directory
#             site_dir_f - French site domain & directory
#
# Description:
#
#   This function generates the URL patterns for this site as well
# as for the login pages.
#
#***********************************************************************
sub Set_Site_URL_Patterns {
    my ($site_dir_e, $site_dir_f) = @_;

    my ($protocol, $domain_e, $dir_e, $query, $domain_f, $dir_f, $page);
    my ($url, $resp, $new_url);

    #
    # Add trailing / to site directories
    #
    if ( ! ($site_dir_e =~ /\/$/) ) {
        $site_dir_e .= "/";
    }
    if ( ! ($site_dir_f =~ /\/$/) ) {
        $site_dir_f .= "/";
    }

    #
    # Extract the domain & directory portion from the site directories
    #
    ($protocol, $domain_e, $dir_e, $query, $new_url) = URL_Check_Parse_URL($site_dir_e);
    ($protocol, $domain_f, $dir_f, $query, $new_url) = URL_Check_Parse_URL($site_dir_f);

    #
    # Save site pattern with all combinations of English & French
    # domains along with English & French directories.
    #
    @site_url_patterns = ("$domain_e/$dir_e");
    if ( $dir_f ne $dir_e ) {
        push(@site_url_patterns, "$domain_e/$dir_f");
    }
    if ( $domain_f ne $domain_e ) {
        push(@site_url_patterns, "$domain_f/$dir_e");
        if ( $dir_f ne $dir_e ) {
            push(@site_url_patterns, "$domain_f/$dir_f");
        }
    }

    #
    # Save cgi-bin site pattern with all combinations of English & French
    # domains along with English & French directories.
    #
    push(@site_url_patterns, "$domain_e/cgi-bin/$dir_e");
    if ( $dir_f ne $dir_e ) {
        push(@site_url_patterns, "$domain_e/cgi-bin/$dir_f");
    }
    if ( $domain_f ne $domain_e ) {
        push(@site_url_patterns, "$domain_f/cgi-bin/$dir_e");
        if ( $dir_f ne $dir_e ) {
            push(@site_url_patterns, "$domain_f/cgi-bin/$dir_f");
        }
    }

    #
    # Set login URL patterns
    #
    Set_Login_URL_Patterns($domain_e, $domain_f, $dir_e, $dir_f);

    #
    # Get login page and check for domain change (e.g. using
    # AccessKey for login).  If there is a domain change, this new
    # domain has to be added to the site URL patterns.
    #
    if ( defined($loginpagee) ){
        #
        # Is this an absolute URL ?
        #
         if ( $loginpagee =~ /^http[s]?:/i ) {
             $url = $loginpagee;
         }
         else {
             $url = $site_dir_e . $loginpagee;
         }

        #
        # Get login page and break apart the response URL
        #
        ($url, $resp) = Crawler_Get_HTTP_Response($url, "");
        ($protocol, $login_domain_e, $dir_e, $query, $new_url) = 
            URL_Check_Parse_URL($url);
        print "login_domain_e = $login_domain_e\n" if $debug;
    }

    #
    # Check domain of French login page
    #
    if ( defined($loginpagef) ){
        #
        # Is this an absolute URL ?
        #
         if ( $loginpagef =~ /^http[s]?:/i ) {
             $url = $loginpagef;
         }
         else {
             $url = $site_dir_f . $loginpagef;
         }

        #
        # Get login page and break apart the response URL
        #
        ($url, $resp) = Crawler_Get_HTTP_Response($url, "");
        ($protocol, $login_domain_f, $dir_e, $query, $new_url) = 
            URL_Check_Parse_URL($url);
        print "login_domain_f = $login_domain_f\n" if $debug;
    }

    #
    # If we have a login page domain, add it to the site URL patterns
    #
    if ( defined($login_domain_e) && 
         ($login_domain_e ne "") &&
         ($login_domain_e ne $domain_e) ) {
        push(@site_url_patterns, $login_domain_e);
        print "Add login_domain_e = $login_domain_e to site_url_patterns\n" if $debug;
    }
    if ( defined($login_domain_f) && 
         ($login_domain_f ne "") &&
         ($login_domain_f ne $domain_e) ) {
        push(@site_url_patterns, $login_domain_f);
        print "Add login_domain_f = $login_domain_f to site_url_patterns\n" if $debug;
    }

    if ( $debug ) {
        print "Set_Site_URL_Patterns site URL patterns\n";
        foreach (@site_url_patterns) {
            print "  $_\n";
        }
    }
}

#***********************************************************************
#
# Name: Initialize_Crawler_Variables
#
# Parameters: none
#
# Description:
#
#   This function initializes the crawler variables.
#
#***********************************************************************
sub Initialize_Crawler_Variables {
    my ($site_dir_e, $site_dir_f) = @_;

    my ($dir_e, $dir_f, $day, $month, $year);
    my ($protocol, $query, $new_url);

    #
    # Create user agent
    #
    if ( ! defined($user_agent) ) {
        Create_User_Agents();
    }

    #
    # Get today's date
    #
    ($day, $month, $year) = (localtime())[3,4,5];
    $year += 1900;
    $month++;
    $yyyy_mm_dd_today = sprintf("%04d-%02d-%02d", $year,$month, $day);

    #
    # Add trailing / to site directories
    #
    if ( ! ($site_dir_e =~ /\/$/) ) {
        $site_dir_e .= "/";
    }
    if ( ! ($site_dir_f =~ /\/$/) ) {
        $site_dir_f .= "/";
    }

    #
    # Split URL into its components
    #
    ($protocol, $domain_e, $dir_e, $query, $new_url) = 
        URL_Check_Parse_URL($site_dir_e);
    ($protocol, $domain_f, $dir_f, $query, $new_url) = 
        URL_Check_Parse_URL($site_dir_f);

    #
    # If directory is not just a simple /, remove the trailing slash.
    # This add & remove of a slash is needed to handle
    #   http://domain and
    #   http://domain/directory
    # cases.
    #
    if ( $dir_e ne "/" ) {
        $dir_e =~ s/\/$//;
    }
    if ( $dir_f ne "/" ) {
        $dir_f =~ s/\/$//;
    }

    #
    # Save site pattern with all combinations of English & French
    # domains along with English & French directories.
    #
    Set_Site_URL_Patterns($site_dir_e, $site_dir_f);

    #
    # Empty out the HTTP 401 credentials table
    #
    %http_401_credentials = ();

    #
    # Clear abort crawl flag
    #
    $abort_crawl = 0;
}

#***********************************************************************
#
# Name: Clear_User_Agent_Robot_Rules
#
# Parameters: none
#
# Description:
#
#   This function removes any robot rules from the User Agent.
# This allows us to ignore robot.txt directives.
#
# Returns:
#    url - URL of response
#    HTTP::Response object
#
#***********************************************************************
sub Clear_User_Agent_Robot_Rules {

    my ($rules, $loc, @domains, $domain, $domain_rules, $rule);

    #
    # Get rules from the user agent
    #
    print "Clear robot rules from user agent\n" if $debug;
    $rules =$user_agent->rules;

    #
    # Get the loc, location field and the list of domains
    #
    $loc = $$rules{"loc"};
    @domains = keys(%$loc);

    #
    # Process each domain in the list
    #
    foreach $domain (@domains) {
        print "Clear rules for domain $domain\n" if $debug;
        $domain_rules = $$loc{"$domain"}{"rules"};
        $$loc{"$domain"}{"rules"} = ();
   }
}

#***********************************************************************
#
# Name: HTTP_Response_Data_Callback
#
# Parameters: response - HTTP::Response object
#             ua - LWP::UserAgent object
#             h -  HTTP::Headers object
#             data - data chunk
#
# Description:
#
#   This function is a callback for a UserAgent->get operation to
# receive data chunks.  The data is saved to a file.
#
# This callback is used rather than the :content_file or other
# LWP::UserAgent capability due to a bug in libwww in which an
# IO error may occur when reading binary data over an https
# connection.
#
# Returns:
#    true
#
#***********************************************************************
sub HTTP_Response_Data_Callback {
    my ($response, $ua, $h, $data) = @_;

    #
    # Check response code.
    #
    if ( $response->code == 200 ) {
        #
        # Print the data to the file handle
        #
        $content_length += length($data);
        print "HTTP_Response_Data_Callback chunk = " . length($data) . " total length = $content_length\n" if $debug;
        print HTTP_FH $data;
    }
    else {
        print "Response code " . $response->code . "\n" if $debug;
    }

    #
    # Erase the content from the HTTP::Response object since it
    # has been written to a file.  This avoids duplication of the
    # potentially large amount of data in the file and the response
    # object.
    #
    $response->content("");
    #print "Response = " . $response->as_string . "\n" if $debug;

    #
    # Return True to continue to receive data
    #
    return(1);
}

#***********************************************************************
#
# Name: Crawler_Get_HTTP_Response
#
# Parameters: this_url - a URL
#             referer_url - the referer URL
#
# Description:
#
#   This function gets a HTTP::Response object for the URL.
#
# Returns:
#    url - URL of response
#    HTTP::Response object
#
#***********************************************************************
sub Crawler_Get_HTTP_Response {
    my ( $this_url, $referer_url ) = @_;

    my ($req, $resp, $http_error_code, $http_error, $filename);
    my ($user, $password, $realm, $url, $header, $redirect_domain);
    my ($redirect_protocol, $protocol, $host, $path, $query, $port);
    my ($redirect_file_path, $redirect_query, $redirect_dir, $new_url);
    my ($redirect_count) = 0;
    my ($http_401_count) = 0;
    my ($done) = 0;
    my ($robots_cleared) = 0;
    my ($use_simple_request) = 1;

    #
    # Do we have a  user agent ?
    #
    if ( ! defined($user_agent) ) {
        Create_User_Agents();
    }

    #
    # Get components of original URL
    #
    ($redirect_protocol, $redirect_domain, $redirect_file_path, $redirect_query, $new_url) = 
        URL_Check_Parse_URL($this_url);
    $redirect_dir = dirname($redirect_file_path);
    if ( $redirect_dir eq "." ) {
        $redirect_dir = "";
    }

    #
    # Did the URL look like a valid URL ?
    #
    if ( $redirect_protocol eq "" ) {
        print "Invalid URL passed to Crawler_Get_HTTP_Response, $this_url\n" if $debug;
        return ($this_url, $resp);
    }

    #
    # Are we saving the content in a file ?
    #
    if ( $user_agent_content_file ) {
        (undef, $filename) = tempfile(OPEN => 0);
        $content_length = 0;
        $lwp_user_agent->remove_handler("response_data");
        $lwp_user_agent->add_handler("response_data" => \&HTTP_Response_Data_Callback);
        $use_simple_request = 0;
    }

    #
    # Loop, following redirects, until we have the web document
    #
    $url = $this_url;
    print "GET url = $url, Referrer = $referer_url\n" if $debug;
    while ( ! $done ) {

        #
        # Build the page request
        #
        print "Crawler_Get_HTTP_Response GET url = $url\n" if $debug;
        $req = new HTTP::Request( GET => $url );
        $req->header("Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
        $req->header("Pragma" => "no-cache");
        $req->header("Cache-Control" => "no-cache");
        $req->header("Connection" => "keep-alive");

        #
        # Add accepted content encodings
        #
        if ( defined($accepted_content_encodings) ) {
            $req->header("Accept-Encoding" => $accepted_content_encodings);
        }
        
        #
        # Set referer if we have one.
        #
        if ( defined($referer_url) ) {
            $req->referrer("$referer_url");
        }

        #
        # Are we doing a simple request (the usual case) ?
        #
        if ( $use_simple_request ) {
            #
            # Perform a simple request, this prevents automatic redirecting
            #
            $user_agent->prepare_request($req);
            print "Request  = " . $req->as_string . "\n" if $debug;
            $resp = $user_agent->simple_request($req);
        }
        else {
            #
            # Perform a GET, while this will follow automatic redirects
            # it is also necessary when getting password protected
            # documents.
            #
            print "Request  = " . $req->as_string . "\n" if $debug;
            
            #
            # If we are saving content to a file, use the LWP::UserAgent
            # rather than the LWP::RobotUA
            #
            if ( $user_agent_content_file ) {
                print "Use LWP::UserAgent to get content in file $filename\n" if $debug;
                #$lwp_user_agent->prepare_request($req);
                unlink($filename);
                open(HTTP_FH, ">$filename");
                binmode HTTP_FH;
                $resp = $lwp_user_agent->request($req);
                close(HTTP_FH);
            }
            else {
                print "Use LWP::RobotUA to get content\n" if $debug;
                #$user_agent->prepare_request($req);
                $resp = $user_agent->request($req);
            }
        }

        #
        # Print response information
        #
        print "Response code = " . $resp->code . "\n" if $debug;
        $header = $resp->headers;
        print "Response header = " . $header->as_string . "\n" if $debug;

        #
        # Check for success on GET operation
        #
        if ( !$resp->is_success ) {
            #
            # Operation failed, check to see if we received a 401
            # (Not Authorized) error.
            #
            $http_error_code = $resp->code;
            if ( $http_error_code == 401 ) {
                #
                # Got a 401 - Not Authorized code.  Increment count
                # of the number of times we hit this, we don't want to
                # get into a 401 loop.
                #
                $http_401_count++;

                #
                # Have we seen too many 401 errors ?
                #
                if ( $http_401_count > $max_401s ) {
                    $done = 1;
                    print "Aborting GET, too many 401 - Not Authorized errors\n" if $debug;
                }

                #
                # Do we have a 401 handler function ?
                #
                if ( defined($http_401_callback_function) ) {
                    #
                    # Break url into components
                    #
                    ($protocol, $host, $path, $query, $new_url) = 
                        URL_Check_Parse_URL($url);
                    $redirect_dir = dirname($redirect_file_path);
                    if ( $redirect_dir eq "." ) {
                        $redirect_dir = "";
                    }

                    #
                    # Is this first 401 code for this URL ?
                    #
                    if ( $http_401_count == 1 ) {
                        #
                        # Get credentials for the domain
                        #
                        $path = "$host/";
                    }
                    else {
                        #
                        # Get credentials for the full path (domain + directory)
                        #
                        $path =~ s/[^\/]*$//g;
                        $path =~ s/\/$//g;
                        $path = "$host/$path";
                    }

                    #
                    # Have we already requested credentials for this URL
                    # directory ? If we did and we get here, we either did
                    # not supply valid credentials or any credentials, either
                    # way we will not ask again
                    #
                    print "Check 401 credentials for $path\n" if $debug;
                    if ( ! defined($http_401_credentials{$path}) ) {
                        print "Call 401 callback function for path = $path\n" if $debug;
                        $realm = $resp->header('WWW-Authenticate');

                        #
                        # Get the text between the first and last " characters.
                        # The typical value of realm would be something like
                        #    Basic realm="Client Login Screen"
                        # we want the 'Client Login Screen' string only.
                        #
                        $realm =~ s/"$//;
                        $realm =~ s/^.*="//;
                        ($user, $password) = &$http_401_callback_function($this_url,
                                                                          $realm);

                        #
                        # Add credentials to request if we have them
                        #
                        if ( $user ne "" ) {
                            #
                            # Do we have a port number in the host field ?
                            #
                            if ( $host =~ /:/ ) {
                                ($host, $port) = split(/:/, $host);
                            }
                            else {
                                if ( $protocol =~ /https/i ) {
                                    #
                                    # Default port to 443
                                    #
                                    $port = 443;
                                }
                                else {
                                    #
                                    # Default port to 80
                                    #
                                    $port = 80;
                                }
                            }

                            #
                            # Add credentials to the user agent
                            #
                            print "Add login credentials to user agent (user=$user, password=$password, host=$host:$port, realm=$realm)\n" if $debug;
                            $user_agent->credentials("$host:$port", "$realm",
                                                     "$user", "$password");

                            $http_401_credentials{$path} = 1;

                            #
                            # We can't do a simple request to get a
                            # password protected document.  The simple
                            # request will fail, we must do a full request.
                            #
                            $use_simple_request = 0;
                        }
                        else {
                            #
                            # No user, set response code to 404 to avoid
                            # retrying the GET.
                            #
                            print "Skip retry of GET, no user supplied for 401 error\n" if $debug;
                            $http_error_code = 404;
                            $http_401_credentials{$path} = 0;
                        }
                    }
                    else {
                        #
                        # Do we want to skip this directory ?
                        #
                        if ( ! $http_401_credentials{$path} ) {
                            $http_error_code = 404;
                        }
                        else {
                            #
                            # We can't do a simple request to get a
                            # password protected document.  The simple
                            # request will fail, we must do a full request.
                            #
                            $use_simple_request = 0;
                        }
                    }
                }
            }

            #
            # Did we get a 403 Forbidden by robots response ?
            # and are we ignoring robots directives ?
            #
            elsif ( ($http_error_code == 403) && (! $respect_robots_txt) ) {
                #
                # Clear the rules from the user agent to ignore
                # robots.txt
                #
                if ( ! $robots_cleared ) {
                    print "Got 403-Forbidden by robots\n" if $debug;
                    Clear_User_Agent_Robot_Rules();
                    $robots_cleared = 1;
                }
                else {
                    print "Forbidden by robots.txt twice\n" if $debug;
                    $done = 1;
                }
            }

            #
            # Is there a redirect ?
            #
            elsif ( $resp->is_redirect ) {
                #
                # Get new target for redirect
                #
                print "Redirect, code = " . $resp->code . "\n" if $debug;
                $redirect_count++;
                $header = $resp->headers;
                $url = $header->header("Location");
                print "Redirect to = $url\n" if $debug;

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
                # Did the URL look like a valid URL ?
                #
                if ( $redirect_protocol eq "" ) {
                    print "Invalid URL provided in redirect, $url\n" if $debug;
                    return ($url, $resp);
                }

                #
                # Have we seen too many redirects ?
                #
                if ( $redirect_count >= $max_redirects ) {
                    $done = 1;
                    print "Aborting GET, too many redirects\n" if $debug;
                }
            }
            else {
                #
                # Nor a 401 (Not Authorized) and not a redirect.
                #
                $done = 1;
                if ( $debug ) {
                    $http_error_code = $resp->code;
                    $http_error = $resp->status_line;
                    print "Error accessing URL, code is $http_error_code\n";
                    print "                     Error is $http_error\n";
                }
            }
        }
        else {
            #
            # GET was successful
            #
            $done = 1;
            print "Crawler_Get_HTTP_Response: GET successful\n" if $debug;
            $header = $resp->headers;
            print "Content type = " . $header->content_type . "\n" if $debug;

            #
            # Did we save the content in a file ?
            #
            if ( $user_agent_content_file ) {
                $header->push_header("WPSS-Content-File" => $filename);
                print "Set header WPSS-Content-File => $filename\n" if $debug;
            }
        }
    }
    print "GET url response = $url, Referrer = $referer_url\n" if $debug;

    #
    # Return the response object
    #
    return($url, $resp);
}

#***********************************************************************
#
# Name: Correct_Link_Format
#
# Parameters: link_href - list of links from a document
#
# Description:
#
#   This function checks to see that links are well formed.  It
# ensures that there are 2 slashes after the protocol (e.g. http://)
# and that there are only single slashes in the path portion of the URL.
#
# Returns:
#  list of links.
#
#***********************************************************************
sub Correct_Link_Format {
    my (@link_href) = @_;

    my ($this_link, %filtered_links, $protocol, $host, $path, $query, $new_url);

    #
    # Check all links
    #
    foreach $this_link (@link_href) {

        #
        # Is this a mailto link ?
        #
        if ( $this_link =~ /^mailto:/ ) {
            print "Ignore mailto link $this_link\n" if $debug;
            next;
        }

        #
        # Is this a javascript link ?
        #
        if ( $this_link =~ /^javascript:/ ) {
            print "Ignore javascript link $this_link\n" if $debug;
            next;
        }

        #
        # Strip off any anchor references in the URL
        #
        $this_link =~ s/#.*//;

        #
        # Do we still have a link ? Was it just an anchor ?
        #
        if ( $this_link eq "" ) {
            next;
        }

        #
        # Have we seen this link before in the list?
        #
        if ( defined($filtered_links{$this_link}) ) {
            next;
        }

        #
        # Split URL into its components
        #
        print "Correct_Link_Format: $this_link\n" if $debug;
        ($protocol, $host, $path, $query, $new_url) = 
            URL_Check_Parse_URL($this_link);

        #
        # Use the reconstructed link
        #
        $this_link = $new_url;

        #
        # Add link to the filtered list.
        #
        $filtered_links{$this_link} = 1;
    }

    #
    # Return list of filtered links
    #
    return(keys %filtered_links);

}

#***********************************************************************
#
# Name: Correct_Link_Domain_Language
#
# Parameters: link_href - list of links from a document
#
# Description:
#
#   This function checks the list of links to see if the domain 
# portion has to be corrected for the document language.
# It ensures all English documents use the English domain
# while French ones use the corresponding French value.  
# The directory portion is not changed in case there are 2 real
# directories (not symbolically linked together).
#
# Returns:
#  list of links.
#
#***********************************************************************
sub Correct_Link_Domain_Language {
    my (@link_href) = @_;

    my ($this_link, %filtered_links, $language);

    #
    # Check all links
    #
    foreach $this_link (@link_href) {
        #
        # Strip off any anchor references in the URL
        #
        $this_link =~ s/#.*//;

        #
        # Have we seen this link before in the list?
        #
        if ( defined($filtered_links{$this_link}) ) {
            next;
        }

        #
        # Check document language based on URL.
        #
        print "Correct_Link_Domain_Language: $this_link\n" if $debug;
        if ( ( $this_link =~ /-e\./i ) || ( $this_link =~ /_e\./i ) ||
             ( $this_link =~ /-eng\./i ) ) {
            #
            # Convert any French domain to the English one.
            #
            $this_link =~ s/\/\/$domain_f\//\/\/$domain_e\//;
        }
        elsif ( ( $this_link =~ /-f\./i ) || ( $this_link =~ /_f\./i ) ||
             ( $this_link =~ /-fra\./i ) ) {
            #
            # Convert any English domain to the French one.
            #
            $this_link =~ s/\/\/$domain_e\//\/\/$domain_f\//;
        }
        $filtered_links{$this_link} = 1;
    }

    #
    # Return list of filtered links
    #
    return(keys %filtered_links);

}

#***********************************************************************
#
# Name: Clean_URL_Arguments
#
# Parameters: link_href - list of links from a document
#
# Description:
#
#   This function looks for any URL arguments and checks
# for duplicate settings.
#
# Returns:
#  list of links.
#
#***********************************************************************
sub Clean_URL_Arguments {
    my (@link_href) = @_;

    my ( $this_link, %filtered_links, $url_arguments, @argument_list );
    my ( $arg, $new_url_arguments, %found_arg );

    #
    # Check all links for URL arguments
    #
    foreach $this_link (@link_href) {
        #
        # Have we seen this link before in the list or have we visited 
        # this link ?
        #
        if ( defined($filtered_links{$this_link}) ) {
            next;
        }

        #
        # Do we have a ? in the URL ?
        #
        if ( $this_link =~ /\?/ ) {
            #print "Clean_URL_Arguments: $this_link\n" if $debug;

            #
            # Get the URL arguments and split them on the &
            #
            $url_arguments = $this_link;
            $url_arguments =~ s/^.*?\?//g;
            @argument_list = split(/&/, $url_arguments);

            #
            # Create a new argument list by removing duplicates
            #
            $new_url_arguments = "";
            %found_arg = ();
            foreach $arg (@argument_list) {
                if ( ! defined($found_arg{$arg}) ) {
                    if ( $new_url_arguments eq "" ) {
                        $new_url_arguments = "?" . $arg;
                    }
                    else {
                        $new_url_arguments .= "&" . $arg;
                    }
                    $found_arg{$arg} = 1;
                }
            }

            #
            # Replace argument list in URL
            #
            print "Clean_URL_Arguments\n  Old = $this_link\n" if $debug;
            $this_link =~ s/\?.*//g;
            $this_link .= $new_url_arguments;
            print "  New = $this_link\n" if $debug;
        }

        #
        # Add link to filtered set.
        #
        $filtered_links{$this_link} = 1;
    }

    #
    # Return list of filtered links
    #
    return(keys %filtered_links);
}

#***********************************************************************
#
# Name: Correct_Domain_Aliases
#
# Parameters: link_href - list of links from a document
#
# Description:
#
#   This function checks to see if a domain alias is used in
# a URL.  If one is found it is swithched to the primary domain.
#
# Returns:
#  list of links.
#
#***********************************************************************
sub Correct_Domain_Aliases {
    my (@link_href) = @_;

    my ($this_link, %filtered_links, $domain, $primary_domain);

    #
    # Check all links
    #
    foreach $this_link (@link_href) {
        #
        # Get domain name from link
        #
        #print "Correct_Domain_Aliases: $this_link\n" if $debug;
        $domain = $this_link;
        $domain =~ s/^http(s)?:\/\///gi;
        $domain =~ s/\/.*//g;

        #
        # Is this an alias domain name ?
        #
        if ( defined($domain_alias_map{$domain}) ) {
            #
            # Switch to primary domain
            #
            $primary_domain = $domain_alias_map{$domain};
            print "Correct $domain to $primary_domain in $this_link\n" if $debug;
            $this_link =~ s/\/$domain\//\/$primary_domain\//;
        }

        #
        # Have we seen this link already ?
        #
        if ( defined($filtered_links{$this_link}) ) {
            next;
        }

        $filtered_links{$this_link} = 1;
    }

    #
    # Return list of filtered links
    #
    return(keys %filtered_links);
}

#***********************************************************************
#
# Name: Matches_URL_Ignore_Pattern
#
# Parameters: url - a single URL
#
# Description:
#
#   This function checks to see if this URL matches any of the ignore
# patterns.
#
# Returns:
#   1 - matches a pattern
#   0 - does not match pattern
#
#***********************************************************************
sub Matches_URL_Ignore_Pattern {
    my ($url) = @_;

    my ($pattern);

    #
    # Strip off leading http to make the pattern match easier
    #
    $url =~ s/^http(s)?:\/\///i;

    #
    # See if this URL is one we will ignore (i.e. pretend it does not
    # exist).
    #
    foreach $pattern (@site_ignore_patterns) {
        if ( $url =~ /$pattern/ ) {
            #
            # URL contains an ignore pattern, don't include it
            # in the list.
            #
            print "  Ignoring this link, contains pattern \"$pattern\"\n" if $debug;
            return(1);
         }
    }

    #
    # Does not match any ignore pattern
    #
    return(0);
}

#***********************************************************************
#
# Name: Matches_Site_URL_Pattern
#
# Parameters: url - a single URL
#
# Description:
#
#   This function checks to see if this URL matches any of the site
# url patterns.
#
# Returns:
#   1 - matches site URL patterns
#   0 - does not match pattern
#
#***********************************************************************
sub Matches_Site_URL_Pattern {
    my ($url) = @_;

    my ($pattern);

    #
    # Strip off leading http to make the pattern match easier
    #
    $url =~ s/^http(s)?:\/\///i;

    #
    # See if this URL belongs to this site.
    #
    foreach $pattern (@site_url_patterns) {
        if ( $url =~ /^$pattern/ ) {
            #
            # URL is part of this site.
            #
            print "  Link is part of site, contains pattern \"$pattern\"\n" if $debug;
            return(1);
         }
    }

    #
    # Does not match any site patterns
    #
    print "  Link is not part of site\n" if $debug;
    return(0);
}

#***********************************************************************
#
# Name: Filter_Links
#
# Parameters: links - list of link objects
#
# Description:
#
#   This function checks the list of links to see if they are for
# the current site. 
#
# Returns:
#  list of links passing the filter.
#
#***********************************************************************
sub Filter_Links {
    my (@links) = @_;

    my ( $this_link, %filtered_links, @link_href );

    #
    # Get list of href values from links.
    #
    foreach (@links) {
        push (@link_href, $_->abs_url);
    }

    #
    # Clean up links, remove extra / characters and ensure it is well
    # formed.
    #
    @link_href = Correct_Link_Format(@link_href);

    #
    # Correct any domain aliases
    #
    @link_href = Correct_Domain_Aliases(@link_href);

    #
    # Correct link domain portion to match the
    # document language.
    #
    @link_href = Correct_Link_Domain_Language(@link_href);

    #
    # Clean up any URL argument list, remove duplicate variable
    # settings.
    #
    @link_href = Clean_URL_Arguments(@link_href);

    #
    # Check if links are part of the site
    #
    foreach $this_link (@link_href) {
        #
        # Have we seen this link before in the list or have we visited 
        # this link ?
        #
        if ( defined($filtered_links{$this_link}) ) {
            next;
        }

        #
        # See if this URL is one we will ignore (i.e. pretend it does not
        # exist).
        #
        if ( Matches_URL_Ignore_Pattern($this_link) ) {
            next;
        }

        #
        # See if URL is in our site.
        #
        print "Filter_Links: $this_link\n" if $debug;
        if ( Matches_Site_URL_Pattern($this_link) ) {
            $filtered_links{$this_link} = 1;
        }

        #
        # Did we pass the filter ?
        #
        if ( $debug ) {
            if ( defined($filtered_links{$this_link}) ) {
                print "Filter_Links: passes filter\n";
            }
            else {
                print "Filter_Links: fails filter\n";
            }
        }
    }

    #
    # Look for links from a <link> or <script> tag that references
    # a CSS or JavaScript file.  Look for links from <frame> and
    # <iframe> tags.
    # Even if these are not part of our site we include them as they
    # have a direct impact on this document.
    #
    foreach $this_link (@links) {
        #
        # Check <link> tags
        #
        if ( $this_link->link_type eq "link" ) {
            #
            # Is this a CSS link ?
            #
            if ( $this_link->href =~ /\.css$/ ) {
                #
                # Was the link excluded as not being part of our site ?
                #
                if ( ! Matches_Site_URL_Pattern($this_link->abs_url) ) {
                    print "Add css or js URL " . $this_link->abs_url .
                          " to filtered set\n" if $debug;
                    $filtered_links{$this_link->abs_url} = 1;
                }
            }
        }
        #
        # Check <script> tags
        #
        elsif ( $this_link->link_type eq "script" ) {
            #
            # Is this a JavaScript link ?
            #
            if ( $this_link->href =~ /\.js$/ ) {
                #
                # Was the link excluded as not being part of our site ?
                #
                if ( ! Matches_Site_URL_Pattern($this_link->abs_url) ) {
                    print "Add js URL " . $this_link->abs_url .
                          " to filtered set\n" if $debug;
                    $filtered_links{$this_link->abs_url} = 1;
                }
            }
        }
        #
        # Check <frame> or <iframe> tags
        #
        elsif ( ($this_link->link_type eq "frame") ||
                ($this_link->link_type eq "iframe") ) {
            #
            # Was the link excluded as not being part of our site ?
            #
            if ( ! Matches_Site_URL_Pattern($this_link->abs_url) ) {
                print "Add frame URL " . $this_link->abs_url .
                      " to filtered set\n" if $debug;
                $filtered_links{$this_link->abs_url} = 1;
            }
        }
    }

    #
    # Return list of filtered links
    #
    return(keys %filtered_links);
}

#***********************************************************************
#
# Name: Set_Initial_Crawl_List
#
# Parameters: urls_to_crawl - address of a list of URL to crawl
#             urls_to_crawl_map - address of a hash table
#             site_dir_e - English site domain & directory
#             site_dir_f - French site domain & directory
#             site_entry_e - English entry page
#             site_entry_f - French entry page
#
# Description:
#
#   This function adds the login & logout pages to the list of URLs
# to crawl for the site.  It also adds the pages to the crawl map
# so they won't be added again if a reference to them is found on another
# page.
#
#***********************************************************************
sub Set_Initial_Crawl_List {
    my ($urls_to_crawl, $urls_to_crawl_map, $site_dir_e, $site_dir_f,
        $site_entry_e, $site_entry_f) = @_;

    my ($page, $url);

    #
    # If French login/logout/entry pages are defined for this site, add them
    # to the list of URLs to crawl.
    #
    foreach $page (($logoutpagef, $site_entry_f, $loginpagef)) {
        if ( defined($page) ) {
            #
            # Is page a fully qualified URL (i.e. leading http) ?
            #
            if ( $page =~ /^http[s]?:/i ){
                push( @$urls_to_crawl, "$page");
                $$urls_to_crawl_map{"$page"} = 1;
            }
            else {
                if ( $page eq "/" ) {
                    $page = "";
                }
                if ( $page ne "" ) {
                    push( @$urls_to_crawl, "$site_dir_f/$page");

                    #
                    # Add URL to map with both the English & French site
                    # directory paths.
                    #
                    $$urls_to_crawl_map{"$site_dir_e/$page"} = 1;
                    $$urls_to_crawl_map{"$site_dir_f/$page"} = 1;
                }
                else {
                    push( @$urls_to_crawl, "$site_dir_f");

                    #
                    # Add URL to map with both the English & French site
                    # directory paths.
                    #
                    $$urls_to_crawl_map{"$site_dir_e"} = 1;
                    $$urls_to_crawl_map{"$site_dir_f"} = 1;
                }
            }
        }
    }

    #
    # If English login/logout/entry pages are defined for this site, add them
    # to the list of URLs to crawl.
    #
    foreach $page (($logoutpagee, $site_entry_e, $loginpagee)) {
        if ( defined($page) ) {
            #
            # Is page a fully qualified URL (i.e. leading http) ?
            #
            if ( $page =~ /^http[s]?:/i ){
                push( @$urls_to_crawl, "$page");
                $$urls_to_crawl_map{"$page"} = 1;
            }
            else {
                if ( $page eq "/" ) {
                    $page = "";
                }
                if ( $page ne "" ) {
                    push( @$urls_to_crawl, "$site_dir_e/$page");

                    #
                    # Add URL to map with both the English & French site
                    # directory paths.
                    #
                    $$urls_to_crawl_map{"$site_dir_e/$page"} = 1;
                    $$urls_to_crawl_map{"$site_dir_f/$page"} = 1;
                }
                else {
                    push( @$urls_to_crawl, "$site_dir_e");

                    #
                    # Add URL to map with both the English & French site
                    # directory paths.
                    #
                    $$urls_to_crawl_map{"$site_dir_e"} = 1;
                    $$urls_to_crawl_map{"$site_dir_f"} = 1;
                }
            }
        }
    }

    #
    # Dump initial crawl list.
    #
    if ( $debug ) {
        print "Initial crawl URL list\n";
        foreach (@$urls_to_crawl) {
            print "   " . $_ . "\n";
        }
    }
}

#***********************************************************************
#
# Name: Get_Login_Form
#
# Parameters: url - url of login page
#             resp - HTTP::Response object
#
# Description:
#
#   This function looks for the login form on the current page.
# If found, it returns a HTML::Form object for that form.
#
# Returns:
#    form - HTML::Form object
#
#***********************************************************************
sub Get_Login_Form {
    my ($url, $resp) = @_;

    my (@forms, $this_form, $login_form, $name);

    #
    # Parse forms from content
    #
    print "Get forms from $url\n" if $debug;
    @forms = HTML::Form->parse($resp);

    #
    # If we don't have any forms, return undefind value
    #
    if ( @forms > 0 ) {
        #
        # If we have a login form name, look for it in the list
        # of forms.
        #
        if ( defined($login_form_name) && ($login_form_name ne "") ) {
            print "Look for form with name or id = \"$login_form_name\"\n" if $debug;
            foreach $this_form (@forms) {
                #
                # Check form name attribute
                #
                if ( defined($this_form->attr("name")) ) {
                    $name = $this_form->attr("name");
                    print "Found form name = \"$name\"\n" if $debug;
                    if ( $name eq $login_form_name ) {
                        $login_form = $this_form;
                        print "Found login form\n" if $debug;
                        last;
                    }
                }

                #
                # Check form id attribute
                #
                if ( defined($this_form->attr("id")) ) {
                    $name = $this_form->attr("id");
                    print "Found form id = \"$name\"\n" if $debug;
                    if ( $name eq $login_form_name ) {
                        $login_form = $this_form;
                        print "Found login form\n" if $debug;
                        last;
                    }
                }
            }
        }
        else {
            #
            # No form name specified, take the first form in the list
            #
            $login_form = $forms[0]; 
            print "No login form name specified, use first form  id = " .
                  $login_form->attr("id") . " name = " .
                  $login_form->attr("name") . "\n" if $debug;
        }
    }
    else {
        print "No forms on page\n" if $debug;
    }

    #
    # Return form object
    #
    return($login_form);
}

#***********************************************************************
#
# Name: Call_Callback_Functions
#
# Parameters: url - URL of document
#             referer_url - referer URL
#             resp - HTTP::Response object
#
# Description:
#
#   This function calls on the various callback functions for either
# content or an HTTP::Response object.
#
#***********************************************************************
sub Call_Callback_Functions {
    my ($url, $referer_url, $resp) = @_;

    my ($content, $content_type, $header);

    #
    # Determine content type
    #
    $header = $resp->headers;
    $content_type = $header->content_type;

    #
    # If there is a http response callback function, call it.
    #
    if ( defined($http_response_callback_function) ) {
        print "Call http response callback function\n" if $debug;
        if ( &$http_response_callback_function($url,
             $referer_url, $content_type, $resp) == 1 ) {
            #
            # Exit crawler
            #
            return(0);
        }
    }

    #
    # If there is a content callback function, call it.
    #
    if ( defined($content_callback_function) ) {
        print "Call http content callback function\n" if $debug;
        $content = Crawler_Decode_Content($resp);
        if ( &$content_callback_function($url,
             $referer_url, $content_type, $content) == 1 ) {
            #
            # Exit crawler
            #
            return(0);
        }
    }

    #
    # Return success
    #
    return(1);
}

#***********************************************************************
#
# Name: Submit_To_Interstitial_Page
#
# Parameters: url - url of login page
#             form - HTMP::Form object
#
# Description:
#
#   This function performs a form submission to an interstitial page
# (usually after a login or logout).
#
# Returns:
#    resp - HTTP::Response object
#    url - repsonse URL
#
#***********************************************************************
sub Submit_To_Interstitial_Page {
    my ($referer_resp, $referer_url) = @_;

    my (@forms, $form, $req, $content, $resp, $url, $header);

    #
    # Check for UTF-8 content
    #
    $content = Crawler_Decode_Content($resp);

    #
    # Parse forms from content of interstitial page
    #
    print "Get forms from $referer_url\n" if $debug;
    #print "Content = $content\n";
    @forms = HTML::Form->parse($referer_resp);
    if ( @forms > 0 ) {
        #
        # Take first form, assume it is the one to submit the page.
        #
        $form = $forms[0];

        #
        # Print form inputs
        #
        my @inputs = $form->inputs;
        print "Form inputs\n" if $debug;
        foreach (@inputs) {
            print "name = " . $_->name() . "\n" if $debug;
            print "type = " . $_->type() . "\n" if $debug;
        }

        #
        # Click the 'submit' button
        #
        print "Submit_To_Interstitial_Page, click first submit button on page $referer_url\n" if $debug;
        print "Form name is " . $form->attr("name") . "\n" if $debug;
        $req = $form->click();

        #
        # POST the form results
        #
        print "POST the interstitial form\n" if $debug;
        $req->referrer("$referer_url");
        #print "Request  = " . $req->as_string . "\n" if $debug;
        sleep(1);
        $resp = $user_agent->request($req);

        #
        # Do we have a redirect ?
        #
        if ( $resp->is_redirect ) {
            print "Form submit redirect, code = " . $resp->code . "\n" if $debug;
            $header = $resp->headers;
            $url = $header->header("Location");
            print "Get redirected URL $url\n" if $debug;
            $resp = $user_agent->get($url);
        }

        #
        # Get response URL
        #
        if ( $resp->is_success ) {
            $url = $resp->base;
            print "URL after interstitial POST is $url\n" if $debug;

            #
            # Call http response or content callbacks.
            #
            if ( Call_Callback_Functions($url, $referer_url, $resp) ) {
                #
                # Callbacks succeed, return respone object to caller
                #
                return($resp, $url);
            }
        }
        else {
            #
            # Error in form submit
            #
            print "Error in submitting to form on interstitial page\n" if $debug;
            print "Error code is " . $resp->code . "\n" if $debug;
            print "      Error is " . $resp->status_line . "\n" if $debug;
        }
    }
    else {
        #
        # No forms found
        #
        print "No forms on interstitial page $referer_url\n" if $debug;
    }

    #
    # If we got here, there was some sort of error, return undefined to
    # the caller.
    #
    return;
}

#***********************************************************************
#
# Name: Do_Site_Login
#
# Parameters: url - url of login page
#             form - HTMP::Form object
#
# Description:
#
#   This function performs a login by clicking the 'submit' button.
# It returns the URL after the form submission.
#
# Returns:
#    resp - HTTP::Response object
#    response_url - url of page after login
#
#***********************************************************************
sub Do_Site_Login {
    my ($url, $form) = @_;

    my ($req, $resp, $response_url, $header, $count);
    my ($protocol, $domain, $file_path, $query, $new_url);
    my ($dir_path, $action_url);

    #
    # Get components of login URL
    #
    ($protocol, $domain, $file_path, $query, $new_url) = 
        URL_Check_Parse_URL($url);
    $dir_path = dirname($file_path);
    if ( $dir_path eq "." ) {
        $dir_path = "";
    }

    #
    # Get the form action URL
    #
    $action_url = $form->action();
    print "Form action URL = $action_url\n" if $debug;

    #
    # Does URL have a leading http ?
    #
    if ( ! ($action_url =~ /^http/) ) {
        #
        # If we have a leading //, use protocol from
        # previous request.
        #
        if ( $action_url =~ /^\/\// ) {
            print "Add protocol to URL\n" if $debug;
            $action_url = "$protocol$action_url";
        }
        else {
            #
            # Add protocol and domain from previous request.
            #
            print "Add protocol & domain to URL\n" if $debug;
            $action_url = "$protocol//$domain$action_url";
        }
    }

    #
    # Click the 'submit' button
    #
    print "Do_Site_Login, click first submit button\n" if $debug;
    $req = $form->click();

    #
    # POST the form results
    #
    print "POST the login form\n" if $debug;
    $req->referrer("$url");
    $req->header(Accept => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
    print "Request  = " . $req->as_string . "\n" if $debug;
    $resp = $user_agent->request($req);
    print "Response  = " . $resp->as_string . "\n" if $debug;

    #
    # Do we have a redirect ?
    #
    while ( $resp->is_redirect ) {
        #
        # Get redirected location
        #
        print "Form submit redirect, code = " . $resp->code . "\n" if $debug;
        $header = $resp->headers;
        $response_url = $header->header("Location");
        print "Redirect location = $response_url\n" if $debug;

        #
        # Does URL have a leading http ?
        #
        if ( ! ($response_url =~ /^http/) ) {
            #
            # If we have a leading //, use protocol from
            # previous request.
            #
            if ( $response_url =~ /^\/\// ) {
                print "Add protocol to received URL\n" if $debug;
                $response_url = "$protocol$response_url";
            }
            else {
                #
                # Add protocol and domain from previous request.
                #
                if ( $response_url =~ /^\// ) {
                    print "Add protocol & domain to received URL\n" if $debug;
                    $response_url = "$protocol//$domain$response_url";
                }
                else {
                    #
                    # No directory component in redirect URL, use
                    # directory from previous request.
                    #
                    print "Add protocol, domain & directory to received URL\n" if $debug;
                    if ( $dir_path ne "" ) {
                        $response_url = "$protocol//$domain/$dir_path/$response_url";
                    }
                    else {
                        $response_url = "$protocol//$domain/$response_url";
                    }
                }
            }
        }

        #
        # Get components of login URL
        #
        ($protocol, $domain, $file_path, $query, $new_url) = 
            URL_Check_Parse_URL($response_url);
        $dir_path = dirname($file_path);
        if ( $dir_path eq "." ) {
            $dir_path = "";
        }

        #
        # Get redirected page
        #
        print "Get redirected URL $response_url\n" if $debug;
        $req = new HTTP::Request(GET => $response_url);
        $req->header(Accept => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
        print "Request  = " . $req->as_string . "\n" if $debug;
        $resp = $user_agent->request($req);
        #print "Response  = " . $resp->as_string . "\n" if $debug;
    }

    #
    # Get response URL
    #
    if ( $resp->is_success || $resp->is_redirect ) {
        print "URL after login POST is $response_url\n" if $debug;

        #
        # Call http response or content callbacks.
        #
        if ( ! Call_Callback_Functions($response_url, $url, $resp) ) {
            #
            # Exit crawler
            #
            return;
        }

        #
        # Are we expecting interstitial pages after the login ?
        #
        for ($count = 0; $count < $login_interstitial_count; $count++) {
            print "Submit to interstitial page # $count or $login_interstitial_count\n" if $debug;
            ($resp, $response_url) = Submit_To_Interstitial_Page($resp, $response_url);
            if ( ! defined($resp) ) {
                return;
            }
        }
    }
    else {
        #
        # Form submission failed.
        #
        if ( $debug ) {
            print "Error in login form submission, error code is " . 
                   $resp->code . "\n";
            print "      Error is " . $resp->status_line . "\n";
        }
    }

    #
    # Return response object and URL
    #
    return($resp, $response_url);
}

#***********************************************************************
#
# Name: Is_Site_Login
#
# Parameters: url - url of current page
#             site_dir_e - English site domain & directory
#             site_dir_f - French site domain & directory
#             resp - HTTP::Response object
#             link_href - list of links from the URL
#
# Description:
#
#   This function checks to see if the current page is one
# of the login pages.  If so it calls the login callback function
# to have the calling application provide the login credentials.
# After the login form is submitted, if we are redirected to another
# page, this new page is added to the links to crawl.
#
#***********************************************************************
sub Is_Site_Login {
    my ($url, $site_dir_e, $site_dir_f, $resp, @link_href) = @_;

    my ($pattern, $form, $response_url, $login_resp, $header, $pattern_url);

    #
    # Strip off leading http to make the pattern match easier
    #
    $pattern_url = $url;
    $pattern_url =~ s/^http(s)?:\/\///i;

    #
    # See if this URL matches one of the login patterns
    #
    foreach $pattern (@login_url_patterns) {
        if ( $pattern_url eq $pattern ) {
            #
            # URL is a login page
            #
            print "  Link is login page of site, matches pattern \"$pattern\"\n" if $debug;

            #
            # Get login form object from the page
            #
            $form = Get_Login_Form($url, $resp);

            #
            # Did we find the login form ?
            #
            if ( defined($form) ) {
                #
                # Call login callback function if one is defined
                #
                if ( defined($login_callback_function) ) {
                    print "Call login callback function\n" if $debug;
                    &$login_callback_function($url, $form);

                    #
                    # Submit the login form and get URL of page after
                    # login.
                    #
                    ($login_resp, $response_url) = Do_Site_Login($url, $form);
                    if ( defined($login_resp) && ($login_resp->is_success) ) {
                        print "Page after login is $response_url\n" if $debug;
                        push(@link_href, $response_url);
                    }
                }
                else {
                    print "No login callback function defined\n" if $debug;
                }
                last;
            }
            else {
                #
                # Did not find login form
                #
                print "Did not find login form $login_form_name in $url\n" if $debug;
            }
        }
    }

    #
    # Return list of link hrefs
    #
    return($response_url, @link_href);
}

#***********************************************************************
#
# Name: Entry_Pages_Valid
#
# Parameters: site_entry_e - English entry page URL
#             site_entry_f - French entry page URL
#
# Description:
#
#   This function attempts to GET both the English & French entry
# pages.  This is done to ensure they are accessible before we start
# crawling the site.
#
# Returns:
#   1 - Entry pages valid
#   0 - Entry pages invalid
#
#***********************************************************************
sub Entry_Pages_Valid {
    my ($site_entry_e, $site_entry_f) = @_;

    my ($rewritten_url, $resp);

    #
    # Get English entry page
    #
    ($rewritten_url, $resp) = Crawler_Get_HTTP_Response($site_entry_e, "");

    #
    # If successful, get the French entry page
    #
    if ( $resp->is_success ) {
        ($rewritten_url, $resp) = Crawler_Get_HTTP_Response($site_entry_f, "");

        #
        # If successful, return True
        #
        if ( $resp->is_success ) {
            return(1);
        }
        else {
            print "Failed to get French entry page\n  --> $site_entry_f\n" if $debug;
        }
    }
    else {
        print "Failed to get English entry page\n  --> $site_entry_e\n" if $debug;
    }

    #
    # Return failure
    #
    return(0);
}

#***********************************************************************
#
# Name: Get_Robots_Txt_Details
#
# Parameters: site_entry_e - English site directory
#
# Description:
#
#   This function attempts to GET a robots.txt file for the site.  If
# found, the details of the page are returned.
# crawling the site.
#
# Returns:
#   url - robots.txt file url
#   content_type - mime type
#   last_modified - last modification date
#   size - size of file
#
#***********************************************************************
sub Get_Robots_Txt_Details {
    my ($site_dir_e) = @_;

    my ($url, $content_type, $last_modified, $size);
    my ($content, $resp, $resp_url, $protocol, $domain, $file_path, $query);
    my ($day, $month, $year, $header, $rewritten_url, $new_url);

    #
    # Add trailing / to site directory if it does not already exist.
    #
    if ( ! ( $site_dir_e =~ /\/$/ ) ) {
        $site_dir_e .= "/";
    }

    #
    # Get the protocol and domain from site directory.
    #
    ($protocol, $domain, $file_path, $query, $new_url) =
        URL_Check_Parse_URL($site_dir_e);

    #
    # Construct URL for robots.txt and attempt to get it
    #
    $url = "$protocol//$domain/robots.txt";
    print "Attempting to get robots.txt at $url\n" if $debug;
    ($rewritten_url, $resp) = Crawler_Get_HTTP_Response($url, "");

    #
    # Did we get a robots.txt file ?
    #
    if ( $resp->is_success ) {
        #
        # Get details
        #
        print "Found robots.txt at $rewritten_url\n" if $debug;
        $url = $rewritten_url;
        $header = $resp->headers;
        $content_type = $header->content_type;
        $size = length($resp->content);

        #
        # Get last modified, if not found use today's date
        #
        if ( defined($header->last_modified) ) {
            ($day, $month, $year) = (localtime($header->last_modified))[3,4,5];
            $year += 1900;
            $month++;
            $last_modified = sprintf("%04d-%02d-%02d", $year,$month, $day);
        }
        else {
            $last_modified = $yyyy_mm_dd_today;
        }
    }
    else {
        #
        # Set url to empty string to indicate no robots.txt file
        #
        $url = "";
    }

    #
    # Return robots.txt details
    #
    return($url, $content_type, $last_modified, $size, $resp);
}

#***********************************************************************
#
# Name: Content_Checksum
#
# Parameters: resp - HTTP::Response object
#
# Description:
#
#   This function calculates a checksum for the content.  If the content
# is HTML, the checksum is for the content after removing the HTML tags.
#
# Returns:
#   checksum
#
#***********************************************************************
sub Content_Checksum {
    my ($resp) = @_;

    my ($checksum, $content, $header, $content_type);

    #
    # Get content type
    #
    $header = $resp->headers;
    $content_type = $header->content_type;

    #
    # Check for UTF-8 content
    #
    $content = Crawler_Decode_Content($resp);

    #
    # Determine content type
    #
    if ( $content_type =~ /text\/html/ ) {
        #
        # Extract text from HTML markup
        #
        print "Content_Checksum: Extract text from HTML\n" if $debug;
        $content = TextCat_Extract_Text_From_HTML(\$content);
        print "Extracted content length = " . length($content) . "\n" if $debug;
    }
    else {
        #
        # Not text/html, use content from response object.
        #
        print "Content_Checksum: Non text/html content\n" if $debug;
    }

    #
    # Get checksum for the content and return it.
    #
    $checksum = md5_hex(encode_utf8($content));
    print "Content_Checksum: Checksum = $checksum\n" if $debug;
    return($checksum);
}

#***********************************************************************
#
# Name: Set_Crawler_Options
#
# Parameters: crawler_options - hash table of options
#
# Description:
#   This function sets a number of crawler options.
#
#***********************************************************************
sub Set_Crawler_Options {
    my ($crawler_options) = @_;

    #
    # Check for maximum crawl depth
    #
    if ( defined($crawler_options)
         && defined($$crawler_options{"crawl_depth"})) {
        $max_crawl_depth = $$crawler_options{"crawl_depth"};
    }
    else {
        $max_crawl_depth = 0;
    }

    #
    # Check for maximum number of URLs to return
    #
    if ( defined($crawler_options)
         && (defined($$crawler_options{"max_urls_to_return"})) ) {
        $max_urls_to_return = $$crawler_options{"max_urls_to_return"};
    }
    else {
        $max_urls_to_return = 0;
    }
}

#***********************************************************************
#
# Name: Crawl_Site
#
# Parameters: site_dir_e - English site domain & directory
#             site_dir_f - French site domain & directory
#             site_entry_e - English entry page
#             site_entry_f - French entry page
#             crawler_options - address of a hash table of options
#             url_list - reference to list to contain list of site URLs
#             url_type - reference to list to contain URL mime type
#             url_last_modified - reference to list to contain URL
#                   last modified date
#             url_size - reference to list to contain URL document size
#             url_referer - reference to list to contain URL referer
#
# Description:
#
#   This function runs the validate TQA check tool on the
# supplied URL.  It then updates the database with the results
# of the tool.
#
# Returns:
#    0 - crawl successful
#    1 - crawl failed
#
#***********************************************************************
sub Crawl_Site {
    my ( $site_dir_e, $site_dir_f, $site_entry_e, $site_entry_f, 
         $crawler_options, $url_list, $url_type, $url_last_modified,
         $url_size, $url_referer ) = @_;

    my (@links, $link, @link_href, $referer);
    my ($resp, $content, $url, %url_referer_map, @urls_to_crawl);
    my ($n_links, $i, $header, $day, $month, $year, $last_modified);
    my ($rewritten_url, %urls_to_crawl_map, $content_type);
    my (%url_list_map, %url_checksum_map, $checksum, $list_length);
    my ($size, $lang, $base, $login_url, $crawl_depth);
    my ($logged_in) = 0;

    #
    # Set crawler options
    #
    Set_Crawler_Options($crawler_options);

    #
    # Initialize lists to empty lists
    #
    @$url_list = ();
    @$url_type = ();
    @$url_last_modified = ();
    @$url_size = ();
    @$url_referer = ();

    #
    # Initialize crawler variables.
    #
    Initialize_Crawler_Variables($site_dir_e, $site_dir_f);
    print "Crawl_Site: English entry = $site_dir_e/$site_entry_e\n" if $debug;
    print "            French  entry = $site_dir_f/$site_entry_f\n" if $debug;

    #
    # Check for a robots.txt file
    #
    ($url, $content_type, $last_modified, $size, $resp) = 
        Get_Robots_Txt_Details($site_dir_e);
    if ( $url ne "" ) {
        #
        # We have a robots.txt file, save the details
        #
        push(@$url_list, $url);
        push(@$url_type, $content_type);
        push(@$url_last_modified, $last_modified);
        push(@$url_size, $size);
        push(@$url_referer, "");

        #
        # Call http response or content callbacks.
        #
        if ( ! Call_Callback_Functions($url, "", $resp) ) {
                #
                # Exit crawler
                #
                return;
        }
    }

    #
    # Check that we can get to the English & French entry pages.
    #
    if ( ! Entry_Pages_Valid("$site_dir_e/$site_entry_e",
                             "$site_dir_f/$site_entry_f") ) {
        return(1);
    }

    #
    # Set initial page crawl list.
    #
    Set_Initial_Crawl_List(\@urls_to_crawl, \%urls_to_crawl_map,
                           $site_dir_e, $site_dir_f, $site_entry_e,
                           $site_entry_f);

    #
    # Loop until we have finished all URLs that can be crawled
    #
    while ( (! $abort_crawl) && (@urls_to_crawl) ) {

        #
        # Dump initial crawl list.
        #
        if ( $debug ) {
            print "Crawl URL list\n";
            foreach (@urls_to_crawl) {
                print "   " . $_ . "\n";
            }
        }

        #
        # Take first URL in the list
        #
        $list_length = @urls_to_crawl;
        print "URLs to crawl list length is $list_length\n" if $debug;
        $url = pop(@urls_to_crawl);
        $urls_to_crawl_map{$url} = 1;
        
        #
        # Determine the crawl depth if this URL has a referrer
        #
        if ( defined($url_referer_map{$url}) ) {
            $referer = $url_referer_map{$url};
            $crawl_depth = $url_list_map{$referer} + 1;
        }
        else {
            #
            # Must be a top level URL
            #
            $crawl_depth = 0;
        }
        print "Depth $crawl_depth url = $url\n" if $debug;

        #
        # Get HTTP::Response object for the URL.
        #
        ($rewritten_url, $resp) = Crawler_Get_HTTP_Response($url, 
                                                       $url_referer_map{$url});

        #
        # If the response URL is not the same as the requested URL,
        # it is possible that we should now ignore this URL.
        #
        if ( $rewritten_url ne $url ) {
            #
            # See if this URL is one we will ignore (i.e. pretend it does not
            # exist).
            #
            if ( Matches_URL_Ignore_Pattern($rewritten_url) ) {
                print "Rewritten URL $rewritten_url matches URL ignore patterns\n" if $debug;
                next;
            }
            #
            # Does the URL not match one of the site URL patterns ?
            #
            if ( ! Matches_Site_URL_Pattern($rewritten_url) ) {
                #
                # Don't ignore CSS and JavaScript files.  
                #
                if ( ( ! ($rewritten_url =~ /\.css$/) ) &&
                     ( ! ($rewritten_url =~ /\.js$/) ) ) {
                    print "Rewritten URL $rewritten_url does not match site patterns\n" if $debug;
                    next;
                }
            }
        }

        #
        # Did we get the document ?
        #
        if ( defined($resp) && $resp->is_success ) {
            # 
            # Do we already have this URL in the list ?
            # 
            if ( defined($url_list_map{$url}) ) {
                next;
            } 

            #
            # Get checksum for the content
            #
            $checksum = Content_Checksum($resp);

            #
            # Have we seen a document with the same checksum before ?
            # there may be multiple URLs for the same document.
            #
            if ( defined($url_checksum_map{$checksum}) ) {
                print "Duplicate content, previously seen at\n  --> " .
                      $url_checksum_map{$checksum} . "\n" if $debug;
                next;
            }
            else {
                $url_checksum_map{$checksum} = $rewritten_url;
                $url_checksum_map{$checksum} = $url;
                $url_list_map{$rewritten_url} = $crawl_depth;
            }

            #
            # Try and determine the language of the URL.
            #
            $lang = URL_Check_GET_URL_Language($rewritten_url);

            #
            # Add URL and its attributes to the lists.
            #
            $header = $resp->headers;
            push (@$url_list, $url);
            $url_list_map{$url} = $crawl_depth;
            $content_type = $header->content_type;
            push (@$url_type, $content_type);

            #
            # Get last modified, if not found use today's date
            #
            if ( defined($header->last_modified) ) {
                ($day, $month, $year) = (localtime($header->last_modified))[3,4,5];
                $year += 1900;
                $month++;
                $last_modified = sprintf("%04d-%02d-%02d", $year,$month, $day);
            }
            else {
                $last_modified = $yyyy_mm_dd_today;
            }

            #
            # Save URL attributes in lists
            #
            push (@$url_last_modified, $last_modified);
            push (@$url_size, length($resp->content));
            push (@$url_referer, $url_referer_map{$url});

            #
            # Call http response or content callbacks.
            #
            if ( ! Call_Callback_Functions($url,
                      $url_referer_map{$url}, $resp) ) {
                    #
                    # Exit crawler
                    #
                    return;
            }

            #
            # Have we reached the maximum number of URLs to return ?
            #
            if ( ($max_urls_to_return > 0) &&
                 ($max_urls_to_return <= @$url_list) ) {
                print "Reached maximum number of URLs to return $max_urls_to_return\n" if $debug;
                last;
            }
            
            #
            # Have we reached the crawl depth ? if so we don't extract links
            # from this page.
            #
            if ( ($max_crawl_depth > 0 ) && ($crawl_depth >= $max_crawl_depth) ) {
                print "Reached crawl depth, skip URL\n" if $debug;
                next;
            }

            #
            # Check for UTF-8 content
            #
            $content = Crawler_Decode_Content($resp);

            #
            # If this document is of type 'text/html', we can extract
            # links from it. If this is css content, we can extract
            # image references
            #
            if ( ($content_type =~ /text\/html/) ||
                 ($content_type =~ /text\/css/) ) {
                #
                # Get links from page
                #
                print "Crawl_Site: extract links from $url\n" if $debug;
                if ( $content_type =~ /text\/css/ ) {
                    $base = $rewritten_url;
                }
                else {
                    #
                    # Determine the abse URL for any relative URLs.  Usually 
                    # this is the base field from the HTTP Response object
                    # (Location field in HTTP packet).  If the response code
                    # is 200 (OK), we don't use the the base field in case 
                    # the Location field is set (which it should not be).
                    #
                    if ( $resp->code == 200 ) {
                        $base = $rewritten_url;
                    }
                    else {
                        $base = $resp->base;
                    }
                }
                @links = Extract_Links($rewritten_url, $base,
                                       $lang, $content_type, \$content);

                #
                # Filter the links to remove any that are not from
                # this site or those we have already visited.
                #
                @link_href = Filter_Links(@links);

                #
                # Check to see if this is a login page, if it is perform
                # a login.  If we get directed to another page after
                # the login, that new page must be added to the crawl
                # list.
                #
                ($login_url, @link_href) = Is_Site_Login($url, $site_dir_e,
                                                         $site_dir_f,
                                                         $resp, @link_href);

                #
                # If we have a login URL, add it to the list of URL's
                # that have already been crawled
                #
                if ( defined($login_url) && 
                     (! defined($url_list_map{$login_url})) ) {
                    $url_list_map{$login_url} = 0;
                    push (@$url_list, $login_url);
                }

                #
                # Set the referer for all links found in this document
                #
                foreach (@link_href) {
                    if ( ! defined($url_referer_map{$_}) ) {
                        $url_referer_map{$_} = $rewritten_url;
                    }

                    #
                    # Is the URL already in one of the lists being
                    # processed ?
                    #
                    if ( defined($urls_to_crawl_map{$_}) ) {
                        print "Not adding to crawl list \"$_\"\n" if $debug;
                    }
                    elsif ( defined($url_list_map{$_}) ) {
                        print "Not adding to crawl list \"$_\"\n" if $debug;
                    }
                    else {
                        push (@urls_to_crawl, $_);
                        $urls_to_crawl_map{$_} = 1;
                        print "Add to crawl list \"$_\"\n" if $debug;
                    }
                }
            }
            else {
                print "Not crawling $rewritten_url, content type = $content_type\n" if $debug;
            }
        }
        else {
            if ( defined($resp) ) {
                print "Failed to GET $url, error is " . $resp->code .
                      "\n" if $debug;
            }
            else {
                print "Failed to GET $url, error is undefined resp object\n" if $debug;
            }
        }
    }
    print "End of URLs to crawl list\n" if $debug;

    #
    # Now that we have completed the site crawl, erase any login/logout
    # setting we may have (so the next crawl does not get confused using
    # this sites login/logout pages).
    #
    $loginpagee = "";
    $logoutpagee = "";
    $loginpagef = "";
    $logoutpagef = "";
    $login_domain_e = "";
    $login_domain_f = "";

    #
    # Return abort status
    #
    return($abort_crawl);
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
    my (@package_list) = ("extract_links", "textcat", "url_check");

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

