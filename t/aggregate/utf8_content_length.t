use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use File::Spec;
use Test::More;

use Catalyst::Test qw/TestAppEncoding/;

if ( $ENV{CATALYST_SERVER} ) {
    plan skip_all => 'This test does not run live';
    exit 0;
}

my $fn = "$Bin/../catalyst_130pix.gif";
ok -r $fn, 'Can read catalyst_130pix.gif';
my $size = -s $fn;
{
    my $r = request('/binary');
    is $r->code, 200, '/binary OK';
    is $r->header('Content-Length'), $size, '/binary correct content length';
}
SKIP: {
    # Test that even if what is really binary has been upgraded into character
    # octets in perl, then when we output it we get the correct content length.
    # The issue was initially described in the thread 'Avoiding UTF8 in
    # Catalyst': http://lists.scsys.co.uk/pipermail/catalyst/2009-November/023912.html.
    # FIXME! (See ml thread re 5.80015 release)
    skip 'Known not to work on Win32', 2 if ($^O eq 'MSWin32');
    my $r = request('/binary_utf8');
    is $r->code, 200, '/binary_utf8 OK';
    is $r->header('Content-Length'), $size, '/binary_utf8 correct content length';
}

done_testing;

