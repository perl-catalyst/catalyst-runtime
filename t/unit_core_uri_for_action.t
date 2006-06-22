#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;

plan tests => 17;

use_ok('TestApp');

my $dispatcher = TestApp->dispatcher;

my $private_action = $dispatcher->get_action_by_path(
                       '/class_forward_test_method'
                     );

ok(!defined($dispatcher->uri_for_action($private_action)),
   "Private action returns undef for URI");

my $path_action = $dispatcher->get_action_by_path(
                    '/action/testrelative/relative'
                  );

is($dispatcher->uri_for_action($path_action), "/action/relative/relative",
   "Public path action returns correct URI");

ok(!defined($dispatcher->uri_for_action($path_action, [ 'foo' ])),
   "no URI returned for Path action when snippets are given");

my $regex_action = $dispatcher->get_action_by_path(
                     '/action/regexp/one'
                   );

ok(!defined($dispatcher->uri_for_action($regex_action)),
   "Regex action without captures returns undef");

ok(!defined($dispatcher->uri_for_action($regex_action, [ 1, 2, 3 ])),
   "Regex action with too many captures returns undef");

is($dispatcher->uri_for_action($regex_action, [ 'foo', 123 ]),
   "/action/regexp/foo/123",
   "Regex action interpolates captures correctly");

my $index_action = $dispatcher->get_action_by_path(
                     '/action/index/index'
                   );

ok(!defined($dispatcher->uri_for_action($index_action, [ 'foo' ])),
   "no URI returned for index action when snippets are given");

is($dispatcher->uri_for_action($index_action),
   "/action/index",
   "index action returns correct path");

my $chained_action = $dispatcher->get_action_by_path(
                       '/action/chained/endpoint',
                     );

ok(!defined($dispatcher->uri_for_action($chained_action)),
   "Chained action without captures returns undef");

ok(!defined($dispatcher->uri_for_action($chained_action, [ 1, 2 ])),
   "Chained action with too many captures returns undef");

is($dispatcher->uri_for_action($chained_action, [ 1 ]),
   "/chained/foo/1/end",
   "Chained action with correct captures returns correct path");

my $request = Catalyst::Request->new( {
                base => URI->new('http://127.0.0.1/foo')
              } );

my $context = TestApp->new( {
                request => $request,
                namespace => 'yada',
              } );

is($context->uri_for($path_action),
   "http://127.0.0.1/foo/action/relative/relative",
   "uri_for correct for path action");

is($context->uri_for($path_action, qw/one two/, { q => 1 }),
   "http://127.0.0.1/foo/action/relative/relative/one/two?q=1",
   "uri_for correct for path action with args and query");

ok(!defined($context->uri_for($path_action, [ 'blah' ])),
   "no URI returned by uri_for for Path action with snippets");

is($context->uri_for($regex_action, [ 'foo', 123 ], qw/bar baz/, { q => 1 }),
   "http://127.0.0.1/foo/action/regexp/foo/123/bar/baz?q=1",
   "uri_for correct for regex with captures, args and query");

is($context->uri_for($chained_action, [ 1 ], 2, { q => 1 }),
   "http://127.0.0.1/foo/chained/foo/1/end/2?q=1",
   "uri_for correct for chained with captures, args and query");
