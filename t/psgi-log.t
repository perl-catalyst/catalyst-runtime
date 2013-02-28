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


subtest "psgi.errors" => sub{

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
        my $res = $cb->(GET "/log/debug");
        my @logs = $handle->logs;
        is(scalar(@logs), 1, "one event output");
        like($logs[0], qr/debug$/, "event matches test data");
    };
};

subtest "psgix.logger" => sub {

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
        my $res = $cb->(GET "/log/debug");
        is(scalar(@logs), 1, "one event logged");
        is_deeply($logs[0], { level => 'debug', message => "debug" }, "right stuff");
    };
};



done_testing;
