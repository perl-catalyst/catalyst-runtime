package Catalyst::Plugin::Test::Plugin;

use strict;
use warnings;
use MRO::Compat;

use base qw/Class::Data::Inheritable/;

 __PACKAGE__->mk_classdata('ran_setup');

sub setup {
   my $c = shift;
   $c->ran_setup('1');
}

sub prepare {
    my $class = shift;

    my $c = $class->next::method(@_);
    $c->response->header( 'X-Catalyst-Plugin-Setup' => $c->ran_setup );

    return $c;
}


1;
