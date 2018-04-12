package ChainedActionsApp;
use Moose;
use TestLogger;

use Catalyst::Runtime 5.80;

use Catalyst qw//;

use namespace::clean -except => [ 'meta' ];

extends 'Catalyst';

our $VERSION = "0.01";
$VERSION = eval $VERSION;

__PACKAGE__->config(
  name => 'ChainedActionsApp',
  disable_component_regex_fallback => 1,
);

__PACKAGE__->log(TestLogger->new);

__PACKAGE__->setup;

1;
