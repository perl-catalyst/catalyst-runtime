use strict;
use warnings;

use Test::More tests => 3;
use Test::NoWarnings;    # Adds an extra test.

BEGIN {
  package MyApp::Controller::Foo;

  use base qw/Catalyst::Controller/;

  package MyApp::Controller::Root;

  use base qw/Catalyst::Controller/;

  __PACKAGE__->config(namespace => '');

  package Stub;

  sub config { {} };
}

is(MyApp::Controller::Foo->action_namespace('Stub'), 'foo');

is(MyApp::Controller::Root->action_namespace('Stub'), '');
