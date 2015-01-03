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
use Data::Dumper;

my $encode_str = "\x{e3}\x{81}\x{82}"; # e38182 is japanese 'あ'
my $decode_str = Encode::decode('utf-8' => $encode_str);
my $escape_str = uri_escape_utf8($decode_str);

# JNAP - I am removing this test case because I think its not correct.  I think
# we do not check the server encoding to determine if the parts of a request URL
# both paths and query should be decoded.  I think its always safe to assume utf8
# encoded urlencoded bits.  That is my reading of the spec.  Please correct me if
# I am wrong
#check_parameter(GET "/?myparam=$escape_str");
check_parameter(POST '/',
    Content_Type => 'form-data',
    Content => [
        'myparam' => [
            "$Bin/unicode_plugin_no_encoding.t",
            "$Bin/unicode_plugin_request_decode.t",
        ]
    ],
);

sub check_parameter {
    my ( undef, $c ) = ctx_request(shift);

    my $myparam = $c->req->param('myparam');
    unless ( $c->request->method eq 'POST' ) {
        is $c->res->output => $encode_str;
        is $myparam => $encode_str;
    }

    is scalar(@TestLogger::ELOGS), 0
        or diag Dumper(\@TestLogger::ELOGS);
}

done_testing;
