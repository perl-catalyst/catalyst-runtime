#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;

plan tests => 5;

use_ok('TestApp');

is(TestApp->controller('Args')->action_for('args')->code,
   TestApp::Controller::Args->can('args'),
   'action_for on controller ok');
   is(TestApp->controller('Args')->action_for('args').'',
      'args/args',
      'action stringifies');

my $controller = Catalyst::Context->new( application => TestApp->new )->controller('Args');
is($controller->action_for('args')->code,
    TestApp::Controller::Args->can('args'),
    'action_for on controller ok');
is($controller->action_for('args').'',
    'args/args',
    'action stringifies');

