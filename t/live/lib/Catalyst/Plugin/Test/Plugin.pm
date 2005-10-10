package Catalyst::Plugin::Test::Plugin;

use strict;

use base 'Class::Data::Inheritable';

 __PACKAGE__->mk_classdata('ran_setup');

sub setup {
   my $c = shift;
   $c->ran_setup('1');
}

sub  prepare {

    my $class = shift;

    my $c = $class->NEXT::prepare(@_);
    $c->response->header( 'X-Catalyst-Plugin-Setup' => $c->ran_setup );

    return $c;

}

1;
