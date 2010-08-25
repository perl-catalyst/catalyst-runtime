package ChainedActionsApp;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;

use Catalyst qw//;

extends 'Catalyst';

our $VERSION = "0.01";
$VERSION = eval $VERSION;

__PACKAGE__->config(
  name => 'ChainedActionsApp',
  disable_component_regex_fallback => 1,
);

__PACKAGE__->setup;

1;
