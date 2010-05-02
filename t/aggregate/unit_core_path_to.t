use strict;
use warnings;

use Test::More;
use FindBin;
use Path::Class;
use File::Basename;

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

if ( $os ne 'Unix' ) {
    plan skip_all => 'tests require Unix';
}

use_ok('Catalyst');

my $context = 'Catalyst';

$context->setup_home;
my $base = dir($FindBin::Bin)->relative->stringify;

isa_ok( Catalyst::path_to( $context, $base ), 'Path::Class::Dir' );
isa_ok( Catalyst::path_to( $context, $base, basename $0 ), 'Path::Class::File' );

my $config = Catalyst->config;

$config->{home} = '/home/sri/my-app/';

is( Catalyst::path_to( $context, 'foo' ), '/home/sri/my-app/foo', 'Unix path' );

$config->{home} = '/Users/sri/myapp/';

is( Catalyst::path_to( $context, 'foo', 'bar' ),
    '/Users/sri/myapp/foo/bar', 'deep Unix path' );

done_testing;
