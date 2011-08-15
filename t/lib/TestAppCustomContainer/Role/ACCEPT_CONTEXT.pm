package TestAppCustomContainer::Role::ACCEPT_CONTEXT;
use Moose::Role;
use namespace::autoclean;

has accept_context_called => (
    traits  => ['Counter'],
    isa     => 'Int',
    is      => 'ro',
    default => 0,
    handles => {
        inc_accept_context_called => 'inc',
    },
);

sub ACCEPT_CONTEXT {}

around ACCEPT_CONTEXT => sub {
    my ( $orig, $self, $ctx, @args ) = @_;

    $self->inc_accept_context_called;

    return $self->$orig() || $self;
};

1;
