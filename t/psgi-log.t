=head1 PROBLEM

In https://github.com/plack/Plack/commit/cafa5db84921f020183a9c834fd6a4541e5a6b84
chansen made a change to the FCGI handler in Plack, in which he replaced
STDERR, STDOUT and STDIN with proper IO::Handle objects.

The side effect of that change is that catalyst outputing logs on STDERR will
no longer end up by default in the error log of the webserver when running
under FCGI. This test tries to make sure we use the propper parts of the psgi
environment when we output things from Catalyst::Log.

There is one more "regression", and that is warnings. By using
Catalyst::Plugin::LogWarnings, you also get those in the right place if this
test passes :)

=cut

use strict;
use warnings;
no warnings 'once';
use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;

use File::Spec;
use File::Temp qw/ tempdir /;

use TestApp;

use Plack::Builder;
use Plack::Test;
use HTTP::Request::Common;

{
    package MockHandle;
    use Moose;

    has 'log' => (is => 'ro', isa => 'ArrayRef', traits => ['Array'], default => sub { [] },
        handles => {
            'logs' => 'elements',
            'print' => 'push',
        }
    );

    no Moose;
}

my $cmp = TestApp->debug ? '>=' : '==';

#subtest "psgi.errors" => sub
{

    my $handle = MockHandle->new();
    my $app = builder {

        enable sub {
            my $app = shift;
            sub {
                my $env = shift;
                $env->{'psgi.errors'} = $handle;
                my $res = $app->($env);
                return $res;
            };
        };
        TestApp->psgi_app;
    };


    test_psgi $app, sub {
        my $cb = shift;
        my $res = $cb->(GET "/log/info");
        my @logs = $handle->logs;
        cmp_ok(scalar(@logs), $cmp, 1, "psgi.errors: one event output");
        like($logs[0], qr/info$/m, "psgi.errors: event matches test data");
    };
};

#subtest "psgix.logger" => sub
{

    my @logs;
    my $logger = sub {
        push(@logs, @_);
    };
    my $app = builder {
        enable sub {
            my $app = shift;
            sub {
                my $env = shift;
                $env->{'psgix.logger'} = $logger;
                $app->($env);
            };
        };
        TestApp->psgi_app;
    };

    test_psgi $app, sub {
        my $cb = shift;
        my $res = $cb->(GET "/log/info");
        cmp_ok(scalar(@logs), $cmp, 1, "psgix.logger: one event logged");
        is(scalar(grep { $_->{level} eq 'info' and $_->{message} eq 'info' } @logs),
           1, "psgix.logger: right stuff");
    };
};



done_testing;
