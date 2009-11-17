package Catalyst::Exception::Interface;

use MooseX::Role::WithOverloading;
use namespace::clean -except => 'meta';

use overload
    q{""}    => sub { $_[0]->as_string },
    fallback => 1;

requires qw/as_string throw rethrow/;

1;
