package TestApp::Controller::Engine::Request::Uploads;

use strict;
use base 'Catalyst::Base';

sub slurp : Relative {
    my ( $self, $c ) = @_;
    $c->response->content_type('text/plain; charset=utf-8');
    $c->response->output( $c->request->upload('slurp')->slurp );
}

1;
