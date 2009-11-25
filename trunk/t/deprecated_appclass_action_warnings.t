use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Catalyst::Test 'DeprecatedActionsInAppClassTestApp';

plan tests => 3;

my $warnings;
my $logger = DeprecatedActionsInAppClassTestApp::Log->new;
Catalyst->log($logger);

ok( my $response = request('http://localhost/foo'), 'Request' );
ok( $response->is_success, 'Response Successful 2xx' );
is( $DeprecatedActionsInAppClassTestApp::Log::warnings, 1, 'Get the appclass action warning' );