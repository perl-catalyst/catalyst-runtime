package Catalyst::Response;

use strict;
use base 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors(qw/cookies headers output redirect status/);

=head1 NAME

Catalyst::Response - Catalyst Response Class

=head1 SYNOPSIS

    $resp = $c->response;
    $resp->cookies;
    $resp->headers;
    $resp->output;
    $resp->redirect;
    $resp->status;

See also L<Catalyst::Application>.

=head1 DESCRIPTION

This is the Catalyst Response class, which provides a set of accessors to
response data.

=head1 METHODS

=over 4

=item $resp->cookies

Returns a reference to a hash containing the cookies.

    $c->response->cookies->{foo} = { value => '123' };

=item $resp->headers

Returns a L<HTTP::Headers> object containing the headers.

    $c->response->headers->header( 'X-Catalyst' => $Catalyst::VERSION );

=item $resp->output($text)

Contains the final output.

    $c->response->output('Catalyst rockz!');

=item $resp->redirect($url)

Contains a location to redirect to.

    $c->response->redirect('http://slashdot.org');

=item status

Contains the HTTP status.

    $c->response->status(404);

=back

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
