use strict;
use warnings;

use Test::More;
use FindBin;
use Path::Class;
use File::Basename;
BEGIN {
    delete $ENV{CATALYST_HOME}; # otherwise it'll set itself up to the wrong place
}
use lib "$FindBin::Bin/../lib";
use TestApp;

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

my $context = 'TestApp';
my $base;

isa_ok( $base = Catalyst::path_to( $context, '' ), 'Path::Class::Dir' );

my $config = Catalyst->config;

is( Catalyst::path_to( $context, 'foo' ), "$base/foo", 'Unix path' );

is( Catalyst::path_to( $context, 'foo', 'bar' ),
    "$base/foo/bar", 'deep Unix path' );

done_testing;
