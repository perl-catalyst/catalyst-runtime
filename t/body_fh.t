use warnings;
use strict;
use Test::More;
use HTTP::Request::Common;
use HTTP::Message::PSGI;
use Plack::Util;

# Test case to check that we now send scalar and filehandle like
# bodys directly to the PSGI engine, rather than call $writer->write
# or unroll the filehandle ourselves.

{
  package MyApp::Controller::Root;

  use base 'Catalyst::Controller';

  sub flat_response :Local {
    my $response = 'Hello flat_response';
    pop->res->body($response);
  }

  sub memory_stream :Local {
    my $response = 'Hello memory_stream';
    open my $fh, '<', \$response || die "$!";

    pop->res->body($fh);
  }

  sub manual_write_fh :Local {
    my ($self, $c) = @_;
    my $response = 'Hello manual_write_fh';
    my $writer = $c->res->write_fh;
    $writer->write($response);
    $writer->close;
  }

  sub manual_write :Local {
    my ($self, $c) = @_;
    $c->res->write('Hello');
    $c->res->body('manual_write');
  }

  package MyApp;
  use Catalyst;

}

$INC{'MyApp/Controller/Root.pm'} = '1'; # sorry...

ok(MyApp->setup);
ok(my $psgi = MyApp->psgi_app);

{
  ok(my $env = req_to_psgi(GET '/root/flat_response'));
  ok(my $psgi_response = $psgi->($env));

  $psgi_response->(sub {
    my $response_tuple = shift;
    my ($status, $headers, $body) = @$response_tuple;

    ok $status;
    ok $headers;
    is $body->[0], 'Hello flat_response';

   });
}

{
  ok(my $env = req_to_psgi(GET '/root/memory_stream'));
  ok(my $psgi_response = $psgi->($env));

  $psgi_response->(sub {
    my $response_tuple = shift;
    my ($status, $headers, $body) = @$response_tuple;

    ok $status;
    ok $headers;
    is ref($body), 'GLOB';

  });
}

{
  ok(my $env = req_to_psgi(GET '/root/manual_write_fh'));
  ok(my $psgi_response = $psgi->($env));

  $psgi_response->(sub {
    my $response_tuple = shift;
    my ($status, $headers, $body) = @$response_tuple;

    ok $status;
    ok $headers;
    ok !$body;

    return Plack::Util::inline_object(
        write => sub { is shift, 'Hello manual_write_fh' },
        close => sub { ok 1, 'closed' },
      );
  });
}

{
  ok(my $env = req_to_psgi(GET '/root/manual_write'));
  ok(my $psgi_response = $psgi->($env));

  $psgi_response->(sub {
    my $response_tuple = shift;
    my ($status, $headers, $body) = @$response_tuple;

    ok $status;
    ok $headers;
    ok !$body;

    my @expected = (qw/Hello manual_write/);
    return Plack::Util::inline_object(
        close => sub { ok 1, 'closed'; is scalar(@expected), 0; },
        write => sub { is shift, shift(@expected) },
      );
  });
}

## We need to specify the number of expected tests because tests that live
## in the callbacks might never get run (thus all ran tests pass but not all
## required tests run).

done_testing(28);
