#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Exception;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

{
    package TestCreateScript;
    use Moose;
    extends 'Catalyst::Script::Create';
    our $help;
    sub _exit_with_usage { $help++ }
}

{
    package TestHelperClass;
    use Moose;
    
    has 'newfiles' => ( is => 'ro', init_arg => '.newfiles' );
    has 'mech' => ( is => 'ro' );
    our @ARGS;
    our %p;
    sub mk_component {
        my $self = shift;
        @ARGS = @_;
        %p = ( '.newfiles' => $self->newfiles, mech => $self->mech);
        return $self->_mk_component_return;
    }
    sub _mk_component_return { 1 }
}
{
    package TestHelperClass::False;
    use Moose;
    extends 'TestHelperClass';
    sub _mk_component_return { 0 }
}

{
    local $TestCreateScript::help;
    local @ARGV;
    lives_ok {
        TestCreateScript->new_with_options(application_name => 'TestAppToTestScripts', helper_class => 'TestHelperClass')->run;
    } "no argv";
    ok $TestCreateScript::help, 'Exited with usage info';
}
{
    local $TestCreateScript::help;
    local @ARGV = 'foo';
    local @TestHelperClass::ARGS;
    local %TestHelperClass::p;
    lives_ok {
        TestCreateScript->new_with_options(application_name => 'TestAppToTestScripts', helper_class => 'TestHelperClass')->run;
    } "with argv";
    ok !$TestCreateScript::help, 'Did not exit with usage into';
    is_deeply \@TestHelperClass::ARGS, ['TestAppToTestScripts', 'foo'], 'Args correct';
    is_deeply \%TestHelperClass::p, { '.newfiles' => 1, mech => undef }, 'Params correct';
}

{
    local $TestCreateScript::help;
    local @ARGV = 'foo';
    local @TestHelperClass::ARGS;
    local %TestHelperClass::p;
    lives_ok {
        TestCreateScript->new_with_options(application_name => 'TestAppToTestScripts', helper_class => 'TestHelperClass::False')->run;
    } "with argv";
    ok $TestCreateScript::help, 'Did exit with usage into as mk_component returned false';
    is_deeply \@TestHelperClass::ARGS, ['TestAppToTestScripts', 'foo'], 'Args correct';
    is_deeply \%TestHelperClass::p, { '.newfiles' => 1, mech => undef }, 'Params correct';
}

done_testing;
