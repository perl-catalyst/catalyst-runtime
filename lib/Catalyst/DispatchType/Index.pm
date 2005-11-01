package Catalyst::DispatchType::Index;

use strict;
use base qw/Catalyst::DispatchType/;

=head1 NAME

Catalyst::DispatchType::Index - Index DispatchType

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item $self->match( $c, $path )

=cut

sub match {
    my ( $self, $c, $path ) = @_;
    return if @{ $c->req->args };
    my $result = $c->get_action( 'index', $path );

    if ($result) {
        $c->action( $result );
        $c->namespace( $result->namespace );
        $c->req->action('index');
        $c->req->match( $c->req->path );
        return 1;
    }
    return 0;
}

=back

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
