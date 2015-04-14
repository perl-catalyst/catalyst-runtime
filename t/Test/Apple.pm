package t::Test::Apple;

use strict;
use warnings;

use parent qw/Catalyst::Controller/;

sub default :Path {
}

sub apple :Local {
}

1;
