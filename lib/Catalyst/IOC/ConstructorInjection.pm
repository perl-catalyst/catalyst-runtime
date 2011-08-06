package Catalyst::IOC::ConstructorInjection;
use Moose;
use Catalyst::Utils ();
extends 'Bread::Board::ConstructorInjection';

with 'Bread::Board::Service::WithClass',
     'Bread::Board::Service::WithParameters',
     'Bread::Board::Service::WithDependencies';

has config_key => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

sub _build_config_key { Catalyst::Utils::class2classsuffix( shift->class ) }

sub _build_constructor_name { 'COMPONENT' }

sub get {
    my $self = shift;

    my $constructor = $self->constructor_name;
    my $component   = $self->class;
    my $config      = $self->param('config')->{ $self->config_key } || {};
    # FIXME - Is depending on the application name to pass into constructors here a good idea?
    #         This makes app/ctx split harder I think.. Need to think more here, but I think
    #         we want to pass the application in as a parameter when building the service
    #         rather than depending on the app name, so that later, when the app becomes an instance
    #         then it'll get passed in, and components can stash themselves 'per app instance'
    my $app_name    = $self->param('application_name');

    # Stash catalyst_component_name in the config here, so that custom COMPONENT
    # methods also pass it. local to avoid pointlessly shitting in config
    # for the debug screen, as $component is already the key name.
    local $config->{catalyst_component_name} = $component;

    unless ( $component->can( $constructor ) ) {
        # FIXME - make some deprecation warnings
        return $component;
    }

    my $instance = eval { $component->$constructor( $app_name, $config ) };

    if ( my $error = $@ ) {
        chomp $error;
        Catalyst::Exception->throw(
            message => qq/Couldn't instantiate component "$component", "$error"/
        );
    }
    elsif (!blessed $instance) {
        my $metaclass = Moose::Util::find_meta($component);
        my $method_meta = $metaclass->find_method_by_name($constructor);
        my $component_method_from = $method_meta->associated_metaclass->name;
        my $value = defined($instance) ? $instance : 'undef';
        Catalyst::Exception->throw(
            message =>
            qq/Couldn't instantiate component "$component", $constructor() method (from $component_method_from) didn't return an object-like value (value was $value)./
        );
    }

    return $instance;
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
