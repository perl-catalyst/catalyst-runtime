#!perl

use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 6;

use Catalyst::Test 'TestApp';

eval q{
    package TestApp::Controller::Action::Chained;
    sub should_fail : Chained('should_fail') Args(0) {}
};
ok(!$@);

eval { TestApp->setup_actions; };
like($@, qr|Actions cannot chain to themselves registering /action/chained/should_fail|,
    'Local self referencing attributes makes action setup fail');

eval q{
    package TestApp::Controller::Action::Chained;
    no warnings 'redefine';
    sub should_fail {}
    use warnings 'redefine';
    sub should_also_fail : Chained('/action/chained/should_also_fail') Args(0) {}
};
ok(!$@);

eval { TestApp->setup_actions };
like($@, qr|Actions cannot chain to themselves registering /action/chained/should_also_fail|,
    'Full path self referencing attributes makes action setup fail');

eval q{
    package TestApp::Controller::Action::Chained;
    no warnings 'redefine';
    sub should_also_fail {}
};
ok(!$@);

eval { TestApp->setup_actions };
ok(!$@, 'And ok again') or warn $@;

