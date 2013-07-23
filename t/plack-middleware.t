#!/usr/bin/env perl

use FindBin;
use Test::Most;
use HTTP::Request::Common;

use lib "$FindBin::Bin/lib";
use Catalyst::Test 'TestApp';

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
}
done_testing;
