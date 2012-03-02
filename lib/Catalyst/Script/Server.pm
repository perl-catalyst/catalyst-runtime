package Catalyst::Script::Server;
use Moose;
use MooseX::Types::Common::Numeric qw/PositiveInt/;
use MooseX::Types::Moose qw/ArrayRef Str Bool Int RegexpRef/;
use Catalyst::Utils;
use Try::Tiny;
use namespace::autoclean;

with 'Catalyst::ScriptRole';

has debug => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'd',
    isa           => Bool,
    is            => 'ro',
    documentation => q{Force debug mode},
);

has host => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'h',
    isa           => Str,
    is            => 'ro',
    # N.B. undef (the default) means we bind on all interfaces on the host.
    documentation => 'Specify a hostname or IP on this host for the server to bind to',
);

has fork => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'f',
    isa           => Bool,
    is            => 'ro',
    default       => 0,
    documentation => 'Fork the server to be able to serve multiple requests at once',
);

has port => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'p',
    isa           => PositiveInt,
    is            => 'ro',
    default       => sub {
        Catalyst::Utils::env_value(shift->application_name, 'port') || 3000
    },
    documentation => 'Specify a different listening port (to the default port 3000)',
);

use Moose::Util::TypeConstraints;
class_type 'MooseX::Daemonize::Pid::File';
subtype 'Catalyst::Script::Server::Types::Pidfile',
    as 'MooseX::Daemonize::Pid::File';

coerce 'Catalyst::Script::Server::Types::Pidfile', from Str, via {
    try { Class::MOP::load_class("MooseX::Daemonize::Pid::File") }
    catch {
        warn("Could not load MooseX::Daemonize::Pid::File, needed for --pid option\n");
        exit 1;
    };
    MooseX::Daemonize::Pid::File->new( file => $_ );
};
MooseX::Getopt::OptionTypeMap->add_option_type_to_map(
    'Catalyst::Script::Server::Types::Pidfile' => '=s',
);
has pidfile => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'pid',
    isa           => 'Catalyst::Script::Server::Types::Pidfile',
    is            => 'ro',
    documentation => 'Specify a pidfile',
    coerce        => 1,
    predicate     => '_has_pidfile',
);

# Override MooseX::Daemonize
sub dont_close_all_files { 1 }
sub BUILD {
    my $self = shift;

    if ($self->background) {
        # FIXME - This is evil. Should we just add MX::Daemonize to the deps?
        try { Class::MOP::load_class('MooseX::Daemonize::Core'); Class::MOP::load_class('POSIX') }
        catch {
            warn("MooseX::Daemonize is needed for the --background option\n");
            exit 1;
        };
        MooseX::Daemonize::Core->meta->apply($self);
        POSIX::close($_) foreach (0..2);
    }
}

has keepalive => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'k',
    isa           => Bool,
    is            => 'ro',
    default       => 0,
    documentation => 'Support keepalive',
);

has background => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'bg',
    isa           => Bool,
    is            => 'ro',
    default       => 0,
    documentation => 'Run in the background',
);

has restart => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'r',
    isa           => Bool,
    is            => 'ro',
    default       => sub {
        Catalyst::Utils::env_value(shift->application_name, 'reload') || 0;
    },
    documentation => 'use Catalyst::Restarter to detect code changes and restart the application',
);

has restart_directory => (
    traits        => [qw(Getopt)],
    cmd_aliases   => [ 'rdir', 'restartdirectory' ],
    isa           => ArrayRef[Str],
    is            => 'ro',
    documentation => 'Restarter directory to watch',
    predicate     => '_has_restart_directory',
);

has restart_delay => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'rd',
    isa           => Int,
    is            => 'ro',
    documentation => 'Set a restart delay',
    predicate     => '_has_restart_delay',
);

{
    use Moose::Util::TypeConstraints;

    my $tc = subtype 'Catalyst::Script::Server::Types::RegexpRef', as RegexpRef;
    coerce $tc, from Str, via { qr/$_/ };

    MooseX::Getopt::OptionTypeMap->add_option_type_to_map($tc => '=s');

    has restart_regex => (
        traits        => [qw(Getopt)],
        cmd_aliases   => 'rr',
        isa           => $tc,
        coerce        => 1,
        is            => 'ro',
        documentation => 'Restart regex',
        predicate     => '_has_restart_regex',
    );
}

has follow_symlinks => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'sym',
    isa           => Bool,
    is            => 'ro',
    default       => 0,
    documentation => 'Follow symbolic links',
    predicate     => '_has_follow_symlinks',
);

sub _plack_engine_name {
    my $self = shift;
    return $self->fork || $self->keepalive ? 'Starman' : 'Standalone';
}

sub _restarter_args {
    my $self = shift;

    return (
        argv => $self->ARGV,
        start_sub => sub { $self->_run_application },
        ($self->_has_follow_symlinks   ? (follow_symlinks => $self->follow_symlinks)   : ()),
        ($self->_has_restart_delay     ? (sleep_interval  => $self->restart_delay)     : ()),
        ($self->_has_restart_directory ? (directories     => $self->restart_directory) : ()),
        ($self->_has_restart_regex     ? (filter          => $self->restart_regex)     : ()),
    ),
    (
        map { $_ => $self->$_ } qw(application_name host port debug pidfile fork background keepalive)
    );
}

has restarter_class => (
    is => 'ro',
    isa => Str,
    lazy => 1,
    default => sub {
        my $self = shift;
        Catalyst::Utils::env_value($self->application_name, 'RESTARTER') || 'Catalyst::Restarter';
    }
);

sub run {
    my $self = shift;

    local $ENV{CATALYST_DEBUG} = 1
        if $self->debug;

    if ( $self->restart ) {
        die "Cannot run in the background and also watch for changed files.\n"
            if $self->background;
        die "Cannot write out a pid file and fork for the restarter.\n"
            if $self->_has_pidfile;

        # If we load this here, then in the case of a restarter, it does not
        # need to be reloaded for each restart.
        require Catalyst;

        # If this isn't done, then the Catalyst::Devel tests for the restarter
        # fail.
        $| = 1 if $ENV{HARNESS_ACTIVE};

        Catalyst::Utils::ensure_class_loaded($self->restarter_class);

        my $subclass = $self->restarter_class->pick_subclass;

        my $restarter = $subclass->new(
            $self->_restarter_args()
        );

        $restarter->run_and_watch;
    }
    else {
        if ($self->background) {
            $self->daemon_fork;

            return 1 unless $self->is_daemon;

            Class::MOP::load_class($self->application_name);

            $self->daemon_detach;
        }

        $self->pidfile->write
            if $self->_has_pidfile;

        $self->_run_application;
    }


}

sub _plack_loader_args {
    my ($self) = shift;
    return (
        port => $self->port,
        host => $self->host,
        keepalive => $self->keepalive ? 100 : 1,
        server_ready => sub {
            my ($args) = @_;

            my $name  = $args->{server_software} || ref($args); # $args is $server
            my $host  = $args->{host} || 0;
            my $proto = $args->{proto} || 'http';

            print STDERR "$name: Accepting connections at $proto://$host:$args->{port}/\n";
        },
    );
}

around _application_args => sub {
    my ($orig, $self) = @_;
    return (
        $self->port,
        $self->host,
        {
           %{ $self->$orig },
           map { $_ => $self->$_ } qw/
                fork
                keepalive
                background
                pidfile
                keepalive
                follow_symlinks
                port
                host
            /,
        },
    );
};

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Catalyst::Script::Server - Catalyst test server

=head1 SYNOPSIS

 myapp_server.pl [options]

 Options:
   -d     --debug          force debug mode
   -f     --fork           handle each request in a new process
                      (defaults to false)
          --help           display this help and exits
   -h     --host           host (defaults to all)
   -p     --port           port (defaults to 3000)
   -k     --keepalive      enable keep-alive connections
   -r     --restart        restart when files get modified
                       (defaults to false)
   --rd   --restart_delay  delay between file checks
                      (ignored if you have Linux::Inotify2 installed)
   --rr   --restart_regex  regex match files that trigger
                      a restart when modified
                      (defaults to '\.yml$|\.yaml$|\.conf|\.pm$')
   --rdir --restart_directory  the directory to search for
                      modified files, can be set multiple times
                      (defaults to '[SCRIPT_DIR]/..')
   --sym  --follow_symlinks   follow symlinks in search directories
                      (defaults to false. this is a no-op on Win32)
   --bg   --background        run the process in the background
   --pid  --pidfile           specify filename for pid file

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst test server for this application.

=head1 SEE ALSO

L<Catalyst::ScriptRunner>

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
