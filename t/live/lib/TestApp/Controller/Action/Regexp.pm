package TestApp::Controller::Action::Regexp;

use strict;
use base 'TestApp::Controller::Action';

sub one : Action Regexp('^action/regexp/(\w+)/(\d+)$') {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub two : Action Regex('^action/regexp/(\d+)/(\w+)$') {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

1;
