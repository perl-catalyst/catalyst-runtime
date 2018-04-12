package ScriptTestApp::Script::Foo;
use Moose;
use namespace::clean -except => [ 'meta' ];

with 'Catalyst::ScriptRole';

sub run { __PACKAGE__ }

1;
