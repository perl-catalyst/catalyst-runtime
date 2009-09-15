#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Test::More tests => 1;
use Test::Exception;

TODO: {
    local $TODO = 'Does not work yet';

lives_ok {
    require TestAppClassExceptionSimpleTest;
} 'Can load application';

}

