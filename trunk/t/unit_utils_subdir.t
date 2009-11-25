use Test::More tests => 8;

use strict;
use warnings;

# simulates an entire testapp rooted at t/something
# except without bothering creating it since it's
# only the -e check on the Makefile.PL that matters

BEGIN { use_ok 'Catalyst::Utils' }
use FindBin;
use Path::Class::Dir;

{
    $INC{'TestApp.pm'} = "$FindBin::Bin/something/script/foo/../../lib/TestApp.pm";
    my $home = Catalyst::Utils::home('TestApp');
    like($home, qr{t[\/\\]something}, "has path TestApp/t/something");
    unlike($home, qr{[\/\\]script[\/\\]foo}, "doesn't have path /script/foo");
}

{
    $INC{'TestApp.pm'} = "$FindBin::Bin/something/script/foo/bar/../../../lib/TestApp.pm";
    my $home = Catalyst::Utils::home('TestApp');
    like($home, qr{t[\/\\]something}, "has path TestApp/t/something");
    unlike($home, qr{[\/\\]script[\/\\]foo[\/\\]bar}, "doesn't have path /script/foo/bar");
}

{
    $INC{'TestApp.pm'} = "$FindBin::Bin/something/script/../lib/TestApp.pm";
    my $home = Catalyst::Utils::home('TestApp');
    like($home, qr{t[\/\\]something}, "has path TestApp/t/something");
    unlike($home, qr{[\/\\]script[\/\\]foo}, "doesn't have path /script/foo");
}

{
    $INC{'TestApp.pm'} = "TestApp.pm";
    my $dir = "$FindBin::Bin/something";
    chdir( $dir );

    my $home = Catalyst::Utils::home('TestApp');

    $dir = Path::Class::Dir->new( $dir );
    is( $home, "$dir", 'same dir loading' );
}
