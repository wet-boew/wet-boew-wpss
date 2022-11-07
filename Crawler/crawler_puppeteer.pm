#***********************************************************************
#
# Name:   crawler_puppeteer.pm
#
# $Revision: 2417 $
# $URL: svn://10.36.148.185/WPSS_Tool/Crawler/Tools/crawler_puppeteer.pm $
# $Date: 2022-11-07 07:51:18 -0500 (Mon, 07 Nov 2022) $
#
# Description:
#
#   This file contains routines to interact with the puppeteer module to drive
# a headless Chrome browser.
#
# Public functions:
#     Crawler_Puppeteer_Clear_Cache
#     Crawler_Puppeteer_Config
#     Crawler_Puppeteer_Debug
#     Set_Crawler_Puppeteer_Language
#     Crawler_Puppeteer_Start_Markup_Server
#     Crawler_Puppeteer_Stop_Markup_Server
#     Crawler_Puppeteer_Page_Markup
#     Crawler_Puppeteer_User_Agent_Details
#
# Terms and Conditions of Use
#
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is
# distributed under the MIT License.
#
# MIT License
#
# Copyright (c) 2019 Government of Canada
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

package crawler_puppeteer;

use strict;
use Encode;
use File::Basename;
use File::Path qw(remove_tree);
use LWP::UserAgent;
use File::Temp qw/ tempfile tempdir /;
use IO::Socket::INET;
use IO::Socket::SSL qw( SSL_VERIFY_NONE );

my $have_threads = eval 'use threads; 1';
if ( $have_threads ) {
    $have_threads = eval 'use threads::shared; 1';
}

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Crawler_Puppeteer_Clear_Cache
                  Crawler_Puppeteer_Config
                  Crawler_Puppeteer_Debug
                  Set_Crawler_Puppeteer_Language
                  Crawler_Puppeteer_Start_Markup_Server
                  Crawler_Puppeteer_Stop_Markup_Server
                  Crawler_Puppeteer_Page_Markup
                  Crawler_Puppeteer_User_Agent_Details
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);
my ($puppeteer_user_dir, $puppeteer_server_last_arg);
my ($puppeteer_server_cmnd, $puppeteer_chrome_min_version);
my ($debug) = 0;
my ($markup_server_port_start) = "8000";
my ($markup_server_port) = $markup_server_port_start;
my ($retry_page) = 0;
my ($default_windows_chrome_path, $userprofile);
my ($user_agent_name) = "Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) WPSS_Tool";
my ($default_user_agent_check_url) = "https://www.google.com/";

my ($headless_chrome_installed, $chrome_path, $puppeteer_install_error);
my ($user_agent_software_versions);
if ( $have_threads ) {
    share(\$headless_chrome_installed);
    share(\$chrome_path);
    share(\$puppeteer_install_error);
    share(\$user_agent_software_versions);
}

my ($markup_server_running) = 0;

#
# String table for error strings.
#
my %string_table_en = (
    "Chrome not installed, headless chrome not available", "Chrome not installed, headless chrome not available",
    "Chrome version below minimum value",                  "Chrome version below minimum value",
    "No puppeteer configuration paramters supplied",       "No puppeteer configuration paramters supplied",
    "Node not installed, headless chrome not available",   "Node not installed, headless chrome not available",
    "Puppeteer-core module not installed",                 "Puppeteer-core module not installed",
);

#
# String table for error strings (French).
#
my %string_table_fr = (
    "Chrome not installed, headless chrome not available", "Chrome not installed, headless chrome not available",
    "Chrome version below minimum value",                  "Version Chrome inférieure à la valeur minimale",
    "No puppeteer configuration paramters supplied",       "No puppeteer configuration paramters supplied",
    "Node not installed, headless chrome not available",   "Node not installed, headless chrome not available",
    "Puppeteer-core module not installed",                 "Module Puppeteer-core non installé",
);

#
# Default messages to English
#
my ($string_table) = \%string_table_en;

#**********************************************************************
#
# Name: Set_Crawler_Puppeteer_Language
#
# Parameters: language
#
# Description:
#
#   This function sets the language of error messages generated
# by this module.
#
#***********************************************************************
sub Set_Crawler_Puppeteer_Language {
    my ($language) = @_;

    #
    # Check for French language
    #
    if ( $language =~ /^fr/i ) {
        print "Set_Crawler_Puppeteer_Language, language = French\n" if $debug;
        $string_table = \%string_table_fr;
    }
    else {
        #
        # Default language is English
        #
        print "Set_Crawler_Puppeteer_Language, language = English\n" if $debug;
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

#********************************************************
#
# Name: Crawler_Puppeteer_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Crawler_Puppeteer_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: Crawler_Puppeteer_Clear_Cache
#
# Parameters: cookie_file - path to cookie jar file
#
# Description:
#
#   This function clears the user data directory cache for Puppeteer.
#
#***********************************************************************
sub Crawler_Puppeteer_Clear_Cache {
    my ($cookie_file) = @_;
    
    my ($error, $diag, $file, $message);

    #
    # If we have a running markup server, stop it.
    #
    print "Crawler_Puppeteer_Clear_Cache\n" if $debug;
    if ( $markup_server_running ) {
        Crawler_Puppeteer_Stop_Markup_Server();
    }

    #
    # Remove the user data directory cache
    #
    if ( -d $puppeteer_user_dir ) {
        print "Remove user data directory cache $puppeteer_user_dir\n" if $debug;
        remove_tree($puppeteer_user_dir, {error => \$error});
    
        #
        # Check for possible errors
        #
        if ( @$error ) {
            print "Error: Failed to remove_tree $puppeteer_user_dir\n";
            for $diag (@$error) {
                ($file, $message) = %$diag;
                if ($file eq '') {
                    print "general error: $message\n";
                }
                else {
                    print "problem unlinking $file: $message\n";
                }
            }
        }
    }
}

#***********************************************************************
#
# Name: Crawler_Puppeteer_Config
#
# Parameters: config_vars
#
# Description:
#
#   This function sets a number of package configuration values.
# The values are passed in as a hash table.
#
#***********************************************************************
sub Crawler_Puppeteer_Config {
    my (%config_vars) = @_;

    my ($key, $value);

    #
    # Check for known configuration values
    #
    while ( ($key, $value) = each %config_vars ) {
        #
        # Check for known configuration variables
        #
        if ( $key eq "markup_server_port" ) {
            $markup_server_port_start = $value;
        }
        elsif ( $key eq "default_windows_chrome_path" ) {
            $default_windows_chrome_path = $value;
        }
        elsif ( $key eq "puppeteer_chrome_min_version" ) {
            $puppeteer_chrome_min_version = $value;
        }
    }
}

#***********************************************************************
#
# Name: Crawler_Puppeteer_Stop_Markup_Server
#
# Parameters: none
#
# Description:
#
#   This function stops the markup server process.
#
#***********************************************************************
sub Crawler_Puppeteer_Stop_Markup_Server {

    my ($req, $user_agent, $resp, $url);

    #
    # Build request string
    #
    print "Crawler_Puppeteer_Stop_Markup_Server\n" if $debug;
    $url = "http://127.0.0.1:$markup_server_port/EXIT";
    print "GET $url\n" if $debug;
    $req = HTTP::Request->new(GET => $url);

    #
    # Send the exit to the markup server
    #
    $user_agent = LWP::UserAgent->new;
    $user_agent->timeout(2);
    $resp = $user_agent->request($req);
    sleep(1);
    print "Exit response = " . $resp->as_string . "\n" if $debug;
    $markup_server_running = 0;
}

#***********************************************************************
#
# Name: Check_Puppeteer_Requirements
#
# Parameters: none
#
# Description:
#
#   This function checks to see if all the system requirements are
# available to run puppeteer.  The requirements are:
#    - Chrome browser
#    - Node runtime environment
#    - Puppeteer module installed in Node
#
# Returns:
#   1 - requirements met
#   0 - requirements not met
#
#***********************************************************************
sub Check_Puppeteer_Requirements {
    my ($file_path, $version, $major, $minor, $version_str);
    my ($js_fh, $js_filename, $node_output, $line, $output);
    my ($bat_fh, $bat_filename, $chromedriver_path);
    my ($meets_requirements) = 1;

    #
    # Have we already checked that puppeteer requirements are available
    #
    print "Check_Puppeteer_Requirements\n" if $debug;
    if ( defined($headless_chrome_installed) ) {
        return($headless_chrome_installed);
    }
    
    #
    # Do we have configuration parameters?
    #
    if ( (! defined($markup_server_port_start))          ||
         (! defined($default_windows_chrome_path)) ||
         (! defined($puppeteer_chrome_min_version)) ) {
        print "No puppeteer configuration paramters supplied\n" if $debug;
        print STDERR "crawler_puppeteer: No puppeteer configuration paramters supplied\n";
        $meets_requirements = 0;
        $puppeteer_install_error = String_Value("No puppeteer configuration paramters supplied");
        return($meets_requirements);
    }

    #
    # Check for requirements
    #
    if ( $^O =~ /MSWin32/ ) {
        #
        # Windows.
        # Find Chrome in the path or use default path
        #
        $chrome_path = `where chrome 2>&1`;
        if ( $chrome_path =~ /Could not find/i ) {
            print "Chrome not in path, use default\n" if $debug;
            if ( defined($default_windows_chrome_path) ) {
                #
                # Check each path for an instance of Chrome
                #
                print "Default chrome paths = $default_windows_chrome_path\n" if $debug;
                foreach $file_path (split(/\n/, $default_windows_chrome_path)) {
                    if ( -f $file_path ) {
                        $chrome_path = $file_path;
                        print "Chrome found at path = $file_path\n" if $debug;
                        last;
                    }
                }
            }
            else {
                print "No default chrome path\n" if $debug;
                undef $chrome_path;
            }
        }
        
        #
        # Did we get a path? If so get version.
        #
        if ( defined($chrome_path) && (-f $chrome_path) ) {
            #
            # Check version of chrome
            #
            $file_path = $chrome_path;

            #
            # Escape all backslash characters in file path.
            # Use wmic command to get Chrome version as the --version
            # argument does not always work.
            #
            $file_path =~ s/\\/\\\\/g;
            print "Check Chrome version from\nwmic datafile where name=\"$file_path\" get Version /value\n" if $debug;
            $version_str = `wmic datafile where name=\"$file_path\" get Version /value`;
            ($version) = $version_str =~ /^[\s\n\r]*version=([\d\.]+).*$/mio;
            ($major, $minor) = $version =~ /^(\d+)\.([\d\.]+)$/io;
            print "Chrome version = $major from $version_str\n" if $debug;
            $user_agent_software_versions = "Chrome = $major.$minor";
        }
        else {
            #
            # No chrome executable
            #
            print "Chrome executable not found\n" if $debug;
            print STDERR "crawler_puppeteer: Chrome not installed, headless chrome not available\n";
            $meets_requirements = 0;
            $puppeteer_install_error = String_Value("Chrome not installed, headless chrome not available");
        }
        
        #
        # Get path to node
        #
        print "Check for node program\n" if $debug;
        $file_path = `where node 2>&1`;
        if ( $file_path =~ /Could not find/i ) {
            print "Node not in path\n" if $debug;
            print STDERR "crawler_puppeteer: Node not installed, headless chrome not available\n";
            $meets_requirements = 0;
            $puppeteer_install_error = String_Value("Node not installed, headless chrome not available");
        }
        else {
            print "Node found at $file_path\n" if $debug;
            $version = `node -v`;
            chomp($version);
            $user_agent_software_versions .= ", Node = $version";
        }
    }
    else {
        #
        # Not Windows.
        #
        print STDERR "crawler_puppeteer: Not Windows, headless chrome not available\n";
        $meets_requirements = 0;
        $puppeteer_install_error = String_Value("Chrome not installed, headless chrome not available");
    }
    
    #
    # Check Chrome browser
    #
    if ( $meets_requirements ) {
        #
        # Is the major version number greater than the minimum required?
        #
        if ( defined($puppeteer_chrome_min_version) && defined($major) &&
             ($major >= $puppeteer_chrome_min_version) ) {
            print "Have valid Chrome version $major\n" if $debug;
        }
        else {
            #
            # Either no versions or version below minimum
            #
            print "Chrome version below minimum or no minimum value set\n" if $debug;
            print STDERR "crawler_puppeteer: Headless Chrome version below minimum or no version found\n";
            $puppeteer_install_error = String_Value("Chrome version below minimum value");
            $meets_requirements = 0;
        }
    }

    #
    # Check that puppeteer module is installed for node
    #
    if ( $meets_requirements ) {
        #
        # Write temporary program to test puppeteer
        #
        ($js_fh, $js_filename) =
           tempfile("WPSS_TOOL_CP_XXXXXXXXXX",
                    SUFFIX => '.js',
                    TMPDIR => 1);
        if ( ! defined($js_fh) ) {
            print STDERR "Error: Failed to create temporary file in Check_Puppeteer_Requirements\n";
            return(0);
        }
        binmode $js_fh, ":utf8";
        print $js_fh "
var fs = require('fs');
const puppeteer = require('puppeteer-core');
console.log('Puppeteer installed');
var file = 'puppeteer-core/package.json';
var json = require(file);
var version = json.version;
console.log('Version: ' + version);
";
        close($js_fh);

        #
        # Write temporary batch script to test puppeteer
        #
        ($bat_fh, $bat_filename) =
           tempfile("WPSS_TOOL_CP_XXXXXXXXXX",
                    SUFFIX => '.bat',
                    TMPDIR => 1);
        if ( ! defined($bat_fh) ) {
            print STDERR "Error: Failed to create temporary file in Check_Puppeteer_Requirements\n";
            unlink($js_filename);
            return(0);
        }
        print $bat_fh "
set NODE_PATH=\%AppData\%\\npm\\node_modules
echo NODE_PATH=\%NODE_PATH\%
echo Run node $js_filename
node \"$js_filename\"
";
        close($bat_fh);

        #
        # Check to see if puppeteer is installed.
        #
        print "Test for puppeteer-core module\n" if $debug;
        print "$bat_filename 2>&1\n" if $debug;
        $node_output = `$bat_filename 2>&1`;
        print "Output = $node_output\n" if $debug;
        if ( $node_output =~ /Cannot find module/im ) {
            print "Puppeteer-core module not installed, output = $node_output\n" if $debug;
            print STDERR "crawler_puppeteer: Node/Puppeteer-core module not installed, headless chrome not available\n";
            $puppeteer_install_error = String_Value("Puppeteer-core module not installed");
            $meets_requirements = 0;
        }
        else {
            $version = "unknown";
            foreach $line (split(/\n/, $node_output)) {
                if ( $line =~ /Version: /i ) {
                    $line =~ s/Version: //i;
                    $version = $line;
                    last;
                }
            }
            $user_agent_software_versions .= ", Puppeteer-core = $version";
        }
        unlink($js_filename);
        unlink($bat_filename);
    }
    
    #
    # Get chromedriver version
    #
    if ( $meets_requirements ) {
        print "Get chromedriver version\n" if $debug;
        $output = `npm list chromedriver -g 2>&1`;
        $version = "";
        foreach $line (split(/[\n\r]/, $output)) {
            if ( $line =~ /^\|/ ) {
                #
                # Skip chromedrive from nested module
                #
                next;
            }
            elsif ( $line =~ /chromedriver/ ) {
                print "Found chromedriver version $line\n" if $debug;
                $line =~ s/^.*@//g;
                $version = $line;
                $user_agent_software_versions .= ", Chromedriver = $version";
                last;
            }
        }
    }
    #
    # Return requirements indicator
    #
    $headless_chrome_installed = $meets_requirements;
    return($meets_requirements);
}

#***********************************************************************
#
# Name: Crawler_Puppeteer_Start_Markup_Server
#
# Parameters: user_agent_check_url - URL to check user agents
#
# Description:
#
#   This function starts the markup server process using puppeteer running
# in node.
# The puppeteer program arguments include:
#    Server port number
#    Path to chrome browser
#    Temporary directory for user data
#
# Returns:
#   1 - server started successfully
#   0 - server did not start or supporting files are not available
#
#***********************************************************************
sub Crawler_Puppeteer_Start_Markup_Server {
    my ($user_agent_check_url) = @_;

    my ($debug_option, $sec, $min, $hour, $time, $cmd, $rc, $url);
    my ($port, $port_found, $socket, $lwp_user_agent, $resp);

    #
    # Check to see if the required programs and files are
    # available (e.g. Chrome browser, Node, etc.).
    #
    print "Crawler_Puppeteer_Start_Markup_Server\n" if $debug;
    if ( Check_Puppeteer_Requirements() ) {
        #
        # Stop any server that may be running
        #
        Crawler_Puppeteer_Stop_Markup_Server();
    
        #
        # Remove any existing cache
        #
        Crawler_Puppeteer_Clear_Cache("");
        
        #
        # Pass debug flag to markup server
        #
        if ( $debug ) {
            $debug_option = " -debug";
        }
        else {
            $debug_option = "";
        }

        #
        # Check to see that user data directory exists.  It might have
        # been removed in a cache clearing.
        #
        if ( ! -d $puppeteer_user_dir ) {
            print "Missing directory $puppeteer_user_dir\n" if $debug;
            mkdir($puppeteer_user_dir);
        }
        
        #
        # Check for a user agent check url
        #
        if ( ! defined($user_agent_check_url) || ($user_agent_check_url eq "") ) {
            $user_agent_check_url = $default_user_agent_check_url;
        }

        #
        # Create a LWP::UserAgent object to test puppeteer
        #
        print "Create LWP::UserAgent user agent $user_agent_name\n" if $debug;
        $lwp_user_agent = LWP::UserAgent->new(agent => "$user_agent_name");
        $lwp_user_agent->ssl_opts(verify_hostname => 0,
                                  SSL_verify_mode => SSL_VERIFY_NONE);
        $lwp_user_agent->timeout("60");

        #
        # Look for a usable port for the markup server
        #
        $port = $markup_server_port_start;
        $port_found = 0;
        while ( ! $port_found ) {
            #
            # Create a socket object and attempt to bind to the port
            #
            print "Attempt to connect to port $port\n" if $debug;
            $socket = new IO::Socket::INET(LocalHost => '127.0.0.1',
                                           LocalPort => $port,
                                           Proto => 'tcp',
                                           Listen => 5,
                                           Reuse => 1);
        
            #
            # Were we successful?
            #
            if ( defined($socket) ) {
                #
                # Found a usable port, release it and stop search
                #
                $socket->close();

                #
                # Start the puppeteer_markup_server.js program in Node
                #
                ($sec, $min, $hour) = (localtime)[0,1,2];
                $time = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
                print "Crawler_Puppeteer_Start_Markup_Server at $time\n" if $debug;
                $cmd = "$puppeteer_server_cmnd $port \"$chrome_path\" \"$puppeteer_user_dir\" $debug_option";
                print "$cmd\n" if $debug;
                $rc = system("$cmd");
                print "Puppeteer server started, rc = $rc\n" if $debug;
                sleep(5);

                #
                # Test the puppeteer markup server
                #
                $url = "http://127.0.0.1:$port/GET?url=$user_agent_check_url";
                print "Test puppeteer markup server by getting $url\n" if $debug;
                $resp = $lwp_user_agent->get($url);
                if ( defined($resp) && ($resp->is_success) ) {
                    #
                    # Save the port number to be used in page requests
                    #
                    print "puppeteer markup server is running and responds\n" if $debug;
                    $markup_server_port = $port;
                    $port_found = 1;

                    #
                    # Set flag to indicate that the markup server has been started.
                    #
                    $markup_server_running = 1;
                    return(1);
                }
                #
                # test failed
                #
                else {
                    print "Got error response from puppeteer markup server\n" if $debug;
                    if ( defined($resp) ) {
                        print "  HTTP response:" . $resp->status_line . "\n" if $debug;
                        print $resp->as_string . "\n" if $debug;
                    }
                    else {
                        print STDERR "  HTTP response: undefined\n" if $debug;
                    }
                }
            }
            
            #
            # If we didn't find a usable port, increment port number.
            # Try a maximum of 10 times.
            #
            if ( ! $port_found ) {
                if ( ($port - $markup_server_port) < 10 ) {
                    $port++;
                }
                else {
                    print "Failed to find a free port starting at $markup_server_port_start\n" if $debug;
                    print STDERR "Failed to find a free port for puppeteer starting at $markup_server_port_start\n";
                    $markup_server_running = 0;
                    return(0);
                }
            }
        }
    }
    
    #
    # Server did not start
    #
    print "Puppeteer server not started\n" if $debug;
    $markup_server_running = 0;
    return(0);
}

#***********************************************************************
#
# Name: Server_Page_Markup
#
# Parameters: this_url - a URL
#             image_file - name of file to contain the screen capture
#               of the web page
#             user - user name for HTTP 401 authentication
#             password - password for HTTP 401 authentication
#
# Description:
#
#   This function makes a request to the markup_server.js program in
# Node to get the HTML markup of a web page after any load time
# JavaScript is run on the page.
#
#***********************************************************************
sub Server_Page_Markup {
    my ($this_url, $image_file, $user, $password) = @_;

    my ($content, $output, $line, $load_time, $markup);
    my ($sec, $min, $hour, $time, $image_param, %generated_markup);
    my ($user_agent, $resp, $url, $req, $authen_param, $error);
    my ($markup_ptr) = \%generated_markup;

    #
    # If the markup page server is not running, start it.
    #
    print "Server_Page_Markup\n" if $debug;
    if ( ! $markup_server_running ) {
        print "Restart markup server, test url = $this_url\n" if $debug;
        Crawler_Puppeteer_Start_Markup_Server($this_url);
    }
    
    #
    # Get current time/date
    #
    ($sec, $min, $hour) = (localtime)[0,1,2];
    $time = sprintf("%02d:%02d:%02d", $hour, $min, $sec);

    #
    # Are we capturing an image of the web page ?
    #
    if ( defined($image_file) && ($image_file ne "") ) {
        $image_param = "page_image=$image_file\&";
        $image_param =~ s/\\/\//g;
    }
    else {
        $image_param = "";
    }
    
    #
    # Do we have HTTP 401 authentication credentials?
    #
    if ( defined($user) && ($user ne "") ) {
        $authen_param = "username=$user\&password=$password\&";
        print "Add HTTP 401 credentials\n" if $debug;
    }
    else {
        $authen_param = "";
    }
    
    #
    # Build request string
    #
    $url = "http://127.0.0.1:$markup_server_port/GET?$authen_param$image_param" .
           "url=$this_url";
    print "URL to get = $url\n" if $debug;

    #
    # Send the request to the server
    #
    $req = HTTP::Request->new(GET => $url);
    print "Request = " . $req->as_string . "\n" if $debug;

    #
    # Get page markup from the URL ?
    #
    $user_agent = LWP::UserAgent->new;
    print "start $time page markup from $this_url\n" if $debug;
    $resp = $user_agent->request($req);
    ($sec, $min, $hour) = (localtime)[0,1,2];
    $time = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
    print "end   $time page markup\n" if $debug;

    #
    # Did we get the page markup ?
    #
    if ( defined($resp) && ($resp->is_success) ) {
        $output = $resp->decoded_content;
        print "Got response\n" if $debug;

        if ( $output =~ /===== PAGE MARKUP ENDS =====/ ) {
            print "Found markup end marker\n" if $debug;
            $markup = 0;
            foreach $line (split(/\n/, $output)) {
                if ( $line =~ /^.*page load time/ ) {
                    $load_time = $line;
                    $load_time =~ s/^.*page load time//g;
                }
                elsif ( $line =~ /===== PAGE MARKUP BEGINS =====/ ) {
                    #
                    # Start of markup
                    #
                    $markup = 1;
                }
                elsif ( $line =~ /===== PAGE MARKUP ENDS =====/ ) {
                    #
                    # End of markup
                    #
                    $markup = 0;
                }
                elsif ( $markup ) {
                    $content .= $line . "\n";
                }
            }
            print "Found page markup and load time $load_time\n" if $debug;
            $generated_markup{"generated_content"} = $content;
        }
        #
        # Check for error message from the markup server
        #
        elsif ( $output =~ /===== PAGE ERROR ENDS =====/ ) {
            print "Found error end marker\n" if $debug;
            $error = 0;
            foreach $line (split(/\n/, $output)) {
                if ( $line =~ /===== PAGE ERROR BEGINS =====/ ) {
                    #
                    # Start of error message
                    #
                    $error = 1;
                }
                elsif ( $line =~ /===== PAGE ERROR ENDS =====/ ) {
                    #
                    # End of error message
                    #
                    $error = 0;
                }
                elsif ( $error ) {
                    $content .= $line . "\n";
                }
            }
            print "Found page error marker\n" if $debug;
            $generated_markup{"error"} = "Chrome/Puppeteer:\n$content";
            print "Error with puppeteer/headless browser output\n" if $debug;
            print STDERR "crawler_puppeteer: Error Server_Page_Markup\n";
            print STDERR "Response successful, page error marker found\n";
            print STDERR "  get($url)\n";
            print STDERR "$output\n";
            
            #
            # Try stopping and restarting the markup server
            #
            print "Attempting a restart of the crawler_puppeteer server, test url = $this_url\n" if $debug;
            Crawler_Puppeteer_Start_Markup_Server($this_url);
        }
        else {
            #
            # Error running puppeteer
            #
            print "Error with puppeteer output\n" if $debug;
            print STDERR "crawler_puppeteer: Error Server_Page_Markup\n";
            print STDERR "Missing page markup markers\n";
            print STDERR "  get($url)\n";
            print STDERR "$output\n";
            
            $generated_markup{"generated_content"} = "";
            #
            # Try stopping and restarting the markup server
            #
            print "Attempting a restart of the crawler_puppeteer server, test url = $this_url\n" if $debug;
            Crawler_Puppeteer_Start_Markup_Server($this_url);
        }
    }
    #
    # Did the puppeteer server encounter an error with the headless user agent?
    #
    elsif ( defined($resp) && (! $resp->is_success) ) {
        $output = $resp->decoded_content;
        print "Got error response\n" if $debug;

        #
        # Get the error message from the markup server
        #
        if ( $output =~ /===== PAGE ERROR ENDS =====/ ) {
            print "Found markup end marker\n" if $debug;
            $error = 0;
            foreach $line (split(/\n/, $output)) {
                if ( $line =~ /===== PAGE ERROR BEGINS =====/ ) {
                    #
                    # Start of error message
                    #
                    $error = 1;
                }
                elsif ( $line =~ /===== PAGE ERROR ENDS =====/ ) {
                    #
                    # End of error message
                    #
                    $error = 0;
                }
                elsif ( $error ) {
                    $content .= $line . "\n";
                }
            }
            print "Found page error marker\n" if $debug;
            $generated_markup{"error"} = "Chrome/Puppeteer:\n$content";;
            print "Error with puppeteer/headless browser output\n" if $debug;
            print STDERR "crawler_puppeteer: Error Server_Page_Markup\n";
            print STDERR "Response not successful, page error marker found\n";
            print STDERR "  get($url)\n";
            print STDERR "$output\n";

            #
            # Try stopping and restarting the markup server
            #
            print "Attempting a restart of the crawler_puppeteer server, test url = $this_url\n" if $debug;
            Crawler_Puppeteer_Start_Markup_Server($this_url);
        }
        else {
            #
            # Error running puppeteer
            #
            print "Error with puppeteer output\n" if $debug;
            print STDERR "crawler_puppeteer: Error Server_Page_Markup\n";
            print STDERR "Response not successful\n";
            print STDERR "  get($url)\n";
            print STDERR "$output\n";
            $generated_markup{"error"} = "";

            #
            # Try stopping and restarting the markup server
            #
            print "Attempting a restart of the crawler_puppeteer server, test url = $this_url\n" if $debug;
            Crawler_Puppeteer_Start_Markup_Server($this_url);
        }
        $generated_markup{"generated_content"} = "";
    }
    else {
        #
        # Error running puppeteer
        #
        print "Failed to get response from puppeteer markup server\n" if $debug;
        $generated_markup{"generated_content"} = "";

        #
        # Restart the markup server (it may have exited after an idle timeout)
        #
        print "Attempting a restart of the crawler_puppeteer server, test url = $this_url\n" if $debug;
        Crawler_Puppeteer_Start_Markup_Server($this_url);

        #
        # Have we already tried to get this page for the 2nd time?
        #
        if ( ! $retry_page ) {
            #
            # Try one more time to get the page.
            #
            $retry_page = 1;
            print "Retry GET of page\n" if $debug;
            $markup_ptr = Server_Page_Markup($this_url,
                                             $image_file, $user, $password);
        }
        else {
            #
            # Failed to get page twice, report error.
            #
            print STDERR "crawler_puppeteer: Error in Server_Page_Markup\n";
            print STDERR "Response not defined\n";
            print STDERR "  get($url)\n";
            if ( defined($resp) ) {
                print STDERR "  HTTP response:" . $resp->status_line . "\n";
                print STDERR $resp->as_string . "\n";
            }
            else {
                print STDERR "  HTTP response: undefined\n";
            }
            $generated_markup{"error"} = "";
            $generated_markup{"generated_content"} = "";
        }
        $retry_page = 0;
    }

    #
    # Return content
    #
    return($markup_ptr);
}

#***********************************************************************
#
# Name: Crawler_Puppeteer_Page_Markup
#
# Parameters: this_url - a URL
#             image_file - name of file to contain the screen capture
#               of the web page
#             user - user name for HTTP 401 authentication
#             password - password for HTTP 401 authentication
#
# Description:
#
#   This function runs the headless user agent Puppeteer to
# get the HTML markup of the page after any load time JavaScript is
# run on the page.
#
#***********************************************************************
sub Crawler_Puppeteer_Page_Markup {
    my ($this_url, $image_file, $user, $password) = @_;

    my ($markup);
    
    #
    # Get page markup.
    #
    print "Crawler_Puppeteer_Page_Markup\n" if $debug;
    $markup = Server_Page_Markup($this_url, $image_file,
                                 $user, $password);

    #
    # Return markup
    #
    print "Return markup table\n" if $debug;
    return($markup);
}

#***********************************************************************
#
# Name: Crawler_Puppeteer_User_Agent_Details
#
# Parameters: none
#
# Description:
#
#   This function returns the versions of software for the headless
# user agent. If the agent is not installed, it returns the reason
# it is not used.
#
#***********************************************************************
sub Crawler_Puppeteer_User_Agent_Details {
    #
    # Do we have an installation error string?
    #
    print "Crawler_Puppeteer_User_Agent_Details\n" if $debug;
    if ( defined($puppeteer_install_error) && ($puppeteer_install_error ne "") ) {
        return($puppeteer_install_error);
    }
    else {
        return($user_agent_software_versions);
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
# Create a temporary directory for user data for Chrome
#
$puppeteer_user_dir = tempdir("WPSS_TOOL_Chrome_Dir_XXXXXXXXXX", TMPDIR => 1);

#
# Get path to Node command
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $puppeteer_server_cmnd = "START /B .\\bin\\puppeteer_markup_server.bat";
    $puppeteer_server_last_arg = "";
} else {
    #
    # Not Windows.
    #
    $puppeteer_server_cmnd = "node ./lib/puppeteer_markup_server.js";
    $puppeteer_server_last_arg = "\&";
}

#
# Remove any stdout or stderr files
#
unlink("puppeteer_stdout.txt");
unlink("puppeteer_stderr.txt");

#
# Make sure npm modules are in the path
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $paths = $ENV{"PATH"};
    $userprofile = $ENV{"USERPROFILE"};
    $paths .= ";$userprofile/AppData/Roaming/npm";
    $ENV{"PATH"} = $paths;
}

#
# Return true to indicate we loaded successfully
#
return 1;

