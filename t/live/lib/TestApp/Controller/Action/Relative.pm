package TestApp::Controller::Action::Relative;

use strict;
use base 'TestApp::Controller::Action';

sub relative : Local {
    my ( $self, $c ) = @_;
    $c->forward('/action/forward/one');
}

sub relative_two : Local {
    my ( $self, $c ) = @_;
    $c->forward( 'TestApp::Controller::Action::Forward', 'one' );
}

1;
