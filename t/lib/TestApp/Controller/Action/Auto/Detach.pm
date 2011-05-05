package TestApp::Controller::Action::Auto::Detach;

use strict;
use base 'TestApp::Controller::Action';

sub auto : Private {
    my ( $self, $c ) = @_;
    $c->res->body( "detach auto" );
    if ($c->req->param("with_forward_detach")) {
        $c->forward("with_forward_detach");
    } else {
        $c->detach;
    }
    return 1;
}

sub default : Path {
    my ( $self, $c ) = @_;
    $c->res->body( 'detach default' );
}

sub with_forward_detach : Private {
    my ($self, $c) = @_;
    $c->res->body( "detach with_forward_detach" );
    if ($c->req->param("detach_to_action")) {
        $c->detach("detach_action");
    } else {
        $c->detach;
    }
}

sub detach_action : Private {
    my ($self, $c) = @_;
    $c->res->body("detach_action");
}

1;
