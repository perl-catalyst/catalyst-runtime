# Run all tests against FastCGI mode under Apache
#
# Note, to get this to run properly, you may need to give it the path to your
# httpd.conf:
#
# perl t/optional_apache-fastcgi.pl -httpd_conf /etc/apache/httpd.conf

use strict;
use warnings;

use Apache::Test;
use Apache::TestRun ();

use File::Path;
use File::Copy::Recursive;
use FindBin;
use IO::Socket;

use lib 't/lib';
use MakeTestApp;

make_test_app;

$ENV{CATALYST_SERVER} = 'http://localhost:8529';

if ( !-e 't/optional_apache-fastcgi.pl' ) {
    die "ERROR: Please run test from the Catalyst-Runtime directory\n";
}

push @ARGV, glob( 't/aggregate/live_*' );

Apache::TestRun->new->run(@ARGV);

# clean up if the server has shut down
# this allows the test files to stay around if the user ran -start-httpd
if ( !check_port( 'localhost', 8529 ) ) {
    rmtree "$FindBin::Bin/../t/tmp" if -d "$FindBin::Bin/../t/tmp";
}

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
