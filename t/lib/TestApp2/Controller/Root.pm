package TestApp2::Controller::Root;
use strict;
use warnings;
use utf8;

__PACKAGE__->config(namespace => q{});

use base 'Catalyst::Controller';

# your actions replace this one
sub main :Path('') { 
    $_[1]->res->body('<h1>It works</h1>');
    $_[1]->res->content_type('text/html');
}

1;
