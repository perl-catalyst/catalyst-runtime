package TestApp;

use Catalyst;

__PACKAGE__->action(
    echo => sub {
        my ( $self, $c ) = @_;

        for my $field ( $c->req->headers->header_field_names ) {
            my $header = ( $field =~ /^X-/ ) ? $field : "X-$field";
            $c->res->headers->header(
                $header => $c->req->headers->header($field) );
        }

        $c->res->headers->content_type('text/plain');
        $c->res->output('ok');
    }
);

package main;

use Test::More tests => 5;
use Catalyst::Test 'TestApp';
use HTTP::Request::Common;

my $request = POST(
    'http://localhost/echo',
    'X-Whats-Cool' => 'Catalyst',
    'Content-Type' => 'form-data',
    'Content'      => [
        catalyst => 'Rocks!',
        file     => [$0],
    ]
);

ok( my $response = request($request) );
ok( $response->content_type eq 'text/plain' );
ok( $response->headers->header('X-Content-Type') =~ /^multipart\/form-data/ );
ok( $response->headers->header('X-Content-Length') ==
      $request->content_length );
ok( $response->headers->header('X-Whats-Cool') eq 'Catalyst' );
