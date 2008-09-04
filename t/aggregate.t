#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Aggregate;

my $tests = Test::Aggregate->new({
    dirs          => 't/aggregate',
    verbose       => 1,
    set_filenames => 1,
});

$tests->run;
