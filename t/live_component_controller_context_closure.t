use strict;
use warnings;
use Test::More;

BEGIN {
    unless (eval 'use CatalystX::LeakChecker 0.05; 1') {
        plan skip_all => 'CatalystX::LeakChecker 0.05 required for this test';
    }

    plan tests => 6;
}

use FindBin;
use lib "$FindBin::Bin/lib";

BEGIN { $::setup_leakchecker = 1 }
local $SIG{__WARN__} = sub { return if $_[0] =~ /Unhandled type: GLOB/; warn $_[0] };
use Catalyst::Test 'TestApp';

{
    my ($resp, $ctx) = ctx_request('/contextclosure/normal_closure');
    ok($resp->is_success);
    #is($ctx->count_leaks, 1);
    # FIXME: find out why this changed from 1 to 2 after 52af51596d
    # ^^ probably has something to do with env being in Engine and Request - JNAP
    # ^^ I made the env in Engine a weak ref, should help until we can remove it
    is($ctx->count_leaks, 1);
}

{
    my ($resp, $ctx) = ctx_request('/contextclosure/context_closure');
    ok($resp->is_success);
    is($ctx->count_leaks, 0);
}

{
    my ($resp, $ctx) = ctx_request('/contextclosure/non_closure');
    ok($resp->is_success);
    is($ctx->count_leaks, 0);
}
