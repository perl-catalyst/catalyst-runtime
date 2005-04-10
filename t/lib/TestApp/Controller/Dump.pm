package TestApp::Controller::Dump;

use strict;
use base 'Catalyst::Base';

sub default : Action Private {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump');
}

sub parameters : Action Relative {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Parameters');
}

sub request : Action Relative {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub response : Action Relative {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Response');
}

1;
