#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use utf8;

# setup library path
use FindBin qw($Bin);
use lib "$Bin/lib";

use Catalyst::Test 'TestAppWithoutUnicode';
use Encode;
use HTTP::Request::Common;
use URI::Escape qw/uri_escape_utf8/;
use HTTP::Status 'is_server_error';

my $encode_str = "\x{e3}\x{81}\x{82}"; # e38182 is japanese 'あ'
my $decode_str = Encode::decode('utf-8' => $encode_str);
my $escape_str = uri_escape_utf8($decode_str);

check_parameter(GET "/?myparam=$escape_str");

sub check_parameter {
    my ( undef, $c ) = ctx_request(shift);
    is $c->res->output => $encode_str;

    my $myparam = $c->req->param('myparam');
    ok !utf8::is_utf8($myparam);
    is $myparam => $encode_str;

    is scalar(@TestLogger::ELOGS), 2
        or diag Dumper(\@TestLogger::ELOGS);
    like $TestLogger::ELOGS[0], qr/method \"decode\"/;
}

done_testing;
