package Catalyst::Engine::CGI::NPH;

use strict;
use base 'Catalyst::Engine::CGI';

=head1 NAME

Catalyst::Engine::CGI::NPH - Catalyst CGI Engine

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This Catalyst engine returns a complete HTTP response message.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::CGI>.

=over 4

=item $c->finalize_headers

=cut

sub finalize_headers {
    my $c = shift;
    my %headers = ( -nph => 1 );
    $headers{-status} = $c->response->status if $c->response->status;
    for my $name ( $c->response->headers->header_field_names ) {
        $headers{"-$name"} = $c->response->headers->header($name);
    }
    my @cookies;
    while ( my ( $name, $cookie ) = each %{ $c->response->cookies } ) {
        push @cookies, $c->cgi->cookie(
            -name    => $name,
            -value   => $cookie->{value},
            -expires => $cookie->{expires},
            -domain  => $cookie->{domain},
            -path    => $cookie->{path},
            -secure  => $cookie->{secure} || 0
        );
    }
    $headers{-cookie} = \@cookies if @cookies;
    print $c->cgi->header(%headers);
}

=back

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine::CGI>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
