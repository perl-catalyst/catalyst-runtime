#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Exception;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

{
    package TestHelpScript;
    use Moose;
    with 'Catalyst::ScriptRole';
    our $help;
    sub _getopt_full_usage { $help++ }
}

test('-h');
test('--help');
test('-?');

sub test {
    local $TestHelpScript::help;
    local @ARGV = (@_);
    lives_ok {
        TestHelpScript->new_with_options(application_name => 'TestAppToTestScripts')->run;
    } 'Lives';
    ok $TestHelpScript::help, 'Got help';
}

done_testing;
