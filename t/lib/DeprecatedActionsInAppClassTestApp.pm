package DeprecatedActionsInAppClassTestApp;

use strict;
use warnings;
use Catalyst;

__PACKAGE__->setup;

sub foo : Local {
    my ($self, $c) = @_;
    $c->res->body('OK');
}

1;
