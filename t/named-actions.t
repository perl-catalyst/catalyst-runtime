{
    package MyApp::Controller::Root;
    $INC{'MyApp/Controller/Root.pm'} = __FILE__;

    use warnings;
    use strict;
    use base 'Catalyst::Controller';

    sub root :Chained(/) PathPart('') CaptureArgs(0) Name(Root) {
        my ($self, $c) = @_;
    }

      sub a :Chained(root) PathPart('a') Args(0) {
          my ($self, $c) = @_;
          $c->response->body('/a');
      }

      sub b :Chained(*Root) PathPart('b') Args(0) {
          my ($self, $c, @a) = @_;
          $c->response->body('/b');
      }

      sub c :Chained(*Root) PathPart('c') CaptureArgs(0) Name(C) { }

    MyApp::Controller::Root->config(namespace=>'');

    package MyApp::Controller::Home;
    $INC{'MyApp/Controller/Home.pm'} = __FILE__;

    use warnings;
    use strict;
    use base 'Catalyst::Controller';

    sub root_a :Chained(*Root) PathPart('home') CaptureArgs(0) {
        my ($self, $c) = @_;
    }

      sub a :Chained(root_a) PathPart('a') Args(0) {
          my ($self, $c) = @_;
          $c->response->body('/home/a');
      }

    sub root_b :Chained(../root) PathPart('home') CaptureArgs(0) {
        my ($self, $c) = @_;
    }

      sub b :Chained(root_b) PathPart('b') Args(0) {
          my ($self, $c) = @_;
          $c->response->body('/home/b');
      }

    sub d :Chained(*C) PathPart('d') Args(0) Name(D) {
        my ($self, $c) = @_;
        $c->response->body('/c/d');
    }

    package MyApp::Controller::URI;
    $INC{'MyApp/Controller/URI.pm'} = __FILE__;

    use warnings;
    use strict;
    use base 'Catalyst::Controller';

    sub uri1 :Path(/uri1) Args(0) {
        my ($self, $c) = @_;
        $c->response->body($c->uri_for( $c->controller('Root')->action_for('*D') ));
    }

    sub uri2 :Path(/uri2) Args(0) {
        my ($self, $c) = @_;
        $c->response->body($c->uri_for( $c->action_for('*D') ));
    }

    sub uri3 :Path(/uri3) Args(0) {
        my ($self, $c) = @_;
        $c->response->body($c->uri_for( $self->action_for('../*D') ));
    }

    package MyApp::Controller::Flow;
    $INC{'MyApp/Controller/Flow.pm'} = __FILE__;

    use warnings;
    use strict;
    use base 'Catalyst::Controller';

    sub test_forward :Path(/forward) Args(0) {
        my ($self, $c) = @_;
        $c->forward('*ForForward');
    }

    sub forward_target :Action Name(ForForward) {
        my ($self, $c) = @_;
        $c->response->body('forward');
    }

    sub test_detach :Path(/detach) Args(0) {
        my ($self, $c) = @_;
        $c->detach('*ForDetach');
    }

    sub detach_target :Action Name(ForDetach) {
        my ($self, $c) = @_;
        $c->response->body('detach');
    }

    sub test_go :Path(/go) Args(0) {
        my ($self, $c) = @_;
        $c->detach('*ForGo');
    }

    sub go_target :Action Name(ForGo) {
        my ($self, $c) = @_;
        $c->response->body('go');
    }

    sub test_visit :Path(/visit) Args(0) {
        my ($self, $c) = @_;
        $c->detach('*ForVisit');
    }

    sub visit_target :Action Name(ForVisit) {
        my ($self, $c) = @_;
        $c->response->body('visit');
    }

    package MyApp;
    use Catalyst;

    MyApp->setup;
}

use Test::More;
use Catalyst::Test 'MyApp';

{
    ok my $res = request '/detach';
    is $res->content, 'detach';
}

{
    ok my $res = request '/forward';
    is $res->content, 'forward';
}

{
    ok my $res = request '/go';
    is $res->content, 'go';
}

{
    ok my $res = request '/visit';
    is $res->content, 'visit';
}

{
    ok my $res = request '/uri1';
    is $res->content, 'http://localhost/c/d';

    ok $res = request '/uri2';
    is $res->content, 'http://localhost/c/d';

    ok $res = request '/uri3';
    is $res->content, 'http://localhost/c/d';

}

{
    ok my $res = request '/a';
    is $res->content, '/a';
}

{
    ok my $res = request '/b';
    is $res->content, '/b';
}

{
    ok my $res = request '/home/a';
    is $res->content, '/home/a';
}

{
    ok my $res = request '/home/b';
    is $res->content, '/home/b';
}

{
    ok my $res = request '/c/d';
    is $res->content, '/c/d';
}

done_testing;
