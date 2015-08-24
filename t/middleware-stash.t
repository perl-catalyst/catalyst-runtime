use warnings;
use strict;

{

  package MyMiddleware;
  $INC{'MyMiddleware'} = __FILE__;

  our $INNER_VAR_EXPOSED;

  use base 'Plack::Middleware';

  sub call {
    my ($self, $env) = @_;

    my $res = $self->app->($env);

    return $self->response_cb($res, sub{
      my $inner = shift;

      $INNER_VAR_EXPOSED = $env->{inner_var_from_catalyst};

      return;
    });

  }

  package MyAppChild::Controller::User;
  $INC{'MyAppChild/Controller/User.pm'} = __FILE__;

  use base 'Catalyst::Controller';
  use Test::More;

  sub stash :Local {
    my ($self, $c) = @_;
    $c->stash->{inner} = "inner";
    $c->res->body( "inner: ${\$c->stash->{inner}}, outer: ${\$c->stash->{outer}}");

    $c->req->env->{inner_var_from_catalyst} = 'station';

    is_deeply [sort {$a cmp $b} keys(%{$c->stash})], ['inner','outer'], 'both keys in stash';
  }

  package MyAppChild;
  $INC{'MyAppChild.pm'} = __FILE__;

  use Catalyst;
  MyAppChild->setup;

  package MyAppParent::Controller::User;
  $INC{'MyAppParent/Controller/User.pm'} = __FILE__;

  use base 'Catalyst::Controller';
  use Test::More;

  sub stash :Local {
    my ($self, $c) = @_;
    $c->stash->{outer} = "outer";
    $c->res->from_psgi_response( MyAppChild->to_app->($c->req->env) );

    is_deeply [sort keys(%{$c->stash})], ['inner','outer'];
  }

  package MyAppParent;
  use Catalyst;
  MyAppParent->config(psgi_middleware=>['+MyMiddleware']);
  MyAppParent->setup;

}

use Test::More;
use Catalyst::Test 'MyAppParent';

my $res = request '/user/stash';
is $res->content, 'inner: inner, outer: outer', 'got expected response';
is $MyMiddleware::INNER_VAR_EXPOSED, 'station', 'env does not get trampled';

done_testing;
