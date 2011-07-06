package Catalyst::SubContainer;
use Bread::Board;
use Moose;
use Catalyst::BlockInjection;

extends 'Bread::Board::Container';

sub get_component {
    my ( $self, $name, $args ) = @_;
    return $self->resolve( service => $name, parameters => { context => $args } );
}

sub get_component_regexp {
    my ( $self, $c, $name, $args ) = @_;

    return
        if $c->config->{disable_component_resolution_regex_fallback} && !ref $name;

    my $appclass = ref $c || $c;
    my $prefix   = ucfirst $self->name;
    my $p        = substr $prefix, 0, 1;

    my $query = ref $name ? $name : qr{$name}i;
    $query =~ s/^${appclass}::($p|$prefix):://i;

    my @comps  = $self->get_service_list;
    my @result = map {
        $self->resolve( service => $_, parameters => { context => $args } )
    } grep { m/$query/ } @comps;

    if (!ref $name && $result[0]) {
        $c->log->warn( Carp::shortmess(qq(Found results for "${name}" using regexp fallback)) );
        $c->log->warn( 'Relying on the regexp fallback behavior for component resolution' );
        $c->log->warn( 'is unreliable and unsafe. You have been warned' );
        return $result[0];
    }

    return @result;
}

1;
