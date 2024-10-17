use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

our $EXPECTED_ENV_VAR;
our $EXPECTED_ENV_VAL;

BEGIN {
    $EXPECTED_ENV_VAR = "CATALYSTTEST$$"; # has to be uppercase otherwise fails on Win32
    $EXPECTED_ENV_VAL = "Test env value " . rand(100000);
}

use Test::More;
use Catalyst::Test 'TestApp';

use Catalyst::Request;
use HTTP::Headers;
use HTTP::Request::Common;

my $response = request("http://localhost/dump/env", {
    extra_env => { $EXPECTED_ENV_VAR => $EXPECTED_ENV_VAL },
});

ok( $response, 'Request' );
ok( $response->is_success, 'Response Successful 2xx' );
is( $response->content_type, 'text/plain', 'Response Content-Type' );

my $env;
ok( eval '$env = ' . $response->content, 'Unserialize Catalyst::Request' );
is ref($env), 'HASH';
ok exists($env->{PATH_INFO}), 'Have a PATH_INFO env var for dump/env';

SKIP:
{
    if ( $ENV{CATALYST_SERVER} ) {
        skip 'Using remote server', 1;
    }
    is $env->{$EXPECTED_ENV_VAR}, $EXPECTED_ENV_VAL,
        'Value we set as expected for /dump/env'
}

done_testing;

