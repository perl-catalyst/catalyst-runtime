use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Test::More;
use Test::Exception;

use Catalyst::Script::FastCGI;

my $testopts;

# Test default (no opts/args behaviour)
testOption( [ qw// ], [undef, opthash()] );

# listen socket
testOption( [ qw|-l /tmp/foo| ], ['/tmp/foo', opthash()] );
testOption( [ qw/-l 127.0.0.1:3000/ ], ['127.0.0.1:3000', opthash()] );

#daemonize           -d --daemon
testOption( [ qw/-d/ ], [undef, opthash()] );
testOption( [ qw/--daemon/ ], [undef, opthash()] );

# pidfile        -pidfile                  --pid --pidfile
testOption( [ qw/--pidfile cat.pid/ ], [undef, opthash(pidfile => 'cat.pid')] );
testOption( [ qw/--pid cat.pid/ ], [undef, opthash(pidfile => 'cat.pid')] );

# manager
testOption( [ qw/--manager foo::bar/ ], [undef, opthash(manager => 'foo::bar')] );
testOption( [ qw/-M foo::bar/ ], [undef, opthash(manager => 'foo::bar')] );

# keeperr
testOption( [ qw/--keeperr/ ], [undef, opthash(keep_stderr => 1)] );
testOption( [ qw/-e/ ], [undef, opthash(keep_stderr => 1)] );

# nproc
testOption( [ qw/--nproc 6/ ], [undef, opthash(nproc => 6)] );
testOption( [ qw/--n 6/ ], [undef, opthash(nproc => 6)] );

# detach
testOption( [ qw/--detach/ ], [undef, opthash(detach => 1)] );
testOption( [ qw/--det/ ], [undef, opthash(detach => 1)] );

done_testing;

sub testOption {
    my ($argstring, $resultarray) = @_;

    local @ARGV = @$argstring;
    local @TestAppToTestScripts::RUN_ARGS;
    lives_ok {
        Catalyst::Script::FastCGI->new_with_options(application_name => 'TestAppToTestScripts')->run;
    } "new_with_options";
    # First element of RUN_ARGS will be the script name, which we don't care about
    shift @TestAppToTestScripts::RUN_ARGS;
    is_deeply \@TestAppToTestScripts::RUN_ARGS, $resultarray, "is_deeply comparison";
}

# Returns the hash expected when no flags are passed
sub opthash {
    return {
        pidfile => undef,
        keep_stderr => undef,
        detach => undef,
        nproc => undef,
        manager => undef,
        @_,
    };
}
