use strict;
use warnings;

use File::Spec;
use FindBin ();
use Test::More;

if ( !-e "$FindBin::Bin/../MANIFEST.SKIP" ) {
    plan skip_all => 'Critic test only for developers.';
}
else {
    eval { require Test::NoTabs };
    if ( $@ ) {
        plan tests => 1;
        fail( 'You must install Test::NoTabs to run 04critic.t' );
        exit;
    }
}

Test::NoTabs->import;
all_perl_files_ok(qw/lib/);
