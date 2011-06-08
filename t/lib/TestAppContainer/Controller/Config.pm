package TestAppContainer::Controller::Config;

use strict;
use warnings;

use base qw( Catalyst::Controller );

sub index : Private {
    my ( $self, $c ) = @_;
    $c->res->output( $self->{ foo } );
}

sub appconfig : Global {
    my ( $self, $c, $var ) = @_;
    $c->res->body( $c->config->{ $var } );
}

1;
