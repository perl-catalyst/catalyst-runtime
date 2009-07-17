package Catalyst::Script::FastCGI;

BEGIN { $ENV{CATALYST_ENGINE} ||= 'FastCGI' }
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use Pod::Usage;
use Moose;
use namespace::autoclean;

with 'MooseX::Getopt';

has help => (
    traits => [qw(Getopt)],
    cmd_aliases => 'h',
    isa => 'Bool',
    is => 'ro',
    documentation => qq{ display this help and exits },
);

has listen => (
    traits => [qw(Getopt)],
    cmd_aliases => 'l',
    isa => 'Int',
    is => 'ro',
    default => "3000",
    documentation => qq{ specify a different listening port }
);

has pidfile => (
    traits => [qw(Getopt)],
    cmd_aliases => 'pid',
    isa => 'Str',
    is => 'ro',
    documentation => qq{ specify a pidfile }
);

has daemon => ( 
    isa => 'Bool',   
    is => 'ro', 
    traits => [qw(Getopt)],
    cmd_aliases => 'd', 
    documentation => qq{ daemonize }
);

has manager => ( 
    isa => 'Str',    
    is => 'ro',
    traits => [qw(Getopt)],
    cmd_aliases => 'm',
    documentation => qq{ use a different FastCGI manager } 
);

has keep_stderr => ( 
    traits => [qw(Getopt)],
    cmd_aliases => 'std', 
    isa => 'Bool',   
    is => 'ro',  
    documentation => qq{ log STDERR }
);

has nproc => (
    traits => [qw(Getopt)],
    cmd_aliases => 'np',  
    isa => 'Int',
    is => 'ro',  
    documentation => qq{ specify an nproc }
);

has detach => ( 
    traits => [qw(Getopt)],
    cmd_aliases => 'det', 
    isa => 'Bool',   
    is => 'ro',  
    documentation => qq{ detach this FastCGI process }
);

has _app => (
    reader   => 'app',
    init_arg => 'app',
    traits => [qw(NoGetopt)],
    isa => 'Str',
    is => 'ro',
);

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
