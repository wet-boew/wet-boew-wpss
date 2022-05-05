package CSS::Parse;

$VERSION = 1.01;

use strict;
use warnings;

# Create an empty object
sub new {
	my $class = shift;
	my $self = bless {}, $class;
	
	$self->{parent} = undef;

	return $self;
}

# The main parser
sub parse_string {
	my $self = shift;
	my $string = shift;

	die("CSS::Parse is not a valid parser! Use a subclass instead (CSS::Parse::*)\n");
}

1;

__END__

=head1 NAME

CSS::Parse - Template class for CSS parser modules

=head1 DESCRIPTION

This module should not be used directly. Instead, use the CSS::Parse::* modules.

=head1 AUTHOR

Copyright (C) 2003-2004, Cal Henderson <cal@iamcal.com>

=head1 SEE ALSO

L<CSS>

=cut

