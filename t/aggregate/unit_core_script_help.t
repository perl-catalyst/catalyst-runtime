use strict;
use warnings;
use Test::More;
use Test::Fatal;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

{
    package TestHelpScript;
    use Moose;
    with 'Catalyst::ScriptRole';
    our $help;
    sub print_usage_text { $help++ }
}

test('--help');
test('-?');

sub test {
    local $TestHelpScript::help;
    local @ARGV = (@_);
    is exception {
        TestHelpScript->new_with_options(application_name => 'TestAppToTestScripts')->run;
    }, undef, 'Lives';
    ok $TestHelpScript::help, 'Got help';
}

done_testing;
