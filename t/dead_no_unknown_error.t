#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Test::More tests => 1;

use Catalyst ();
use Catalyst::Engine::HTTP;
eval {
    require TestAppUnknownError;
};
unlike($@, qr/Unknown error/, 'No unknown error');

1;

