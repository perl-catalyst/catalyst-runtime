use Test::More tests=>7;

use strict;
use warnings;

# simulates an entire testapp rooted at t/something
# except without bothering creating it since its
# only the -e check on the Makefile.PL that matters

BEGIN { use_ok 'Catalyst::Utils' }
use FindBin;

$INC{'TestApp.pm'} = "$FindBin::Bin/something/script/foo/../../lib/TestApp.pm";
my $home = Catalyst::Utils::home('TestApp');
like($home, qr/t\/something/, "has path TestApp/t/something"); 
unlike($home, qr/\/script\/foo/, "doesn't have path /script/foo");

$INC{'TestApp.pm'} = "$FindBin::Bin/something/script/foo/bar/../../../lib/TestApp.pm";
$home = Catalyst::Utils::home('TestApp');
like($home, qr/t\/something/, "has path TestApp/t/something"); 
unlike($home, qr/\/script\/foo\/bar/, "doesn't have path /script/foo");

$INC{'TestApp.pm'} = "$FindBin::Bin/something/script/../lib/TestApp.pm";
$home = Catalyst::Utils::home('TestApp');
like($home, qr/t\/something/, "has path TestApp/t/something"); 
unlike($home, qr/\/script\/foo/, "doesn't have path /script/foo");
