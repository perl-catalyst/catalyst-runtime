package Catalyst::Response;

use strict;
use base 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors(qw/cookies headers output redirect status/);

=head1 NAME

Catalyst::Response - Catalyst Response Class

=head1 SYNOPSIS

See L<Catalyst::Application>.

=head1 DESCRIPTION

The Catalyst Response.

=head2 METHODS

=head3 cookies

Returns a hashref containing the cookies.

    $c->response->cookies->{foo} = { value => '123' };

=head3 headers

Returns a L<HTTP::Headers> object containing the headers.

    $c->response->headers->header( 'X-Catalyst' => $Catalyst::VERSION );

=head3 output

Contains the final output.

    $c->response->output('Catalyst rockz!');

=head3 redirect

Contains a location to redirect to.

    $c->response->redirect('http://slashdot.org');

=head3 status

Contains the HTTP status.

    $c->response->status(404);

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
