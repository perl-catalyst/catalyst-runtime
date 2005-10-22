package Catalyst::DispatchType;

use strict;
use base 'Class::Accessor::Fast';

=head1 NAME

Catalyst::DispatchType - DispatchType Base Class

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item $self->list($c)

=cut

sub list { }

=item $self->match( $c, $path )

=cut

sub match { die "Abstract method!" }

=item $self->register( $c, $action )

=cut

sub register { }

=back

=head1 AUTHOR

Matt S Trout
Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
