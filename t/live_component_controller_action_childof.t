#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

our $iters;

BEGIN { $iters = $ENV{CAT_BENCH_ITERS} || 2; }

use Test::More tests => 66*$iters;
use Catalyst::Test 'TestApp';

if ( $ENV{CAT_BENCHMARK} ) {
    require Benchmark;
    Benchmark::timethis( $iters, \&run_tests );
}
else {
    for ( 1 .. $iters ) {
        run_tests();
    }
}

sub run_tests {

    #
    #   This is a simple test where the parent and child actions are
    #   within the same controller.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->foo
          TestApp::Controller::Action::ChildOf->endpoint
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/foo/1/end/2'), 'childof + local endpoint' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2', 'Content OK' );
    }

    #
    #   This makes sure the above isn't found if the argument for the
    #   end action isn't supplied.
    #
    {
        my $expected = undef;

        ok( my $response = request('http://localhost/childof/foo/1/end'), 
            'childof + local endpoint; missing last argument' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->header('Status'), 500, 'Status OK' );
    }

    #
    #   Tests the case when the child action is placed in a subcontroller.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->foo
          TestApp::Controller::Action::ChildOf::Foo->spoon
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/foo/1/spoon'), 'childof + subcontroller endpoint' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; ', 'Content OK' );
    }

    #
    #   Tests if the relative specification (e.g.: ChildOf('bar') ) works
    #   as expected.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->bar
          TestApp::Controller::Action::ChildOf->finale
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/bar/1/spoon'), 'childof + relative endpoint' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '; 1, spoon', 'Content OK' );
    }

    #
    #   Just a test for multiple arguments.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->foo2
          TestApp::Controller::Action::ChildOf->endpoint2
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/foo2/10/20/end2/15/25'), 
            'childof + local (2 args each)' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '10, 20; 15, 25', 'Content OK' );
    }

    #
    #   The first three-chain test tries to call the action with :Args(1)
    #   specification. There's also a one action with a :Captures(1)
    #   attribute, that should not be dispatched to.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->one_end
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/one/23'),
            'three-chain (only first)' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '; 23', 'Content OK' );
    }

    #
    #   This is the second three-chain test, it goes for the action that
    #   handles "/one/$cap/two/$arg1/$arg2" paths. Should be the two action
    #   having :Args(2), not the one having :Captures(2).
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->one
          TestApp::Controller::Action::ChildOf->two_end
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/one/23/two/23/46'),
            'three-chain (up to second)' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '23; 23, 46', 'Content OK' );
    }

    #
    #   Last of the three-chain tests. Has no concurrent action with :Captures
    #   and is more thought to simply test the chain as a whole and the 'two'
    #   action specifying :Captures.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->one
          TestApp::Controller::Action::ChildOf->two
          TestApp::Controller::Action::ChildOf->three_end
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/one/23/two/23/46/three/1/2/3'),
            'three-chain (all three)' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '23, 23, 46; 1, 2, 3', 'Content OK' );
    }

    #
    #   Tests dispatching on number of arguments for :Args. This should be
    #   dispatched to the action expecting one argument.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->multi1
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/multi/23'),
            'multi-action (one arg)' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '; 23', 'Content OK' );
    }

    #
    #   Belongs to the former test and goes for the action expecting two arguments.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->multi2
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/multi/23/46'),
            'multi-action (two args)' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '; 23, 46', 'Content OK' );
    }

    #
    #   Dispatching on argument count again, this time we provide too many
    #   arguments, so dispatching should fail.
    #
    {
        my $expected = undef;

        ok( my $response = request('http://localhost/childof/multi/23/46/67'),
            'multi-action (three args, should lead to error)' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->header('Status'), 500, 'Status OK' );
    }

    #
    #   This tests the case when an action says it's the child of an action in
    #   a subcontroller.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf::Foo->higher_root
          TestApp::Controller::Action::ChildOf->higher_root
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/higher_root/23/bar/11'),
            'root higher than child' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '23; 11', 'Content OK' );
    }

    #
    #   Just a more complex version of the former test. It tests if a controller ->
    #   subcontroller -> controller dispatch works.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->pcp1
          TestApp::Controller::Action::ChildOf::Foo->pcp2
          TestApp::Controller::Action::ChildOf->pcp3
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/pcp1/1/pcp2/2/pcp3/3'),
            'parent -> child -> parent' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1, 2; 3', 'Content OK' );
    }

    #
    #   Tests dispatch on capture number. This test is for a one capture action.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->multi_cap1
          TestApp::Controller::Action::ChildOf->multi_cap_end1
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/multi_cap/1/baz'),
            'dispatch on capture num 1' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; ', 'Content OK' );
    }

    #
    #   Belongs to the former test. This one goes for the action expecting two
    #   captures.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->multi_cap2
          TestApp::Controller::Action::ChildOf->multi_cap_end2
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/multi_cap/1/2/baz'),
            'dispatch on capture num 2' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1, 2; ', 'Content OK' );
    }

    #
    #   Tests the priority of a slurpy arguments action (with :Args) against
    #   two actions chained together. The two actions should win.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->priority_a2
          TestApp::Controller::Action::ChildOf->priority_a2_end
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/priority_a/1/end/2'),
            'priority - slurpy args vs. parent/child' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2', 'Content OK' );
    }

    #
    #   This belongs to the former test but tests if two chained actions have
    #   priority over an action with the exact arguments.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->priority_b2
          TestApp::Controller::Action::ChildOf->priority_b2_end
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/priority_b/1/end/2'),
            'priority - fixed args vs. parent/child' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2', 'Content OK' );
    }

    #
    #   Test dispatching between two controllers that are on the same level and
    #   therefor have no parent/child relationship.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf::Bar->cross1
          TestApp::Controller::Action::ChildOf::Foo->cross2
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/cross/1/end/2'),
            'cross controller w/o par/child relation' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2', 'Content OK' );
    }

    #
    #   This is for testing if the arguments got passed to the actions 
    #   correctly.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf::PassedArgs->first
          TestApp::Controller::Action::ChildOf::PassedArgs->second
          TestApp::Controller::Action::ChildOf::PassedArgs->third
          TestApp::Controller::Action::ChildOf::PassedArgs->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/passedargs/a/1/b/2/c/3'),
            'Correct arguments passed to actions' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2; 3', 'Content OK' );
    }

    #
    #   The :Args attribute is optional, we check the action not specifying
    #   it with these tests.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->opt_args
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/opt_args/1/2/3'),
            'Optional :Args attribute working' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '; 1, 2, 3', 'Content OK' );
    }

    #
    #   Tests for optional PathPart attribute.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->opt_pp_start
          TestApp::Controller::Action::ChildOf->opt_pathpart
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/optpp/1/opt_pathpart/2'),
            'Optional :PathName attribute working' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2', 'Content OK' );
    }

    #
    #   Tests for optional PathPart *and* Args attributes.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::ChildOf->begin
          TestApp::Controller::Action::ChildOf->opt_all_start
          TestApp::Controller::Action::ChildOf->oa
          TestApp::Controller::Action::ChildOf->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/childof/optall/1/oa/2/3'),
            'Optional :PathName *and* :Args attributes working' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2, 3', 'Content OK' );
    }
}
