package Catalyst::Script::Server;

BEGIN {
    $ENV{CATALYST_ENGINE} ||= 'HTTP';
    $ENV{CATALYST_SCRIPT_GEN} = 31;
    require Catalyst::Engine::HTTP;
}

use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use Pod::Usage;
use Moose;
use Catalyst::Restarter;
use namespace::autoclean;

with 'MooseX::Getopt';

has debug => (
    traits => [qw(Getopt)],
    cmd_aliases => 'd',
    isa => 'Bool',
    is => 'ro',
    documentation => qq{
    -d --debug force debug mode
    }

);

has help => (
    traits => [qw(Getopt)],
    cmd_aliases => 'h',
    isa => 'Bool',
    is => 'ro',
    documentation => qq{
    -h --help display this help and exits
    },
);

has host => (
    isa => 'Str',
    is => 'ro',
    ,
    default =>  "localhost"
);

has fork => (
    traits => [qw(Getopt)],
    cmd_aliases => 'f',
    isa => 'Bool',
    is => 'ro',

);

has listen => (
    traits => [qw(Getopt)],
    cmd_aliases => 'l',
    isa => 'Int',
    is => 'ro',
    ,
    default => "3000"
);

has pidfile => (
    traits => [qw(Getopt)],
    cmd_aliases => 'pid',
    isa => 'Str',
    is => 'ro',

);

has keepalive => (
    traits => [qw(Getopt)],
    cmd_aliases => 'k',
    isa => 'Bool',
    is => 'ro',
    ,

);

has background => (
    traits => [qw(Getopt)],
    cmd_aliases => 'bg',
    isa => 'Bool',
    is => 'ro',
);


has _app => (
    reader   => 'app',
    init_arg => 'app',
    traits => [qw(NoGetopt)],
    isa => 'Str',
    is => 'ro',
);

has restart => (
    traits => [qw(Getopt)],
    cmd_aliases => 'r',
    isa => 'Bool',
    is => 'ro',

);

has restart_directory => (
    traits => [qw(Getopt)],
    cmd_aliases => 'rdir',
    isa => 'ArrayRef[Str]',
    is  => 'ro',
    predicate => '_has_restart_directory',
);

has restart_delay => (
    traits => [qw(Getopt)],
    cmd_aliases => 'rdel',
    isa => 'Int',
    is => 'ro',
    predicate => '_has_restart_delay',
);

has restart_regex => (
    traits => [qw(Getopt)],
    cmd_aliases => 'rxp',
    isa => 'Str',
    is => 'ro',
    predicate => '_has_restart_regex',
);

has follow_symlinks => (
    traits => [qw(Getopt)],
    cmd_aliases => 'sym',
    isa => 'Bool',
    is => 'ro',
    predicate => '_has_follow_symlinks',

);

sub usage {
    my ($self) = shift;

    return pod2usage();

}


sub run {
    my ($self) = shift;

    $self->usage if $self->help;

    if ( $self->debug ) {
        $ENV{CATALYST_DEBUG} = 1;
    }

    # If we load this here, then in the case of a restarter, it does not
    # need to be reloaded for each restart.
    require Catalyst;

    # If this isn't done, then the Catalyst::Devel tests for the restarter
    # fail.
    $| = 1 if $ENV{HARNESS_ACTIVE};

    if ( $self->restart ) {
        die "Cannot run in the background and also watch for changed files.\n"
            if $self->background;

        require Catalyst::Restarter;

        my $subclass = Catalyst::Restarter->pick_subclass;

        my %args;
        $args{follow_symlinks} = $self->follow_symlinks
            if $self->_has_follow_symlinks;
        $args{directories}     = $self->restart_directory
            if $self->_has_restart_directory;
        $args{sleep_interval}  = $self->restart_delay
            if $self->_has_restart_delay;
        $args{filter} = qr/$self->restart_regex/
            if $self->_has_restart_regex;

        my $restarter = $subclass->new(
            %args,
            start_sub => sub { $self->_run },
            argv      => \$self->ARGV,
        );

        $restarter->run_and_watch;
    }
    else {
        $self->_run;
    }


}

sub _run {
    my ($self) = shift;

    my $app = $self->app;
    Class::MOP::load_class($app);

    $app->run(
        $self->listen, $self->host,
        {
           'fork'            => $self->fork,
           keepalive         => $self->keepalive,
           background        => $self->background,
           pidfile           => $self->pidfile,
           keepalive         => $self->keepalive,
           follow_symlinks   => $self->follow_symlinks,
        }
    );
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

[% appprefix %]_server.pl - Catalyst Testserver

=head1 SYNOPSIS

[% appprefix %]_server.pl [options]

 Options:
   -d     --debug          force debug mode
   -f     --fork           handle each request in a new process
                      (defaults to false)
   -h     --help           display this help and exits
          --host           host (defaults to all)
   -p     --port           port (defaults to 3000)
   -k     --keepalive      enable keep-alive connections
   -r     --restart        restart when files get modified
                       (defaults to false)
   --rd   --restartdelay  delay between file checks
                      (ignored if you have Linux::Inotify2 installed)
   --rr   --restartregex  regex match files that trigger
                      a restart when modified
                      (defaults to '\.yml$|\.yaml$|\.conf|\.pm$')
   --rdir --restartdirectory  the directory to search for
                      modified files, can be set mulitple times
                      (defaults to '[SCRIPT_DIR]/..')
   --sym  --follow_symlinks   follow symlinks in search directories
                      (defaults to false. this is a no-op on Win32)
   --bg   --background        run the process in the background
   --pid  --pidfile           specify filename for pid file

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
