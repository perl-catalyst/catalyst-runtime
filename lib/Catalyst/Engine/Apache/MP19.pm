package Catalyst::Engine::Apache::MP19;

use strict;
use base 'Catalyst::Engine::Apache';

use Apache2             ();
use Apache::Connection  ();
use Apache::Const       ();
use Apache::RequestIO   ();
use Apache::RequestRec  ();
use Apache::RequestUtil ();
use Apache::Request     ();
use Apache::Cookie      ();
use Apache::Upload      ();
use Apache::URI         ();
use APR::URI            ();

Apache::Const->import( -compile => ':common' );

=head1 NAME

Catalyst::Engine::Apache::MP2 - Catalyst Apache MP2 Engine

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is the Catalyst engine specialized for Apache mod_perl version 2.

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

=item $c->prepare_uploads

=cut

sub prepare_uploads {
    my $c = shift;

    my @uploads;

    for my $field ( $c->apache->upload ) {

        for my $upload ( $c->apache->upload($field) ) {

            my $object = Catalyst::Request::Upload->new(
                filename => $upload->filename,
                size     => $upload->size,
                tempname => $upload->tempname,
                type     => $upload->type
            );

            push( @uploads, $field, $object );
        }
    }

    $c->req->_assign_values( $c->req->uploads, \@uploads );
}

=back

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine>, L<Catalyst::Engine::Apache>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
