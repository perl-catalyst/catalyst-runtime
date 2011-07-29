package Catalyst::IOC::Service::WithCOMPONENT;
use Moose::Role;

with 'Bread::Board::Service';

# FIXME - just till I understand how it's supposed to be done
# Made this so that COMPONENT is executed once,
# and ACCEPT_CONTEXT every call.
has instance => (
    is => 'rw',
    required => 0,
);

sub _build_constructor_name { 'COMPONENT' }

around 'get' => sub {
    my ( $orig, $self ) = @_;

    my $constructor = $self->constructor_name;
    my $component   = $self->class;

    unless ( $component->can( $constructor ) ) {
        # FIXME - make some deprecation warnings
        return $component;
    }

    if ($self->instance) {
        return $self->instance;
    }

    my $instance = eval { $self->$orig() };

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

    $self->instance($instance);

    return $instance;
};

no Moose::Role;
1;

__END__

=pod

=head1 NAME

Catalyst::Service::WithCOMPONENT

=head1 DESCRIPTION

=head1 METHODS

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
