use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;

use_ok('TestAppContainer');

is( TestAppContainer->controller('Config')->{foo}, 'foo', 'config ok' );

ok( TestAppContainer->config->{cache} !~ /^__HOME__/,
    'home dir substituted in config var'
);

is( TestAppContainer->config->{foo}, 'bar', 'app finalize_config works' );

my $home = TestAppContainer->config->{ home };
my $path = join ',',
    $home, TestAppContainer->path_to( 'x' ),
    $home, TestAppContainer->path_to( 'y' );
is( TestAppContainer->config->{multi}, $path, 'vars substituted in config var, twice' );

done_testing;
