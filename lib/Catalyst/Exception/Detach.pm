package Catalyst::Exception::Detach;

use Moose;
use namespace::clean -except => 'meta';

with 'Catalyst::Exception::Basic';

has '+message' => (
    default => "catalyst_detach\n",
);

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Catalyst::Exception::Detach - Exception for redispatching using $ctx->detach()

=cut
