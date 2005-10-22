package TestApp::Controller::Index;

use strict;
use base 'Catalyst::Base';

sub index : Private {
    my ( $self, $c ) = @_;
    $c->res->body( 'Index index' );
}

1;
