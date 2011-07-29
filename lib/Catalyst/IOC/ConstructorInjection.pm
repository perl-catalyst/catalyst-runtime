package Catalyst::IOC::ConstructorInjection;
use Moose;
extends 'Bread::Board::ConstructorInjection';

with 'Bread::Board::Service::WithClass',
     'Bread::Board::Service::WithDependencies',
     'Bread::Board::Service::WithParameters',
     'Catalyst::IOC::Service::WithCOMPONENT',
     'Catalyst::IOC::Service::WithAcceptContext';

# FIXME - how much of this should move to ::WithCOMPONENT?
sub get {
    my $self = shift;

    my $constructor = $self->constructor_name;
    my $component   = $self->class;
    my $params      = $self->params;
    my $config      = $params->{config}->{ $self->param('suffix') } || {};
    my $app_name    = $params->{application_name};

    # Stash catalyst_component_name in the config here, so that custom COMPONENT
    # methods also pass it. local to avoid pointlessly shitting in config
    # for the debug screen, as $component is already the key name.
    local $config->{catalyst_component_name} = $component;

    return $component->$constructor( $app_name, $config );
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
