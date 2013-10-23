#!/usr/bin/env perl

use warnings;
use strict;

use FindBin;
use Test::More;
use HTTP::Request::Common;
use JSON::MaybeXS;

use lib "$FindBin::Bin/lib";
use Catalyst::Test 'TestContentNegotiation';

{
  ok my $req = POST '/',
     Content_Type => 'application/json',
     Content => encode_json +{message=>'test'};

  ok my $res = request $req;

  is $res->content, 'is_json';
}

{
  ok my $req = POST '/', [a=>1,b=>2];
  ok my $res = request $req;

  is $res->content, 'is_urlencoded';
}

{
  ok my $path = TestContentNegotiation->path_to(qw/share file.txt/);
  ok my $req = POST '/',
    Content_Type => 'form-data',
    Content =>  [a=>1, b=>2, file=>["$path"]];

  ok my $res = request $req;

  is $res->content, 'is_multipart';
}


done_testing;
