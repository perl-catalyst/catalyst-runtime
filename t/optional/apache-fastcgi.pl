#!perl

# Run all tests against FastCGI mode under Apache
#
# Note, to get this to run properly, you may need to give it the path to your
# httpd.conf:
# 
# perl t/optional/apache-fastcgi.pl -httpd_conf /etc/apache/httpd.conf

use strict;
use warnings;

use Apache::Test;
use Apache::TestRun ();

use File::Path;
use File::Copy::Recursive;
use FindBin;
use IO::Socket;

# clean up
rmtree "$FindBin::Bin/../../t/tmp" if -d "$FindBin::Bin/../../t/tmp";

# create a TestApp and copy the test libs into it
mkdir "$FindBin::Bin/../../t/tmp";
chdir "$FindBin::Bin/../../t/tmp";
system "$FindBin::Bin/../../script/catalyst.pl TestApp";
chdir "$FindBin::Bin/../..";
File::Copy::Recursive::dircopy( 't/live/lib', 't/tmp/TestApp/lib' );

# remove TestApp's tests so Apache::Test doesn't try to run them
rmtree 't/tmp/TestApp/t';

$ENV{CATALYST_SERVER} = 'http://localhost:8529/fastcgi';

Apache::TestRun->new->run(@ARGV);

# clean up if the server has shut down
# this allows the test files to stay around if the user ran -start-httpd
if ( ! check_port( 'localhost', 8529 ) ) {
    rmtree "$FindBin::Bin/../../t/tmp" if -d "$FindBin::Bin/../../t/tmp";
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
