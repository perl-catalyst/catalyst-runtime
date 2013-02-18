package TestApp::Controller::HTTPMethods;

use Moose;
use MooseX::MethodAttributes;
 
extends 'Catalyst::Controller';
 
sub default : Path Args {
    my ($self, $ctx) = @_;
    $ctx->response->body('default');
}
 
sub get : Path('foo') Method('GET') {
    my ($self, $ctx) = @_;
    $ctx->response->body('get');
}
 
sub post : Path('foo') Method('POST') {
    my ($self, $ctx) = @_;
    $ctx->response->body('post');
}
 
sub get_or_post : Path('bar') Method('GET') Method('POST') {
    my ($self, $ctx) = @_;
    $ctx->response->body('get or post');
}
 
sub any_method : Path('baz') {
    my ($self, $ctx) = @_;
    $ctx->response->body('any');
}

sub base :Chained('/') PathPrefix CaptureArgs(0) { }

sub chained_get :Chained('base') Args(0) GET {
    pop->res->body('chained_get');
}

sub chained_post :Chained('base') Args(0) POST {
    pop->res->body('chained_post');
}

sub chained_put :Chained('base') Args(0) PUT {
    pop->res->body('chained_put');
}

sub chained_delete :Chained('base') Args(0) DELETE {
    pop->res->body('chained_delete');
}

sub get_or_put :Chained('base') PathPart('get_put_post_delete') CaptureArgs(0) GET PUT { }

sub get2 :Chained('get_or_put') PathPart('') Args(0) GET {
    pop->res->body('get2');
}
    
sub put2 :Chained('get_or_put') PathPart('') Args(0) PUT {
    pop->res->body('put2');
}

sub post_or_delete :Chained('base') PathPart('get_put_post_delete') CaptureArgs(0) POST DELETE { }

sub post2 :Chained('post_or_delete') PathPart('') Args(0) POST {
    pop->res->body('post2');
}
    
sub delete2 :Chained('post_or_delete') PathPart('') Args(0) DELETE {
    pop->res->body('delete2');
}

sub check_default :Chained('base') CaptureArgs(0) { }

sub default_get :Chained('check_default') PathPart('') Args(0) GET {
    pop->res->body('get3');
}

sub default_post :Chained('check_default') PathPart('') Args(0) POST {
    pop->res->body('post3');
}

sub chain_default :Chained('check_default') PathPart('') Args(0) {
    pop->res->body('chain_default');
}

__PACKAGE__->meta->make_immutable;
