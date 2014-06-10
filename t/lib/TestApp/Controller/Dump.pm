package TestApp::Controller::Dump;

use strict;
use base 'Catalyst::Controller';

sub default : Action {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump');
}

sub env : Action Relative {
    my ( $self, $c ) = @_;
    $c->stash(env => $c->req->env);
    $c->forward('TestApp::View::Dump::Env');
}

sub env_on_engine : Action Relative {
    my ( $self, $c ) = @_;
    # JNAP - I changed this to req since the engine no longer
    # has the env but the tests here are useful.
    $c->stash(env => $c->req->env);
    $c->forward('TestApp::View::Dump::Env');
}

sub request : Action Relative {
    my ( $self, $c ) = @_;
    $c->req->params(undef); # Should be a no-op, and be ignored.
                            # Back compat test for 5.7
    $c->forward('TestApp::View::Dump::Request');
}

sub prepare_parameters : Action Relative {
    my ( $self, $c ) = @_;

    die 'Must pass in parameters' unless keys %{$c->req->parameters};

    $c->req->parameters( {} );
    die 'parameters are not empty' if keys %{$c->req->parameters};

    # Now reset and reload
    $c->prepare_parameters;
    die 'Parameters were not reset' unless keys %{$c->req->parameters};

    $c->forward('TestApp::View::Dump::Request');
}
sub response : Action Relative {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Response');
}

sub body : Action Relative {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Body');
}

1;
