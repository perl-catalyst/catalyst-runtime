package TestFromPSGI::Controller::Root;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

sub test_psgi_keys :Local {
  my ($self, $c) = @_;
  $c->res->body('ok');
}

sub from_psgi_array : Local {
  my ($self, $c) = @_;
  my $res = sub {
    my ($env) = @_;
    return [200, ['Content-Type'=>'text/plain'],
      [qw/hello world today/]];
  }->($c->req->env);

  $c->res->from_psgi_response($res);
}

sub from_psgi_code : Local {
  my ($self, $c) = @_;

  my $res = sub {
    my ($env) = @_;
    return sub {
      my $responder = shift;
      return $responder->([200, ['Content-Type'=>'text/plain'],
        [qw/hello world today2/]]);
    };
  }->($c->req->env);

  $c->res->from_psgi_response($res);
}

sub from_psgi_code_itr : Local {
  my ($self, $c) = @_;
  my $res = sub {
    my ($env) = @_;
    return sub {
      my $responder = shift;
      my $writer = $responder->([200, ['Content-Type'=>'text/plain']]);
      $writer->write('hello');
      $writer->write('world');
      $writer->write('today3');
      $writer->close;
    };
  }->($c->req->env);

  $c->res->from_psgi_response($res);
}

__PACKAGE__->meta->make_immutable;
