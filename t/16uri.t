package TestApp;

use Catalyst qw[-Engine=Test];

TestApp->action( '!default'  => \&default );
TestApp->action( 'index/a/b' => \&default );

sub default {
    my ( $self, $c ) = @_;
    $c->res->headers->header( 'X-Arguments' => $c->req->arguments );
    $c->res->headers->header( 'X-Base' => $c->req->base );
    $c->res->headers->header( 'X-Path' => $c->req->path );
    $c->res->headers->content_type('text/plain');
    $c->res->output('ok');
}

package main;

use Test::More tests => 9;
use Catalyst::Test 'TestApp';

{
    local %ENV;

    $ENV{SCRIPT_NAME} = '/nph-catalyst.cgi';
    $ENV{PATH_INFO}   = '/index';

    my $response = request('/nph-catalyst.cgi/index');

    ok( $response->headers->header('X-Base') eq 'http://localhost/nph-catalyst.cgi' );
    ok( $response->headers->header('X-Arguments') eq 'index' );
    ok( $response->headers->header('X-Path') eq 'index' );
}

{
    local %ENV;

    my $response = request('/index?a=a&b=b');

    ok( $response->headers->header('X-Base') eq 'http://localhost/' );
    ok( $response->headers->header('X-Arguments') eq 'index' );
    ok( $response->headers->header('X-Path') eq 'index' );
}

{
    local %ENV;

    my $response = request('http://localhost:8080/index/a/b/c');

    ok( $response->headers->header('X-Base') eq 'http://localhost:8080/' );
    ok( $response->headers->header('X-Arguments') eq 'c' );
    ok( $response->headers->header('X-Path') eq 'index/a/b/c' );
}
