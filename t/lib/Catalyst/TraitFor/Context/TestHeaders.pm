package Catalyst::TraitFor::Context::TestHeaders;

use Moose::Role;

after prepare_action => sub{
    my $c = shift;
    $c->res->header( 'X-Catalyst-Action' => $c->req->action );
};

1;

