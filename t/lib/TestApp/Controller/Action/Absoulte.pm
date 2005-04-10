package TestApp::Controller::Action::Absoulte;

use strict;
use base 'TestApp::Controller::Action';

sub action_absolute_one : Action Absolute {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub action_absolute_two : Action Global {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub action_absolute_three : Action Path('/action_absolute_three') {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

1;
