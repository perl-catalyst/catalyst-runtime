package TestAppStats::Controller::Root;
use strict;
use warnings;
use base 'Catalyst::Controller';

__PACKAGE__->config->{namespace} = '';

# Return log messages from previous request
sub default : Private {
    my ( $self, $c ) = @_;
    $c->stats->profile("test");
    $c->res->body(join("\n", @TestAppStats::log_messages));
    @TestAppStats::log_messages = ();
}

1;
