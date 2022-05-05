package CSS;

$VERSION = 1.08;

use strict;
use warnings;

use Carp;
use CSS::Style;
use CSS::Selector;
use CSS::Property;
use CSS::Adaptor;

use Data::Dumper;

sub new {
	my $class = shift;
	my $self = bless {}, $class;

	my $options = shift;
	$self->{styles} = [];
	$self->{parser} = $options->{parser} || 'CSS::Parse::Lite';
	$self->{adaptor} = $options->{adaptor} || 'CSS::Adaptor';

	return $self;
}

sub read_file {
	my $self = shift;
	my $path = shift;

	if (ref $path){
		if (ref $path eq 'ARRAY'){
			$self->read_file($_) for @$path;
			return 1;
		}
	} else {
 		if ($path){
			local *IN;
 			open(IN, $path) or croak "couldn't open file: $!";
			my $source = join '',<IN>;
			close(IN);
			$self->parse_string($source) if $source;
			return 1;
		}
	}
	croak "only scalars and arrays accepted: $!";
}

sub read_string {
	my $self = shift;
	my $data = shift;

	if (ref $data){
		if (ref $data eq 'ARRAY'){
			$self->read_string($_) for @$data;
			return 1;
		}
	} else {
		$self->parse_string($data) if length $data;
	}
}

sub parse_string {
	my $self = shift;
	my $string = shift;

	# remove comments
	$string =~ s!/\*.*?\*\/!!g;
	$string =~ s|<!--||g;
	$string =~ s|-->||g;

	eval "use $self->{parser}";
	my $parser_obj = new $self->{parser};
	$parser_obj->{'parent'} = $self;
	$parser_obj->parse_string($string);
}

sub purge {
	my $self = shift;
	$self->{styles} = [];
}

sub set_adaptor {
	my $self = shift;
	my $adaptor = shift;

	$self->{adaptor} = $adaptor;

	for(@{$self->{styles}}){
		$_->set_adaptor($adaptor);
	}
}

sub output {
	my $self = shift;
	my $adaptor = shift || $self->{adaptor};

	for(@{$self->{styles}}){
		$_->set_adaptor($adaptor);
	}

	my $output = '';
	for(@{$self->{styles}}){
		$output .= "$_";
	}

	return $output;
}

sub get_style_by_selector {
	my ($self, $sel_name) = @_;

        for my $style (@{$self->{styles}}){
                for my $selector (@{$style->{selectors}}){
                        if ($selector->{name} eq $sel_name){
                                return $style;
                        }
                }
        }
        return 0;
}

1;
__END__

=head1 NAME

CSS - Object oriented access to Cascading Style Sheets (CSS)

=head1 SYNOPSIS

  use CSS;

  # create a CSS object with the default options  
  my $css = CSS->new();

  # create a CSS object with a specific parser
  my $css = CSS->new( { 'parser' => 'CSS::Parse::Lite' } );
  my $css = CSS->new( { 'parser' => 'CSS::Parse::Heavy' } );
  my $css = CSS->new( { 'parser' => 'CSS::Parse::Compiled' } );

  # create a CSS object with a specific adaptor
  my $css = CSS->new( { 'adaptor' => 'CSS::Adaptor' } );
  my $css = CSS->new( { 'adaptor' => 'CSS::Adaptor::Pretty' } );
  my $css = CSS->new( { 'adaptor' => 'CSS::Adaptor::Debug' } );



  # parse some CSS from a string
  $css->read_string( $css_data );
  $css->read_string( ( $css_data, $more_css_data ) );

  # parse some CSS from a file
  $css->read_file( 'my_file.css' );
  $css->read_file( ( 'my_file.css', 'my_other_file.css' ) );



  # output the CSS using the current adaptor
  print $css->output();

  # set a new adaptor and then output the CSS
  $css->set_adaptor( 'CSS::Adaptor::Foo' );
  print $css->output();

  # output the CSS using a tempory adaptor
  print $css->output( 'CSS::Adaptor::Bar' );



  # forget about the CSS we've already parsed
  $css->purge();


=head1 DESCRIPTION

This module can be used, along with a CSS::Parse::* module, to parse
CSS data and represent it as a tree of objects. Using a CSS::Adaptor::*
module, the CSS data tree can then be transformed into other formats.

=head1 NOTICE

From version 1.00 of this module onwards, backwards compatibility is
broken. This is due to large changes in the way data is parsed and
then represented internally. Version 0.08 is still available on
CPAN: L<http://search.cpan.org/author/IAMCAL/CSS-0.08/>

=head1 TREE STRUCTURE

The CSS object is the head of the tree. It contains a list of 
CSS::Style objects which each represent a CSS ruleset. Each of
these objects contains a list of selectors and properties. Each
selector is stored as a CSS::Selector object. Each property
object is stored as a CSS::Property object and contains a list
of values. These values are stored as CSS::Value objects.

  foo, bar {
      baz: fop;
      woo: yay houpla;
  }

The above example would be represented as a single CSS::Style object.
That object would then have two CSS::Selector objects representing
'foo' and 'bar'. It would also have two CSS::Property objects 
representing 'baz' and 'woo'. The 'baz' object then has a single child
CSS::Value object for 'fop', whilst the 'woo' object has two
child objects for 'yay' and 'houpla'.

=head1 METHODS

=head2 CONSTRUCTOR

=over 4

=item C<new()> or C<new( { ..options.. } )>

An optional hash can contain arguments:

  parser	module to use as the CSS parser
  adaptor	adaptor to use for output

=back

=head2 ACCESSORS

=over 4

=item C<read_file( $filename )> or C<read_file( @filenames )>

Read one or mores files and parse the CSS within them.


=item C<read_string( $scalar )> or C<read_string( @strings )>

Read one or more strings and parse the CSS within them.


=item C<output()> or C<output( 'CSS::Adaptor::Foo' )>

Return a string representation of the CSS tree, using either the 
current adaptor or the specified one.


=item C<set_adaptor( 'CSS::Adaptor::Bar' )>

Set the current adaptor for the CSS tree.


=item C<purge()>

Forget all the objects in the CSS tree;


=item C<get_style_by_selector( 'selector_name' )>

Returns the first CSS::Style object with the specified selector
name attached. Returns zero on failure.


=back

=head1 AUTHORS

Copyright (C) 2001-2002, Allen Day <allenday@ucla.edu>

Copyright (C) 2003-2004, Cal Henderson <cal@iamcal.com>

=head1 SEE ALSO

L<CSS::Style>, L<CSS::Selector>, L<CSS::Property>, L<CSS::Value>, 
L<CSS::Parse>, L<CSS::Parse::Lite>, L<CSS::Parse::Heavy>, 
L<CSS::Parse::Compiled>, L<CSS::Parse::PRDGrammar>, L<CSS::Adaptor>, 
L<CSS::Adaptor::Pretty>, L<CSS::Adaptor::Debug>, perl(1)

=cut

