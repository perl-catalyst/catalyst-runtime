#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 12;
use Time::HiRes qw/gettimeofday/;
use Tree::Simple;

my @fudge_t = ( 0, 0 );
BEGIN {
    no warnings;
    *Time::HiRes::gettimeofday = sub () { return @fudge_t };
}

BEGIN { use_ok("Catalyst::Stats") };

{
    my $stats = Catalyst::Stats->new;
    is (ref($stats), "Catalyst::Stats", "new");

    my @expected; # level, string, time

    $fudge_t[0] = 1;
    ok($stats->profile("single comment arg"), "profile");
    push(@expected, [ 0, "- single comment arg", 1, 0 ]);

    $fudge_t[0] = 3;
    $stats->profile(comment => "hash comment arg");
    push(@expected, [ 0, "- hash comment arg", 2, 0 ]);

    $fudge_t[0] = 10;
    $stats->profile(begin => "block", comment => "start block");
    push(@expected, [ 0, "block - start block", 4, 1 ]);


    $fudge_t[0] = 11;
    $stats->profile("inside block");
    push(@expected, [ 1, "- inside block", 1, 0 ]);

    $fudge_t[1] = 100000;
    my $uid = $stats->profile(begin => "nested block", uid => "boo");
    push(@expected, [ 1, "nested block", 0.7, 1 ]);
    is ($uid, "boo", "set UID");

    $stats->enable(0);
    $fudge_t[1] = 150000;
    $stats->profile("this shouldn't appear");
    $stats->enable(1);

    $fudge_t[1] = 200000;
    $stats->profile(begin => "double nested block 1");
    push(@expected, [ 2, "double nested block 1", 0.2, 1 ]);

    $stats->profile(comment => "attach to uid", parent => $uid);

    $fudge_t[1] = 250000;
    $stats->profile(begin => "badly nested block 1");
    push(@expected, [ 3, "badly nested block 1", 0.35, 1 ]);

    $fudge_t[1] = 300000;
    $stats->profile(comment => "interleave 1");
    push(@expected, [ 4, "- interleave 1", 0.05, 0 ]);

    $fudge_t[1] = 400000; # end double nested block time
    $stats->profile(end => "double nested block 1");

    $fudge_t[1] = 500000;
    $stats->profile(comment => "interleave 2");
    push(@expected, [ 4, "- interleave 2", 0.2, 0 ]);

    $fudge_t[1] = 600000; # end badly nested block time
    $stats->profile(end => "badly nested block 1");

    $fudge_t[1] = 800000; # end nested block time
    $stats->profile(end => "nested block");

    $fudge_t[0] = 14; # end block time
    $fudge_t[1] = 0;
    $stats->profile(end => "block", comment => "end block");

    push(@expected, [ 2, "- attach to uid", 0.1, 0 ]);


    my @report = $stats->report;
    is_deeply(\@report, \@expected, "report");

    is ($stats->elapsed, 14, "elapsed");
}

# COMPATABILITY METHODS

# accept
{
    my $stats = Catalyst::Stats->new;
    my $root = $stats->{tree};
    my $uid = $root->getUID;

    my $visitor = Tree::Simple::Visitor::FindByUID->new;
    $visitor->includeTrunk(1); # needed for this test
    $visitor->searchForUID($uid);
    $stats->accept($visitor);
    is( $visitor->getResult, $root, '[COMPAT] accept()' );

}

# addChild
{
    my $stats = Catalyst::Stats->new;
    my $node = Tree::Simple->new(
        {
            action  => 'test',
            elapsed => '10s',
            comment => "",
        }
    );

    $stats->addChild( $node );

    my $actual = $stats->{ tree }->{ _children }->[ 0 ];
    is( $actual, $node, '[COMPAT] addChild()' );
    is( $actual->getNodeValue->{ elapsed }, 10, '[COMPAT] addChild(), data munged' );
}

# setNodeValue
{
    my $stats = Catalyst::Stats->new;
    my $stat = {
        action  => 'test',
        elapsed => '10s',
        comment => "",
    };

    $stats->setNodeValue( $stat );

    is_deeply( $stats->{tree}->getNodeValue, { action => 'test', elapsed => 10, comment => '' }   , '[COMPAT] setNodeValue(), data munged' );
}

# getNodeValue
{
    my $stats = Catalyst::Stats->new;
    my $expected = $stats->{tree}->getNodeValue->{t};
    is_deeply( $stats->getNodeValue, $expected, '[COMPAT] getNodeValue()' );
}

# traverse
{
    my $stats = Catalyst::Stats->new;
    $stats->{tree}->addChild( Tree::Simple->new( { foo => 'bar' } ) );
    my @value;
    $stats->traverse( sub { push @value, shift->getNodeValue->{ foo }; } );

    is_deeply( \@value, [ 'bar' ], '[COMPAT] traverse()' );
}

