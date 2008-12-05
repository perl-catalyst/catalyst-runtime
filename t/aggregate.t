#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Aggregate;

my $tests = Test::Aggregate->new({
    dirs          => 't/aggregate',
    verbose       => 0,
    set_filenames => 1,
    findbin       => 1,
});

$tests->run;
