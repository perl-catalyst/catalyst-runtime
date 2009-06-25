package testapp::Script::Server;

use Catalyst::Engine::HTTP;
use testapp;
use Moose;

with 'MooseX::GetOpt';

has argv => ( isa => 'ArrayRef', is => 'ro', required => 1 );
has [qw/ fork background keepalive /] => ( isa => 'Bool', is => 'ro', required => 1, default => 0 );
has pidfile => ( isa => 'Str', required => 0, is => 'ro' );

sub run {
    my $self = shift;
    testapp->run(
        $port, $host,
        {
            argv       => $self->argv,
            'fork'     => $self->fork,
            keepalive  => $self->keepalive,
            background => $self->background,
            pidfile    => $self->pidfile,
        }
    );
}

pod2usage(1) if $help;

if ( $debug ) {
    $ENV{CATALYST_DEBUG} = 1;
}

# If we load this here, then in the case of a restarter, it does not
# need to be reloaded for each restart.
require Catalyst;

# If this isn't done, then the Catalyst::Devel tests for the restarter
# fail.
$| = 1 if $ENV{HARNESS_ACTIVE};

my $runner = sub {
    # This is require instead of use so that the above environment
    # variables can be set at runtime.
    require TestApp;

    TestApp->run(
        $port, $host,
        {
            argv       => \@argv,
            'fork'     => $fork,
            keepalive  => $keepalive,
            background => $background,
            pidfile    => $pidfile,
        }
    );
};

if ( $restart ) {
    die "Cannot run in the background and also watch for changed files.\n"
        if $background;

    require Catalyst::Restarter;

    my $subclass = Catalyst::Restarter->pick_subclass;

    my %args;
    $args{follow_symlinks} = 1
        if $follow_symlinks;
    $args{directories} = $watch_directory
        if defined $watch_directory;
    $args{sleep_interval} = $check_interval
        if defined $check_interval;
    $args{filter} = qr/$file_regex/
        if defined $file_regex;

    my $restarter = $subclass->new(
        %args,
        start_sub => $runner,
    );

    $restarter->run_and_watch;
}
else {
    $runner->();
}

__PACKAGE__->new_with_options->run;



1;

=head1 NAME

testapp_server.pl - Catalyst Testserver

=head1 SYNOPSIS

testapp_server.pl [options]

 Options:
   -d -debug          force debug mode
   -f -fork           handle each request in a new process
                      (defaults to false)
   -? -help           display this help and exits
      -host           host (defaults to all)
   -p -port           port (defaults to 3000)
   -k -keepalive      enable keep-alive connections
   -r -restart        restart when files get modified
                      (defaults to false)
   -rd -restartdelay  delay between file checks
                      (ignored if you have Linux::Inotify2 installed)
   -rr -restartregex  regex match files that trigger
                      a restart when modified
                      (defaults to '\.yml$|\.yaml$|\.conf|\.pm$')
   -restartdirectory  the directory to search for
                      modified files, can be set mulitple times
                      (defaults to '[SCRIPT_DIR]/..')
   -follow_symlinks   follow symlinks in search directories
                      (defaults to false. this is a no-op on Win32)
   -background        run the process in the background
   -pidfile           specify filename for pid file

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst Testserver for this application.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
