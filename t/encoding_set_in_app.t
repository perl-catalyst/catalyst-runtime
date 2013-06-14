use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;

#for this test encoding => 'UTF-8' is set in TestAppEncodingSetInApp.pm
use Catalyst::Test 'TestAppEncodingSetInApp';

my ( undef, $c ) = ctx_request('/');
isa_ok( $c->encoding,  'Encode::utf8', '$c->encoding' );

done_testing;
