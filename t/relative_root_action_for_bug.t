use Test::Most;

{
    package MyApp::Controller::Root;
    $INC{'MyApp/Controller/Root.pm'} = __FILE__;

    use Moose;
    use MooseX::MethodAttributes;

    extends 'Catalyst::Controller';

    sub root :Chained(/) PathPart('') CaptureArgs(0) {
      my ($self, $c) = @_;
    }

    sub top :Chained('root') Args(0) {
      my ($self, $c) = @_;
      Test::Most::is $self->action_for('top'), 'top';
      Test::Most::is $self->action_for('story/story'), 'story/story';

      #warn ref($c)->dispatcher->get_action('story/story', '/root');

      #use Devel::Dwarn;
      #Dwarn ref($c)->dispatcher->_action_hash->{'story/story'};
    }

    MyApp::Controller::Root->config(namespace=>'');

    package MyApp::Controller::Story;
    $INC{'MyApp/Controller/Story.pm'} = __FILE__;

    use Moose;
    use MooseX::MethodAttributes;

    extends 'Catalyst::Controller';

    sub root :Chained(/root) PathPart('') CaptureArgs(0) {
      my ($self, $c) = @_;
    }

    sub story :Chained(root) Args(0) {
      my ($self, $c) = @_;

      Test::Most::is $self->action_for('story'), 'story/story';
      Test::Most::is $self->action_for('author/author'), 'story/author/author';
    }

    __PACKAGE__->meta->make_immutable;

    package MyApp::Controller::Story::Author;
    $INC{'MyApp/Controller/Story/Author.pm'} = __FILE__;

    use Moose;
    use MooseX::MethodAttributes;

    extends 'Catalyst::Controller';

    sub root :Chained(/story/root) PathPart('') CaptureArgs(0) {
      my ($self, $c) = @_;
    }

    sub author :Chained(root) Args(0) {
      my ($self, $c, $id) = @_;
      Test::Most::is $self->action_for('author'), 'story/author/author';
    }


    __PACKAGE__->meta->make_immutable;

    package MyApp;
    $INC{'MyApp.pm'} = __FILE__;

    use Catalyst;

    MyApp->setup;
}

use Catalyst::Test 'MyApp';

ok request '/story';
ok request '/author';
ok request '/top';

done_testing(8);

