package TestApp::Controller::Action::Forward;

use strict;
use base 'TestApp::Controller::Action';

sub one : Local {
    my ( $self, $c ) = @_;
    $c->forward('two');
}

sub two : Private {
    my ( $self, $c ) = @_;
    $c->forward('three');
}

sub three : Local {
    my ( $self, $c ) = @_;
    $c->forward('four');
}

sub four : Private {
    my ( $self, $c ) = @_;
    $c->forward('/action/forward/five');
}

sub five : Local {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub jojo : Local {
    my ( $self, $c ) = @_;
    $c->forward('one');
    $c->forward('three');
}

sub inheritance : Local {
    my ( $self, $c ) = @_;
    $c->forward('/action/inheritance/a/b/default');
    $c->forward('five');
}

sub global : Local {
    my ( $self, $c ) = @_;
    $c->forward('/global_action');
}

sub with_args : Local {
    my ( $self, $c, $orig ) = @_;
    $c->forward( 'args', [qq/new/] );
    $c->res->body( $c->req->args->[0] );
}

sub with_method_and_args : Local {
    my ( $self, $c, $orig ) = @_;
    $c->forward( qw/TestApp::Controller::Action::Forward args/, [qq/new/] );
    $c->res->body( $c->req->args->[0] );
}

sub args : Local {
    my ( $self, $c, $val ) = @_;
    die "Expected argument 'new', got '$val'" unless $val eq 'new';
    die "passed argument does not match args" unless $val eq $c->req->args->[0];
}

sub args_embed_relative : Local {
    my ( $self, $c ) = @_;
    $c->forward( 'embed/ok' );
}

sub args_embed_absolute : Local {
    my ( $self, $c ) = @_;
    $c->forward( '/action/forward/embed/ok' );
}

sub embed : Local {
    my ( $self, $c, $ok ) = @_;
    
    $ok ||= 'not ok';
    $c->res->body( $ok );
}

1;
