#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Test::More tests => 2;
use Test::Exception;

lives_ok {
    require TestAppClassExceptionSimpleTest;
} 'Can load application';


lives_ok {
    Catalyst::Exception->throw
} 'throw is properly stubbed out';



