use strict;
use warnings;
use Test::More tests => 1;
use HTTP::Request::Common;

BEGIN {
    package TestApp::Controller::Root;
    $INC{'TestApp/Controller/Root.pm'} = __FILE__;
    use Moose;
    use MooseX::MethodAttributes;
    extends 'Catalyst::Controller';

    has counter => (is => 'rw', isa => 'Int', default => sub { 0 });
    sub increment {
        my $self = shift;
        $self->counter($self->counter + 1);
    }
    sub root :Chained('/') :PathPart('') :CaptureArgs(0) {
        my ($self, $c, $arg) = @_;
        die "Died in root";
    }
    sub main :Chained('root') :PathPart('') :Args(0) {
        my ($self, $c, $arg) = @_;
        $self->increment;
        die "Died in main";
    }
    sub hits :Path('hits') :Args(0) {
        my ($self, $c, $arg) = @_;
        $c->response->body($self->counter);
    }
    __PACKAGE__->config(namespace => '');
}
{
    package TestApp;
    $INC{'TestApp.pm'} = __FILE__;
    use Catalyst;
    __PACKAGE__->config(abort_chain_on_error_fix => 0);
    __PACKAGE__->setup('-Log=fatal');
}

use Catalyst::Test 'TestApp';

{
    my $res = request('/');
}
{
    my $res = request('/hits');
    is $res->content, 1, "main action performed on crash with explicit setting to false";
}
