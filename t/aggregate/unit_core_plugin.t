#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use lib 't/lib';

{

    package Faux::Plugin;

    sub new { bless { count => 1 }, shift }
    sub count { shift->{count}++ }
}

my $warnings = 0;

use PluginTestApp;
my $logger = Class::MOP::Class->create_anon_class(
    methods => {
        error => sub {0},
        debug => sub {0},
        info => sub {0},
        warn => sub {
            if ($_[1] =~ /plugin method is deprecated/) {
               $warnings++;
                return;
            }
            die "Caught unexpected warning: " . $_[1];
        },
    },
)->new_object;
PluginTestApp->log($logger);

use Catalyst::Test qw/PluginTestApp/;

ok( get("/compile_time_plugins"), "get ok" );
is( $warnings, 0, 'no warnings' );
# FIXME - Run time plugin support is insane, and should be removed
#         for Catalyst 5.9
ok( get("/run_time_plugins"),     "get ok" );

local $ENV{CATALYST_DEBUG} = 0;

is( $warnings, 1, '1 warning' );

use_ok 'TestApp';
my @expected = qw(
  Catalyst::Plugin::Test::Errors
  Catalyst::Plugin::Test::Headers
  Catalyst::Plugin::Test::Inline
  Catalyst::Plugin::Test::MangleDollarUnderScore
  Catalyst::Plugin::Test::Plugin
  TestApp::Plugin::AddDispatchTypes
  TestApp::Plugin::FullyQualified
);

# Faux::Plugin is no longer reported
is_deeply [ TestApp->registered_plugins ], \@expected,
  'registered_plugins() should only report the plugins for the current class';

done_testing;
