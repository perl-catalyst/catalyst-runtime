#!perl

use strict;
use warnings;
use lib 't/lib';

use Test::More;

plan tests => 4;

use Catalyst::Test 'TestApp';

eval q{
    package TestApp::Controller::Action::Chained;
    sub should_fail : Chained('/') Chained('foo') Args(0) {}
};
ok(!$@);

eval { TestApp->setup_actions; };
ok($@, 'Multiple chained attributes make action setup fail');

eval q{
    package TestApp::Controller::Action::Chained;
    no warnings 'redefine';
    sub should_fail {}
};
ok(!$@);

eval { TestApp->setup_actions };
ok(!$@, 'And ok again') or warn $@;

