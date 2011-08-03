use warnings;
use strict;
use FindBin '$Bin';
use lib "$Bin/../lib";
use TestCustomContainer;

TestCustomContainer->new(sugar => 0);
