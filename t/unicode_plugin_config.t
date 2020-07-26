use strict;
use warnings;
use Test::More;

BEGIN { $ENV{TESTAPP_ENCODING} = 'UTF-8' };

# setup library path
use FindBin qw($Bin);
use lib "$Bin/lib";

use Catalyst::Test 'TestAppUnicode';

{
    TestAppUnicode->encoding('UTF-8');
    action_ok('/unicode', 'encoding configured ok');
}

done_testing;

