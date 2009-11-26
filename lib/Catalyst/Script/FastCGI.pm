package Catalyst::Script::FastCGI;

BEGIN { $ENV{CATALYST_ENGINE} ||= 'FastCGI' }
use Moose;
use MooseX::Types::Moose qw/Str Bool Int/;
use namespace::autoclean;

with 'Catalyst::ScriptRole';

has listen => (
    traits => [qw(Getopt)],
    cmd_aliases => 'l',
    isa => Str,
    is => 'ro',
    documentation => 'Specify a listening port/socket',
);

has pidfile => (
    traits => [qw(Getopt)],
    cmd_aliases => 'pid',
    isa => Str,
    is => 'ro',
    documentation => 'Specify a pidfile',
);

has daemon => (
    traits => [qw(Getopt)],
    isa => Bool,
    is => 'ro',
    cmd_aliases => 'd',
    documentation => 'Daemonize (go into the background)',
);

has manager => (
    traits => [qw(Getopt)],
    isa => Str,
    is => 'ro',
    cmd_aliases => 'M',
    documentation => 'Use a different FastCGI process manager class',
);

has keeperr => (
    traits => [qw(Getopt)],
    cmd_aliases => 'e',
    isa => Bool,
    is => 'ro',
    documentation => 'Log STDERR',
);

has nproc => (
    traits => [qw(Getopt)],
    cmd_aliases => 'n',
    isa => Int,
    is => 'ro',
    documentation => 'Specify a number of child processes',
);

has detach => (
    traits => [qw(Getopt)],
    cmd_aliases => 'det',
    isa => Bool,
    is => 'ro',
    documentation => 'Detach this FastCGI process',
);

sub _application_args {
    my ($self) = shift;
    return (
        $self->listen,
        {
            nproc   => $self->nproc,
            pidfile => $self->pidfile,
            manager => $self->manager,
            detach  => $self->detach,
            keep_stderr => $self->keeperr,
        }
    );
}

__PACKAGE__->meta->make_immutable;

=head1 NAME

Catalyst::Script::FastCGI - The FastCGI Catalyst Script

=head1 SYNOPSIS

  myapp_fastcgi.pl [options]

 Options:
   -? -help      display this help and exits
   -l -listen    Socket path to listen on
                 (defaults to standard input)
                 can be HOST:PORT, :PORT or a
                 filesystem path
   -n -nproc     specify number of processes to keep
                 to serve requests (defaults to 1,
                 requires -listen)
   -p -pidfile   specify filename for pid file
                 (requires -listen)
   -d -daemon    daemonize (requires -listen)
   -M -manager   specify alternate process manager
                 (FCGI::ProcManager sub-class)
                 or empty string to disable
   -e -keeperr   send error messages to STDOUT, not
                 to the webserver

=head1 DESCRIPTION

Run a Catalyst application as fastcgi.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
