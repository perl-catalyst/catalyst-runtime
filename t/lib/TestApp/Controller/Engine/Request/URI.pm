package TestApp::Controller::Engine::Request::URI;

use strict;
use base 'Catalyst::Base';

sub default : Private {
    my ( $self, $c ) = @_;
    
    $c->forward('TestApp::View::Dump::Request');
}

sub change_path : Local {
    my ( $self, $c ) = @_;
    
    # change the path
    $c->req->path( '/my/app/lives/here' );
    
    $c->forward('TestApp::View::Dump::Request');
}

sub change_base : Local {
    my ( $self, $c ) = @_;
    
    # change the base and uri paths
    $c->req->base->path( '/new/location' );
    $c->req->uri->path( '/new/location/engine/request/uri/change_base' );
    
    $c->forward('TestApp::View::Dump::Request');
}

1;
