package TestAppEncodingSetInPlugin;
use Moose;

use Catalyst qw/+TestAppEncodingSetInPlugin::SetEncoding/;

extends 'Catalyst';

__PACKAGE__->setup;

1;
