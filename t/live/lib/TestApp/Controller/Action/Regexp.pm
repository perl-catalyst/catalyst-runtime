package TestApp::Controller::Action::Regexp;

use strict;
use base 'TestApp::Controller::Action';

sub one : Action Regex('^action/regexp/(\w+)/(\d+)$') {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub two : Action Regexp('(\d+)/(\w+)$') {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

1;
