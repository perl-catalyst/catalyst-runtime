package Catalyst::DispatchType::Default;

use strict;
use base qw/Catalyst::DispatchType/;

=head1 NAME

Catalyst::DispatchType::Default - Default DispatchType

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item $self->match( $c, $path )

=cut

sub match {
    my ( $self, $c, $path ) = @_;
    return if $path =~ m!/!;    # Not at root yet, wait for it ...
    my $result = ( $c->get_actions( 'default', $c->req->path ) )[-1];

    # Find default on namespace or super
    if ($result) {
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

=back

=head1 AUTHOR

Matt S Trout
Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
