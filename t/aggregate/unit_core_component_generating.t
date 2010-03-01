use Test::More tests => 3;
use strict;
use warnings;

use lib 't/lib';
use TestApp;

ok(TestApp->model('Generating'), 'knows about generating model');
ok(TestApp->model('Generated'), 'knows about the generated model');
is(TestApp->model('Generated')->foo, 'foo', 'can operate on generated model');
