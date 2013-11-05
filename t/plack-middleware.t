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

done_testing;
