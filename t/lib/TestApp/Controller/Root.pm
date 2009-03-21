package TestApp::Controller::Root;

use base 'Catalyst::Controller';

__PACKAGE__->config->{namespace} = '';

sub chain_root_index : Chained('/') PathPart('') Args(0) { }

sub zero : Path('0') {
    my ( $self, $c ) = @_;
    $c->res->header( 'X-Test-Class' => ref($self) );
    $c->response->content_type('text/plain; charset=utf-8');
    $c->forward('TestApp::View::Dump::Request');
}

sub localregex : LocalRegex('^localregex$') {
    my ( $self, $c ) = @_;
    $c->res->header( 'X-Test-Class' => ref($self) );
    $c->response->content_type('text/plain; charset=utf-8');
    $c->forward('TestApp::View::Dump::Request');
}

sub chain_to_self : Chained('chain_to_self') PathPart('') CaptureArgs(1) { }

sub chain_recurse_endoint : Chained('chain_to_self') Args(0) { }

1;
