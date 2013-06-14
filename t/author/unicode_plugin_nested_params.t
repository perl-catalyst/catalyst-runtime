#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use utf8;

# setup library path
use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN { eval { require Catalyst::Plugin::Params::Nested; 1; } ||
    plan skip_all => 'Need Catalyst::Plugin::Params::Nested' }

use Catalyst::Test 'TestApp2';
use Encode;
use HTTP::Request::Common;
use URI::Escape qw/uri_escape_utf8/;
use HTTP::Status 'is_server_error';

my $encode_str = "\x{e3}\x{81}\x{82}"; # e38182 is japanese 'あ'
my $decode_str = Encode::decode('utf-8' => $encode_str);
my $escape_str = uri_escape_utf8($decode_str);

BEGIN {
    eval 'require Catalyst::Plugin::Params::Nested';
    plan skip_all => 'Catalyst::Plugin::Params::Nested is required' if $@;
}

{
    my ($res, $c) = ctx_request("/?foo.1=bar&foo.2=$escape_str");
    is( $c->res->output, '<h1>It works</h1>', 'Content displayed' );
    
    my $got = $c->request->parameters;
    my $expected = {
        'foo.1' => 'bar',
        'foo.2' => $decode_str,
        'foo'   => [undef, 'bar', $decode_str],
    };
    
    is( $got->{foo}->[0], undef, '{foo}->[0] is undef' );
    is( $got->{foo}->[1], 'bar', '{foo}->[1] is bar' );
    ok( utf8::is_utf8( $got->{'foo.2'}       ), '{foo.2} is utf8' );
    ok( utf8::is_utf8( $got->{foo}->[2]      ), '{foo}->[2] is utf8' );
    is_deeply($got, $expected, 'nested params' );
}

{
    my ($res, $c) = ctx_request("/?foo.1=bar&foo.2=$escape_str&bar.baz=$escape_str&baz.bar.foo=$escape_str&&arr.0.1=$escape_str");
    
    my $got = $c->request->parameters;
    my $expected = {
        'foo.1'       => 'bar',
        'foo.2'       => $decode_str,
        'bar.baz'     => $decode_str,
        'baz.bar.foo' => $decode_str,
        'arr.0.1'     => $decode_str,
        'arr'         => [ [undef, $decode_str] ],
        'foo'         => [undef, 'bar', $decode_str],
        'bar'         => { baz => $decode_str },
        'baz'         => { bar => { foo => $decode_str } },
    };
    
    is( ref $got->{arr}->[0], 'ARRAY', '{arr}->[0] is ARRAY' );
    ok( utf8::is_utf8( $got->{arr}->[0]->[1] ), '{arr}->[0]->[1] is utf8' );
    ok( utf8::is_utf8( $got->{bar}{baz}      ), '{bar}{baz} is utf8' );
    ok( utf8::is_utf8( $got->{baz}{bar}{foo} ), '{baz}{bar}{foo} is utf8' );
    is_deeply($got, $expected, 'nested params' );
}

done_testing();
