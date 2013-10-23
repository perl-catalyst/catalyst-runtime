#!/usr/bin/env perl

use warnings;
use strict;

use FindBin;
use Test::More;
use HTTP::Request::Common;

use lib "$FindBin::Bin/lib";
use Catalyst::Test 'TestFromPSGI';

{
  ok my $response = request GET '/from_psgi_array',
    'got welcome from a catalyst controller';

  is $response->content, 'helloworldtoday',
    'expected content body /from_psgi_array';
}

{
  ok my $response = request GET '/from_psgi_code',
    'got welcome from a catalyst controller';

  is $response->content, 'helloworldtoday2',
    'expected content body /from_psgi_code';
}

{
  ok my $response = request GET '/from_psgi_code_itr',
    'got welcome from a catalyst controller';

  is $response->content, 'helloworldtoday3',
    'expected content body /from_psgi_code_itr';
}

{
  ok my($res, $c) = ctx_request(POST '/test_psgi_keys?a=1&b=2', [c=>3,d=>4]);

  ok $c->req->env->{"psgix.input.buffered"}, "input is buffered";

  is $c->req->parameters->get('c'), 3;
  is $c->req->parameters->get('d'), 4;
  is $c->req->parameters->get('a'), 1;
  is $c->req->parameters->get('b'), 2;

  is $c->req->body_parameters->get('c'), 3;
  is $c->req->body_parameters->get('d'), 4;
  is $c->req->query_parameters->get('a'), 1;
  is $c->req->query_parameters->get('b'), 2;
}

done_testing;
