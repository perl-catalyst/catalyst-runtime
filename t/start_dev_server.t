use Test::More tests => 1;
use strict;
use warnings;
use Catalyst::Engine::HTTP;
use File::Temp qw/ tempdir tmpnam /;
use FindBin qw/$Bin/;
use File::Spec;
use lib "$Bin/TestApp/lib";
use TestApp;
use Test::WWW::Mechanize;

my $dir = tempdir(); # CLEANUP => 1 );
my $devnull = File::Spec->devnull;

my $server_path   = File::Spec->catfile('script', 'testapp_server.pl');
my $port = int(rand(10000)) + 40000; # get random port between 40000-50000

my $childpid = fork();
die "fork() error, cannot continue" unless defined($childpid);

if ($childpid == 0) {
  system("$^X $server_path -p $port > $devnull 2>&1");
  exit; # just for sure; we should never got here
}

sleep 10; #wait for catalyst application to start
my $mech = Test::WWW::Mechanize->new;
$mech->get_ok( "http://localhost:" . $port );

kill 'KILL', $childpid;


