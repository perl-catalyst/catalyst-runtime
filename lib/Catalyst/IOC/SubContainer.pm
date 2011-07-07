package Catalyst::IOC::SubContainer;
use Bread::Board;
use Moose;
use Catalyst::IOC::BlockInjection;

extends 'Bread::Board::Container';

has disable_regex_fallback => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);

sub get_component {
    my ( $self, $name, @args ) = @_;

    return $self->resolve(
        service    => $name,
        parameters => { accept_context_args => \@args },
    );
}

sub get_component_regexp {
    my ( $self, $name, $c, @args ) = @_;

    return
        if $self->disable_regex_fallback && !ref $name;

    my $query   = ref $name ? $name : qr{$name}i;
    my $appname = $self->parent->name;
    $query      =~ s/^${appname}:://i;
    $query      =~ s/[MVC]|(Model|View|Controller):://i;

    my @result = map {
        $self->get_component( $_, $c, @args )
    } grep { m/$query/ } $self->get_service_list;

    if (!ref $name && $result[0]) {
        $c->log->warn( Carp::shortmess(qq(Found results for "${name}" using regexp fallback)) );
        $c->log->warn( 'Relying on the regexp fallback behavior for component resolution' );
        $c->log->warn( 'is unreliable and unsafe. You have been warned' );
        return $result[0];
    }

    return @result;
}

1;

__END__

=pod

=head1 NAME

Catalyst::IOC::SubContainer - Container for models, controllers and views

=head1 METHODS

=head2 get_component

=head2 get_component_regexp

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
