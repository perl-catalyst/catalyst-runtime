use strict;
use warnings;

use Test::More tests => 1;
use Test::TCP;

use File::Path;
use FindBin;
use Net::EmptyPort qw(wait_port empty_port);
use Try::Tiny;
use Plack::Builder;
use lib 't/lib';
use MakeTestApp;

# Run a single test by providing it as the first arg
my $single_test = shift;

my $test_app_dir = make_test_app;

# spawn the standalone HTTP server
my $port = empty_port;

my $pid = fork;
if ($pid) {
    # parent.
    print "Waiting for server to start...\n";
    wait_port_timeout($port, 30);
} elsif ($pid == 0) {
    # child process
    unshift @INC, "$test_app_dir/lib", "$FindBin::Bin/../../lib";
    require TestApp;

    my $psgi_app = TestApp->apply_default_middlewares(TestApp->psgi_app);
    Plack::Loader->auto(port => $port)->run(builder {
        mount '/test_prefix' => $psgi_app;
        mount '/' => sub {
            return [501, ['Content-Type' => 'text/plain'], ['broken tests']];
        };
    });

    exit 0;
} else {
    die "fork failed: $!";
}

# run the testsuite against the HTTP server
$ENV{CATALYST_SERVER} = "http://localhost:$port/test_prefix";

chdir '..';

my $return;
if ( $single_test ) {
    $return = system( "$^X -Ilib/ $single_test" );
}
else {
    $return = prove(grep { $_ ne '..' } glob('t/aggregate/live_*.t'));
}

# shut it down
kill 'INT', $pid;

# clean up
rmtree "$FindBin::Bin/../../t/tmp" if -d "$FindBin::Bin/../../t/tmp";

is( $return, 0, 'live tests' );

# kill 'INT' doesn't exist in Windows, so to prevent child hanging,
# this process will need to commit seppuku to clean up the children.
if ($^O eq 'MSWin32') {
    # Furthermore, it needs to do it 'politely' so that TAP doesn't
    # smell anything 'dubious'.
    require Win32::Process;  # core in all versions of Win32 Perl
    Win32::Process::KillProcess($$, $return);
}

sub wait_port_timeout {
    my ($port, $timeout) = @_;

    wait_port($port, $timeout * 10) and return;

    die "Server did not start within $timeout seconds";
}

sub prove {
    my (@tests) = @_;
    if (!(my $pid = fork)) {
        require TAP::Harness;

        my $harness = TAP::Harness->new({
            lib => ['lib'],
        });

        my $aggregator = $harness->runtests(@tests);

        exit $aggregator->has_errors ? 1 : 0;
    } else {
        waitpid $pid, 0;
        return $?;
    }
}
