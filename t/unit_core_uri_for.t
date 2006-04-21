use strict;
use warnings;

use Test::More tests => 9;
use Test::MockObject;
use URI;

my $request = Test::MockObject->new;
$request->mock( 'base', sub { URI->new('http://127.0.0.1/foo') } );

my $context = Test::MockObject->new;
$context->mock( 'request',   sub { $request } );
$context->mock( 'namespace', sub { 'yada' } );

use_ok('Catalyst');

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

# test with utf-8
is(
    Catalyst::uri_for( $context, 'quux', { param1 => "\x{2620}" } )->as_string,
    'http://127.0.0.1/foo/yada/quux?param1=%E2%98%A0',
    'URI for undef action with query params in unicode'
);

$request->mock( 'base',  sub { URI->new('http://localhost:3000/') } );
$request->mock( 'match', sub { 'orderentry/contract' } );
is(
    Catalyst::uri_for( $context, '/Orderentry/saveContract' )->as_string,
    'http://localhost:3000/Orderentry/saveContract',
    'URI for absolute path'
);

{
    $request->mock( 'base', sub { URI->new('http://127.0.0.1/') } );

    my $context = Test::MockObject->new;
    $context->mock( 'request',   sub { $request } );
    $context->mock( 'namespace', sub { '' } );

    is( Catalyst::uri_for( $context, '/bar/baz' )->as_string,
        'http://127.0.0.1/bar/baz', 'URI with no base or match' );
}

