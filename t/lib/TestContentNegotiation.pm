package TestContentNegotiation;

use Moose;
use Catalyst;

extends 'Catalyst';

__PACKAGE__->config(
  'Controller::Root', { namespace => '' },
);

__PACKAGE__->setup;

