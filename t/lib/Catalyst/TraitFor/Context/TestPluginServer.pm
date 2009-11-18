package Catalyst::TraitFor::Context::TestPluginServer;

use Moose::Role;

# Note: Catalyst::Plugin::Server forces the body to
#       be parsed, by calling the $c->req->body method in prepare_action.
#       We need to test this, as this was broken by 5.80. See also
#       t/aggregate/live_engine_request_body.t.

after prepare_action => sub {
    my $c = shift;
    $c->res->header('X-Have-Request-Body', 1) if $c->req->body;
};

1;
