package CSS::Value;

$VERSION = 1.03;

use strict;
use warnings;
use overload '""' => 'to_string';

sub new {
        my $class = shift;
        my $self = bless {}, $class;

	$self->{options}	= shift;
	$self->{value}		= '';
	$self->{adaptor}	= 'CSS::Adaptor';

        $self->{value}		= $self->{options}->{value} if defined $self->{options}->{value};
	$self->{adaptor}	= $self->{options}->{adaptor} if defined $self->{options}->{adaptor};

        return $self;
}

sub to_string {
	my $self = shift;
	my $adaptor_obj = new $self->{adaptor};
	return $adaptor_obj->output_value($self);
}

1;

__END__

=head1 NAME

CSS::Value - A property value in a CSS object tree

=head1 SYNOPSIS

  use CSS;

=head1 DESCRIPTION

This module represents a property value in a CSS object tree.
Read the CSS.pm pod for information about the CSS object tree.

=head1 METHODS

=head2 CONSTRUCTORS

=over 4

=item C<new()> or C<new( { ..options.. } )>

This constructor returns a new C<CSS::Value> object, with
an optional hash of options.

  value		value string
  adaptor       adaptor to use for serialization

=back

=head2 ACCESSORS

=over 4

=item C<to_string()>

This method is used to serialize the value.

=back

=head1 AUTHOR

Copyright (C) 2003-2004, Cal Henderson <cal@iamcal.com>

=head1 SEE ALSO

L<CSS>, http://www.w3.org/TR/REC-CSS1

=cut


