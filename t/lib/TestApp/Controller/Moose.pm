package TestApp::Controller::Moose;

use Moose;

use namespace::clean -except => 'meta';

BEGIN { extends qw/Catalyst::Controller/; }

has attribute => (
    is      => 'ro',
    default => 42,
);

sub get_attribute : Local {
    my ($self, $c) = @_;
    $c->response->body($self->attribute);
}

1;
