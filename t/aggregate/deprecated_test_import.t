use strict;
use warnings;

use Test::More;
use Catalyst::Test ();

my $warn;
{
    local $SIG{__WARN__} = sub { $warn = shift; };
    Catalyst::Test->import();
}
ok $warn;
like $warn, qr/deprecated/;

done_testing;

