package TestAppViewWarnings::Controller::Root;
use strict;
use warnings;
use base 'Catalyst::Controller';

__PACKAGE__->config->{namespace} = '';

# Return log messages from previous request
sub index :Path Args() {}

sub end : Action {
    my ($self, $c) = @_;
    $c->view; # Cause view lookup and ergo warning we are testing.
    $c->res->body('foo');
}

1;
