package CSS::Adaptor;

$VERSION = 1.01;

use strict;
use warnings;

use Carp qw(croak confess);

sub new {
	my $class = shift;
 	my $self = bless {}, $class;
	return $self;
}

sub output_rule {
	my ($self, $rule) = @_;
	return $rule->selectors.' { '.$rule->properties." }\n" ;
}

sub output_selectors {
	my ($self, $selectors) = @_;
	return join ', ', map {$_->{name}} @{$selectors}
}

sub output_properties {
	my ($self, $properties) = @_;
	return join '; ', map {$_->{property}.": ".$_->values} @{$properties};
}

sub output_values {
	my ($self, $values) = @_;
	return join '', map {$_->{value}} @{$values};
}

1;

__END__

=head1 NAME

CSS::Adaptor - Arbitrarily map CSS data for use in another context.

=head1 SYNOPSIS

  use CSS;

  # create a CSS object with an adaptor
  my $css = new CSS({
       'adaptor' => 'CSS::Adaptor',
  });


  # load some CSS data
  $css->read_file( "my_file.css" );


  # change the adaptor
  $css->set_adaptor( "CSS::Adaptor::Pretty" );


  # output CSS object using the current adaptor
  print $css->output();
  

=head1 DESCRIPTION

This class is used by CSS to translate a CSS object to a string. This 
allows CSS data to be easily mapped into other formats.

This documentation is for people who want to write their own CSS::Adaptor
module. For usage information, see the documentation for CSS.

=head1 METHODS

=head2 CONSTRUCTOR

=over 4

=item C<new()>

Called without options.

=back

=head2 FUNCTIONS

=over 4

=item C<output_rule( $rule )>

returns a string containing a formatted CSS::Style object, passed as an object ref

=item C<output_selectors( $selectors )>

returns a string containing a formatted list of CSS::Selector objects, passed as an array ref

=item C<output_properties( $properties )>

returns a string containing a formatted list of CSS::Property objects, passed as an array ref

=item C<output_values( $values )>

returns a string containing a formatted list of CSS::Value objects, passed as an array ref

=back

=head1 AUTHORS

Copyright (C) 2001-2002, Allen Day <allenday@ucla.edu>

Copyright (C) 2003-2004, Cal Henderson <cal@iamcal.com>

=head1 SEE ALSO

L<CSS>

=cut

