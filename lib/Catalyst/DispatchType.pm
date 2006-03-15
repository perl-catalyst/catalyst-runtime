package Catalyst::DispatchType;

use strict;
use base 'Class::Accessor::Fast';

=head1 NAME

Catalyst::DispatchType - DispatchType Base Class

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=head2 $self->list($c)

abstract method, to be implemented by dispatchtypes. Called to display
info in debug log.

=cut

sub list { }

=head2 $self->match( $c, $path )

abstract method, to be implemented by dispatchtypes. Returns true if the
dispatch type matches the given path

=cut

sub match { die "Abstract method!" }

=head2 $self->register( $c, $action )

abstract method, to be implemented by dispatchtypes. Takes a
context object and a L<Catalyst::Action> object. 

Should return true if it registers something, or false otherwise.

=cut

sub register { }

=head1 AUTHOR

Matt S Trout
Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
