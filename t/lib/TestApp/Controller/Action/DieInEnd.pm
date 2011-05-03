package TestApp::Controller::Action::DieInEnd;

use strict;
use base 'TestApp::Controller::Action';

sub end : Private {
    my ( $self, $c ) = @_;
    die "I'm ending with death";
}

sub default : Private {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

1;
