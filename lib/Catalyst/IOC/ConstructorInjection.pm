package Catalyst::IOC::ConstructorInjection;
use Moose;
use Bread::Board::Dependency;
use Try::Tiny;
use Catalyst::Utils ();

extends 'Bread::Board::ConstructorInjection';

sub BUILD {
    my $self = shift;
    $self->add_dependency(
        __catalyst_config => Bread::Board::Dependency->new(
            service_path => '/config'
        )
    );
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
    my $app_config = delete $deps{__catalyst_config};
    my $conf_key = Catalyst::Utils::class2classsuffix($self->catalyst_component_name);
    $self->_set_config($app_config->{$conf_key} || {});
    return %deps;
};

sub get {
    my $self = shift;
    my $component   = $self->class;

    my $params = $self->params;
    my %config = (%{ $self->config || {} }, %{ $params });
    $self->_clear_config;

    my $app_name = $self->param('application');

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
