package Catalyst::DispatchType::Index;

use strict;
use base qw/Catalyst::DispatchType/;

=head1 NAME

Catalyst::DispatchType::Index - Index DispatchType

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

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

    if ($result && $result->match($c)) {
        $c->action($result);
        $c->namespace( $result->namespace );
        $c->req->action('index');
        $c->req->match( $c->req->path );
        return 1;
    }
    return 0;
}

=head2 $self->uri_for_action( $action, $captures )

get a URI part for an action; always returns undef is $captures is set
since index actions don't have captures

=cut

sub uri_for_action {
    my ( $self, $action, $captures ) = @_;

    return undef if @$captures;

    return undef unless $action->name eq 'index';

    return "/".$action->namespace;
}

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
