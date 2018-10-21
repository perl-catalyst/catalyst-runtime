use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Test::More tests => 1;

use Catalyst ();
eval {
    require TestAppUnknownError;
};
unlike($@, qr/Unknown error/, 'No unknown error');

1;

