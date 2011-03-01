package TestApp::Controller::Engine::Request::Uploads;

use strict;
use base 'Catalyst::Controller';

sub slurp : Relative {
    my ( $self, $c ) = @_;
    $c->response->content_type('text/plain; charset=utf-8');
    my $upload = $c->request->upload('slurp');
    my $contents = $upload->slurp;
    my $contents2 = $upload->slurp;
    die("Slurp not callable multiple times") unless $contents eq $contents2;
    $c->response->output( $c->request->upload('slurp')->slurp );
}

1;
