package Catalyst::Action::TestBefore;

use strict;
use warnings;

use base qw/Catalyst::Action/;

sub execute {
    my $self = shift;
    my ( $controller, $c ) = @_;
    $c->stash->{test} = 'works';
    $self->NEXT::execute( @_ );
}

1;
