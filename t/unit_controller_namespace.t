use strict;
use warnings;

use Test::More tests => 2;

BEGIN {
  package MyApp::Controller::Foo;

  use base qw/Catalyst::Controller/;

  package MyApp::Controller::Root;

  use base qw/Catalyst::Controller/;

  __PACKAGE__->config(namespace => '');

  package Stub;

  sub config { {} };
}

is(MyApp::Controller::Foo->COMPONENT('MyApp')->action_namespace('Stub'), 'foo');

is(MyApp::Controller::Root->COMPONENT('MyApp')->action_namespace('Stub'), '');
