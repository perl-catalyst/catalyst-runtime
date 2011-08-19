use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use TestApp;
use Catalyst::Test ();

{
    like do {
        my $warning;
        local $SIG{__WARN__} = sub { $warning = $_[0] };
        isa_ok Catalyst::Test::local_request('TestApp', '/'), 'HTTP::Response';
        $warning;
    }, qr/deprecated/, 'local_request is deprecated';
}

done_testing;
