#!perl

use strict;
use warnings;
use lib 't/lib';

use Test::More;

plan tests => 16;

use Catalyst::Test 'TestApp';

for my $fail (
    "(' ')",
    "('')",
    "('1.23')",
) {

    eval <<"END";
        package TestApp::Controller::Action::Chained;
        no warnings 'redefine';
        sub should_fail : Chained('/') Args$fail {}
END
    ok(!$@);

    eval { TestApp->setup_actions };
    like($@, qr/Invalid Args\Q$fail\E/,
        "Bad Args$fail attribute makes action setup fail");
}

for my $ok (
    "()",
    "(0)",
    "(1)",
    "('0')",
    "",
) {
    eval <<"END";
        package TestApp::Controller::Action::Chained;
        no warnings 'redefine';
        sub should_fail : Chained('/') Args$ok {}
END
    ok(!$@);
    eval { TestApp->setup_actions };
    ok(!$@, "Args$ok works");
}
