package TestAppIndexDefault;
use strict;
use warnings;
use TestLogger;
use Catalyst;

__PACKAGE__->log(TestLogger->new);

__PACKAGE__->setup;

1;
