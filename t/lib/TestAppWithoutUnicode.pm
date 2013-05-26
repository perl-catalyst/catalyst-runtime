package TestAppWithoutUnicode;
use strict;
use warnings;
use TestLogger;
use base qw/Catalyst/;
use Catalyst qw/Params::Nested/;

__PACKAGE__->config('name' => 'TestAppWithoutUnicode');

__PACKAGE__->log(TestLogger->new);

__PACKAGE__->setup;

1;
