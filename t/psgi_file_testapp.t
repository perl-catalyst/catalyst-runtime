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
        my $app = TestApp->psgi_app;
    };
    close($psgi);
}
use Catalyst::Test qw/ TestApp /;

ok request('/');
ok $main::have_loaded_psgi;

done_testing;

