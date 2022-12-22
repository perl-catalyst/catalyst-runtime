{
    package MyApp::Controller::Root;
    $INC{'MyApp/Controller/Root.pm'} = __FILE__;

    use warnings;
    use strict;
    use base 'Catalyst::Controller';

    sub root :Chained(/) PathPart('') CaptureArgs(0) {
        my ($self, $c) = @_;
        my @a = (1);
        @a = $c->action->next(@a);
        push @a, 7;
        $c->response->body(join ',',@a);
    }

      sub a :Chained(root) PathPart('a') CaptureArgs(0) {
          my ($self, $c, @a) = @_;
          push @a, 2;
          @a = $c->action->next(@a);
          push @a, 6;
          return @a;
      }

          sub b :Chained(a) PathPart('b') CaptureArgs(1) {
              my ($self, $c, @a) = @_;
              push @a, 3;
              @a = $c->action->next(@a);
              push @a, 5;
              return @a;
          }

              sub c :Chained(b) PathPart('c') Args(0) {
                  my ($self, $c, @a) = @_;
                  push @a, 4;
                  return @a;
              }

    MyApp::Controller::Root->config(namespace=>'');

    package MyApp;
    use Catalyst;

    MyApp->setup;
}

use Test::More;
use Catalyst::Test 'MyApp';

ok my $res = request '/a/b/99/c';
is $res->content, '1,2,99,3,4,5,6,7';

done_testing;
