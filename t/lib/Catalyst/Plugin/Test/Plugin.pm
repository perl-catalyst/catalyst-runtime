package Catalyst::Plugin::Test::Plugin;

use strict;

use base qw/Catalyst::Base Class::Data::Inheritable/;

 __PACKAGE__->mk_classdata('ran_setup');

sub setup {
   my $c = shift;
   $c->ran_setup('1');
}

sub  prepare {

    my $class = shift;

# Note: This use of NEXT is deliberately left here (without a use NEXT)
#       to ensure back compat, as NEXT always used to be loaded, but 
#       is now replaced by Class::C3::Adopt::NEXT.
    my $c = $class->NEXT::prepare(@_);
    $c->response->header( 'X-Catalyst-Plugin-Setup' => $c->ran_setup );

    return $c;

}

sub end : Private {
    my ($self,$c) = @_;
}

1;
