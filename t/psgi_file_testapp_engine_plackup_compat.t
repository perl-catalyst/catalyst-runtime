use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/lib";

use Test::More;
use Test::Fatal;
use Plack::Test;
use TestApp;
use HTTP::Request::Common;

plan skip_all => "Catalyst::Engine::PSGI required for this test"
    unless eval { local $SIG{__WARN__} = sub{}; require Catalyst::Engine::PSGI; 1; };

my $warning;
local $SIG{__WARN__} = sub { $warning = $_[0] };

TestApp->setup_engine('PSGI');
my $app = sub { TestApp->run(@_) };

like $warning, qr/You are running Catalyst\:\:Engine\:\:PSGI/,
  'got deprecation alert warning';

test_psgi $app, sub {
    my $cb = shift;
    is exception {
        my $TIMEOUT_IN_SECONDS = 5;
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm($TIMEOUT_IN_SECONDS);

        my $res = $cb->(GET "/");
        is $res->content, "root index", 'got expected content';
        like $warning, qr/env as a writer/, 'got deprecation alert warning';

        alarm(0);
        1
    }, undef, q{app didn't die or timeout};
};

done_testing;

