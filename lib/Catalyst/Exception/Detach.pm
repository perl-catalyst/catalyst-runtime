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

=head1 SYNOPSIS

   Do not use this class directly, instead you should use the singleton instance
   found in $Catalyst::DETACH;
   
   E.g. die $Catalyst::DETACH
   
See also L<Catalyst> and L<Catalyst::Exception>.

=head1 DESCRIPTION

This is the class for the Catalyst Exception which is thrown then you call
C<< $c->detach() >>. There should be a singleton instance of this class in the
C<< $Catalyst::DETACH >> global variable.

Users should never need to know or care about this exception, please just use
C<< $c->detach >>

=head2 meta

Provided by Moose

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
