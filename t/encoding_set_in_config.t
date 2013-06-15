use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;

BEGIN { eval { require Catalyst::Plugin::ConfigLoader; 1; } ||
    plan skip_all => 'Need Catalyst::Plugin::ConfigLoader' }

#for this test encoding => 'UTF-8' is set in testappencodingsetinconfig.json
use Catalyst::Test 'TestAppEncodingSetInConfig';

my ( undef, $c ) = ctx_request('/');
isa_ok( $c->encoding,  'Encode::utf8', '$c->encoding' );

done_testing;
