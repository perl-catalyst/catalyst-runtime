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

sub index : Private {
    my ( $self, $c ) = @_;
    $c->res->body('root index');
}

sub global_action : Private {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub class_forward_test_method :Private {
    my ( $self, $c ) = @_;
    $c->response->headers->header( 'X-Class-Forward-Test-Method' => 1 );
}

sub loop_test : Local {
    my ( $self, $c ) = @_;

    for( 1..1001 ) {
        $c->forward( 'class_forward_test_method' );
    }
}

sub recursion_test : Local {
    my ( $self, $c ) = @_;
    $c->forward( 'recursion_test' );
}

1;
