#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 7;

use lib "t/lib";

BEGIN { use_ok("Catalyst::Utils") };

is( Catalyst::Utils::class2prefix('MyApp::V::Foo::Bar'), 'foo/bar', 'class2prefix works with M/V/C' );

is( Catalyst::Utils::class2prefix('MyApp::Controller::Foo::Bar'), 'foo/bar', 'class2prefix works with Model/View/Controller' );

is( Catalyst::Utils::class2prefix('MyApp::Controller::Foo::View::Bar'), 'foo/view/bar', 'class2prefix works with tricky components' );

is( Catalyst::Utils::appprefix('MyApp::Foo'), 'myapp_foo', 'appprefix works' );

is( Catalyst::Utils::class2appclass('MyApp::Foo::Controller::Bar::View::Baz'), 'MyApp::Foo', 'class2appclass works' );

is( Catalyst::Utils::class2classprefix('MyApp::Foo::Controller::Bar::View::Baz'), 'MyApp::Foo::Controller', 'class2classprefix works' );

is( Catalyst::Utils::class2classsuffix('MyApp::Foo::Controller::Bar::View::Baz'), 'Controller::Bar::View::Baz', 'class2classsuffix works' );

is( Catalyst::Utils::class2env('MyApp::Foo'), 'MYAPP_FOO', 'class2env works' );
