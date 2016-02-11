#***********************************************************************
#
# Name: lwp_robotua_cached.pm
#
# $Revision: 7451 $
# $URL: svn://10.36.21.45/trunk/Web_Checks/Crawler/Tools/lwp_robotua_cached.pm $
# $Date: 2016-01-20 08:14:06 -0500 (Wed, 20 Jan 2016) $
#
# Description:
#
#   This file implements a LWP::RobotUA object that can use a disk
# cache for retrieved files.  This implementation merges the code
# from LWP::RobotUA and LWP::UserAgent::Cached.
#
#
# Terms and Conditions of Use
#
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is
# distributed under the MIT License.
#
# MIT License
#
# Copyright (c) 2016 Government of Canada
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

package LWP::RobotUA::Cached;

@ISA = qw(LWP::UserAgent);
$VERSION = "6.15";

require WWW::RobotRules;
require HTTP::Request;
require HTTP::Response;
use LWP::UserAgent;

use Carp;
use HTTP::Status ();
use HTTP::Date qw(time2str);
use strict;
use Digest::MD5;
use HTTP::Response;

#
# Additional attributes in addition to those found in LWP::UserAgent:
#
# $self->{'delay'}    Required delay between request to the same
#                     server in minutes.
#
# $self->{'rules'}     A WWW::RobotRules object
#

#********************************************************
#
# Name: new
#
# Parameters: cnf - hash table of configuration items
#
# Description:
#
#   This function creates a new LWP::RobotUA::Cached object.
#
#********************************************************
sub new
{
    my $class = shift;
    my %cnf;
    if (@_ < 4) {
        # legacy args
        @cnf{qw(agent from rules)} = @_;
    }
    else {
        %cnf = @_;
    }

    Carp::croak('LWP::RobotUA agent required') unless $cnf{agent};
    Carp::croak('LWP::RobotUA from address required')
    unless $cnf{from} && $cnf{from} =~ m/\@/;

    my $delay = delete $cnf{delay} || 1;
    my $use_sleep = delete $cnf{use_sleep};
    $use_sleep = 1 unless defined($use_sleep);
    my $rules = delete $cnf{rules};
    my $self = LWP::UserAgent->new(%cnf);
    $self = bless $self, $class;

    $self->{'delay'} = $delay;   # minutes
    $self->{'use_sleep'} = $use_sleep;

    if ($rules) {
        $rules->agent($cnf{agent});
        $self->{'rules'} = $rules;
    }
    else {
        $self->{'rules'} = WWW::RobotRules->new($cnf{agent});
    }

    #
    # Get cache options
    #
    my $cache_dir      = delete $cnf{cache_dir};
    my $nocache_if     = delete $cnf{nocache_if};
    my $recache_if     = delete $cnf{recache_if};
    my $cachename_spec = delete $cnf{cachename_spec};

    #
    # Set object properties
    #
    $self->{cache_dir}      = $cache_dir;
    $self->{nocache_if}     = $nocache_if;
    $self->{recache_if}     = $recache_if;
    $self->{cachename_spec} = $cachename_spec;

    $self;
}

# generate getters and setters
foreach my $opt_name (qw(cache_dir nocache_if recache_if cachename_spec)) {
	no strict 'refs';
	*$opt_name = sub {
		my $self = shift;
		if (@_) {
			my $opt_val = $self->{$opt_name};
			$self->{$opt_name} = shift;
			return $opt_val;
		}

		return $self->{$opt_name};
	}
}

sub delay     { shift->_elem('delay',     @_); }
sub use_sleep { shift->_elem('use_sleep', @_); }


sub agent
{
    my $self = shift;
    my $old = $self->SUPER::agent(@_);
    if (@_) {
        # Changing our name means to start fresh
        $self->{'rules'}->agent($self->{'agent'});
    }
    $old;
}


sub rules {
    my $self = shift;
    my $old = $self->_elem('rules', @_);
    $self->{'rules'}->agent($self->{'agent'}) if @_;
    $old;
}


sub no_visits
{
    my($self, $netloc) = @_;
    $self->{'rules'}->no_visits($netloc) || 0;
}

*host_count = \&no_visits;  # backwards compatibility with LWP-5.02


sub host_wait
{
    my($self, $netloc) = @_;
    return undef unless defined $netloc;

    my $last = $self->{'rules'}->last_visit($netloc);
    if ($last) {
        my $wait = int($self->{'delay'} * 60 - (time - $last));
        $wait = 0 if $wait < 0;
        return $wait;
    }
    return 0;
}


sub simple_request
{
    my($self, $request, $arg, $size) = @_;

    # Do we try to access a new server?
    my $allowed = $self->{'rules'}->allowed($request->uri);

    if ($allowed < 0) {
        # Host is not visited before, or robots.txt expired; fetch "robots.txt"
        my $robot_url = $request->uri->clone;
        $robot_url->path("robots.txt");
        $robot_url->query(undef);

        # make access to robot.txt legal since this will be a recursive call
        $self->{'rules'}->parse($robot_url, "");

        my $robot_req = HTTP::Request->new('GET', $robot_url);
        my $parse_head = $self->parse_head(0);
        my $robot_res = $self->request($robot_req);
        $self->parse_head($parse_head);
        my $fresh_until = $robot_res->fresh_until;
        my $content = "";
        if ($robot_res->is_success && $robot_res->content_is_text) {
            $content = $robot_res->decoded_content;
            $content = "" unless $content && $content =~ /^\s*Disallow\s*:/mi;
        }
        $self->{'rules'}->parse($robot_url, $content, $fresh_until);

        # recalculate allowed...
        $allowed = $self->{'rules'}->allowed($request->uri);
    }

    # Check rules
    unless ($allowed) {
        my $res = HTTP::Response->new(&HTTP::Status::RC_FORBIDDEN,
                                      'Forbidden by robots.txt');
        $res->request( $request ); # bind it to that request
        return $res;
    }

    my $netloc = eval { local $SIG{__DIE__}; $request->uri->host_port; };
    my $wait = $self->host_wait($netloc);

    if ($wait) {
        if ($self->{'use_sleep'}) {
            sleep($wait)
        }
        else {
            my $res = HTTP::Response->new(&HTTP::Status::RC_SERVICE_UNAVAILABLE,
                                          'Please, slow down');
           $res->header('Retry-After', time2str(time + $wait));
           $res->request( $request ); # bind it to that request
           return $res;
       }
    }

    # Perform the request
    #my $res = $self->SUPER::simple_request($request, $arg, $size);
    my $res = perform_simple_request($self, $request, $arg, $size);

    $self->{'rules'}->visit($netloc);

    $res;
}

sub perform_simple_request {
	my $self = shift;

  #
  # Do we have a disk cache ?
  #
	unless (defined $self->{cache_dir}) {
    #
    # Call on the super classes simple_request method
    #
		return $self->SUPER::simple_request(@_);
	}

	my $request = $_[0];
	eval{ $self->prepare_request($request) };
	my $fpath = $self->_get_cache_name($request);
	my $response;
	my $no_collision_suffix;

  #
  # Do we have a file path for a cached version of the HTTP::Response object ?
  #
	if (-e $fpath) {
		unless ($response = $self->_parse_cached_response($fpath, $request)) {
			# collision
			if (my @cache_list = <$fpath-*>) {
				foreach my $cache_file (@cache_list) {
					if ($response = $self->_parse_cached_response($cache_file, $request)) {
						$fpath = $cache_file;
						last;
					}
				}

				unless ($response) {
					$no_collision_suffix = sprintf('-%03d', substr($cache_list[-1], -3) + 1);
				}
			}
			else {
				$no_collision_suffix = '-001';
			}
		}

		if ($response && defined($self->{recache_if}) && ref($self->{recache_if}) eq 'CODE' &&
		    $self->{recache_if}->($response, $fpath))
		{
			$response = undef;
		}
	}

  #
  # Do we have a HTTP::Response object ?
  #
	unless ($response) {
    #
    # Call on the super classes simple_request method
    #
		$response = $self->SUPER::simple_request(@_);

		if (!defined($self->{nocache_if}) || ref($self->{nocache_if}) ne 'CODE' || !$self->{nocache_if}->($response)) {
			if (defined $no_collision_suffix) {
				$fpath .= $no_collision_suffix;
			}

      #
      # Save the response in a file in the cache
      #
			if (open my $fh, '>:raw', $fpath) {
				print $fh $request->url, "\n";
				print $fh $response->as_string;
				close $fh;

				unless ($self->{was_redirect}) {
					@{$self->{last_cached}} = ();
				}
				push @{$self->{last_cached}}, $fpath;
				$self->{was_redirect} = $response->is_redirect && _in($request->method, $self->requests_redirectable);
			}
			else {
				die "LWP::RobotUA::Cached perform_simple_request failed to open('$fpath', 'w'): $!";
			}
		}
	}

	return $response;
}

sub as_string
{
    my $self = shift;
    my @s;
    push(@s, "Robot: $self->{'agent'} operated by $self->{'from'}  [$self]");
    push(@s, "    Minimum delay: " . int($self->{'delay'}*60) . "s");
    push(@s, "    Will sleep if too early") if $self->{'use_sleep'};
    push(@s, "    Rules = $self->{'rules'}");
    join("\n", @s, '');
}

sub last_cached {
	my $self = shift;
	return exists $self->{last_cached} ?
		@{$self->{last_cached}} : ();
}

sub uncache {
	my $self = shift;
	unlink $_ for $self->last_cached;
}

sub _get_cache_name {
	my ($self, $request) = @_;

	if (defined($self->{cachename_spec}) && %{$self->{cachename_spec}}) {
		my $tmp_request = $request->clone();
		my $leave_only_specified;
		if (exists $self->{cachename_spec}{_headers}) {
			ref $self->{cachename_spec}{_headers} eq 'ARRAY'
				or croak 'cachename_spec->{_headers} should be array ref';
			$leave_only_specified = 1;
		}

		foreach my $hname ($tmp_request->headers->header_field_names) {
			if (exists $self->{cachename_spec}{$hname}) {
				if (defined $self->{cachename_spec}{$hname}) {
					$tmp_request->headers->header($hname, $self->{cachename_spec}{$hname});
				}
				else {
					$tmp_request->headers->remove_header($hname);
				}
			}
			elsif ($leave_only_specified && !_in($hname, $self->{cachename_spec}{_headers})) {
				$tmp_request->headers->remove_header($hname);
			}
		}

		if (exists $self->{cachename_spec}{_body}) {
			$tmp_request->content($self->{cachename_spec}{_body});
		}

		return $self->{cache_dir} . '/' . Digest::MD5::md5_hex($tmp_request->as_string);
	}

	return $self->{cache_dir} . '/' . Digest::MD5::md5_hex($request->as_string);
}

sub _parse_cached_response {
	my ($self, $cache_file, $request) = @_;
	my $fh;
	unless (open $fh, '<:raw', $cache_file) {
		carp "open('$cache_file', 'r'): $!";
		return;
	}

  #
  # Does the URL in the cache match the URL we are requesting ?
  #
	my $url = <$fh>;
	$url =~ s/\s+$//;
	if ($url ne $request->url) {
		close $fh;
		return;
	}

  #
  # Read the contents of the cache file
  #
	local $/ = undef;
	my $response_str = <$fh>;
	close $fh;

  #
  # Create an HTTP::Response object from the contents of the cache
  # file.
  #
	my $response = HTTP::Response->parse($response_str);
	$response->request($request);

  #
  # If we have a cookie jar, extract the cookies that are relavent to
  # the response.
  #
	if ($self->cookie_jar) {
		$self->cookie_jar->extract_cookies($response);
	}

	return $response;
}

sub _in($$) {
	my ($what, $where) = @_;

	foreach my $item (@$where) {
		return 1 if ($what eq $item);
	}

	return 0;
}

1;


__END__

=head1 NAME

LWP::RobotUA - a class for well-behaved Web robots

=head1 SYNOPSIS

  use LWP::RobotUA;
  my $ua = LWP::RobotUA->new('my-robot/0.1', 'me@foo.com');
  $ua->delay(10);  # be very nice -- max one hit every ten minutes!
  ...

  # Then just use it just like a normal LWP::UserAgent:
  my $response = $ua->get('http://whatever.int/...');
  ...

=head1 DESCRIPTION

This class implements a user agent that is suitable for robot
applications.  Robots should be nice to the servers they visit.  They
should consult the F</robots.txt> file to ensure that they are welcomed
and they should not make requests too frequently.

But before you consider writing a robot, take a look at
<URL:http://www.robotstxt.org/>.

When you use an I<LWP::RobotUA> object as your user agent, then you do not
really have to think about these things yourself; C<robots.txt> files
are automatically consulted and obeyed, the server isn't queried
too rapidly, and so on.  Just send requests
as you do when you are using a normal I<LWP::UserAgent>
object (using C<< $ua->get(...) >>, C<< $ua->head(...) >>,
C<< $ua->request(...) >>, etc.), and this
special agent will make sure you are nice.

=head1 METHODS

The LWP::RobotUA is a sub-class of LWP::UserAgent and implements the
same methods. In addition the following methods are provided:

=over 4

=item $ua = LWP::RobotUA->new( %options )

=item $ua = LWP::RobotUA->new( $agent, $from )

=item $ua = LWP::RobotUA->new( $agent, $from, $rules )

The LWP::UserAgent options C<agent> and C<from> are mandatory.  The
options C<delay>, C<use_sleep> and C<rules> initialize attributes
private to the RobotUA.  If C<rules> are not provided, then
C<WWW::RobotRules> is instantiated providing an internal database of
F<robots.txt>.

It is also possible to just pass the value of C<agent>, C<from> and
optionally C<rules> as plain positional arguments.

=item $ua->delay

=item $ua->delay( $minutes )

Get/set the minimum delay between requests to the same server, in
I<minutes>.  The default is 1 minute.  Note that this number doesn't
have to be an integer; for example, this sets the delay to 10 seconds:

    $ua->delay(10/60);

=item $ua->use_sleep

=item $ua->use_sleep( $boolean )

Get/set a value indicating whether the UA should sleep() if requests
arrive too fast, defined as $ua->delay minutes not passed since
last request to the given server.  The default is TRUE.  If this value is
FALSE then an internal SERVICE_UNAVAILABLE response will be generated.
It will have a Retry-After header that indicates when it is OK to
send another request to this server.

=item $ua->rules

=item $ua->rules( $rules )

Set/get which I<WWW::RobotRules> object to use.

=item $ua->no_visits( $netloc )

Returns the number of documents fetched from this server host. Yeah I
know, this method should probably have been named num_visits() or
something like that. :-(

=item $ua->host_wait( $netloc )

Returns the number of I<seconds> (from now) you must wait before you can
make a new request to this host.

=item $ua->as_string

Returns a string that describes the state of the UA.
Mainly useful for debugging.

=back

=head1 SEE ALSO

L<LWP::UserAgent>, L<WWW::RobotRules>

=head1 COPYRIGHT

Copyright 1996-2004 Gisle Aas.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

