use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Test::More;
use Test::Exception;

use Catalyst::Script::FastCGI;

my $fake_handler = \42;

{
    package TestFastCGIScript;
    use Moose;
    use namespace::autoclean;

    extends 'Catalyst::Script::FastCGI';

    # Avoid loading the real plack engine, as that will load FCGI and fail if
    # it's not there. We don't really need a full engine anyway as the overriden
    # MyApp->run will just capture its arguments and return without delegating
    # to the engine to run things.
    override load_engine => sub { $fake_handler };

    __PACKAGE__->meta->make_immutable;
}

sub testOption {
    my ($argstring, $resultarray) = @_;

    local @ARGV = @$argstring;
    local @TestAppToTestScripts::RUN_ARGS;
    lives_ok {
        TestFastCGIScript->new_with_options(application_name => 'TestAppToTestScripts')->run;
    } "new_with_options";
    # First element of RUN_ARGS will be the script name, which we don't care about
    shift @TestAppToTestScripts::RUN_ARGS;
    my $server = pop @TestAppToTestScripts::RUN_ARGS;
    is $server, $fake_handler, 'Loaded Plack handler gets passed to the app';
    is_deeply \@TestAppToTestScripts::RUN_ARGS, $resultarray, "is_deeply comparison";
}

# Returns the hash expected when no flags are passed
sub opthash {
    return {
        (map { ($_ => undef) } qw(pidfile keep_stderr detach nproc manager)),
        proc_title => 'perl-fcgi-pm [TestAppToTestScripts]',
        @_,
    };
}


# Test default (no opts/args behaviour)
testOption( [ qw// ], [undef, opthash()] );

# listen socket
testOption( [ qw|-l /tmp/foo| ], ['/tmp/foo', opthash()] );
testOption( [ qw/-l 127.0.0.1:3000/ ], ['127.0.0.1:3000', opthash()] );

#daemonize           -d --daemon
testOption( [ qw/-d/ ], [undef, opthash(detach => 1)] );
testOption( [ qw/--daemon/ ], [undef, opthash(detach => 1)] );

# pidfile        -pidfile -p                 --pid --pidfile
testOption( [ qw/--pidfile cat.pid/ ], [undef, opthash(pidfile => 'cat.pid')] );
testOption( [ qw/--pid cat.pid/ ], [undef, opthash(pidfile => 'cat.pid')] );
testOption( [ qw/-p cat.pid/ ], [undef, opthash(pidfile => 'cat.pid')] );

# manager
testOption( [ qw/--manager foo::bar/ ], [undef, opthash(manager => 'foo::bar')] );
testOption( [ qw/-M foo::bar/ ], [undef, opthash(manager => 'foo::bar')] );

# keeperr
testOption( [ qw/--keeperr/ ], [undef, opthash(keep_stderr => 1)] );
testOption( [ qw/-e/ ], [undef, opthash(keep_stderr => 1)] );

# nproc
testOption( [ qw/--nproc 6/ ], [undef, opthash(nproc => 6)] );
testOption( [ qw/--n 6/ ], [undef, opthash(nproc => 6)] );

# proc_title
testOption( [ qw/--proc_title foo/ ], [undef, opthash(proc_title => 'foo')] );

done_testing;
