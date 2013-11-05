package TestFromPSGI;

use Moose;
use Catalyst;

__PACKAGE__->config(
  'Controller::Root', { namespace => '' },
  use_hash_multivalue_in_request => 1,
);

__PACKAGE__->setup;

