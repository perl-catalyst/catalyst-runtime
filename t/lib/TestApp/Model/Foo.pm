package TestApp::Model::Foo;

use strict;
use warnings;

use base qw/ Catalyst::Model /;

sub model_foo_method { 1 }

package TestApp::Model::Foo::Bar;
sub model_foo_bar_method_from_foo { 1 }

package TestApp::Model::Foo;
sub bar { "TestApp::Model::Foo::Bar" }

1;
