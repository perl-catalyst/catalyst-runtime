use strict;
use warnings;
use lib 't/lib';

use Test::More;

# This test needs to be rewritten (and the code it was using as well) since
# when we added the arg and capturearg type constraint support, we now allow
# non integer values.  however we could probably support some additional sanity
# testing on the values, so this is a nice TODO for someone -jnap

plan skip_all => 'Removing this test because constraint arg types allow this';

use Catalyst::Test 'TestApp';

for my $fail (
    "(' ')",
    "('')",
    "('1.23')",
    "(-1)",
) {
    for my $type (qw(Args CaptureArgs)) {
        eval <<"END";
            package TestApp::Controller::Action::Chained;
            no warnings 'redefine';
            sub should_fail : Chained('/') ${type}${fail} {}
END
        ok(!$@);

        eval { TestApp->setup_actions };
        like($@, qr/Invalid \Q${type}${fail}\E/,
             "Bad ${type}${fail} attribute makes action setup fail");
    }
}

for my $ok (
    "()",
    "(0)",
    "(1)",
    "('0')",
    "",
) {
    for my $type (qw(Args CaptureArgs)) {
        eval <<"END";
            package TestApp::Controller::Action::Chained;
            no warnings 'redefine';
            sub should_fail : Chained('/') ${type}${ok} {}
END
        ok(!$@);
        eval { TestApp->setup_actions };
        ok(!$@, "${type}${ok} works");
    }
}

for my $first (qw(Args CaptureArgs)) {
    for my $second (qw(Args CaptureArgs)) {
        eval <<"END";
            package TestApp::Controller::Action::Chained;
            no warnings 'redefine';
            sub should_fail :Chained('/') $first $second {}
END
        ok(!$@);
        eval { TestApp->setup_actions };
        my $msg = $first eq $second
           ? "Multiple $first"
           : "Combining Args and CaptureArgs";
        like($@, qr/$msg attributes not supported registering/,
             "$first + $second attribute makes action setup fail");
    }
}

done_testing();
