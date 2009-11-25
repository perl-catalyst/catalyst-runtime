use strict;
use warnings;

use Test::More;

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

if(  $os ne 'Unix' ) {
    plan skip_all => 'tests require Unix';
}
else {
    plan tests => 3;
}

use_ok('Catalyst');

my $context = 'Catalyst';

my $config = Catalyst->config;

$config->{home} = '/home/sri/my-app/';

is( Catalyst::path_to( $context, 'foo' ), '/home/sri/my-app/foo', 'Unix path' );

$config->{home} = '/Users/sri/myapp/';

is( Catalyst::path_to( $context, 'foo', 'bar' ),
    '/Users/sri/myapp/foo/bar', 'deep Unix path' );
