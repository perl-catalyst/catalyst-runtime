use Test::More;

{
    package MyApp::Controller::Root;
    $INC{'MyApp/Controller/Root.pm'} = __FILE__;

    use warnings;
    use strict;
    use base 'Catalyst::Controller';

    sub root :Chained('/') PathPart('') CaptureArgs(0) {
        my ($self, $c) = @_;
        my @a = (1);
        $a = $c->action->next(@a);
        push @$a, 7;
        $c->response->body(join ',',@$a);
    }

      sub a :Chained(root) PathPart('a') CaptureArgs(0) {
          my ($self, $c, @a) = @_;
          push @a, 2;
          my $a = $c->action->next(@a);
          push @$a, 6;
          return $a;
      }

          sub b :Chained(a) PathPart('b') CaptureArgs(1) {
              my ($self, $c, @a) = @_;
              push @a, 3;
              my $a = $c->action->next(@a);
              push @$a, 5;
              return $a;
          }

              sub c :Chained(b) PathPart('c') Args(0) {
                  my ($self, $c, @a) = @_;
                  push @a, 4;
                  return \@a;
              }

    package MyApp::Controller::User;
    $INC{'MyApp/Controller/User.pm'} = __FILE__;

    use warnings;
    use strict;
    use base 'Catalyst::Controller';
    use Data::Dumper;

    sub root :Chained('/') PathPart('user') CaptureArgs(0) {
      my ($self, $c) = @_;
      push @{ $c->stash->{state} }, $c->state;
      return 100;
    }

      sub a :Chained(root) PathPart(a) CaptureArgs(0) {
        my ($self, $c) = @_;
        push @{ $c->stash->{state} }, $c->state;
        return 101;
      }

        sub b :Chained(a) PathPart(b) Args(0) {
          my ($self, $c) = @_;
          push @{ $c->stash->{state} }, $c->state;
          $c->res->body(join ',', @{ $c->stash->{state} });
        }

    MyApp::Controller::Root->config(namespace=>'');

    package MyApp::Controller::Home;
    $INC{'MyApp/Controller/Home.pm'} = __FILE__;

    use warnings;
    use strict;
    use base 'Catalyst::Controller';
    use Data::Dumper;

    sub root :Chained('/') PathPart('') CaptureArgs(0) {
      my ($self, $c) = @_;
      my $before_state = $c->state;
      my $a = $c->action->next(100);
      my $after_state = $c->state;
      Test::More::is_deeply $a, $after_state;
      $c->res->body(Dumper [ 10, $before_state, $after_state ]);
    }

      sub d :Chained(root) PathPart('') CaptureArgs(0) {
        my ($self, $c) = @_;
        my $before_state = $c->state;
        my $a = $c->action->next(200);
        my $after_state = $c->state;
        Test::More::is_deeply $a, $after_state;
        return [20, $before_state, @$after_state];
      }

        sub dd :Chained(d) PathPart(dd) Args(0) {
          my ($self, $c) = @_;
          my $before_state = $c->state();
          return [30, $before_state];
        }

      sub e :Chained(root) PathPart(e) Args(0) {
        my ($self, $c) = @_;
        return 'foo';
      }

      sub f :Chained(root) PathPart(f) Args(0) {
        my ($self, $c) = @_;
        return +{ bar => 1, baz => [3,4,5] };
      }

    package MyApp;
    use Catalyst;

    MyApp->setup;
}

use Catalyst::Test 'MyApp';

{
  ok my $res = request '/user/a/b';
  is $res->content, '1,100,101';  ## ?? Not sure why state is 1 for the first action in the chain...
}

{
  ok my $res = request '/a/b/99/c';
  is $res->content, '1,2,99,3,4,5,6,7';
}

{
  ok my $res = request '/dd';
  my $data = eval $res->content;
  is_deeply $data, [
    10,
    1,
    [
      20,
      1,
      30,
      1,
    ],
  ];
}

{
  ok my $res = request '/e';
  my $data = eval $res->content;
  is_deeply $data, [
    10,
    1,
    "foo",
  ];
}

{
  ok my $res = request '/f';
  my $data = eval $res->content;
  is_deeply $data, [
    10,
    1,
    {
      bar => 1,
      baz => [
        3,
        4,
        5,
      ],
    },
  ];
}

done_testing;
