use strict;
use warnings;
use Test::More;

BEGIN {
  package TestApp::Exception;
  $INC{'TestApp/Exception.pm'} = __FILE__;

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

  package TestApp::Controller::Root;
  $INC{'TestApp/Controller/Root.pm'} = __FILE__;

  use Moose;
  use MooseX::MethodAttributes;
  extends 'Catalyst::Controller';

  sub main :Path('') :Args(1) {
    my ($self, $c, $arg) = @_;
    $c->res->body('<h1>OK</h1>');
    $c->res->content_type('text/html');
  }

  TestApp::Controller::Root->config(namespace => '');
}
 
{
  package TestApp;
  $INC{'TestApp.pm'} = __FILE__;
 
  use Catalyst;
  use TestApp::Exception;

  sub handle_unicode_encoding_exception {
    my ( $self, $param_value, $error_msg ) = @_;
    TestApp::Exception->throw(
      200, ['content-type'=>'text/plain'], ['Bad unicode data']);
  }

  __PACKAGE__->setup;
}
 
 
use Catalyst::Test 'TestApp';

{
  my $res = request('/ok');
  is ($res->status_line, "200 OK");
  is ($res->content, '<h1>OK</h1>');
}
 
{
  my $res = request('/%E2%C3%83%C6%92%C3%8');
  is ($res->content, 'Bad unicode data');
}

done_testing;
