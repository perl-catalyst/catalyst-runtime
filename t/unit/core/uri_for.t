use strict;
use warnings;

use Test::More tests => 6;
use Test::MockObject;
use URI;

my $request = Test::MockObject->new;
$request->mock( 'base',  sub { URI->new('http://127.0.0.1/foo') } );
$request->mock( 'match', sub { '/yada' } );

my $context = Test::MockObject->new;
$context->mock( 'request', sub { $request } );

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

is( Catalyst::uri_for( $context, '../quux' )->as_string,
    'http://127.0.0.1/foo/quux', 'URI for relative dot path' );

$request->mock( 'base',  sub { URI->new('http://localhost:3000/') } );
$request->mock( 'match', sub { 'orderentry/contract' } );
is(
    Catalyst::uri_for( $context, '/Orderentry/saveContract' )->as_string,
    'http://localhost:3000/Orderentry/saveContract',
    'URI for absolute path'
);

{
    $request->mock( 'base',  sub { URI->new('http://127.0.0.1/') } );
    $request->mock( 'match', sub { '' } );

    my $context = Test::MockObject->new;
    $context->mock( 'request', sub { $request } );

    is( Catalyst::uri_for( $context, '/bar/baz' )->as_string,
        'http://127.0.0.1/bar/baz', 'URI with no base or match' );
}
