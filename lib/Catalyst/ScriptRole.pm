package Catalyst::ScriptRole;
use Moose::Role;
use Pod::Usage;
use MooseX::Getopt;
use Catalyst::EngineLoader;
use Moose::Util::TypeConstraints;
use Catalyst::Utils;
use namespace::autoclean;

subtype 'Catalyst::ScriptRole::LoadableClass',
  as 'ClassName';
coerce 'Catalyst::ScriptRole::LoadableClass',
  from 'Str',
  via { Catalyst::Utils::ensure_class_loaded($_); $_ };

with 'MooseX::Getopt' => {
    -version => 0.48,
    -excludes => [qw/
        _getopt_spec_warnings
        _getopt_spec_exception
        print_usage_text
    /],
};

has application_name => (
    traits   => ['NoGetopt'],
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);

has loader_class => (
    isa => 'Catalyst::ScriptRole::LoadableClass',
    is => 'ro',
    coerce => 1,
    default => 'Catalyst::EngineLoader',
    documentation => 'The class to use to detect and load the PSGI engine',
);

has _loader => (
    isa => 'Plack::Loader',
    default => sub {
        my $self = shift;
        $self->loader_class->new(application_name => $self->application_name);
    },
    handles => {
        load_engine => 'load',
        autoload_engine => 'auto',
    },
    lazy => 1,
);

sub _getopt_spec_exception {}

sub _getopt_spec_warnings {
    shift;
    warn @_;
}

sub print_usage_text {
    my $self = shift;
    pod2usage();
    exit 0;
}

sub run {
    my $self = shift;
    $self->_run_application;
}

sub _application_args {
    my $self = shift;
    return {
        argv => $self->ARGV,
        extra_argv => $self->extra_argv,
    }
}

sub _plack_loader_args {
    my $self = shift;
    my @app_args = $self->_application_args;
    return (port => $app_args[0]);
}

sub _plack_engine_name {}

sub _run_application {
    my $self = shift;
    my $app = $self->application_name;
    Catalyst::Utils::ensure_class_loaded($app);
    my $server;
    if (my $e = $self->_plack_engine_name ) {
        $server = $self->load_engine($e, $self->_plack_loader_args);
    }
    else {
        $server = $self->autoload_engine($self->_plack_loader_args);
    }
    $app->run($self->_application_args, $server);
}

1;

=head1 NAME

Catalyst::ScriptRole - Common functionality for Catalyst scripts.

=head1 SYNOPSIS

    package MyApp::Script::Foo;
    use Moose;
    use namespace::autoclean;

    with 'Catalyst::ScriptRole';

    sub _application_args { ... }

=head1 DESCRIPTION

Role with the common functionality of Catalyst scripts.

=head1 METHODS

=head2 run

The method invoked to run the application.

=head2 print_usage_text

Prints out the usage text for the script you tried to invoke.

=head1 ATTRIBUTES

=head2 application_name

The name of the application class, e.g. MyApp

=head1 SEE ALSO

L<Catalyst>

L<MooseX::Getopt>

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
