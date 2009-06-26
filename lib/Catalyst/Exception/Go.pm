package Catalyst::Exception::Go;

use Moose;
use namespace::clean -except => 'meta';

extends 'Catalyst::Exception';

has '+message' => (
    default => "catalyst_go\n",
);

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Catalyst::Exception::Go - Exception for redispatching using $ctx->go()

=cut
