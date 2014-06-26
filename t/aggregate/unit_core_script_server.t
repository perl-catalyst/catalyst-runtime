use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use File::Temp qw/ tempdir /;
use Cwd;
use Test::More;
use Try::Tiny;

use Catalyst::Script::Server;

my $cwd = getcwd;
chdir(tempdir(CLEANUP => 1));

my $testopts;

# Test default (no opts/args behaviour)
# Note undef for host means we bind to all interfaces.
testOption( [ qw// ], ['3000', undef, opthash()] );

# Old version supports long format opts with either one or two dashes.  New version only supports two.
#                Old                       New
# help           -? -help --help           -? --help
# debug          -d -debug --debug         -d --debug
# host           -host --host              --host
testOption( [ qw/--host testhost/ ], ['3000', 'testhost', opthash(host => 'testhost')] );
testOption( [ qw/-h testhost/ ], ['3000', 'testhost', opthash(host => 'testhost')] );

# port           -p -port --port           -l --listen
testOption( [ qw/-p 3001/ ], ['3001', undef, opthash(port => 3001)] );
testOption( [ qw/--port 3001/ ], ['3001', undef, opthash(port => 3001)] );
{
    local $ENV{TESTAPPTOTESTSCRIPTS_PORT} = 5000;
    testOption( [ qw// ], [5000, undef, opthash(port => 5000)] );
}
{
    local $ENV{CATALYST_PORT} = 5000;
    testOption( [ qw// ], [5000, undef, opthash(port => 5000)] );
}

if (try { require Plack::Handler::Starman; 1; }) {
    # fork           -f -fork --fork           -f --fork
    testOption( [ qw/--fork/ ], ['3000', undef, opthash(fork => 1)] );
    testOption( [ qw/-f/ ], ['3000', undef, opthash(fork => 1)] );
}

if (try { require MooseX::Daemonize; 1; }) {
    # pidfile        -pidfile                  --pid --pidfile
    testOption( [ qw/--pidfile cat.pid/ ], ['3000', undef, opthash(pidfile => "cat.pid")] );
    testOption( [ qw/--pid cat.pid/ ], ['3000', undef, opthash(pidfile => "cat.pid")] );
}

if (try { require Plack::Handler::Starman; 1; }) {
    # keepalive      -k -keepalive --keepalive -k --keepalive
    testOption( [ qw/-k/ ], ['3000', undef, opthash(keepalive => 1)] );
    testOption( [ qw/--keepalive/ ], ['3000', undef, opthash(keepalive => 1)] );
}

# symlinks       -follow_symlinks          --sym --follow_symlinks
#
testOption( [ qw/--sym/ ], ['3000', undef, opthash(follow_symlinks => 1)] );
testOption( [ qw/--follow_symlinks/ ], ['3000', undef, opthash(follow_symlinks => 1)] );

if (try { require MooseX::Daemonize; 1; }) {
    # background     -background               --bg --background
    testBackgroundOptionWithFork( [ qw/--background/ ]);
    testBackgroundOptionWithFork( [ qw/--bg/ ]);
}

# restart        -r -restart --restart     -R --restart
testRestart( ['-r'], restartopthash() );
{
    local $ENV{TESTAPPTOTESTSCRIPTS_RELOAD} = 1;
    testRestart( [], restartopthash() );
}
{
    local $ENV{CATALYST_RELOAD} = 1;
    testRestart( [], restartopthash() );
}

# restart dly    -rd -restartdelay         --rd --restart_delay
testRestart( ['-r', '--rd', 30], restartopthash(sleep_interval => 30) );
testRestart( ['-r', '--restart_delay', 30], restartopthash(sleep_interval => 30) );

# restart dir    -restartdirectory         --rdir --restart_directory
testRestart( ['-r', '--rdir', 'root'], restartopthash(directories => ['root']) );
testRestart( ['-r', '--rdir', 'root', '--rdir', 'lib'], restartopthash(directories => ['root', 'lib']) );
testRestart( ['-r', '--restart_directory', 'root'], restartopthash(directories => ['root']) );

# restart regex  -rr -restartregex         --rr --restart_regex
testRestart( ['-r', '--rr', 'foo'], restartopthash(filter => qr/foo/) );
testRestart( ['-r', '--restart_regex', 'foo'], restartopthash(filter => qr/foo/) );

local $ENV{TESTAPPTOTESTSCRIPTS_RESTARTER};
local $ENV{CATALYST_RESTARTER};
{
    is _build_testapp([])->restarter_class, 'Catalyst::Restarter', 'default restarter with no $ENV{CATALYST_RESTARTER}';
}
{
    local $ENV{CATALYST_RESTARTER} = "CatalystX::Restarter::Other";
    is _build_testapp([])->restarter_class, $ENV{CATALYST_RESTARTER}, 'override restarter with $ENV{CATALYST_RESTARTER}';
}
{
    local $ENV{TESTAPPTOTESTSCRIPTS_RESTARTER} = "CatalystX::Restarter::Other2";
    is _build_testapp([])->restarter_class, $ENV{TESTAPPTOTESTSCRIPTS_RESTARTER}, 'override restarter with $ENV{TESTAPPTOTESTSCRIPTS_RESTARTER}';
}
done_testing;

sub testOption {
    my ($argstring, $resultarray) = @_;
    my $app = _build_testapp($argstring);
    try {
        $app->run;
    }
    catch {
        fail $_;
    };
    # First element of RUN_ARGS will be the script name, which we don't care about

    shift @TestAppToTestScripts::RUN_ARGS;
    my $server = pop @TestAppToTestScripts::RUN_ARGS;
    like ref($server), qr/^Plack::Handler/, 'Is a Plack::Handler';

    my @run_args =  @TestAppToTestScripts::RUN_ARGS;
    $run_args[-1]->{pidfile} = $run_args[-1]->{pidfile}->file->stringify
      if scalar(@run_args) && $run_args[-1]->{pidfile};

    # Mangle argv into the options..
    $resultarray->[-1]->{argv} = $argstring;
    $resultarray->[-1]->{extra_argv} = [];
    is_deeply \@run_args, $resultarray, "is_deeply comparison " . join(' ', @$argstring);
}

sub testBackgroundOptionWithFork {
    my ($argstring) = @_;

    ## First, make sure we can get an app
    my $app = _build_testapp($argstring);

    ## Sorry, don't really fork since this cause trouble in Test::Aggregate
    $app->meta->add_around_method_modifier('daemon_fork', sub { return; });

    try {
        $app->run;
    }
    catch {
        fail $_;
    };

    ## Check a few args
    is_deeply $app->{ARGV}, $argstring;
    is $app->port, '3000';
    is($app->{background}, 1);
}

sub testRestart {
    my ($argstring, $resultarray) = @_;
    my $app = _build_testapp($argstring);
    ok $app->restart, 'App is in restart mode';
    my $args = {$app->_restarter_args};
    is_deeply delete $args->{argv}, $argstring, 'argv is arg string';
    is ref(delete $args->{start_sub}), 'CODE', 'Closure to start app present';
    is_deeply $args, $resultarray, "is_deeply comparison of restarter args " . join(' ', @$argstring);
}

sub _build_testapp {
    my ($argstring, $resultarray) = @_;

    local @ARGV = @$argstring;
    local @TestAppToTestScripts::RUN_ARGS;
    my $i;
    try {
        $i = Catalyst::Script::Server->new_with_options(application_name => 'TestAppToTestScripts');
        pass "new_with_options " . join(' ', @$argstring);
    }
    catch {
        fail "new_with_options " . join(' ', @$argstring) . " " . $_;
    };
    ok $i;
    return $i;
}

# Returns the hash expected when no flags are passed
sub opthash {
    return {
        'pidfile' => undef,
        'fork' => 0,
        'follow_symlinks' => 0,
        'background' => 0,
        'keepalive' => 0,
        port => 3000,
        host => undef,
        @_,
    };
}

sub restartopthash {
    my $opthash = opthash(@_);
    my $val = {
        application_name => 'TestAppToTestScripts',
        port => '3000',
        debug => undef,
        host => undef,
        %$opthash,
    };
    return $val;
}

chdir($cwd);

1;

