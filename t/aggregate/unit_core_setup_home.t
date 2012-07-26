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

{
    my $home_flag;
    delete $ENV{CATALYST_HOME} if exists $ENV{CATALYST_HOME};

    my $c = Catalyst::IOC::Container->new(name => 'TestAppSetupHome');
    ok(my $home = $c->resolve(service => 'home', parameters => { home_flag => $home_flag }), 'home service returns ok');
    is($home, $homes_and_roots[0][0], 'value is expected');
    ok(my $root = $c->resolve(service => 'root_dir'), 'root service returns ok');
    is($root, $homes_and_roots[0][1], 'value is expected');
}

{
    my $home_flag;
    $ENV{CATALYST_HOME} = $homes_and_roots[1][0];

    my $c = Catalyst::IOC::Container->new(name => 'TestAppSetupHome');
    ok(my $home = $c->resolve(service => 'home', parameters => { home_flag => $home_flag }), 'home service returns ok');
    is($home, $homes_and_roots[1][0], 'value is expected');
    ok(my $root = $c->resolve(service => 'root_dir'), 'root service returns ok');
    is($root, $homes_and_roots[1][1], 'value is expected');
}

{
    my $home_flag = $homes_and_roots[2][0];
    delete $ENV{CATALYST_HOME} if exists $ENV{CATALYST_HOME};

    my $c = Catalyst::IOC::Container->new(name => 'TestAppSetupHome');
    ok(my $home = $c->resolve(service => 'home', parameters => { home_flag => $home_flag }), 'home service returns ok');
    is($home, $homes_and_roots[2][0], 'value is expected');
    ok(my $root = $c->resolve(service => 'root_dir'), 'root service returns ok');
    is($root, $homes_and_roots[2][1], 'value is expected');
}

{
    my $home_flag       = $homes_and_roots[2][0];
    $ENV{CATALYST_HOME} = $homes_and_roots[1][0];

    my $c = Catalyst::IOC::Container->new(name => 'TestAppSetupHome');
    ok(my $home = $c->resolve(service => 'home', parameters => { home_flag => $home_flag }), 'home service returns ok');
    is($home, $homes_and_roots[2][0], 'value is expected');
    ok(my $root = $c->resolve(service => 'root_dir'), 'root service returns ok');
    is($root, $homes_and_roots[2][1], 'value is expected');
}

for my $home_and_root (@homes_and_roots) {
    for (@$home_and_root) {
        rmdir $_;
    }
}

done_testing;
