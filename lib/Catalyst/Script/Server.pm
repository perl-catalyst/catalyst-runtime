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
use Catalyst::Engine::HTTP;
use namespace::clean -except => [ qw(meta) ];

with 'MooseX::Getopt';

has help => ( 
    traits => [qw(Getopt)],
    cmd_aliases => 'h',
    isa => 'Bool',   
    is => 'ro', 
    required => 0, 
    default => 0,  
);

has host => ( 
    isa => 'Str',    
    is => 'ro', 
    required => 0, 
    default =>  "localhost" 
);

has fork => ( 
    traits => [qw(Getopt)],
    cmd_aliases => 'f',
    isa => 'Bool',
    is => 'ro', 
    required => 0 
);

has listen => ( 
    traits => [qw(Getopt)],
    cmd_aliases => 'l',
    isa => 'Int',
    is => 'ro', 
    required => 0, 
    default => "3000" 
);

has pidfile => ( 
    traits => [qw(Getopt)],
    cmd_aliases => 'pid',
    isa => 'Str',    
    is => 'ro', 
    required => 0 
);

has keepalive => ( 
    traits => [qw(Getopt)],
    cmd_aliases => 'k',
    isa => 'Bool',   
    is => 'ro', 
    required => 0, 
    default => 0 
);

has background => ( 
    traits => [qw(Getopt)],
    cmd_aliases => 'bg',
    isa => 'Bool',   
    is => 'ro', 
    required => 0 
);

has app => ( isa => 'Str',    is => 'ro', required => 1 ); # THIS IS FUCKING RETARDED HALP PLZ
has restart => (
    traits => [qw(Getopt)],
    cmd_aliases => 'r', 
    isa => 'Bool',   
    is => 'ro', 
    required => 0 
);

has restart_delay   => ( isa => 'Int',    is => 'ro', required => 0 );
has restart_regex   => ( isa => 'Str',    is => 'ro', required => 0 );
has follow_symlinks => ( isa => 'Bool',   is => 'ro', required => 0 );

my @argv = @ARGV;

sub run {
    my $self = shift;
    
    pod2usage() if $self->help;
    my $app = $self->app;
    Class::MOP::load_class($app);
    $app->run(
        $self->listen, $self->host,
        {  
           'fork'     => $self->fork,
           keepalive  => $self->keepalive,
           background => $self->background,
           pidfile    => $self->pidfile,
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
