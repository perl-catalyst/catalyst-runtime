package Catalyst::Script::Server;
use Moose;
use MooseX::Types::Common::Numeric qw/PositiveInt/;
use MooseX::Types::Moose qw/ArrayRef Str Bool Int RegexpRef/;
use Catalyst::Utils;
use namespace::autoclean;

sub _plack_engine_name { 'Standalone' }

with 'Catalyst::ScriptRole';

__PACKAGE__->meta->get_attribute('help')->cmd_aliases('?');

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

has pidfile => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'pid',
    isa           => Str,
    is            => 'ro',
    documentation => 'Specify a pidfile',
);

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

    my $tc = subtype as RegexpRef;
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

sub _restarter_args {
    my $self = shift;

    return (
        argv => $self->ARGV,
        start_sub => sub { $self->_run_application },
        ($self->_has_follow_symlinks   ? (follow_symlinks => $self->follow_symlinks)   : ()),
        ($self->_has_restart_delay     ? (sleep_interval  => $self->restart_delay)     : ()),
        ($self->_has_restart_directory ? (directories     => $self->restart_directory) : ()),
        ($self->_has_restart_regex     ? (filter          => $self->restart_regex)     : ()),
    );
}

sub run {
    my $self = shift;

    local $ENV{CATALYST_DEBUG} = 1
        if $self->debug;

    if ( $self->restart ) {
        die "Cannot run in the background and also watch for changed files.\n"
            if $self->background;

        # If we load this here, then in the case of a restarter, it does not
        # need to be reloaded for each restart.
        require Catalyst;

        # If this isn't done, then the Catalyst::Devel tests for the restarter
        # fail.
        $| = 1 if $ENV{HARNESS_ACTIVE};

        require Catalyst::Restarter;

        my $subclass = Catalyst::Restarter->pick_subclass;

        my $restarter = $subclass->new(
            $self->_restarter_args()
        );

        $restarter->run_and_watch;
    }
    else {
        $self->_run_application;
    }


}

sub _application_args {
    my ($self) = shift;
    return (
        $self->port,
        $self->host,
        {
           map { $_ => $self->$_ } qw/
                fork
                keepalive
                background
                pidfile
                keepalive
                follow_symlinks
            /,
        },
    );
}

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

Run a Catalyst test server for this application.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
