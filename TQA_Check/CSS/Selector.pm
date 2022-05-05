package CSS::Selector;

$VERSION = 1.01;

use strict;
use warnings;


sub new {
	my $class = shift;
	my $self = bless {}, $class;

	$self->{options}	= shift;
	$self->{name}		= $self->{options}->{name} || 'NO_NAME';
	$self->{adaptor}	= $self->{options}->{adaptor} || 'CSS::Adaptor';

	return $self;
}

sub set_adaptor {
	my $self = shift;
	my $adaptor = shift;

	# set adaptor
	$self->{adaptor} = $adaptor;
}

1;

__END__

=head1 NAME

CSS::Selector - A selector in a CSS object tree

=head1 SYNOPSIS

  use CSS;

=head1 DESCRIPTION

This module represents a selector in a CSS object tree.
Read the CSS.pm pod for information about the CSS object tree.

=head1 METHODS

=head2 CONSTRUCTORS

=over 4

=item C<new()> or C<new( { ..options.. } )>

This constructor returns a new C<CSS::Selector> object, with
an optional hash of options.

  name      	selector name (as string)
  adaptor       adaptor to use for serialization

=back

=head2 ACCESSORS

=over 4

=item C<set_adaptor( 'CSS::Adaptor::Foo' )>

This method sets the current adaptor for the object.

=back

=head1 AUTHOR

Copyright (C) 2003-2004, Cal Henderson <cal@iamcal.com>

=head1 SEE ALSO

L<CSS>, http://www.w3.org/TR/REC-CSS1

=cut


