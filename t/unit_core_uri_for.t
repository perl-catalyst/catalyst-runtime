use strict;
use warnings;

use Test::More tests => 17;
use URI;

use_ok('Catalyst');

my $request = Catalyst::Request->new( {
                base => URI->new('http://127.0.0.1/foo')
              } );

my $context = Catalyst->new( {
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

