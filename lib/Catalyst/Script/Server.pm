package Catalyst::Script::Server;


use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use Pod::Usage;
use Moose;
use Catalyst::Engine::HTTP;
use namespace::clean -except => [ qw(meta) ];

with 'MooseX::Getopt';

has help            => ( isa => 'Bool',   is => 'ro', required => 0, default => sub { 0 } );
has host            => ( isa => 'Str',    is => 'ro', required => 0, default => sub { "localhost" } );
has fork            => ( isa => 'Bool',   is => 'ro', required => 0 );
has listen          => ( isa => 'Int',    is => 'ro', required => 0, default => sub{ 3000 } );
has pidfile         => ( isa => 'Str',    is => 'ro', required => 0 );
has keepalive       => ( isa => 'Bool',   is => 'ro', required => 0, default => sub { 0 } );
has background      => ( isa => 'Bool',   is => 'ro', required => 0 );
has app             => ( isa => 'Str',    is => 'ro', required => 1 );
has restart         => ( isa => 'Bool',   is => 'ro', required => 0 );
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
           restart_directory => $self->restart_directory,
           follow_symlinks   => $self->follow_symlinks,
        }  
    );

}


1;
