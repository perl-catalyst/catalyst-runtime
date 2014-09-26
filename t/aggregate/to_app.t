use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use TestApp;
use Test::More;

ok(TestApp->can('to_app'));
is(ref(TestApp->to_app), 'CODE');

done_testing;
