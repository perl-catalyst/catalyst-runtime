package Catalyst::DispatchType::Index;

use Moose;
extends 'Catalyst::DispatchType';
use namespace::clean -except => 'meta';

=head1 NAME

Catalyst::DispatchType::Index - Index DispatchType

=head1 SYNOPSIS

See L<Catalyst::DispatchType>.

=head1 DESCRIPTION

Dispatch type managing behaviour for index pages.  For more information on
dispatch types, see:

=over 4

=item * L<Catalyst::Manual::Intro> for how they affect application authors

=item * L<Catalyst::DispatchType> for implementation information.

=back

=cut

has _actions => (
    is => 'rw', isa => 'HashRef', default => sub { +{} }
);

=head1 METHODS

=head2 $self->match( $c, $path )

Check if there's an index action for a given path, and set it up to use it
if there is; only matches a full URI - if $c->req->args is already set
this DispatchType is guaranteed not to match.

=cut

sub match {
    my ( $self, $c, $path ) = @_;
    return if @{ $c->req->args };
    my $result = $c->get_action( 'index', $path );

    return 0 unless $result && exists $self->_actions->{ $result->reverse };

    if ($result && $result->match($c)) {
        $c->action($result);
        $c->namespace( $result->namespace );
        $c->req->action('index');
        $c->req->match( $c->req->path );
        return 1;
    }
    return 0;
}

=head2 $self->register( $c, $action )

Register an action with this DispatchType.

=cut

sub register {
    my ( $self, $c, $action ) = @_;

    $self->_actions->{ $action->reverse } = $action if $action->name eq 'index';

    return 1;
}

=head2 $self->uri_for_action( $action, $captures )

get a URI part for an action; always returns undef is $captures is set
since index actions don't have captures

=cut

sub uri_for_action {
    my ( $self, $action, $captures ) = @_;

    return undef if @$captures;

    return undef unless exists $self->_actions->{ $action->reverse };

    return "/".$action->namespace;
}

sub _is_low_precedence { 1 }

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
