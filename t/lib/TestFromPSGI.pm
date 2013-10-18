package TestFromPSGI;

use Moose;
use Catalyst;

__PACKAGE__->config(
  'Controller::Root', { namespace => '' },
);

__PACKAGE__->setup;

