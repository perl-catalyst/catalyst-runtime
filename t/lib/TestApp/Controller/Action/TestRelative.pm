package TestApp::Controller::Action::TestRelative;

use strict;
use base 'TestApp::Controller::Action';

__PACKAGE__->config(
  path => 'action/relative'
);

sub relative : Local {
    my ( $self, $c ) = @_;
    $c->forward('/action/forward/one');
}

sub relative_two : Local {
    my ( $self, $c ) = @_;
    $c->forward( 'TestApp::Controller::Action::Forward', 'one' );
}

1;
