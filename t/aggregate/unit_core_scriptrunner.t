use strict;
use warnings;
use Test::More;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use_ok('Catalyst::ScriptRunner');

is Catalyst::ScriptRunner->run('ScriptTestApp', 'Foo'), 'ScriptTestApp::Script::Foo',
    'Script existing only in app';
is Catalyst::ScriptRunner->run('ScriptTestApp', 'Bar'), 'ScriptTestApp::Script::Bar',
    'Script existing in both app and Catalyst - prefers app';
is Catalyst::ScriptRunner->run('ScriptTestApp', 'Baz'), 'Catalyst::Script::Baz',
    'Script existing only in Catalyst';
# +1 test for the params passed to new_with_options in t/lib/Catalyst/Script/Baz.pm
{
    my $warnings = '';
    local $SIG{__WARN__} = sub { $warnings .= shift };
    is 'Catalyst::Script::CompileTest', Catalyst::ScriptRunner->run('ScriptTestApp', 'CompileTest');
    like $warnings, qr/Does not compile/;
    like $warnings, qr/Could not load ScriptTestApp::Script::CompileTest - falling back to Catalyst::Script::CompileTest/;
}

done_testing;
