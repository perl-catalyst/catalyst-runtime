package Catalyst::Script::FastCGI;

BEGIN { $ENV{CATALYST_ENGINE} ||= 'FastCGI' }
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use Pod::Usage;
use Moose;
use namespace::autoclean -except => [ qw(meta) ];

with 'MooseX::Getopt';

has help        => ( isa => 'Bool',   is => 'ro', required => 0, default => sub { 0 } );
has listen      => ( isa => 'Int',    is => 'ro', required => 1 );
has pidfile     => ( isa => 'Str',    is => 'ro', required => 0 );
has daemon      => ( isa => 'Bool',   is => 'ro', required => 0, default => sub { 0 } );
has manager     => ( isa => 'Str',    is => 'ro', required => 0 );
has keep_stderr => ( isa => 'Bool',   is => 'ro', required => 0 );
has nproc       => ( isa => 'Int',    is => 'ro', required => 0 );
has detach      => ( isa => 'Bool',   is => 'ro', required => 0, default => sub { 0 } );
has app         => ( isa => 'Str',    is => 'ro', required => 1 );

sub run {
    my $self = shift;
    
    pod2usage() if $self->help;
    my $app = $self->app;
    Class::MOP::load_class($app);
    $app->run(
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

1;
