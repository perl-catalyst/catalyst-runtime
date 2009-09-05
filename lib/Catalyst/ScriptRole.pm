package Catalyst::ScriptRole;
use Moose::Role;
use MooseX::Types::Moose qw/Str Bool/;
use Pod::Usage;
use namespace::autoclean;

with 'MooseX::Getopt';

has application_name => (
    traits => ['NoGetopt'],
    isa => Str,
    is => 'ro',
    required => 1,
);

has help => (
    traits => ['Getopt'],
    cmd_aliases => 'h',
    isa => Bool,
    is => 'ro',
    documentation => q{Display this help and exit},
);

sub _display_help {
    my $self = shift;
    pod2usage();
    exit 0;
}

before run => sub {
    my $self = shift;
    $self->_display_help if $self->help;
};

sub run {
    my $self = shift;
    $self->_run_application;
}

sub _application_args {
    ()
}

sub _run_application {
    my $self = shift;
    my $app = $self->application_name;
    Class::MOP::load_class($app);
    $app->run($self->_application_args);
}

1;
