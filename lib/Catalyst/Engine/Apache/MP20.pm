package Catalyst::Engine::Apache::MP20;

use strict;
use base 'Catalyst::Engine::Apache';

use Apache2::Connection  ();
use Apache2::Const       ();
use Apache2::RequestIO   ();
use Apache2::RequestRec  ();
use Apache2::RequestUtil ();
use Apache2::Request     ();
use Apache2::Cookie      ();
use Apache2::Upload      ();
use Apache2::URI         ();
use APR::URI             ();

Apache2::Const->import( -compile => ':common' );

=head1 NAME

Catalyst::Engine::Apache::MP20 - Catalyst Apache MP20 Engine

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is the Catalyst engine specialized for Apache mod_perl version 2.0.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::Apache>.

=over 4

=item $c->finalize_headers

=cut

sub finalize_headers {
    my $c = shift;

    for my $name ( $c->response->headers->header_field_names ) {
        next if $name =~ /Content-Type/i;
        my @values = $c->response->header($name);
        $c->apache->headers_out->add( $name => $_ ) for @values;
    }

    if ( $c->response->header('Set-Cookie') && $c->response->status >= 300 ) {
        my @values = $c->response->header('Set-Cookie');
        $c->apache->err_headers_out->add( 'Set-Cookie' => $_ ) for @values;
    }

    $c->apache->status( $c->response->status );
    $c->apache->content_type( $c->response->header('Content-Type') );

    return 0;
}

=item $c->handler

=cut

sub handler : method {
    shift->SUPER::handler(@_);
}

=item $c->prepare_request($r)

=cut

sub prepare_request {
    my ( $c, $r ) = @_;
    $c->apache( Apache2::Request->new($r) );
}

=item $c->prepare_uploads

=cut

sub prepare_uploads {
    my $c = shift;

    my @uploads;

    $c->apache->upload->do( sub {
        my ( $field, $upload ) = @_;

        my $object = Catalyst::Request::Upload->new(
            filename => $upload->filename,
            size     => $upload->size,
            tempname => $upload->tempname,
            type     => $upload->type
        );

        push( @uploads, $field, $object );

        return 1;
    });

    $c->request->_assign_values( $c->req->uploads, \@uploads );
}

=back

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine>, L<Catalyst::Engine::Apache>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
