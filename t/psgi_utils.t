use warnings;
use strict;

# Make it easier to mount PSGI apps under catalyst

my $psgi_app = sub {
  my $req = Plack::Request->new(shift);
  return [200,[],[$req->path]];
};

{
  package MyApp::Controller::Docs;

  use base 'Catalyst::Controller';
  use Plack::Request;
  use Catalyst::Utils;

  sub name :Local {
    my ($self, $c) = @_;
    my $env = $c->Catalyst::Utils::env_at_action;
    $c->res->from_psgi_response(
      $psgi_app->($env));

  }

  sub name_args :Local Args(1) {
    my ($self, $c, $arg) = @_;
    my $env = $c->Catalyst::Utils::env_at_action;
    $c->res->from_psgi_response(
      $psgi_app->($env));
  }

  package MyApp::Controller::User;

  use base 'Catalyst::Controller';
  use Plack::Request;
  use Catalyst::Utils;

  sub local_example :Local {
    my ($self, $c) = @_;
    my $env = $self->get_env($c);
    $c->res->from_psgi_response(
      $psgi_app->($env));
  }

  sub local_example_args1 :Local Args(1) {
    my ($self, $c) = @_;
    my $env = $self->get_env($c);
    $c->res->from_psgi_response(
      $psgi_app->($env));
  }

  sub path_example :Path('path-example') {
    my ($self, $c) = @_;
    my $env = $self->get_env($c);
    $c->res->from_psgi_response(
      $psgi_app->($env));
  }

  sub path_example_args1 :Path('path-example-args1') {
    my ($self, $c) = @_;
    my $env = $self->get_env($c);
    $c->res->from_psgi_response(
      $psgi_app->($env));
  }

  sub chained :Chained(/) PathPrefix CaptureArgs(0) { }

    sub from_chain :Chained('chained') PathPart('') CaptureArgs(0) {}

      sub end_chain :Chained('from_chain') PathPath(abc-123) Args(1)
      {
        my ($self, $c) = @_;
        my $env = $self->get_env($c);
        $c->res->from_psgi_response(
          $psgi_app->($env));
      }
  
  sub get_env {
    my ($self, $c) = @_;
    if($c->req->query_parameters->{path_prefix}) {
      return $c->Catalyst::Utils::env_at_path_prefix;
    } elsif($c->req->query_parameters->{env_path}) {
      return $c->Catalyst::Utils::env_at_action;
    } elsif($c->req->query_parameters->{path}) {
      return $c->Catalyst::Utils::env_at_request_uri;
    } else {
      return $c->req->env;
    }
  }

  $INC{'MyApp/Controller/User.pm'} = __FILE__;

  package MyApp;
  use Catalyst;
  MyApp->setup;

}

use Test::More;
use Catalyst::Test 'MyApp';

# BEGIN [user/local_example]
{
  my ($res, $c) = ctx_request('/user/local_example');
  is $c->action, 'user/local_example';
  is $res->content, '/user/local_example';
  is_deeply $c->req->args, [];
}

{
  my ($res, $c) = ctx_request('/user/local_example/111/222');
  is $c->action, 'user/local_example';
  is $res->content, '/user/local_example/111/222';
  is_deeply $c->req->args, [111,222];
}

{
  my ($res, $c) = ctx_request('/user/local_example?path_prefix=1');
  is $c->action, 'user/local_example';
  is $res->content, '/local_example';
  is_deeply $c->req->args, [];
}

{
  my ($res, $c) = ctx_request('/user/local_example/111/222?path_prefix=1');
  is $c->action, 'user/local_example';
  is $res->content, '/local_example/111/222';
  is_deeply $c->req->args, [111,222];
}

{
  my ($res, $c) = ctx_request('/user/local_example?env_path=1');
  is $c->action, 'user/local_example';
  is $res->content, '/';
  is_deeply $c->req->args, [];
}

{
  my ($res, $c) = ctx_request('/user/local_example/111/222?env_path=1');
  is $c->action, 'user/local_example';
  is $res->content, '/111/222';
  is_deeply $c->req->args, [111,222];
}

{
  my ($res, $c) = ctx_request('/user/local_example?path=1');
  is $c->action, 'user/local_example';
  is $res->content, '/';
  is_deeply $c->req->args, [];
}

{
  my ($res, $c) = ctx_request('/user/local_example/111/222?path=1');
  is $c->action, 'user/local_example';
  is $res->content, '/';
  is_deeply $c->req->args, [111,222];
}

# END [user/local_example]

# BEGIN [/user/local_example_args1/***/]

{
  my ($res, $c) = ctx_request('/user/local_example_args1/333');
  is $c->action, 'user/local_example_args1';
  is $res->content, '/user/local_example_args1/333';
  is_deeply $c->req->args, [333];
}

{
  my ($res, $c) = ctx_request('/user/local_example_args1/333?path_prefix=1');
  is $c->action, 'user/local_example_args1';
  is $res->content, '/local_example_args1/333';
  is_deeply $c->req->args, [333];
}

{
  my ($res, $c) = ctx_request('/user/local_example_args1/333?env_path=1');
  is $c->action, 'user/local_example_args1';
  is $res->content, '/333';
  is_deeply $c->req->args, [333];
}

{
  my ($res, $c) = ctx_request('/user/local_example_args1/333?path=1');
  is $c->action, 'user/local_example_args1';
  is $res->content, '/';
  is_deeply $c->req->args, [333];
}

# END [/user/local_example_args1/***/]

# BEGIN [/user/path-example] 

{
  my ($res, $c) = ctx_request('/user/path-example');
  is $c->action, 'user/path_example';
  is $res->content, '/user/path-example';
  is_deeply $c->req->args, [];
}

{
  my ($res, $c) = ctx_request('/user/path-example?path_prefix=1');
  is $c->action, 'user/path_example';
  is $res->content, '/path-example';
  is_deeply $c->req->args, [];
}

{
  my ($res, $c) = ctx_request('/user/path-example?env_path=1');
  is $c->action, 'user/path_example';
  is $res->content, '/';
  is_deeply $c->req->args, [];
}

{
  my ($res, $c) = ctx_request('/user/path-example?path=1');
  is $c->action, 'user/path_example';
  is $res->content, '/';
  is_deeply $c->req->args, [];
}


{
  my ($res, $c) = ctx_request('/user/path-example/111/222');
  is $c->action, 'user/path_example';
  is $res->content, '/user/path-example/111/222';
  is_deeply $c->req->args, [111,222];
}

{
  my ($res, $c) = ctx_request('/user/path-example/111/222?path_prefix=1');
  is $c->action, 'user/path_example';
  is $res->content, '/path-example/111/222';
  is_deeply $c->req->args, [111,222];
}

{
  my ($res, $c) = ctx_request('/user/path-example/111/222?env_path=1');
  is $c->action, 'user/path_example';
  is $res->content, '/111/222';
  is_deeply $c->req->args, [111,222];
}

{
  my ($res, $c) = ctx_request('/user/path-example/111/222?path=1');
  is $c->action, 'user/path_example';
  is $res->content, '/';
  is_deeply $c->req->args, [111,222];
}

{
  my ($res, $c) = ctx_request('/user/path-example-args1/333');
  is $c->action, 'user/path_example_args1';
  is $res->content, '/user/path-example-args1/333';
  is_deeply $c->req->args, [333];
}

{
  my ($res, $c) = ctx_request('/user/path-example-args1/333?path_prefix=1');
  is $c->action, 'user/path_example_args1';
  is $res->content, '/path-example-args1/333';
  is_deeply $c->req->args, [333];
}

{
  my ($res, $c) = ctx_request('/user/path-example-args1/333?env_path=1');
  is $c->action, 'user/path_example_args1';
  is $res->content, '/333';
  is_deeply $c->req->args, [333];
}

{
  my ($res, $c) = ctx_request('/user/path-example-args1/333?path=1');
  is $c->action, 'user/path_example_args1';
  is $res->content, '/';
  is_deeply $c->req->args, [333];
}

# Chaining test /user/end_chain/*
#
#

{
  my ($res, $c) = ctx_request('/user/end_chain/444');
  is $c->action, 'user/end_chain';
  is $res->content, '/user/end_chain/444';
  is_deeply $c->req->args, [444];
}

{
  my ($res, $c) = ctx_request('/user/end_chain/444?path_prefix=1');
  is $c->action, 'user/end_chain';
  is $res->content, '/end_chain/444';
  is_deeply $c->req->args, [444];
}

{
  my ($res, $c) = ctx_request('/user/end_chain/444?env_path=1');
  is $c->action, 'user/end_chain';
  is $res->content, '/444';
  is_deeply $c->req->args, [444];
}

{
  my ($res, $c) = ctx_request('/user/end_chain/444?path=1');
  is $c->action, 'user/end_chain';
  is $res->content, '/';
  is_deeply $c->req->args, [444];
}

{
  my ($res, $c) = ctx_request('/docs/name');
  is $c->action, 'docs/name';
  is $res->content, '/';
  is_deeply $c->req->args, [];
}

{
  my ($res, $c) = ctx_request('/docs/name/111/222');
  is $c->action, 'docs/name';
  is $res->content, '/111/222';
  is_deeply $c->req->args, [111,222];
}

{
  my ($res, $c) = ctx_request('/docs/name_args/111');
  is $c->action, 'docs/name_args';
  is $res->content, '/111';
  is_deeply $c->req->args, [111];
}

done_testing();

__END__


use Plack::App::URLMap;
use HTTP::Request::Common;
use HTTP::Message::PSGI;

my $urlmap = Plack::App::URLMap->new;

my $app1 = sub {
  my $env = shift;
  return [200, [], [
    "REQUEST_URI: $env->{REQUEST_URI}, FROM: $env->{MAP_TO}, PATH_INFO: $env->{PATH_INFO}, SCRIPT_NAME $env->{SCRIPT_NAME}"]];
};

$urlmap->map("/" => sub { my $env = shift; $env->{MAP_TO} = '/'; $app1->($env)});
$urlmap->map("/foo" => sub { my $env = shift; $env->{MAP_TO} = '/foo'; $app1->($env)});
$urlmap->map("/bar/baz" => sub { my $env = shift; $env->{MAP_TO} = '/foo/bar'; $app1->($env)});

my $app = $urlmap->to_app;

warn $app->(req_to_psgi(GET '/'))->[2]->[0];
warn $app->(req_to_psgi(GET '/111'))->[2]->[0];
warn $app->(req_to_psgi(GET '/foo'))->[2]->[0];
warn $app->(req_to_psgi(GET '/foo/222'))->[2]->[0];
warn $app->(req_to_psgi(GET '/bar/baz'))->[2]->[0];
warn $app->(req_to_psgi(GET '/bar/baz/333'))->[2]->[0];

