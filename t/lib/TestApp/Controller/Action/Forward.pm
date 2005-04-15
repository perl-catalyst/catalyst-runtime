package TestApp::Controller::Action::Forward;

use strict;
use base 'TestApp::Controller::Action';

sub one : Relative {
    my ( $self, $c ) = @_;
    $c->forward('two');
}

sub two : Private {
    my ( $self, $c ) = @_;
    $c->forward('three');
}

sub three : Relative {
    my ( $self, $c ) = @_;
    $c->forward('four');
}

sub four : Private {
    my ( $self, $c ) = @_;
    $c->forward('/action/forward/five');
}

sub five : Relative {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}


sub jojo : Relative {
    my ( $self, $c ) = @_;
    $c->forward('one');
    $c->forward('three');
}


sub inheritance : Relative {
    my ( $self, $c ) = @_;
    $c->forward('/action/inheritance/a/b/default');
    $c->forward('five');
}

sub global : Relative {
    my ( $self, $c ) = @_;
    $c->forward('/global_action');
}


1;
