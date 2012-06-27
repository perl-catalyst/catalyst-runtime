package TestApp::ActionRole::Boo;

use Moose::Role;

has boo => (
    is       => 'ro',
    required => 1,
);

around execute => sub {
    my ($orig, $self, $controller, $ctx, @rest) = @_;
    $ctx->stash(action_boo => $self->boo);
    return $self->$orig($controller, $ctx, @rest);
};

1;
