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

# For contextual uri_for
sub just_one_arg     : Chained(/) Args(1) {}
sub leading_capture  : Chained(/) PathPart('') CaptureArgs(1) {}
sub midpoint_capture : Chained(leading_capture) CaptureArgs(1) {}
sub slurpy_endpoint  : Chained(midpoint_capture) Args {}

1;
