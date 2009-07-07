package Catalyst::Exception::Interface;

use Moose::Role;
use namespace::autoclean;

requires qw/as_string throw rethrow/;

1;
