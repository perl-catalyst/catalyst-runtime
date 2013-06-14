package TestAppEncodingSetInConfig::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config(namespace => '');

sub default: Local{
    my ( $self, $c ) = @_;

    $c->res->body('');
}

1;
