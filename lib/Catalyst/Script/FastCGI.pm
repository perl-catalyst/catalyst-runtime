package Catalyst::Script::FastCGI;

BEGIN { $ENV{CATALYST_ENGINE} ||= 'FastCGI' }
use Moose;
use MooseX::Types::Moose qw/Str Bool Int/;
use namespace::autoclean;

with 'Catalyst::ScriptRole';

has listen => (
    traits => [qw(Getopt)],
    cmd_aliases => 'l',
    isa => Int,
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
    documentation => 'Daemonize',
);

has manager => (
    traits => [qw(Getopt)],
    isa => Str,    
    is => 'ro',
    cmd_aliases => 'm',
    documentation => 'Use a different FastCGI manager', # FIXME
);

has keep_stderr => (
    traits => [qw(Getopt)],
    cmd_aliases => 'std', 
    isa => Bool,   
    is => 'ro',  
    documentation => 'Log STDERR',
);

has nproc => (
    traits => [qw(Getopt)],
    cmd_aliases => 'np',  
    isa => Int,
    is => 'ro',  
    documentation => 'Specify an nproc', # FIXME
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
            keep_stderr => $self->keep_stderr,
        }
    );
}

__PACKAGE__->meta->make_immutable;

=head1 NAME

Catalyst::Script::FastCGI - The FastCGI Catalyst Script

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

FIXME

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
