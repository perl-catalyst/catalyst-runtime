use Test::More tests => 6;
use strict;
use warnings;

{

    package MyApp;
    use Catalyst qw/-Engine=Test/;
    use Test::Exception;

    sub stream_it : Local {
        my ( $self, $c ) = @_;

        lives_ok { $c->res->headers->content_encoding("moose") }
          "can set header";
        lives_ok { $c->res->headers->remove_header("moose") }
          "can remove header";
        lives_ok { $c->res->cookies->{yadda} = { value => "ping" } }
          "can make cookie";
        $c->write("foo");
        throws_ok { $c->res->headers->content_encoding("moose") }
          qr/can't modify/i, "can't set header after write";
        throws_ok { $c->res->headers->remove_header("moose") }
          qr/can't modify/i, "can't remove header after write";
        throws_ok { $c->res->cookies->{yadda} = { value => "ping" } }
          qr/read-only/i, "can't make cookie after write";
    }

    __PACKAGE__->setup;
}

use Catalyst::Test qw/MyApp/;

get "/stream_it";

