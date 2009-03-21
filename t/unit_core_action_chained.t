#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 3;


use TestApp;

my $dispatch_type = TestApp->dispatcher->dispatch_type('Chained');
isa_ok($dispatch_type, "Catalyst::DispatchType::Chained", "got dispatch type");

# This test was failing due to recursion/OOM. set up an alarm so things dont
# runaway
local $SIG{ALRM} = sub { 
    ok(0, "Chained->list didn't loop");
    die "alarm expired - test probably looping";
};
alarm 10;

$dispatch_type->list("TestApp");
ok(1, "Chained->list didn't loop");
