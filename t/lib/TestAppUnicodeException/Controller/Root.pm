package TestAppUnicodeException::Controller::Root;
use strict;
use warnings;
use utf8;

__PACKAGE__->config(namespace => q{});

use base 'Catalyst::Controller';

sub main :Path('') :Args(1) {
    my ($self, $c) = @_;
    $c->res->body('<h1>OK</h1>');
    $c->res->content_type('text/html');
}

1;
