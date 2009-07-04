package Catalyst::Script::CGI;
use Moose;

BEGIN { $ENV{CATALYST_ENGINE} ||= 'CGI' }
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use Pod::Usage;
use Moose;
use namespace::autoclean -except => [ qw(meta) ];

with 'MooseX::Getopt';

has app  => ( isa => 'Str',    is => 'ro', required => 1 );
has help => ( isa => 'Bool',   is => 'ro', required => 0, default => sub { 0 } );

sub run {
    my $self = shift;
    
    pod2usage() if $self->help;
    my $app = $self->app;
    Class::MOP::load_class($app);
    $app->run;

}
1;
