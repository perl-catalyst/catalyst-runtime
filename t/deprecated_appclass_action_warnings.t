use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;

eval 'use DeprecatedActionsInAppClassTestApp';
ok( $@, 'application dies if it has actions');
like( $@, qr/cannot be controllers anymore/, 'for the correct reason' );

done_testing;
