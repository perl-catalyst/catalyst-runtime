package Catalyst::Model;

use Moose;
extends qw/Catalyst::Component/;

no Moose;

=head1 NAME

Catalyst::Model - Catalyst Model base class

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

Catalyst Model base class.

=head1 METHODS

Implements the same methods as other Catalyst components, see
L<Catalyst::Component>

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
