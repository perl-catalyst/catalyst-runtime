#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;

plan tests => 3;

use_ok('TestApp');

is(TestApp->component('TestApp')->action_for('global_action')->code, TestApp->can('global_action'),
   'action_for on appclass ok');

is(TestApp->controller('Args')->action_for('args')->code,
   TestApp::Controller::Args->can('args'),
   'action_for on controller ok');
