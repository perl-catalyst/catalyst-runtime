package TestApp::Controller::Action::Path;

use strict;
use base 'TestApp::Controller::Action';

sub one : Action Path("a path with spaces") {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub two : Action Path("åäö") {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub three :Path {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub four : Path( 'spaces_near_parens_singleq' ) {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub five : Path( "spaces_near_parens_doubleq" ) {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

1;
