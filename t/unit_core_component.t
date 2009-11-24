use Test::More tests => 7;
use strict;
use warnings;

use_ok('Catalyst');

my @complist = map { "MyApp::$_"; } qw/C::Controller M::Model V::View/;

{
  package MyApp;

  use base qw/Catalyst/;

  __PACKAGE__->components({ map { ($_, $_) } @complist });
}

is(MyApp->comp('MyApp::V::View'), 'MyApp::V::View', 'Explicit return ok');

is(MyApp->comp('C::Controller'), 'MyApp::C::Controller', 'Two-part return ok');

is(MyApp->comp('Model'), 'MyApp::M::Model', 'Single part return ok');

is(MyApp->comp('::M::'), 'MyApp::M::Model', 'Regex return ok');

is_deeply([ MyApp->comp() ], \@complist, 'Empty return ok');

is_deeply([ MyApp->comp('Foo') ], \@complist, 'Fallthrough return ok');
  # Is this desired behaviour?
