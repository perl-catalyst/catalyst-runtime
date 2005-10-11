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

Catalyst::Response - Catalyst Response Class

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

See also L<Catalyst::Application>.

=head1 DESCRIPTION

This is the Catalyst Response class, which provides a set of accessors
to response data.

=head1 METHODS

=over 4

=item $res->body($text)

    $c->response->body('Catalyst rocks!');

Contains the final output.

=item $res->content_encoding

Shortcut to $res->headers->content_encoding

=item $res->content_length

Shortcut to $res->headers->content_length

=item $res->content_type

Shortcut to $res->headers->content_type

=item $res->cookies

Returns a reference to a hash containing the cookies to be set.

    $c->response->cookies->{foo} = { value => '123' };

=item $res->header

Shortcut to $res->headers->header

=item $res->headers

Returns a L<HTTP::Headers> object containing the headers.

    $c->response->headers->header( 'X-Catalyst' => $Catalyst::VERSION );

=item $res->output

Shortcut to $res->body

=item $res->redirect( $url, $status )

Contains a location to redirect to.

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

=item $res->status

Contains the HTTP status.

    $c->response->status(404);
    
=item $res->write( $data )

Writes $data to the output stream.

=cut

sub write { shift->{_context}->write(@_); }

=back

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Marcus Ramberg, C<mramberg@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

1;
