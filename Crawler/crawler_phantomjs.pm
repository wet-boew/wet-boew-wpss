#***********************************************************************
#
# Name:   crawler_phantomjs.pm
#
# $Revision: 2427 $
# $URL: svn://10.36.148.185/WPSS_Tool/Crawler/Tools/crawler_phantomjs.pm $
# $Date: 2022-11-15 11:31:34 -0500 (Tue, 15 Nov 2022) $
#
# Description:
#
#   This file contains routines to interact with the PhantomJS program.
#
# Public functions:
#     Crawler_Phantomjs_Clear_Cache
#     Crawler_Phantomjs_Config
#     Crawler_Phantomjs_Debug
#     Crawler_Phantomjs_Start_Markup_Server
#     Crawler_Phantomjs_Stop_Markup_Server
#     Crawler_Phantomjs_Page_Markup
#     Crawler_Phantomjs_User_Agent_Details
#
# Terms and Conditions of Use
#
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is
# distributed under the MIT License.
#
# MIT License
#
# Copyright (c) 2015 Government of Canada
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

package crawler_phantomjs;

use strict;
use Encode;
use File::Basename;
use File::Path qw(remove_tree);
use LWP::UserAgent;
use IO::Socket::INET;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(Crawler_Phantomjs_Clear_Cache
                  Crawler_Phantomjs_Config
                  Crawler_Phantomjs_Debug
                  Crawler_Phantomjs_Start_Markup_Server
                  Crawler_Phantomjs_Stop_Markup_Server
                  Crawler_Phantomjs_Page_Markup
                  Crawler_Phantomjs_User_Agent_Details
                  );
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths, $phantomjs_cmnd);
my ($phantomjs_arg, $phantomjs_cache, $phantomjs_server_last_arg);
my ($phantomjs_server_cmnd, $phantomjs_server_arg);
my ($debug) = 0;
my ($use_markup_server) = 0;
my ($markup_server_running) = 0;
my ($markup_server_port_start) = "8000";
my ($markup_server_port) = $markup_server_port_start;
my ($retry_page) = 0;

#********************************************************
#
# Name: Crawler_Phantomjs_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub Crawler_Phantomjs_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: Crawler_Phantomjs_Clear_Cache
#
# Parameters: cookie_file - path to cookie jar file
#
# Description:
#
#   This function clears the disk cache and cookie jar for PhantomJS.
#
#***********************************************************************
sub Crawler_Phantomjs_Clear_Cache {
    my ($cookie_file) = @_;
    
    my ($error, $diag, $file, $message);

    #
    # If we have a running markup server, stop it.
    #
    if ( $markup_server_running ) {
        Crawler_Phantomjs_Stop_Markup_Server();
    }

    #
    # Remove cookie jar file if it exists
    #
    print "Crawler_Phantomjs_Clear_Cache, remove cookie jar $cookie_file\n" if $debug;
    if ( defined($cookie_file) && ($cookie_file ne "") ) {
        unlink($cookie_file);
    }
    
    #
    # Remove the disk cache
    #
    print "Remove disk cache $phantomjs_cache\n" if $debug;
    remove_tree($phantomjs_cache, {error => \$error});
    
    #
    # Check for possible errors
    #
    if ( @$error ) {
        print "Error: Failed to remove_tree $phantomjs_cache\n";
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

#***********************************************************************
#
# Name: Crawler_Phantomjs_Config
#
# Parameters: config_vars
#
# Description:
#
#   This function sets a number of package configuration values.
# The values are passed in as a hash table.
#
#***********************************************************************
sub Crawler_Phantomjs_Config {
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
        elsif ( $key eq "use_markup_server" ) {
            $use_markup_server = $value;
        }
    }
}

#***********************************************************************
#
# Name: Crawler_Phantomjs_Stop_Markup_Server
#
# Parameters: none
#
# Description:
#
#   This function stops the markup server process.
#
#***********************************************************************
sub Crawler_Phantomjs_Stop_Markup_Server {

    my ($req, $user_agent, $resp, $url);

    #
    # Build request string
    #
    print "Crawler_Phantomjs_Stop_Markup_Server\n" if $debug;
    $url = "http://127.0.0.1:$markup_server_port/EXIT";
    $req = HTTP::Request->new(GET => $url);

    #
    # Send the exit to the markup server ?
    #
    $user_agent = LWP::UserAgent->new;
    $resp = $user_agent->request($req);
}

#***********************************************************************
#
# Name: Crawler_Phantomjs_Start_Markup_Server
#
# Parameters: cookie_file - path to cookie jar file
#
# Description:
#
#   This function starts the markup server process in PhantomJS.
# The PhantomJS program arguments include:
#   enable disk cache
#   cookie jar path
#   instruct PhantomJS to ignore SSL errors (e.g. unsigned certificates)
#
# Returns:
#   1 - server started successfully
#   0 - server did not start
#
#***********************************************************************
sub Crawler_Phantomjs_Start_Markup_Server {
    my ($cookie_file) = @_;

    my ($debug_option, $sec, $min, $hour, $time, $output, $cmnd, $rc);
    my ($port, $port_found, $socket);

    #
    # Are we running in single page mode (start PhantonJS for each
    # page) or using a markup server (a background process that gets
    # pages).
    #
    print "Crawler_Phantomjs_Start_Markup_Server\n" if $debug;
    if ( ! $use_markup_server ) {
        #
        # Not using a markup server.  Return true to indicate
        # success.  The real success/failure will be returned
        # when actual page markup is requested.
        #
        print "Not using markup server\n" if $debug;
        return(1);
    }
    
    #
    # Stop any server that may be running
    #
    Crawler_Phantomjs_Stop_Markup_Server();
    
    #
    # Check to see if port number is available
    #
    $port = $markup_server_port_start;
    $port_found = 0;
    while ( ! $port_found ) {
        #
        # Create a socket object and attempt to bind to the port
        #
        print "Attempt to connect to port $port\n" if $debug;
        $socket = new IO::Socket::INET (LocalHost => '127.0.0.1',
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
            $port_found = 1;
            
            #
            # Save the port number to be used in page requests
            #
            $markup_server_port = $port;
        }
        else {
            #
            # Could not connect to socket, increment port number.
            # Try a maximum of 10 times.
            #
            if ( ($port - $markup_server_port_start) < 10 ) {
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
    # Start the markup_server.js program in PhantomJS
    #
    ($sec, $min, $hour) = (localtime)[0,1,2];
    $time = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
    print "Crawler_Phantomjs_Start_Markup_Server at $time\n" if $debug;
    $cmnd = "$phantomjs_server_cmnd --disk-cache=true --cookies-file=\"$cookie_file\" --ignore-ssl-errors=true $phantomjs_server_arg $markup_server_port $debug_option >> phantomjs_stdout.txt 2>> phantomjs_stderr.txt $phantomjs_server_last_arg";
    print "$cmnd\n" if $debug;
    system($cmnd);

    #
    # Set flag to indicate that the markup server has been started.
    #
    print "PhantomJS markup server running\n" if $debug;
    $markup_server_running = 1;
    sleep(5);
    return(1);
}

#***********************************************************************
#
# Name: Single_Page_Markup
#
# Parameters: this_url - a URL
#             cookie_file - path to cookie jar file
#             image_file - name of file to contain the screen capture
#               of the web page
#             user - user name for HTTP 401 authentication
#             password - password for HTTP 401 authentication
#
# Description:
#
#   This function runs the page_markup.js program in PhantomJS to
# get the HTML markup of a single page after any load time JavaScript is
# run on the page.
#
#***********************************************************************
sub Single_Page_Markup {
    my ($this_url, $cookie_file, $image_file, $user, $password) = @_;

    my ($content, $output, $line, $load_time, $markup, $error);
    my ($sec, $min, $hour, $date, $image_param, %generated_markup);

    #
    # Get current time/date
    #
    ($sec, $min, $hour) = (localtime)[0,1,2];
    $date = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
    
    #
    # Are we capturing an image of the web page ?
    #
    if ( defined($image_file) && ($image_file ne "") ) {
        $image_param = " -page_image \"$image_file\"";
    }
    else {
        $image_param = "";
    }

    #
    # Get page markup from the URL ?
    #
    print "Single_Page_Markup start $date page markup from $this_url\n" if $debug;
    print "$phantomjs_cmnd --disk-cache=true --cookies-file=\"$cookie_file\" $phantomjs_arg \"$this_url\" $image_param\n" if $debug;
    $output = `$phantomjs_cmnd --disk-cache=true --cookies-file=\"$cookie_file\" $phantomjs_arg \"$this_url\" $image_param 2>> phantomjs_stderr.txt`;
    ($sec, $min, $hour) = (localtime)[0,1,2];
    $date = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
    print "Single_Page_Markup end   $date page markup\n" if $debug;

    #
    # Did we get the page markup ?
    #
    if ( $output =~ /===== PAGE MARKUP ENDS =====/ ) {
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
        
        #
        # Save page markup
        #
        print "Found page markup and load time $load_time\n" if $debug;
        $content = decode("utf8", $content, Encode::FB_HTMLCREF);
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
        $generated_markup{"error"} = "Phantomjs:\n$content";
        print "Error with Phantomjs/headless browser output\n" if $debug;
        print STDERR "crawler_phantomjs: Error Single_Page_Markup\n";
        print STDERR "Response successful, page error marker found\n";
        print STDERR "  get($this_url)\n";
        print STDERR "$output\n";
    }
    else {
        #
        # Error running phantomjs
        #
        print STDERR "Error running phantomjs\n";
        print STDERR "  $phantomjs_cmnd --disk-cache=true --cookies-file=\"$cookie_file\" $phantomjs_arg \"$this_url\" $image_param\n";
        print STDERR "$output\n";
        $generated_markup{"generated_content"} = "";
    }

    #
    # Return content
    #
    return(\%generated_markup);
}

#***********************************************************************
#
# Name: Server_Page_Markup
#
# Parameters: this_url - a URL
#             cookie_file - path to cookie jar file
#             image_file - name of file to contain the screen capture
#               of the web page
#             user - user name for HTTP 401 authentication
#             password - password for HTTP 401 authentication
#
# Description:
#
#   This function makes a request to the markup_server.js program in
# PhantomJS to get the HTML markup of a web page after any load time
# JavaScript is run on the page.
#
#***********************************************************************
sub Server_Page_Markup {
    my ($this_url, $cookie_file, $image_file, $user, $password) = @_;

    my ($content, $output, $line, $load_time, $markup);
    my ($sec, $min, $hour, $time, $image_param, %generated_markup);
    my ($user_agent, $resp, $url, $req, $authen_param, $error);
    my ($markup_ptr) = \%generated_markup;

    #
    # If the markup page server is not running, start it.
    #
    print "Server_Page_Markup\n" if $debug;
    if ( ! $markup_server_running ) {
        Crawler_Phantomjs_Start_Markup_Server($cookie_file);
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
            #$content = decode("utf8", $content, Encode::FB_HTMLCREF);
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
            $generated_markup{"error"} = "Phantomjs:\n$content";
            print "Error with Phantomjs/headless browser $output\n" if $debug;
            print STDERR "crawler_phantomjs: Error Server_Page_Markup\n";
            print STDERR "Response successful, page error marker found\n";
            print STDERR "  get($this_url)\n";
            print STDERR "$output\n";

            #
            # Try stopping and restarting the markup server
            #
            print "Attempting a restart of the crawler_phantomjs server\n" if $debug;
            Crawler_Phantomjs_Start_Markup_Server($cookie_file);
        }
        else {
            #
            # Error running phantomjs
            #
            print "Error with phantomJS output\n" if $debug;
            print STDERR "Error Server_Page_Markup\n";
            print STDERR "  LWP::UserAgent->get($url)\n";
            print STDERR "$output\n";
            $generated_markup{"generated_content"} = "";
        }
    }
    else {
        #
        # Error running phantomjs
        #
        print "Failed to get response from phamtonjs markup server\n" if $debug;
        $generated_markup{"generated_content"} = "";

        #
        # Restart the markup server
        #
        Crawler_Phantomjs_Start_Markup_Server($cookie_file);

        #
        # Have we already tried to get this page for the 2nd time?
        #
        if ( ! $retry_page ) {
            #
            # Try one more time to get the page.
            #
            $retry_page = 1;
            print "Retry GET of page\n" if $debug;
            $markup_ptr = Server_Page_Markup($this_url, $cookie_file,
                                             $image_file, $user, $password);
        }
        else {
            #
            # Failed to get page twice, report error.
            #
            print STDERR "Error in Server_Page_Markup\n";
            print STDERR "  LWP::UserAgent->get($url)\n";
            if ( defined($resp) ) {
                print STDERR "  HTTP response:" . $resp->status_line . "\n";
                print STDERR $resp->as_string . "\n";
            }
            else {
                print STDERR "  HTTP response: undefined\n";
            }
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
# Name: Crawler_Phantomjs_Page_Markup
#
# Parameters: this_url - a URL
#             cookie_file - path to cookie jar file
#             image_file - name of file to contain the screen capture
#               of the web page
#             user - user name for HTTP 401 authentication
#             password - password for HTTP 401 authentication
#
# Description:
#
#   This function runs the headless user agent PhantomJS to
# get the HTML markup of the page after any load time JavaScript is
# run on the page.
#
#***********************************************************************
sub Crawler_Phantomjs_Page_Markup {
    my ($this_url, $cookie_file, $image_file, $user, $password) = @_;

    my ($markup);
    
    #
    # Are we running in single page mode (start PhantonJS for each
    # page) or using a markup server (a background process that gets
    # pages).
    #
    print "Crawler_Phantomjs_Page_Markup\n" if $debug;
    if ( $use_markup_server ) {
        $markup = Server_Page_Markup($this_url, $cookie_file, $image_file,
                                     $user, $password);
    }
    else {
        $markup = Single_Page_Markup($this_url, $cookie_file, $image_file,
                                     $user, $password);
    }
    
    #
    # Return markup
    #
    print "Return markup table\n" if $debug;
    return($markup);
}

#***********************************************************************
#
# Name: Crawler_Phantomjs_User_Agent_Details
#
# Parameters: none
#
# Description:
#
#   This function returns the versions of software for the headless
# user agent. If the aent is not installed, it returns the reason
# it is not used.
#
#***********************************************************************
sub Crawler_Phantomjs_User_Agent_Details {

    my ($version);
  
    #
    # Get the PhantomJS version
    #
    print "Crawler_Phantomjs_User_Agent_Details\n" if $debug;
    $version = `$phantomjs_cmnd -v`;
    chomp($version);
    return("PhantomJS = $version");
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
# Get path to PhantomJS command
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $phantomjs_cmnd = ".\\bin\\phantomjs";
    $phantomjs_arg = ".\\lib\\page_markup.js";
    $phantomjs_server_cmnd = "START /B .\\bin\\phantomjs";
    $phantomjs_server_arg = ".\\lib\\markup_server.js";
    $phantomjs_server_last_arg = "";
    $phantomjs_cache = $ENV{"HOMEDRIVE"} . $ENV{"HOMEPATH"} . "\\AppData\\Local\\Ofi Labs\\PhantomJS";
} else {
    #
    # Not Windows.
    #
    $phantomjs_cmnd = "$program_dir/bin/phantomjs";
    $phantomjs_arg = "./lib/page_markup.js";
    $phantomjs_server_cmnd = $phantomjs_cmnd;
    $phantomjs_server_arg = "./lib/markup_server.js";
    $phantomjs_server_last_arg = "\&";
    $phantomjs_cache = $ENV{"HOME"} . "/.qws/cache/Ofi Labs/PhantomJS";
}

#
# Remove any existing cache
#
Crawler_Phantomjs_Clear_Cache("");

#
# Remove any stdout or stderr files
#
unlink("phantomjs_stdout.txt");
unlink("phantomjs_stderr.txt");

#
# Return true to indicate we loaded successfully
#
return 1;


