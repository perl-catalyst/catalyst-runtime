#!/usr/bin/env perl

{
  package MyApp;

  use Catalyst;
  use Test::More;

  eval {
    __PACKAGE__->setup_middleware('DoesNotExist'); 1;
  } || do {
    like($@, qr/MyApp::Middleware::DoesNotExist or Plack::Middleware::DoesNotExist/);
  };

  done_testing;
}
