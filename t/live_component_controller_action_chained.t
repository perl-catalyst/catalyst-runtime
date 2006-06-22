#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

our $iters;

BEGIN { $iters = $ENV{CAT_BENCH_ITERS} || 2; }

use Test::More tests => 96*$iters;
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->foo
          TestApp::Controller::Action::Chained->endpoint
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/foo/1/end/2'), 'chained + local endpoint' );
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

        ok( my $response = request('http://localhost/chained/foo/1/end'), 
            'chained + local endpoint; missing last argument' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->header('Status'), 500, 'Status OK' );
    }

    #
    #   Tests the case when the child action is placed in a subcontroller.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->foo
          TestApp::Controller::Action::Chained::Foo->spoon
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/foo/1/spoon'), 'chained + subcontroller endpoint' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; ', 'Content OK' );
    }

    #
    #   Tests if the relative specification (e.g.: Chained('bar') ) works
    #   as expected.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->bar
          TestApp::Controller::Action::Chained->finale
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/bar/1/spoon'), 'chained + relative endpoint' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '; 1, spoon', 'Content OK' );
    }

    #
    #   Just a test for multiple arguments.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->foo2
          TestApp::Controller::Action::Chained->endpoint2
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/foo2/10/20/end2/15/25'), 
            'chained + local (2 args each)' );
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->one_end
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/one/23'),
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->one
          TestApp::Controller::Action::Chained->two_end
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/one/23/two/23/46'),
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->one
          TestApp::Controller::Action::Chained->two
          TestApp::Controller::Action::Chained->three_end
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/one/23/two/23/46/three/1/2/3'),
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->multi1
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/multi/23'),
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->multi2
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/multi/23/46'),
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

        ok( my $response = request('http://localhost/chained/multi/23/46/67'),
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained::Foo->higher_root
          TestApp::Controller::Action::Chained->higher_root
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/higher_root/23/bar/11'),
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->pcp1
          TestApp::Controller::Action::Chained::Foo->pcp2
          TestApp::Controller::Action::Chained->pcp3
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/pcp1/1/pcp2/2/pcp3/3'),
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->multi_cap1
          TestApp::Controller::Action::Chained->multi_cap_end1
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/multi_cap/1/baz'),
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->multi_cap2
          TestApp::Controller::Action::Chained->multi_cap_end2
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/multi_cap/1/2/baz'),
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->priority_a2
          TestApp::Controller::Action::Chained->priority_a2_end
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/priority_a/1/end/2'),
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->priority_b2
          TestApp::Controller::Action::Chained->priority_b2_end
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/priority_b/1/end/2'),
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained::Bar->cross1
          TestApp::Controller::Action::Chained::Foo->cross2
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/cross/1/end/2'),
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained::PassedArgs->first
          TestApp::Controller::Action::Chained::PassedArgs->second
          TestApp::Controller::Action::Chained::PassedArgs->third
          TestApp::Controller::Action::Chained::PassedArgs->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/passedargs/a/1/b/2/c/3'),
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->opt_args
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/opt_args/1/2/3'),
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->opt_pp_start
          TestApp::Controller::Action::Chained->opt_pathpart
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/optpp/1/opt_pathpart/2'),
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
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->opt_all_start
          TestApp::Controller::Action::Chained->oa
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/optall/1/oa/2/3'),
            'Optional :PathName *and* :Args attributes working' );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2, 3', 'Content OK' );
    }

    #
    #   Test if :Chained is the same as :Chained('/')
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->rootdef
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/rootdef/23'),
            ":Chained is the same as :Chained('/')" );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '; 23', 'Content OK' );
    }

    #
    #   Test if :Chained('.') is working
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->parentchain
          TestApp::Controller::Action::Chained::ParentChain->child
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/parentchain/1/child/2'),
            ":Chained('.') chains to parent controller action" );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2', 'Content OK' );
    }

    #
    #   Test behaviour of auto actions returning '1' for the chain.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained::Auto->auto
          TestApp::Controller::Action::Chained::Auto::Foo->auto
          TestApp::Controller::Action::Chained::Auto->foo
          TestApp::Controller::Action::Chained::Auto::Foo->fooend
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/autochain1/1/fooend/2'),
            "Behaviour when auto returns 1 correct" );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2', 'Content OK' );
    }

    #
    #   Test behaviour of auto actions returning '0' for the chain.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained::Auto->auto
          TestApp::Controller::Action::Chained::Auto::Bar->auto
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/autochain2/1/barend/2'),
            "Behaviour when auto returns 0 correct" );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2', 'Content OK' );
    }

    #
    #   Test what auto actions are run when namespaces are changed
    #   horizontally.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained::Auto->auto
          TestApp::Controller::Action::Chained::Auto::Foo->auto
          TestApp::Controller::Action::Chained::Auto::Bar->crossloose
          TestApp::Controller::Action::Chained::Auto::Foo->crossend
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/auto_cross/1/crossend/2'),
            "Correct auto actions are run on cross controller dispatch" );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2', 'Content OK' );
    }

    #
    #   Test forwarding from auto action in chain dispatch.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained::Auto->auto
          TestApp::Controller::Action::Chained::Auto::Forward->auto
          TestApp::Controller::Action::Chained::Auto->fw3
          TestApp::Controller::Action::Chained::Auto->fw1
          TestApp::Controller::Action::Chained::Auto::Forward->forwardend
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/auto_forward/1/forwardend/2'),
            "Forwarding out of auto in chain" );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2', 'Content OK' );
    }

    #
    #   Detaching out of the auto action of a chain.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained::Auto->auto
          TestApp::Controller::Action::Chained::Auto::Detach->auto
          TestApp::Controller::Action::Chained::Auto->fw3
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/auto_detach/1/detachend/2'),
            "Detaching out of auto in chain" );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2', 'Content OK' );
    }

    #
    #   Test forwarding from auto action in chain dispatch.
    #
    {
        my $expected = undef;

        ok( my $response = request('http://localhost/chained/loose/23'),
            "Loose end is not callable" );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->header('Status'), 500, 'Status OK' );
    }

    #
    #   Test forwarding out of a chain.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->chain_fw_a
          TestApp::Controller::Action::Chained->fw_dt_target
          TestApp::Controller::Action::Chained->chain_fw_b
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/chain_fw/1/end/2'),
            "Forwarding out a chain" );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2', 'Content OK' );
    }

    #
    #   Test detaching out of a chain.
    #
    {
        my @expected = qw[
          TestApp::Controller::Action::Chained->begin
          TestApp::Controller::Action::Chained->chain_dt_a
          TestApp::Controller::Action::Chained->fw_dt_target
          TestApp::Controller::Action::Chained->end
        ];

        my $expected = join( ", ", @expected );

        ok( my $response = request('http://localhost/chained/chain_dt/1/end/2'),
            "Forwarding out a chain" );
        is( $response->header('X-Catalyst-Executed'),
            $expected, 'Executed actions' );
        is( $response->content, '1; 2', 'Content OK' );
    }
}
