package TestApp::Controller::Engine::Response::Cookies;

use strict;
use base 'Catalyst::Base';

sub one : Relative {
    my ( $self, $c ) = @_;
    $c->res->cookies->{Catalyst} = { value => 'Cool',     path => '/' };
    $c->res->cookies->{Cool}     = { value => 'Catalyst', path => '/' };
    $c->forward('TestApp::View::Dump::Request');
}

sub two : Relative {
    my ( $self, $c ) = @_;
    $c->res->cookies->{Catalyst} = { value => 'Cool',     path => '/' };
    $c->res->cookies->{Cool}     = { value => 'Catalyst', path => '/' };
    $c->res->redirect('http://www.google.com/');
}

1;
