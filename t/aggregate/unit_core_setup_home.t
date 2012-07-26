#!/usr/bin/env perl
use warnings;
use strict;
use Test::More;
use Catalyst::IOC::Container;
use FindBin '$Bin';
use lib "$Bin/../lib";
use TestAppSetupHome;
use vars '%ENV';

my $lib = "$Bin/../lib";
my @homes_and_roots = (
    [
        "$lib/TestAppSetupHome",
        "$lib/TestAppSetupHome/root",
    ],
    [
        "$lib/TestAppSetupHomeENV",
        "$lib/TestAppSetupHomeENV/root",
    ],
    [
        "$lib/TestAppSetupHomeFLAG",
        "$lib/TestAppSetupHomeFLAG/root",
    ],
);

for my $home_and_root (@homes_and_roots) {
    for (@$home_and_root) {
        mkdir $_;
    }
}

test_it(0, 0, 0);
test_it(0, 1, 1);
test_it(1, 0, 2);
test_it(1, 1, 1);


sub test_it {
    my ($set_flag, $set_env, $expected_result) = @_;

    my @home_flag;
    delete $ENV{CATALYST_HOME} if exists $ENV{CATALYST_HOME};

    if ($set_flag) {
        @home_flag = ("-Home=$homes_and_roots[2][0]");
    }
    if ($set_env) {
        $ENV{CATALYST_HOME} = $homes_and_roots[1][0];
    }

    my $c = Catalyst::IOC::Container->new(name => 'TestAppSetupHome', flags => \@home_flag);
    ok(my $home = $c->resolve(service => 'home'), 'home service returns ok');
    is($home, $homes_and_roots[$expected_result][0], 'home value is expected');
    ok(my $root = $c->resolve(service => 'root_dir'), 'root_dir service returns ok');
    is($root, $homes_and_roots[$expected_result][1], 'root value is expected');
}

for my $home_and_root (@homes_and_roots) {
    for (@$home_and_root) {
        rmdir $_;
    }
}

done_testing;
