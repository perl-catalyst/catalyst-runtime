use strict;
use warnings;
no warnings 'once';
use FindBin qw/$Bin/;
use lib "$Bin/lib";

use Test::More;

use File::Spec;
use File::Temp qw/ tempdir /;

my $temp;
BEGIN {
    $temp = tempdir( CLEANUP => 1 );

    $ENV{CATALYST_HOME} = $temp;
    open(my $psgi, '>', File::Spec->catdir($temp, 'testapp.psgi')) or die;
    print $psgi q{
        use strict;
        use TestApp;

        $main::have_loaded_psgi = 1;
        TestApp->setup_engine('PSGI');
        my $app = sub { TestApp->run(@_) };
    };
    close($psgi);
}
use Catalyst::Test qw/ TestApp /;

ok !$main::have_loaded_psgi, 'legacy psgi file got ignored';

like do {
    my $warning;
    local $SIG{__WARN__} = sub { $warning = $_[0] };
    ok request('/');
    $warning;
}, qr/ignored/, 'legacy psgi files raise a warning';

done_testing;

