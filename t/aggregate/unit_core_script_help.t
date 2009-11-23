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
    __PACKAGE__->meta->get_attribute('help')->cmd_aliases('h');
    our $help;
    sub _exit_with_usage { $help++ }
}

test('-h');
test('--help');

TODO: {
    local $TODO = 'This is bork';
    test('-?');
}

sub test {
    local $TestHelpScript::help;
    local @ARGV = (@_);
    lives_ok {
        TestHelpScript->new_with_options(application_name => 'TestAppToTestScripts')->run;
    };
    ok $TestHelpScript::help;
}

done_testing;
