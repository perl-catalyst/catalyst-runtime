package TestApp::Controller::BodyParams;

use strict;
use base 'Catalyst::Controller';

sub default : Private {
    my ( $self, $c ) = @_;
    $c->req->body_params({override => 'that'});
    $c->res->output($c->req->body_params->{override});
    $c->res->status(200);
}

1;
