use warnings;
use strict;
use FindBin '$Bin';
use lib "$Bin/../lib";
BEGIN {
    if ( $ENV{CATALYST_SERVER} ) {
        plan skip_all => 'This test does not run live';
        exit 0;
    }
}
use TestCustomContainer;

TestCustomContainer->new(sugar => 0);
