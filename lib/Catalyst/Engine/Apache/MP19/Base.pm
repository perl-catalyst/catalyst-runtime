package Catalyst::Engine::Apache::MP19::Base;

use strict;
use base 'Catalyst::Engine::Apache::Base';

use Apache2             ();
use Apache::Connection  ();
use Apache::Const       ();
use Apache::RequestIO   ();
use Apache::RequestRec  ();
use Apache::RequestUtil ();
use Apache::Response    ();

Apache::Const->import( -compile => ':common' );

=head1 NAME

Catalyst::Engine::Apache::MP19::Base - Base class for MP 1.9 Engines

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is a base class for MP 1.99 Engines.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::Apache::Base>.

=over 4

=item $c->finalize_headers

=cut

sub finalize_headers {
    my $c = shift;

    for my $name ( $c->response->headers->header_field_names ) {
        next if $name =~ /^Content-(Length|Type)$/i;
        my @values = $c->response->header($name);
        $c->apache->headers_out->add( $name => $_ ) for @values;
    }

    if ( $c->response->header('Set-Cookie') && $c->response->status >= 300 ) {
        my @values = $c->response->header('Set-Cookie');
        $c->apache->err_headers_out->add( 'Set-Cookie' => $_ ) for @values;
    }

    $c->apache->status( $c->response->status );

    if ( my $type = $c->response->header('Content-Type') ) {
        $c->apache->content_type($type);
    }

    if ( my $length = $c->response->content_length ) {
        $c->apache->set_content_length($length);
    }

    return 0;
}

=item $c->handler

=cut

sub handler : method {
    shift->SUPER::handler(@_);
}

=back

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine>, L<Catalyst::Engine::Apache::Base>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
