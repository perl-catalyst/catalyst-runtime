package TestApp::Controller::Action::Action;

use utf8;
use strict;
use base 'TestApp::Controller::Action';
use Data::Dumper ();

__PACKAGE__->config(
    actions => {
        '*'                 => { extra_attribute  => 13 },
        action_action_five  => { ActionClass => '+Catalyst::Action::TestBefore' },
        action_action_eight => { another_extra_attribute => 'foo' },
    },
    action_args => {
        '*'                 => { extra_arg         => 42 },
        action_action_seven => { another_extra_arg => 23 },
    },
);

sub action_action_one : Global : ActionClass('TestBefore') {
    my ( $self, $c ) = @_;
    $c->res->header( 'X-Action', $c->stash->{test} );
    $c->forward('TestApp::View::Dump::Request');
}

sub action_action_two : Global : ActionClass('TestAfter') {
    my ( $self, $c ) = @_;
    $c->stash->{after_message} = 'awesome';
    $c->forward('TestApp::View::Dump::Request');
}

sub action_action_three : Global : ActionClass('+TestApp::Action::TestBefore') {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub action_action_four : Global : MyAction('TestMyAction') {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub action_action_five : Global {
    my ( $self, $c ) = @_;
    $c->res->header( 'X-Action', $c->stash->{test} );
    $c->forward('TestApp::View::Dump::Request');
}

sub action_action_six : Global : ActionClass('~TestMyAction') {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub action_action_seven : Global : ActionClass('~TestExtraArgsAction') {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub action_action_eight : Global  {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Action');
}

sub action_action_nine : Global : ActionClass('~TestActionArgsFromConstructor') {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

# For testing the regex that parses method attributes

sub action_action_ten :Global
    :Foo
    :Foo()
    :Foo(bar)
    :Foo("bar")
    :Foo(aaa bbb    ccc. dddd)
    :Foo(12345)
    :Foo(  bar  )
    :Foo("bar baz")
    :Foo(bar baz   )
    :Foo(bar(baz))
    :Foo(^$.*+?)
    :Foo(bar\)baz)
    :Foo(ba\\nr)
    :Foo(ba\tr)
    :Foo(bar, baz)
    :Foo(bar;baz)
    :Foo(bar&baz)
    :Foo(bar=1)
    :Foo(  {  "a":"b"})
    :Foo(bar=1, baz=2)
    :Foo(   bar=1,  baz=2, qux=3 )
    :Foo("   bar=1,  baz=2, qux=3 ")
    :Foo(   "   bar=1,  baz=2, qux=3 ")    
    :Foo('   bar=1,  baz=2, qux=3 ')
    :Foo([   bar=1,  baz=2, qux=3 ])            
    :Foo(bar: baz)
    :Foo(中文测试)
    :Foo("bar's baz")
    :Foo(😀 emoji test)
    :Foo(#comment)
    :Foo("fff\nfff")
    :Foo("\taaa\nbbb")
    :Foo('bar's baz')
    :Foo(   )
    :Foo([.*?^$])
    :Foo(
    
    
    )
    :Foo(
        aaa
        bbb😀 ccc  
        ddd
    )
    :Foo("
        aaa
        bbb😀 ccc  
        ddd
    ")
    :Foo(
        'aaa'
        'bbb😀' 'ccc'  
        'ddd'
    )
    :Foo("
        'aaa'
        'bbb😀' 'ccc'  
        'ddd'
    ")     
{
    my ( $self, $c ) = @_;
    $c->response->body(Data::Dumper::Dumper($c->action->attributes->{Foo}));
}

1;
