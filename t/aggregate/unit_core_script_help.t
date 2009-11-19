#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

{
    package TestHelpScript;
    use Moose;
    with 'Catalyst::ScriptRole';
    our $help;
    sub _exit_with_usage { $help++ }
}
{
    local $TestHelpScript::help;
    local @ARGV = ('-h');
    TestHelpFromScriptCGI->new_with_options(application_name => 'TestAppToTestScripts')->run;
    ok $TestHelpFromScriptCGI::help, 1;
}
{
    local $TestHelpScript::help;
    local @ARGV = ('--help');
    TestHelpFromScriptCGI->new_with_options(application_name => 'TestAppToTestScripts')->run;
    is $TestHelpFromScriptCGI::help, 2;
}

done_testing;
