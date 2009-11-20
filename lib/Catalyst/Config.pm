package Catalyst::Config;
use Moose::Role;
use Class::MOP ();
use Catalyst::Utils ();
use namespace::autoclean;

sub config {
    my $self = shift;
    # Uncomment once sane to do so
    #Carp::cluck("config method called on instance") if ref $self;
    my $config = $self->_config || {};
    if (@_) {
        my $newconfig = { %{@_ > 1 ? {@_} : $_[0]} };
        $self->_config(
            $self->merge_config_hashes( $config, $newconfig )
        );
    } else {
        # this is a bit of a kludge, required to make
        # __PACKAGE__->config->{foo} = 'bar';
        # work in a subclass.
        # TODO maybe this should be a ClassData option?
        my $class = blessed($self) || $self;
        my $meta = Class::MOP::get_metaclass_by_name($class);
        unless ($meta->has_package_symbol('$_config')) {
            # Call merge_hashes to ensure we deep copy the parent
            # config onto the subclass
            $self->_config( Catalyst::Utils::merge_hashes($config, {}) );
        }
    }
    return $self->_config;
}

sub merge_config_hashes {
    my ( $self, $lefthash, $righthash ) = @_;

    return Catalyst::Utils::merge_hashes( $lefthash, $righthash );
}

1;

__END__

=head1 NAME

Catalyst::Config - Catalyst config role

=head1 METHODS

=head2 $app->config

=head2 $app->merge_config_hashes

=head1 SEE ALSO

L<Catalyst>, 

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut


