use warnings;
use strict;
use Test::More;
use HTTP::Request::Common;

{
  package TestAppStats::Log;
  $INC{'TestAppStats/Log.pm'} = __FILE__;

  use base qw/Catalyst::Log/;

  my @warn;

  sub my_warnings { $warn[0] };
  sub warn { shift; push(@warn, @_) }

  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  sub get_header_ok :Local {
    my ($self, $c) = @_;
    $c->res->body('get_header_ok');
  }

  sub set_header_nok :Local {
    my ($self, $c) = @_;
    $c->res->body('set_header_nok');
  }

  package MyApp;
  $INC{'MyApp.pm'} = __FILE__;

  use Catalyst;
  use Moose;

  sub debug { 1 }

  __PACKAGE__->log(TestAppStats::Log->new('warn'));

  after 'finalize' => sub {
    my ($c) = @_;
    if($c->res->body eq 'set_header_nok') {
      Test::More::ok 1, 'got this far'; # got this far
      $c->res->header('REQUEST_METHOD', 'bad idea');
    } elsif($c->res->body eq 'get_header_ok') {
      Test::More::ok $c->res->header('x-catalyst'), 'Can query a header without causing trouble';
    }
  };

  MyApp->setup;
}

use Catalyst::Test 'MyApp';

ok request(GET '/root/get_header_ok'), 'got good request for get_header_ok';
ok !TestAppStats::Log::my_warnings, 'no warnings';
ok request(GET '/root/set_header_nok'), 'got good request for set_header_nok';
ok TestAppStats::Log::my_warnings, 'has a warning';
like TestAppStats::Log::my_warnings, qr'Useless setting a header value after finalize_headers', 'got expected warnings';

# We need to specify the number in order to be sure we are testing
# it all correctly.  If you change the number of tests please keep
# this up to date.  DO NOT REMOVE THIS!

done_testing(7);
