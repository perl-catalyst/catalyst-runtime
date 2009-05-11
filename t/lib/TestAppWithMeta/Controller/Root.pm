package TestAppWithMeta::Controller::Root;
use Moose;
use namespace::clean -except => 'meta';

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config( namespace => '' );

no warnings 'redefine';
sub meta { 'fnar' }
use warnings 'redefine';

sub default : Private {
    my ($self, $c) = @_;
    $c->res->body($self->meta);
}

1;

