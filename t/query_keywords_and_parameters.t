use warnings;
use strict;
use Test::More;

# Test case for reported issue when an action consumes JSON but a
# POST sends nothing we get a hard error

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use base 'Catalyst::Controller';

  sub bar :Local Args(0) GET {
    my( $self, $c ) = @_;
  }

  package MyApp;
  use Catalyst;
  MyApp->setup;
}

use HTTP::Request::Common;
use Catalyst::Test 'MyApp';

# These tests assume that the decoding that occurs for the query string follows
# the payload decoding algorithm described here:
# https://www.w3.org/TR/html5/forms.html#url-encoded-form-data

{
  ok my $req = GET 'root/bar';

  my ($res, $c) = ctx_request($req);

  ok !defined($c->req->query_keywords), 'query_keywords is not defined when no ?';
  is_deeply $c->req->query_parameters, {}, 'query_parameters defined, but empty for no ?';
}


{
  ok my $req = GET 'root/bar?';

  my ($res, $c) = ctx_request($req);

  ok !defined $c->req->query_keywords, 'query_keywords is not defined when ? with empty query string';
  is_deeply $c->req->query_parameters, {}, 'query_parameters defined, but empty with empty query string';
}


{
  ok my $req = GET 'root/bar?a=b';

  my ($res, $c) = ctx_request($req);

  ok !defined($c->req->query_keywords), 'query_keywords undefined when isindex not set';
  is_deeply $c->req->query_parameters, { a => 'b' }, 'query_parameters defined for ?a=b';
}


{
  ok my $req = GET 'root/bar?x';

  my ($res, $c) = ctx_request($req);

  is $c->req->query_keywords, 'x', 'query_keywords defined for ?x';
  # The algorithm reads like 'x' should be treated as a value, not a name.
  # Perl does not support undef as a hash key.  I feel this would be the best
  # alternative as isindex is moving towards complete deprecation.
  is_deeply $c->req->query_parameters, { 'x' => undef }, 'query_parameters defined for ?x';
}


{
  ok my $req = GET 'root/bar?x&a=b';

  my ($res, $c) = ctx_request($req);

  is $c->req->query_keywords, 'x', 'query_keywords defined for ?x&a=b';
  # See comment above about the 'query_parameters defined for ?x' test case.
  is_deeply $c->req->query_parameters, { 'x' => undef, a => 'b' }, 'query_parameters defined for ?x&a=b';
}


done_testing();
