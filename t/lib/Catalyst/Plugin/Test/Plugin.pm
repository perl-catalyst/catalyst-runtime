package Catalyst::Plugin::Test::Plugin;

use strict;
use warnings;
use MRO::Compat;

use base qw/Catalyst::Controller Class::Data::Inheritable/;

 __PACKAGE__->mk_classdata('ran_setup');

sub setup {
   my $c = shift;
   $c->ran_setup('1');
}

sub prepare {
    my $class = shift;

    my $c = $class->next::method(@_);
    $c->response->header( 'X-Catalyst-Plugin-Setup' => $c->ran_setup );

    return $c;
}

# Note: Catalyst::Plugin::Server forces the body to
#       be parsed, by calling the $c->req->body method in prepare_action.
#       We need to test this, as this was broken by 5.80. See also
#       t/aggregate/live_engine_request_body.t.
sub prepare_action {
    my $c = shift;
    $c->res->header('X-Have-Request-Body', 1) if $c->req->body;
    $c->next::method(@_);
}

1;
