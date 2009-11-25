use strict;
use warnings;
use Test::More tests => 6;

use_ok('Catalyst::Response');

my $res = Catalyst::Response->new;

# test aliasing of res->code for res->status
$res->code(500);
is($res->code, 500, 'code sets itself');
is($res->status, 500, 'code sets status');
$res->status(501);
is($res->code, 501, 'status sets code');
is($res->body, '', "default response body ''");
$res->body(undef);
is($res->body, '', "response body '' after assigned undef");

