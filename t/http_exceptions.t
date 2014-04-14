use warnings;
use strict;
use Test::More;
use HTTP::Request::Common;
use HTTP::Message::PSGI;
use Plack::Util;
use Plack::Test;

# Test to make sure we let HTTP style exceptions bubble up to the middleware
# rather than catching them outselves.

{
  package MyApp::Exception;

  use overload
    # Use the overloading thet HTTP::Exception uses
    bool => sub { 1 }, '""' => 'as_string', fallback => 1;

  sub new {
    my ($class, $code, $headers, $body) = @_;
    return bless +{res => [$code, $headers, $body]}, $class;
  }

  sub throw { die shift->new(@_) }

  sub as_psgi {
    my ($self, $env) = @_;
    my ($code, $headers, $body) = @{$self->{res}};

    return [$code, $headers, $body]; # for now

    return sub {
      my $responder = shift;
      $responder->([$code, $headers, $body]);
    };
  }

  sub as_string { 'bad stringy bad' }
  
  package MyApp::Controller::Root;

  use base 'Catalyst::Controller';

  my $psgi_app = sub {
    my $env = shift;
    die MyApp::Exception->new(
      404, ['content-type'=>'text/plain'], ['Not Found']);
  };

  sub from_psgi_app :Local {
    my ($self, $c) = @_;
    $c->res->from_psgi_response(
      $psgi_app->(
        $c->req->env));
  }

  sub from_catalyst :Local {
    my ($self, $c) = @_;
    MyApp::Exception->throw(
      403, ['content-type'=>'text/plain'], ['Forbidden']);
  }

  sub classic_error :Local {
    my ($self, $c) = @_;
    Catalyst::Exception->throw("Ex Parrot");
  }

  sub just_die :Local {
    my ($self, $c) = @_;
    die "I'm not dead yet";
  }

  package MyApp;
  use Catalyst;

  sub debug { 1 }

  MyApp->setup_log('fatal');
}

$INC{'MyApp/Controller/Root.pm'} = '1'; # sorry...
MyApp->setup_log('error');

Test::More::ok(MyApp->setup);

ok my $psgi = MyApp->psgi_app;

test_psgi $psgi, sub {
    my $cb = shift;
    my $res = $cb->(GET "/root/from_psgi_app");
    is $res->code, 404;
    is $res->content, 'Not Found', 'NOT FOUND';
};

test_psgi $psgi, sub {
    my $cb = shift;
    my $res = $cb->(GET "/root/from_catalyst");
    is $res->code, 403;
    is $res->content, 'Forbidden', 'Forbidden';
};

test_psgi $psgi, sub {
    my $cb = shift;
    my $res = $cb->(GET "/root/classic_error");
    is $res->code, 500;
    like $res->content, qr'Ex Parrot', 'Ex Parrot';
};

test_psgi $psgi, sub {
    my $cb = shift;
    my $res = $cb->(GET "/root/just_die");
    is $res->code, 500;
    like $res->content, qr'not dead yet', 'not dead yet';
};



# We need to specify the number of expected tests because tests that live
# in the callbacks might never get run (thus all ran tests pass but not all
# required tests run).

done_testing(10);

