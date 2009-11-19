use strict;
use warnings;

use Test::More tests => 1;

use File::Path;
use FindBin;
use IPC::Open3;
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
my @cmd = ($^X, "-I$FindBin::Bin/../../lib",
  "$FindBin::Bin/../../t/tmp/TestApp/script/testapp_server.pl", '-port', $port );
my $pid = open3( undef, my $server, undef, @cmd)
    or die "Unable to spawn standalone HTTP server: $!";

# wait for it to start
print "Waiting for server to start...\n";
my $timeout = 30;
my $count = 0;
while ( check_port( 'localhost', $port ) != 1 ) {
    sleep 1;
    die("Server did not start within $timeout seconds: " . join(' ', @cmd))
        if $count++ > $timeout;
}

# run the testsuite against the HTTP server
$ENV{CATALYST_SERVER} = "http://localhost:$port";

my $return;
if ( $single_test ) {
    $return = system( "$^X -I../lib/ $single_test" );
}
else {
    $return = prove( '-r', '-I../lib/', glob('../t/aggregate/live_*.t') );
}

# shut it down
kill 'INT', $pid;
close $server;

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
    if (!(my $pid = fork)) {
        require App::Prove;
        my $prove = App::Prove->new;
        $prove->process_args(@_);
        exit( $prove->run ? 0 : 1 );
    } else {
        waitpid $pid, 0;
        return $?;
    }
}
