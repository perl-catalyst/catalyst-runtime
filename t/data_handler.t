#!/usr/bin/env perl

use warnings;
use strict;

use FindBin;
use Test::More;
use HTTP::Request::Common;
use JSON::MaybeXS;

use lib "$FindBin::Bin/lib";
use Catalyst::Test 'TestDataHandlers';

ok my($res, $c) = ctx_request('/');

{
  ok my $message = 'helloworld';
  ok my $post = encode_json +{message=>$message};
  ok my $req = POST $c->uri_for_action('/test_json'),
     Content_Type => 'application/json',
     Content => $post;

  ok my $response = request $req, 'got a response from a catalyst controller';
  is $response->content, $message, 'expected content body';
}

{
  ok my $req = POST $c->uri_for_action('/test_nested_for'), [ 'nested.value' => 'expected' ];
  ok my $response = request $req, 'got a response from a catalyst controller';
  is $response->content, 'expected', 'expected content body';
}

{
  my $out;
  local *STDERR;
  open(STDERR, ">", \$out) or die "Can't open STDERR: $!";
  ok my $req = POST $c->uri_for_action('/test_nested_for'), 'Content-Type' => 'multipart/form-data', Content => { die => "a horrible death" };
  ok my $response = request $req;
  is($out, "[error] multipart/form-data does not have an available data handler. Valid data_handlers are application/json, application/x-www-form-urlencoded.\n", 'yep we throw the slightly more usefull error');
}

done_testing;
