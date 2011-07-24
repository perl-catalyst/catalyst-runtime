package Catalyst::Script::FastCGI;
use Moose;
use MooseX::Types::Moose qw/Str Bool Int/;
use Data::OptList;
use namespace::autoclean;

sub _plack_engine_name { 'FCGI' }

with 'Catalyst::ScriptRole';

has listen => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'l',
    isa           => Str,
    is            => 'ro',
    documentation => 'Specify a listening port/socket',
);

has pidfile => (
    traits        => [qw(Getopt)],
    cmd_aliases   => [qw/pid p/],
    isa           => Str,
    is            => 'ro',
    documentation => 'Specify a pidfile',
);

has daemon => (
    traits        => [qw(Getopt)],
    isa           => Bool,
    is            => 'ro',
    cmd_aliases   => [qw/d detach/], # Eww, detach is here as we fucked it up.. Deliberately not documented
    documentation => 'Daemonize (go into the background)',
);

has manager => (
    traits        => [qw(Getopt)],
    isa           => Str,
    is            => 'ro',
    cmd_aliases   => 'M',
    documentation => 'Use a different FastCGI process manager class',
);

has keeperr => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'e',
    isa           => Bool,
    is            => 'ro',
    documentation => 'Log STDERR',
);

has nproc => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'n',
    isa           => Int,
    is            => 'ro',
    documentation => 'Specify a number of child processes',
);

has proc_title => (
    traits        => [qw(Getopt)],
    isa           => Str,
    is            => 'ro',
    lazy          => 1,
    builder       => '_build_proc_title',
    documentation => 'Set the process title',
);

sub _build_proc_title {
    my ($self) = @_;
    return sprintf 'perl-fcgi-pm [%s]', $self->application_name;
}

sub BUILD {
    my ($self) = @_;
    $self->proc_title;
}

# Munge the 'listen' arg so that Plack::Handler::FCGI will accept it.
sub _listen {
    my ($self) = @_;

    if (defined (my $listen = $self->listen)) {
        return [ $listen ];
    } else {
        return undef;
    }
}

sub _plack_loader_args {
    my ($self) = shift;

    my $opts = Data::OptList::mkopt([
      qw/manager nproc proc_title/,
            pid             => [ 'pidfile' ],
            daemonize       => [ 'daemon' ],
            keep_stderr     => [ 'keeperr' ],
            listen          => [ '_listen' ],
        ]);

    my %args = map { $_->[0] => $self->${ \($_->[1] ? $_->[1]->[0] : $_->[0]) } } @$opts;

    # Plack::Handler::FCGI thinks manager => undef means "use no manager".
    delete $args{'manager'} unless defined $args{'manager'};

    return %args;
}

around _application_args => sub {
    my ($orig, $self) = @_;
    return (
        $self->listen,
        {
            %{ $self->$orig },
            nproc       => $self->nproc,
            pidfile     => $self->pidfile,
            manager     => $self->manager,
            detach      => $self->daemon,
            keep_stderr => $self->keeperr,
            proc_title  => $self->proc_title,
        }
    );
};

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Catalyst::Script::FastCGI - The FastCGI Catalyst Script

=head1 SYNOPSIS

  myapp_fastcgi.pl [options]

 Options:
   -? --help       display this help and exits
   -l --listen     Socket path to listen on
                   (defaults to standard input)
                   can be HOST:PORT, :PORT or a
                   filesystem path
   -n --nproc      specify number of processes to keep
                   to serve requests (defaults to 1,
                   requires -listen)
   -p --pidfile    specify filename for pid file
                   (requires -listen)
   -d --daemon     daemonize (requires -listen)
   -M --manager    specify alternate process manager
                   (FCGI::ProcManager sub-class)
                   or empty string to disable
   -e --keeperr    send error messages to STDOUT, not
                   to the webserver
      --proc_title set the process title

=head1 DESCRIPTION

Run a Catalyst application as fastcgi.

=head1 SEE ALSO

L<Catalyst::ScriptRunner>

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
