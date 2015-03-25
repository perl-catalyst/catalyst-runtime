use utf8;
use warnings;
use strict;

# For reported: https://rt.cpan.org/Ticket/Display.html?id=103063

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  sub example :Local Args(0) {
    pop->stash->{testing1} = 'testing2';
  }

  package MyApp;
  use Catalyst;

  #MyApp->config(decode_query_using_global_encoding=>1, encoding => 'SHIFT_JIS');
  #MyApp->config(do_not_decode_query=>1);
  #MyApp->config(decode_query_using_global_encoding=>1, encoding => undef);
  MyApp->config(default_query_encoding=>'SHIFT_JIS');

  MyApp->setup;
}

use Test::More;
use Catalyst::Test 'MyApp';
use Encode;
use HTTP::Request::Common;

{
  my $shiftjs = 'test テスト';
  my $encoded = Encode::encode('SHIFT_JIS', $shiftjs);

  ok my $req = GET "/root/example?a=$encoded";
  my ($res, $c) = ctx_request $req;

  is $c->req->query_parameters->{'a'}, $shiftjs, 'got expected value';
}


done_testing;

