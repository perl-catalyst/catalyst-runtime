use strict;
use warnings;
use Test::More;
use IO::Scalar;

# setup library path
use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
if ( !eval { require Test::WWW::Mechanize::Catalyst } || ! Test::WWW::Mechanize::Catalyst->VERSION('0.51') ) {
    plan skip_all => 'Need Test::WWW::Mechanize::Catalyst for this test';
}
}

# make sure testapp works
use_ok('TestAppUnicode') or BAIL_OUT($@);

our $TEST_FILE = IO::Scalar->new(\"this is a test");
sub IO::Scalar::FILENO { -1 }; # needed?

# a live test against TestAppUnicode, the test application
use Test::WWW::Mechanize::Catalyst 'TestAppUnicode';
my $mech = Test::WWW::Mechanize::Catalyst->new;
$mech->get_ok('http://localhost/', 'get main page');
$mech->content_like(qr/it works/i, 'see if it has our text');
is ($mech->response->header('Content-Type'), 'text/html; charset=UTF-8',
    'Content-Type with charset'
);

{
    $mech->get_ok('http://localhost/unicode_no_enc', 'get unicode_no_enc');

    my $exp = "\xE3\x81\xBB\xE3\x81\x92";
    my $got = Encode::encode_utf8($mech->content);

    is ($mech->response->header('Content-Type'), 'text/plain',
        'Content-Type with no charset');

    is($got, $exp, 'content contains hoge');
}

{
    $mech->get_ok('http://localhost/unicode', 'get unicode');

    is ($mech->response->header('Content-Type'), 'text/plain; charset=UTF-8',
        'Content-Type with charset');

    my $exp = "\xE3\x81\xBB\xE3\x81\x92";
    my $got = Encode::encode_utf8($mech->content);

    is($got, $exp, 'content contains hoge');
}

{
    $mech->get_ok('http://localhost/not_unicode', 'get bytes');
    my $exp = "\xE1\x88\xB4\xE5\x99\xB8";
    my $got = Encode::encode_utf8($mech->content);

    is($got, $exp, 'got 1234 5678');
}

{
    $mech->get_ok('http://localhost/file', 'get file');
    $mech->content_like(qr/this is a test/, 'got filehandle contents');
}

{
    # The latin 1 case is the one everyone forgets. I want to really make sure
    # its right, so lets check the damn bytes.
    $mech->get_ok('http://localhost/latin1', 'get latin1');
    is ($mech->response->header('Content-Type'), 'text/plain; charset=UTF-8',
        'Content-Type with charset');


    my $exp = "LATIN SMALL LETTER E WITH ACUTE: \xC3\xA9";
    my $got = Encode::encode_utf8($mech->content);

    is ($got, $exp, 'content octets are UTF-8');
}

{
    $mech->get_ok('http://localhost/shift_jis', 'get shift_jis');
    is ($mech->response->header('Content-Type'), 'text/plain; charset=Shift_JIS', 'Content-Type with charset');
    my $exp = "\xE3\x81\xBB\xE3\x81\x92";
    my $got = Encode::encode_utf8($mech->content);
    is ($got, $exp, 'content octets are Shift_JIS');
}

done_testing;

