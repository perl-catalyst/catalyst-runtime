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
ok my $message = 'helloworld';
ok my $post = encode_json +{message=>$message};
ok my $req = POST $c->uri_for_action('/test_json'),
   Content_Type => 'application/json',
   Content => $post;

ok my $response = request $req, 'got a response from a catalyst controller';
is $response->content, $message, 'expected content body';

done_testing;
