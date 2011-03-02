use strict;
use warnings;

use Test::More tests => 1;

use File::Path;
use FindBin;
use IO::Socket;

use Catalyst::Devel 1.0;
use File::Copy::Recursive;

# Run a single test by providing it as the first arg
my $single_test = shift;

my $tmpdir = "$FindBin::Bin/../../t/tmp";

# clean up
rmtree $tmpdir if -d $tmpdir;

# create a TestApp and copy the test libs into it
mkdir $tmpdir;
chdir $tmpdir;
system( $^X, "-I$FindBin::Bin/../../lib", "$FindBin::Bin/../../script/catalyst.pl", 'TestApp' );
chdir "$FindBin::Bin/..";
File::Copy::Recursive::dircopy( '../t/lib', '../t/tmp/TestApp/lib' ) or die;

# remove TestApp's tests
rmtree '../t/tmp/TestApp/t' or die;

# spawn the standalone HTTP server
my $port = 30000 + int rand(1 + 10000);

my $pid = fork;
if ($pid) {
    # parent.
    print "Waiting for server to start...\n";
    my $timeout = 30;
    my $count = 0;
    while ( check_port( 'localhost', $port ) != 1 ) {
        sleep 1;
        die "Server did not start within $timeout seconds:"
            if $count++ > $timeout;
    }
} elsif ($pid == 0) {
    # child process
    unshift @INC, "$tmpdir/TestApp/lib", "$FindBin::Bin/../../lib";
    require TestApp;

    my $psgi_app = TestApp->_wrapped_legacy_psgi_app(TestApp->psgi_app);
    Plack::Loader->auto(port => $port)->run($psgi_app);

    exit 0;
} else {
    die "fork failed: $!";
}

# run the testsuite against the HTTP server
$ENV{CATALYST_SERVER} = "http://localhost:$port";

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

sub check_port {
    my ( $host, $port ) = @_;

    my $remote = IO::Socket::INET->new(
        Proto    => "tcp",
        PeerAddr => $host,
        PeerPort => $port
    );
    if ($remote) {
        close $remote;
        return 1;
    }
    else {
        return 0;
    }
}

sub prove {
    my (@tests) = @_;
    if (!(my $pid = fork)) {
        require TAP::Harness;

        my $aggr = -e '.aggregating';
        my $harness = TAP::Harness->new({
            ($aggr ? (test_args => \@tests) : ()),
            lib => ['lib'],
        });

        my $aggregator = $aggr
            ? $harness->runtests('t/aggregate.t')
            : $harness->runtests(@tests);

        exit $aggregator->has_errors ? 1 : 0;
    } else {
        waitpid $pid, 0;
        return $?;
    }
}
