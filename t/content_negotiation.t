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

  is $res->content, 'is_json1';
}

{
  ok my $req = POST '/', [a=>1,b=>2];
  ok my $res = request $req;

  is $res->content, 'is_urlencoded1';
}

{
  ok my $path = TestContentNegotiation->path_to(qw/share file.txt/);
  ok my $req = POST '/',
    Content_Type => 'form-data',
    Content =>  [a=>1, b=>2, file=>["$path"]];

  ok my $res = request $req;

  is $res->content, 'is_multipart1';
}

{
  ok my $req = POST '/under',
     Content_Type => 'application/json',
     Content => encode_json +{message=>'test'};

  ok my $res = request $req;

  is $res->content, 'is_json2';
}

{
  ok my $req = POST '/under', [a=>1,b=>2];
  ok my $res = request $req;

  is $res->content, 'is_urlencoded2';
}

{
  ok my $path = TestContentNegotiation->path_to(qw/share file.txt/);
  ok my $req = POST '/under',
    Content_Type => 'form-data',
    Content =>  [a=>1, b=>2, file=>["$path"]];

  ok my $res = request $req;

  is $res->content, 'is_multipart2';
}

{
  ok my $req = POST '/is_more_than_one_1',
    Content =>  [a=>1, b=>2];

  ok my $res = request $req;

  is $res->content, 'formdata1';
}

{
  ok my $req = POST '/is_more_than_one_2',
    Content =>  [a=>1, b=>2];

  ok my $res = request $req;

  is $res->content, 'formdata2';
}

{
  ok my $req = POST '/is_more_than_one_3',
    Content =>  [a=>1, b=>2];

  ok my $res = request $req;

  is $res->content, 'formdata3';
}

{
  ok my $path = TestContentNegotiation->path_to(qw/share file.txt/);
  ok my $req = POST '/is_more_than_one_1',
    Content_Type => 'form-data',
    Content =>  [a=>1, b=>2, file=>["$path"]];

  ok my $res = request $req;

  is $res->content, 'formdata1';
}

{
  ok my $path = TestContentNegotiation->path_to(qw/share file.txt/);
  ok my $req = POST '/is_more_than_one_2',
    Content_Type => 'form-data',
    Content =>  [a=>1, b=>2, file=>["$path"]];

  ok my $res = request $req;

  is $res->content, 'formdata2';
}

{
  ok my $path = TestContentNegotiation->path_to(qw/share file.txt/);
  ok my $req = POST '/is_more_than_one_3',
    Content_Type => 'form-data',
    Content =>  [a=>1, b=>2, file=>["$path"]];

  ok my $res = request $req;

  is $res->content, 'formdata3';
}

done_testing;
