use strict;
use warnings;
use Test::More;
use utf8;

# setup library path
use FindBin qw($Bin);
use lib "$Bin/lib";

use Catalyst::Test 'TestAppUnicode';
use Encode;
use HTTP::Request::Common;
use URI::Escape qw/uri_escape_utf8/;
use HTTP::Status 'is_server_error';

my $encode_str = "\x{e3}\x{81}\x{82}"; # e38182 is japanese 'あ'
my $decode_str = Encode::decode('utf-8' => $encode_str);
my $escape_str = uri_escape_utf8($decode_str);

sub check_parameter {
    my ( undef, $c ) = ctx_request(shift);
    is $c->res->output => '<h1>It works</h1>';

    my $foo = $c->req->param('foo');
    is $foo, $decode_str;

    my $other_foo = $c->req->method eq 'POST'
        ? $c->req->upload('foo')
            ? $c->req->upload('foo')->filename
            : $c->req->body_parameters->{foo}
        : $c->req->query_parameters->{foo};

    is $other_foo => $decode_str;
}

sub check_argument {
    my ( undef, $c ) = ctx_request(shift);
    is $c->res->output => '<h1>It works</h1>';

    my $foo = $c->req->args->[0];
    is $foo => $decode_str;
}

sub check_capture {
    my ( undef, $c ) = ctx_request(shift);
    is $c->res->output => '<h1>It works</h1>';

    my $foo = $c->req->captures->[0];
    is $foo => $decode_str;
}

sub check_fallback {
  my ( $res, $c ) = ctx_request(shift);
  ok(!is_server_error($res->code)) or diag('Response code is: ' . $res->code);
}

check_parameter(GET "/?foo=$escape_str");
check_parameter(POST '/', ['foo' => $encode_str]);
check_parameter(POST '/',
    Content_Type => 'form-data',
    Content => [
        'foo' => [
            "$Bin/unicode_plugin_request_decode.t",
            $encode_str,
        ]
    ],
);

check_argument(GET "/$escape_str");
check_capture(GET "/capture/$escape_str");

# sending non-utf8 data
my $non_utf8_data = "%C3%E6%CB%AA";
check_fallback(GET "/?q=${non_utf8_data}");
check_fallback(GET "/${non_utf8_data}");
check_fallback(GET "/capture/${non_utf8_data}");
check_fallback(POST '/', ['foo' => $non_utf8_data]);

done_testing;
