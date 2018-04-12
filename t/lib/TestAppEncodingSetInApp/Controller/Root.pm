package TestAppEncodingSetInApp::Controller::Root;
use Moose;
use namespace::clean -except => [ 'meta' ];

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config(namespace => '');

sub default: Local{
    my ( $self, $c ) = @_;

    $c->res->body('');
}

1;
