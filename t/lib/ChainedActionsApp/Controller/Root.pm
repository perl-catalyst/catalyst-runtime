package ChainedActionsApp::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

sub setup : Chained('/') PathPart('') CaptureArgs(0) {
    my ( $self, $c ) = @_;
    # Common things here are to check for ACL and setup global contexts
}

sub home : Chained('setup') PathPart('') Args(0) {
    my($self,$c) = @_;
    $c->response->body( "Application Home Page" );
}

sub home_base : Chained('setup') PathPart('') CaptureArgs(2) {
    my($self,$c,$proj_id,$title) = @_;
    $c->stash({project_id=>$proj_id, project_title=>$title});
}

sub hpages : Chained('home_base') PathPart('') Args(0) {
    my($self,$c) = @_;
    $c->response->body( "List project " . $c->stash->{project_title} . " pages");
}

sub hpage : Chained('home_base') PathPart('') Args(2) {
    my($self,$c,$page_id, $pagetitle) = @_;
    $c->response->body( "This is $pagetitle page of " . $c->stash->{project_title} . " project" );
}

sub no_account : Chained('setup') PathPart('account') Args(0) {
    my($self,$c) = @_;
    $c->response->body( "New account o login" );
}

sub account_base : Chained('setup') PathPart('account') CaptureArgs(1) {
    my($self,$c,$acc_id) = @_;
    $c->stash({account_id=>$acc_id});
}

sub account : Chained('account_base') PathPart('') Args(0) {
    my($self,$c,$acc) = @_;
    $c->response->body( "This is account " . $c->stash->{account_id} );
}

sub default : Chained('setup') PathPart('') Args() {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

sub end : Action {}

__PACKAGE__->meta->make_immutable;

1;
