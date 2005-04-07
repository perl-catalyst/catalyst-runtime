package Catalyst::Response;

use strict;
use base 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors(qw/cookies headers output redirect status/);

sub content_encoding { shift->headers->content_encoding(@_) }
sub content_length   { shift->headers->content_length(@_)   }
sub content_type     { shift->headers->content_type(@_)     }
sub header           { shift->headers->header(@_)           }

=head1 NAME

Catalyst::Response - Catalyst Response Class

=head1 SYNOPSIS

    $resp = $c->response;
    $resp->content_encoding;
    $resp->content_length;
    $resp->content_type;
    $resp->cookies;
    $resp->header;
    $resp->headers;
    $resp->output;
    $resp->redirect;
    $resp->status;

See also L<Catalyst::Application>.

=head1 DESCRIPTION

This is the Catalyst Response class, which provides a set of accessors
to response data.

=head1 METHODS

=over 4

=item $resp->content_encoding

Shortcut to $resp->headers->content_encoding

=item $resp->content_length

Shortcut to $resp->headers->content_length

=item $resp->content_type

Shortcut to $resp->headers->content_type

=item $resp->cookies

Returns a reference to a hash containing the cookies to be set.

    $c->response->cookies->{foo} = { value => '123' };

=item $resp->header

Shortcut to $resp->headers->header

=item $resp->headers

Returns a L<HTTP::Headers> object containing the headers.

    $c->response->headers->header( 'X-Catalyst' => $Catalyst::VERSION );

=item $resp->output($text)

Contains the final output.

    $c->response->output('Catalyst rocks!');

=item $resp->redirect($url)

Contains a location to redirect to.

    $c->response->redirect('http://slashdot.org');

=item status

Contains the HTTP status.

    $c->response->status(404);

=back

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Marcus Ramberg, C<mramberg@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

1;
