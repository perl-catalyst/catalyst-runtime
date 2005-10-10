package TestApp::Controller::Action::Local;

use strict;
use base 'TestApp::Controller::Action';

sub one : Action Relative {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub two : Action Local {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub three : Action Path('three') {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub four : Action Path('four/five/six') {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

1;
