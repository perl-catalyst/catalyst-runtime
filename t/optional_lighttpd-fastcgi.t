use strict;
use warnings;

use Test::More;
BEGIN {
    plan skip_all => 'set TEST_LIGHTTPD to enable this test'
        unless $ENV{TEST_LIGHTTPD};
}

use File::Path;
use FindBin;
use IO::Socket;
use Config ();

BEGIN {
    eval "use FCGI";
    plan skip_all => 'FCGI required' if $@;

    eval "use File::Copy::Recursive";
    plan skip_all => 'File::Copy::Recursive required' if $@;

    eval "use Test::Harness";
    plan skip_all => 'Test::Harness required' if $@;
}

use lib 't/lib';
use MakeTestApp;

my $lighttpd_bin = $ENV{LIGHTTPD_BIN} || `which lighttpd`;
chomp $lighttpd_bin;

plan skip_all => 'Please set LIGHTTPD_BIN to the path to lighttpd'
    unless $lighttpd_bin && -x $lighttpd_bin;

my $fix_scriptname = '';
if (my ($vmajor, $vminor, $vpatch) = `"$lighttpd_bin" -v` =~ /\b(\d+)\.(\d+)\.(\d+)\b/) {
    if ($vmajor > 1 || ($vmajor == 1 && ("$vminor.$vpatch" >= 4.23))) {
        $fix_scriptname = '"fix-root-scriptname" => "enable",';
    }
}

plan tests => 1;

# this creates t/tmp/TestApp
make_test_app;

# Create a temporary lighttpd config
my $docroot = "$FindBin::Bin/../t/tmp";
my $port    = 8529;

# Clean up docroot path
$docroot =~ s{/t/\.\.}{};

my $perl5lib = join($Config::Config{path_sep}, "$docroot/../../lib", $ENV{PERL5LIB} || ());

my $conf = <<"END";
# basic lighttpd config file for testing fcgi+catalyst
server.modules = (
    "mod_access",
    "mod_fastcgi",
    "mod_accesslog"
)

server.document-root = "$docroot"

server.errorlog    = "$docroot/error.log"
accesslog.filename = "$docroot/access.log"

server.bind = "127.0.0.1"
server.port = $port

# catalyst app specific fcgi setup
fastcgi.server = (
    "/" => (
        "FastCgiTest" => (
            "socket"          => "$docroot/test.socket",
            "check-local"     => "disable",
            "bin-path"        => "$docroot/TestApp/script/testapp_fastcgi.pl",
            "min-procs"       => 1,
            "max-procs"       => 1,
            "idle-timeout"    => 20,
            $fix_scriptname
            "bin-environment" => (
                "PERL5LIB" => "$perl5lib"
            )
        )
    )
)
END

open(my $lightconf, '>', "$docroot/lighttpd.conf")
  or die "Can't open $docroot/lighttpd.conf: $!";
print {$lightconf} $conf or die "Write error: $!";
close $lightconf;

my $pid = open my $lighttpd, "$lighttpd_bin -D -f $docroot/lighttpd.conf 2>&1 |"
    or die "Unable to spawn lighttpd: $!";

# wait for it to start
while ( check_port( 'localhost', $port ) != 1 ) {
    diag "Waiting for server to start...";
    sleep 1;
}

# run the testsuite against the server
$ENV{CATALYST_SERVER} = "http://localhost:$port";

my @tests = (shift) || glob('t/aggregate/live_*');
eval {
    runtests(@tests);
};
ok(!$@, 'lighttpd tests ran OK');

# shut it down
kill 'INT', $pid;
close $lighttpd;

# clean up
rmtree "$FindBin::Bin/../t/tmp" if -d "$FindBin::Bin/../t/tmp";

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
