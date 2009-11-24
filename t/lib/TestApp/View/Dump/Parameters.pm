package TestApp::View::Dump::Parameters;

use strict;
use base 'TestApp::View::Dump';

sub process {
    my ( $self, $c ) = @_;
    return $self->SUPER::process( $c, $c->req->parameters );
}

1;
