package CSS::Style;

$VERSION = 1.02;

use strict;
use warnings;
use overload '""' => 'to_string';

# create a new CSS::Style object
sub new {
	my $class = shift;
	my $self = bless {}, $class;

	$self->{options} = shift;
	$self->{selectors} = [];
	$self->{properties} = [];
	$self->{adaptor} = $self->{options}->{adaptor} || 'CSS::Adaptor';

	return $self;
}

sub add_selector {
	my $self = shift;
	my $selector = shift;

	push @{$self->{selectors}}, $selector;
	$selector->set_adaptor($self->{adaptor});
}

sub add_property {
	my $self = shift;
	my $property = shift;

	push @{$self->{properties}}, $property;
	$property->set_adaptor($self->{adaptor});
}

sub set_adaptor {
	my $self = shift;
	my $adaptor = shift;

	# set adaptor
	$self->{adaptor} = $adaptor;

	# recurse adaptor
	$_->set_adaptor($adaptor) for(@{$self->{selectors}});
	$_->set_adaptor($adaptor) for(@{$self->{properties}});
}

sub selectors {
	my $self = shift;
	eval "use $self->{adaptor}";
	my $adaptor_obj = new $self->{adaptor};
	return $adaptor_obj->output_selectors($self->{selectors});
}

sub properties {
	my $self = shift;
	eval "use $self->{adaptor}";
	my $adaptor_obj = new $self->{adaptor};
	return $adaptor_obj->output_properties($self->{properties});
}

sub to_string {
	my $self = shift;
	eval "use $self->{adaptor}";
	my $adaptor_obj = new $self->{adaptor};
	return $adaptor_obj->output_rule($self);
}

sub get_property_by_name {
        my ($self, $prop_name) = @_;

        for my $prop (@{$self->{properties}}){
                if ($prop->{property} eq $prop_name){
                        return $prop;
                }
        }
        return 0;
}

1;

__END__

=head1 NAME

CSS::Style - A ruleset in a CSS object tree

=head1 SYNOPSIS

  use CSS;

=head1 DESCRIPTION

This module represents a ruleset in a CSS object tree.
Read the CSS.pm pod for information about the CSS object tree.

=head1 METHODS

=head2 CONSTRUCTORS

=over 4

=item C<new()> or C<new( { ..options.. } )>

This constructor returns a new C<CSS::Style> object, with
an optional hash of options.

  adaptor       adaptor to use for serialization

=back

=head2 ACCESSORS

=over 4

=item C<add_selector( $selector )>

This method adds a selector to the selector list for the object.
C<$selector> is a reference to a CSS::Selector object.

=item C<add_property( $property )>

This method adds a selector to the property list for the object.
C<$property> is a reference to a CSS::Property object.

=item C<set_adaptor( 'CSS::Adaptor::Foo' )>

This method sets the current adaptor for the object.

=item C<selectors()>

This method is used to serialize the ruleset's selectors, using the current
adaptor. It returns a string which come from the adaptor's C<output_selectors()>
method.

=item C<properties()>

This method is used to serialize the ruleset's properties, using the current
adaptor. It returns a string which come from the adaptor's C<output_properties()>
method.

=item C<to_string()>

This method is used to serialize the ruleset, using the current adaptor. It returns 
a string which comes from the adaptor's output_rules() method.

=item C<get_property_by_name( 'property_name' )>

Returns the first CSS::Property object with the specified name. Returns
zero on failure.

=back

=head1 AUTHOR

Copyright (C) 2003-2004, Cal Henderson <cal@iamcal.com>

=head1 SEE ALSO

L<CSS>, http://www.w3.org/TR/REC-CSS1

=cut


