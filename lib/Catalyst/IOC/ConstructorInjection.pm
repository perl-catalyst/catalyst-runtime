package Catalyst::IOC::ConstructorInjection;
use Moose;
extends 'Bread::Board::ConstructorInjection';

with 'Catalyst::IOC::Service::WithAcceptContext';

sub _build_constructor_name { 'COMPONENT' }

sub get {
    my $self = shift;

    my $constructor = $self->constructor_name;
    my $config      = $self->param('config')->{ $self->params->{suffix} } || {};
    my $class       = $self->param('class');
    my $component   = $self->class;

    unless ( $self->class->can( $constructor ) ) {
        # FIXME - make some deprecation warnings
        return $component;
    }

    # Stash catalyst_component_name in the config here, so that custom COMPONENT
    # methods also pass it. local to avoid pointlessly shitting in config
    # for the debug screen, as $component is already the key name.
    local $config->{catalyst_component_name} = $self->class;

    my $instance = eval { $component->$constructor( $class, $config ) };

    if ( my $error = $@ ) {
        chomp $error;
        Catalyst::Exception->throw(
            message => qq/Couldn't instantiate component "$component", "$error"/
        );
    }
    elsif (!blessed $instance) {
        my $metaclass = Moose::Util::find_meta($component);
        my $method_meta = $metaclass->find_method_by_name('COMPONENT');
        my $component_method_from = $method_meta->associated_metaclass->name;
        my $value = defined($instance) ? $instance : 'undef';
        Catalyst::Exception->throw(
            message =>
            qq/Couldn't instantiate component "$component", COMPONENT() method (from $component_method_from) didn't return an object-like value (value was $value)./
        );
    }

    return $instance;
}

__PACKAGE__->meta->make_immutable;

no Moose; 1;

__END__

=pod

=head1 NAME

Catalyst::IOC::BlockInjection

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
