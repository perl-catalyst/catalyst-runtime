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

sub _exit_with_usage {
    my $self = shift;
    pod2usage();
    exit 0;
}

before run => sub {
    my $self = shift;
    $self->_exit_with_usage if $self->help;
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

# GROSS HACK, temporary until MX::Getopt gets some proper refactoring and unfucking..
around '_parse_argv' => sub {
    my ($orig, $self, @args) = @_;
    my %data = eval { $self->$orig(@args) };
    $self->_exit_with_usage($@) if $@;
    $data{usage} = Catalyst::ScriptRole::Useage->new(code => sub { shift; $self->_exit_with_usage(@_) });
    return %data;
};

# This package is going away.
package # Hide from PAUSE
    Catalyst::ScriptRole::Useage;
use Moose;
use namespace::autoclean;

has code => ( is => 'ro', required => 1 );

sub die { shift->code->(@_) }

1;

=head1 NAME

Catalyst::ScriptRole - Common functionality for Catalyst scripts.

=head1 SYNOPSIS

    FIXME
    
=head1 DESCRIPTION

    FIXME    

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
    
