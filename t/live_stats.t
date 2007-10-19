#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 5;
use Catalyst::Test 'TestAppStats';

{
    ok( my $response = request('http://localhost/'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
}
{
    ok( my $response = request('http://localhost/'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    ok( $response->content =~ m/\/default.*?[\d.]+s.*- test.*[\d.]+s/s, 'Stats report');

}

