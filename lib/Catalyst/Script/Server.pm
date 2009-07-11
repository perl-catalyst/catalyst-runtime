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
#use Catalyst::Engine::HTTP;
use namespace::autoclean;

with 'MooseX::Getopt';

has help => ( 
    traits => [qw(Getopt)],
    cmd_aliases => 'h',
    isa => 'Bool',   
    is => 'ro', 
    ,  
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

has restart_delay => ( 
    traits => [qw(Getopt)],
    cmd_aliases => 'rdel',
    isa => 'Int',    
    is => 'ro', 
     
);

has restart_regex => ( 
    traits => [qw(Getopt)],
    cmd_aliases => 'rxp',
    isa => 'Str',    
    is => 'ro', 
     
);

has follow_symlinks => ( 
    traits => [qw(Getopt)],
    cmd_aliases => 'sym',
    isa => 'Bool',   
    is => 'ro', 
     
);

sub usage {
    my ($self) = shift;
    
    return pod2usage();

}

my @argv = @ARGV;

sub run {
    my $self = shift;
    
    $self->usage if $self->help;
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
           restart           => $self->restart,
           restart_delay     => $self->restart_delay,
           restart_regex     => qr/$self->restart_regex/,
# FIXME    restart_directory => $self->restart_directory,
           follow_symlinks   => $self->follow_symlinks,
        }  
    );

}


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
