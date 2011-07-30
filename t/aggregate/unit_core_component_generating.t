# FIXME - what to do about expand_modules?
use Test::More skip_all => "Needs expand_modules, that has been removed from Catalyst.pm";
use strict;
use warnings;

use lib 't/lib';
use TestApp;

ok(TestApp->model('Generating'), 'knows about generating model');
ok(TestApp->model('Generated'), 'knows about the generated model');
is(TestApp->model('Generated')->foo, 'foo', 'can operate on generated model');

done_testing;
