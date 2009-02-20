package DeprecatedTestApp::C::Root;
use strict;
use warnings;
use base qw/Catalyst::Controller/;

__PACKAGE__->config->{namespace} = '';

sub index : Private {
    my ( $self, $c ) = @_;
    $c->res->body('root index');
}

1;
