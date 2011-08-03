use warnings;
use strict;
use FindBin '$Bin';
use lib "$Bin/../lib";
use TestCustomContainer;
use Test::More skip_all => 'Sugar not implemented';

TestCustomContainer->new(sugar => 1);
