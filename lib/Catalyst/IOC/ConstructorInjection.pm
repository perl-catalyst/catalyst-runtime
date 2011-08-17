package Catalyst::IOC::ConstructorInjection;
use Moose;
use Bread::Board::Dependency;
use Try::Tiny;
use Catalyst::Utils ();

extends 'Bread::Board::ConstructorInjection';

sub BUILD {
    my $self = shift;
    $self->add_dependency(__catalyst_config => Bread::Board::Dependency->new(service_path => '/config'));
    warn("Added dependency for config in " . $self->class);
}

has catalyst_component_name => (
    is => 'ro',
);

has config => (
    init_arg   => undef,
    is         => 'ro',
    isa        => 'HashRef',
    writer     => '_set_config',
    clearer    => '_clear_config',
);

around resolve_dependencies => sub {
    my ($orig, $self, @args) = @_;
    my %deps = $self->$orig(@args);
#    use Data::Dumper;
#        warn("$self Resolve deps" . Data::Dumper::Dumper(\%deps));
    my $app_config = delete $deps{__catalyst_config};
    my $conf_key = Catalyst::Utils::class2classsuffix($self->catalyst_component_name);
    $self->_set_config($app_config->{$conf_key} || {});
    return %deps;
};

sub get {
    my $self = shift;
    warn("In get $self");
    my $component   = $self->class;

    my $params = $self->params;
    my %config = (%{ $self->config }, %{ $params });
#    warn(Data::Dumper::Dumper(\%config));
    $self->_clear_config;

    # FIXME - Is depending on the application name to pass into constructors here a good idea?
    #         This makes app/ctx split harder I think.. Need to think more here, but I think
    #         we want to pass the application in as a parameter when building the service
    #         rather than depending on the app name, so that later, when the app becomes an instance
    #         then it'll get passed in, and components can stash themselves 'per app instance'
    my $app_name    = $self->param('application_name');

    # Stash catalyst_component_name in the config here, so that custom COMPONENT
    # methods also pass it.
    $config{catalyst_component_name} = $self->catalyst_component_name;

    unless ( $component->can( 'COMPONENT' ) ) {
        # FIXME - make some deprecation warnings
        return $component;
    }

    my $instance;
    try {
        $instance = $component->COMPONENT( $app_name, \%config );
    }
    catch {
        Catalyst::Exception->throw(
            message => qq/Couldn't instantiate component "$component", "$_"/
        );
    };

    return $instance
        if blessed $instance;

    my $metaclass = Moose::Util::find_meta($component);
    my $method_meta = $metaclass->find_method_by_name('COMPONENT');
    my $component_method_from = $method_meta->associated_metaclass->name;
    my $value = defined($instance) ? $instance : 'undef';
    Catalyst::Exception->throw(
        message =>
        qq/Couldn't instantiate component "$component", COMPONENT method (from $component_method_from) didn't return an object-like value (value was $value)./
    );
}

__PACKAGE__->meta->make_immutable;

no Moose; 1;

__END__

=pod

=head1 NAME

Catalyst::IOC::ConstructorInjection

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
