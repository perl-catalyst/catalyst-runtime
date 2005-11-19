#!perl

# This test tests the standalone server's auto-restart feature.

use strict;
use warnings;

use File::Path;
use FindBin;
use LWP::Simple;
use IO::Socket;
use Test::More;
use Time::HiRes qw/sleep/;
eval "use File::Copy::Recursive";

plan skip_all => 'set TEST_HTTP to enable this test' unless $ENV{TEST_HTTP};
plan skip_all => 'File::Copy::Recursive required' if $@;

plan tests => 40;

# clean up
rmtree "$FindBin::Bin/../../t/tmp" if -d "$FindBin::Bin/../../t/tmp";

# create a TestApp and copy the test libs into it
mkdir "$FindBin::Bin/../../t/tmp";
chdir "$FindBin::Bin/../../t/tmp";
system "perl -I$FindBin::Bin/../../lib $FindBin::Bin/../../script/catalyst.pl TestApp";
chdir "$FindBin::Bin/../..";
File::Copy::Recursive::dircopy( 't/live/lib', 't/tmp/TestApp/lib' );

# remove TestApp's tests
rmtree 't/tmp/TestApp/t';

# spawn the standalone HTTP server
my $port = 30000 + int rand(1 + 10000);
my $pid = open my $server, 
    "perl -I$FindBin::Bin/../../lib $FindBin::Bin/../../t/tmp/TestApp/script/testapp_server.pl -port $port -restart 2>&1 |"
    or die "Unable to spawn standalone HTTP server: $!";

# wait for it to start
print "Waiting for server to start...\n";
while ( check_port( 'localhost', $port ) != 1 ) {
    sleep 1;
}

# change various files
my @files = (
    "$FindBin::Bin/../../t/tmp/TestApp/lib/TestApp.pm",
    "$FindBin::Bin/../../t/tmp/TestApp/lib/TestApp/Controller/Action/Begin.pm",
    "$FindBin::Bin/../../t/tmp/TestApp/lib/TestApp/Controller/Engine/Request/URI.pm",
);

# change some files and make sure the server restarts itself
for ( 1..20 ) {
    my $index = rand @files;
    open my $pm, '>>', $files[$index]
        or die "Unable to open $files[$index] for writing: $!";
    print $pm "\n";
    close $pm;
    
    # give the server time to notice the change and restart
    my $count = 0;
    sleep 1;
    while ( check_port( 'localhost', $port ) != 1 ) {
        # wait for it to restart
        sleep 0.1;
        die "Server appears to have died" if $count++ > 50;
    }
    my $response = get("http://localhost:$port/action/default");
    like( $response, qr/Catalyst::Request/, 'Non-error restart, request OK' );
    
    #print $server->getline;
}

# add errors to the file and make sure server does not die or restart
for ( 1..20 ) {
    my $index = rand @files;
    open my $pm, '>>', $files[$index]
        or die "Unable to open $files[$index] for writing: $!";
    print $pm "bleh";
    close $pm;
    
    # give the server time to notice the change
    sleep 1;
    if ( check_port( 'localhost', $port ) != 1 ) {
        die "Server appears to have died";
    }
    my $response = get("http://localhost:$port/action/default");
    like( $response, qr/Catalyst::Request/, 'Syntax error, no restart, request OK' );
    
    #print $server->getline;
}

# shut it down
kill 'INT', $pid;
close $server;

# clean up
rmtree "$FindBin::Bin/../../t/tmp" if -d "$FindBin::Bin/../../t/tmp";

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
