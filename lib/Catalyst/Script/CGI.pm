package Catalyst::Script::CGI;
use Moose;

BEGIN { $ENV{CATALYST_ENGINE} ||= 'CGI' }
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use Pod::Usage;
use Moose;
use namespace::autoclean;

with 'MooseX::Getopt';

has _app => (
    reader   => 'app',
    init_arg => 'app',
    traits => [qw(NoGetopt)],
    isa => 'Str',
    is => 'ro',
);

has help => (
    traits => [qw(Getopt)],
    cmd_aliases => 'h',
    isa => 'Bool',
    is => 'ro',
    documentation => qq{ display this help and exits },
);


sub run {
    my $self = shift;

    pod2usage() if $self->help;
    my $app = $self->app;
    Class::MOP::load_class($app);
    $app->run;

}
1;
