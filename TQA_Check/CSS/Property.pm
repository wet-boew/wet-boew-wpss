package CSS::Property;

$VERSION = 1.02;

use strict;
use warnings;

use CSS::Value;

sub new {
	my $class = shift;
	my $self = bless {}, $class;

	$self->{options} = shift;

	$self->{property}	= '';
	$self->{simple_value}	= '';
	$self->{adaptor}	= 'CSS::Adaptor';

	$self->{property}	= $self->{options}->{property} if defined $self->{options}->{property};
	$self->{simple_value}	= $self->{options}->{value} if defined $self->{options}->{value};
	$self->{adaptor}	= $self->{options}->{adaptor} if defined $self->{options}->{adaptor};
	$self->{values}		= [];

	if (defined $self->{simple_value}){
		my $value_obj = new CSS::Value({
					'value'		=> $self->{simple_value},
					'adaptor'	=> $self->{adaptor},
				});
		push @{$self->{values}}, $value_obj;
	}

	return $self;
}

sub set_adaptor {
	my $self = shift;
	my $adaptor = shift;

	# set adaptor
	$self->{adaptor} = $adaptor;
}

sub values {
	my $self = shift;
	my $adaptor_obj = new $self->{adaptor};
	return $adaptor_obj->output_values($self->{values});
}

1;

__END__

=head1 NAME

CSS::Property - A property in a CSS object tree

=head1 SYNOPSIS

  use CSS;

=head1 DESCRIPTION

This module represents a property in a CSS object tree.
Read the CSS.pm pod for information about the CSS object tree.

=head1 METHODS

=head2 CONSTRUCTORS

=over 4

=item C<new()> or C<new( { ..options.. } )>

This constructor returns a new C<CSS::Property> object, with 
an optional hash of options.

  property	property name (as string)
  value		simple value string
  adaptor	adaptor to use for serialization

If the C<value> option is passed, a C<CSS::Value> object is automatically
created and added to the object's values list.

=back

=head2 ACCESSORS

=over 4

=item C<set_adaptor( 'CSS::Adaptor::Foo' )>

This method sets the current adaptor for the object.

=item C<values()>

This method is used to serialize the property's values, using the current
adaptor. It returns a string which comes from the adaptor's C<output_values()>
method.

=back

=head1 AUTHOR

Copyright (C) 2003-2004, Cal Henderson <cal@iamcal.com>

=head1 SEE ALSO

L<CSS>, http://www.w3.org/TR/REC-CSS1

=cut


