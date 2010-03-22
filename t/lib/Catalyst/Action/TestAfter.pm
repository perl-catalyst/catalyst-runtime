package Catalyst::Action::TestAfter;

use strict;
use warnings;

use base qw/Catalyst::Action/; # N.B. Keep as a non-moose class, this also
                               # tests metaclass initialization works as expected

sub execute {
    my $self = shift;
    my ( $controller, $c ) = @_;
    $self->next::method( @_ );
    $c->res->header( 'X-Action-After', $c->stash->{after_message} );
}

1;
