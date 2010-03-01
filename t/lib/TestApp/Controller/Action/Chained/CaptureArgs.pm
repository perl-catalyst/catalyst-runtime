package TestApp::Controller::Action::Chained::CaptureArgs;
use warnings;
use strict;

use base qw( Catalyst::Controller );

#
#   This controller build the following patterns of URI:
#      /captureargs/*/*
#      /captureargs/*/*/edit
#      /captureargs/*
#      /captureargs/*/edit
#      /captureargs/test/*
#   It will output the arguments they got passed to @_ after the
#   context object. 
#   /captureargs/one/edit should not dispatch to /captureargs/*/*
#   /captureargs/test/one should not dispatch to /captureargs/*/*

sub base  :Chained('/') PathPart('captureargs') CaptureArgs(0) {
    my ( $self, $c, $arg ) = @_;
    push @{ $c->stash->{ passed_args } }, 'base';
}

sub two_args :Chained('base') PathPart('') CaptureArgs(2) {
    my ( $self, $c, $arg1, $arg2 ) = @_;
    push @{ $c->stash->{ passed_args } }, 'two_args', $arg1, $arg2;
}

sub one_arg :Chained('base') ParthPart('') CaptureArgs(1) {
    my ( $self, $c, $arg ) = @_;
    push @{ $c->stash->{ passed_args } }, 'one_arg', $arg;
}

sub edit_two_args  :Chained('two_args') PathPart('edit') Args(0) {
    my ( $self, $c ) = @_;
    push @{ $c->stash->{ passed_args } }, 'edit_two_args';
}

sub edit_one_arg :Chained('one_arg') PathPart('edit') Args(0) {
    my ( $self, $c ) = @_;
    push @{ $c->stash->{ passed_args } }, 'edit_one_arg';
}

sub view_two_args :Chained('two_args') PathPart('') Args(0) {
    my ( $self, $c ) = @_;
    push @{ $c->stash->{ passed_args } }, 'view_two_args';
}

sub view_one_arg :Chained('one_arg') PathPart('') Args(0) {
    my ( $self, $c ) = @_;
    push @{ $c->stash->{ passed_args } }, 'view_one_arg';
}

sub test_plus_arg :Chained('base') PathPart('test') Args(1) {
    my ( $self, $c, $arg ) = @_;
    push @{ $c->stash->{ passed_args } }, 'test_plus_arg', $arg;
}


sub end : Private {
    my ( $self, $c ) = @_;
    no warnings 'uninitialized';
    $c->response->body( join '; ', @{ $c->stash->{ passed_args } } );
}

1;
