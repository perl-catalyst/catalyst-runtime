package Catalyst::Response;

use strict;
use base 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors(qw/cookies body headers location status/);

*output = \&body;

sub content_encoding { shift->headers->content_encoding(@_) }
sub content_length   { shift->headers->content_length(@_) }
sub content_type     { shift->headers->content_type(@_) }
sub header           { shift->headers->header(@_) }

=head1 NAME

Catalyst::Response - stores output responding to the current client request

=head1 SYNOPSIS

    $res = $c->response;
    $res->body;
    $res->content_encoding;
    $res->content_length;
    $res->content_type;
    $res->cookies;
    $res->header;
    $res->headers;
    $res->output;
    $res->redirect;
    $res->status;
    $res->write;

=head1 DESCRIPTION

This is the Catalyst Response class, which provides methods for responding to
the current client request.

=head1 METHODS

=head2 $res->body($text)

    $c->response->body('Catalyst rocks!');

Sets or returns the output (text or binary data).

=head2 $res->content_encoding

Shortcut for $res->headers->content_encoding.

=head2 $res->content_length

Shortcut for $res->headers->content_length.

=head2 $res->content_type

Shortcut for $res->headers->content_type.

This value is typically set by your view or plugin. For example,
L<Catalyst::Plugin::Static::Simple> will guess the mime type based on the file
it found, while L<Catalyst::View::TT> defaults to C<text/html>.

=head2 $res->cookies

Returns a reference to a hash containing cookies to be set. The keys of the
hash are the cookies' names, and their corresponding values are hash
references used to construct a L<CGI::Cookie> object.

    $c->response->cookies->{foo} = { value => '123' };

The keys of the hash reference on the right correspond to the L<CGI::Cookie>
parameters of the same name, except they are used without a leading dash.
Possible parameters are:

=head2 value

=head2 expires

=head2 domain

=head2 path

=head2 secure

=head2 $res->header

Shortcut for $res->headers->header.

=head2 $res->headers

Returns an L<HTTP::Headers> object, which can be used to set headers.

    $c->response->headers->header( 'X-Catalyst' => $Catalyst::VERSION );

=head2 $res->output

Alias for $res->body.

=head2 $res->redirect( $url, $status )

Causes the response to redirect to the specified URL.

    $c->response->redirect( 'http://slashdot.org' );
    $c->response->redirect( 'http://slashdot.org', 307 );

=cut

sub redirect {
    my $self = shift;

    if (@_) {
        my $location = shift;
        my $status   = shift || 302;

        $self->location($location);
        $self->status($status);
    }

    return $self->location;
}

=head2 $res->status

Sets or returns the HTTP status.

    $c->response->status(404);
    
=head2 $res->write( $data )

Writes $data to the output stream.

=cut

sub write { shift->{_context}->write(@_); }

=head1 AUTHORS

Sebastian Riedel, C<sri@cpan.org>

Marcus Ramberg, C<mramberg@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

1;
