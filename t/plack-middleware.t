#!/usr/bin/env perl

use warnings;
use strict;

use FindBin;
use Test::More;
use HTTP::Request::Common;

use lib "$FindBin::Bin/lib";
use Catalyst::Test 'TestMiddleware';

ok my($res, $c) = ctx_request('/');

{
  ok my $response = request GET $c->uri_for_action('/welcome'),
    'got welcome from a catalyst controller';

  is $response->content, 'Welcome to Catalyst',
    'expected content body';
}

{
  ok my $response = request GET $c->uri_for('/static/message.txt'),
    'got welcome from a catalyst controller';

  like $response->content, qr'static message',
    'expected content body';
}

{
  ok my $response = request GET $c->uri_for('/static2/message2.txt'),
    'got welcome from a catalyst controller';

  like $response->content, qr'static message',
    'expected content body';
}

{
  ok my $response = request GET $c->uri_for('/static3/message3.txt'),
    'got welcome from a catalyst controller';

  like $response->content, qr'static message',
    'expected content body';
}

{
  ok my $response = request GET $c->uri_for('/forced'),
    'got welcome from a catalyst controller';

  like $response->content, qr'forced message',
    'expected content body';

  ok $response->headers->{"x-runtime"}, "Got value for expected middleware";
}

{
  my $total_mw = scalar(TestMiddleware->registered_middlewares);

  TestMiddleware->setup_middleware;
  TestMiddleware->setup_middleware;

  my $post_mw = scalar(TestMiddleware->registered_middlewares);

  is $total_mw, $post_mw, 'Calling ->setup_middleware does not re-add default middleware';
}

done_testing;
