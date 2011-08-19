#!/usr/bin/evn perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More tests => 6;
use Catalyst::Test 'TestApp';

# test that un-escaped can be feteched.
{

    ok( my $response = request('http://localhost/args/params/one/two') );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content, 'onetwo' );
}

# test that request with URL-escaped code works.
{
    ok( my $response = request('http://localhost/args/param%73/one/two') );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->content, 'onetwo' );
}

