use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Test::More;
use Test::Exception;

use Catalyst::Script::Server;

my $testopts;

# Test default (no opts/args behaviour)
# Note undef for host means we bind to all interfaces.
testOption( [ qw// ], ['3000', undef, opthash()] );

# Old version supports long format opts with either one or two dashes.  New version only supports two.
#                Old                       New
# help           -? -help --help           -? --help
# debug          -d -debug --debug         -d --debug
# host           -host --host              --host
testOption( [ qw/--host testhost/ ], ['3000', 'testhost', opthash()] );
testOption( [ qw/-h testhost/ ], ['3000', 'testhost', opthash()] );

# port           -p -port --port           -l --listen
testOption( [ qw/-p 3001/ ], ['3001', undef, opthash()] );
testOption( [ qw/--port 3001/ ], ['3001', undef, opthash()] );

# fork           -f -fork --fork           -f --fork
testOption( [ qw/--fork/ ], ['3000', undef, opthash(fork => 1)] );
testOption( [ qw/-f/ ], ['3000', undef, opthash(fork => 1)] );

# pidfile        -pidfile                  --pid --pidfile
testOption( [ qw/--pidfile cat.pid/ ], ['3000', undef, opthash(pidfile => "cat.pid")] );
testOption( [ qw/--pid cat.pid/ ], ['3000', undef, opthash(pidfile => "cat.pid")] );

# keepalive      -k -keepalive --keepalive -k --keepalive
testOption( [ qw/-k/ ], ['3000', undef, opthash(keepalive => 1)] );
testOption( [ qw/--keepalive/ ], ['3000', undef, opthash(keepalive => 1)] );

# symlinks       -follow_symlinks          --sym --follow_symlinks
testOption( [ qw/--follow_symlinks/ ], ['3000', undef, opthash(follow_symlinks => 1)] );
testOption( [ qw/--sym/ ], ['3000', undef, opthash(follow_symlinks => 1)] );

# background     -background               --bg --background
testOption( [ qw/--background/ ], ['3000', undef, opthash(background => 1)] );
testOption( [ qw/--bg/ ], ['3000', undef, opthash(background => 1)] );

# restart        -r -restart --restart     -R --restart
testRestart( ['-r'], restartopthash() );
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

done_testing;

sub testOption {
    my ($argstring, $resultarray) = @_;
    my $app = _build_testapp($argstring);
    lives_ok {
        $app->run;
    };
    # First element of RUN_ARGS will be the script name, which we don't care about
    shift @TestAppToTestScripts::RUN_ARGS;
    is_deeply \@TestAppToTestScripts::RUN_ARGS, $resultarray, "is_deeply comparison " . join(' ', @$argstring);
}

sub testRestart {
    my ($argstring, $resultarray) = @_;
    my $app = _build_testapp($argstring);
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
    lives_ok {
        $i = Catalyst::Script::Server->new_with_options(application_name => 'TestAppToTestScripts');
    } "new_with_options " . join(' ', @$argstring);;
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
        @_,
    };
}

sub restartopthash {
    return {
        follow_symlinks => 0,
        @_,
    };
}
