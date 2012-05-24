package TestApp::Controller::BodyParams;

use strict;
use base 'Catalyst::Controller';

sub default : Private {
    my ( $self, $c ) = @_;
    $c->req->body_params({override => 'that'});
    $c->res->output($c->req->body_params->{override});
    $c->res->status(200);
}

sub no_params : Local {
    my ( $self, $c ) = @_;
    my $params = $c->req->body_parameters;
    $c->res->output(ref $params);
    $c->res->status(200);
}

1;
