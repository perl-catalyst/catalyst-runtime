package Catalyst::Exception::Go;

use Moose;
use namespace::clean -except => 'meta';

extends 'Catalyst::Exception';

has '+message' => (
    default => "catalyst_go\n",
);

__PACKAGE__->meta->make_immutable;

1;
