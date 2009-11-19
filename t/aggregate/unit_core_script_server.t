use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Test::More 'no_plan';
use Test::Exception;

use Catalyst::Script::Server;

my $testopts;

# Test default (no opts/args behaviour)
testOption( [ qw// ], ['3000', 'localhost', opthash()] );

# Old version supports long format opts with either one or two dashes.  New version only supports two.
#                Old                       New
# help           -? -help --help           -h --help
# debug          -d -debug --debug         -d --debug
# host           -host --host              --host
testOption( [ qw/--host testhost/ ], ['3000', 'testhost', opthash()] );
testOption( [ qw/-h testhost/ ], ['3000', 'testhost', opthash()] );

# port           -p -port --port           -l --listen
testOption( [ qw/-p 3001/ ], ['3001', 'localhost', opthash()] );
testOption( [ qw/--port 3001/ ], ['3001', 'localhost', opthash()] );

# fork           -f -fork --fork           -f --fork
testOption( [ qw/--fork/ ], ['3000', 'localhost', opthash(fork => 1)] );
testOption( [ qw/-f/ ], ['3000', 'localhost', opthash(fork => 1)] );

# pidfile        -pidfile                  --pid --pidfile
testOption( [ qw/--pidfile cat.pid/ ], ['3000', 'localhost', opthash(pidfile => "cat.pid")] );
testOption( [ qw/--pid cat.pid/ ], ['3000', 'localhost', opthash(pidfile => "cat.pid")] );

# keepalive      -k -keepalive --keepalive -k --keepalive
testOption( [ qw/-k/ ], ['3000', 'localhost', opthash(keepalive => 1)] );
testOption( [ qw/--keepalive/ ], ['3000', 'localhost', opthash(keepalive => 1)] );

# symlinks       -follow_symlinks          --sym --follow_symlinks
testOption( [ qw/--follow_symlinks/ ], ['3000', 'localhost', opthash(follow_symlinks => 1)] );
testOption( [ qw/--sym/ ], ['3000', 'localhost', opthash(follow_symlinks => 1)] );

# background     -background               --bg --background
testOption( [ qw/--background/ ], ['3000', 'localhost', opthash(background => 1)] );
testOption( [ qw/--bg/ ], ['3000', 'localhost', opthash(background => 1)] );

# Restart stuff requires a threaded perl, apparently.
# restart        -r -restart --restart     -R --restart
# restart dly    -rd -restartdelay         --rdel --restart_delay
# restart dir    -restartdirectory         --rdir --restart_directory
# restart regex  -rr -restartregex         --rxp --restart_regex


sub testOption {
    my ($argstring, $resultarray) = @_;

    subtest "Test for ARGV: @$argstring" => sub
        {
            plan tests => 2;
            local @ARGV = @$argstring;
            local @TestAppToTestScripts::RUN_ARGS;
            lives_ok {
                Catalyst::Script::Server->new_with_options(application_name => 'TestAppToTestScripts')->run;
            } "new_with_options";
            # First element of RUN_ARGS will be the script name, which we don't care about
            shift @TestAppToTestScripts::RUN_ARGS;
            is_deeply \@TestAppToTestScripts::RUN_ARGS, $resultarray, "is_deeply comparison";
            done_testing;
        };
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
