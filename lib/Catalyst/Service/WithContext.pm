package Catalyst::Service::WithContext;
use Moose::Role;

use Bread::Board::Types;

with 'Bread::Board::Service';

has accept_context_sub => (
    is => 'ro',
    isa => 'Str',
    default => 'ACCEPT_CONTEXT',
);

around 'get' => sub {
    my ( $orig, $self, @params ) = @_;

    my $instance = $self->$orig();
    my $ac_sub   = $self->accept_context_sub;

    if ( $instance->can($ac_sub) ) {
        return $instance->$ac_sub( @params );
    }

    return $instance;
};

no Moose::Role;
1;
