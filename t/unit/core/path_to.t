use strict;
use warnings;

use Test::More tests => 3;
use Test::MockObject;

my %non_unix = (
    MacOS   => 1,
    MSWin32 => 1,
    os2     => 1,
    VMS     => 1,
    epoc    => 1,
    NetWare => 1,
    dos     => 1,
    cygwin  => 1
);

my $os = $non_unix{$^O} ? $^O : 'Unix';

plan skip_all => 'tests require Unix' unless $os eq 'Unix';

my $context = Test::MockObject->new;

use_ok('Catalyst');

$context->mock( 'config', sub { { home => '/home/sri/my-app/' } } );

is( Catalyst::path_to( $context, 'foo' ), '/home/sri/my-app/foo', 'Unix path' );

$context->mock( 'config', sub { { home => '/Users/sri/myapp' } } );

is( Catalyst::path_to( $context, 'foo', 'bar' ),
    '/Users/sri/myapp/foo/bar', 'deep Unix path' );
