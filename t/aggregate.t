#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use File::Spec::Functions 'catfile', 'updir';

BEGIN {
    unless (-e catfile $FindBin::Bin, updir, '.aggregating') {
        require Test::More;
        Test::More::plan(skip_all => 'No test aggregation requested');
    }
}

BEGIN {
    unless (eval { require Test::Aggregate; Test::Aggregate->VERSION('0.364'); 1 }) {
        require Test::More;
        Test::More::plan(skip_all => 'Test::Aggregate 0.364 required for test aggregation');
    }
}

my $tests = Test::Aggregate->new({
    (@ARGV ? (tests => \@ARGV) : (dirs => 't/aggregate')),
    verbose       => 0,
    set_filenames => 1,
    findbin       => 1,
});

$tests->run;
