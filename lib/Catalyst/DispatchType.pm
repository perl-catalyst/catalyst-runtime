package Catalyst::DispatchType;

use Moose;
with 'MooseX::Emulate::Class::Accessor::Fast';
no Moose;

=head1 NAME

Catalyst::DispatchType - DispatchType Base Class

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is an abstract base class for Dispatch Types.

From a code perspective, dispatch types are used to find which actions
to call for a given request URL.  Website authors will typically work
with them via subroutine names attributes; a description of dispatch
at the attribute/URL level is given in L<Catalyst::Manual::Intro>.

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

=head2 $self->uri_for_action( $action, \@captures )

abstract method, to be implemented by dispatchtypes. Takes a
L<Catalyst::Action> object and an arrayref of captures, and should
return either a URI part which if placed in $c->req->path would cause
$self->match to match this action and set $c->req->captures to the supplied
arrayref, or undef if unable to do so.

=cut

sub uri_for_action { }

=head2 $self->expand_action

Default fallback, returns nothing. See L<Catalyst::Dispatcher> for more info
about expand_action.

=cut

sub expand_action { }

sub _is_low_precedence { 0 }

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
