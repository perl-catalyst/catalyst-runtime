use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$FindBin::Bin/../lib";
use Test::More;
use URI;

use_ok('TestApp');

my $request = Catalyst::Request->new( {
                _log => Catalyst::Log->new,
                base => URI->new('http://127.0.0.1/foo')
              } );
my $dispatcher = TestApp->dispatcher;
my $context = TestApp->new( {
                request => $request,
                namespace => 'yada',
              } );

is(
    Catalyst::uri_for( $context, '/bar/baz' )->as_string,
    'http://127.0.0.1/foo/bar/baz',
    'URI for absolute path'
);

is(
    Catalyst::uri_for( $context, 'bar/baz' )->as_string,
    'http://127.0.0.1/foo/yada/bar/baz',
    'URI for relative path'
);

is(
    Catalyst::uri_for( $context, '', 'arg1', 'arg2' )->as_string,
    'http://127.0.0.1/foo/yada/arg1/arg2',
    'URI for undef action with args'
);


is( Catalyst::uri_for( $context, '../quux' )->as_string,
    'http://127.0.0.1/foo/quux', 'URI for relative dot path' );

is(
    Catalyst::uri_for( $context, 'quux', { param1 => 'value1' } )->as_string,
    'http://127.0.0.1/foo/yada/quux?param1=value1',
    'URI for undef action with query params'
);

is (Catalyst::uri_for( $context, '/bar/wibble?' )->as_string,
   'http://127.0.0.1/foo/bar/wibble%3F', 'Question Mark gets encoded'
);

is( Catalyst::uri_for( $context, qw/bar wibble?/, 'with space' )->as_string,
    'http://127.0.0.1/foo/yada/bar/wibble%3F/with%20space', 'Space gets encoded'
);

is(
    Catalyst::uri_for( $context, '/bar', 'with+plus', { 'also' => 'with+plus' })->as_string,
    'http://127.0.0.1/foo/bar/with+plus?also=with%2Bplus',
    'Plus is not encoded'
);

is(
    Catalyst::uri_for( $context, '/bar', 'with space', { 'also with' => 'space here' })->as_string,
    'http://127.0.0.1/foo/bar/with%20space?also+with=space+here',
    'Spaces encoded correctly'
);

is(
    Catalyst::uri_for( $context, '/bar#fragment', { param1 => 'value1' } )->as_string,
    'http://127.0.0.1/foo/bar?param1=value1#fragment',
    'URI for path with fragment and query params 1'
);

is(
    Catalyst::uri_for( $context, '/bar', { param1 => 'value1' }, \'fragment' )->as_string,
    'http://127.0.0.1/foo/bar?param1=value1#fragment',
    'URI for path with fragment and query params 1'
);

is(
    Catalyst::uri_for( $context, '0#fragment', { param1 => 'value1' } )->as_string,
    'http://127.0.0.1/foo/yada/0?param1=value1#fragment',
    'URI for path 0 with fragment and query params 1'
);

is(
    Catalyst::uri_for( $context, '/bar#fragment^%$', { param1 => 'value1' } )->as_string,
    'http://127.0.0.1/foo/bar?param1=value1#fragment^%$',
    'URI for path with fragment and query params 3'
);

is(
    Catalyst::uri_for( $context, '/foo#bar/baz', { param1 => 'value1' } )->as_string,
    'http://127.0.0.1/foo/foo?param1=value1#bar/baz',
    'URI for path with fragment and query params 3'
);

is(
    Catalyst::uri_for( 'TestApp', '/bar/baz' )->as_string,
    '/bar/baz',
    'URI for absolute path, called with only class name'
);

## relative action (or path) doesn't make sense when calling as class method
# is(
#     Catalyst::uri_for( 'TestApp', 'bar/baz' )->as_string,
#     '/yada/bar/baz',
#     'URI for relative path, called with only class name'
# );

is(
    Catalyst::uri_for( 'TestApp', '/', 'arg1', 'arg2' )->as_string,
    '/arg1/arg2',
    'URI for root action with args, called with only class name'
);

## relative action (or path) doesn't make sense when calling as class method
# is( Catalyst::uri_for( 'TestApp', '../quux' )->as_string,
#     '/quux', 'URI for relative dot path, called with only class name' );

is(
    Catalyst::uri_for( 'TestApp', '/quux', { param1 => 'value1' } )->as_string,
    '/quux?param1=value1',
    'URI for quux action with query params, called with only class name'
);

is (Catalyst::uri_for( 'TestApp', '/bar/wibble?' )->as_string,
   '/bar/wibble%3F', 'Question Mark gets encoded, called with only class name'
);

## relative action (or path) doesn't make sense when calling as class method
# is( Catalyst::uri_for( 'TestApp', qw/bar wibble?/, 'with space' )->as_string,
#     '/yada/bar/wibble%3F/with%20space', 'Space gets encoded, called with only class name'
# );

is(
    Catalyst::uri_for( 'TestApp', '/bar', 'with+plus', { 'also' => 'with+plus' })->as_string,
    '/bar/with+plus?also=with%2Bplus',
    'Plus is not encoded, called with only class name'
);

is(
    Catalyst::uri_for( 'TestApp', '/bar', 'with space', { 'also with' => 'space here' })->as_string,
    '/bar/with%20space?also+with=space+here',
    'Spaces encoded correctly, called with only class name'
);

TODO: {
    local $TODO = 'broken by 5.7008';
    is(
        Catalyst::uri_for( $context, '/bar#fragment', { param1 => 'value1' } )->as_string,
        'http://127.0.0.1/foo/bar?param1=value1#fragment',
        'URI for path with fragment and query params'
    );
}

# test with utf-8
is(
    Catalyst::uri_for( $context, 'quux', { param1 => "\x{2620}" } )->as_string,
    'http://127.0.0.1/foo/yada/quux?param1=%E2%98%A0',
    'URI for undef action with query params in unicode'
);
is(
    Catalyst::uri_for( $context, 'quux', { 'param:1' => "foo" } )->as_string,
    'http://127.0.0.1/foo/yada/quux?param%3A1=foo',
    'URI for undef action with query params in unicode'
);

# test with object
is(
    Catalyst::uri_for( $context, 'quux', { param1 => $request->base } )->as_string,
    'http://127.0.0.1/foo/yada/quux?param1=http%3A%2F%2F127.0.0.1%2Ffoo',
    'URI for undef action with query param as object'
  );

# test with empty arg
{
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    is(
       Catalyst::uri_for( $context )->as_string,
       'http://127.0.0.1/foo/yada',
       'URI with no action'
      );

    is(
       Catalyst::uri_for( $context, 0 )->as_string,
       'http://127.0.0.1/foo/yada/0',
       'URI with 0 path'
      );

    is_deeply(\@warnings, [], "No warnings with no path argument");
}

$request->base( URI->new('http://localhost:3000/') );
$request->match( 'orderentry/contract' );
is(
    Catalyst::uri_for( $context, '/Orderentry/saveContract' )->as_string,
    'http://localhost:3000/Orderentry/saveContract',
    'URI for absolute path'
);

{
    $request->base( URI->new('http://127.0.0.1/') );

    $context->namespace('');

    is( Catalyst::uri_for( $context, '/bar/baz' )->as_string,
        'http://127.0.0.1/bar/baz', 'URI with no base or match' );

    # test "0" as the path
    is( Catalyst::uri_for( $context, qw/0 foo/ )->as_string,
        'http://127.0.0.1/0/foo', '0 as path is ok'
    );

}

# test with undef -- no warnings should be thrown
{
    my $warnings = 0;
    local $SIG{__WARN__} = sub { $warnings++ };

    Catalyst::uri_for( $context, '/bar/baz', { foo => undef } )->as_string,
    is( $warnings, 0, "no warnings emitted" );
}

# Test with parameters '/', 'foo', 'bar' - should not generate a //
is( Catalyst::uri_for( $context, qw| / foo bar | )->as_string,
    'http://127.0.0.1/foo/bar', 'uri is /foo/bar, not //foo/bar'
);

TODO: {
    local $TODO = 'RFCs are for people who, erm - fix this test..';
    # Test rfc3986 reserved characters.  These characters should all be escaped
    # according to the RFC, but it is a very big feature change so I've removed it
    no warnings; # Yes, everything in qw is sane
    is(
        Catalyst::uri_for( $context, qw|! * ' ( ) ; : @ & = $ / ? % # [ ] ,|, )->as_string,
        'http://127.0.0.1/%21/%2A/%27/%2B/%29/%3B/%3A/%40/%26/%3D/%24/%2C/%2F/%3F/%25/%23/%5B/%5D',
        'rfc 3986 reserved characters'
    );

    # jshirley bug - why the hell does only one of these get encoded
    #                has been like this forever however.
    is(
        Catalyst::uri_for( $context, qw|{1} {2}| )->as_string,
        'http://127.0.0.1/{1}/{2}',
        'not-escaping unreserved characters'
    );
}

# make sure caller's query parameter hash isn't messed up
{
    my $query_params_base = {test => "one two",
                             bar  => ["foo baz", "bar"]};
    my $query_params_test = {test => "one two",
                             bar  => ["foo baz", "bar"]};
    Catalyst::uri_for($context, '/bar/baz', $query_params_test);
    is_deeply($query_params_base, $query_params_test,
              "uri_for() doesn't mess up query parameter hash in the caller");
}


{
    my $path_action = $dispatcher->get_action_by_path(
                       '/action/path/six'
                     );

    # 5.80018 is only encoding the first of the / in the arg.
    is(
        Catalyst::uri_for( $context, $path_action, 'foo/bar/baz' )->as_string,
        'http://127.0.0.1/action/path/six/foo%2Fbar%2Fbaz',
        'Escape all forward slashes in args as %2F'
    );
}

{
    my $index_not_private = $dispatcher->get_action_by_path(
                             '/action/chained/argsorder/index'
                            );

    is(
      Catalyst::uri_for( $context, $index_not_private )->as_string,
      'http://127.0.0.1/argsorder',
      'Return non-DispatchType::Index path for index action with args'
    );
}

{
    package MyStringThing;

    use overload '""' => sub { $_[0]->{string} }, fallback => 1;
}

is(
    Catalyst::uri_for( $context, bless( { string => 'test' }, 'MyStringThing' ) ),
    'http://127.0.0.1/test',
    'overloaded object handled correctly'
);

is(
    Catalyst::uri_for( $context, bless( { string => 'test' }, 'MyStringThing' ), \'fragment' ),
    'http://127.0.0.1/test#fragment',
    'overloaded object handled correctly'
);

done_testing;
