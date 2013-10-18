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

done_testing;
