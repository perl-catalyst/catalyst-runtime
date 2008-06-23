package Catalyst::DispatchType::Default;

use Class::C3;
use Moose;
extends 'Catalyst::DispatchType';

no Moose;

=head1 NAME

Catalyst::DispatchType::Default - Default DispatchType

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=head2 $self->match( $c, $path )

If path is empty (i.e. all path parts have been converted into args),
attempts to find a default for the namespace constructed from the args,
or the last inherited default otherwise and will match that.

If path is not empty, never matches since Default will only match if all
other possibilities have been exhausted.

=cut

sub match {
    my ( $self, $c, $path ) = @_;
    return if $path =~ m!/!;    # Not at root yet, wait for it ...
    my $result = ( $c->get_actions( 'default', $c->req->path ) )[-1];

    # Find default on namespace or super
    if ($result && $result->match($c)) {
        $c->action($result);
        $c->namespace( $result->namespace );
        $c->req->action('default');

        # default methods receive the controller name as the first argument
        unshift @{ $c->req->args }, $path if $path;
        $c->req->match('');
        return 1;
    }
    return 0;
}

=head1 AUTHOR

Matt S Trout
Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
