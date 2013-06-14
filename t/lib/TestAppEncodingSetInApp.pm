package TestAppEncodingSetInApp;
use Moose;

use Catalyst;

extends 'Catalyst';

__PACKAGE__->config(
    encoding => 'UTF-8',
);

__PACKAGE__->setup;

1;
