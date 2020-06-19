use strict;
use warnings;
use Test::More;

# setup library path
use FindBin qw($Bin);
use lib "$Bin/lib";

use Catalyst::Test qw(TestAppUnicode);

{
    my $res = request('/');
    ok($res->is_success, 'get main page');
    like($res->decoded_content, qr/it works/i, 'see if it has our text');
    is ($res->header('Content-Type'), 'text/html; charset=UTF-8',
        'Content-Type with charset'
    );
}

{
    my $res = request('/unicode_no_enc');
    ok($res->is_success, 'get unicode_no_enc');

    my $exp = "\xE3\x81\xBB\xE3\x81\x92";
    my $got = Encode::encode_utf8($res->decoded_content);

    is ($res->header('Content-Type'), 'text/plain',
        'Content-Type with no charset');

    is($got, $exp, 'content contains hoge');
}

{
    my $res = request('/unicode');
    ok( $res->is_success, 'get unicode');

    is ($res->header('Content-Type'), 'text/plain; charset=UTF-8',
        'Content-Type with charset');

    my $exp = "\xE3\x81\xBB\xE3\x81\x92";
    my $got = Encode::encode_utf8($res->decoded_content);

    is($got, $exp, 'content contains hoge');
}

{
    my $res = request('/not_unicode');
    ok($res->is_success, 'get bytes');
    my $exp = "\xE1\x88\xB4\xE5\x99\xB8";
    my $got = Encode::encode_utf8($res->decoded_content);

    is($got, $exp, 'got 1234 5678');
}

{
    my $res = request('/file');
    ok($res->is_success, 'get file');
    like($res->decoded_content, qr/this is a test/, 'got filehandle contents');
}

{
    # The latin 1 case is the one everyone forgets. I want to really make sure
    # its right, so lets check the damn bytes.
    my $res = request('/latin1');
    ok($res->is_success, 'get latin1');
    is ($res->header('Content-Type'), 'text/plain; charset=UTF-8',
        'Content-Type with charset');


    my $exp = "LATIN SMALL LETTER E WITH ACUTE: \xC3\xA9";
    my $got = Encode::encode_utf8($res->decoded_content);

    is ($got, $exp, 'content octets are UTF-8');
}

{
    my $res = request('/shift_jis');
    ok($res->is_success, 'get shift_jis');
    is ($res->header('Content-Type'), 'text/plain; charset=Shift_JIS', 'Content-Type with charset');
    my $exp = "\xE3\x81\xBB\xE3\x81\x92";
    my $got = Encode::encode_utf8($res->decoded_content);
    is ($got, $exp, 'content octets are Shift_JIS');
}

done_testing;

