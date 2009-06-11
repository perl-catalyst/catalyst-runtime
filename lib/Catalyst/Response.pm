package Catalyst::Response;

use Moose;
use HTTP::Headers;

with 'MooseX::Emulate::Class::Accessor::Fast';

has cookies   => (is => 'rw', default => sub { {} });
has body      => (is => 'rw', default => '', lazy => 1, predicate => 'has_body');
has location  => (is => 'rw');
has status    => (is => 'rw', default => 200);
has finalized_headers => (is => 'rw', default => 0);
has headers   => (
  is      => 'rw',
  handles => [qw(content_encoding content_length content_type header)],
  default => sub { HTTP::Headers->new() },
  required => 1,
  lazy => 1,
);
has _context => (
  is => 'rw',
  weak_ref => 1,
  handles => ['write'],
  clearer => '_clear_context',
);

sub output { shift->body(@_) }

sub code   { shift->status(@_) }

no Moose;

=head1 NAME

Catalyst::Response - stores output responding to the current client request

=head1 SYNOPSIS

    $res = $c->response;
    $res->body;
    $res->code;
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
the current client request. The appropriate L<Catalyst::Engine> for your environment
will turn the Catalyst::Response into a HTTP Response and return it to the client.

=head1 METHODS

=head2 $res->body(<$text|$fh|$iohandle_object)

    $c->response->body('Catalyst rocks!');

Sets or returns the output (text or binary data). If you are returning a large body,
you might want to use a L<IO::Handle> type of object (Something that implements the read method
in the same fashion), or a filehandle GLOB. Catalyst
will write it piece by piece into the response.

=head2 $res->has_body

Predicate which returns true when a body has been set.

=head2 $res->code

Alias for $res->status.

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

=over 

=item value

=item expires

=item domain

=item path

=item secure

=item httponly

=back

=head2 $res->header

Shortcut for $res->headers->header.

=head2 $res->headers

Returns an L<HTTP::Headers> object, which can be used to set headers.

    $c->response->headers->header( 'X-Catalyst' => $Catalyst::VERSION );

=head2 $res->output

Alias for $res->body.

=head2 $res->redirect( $url, $status )

Causes the response to redirect to the specified URL. The default status is
C<302>.

    $c->response->redirect( 'http://slashdot.org' );
    $c->response->redirect( 'http://slashdot.org', 307 );

This is a convenience method that sets the Location header to the
redirect destination, and then sets the response status.  You will
want to C< return; > or C< $c->detach() > to interrupt the normal
processing flow if you want the redirect to occur straight away.

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

=head2 $res->location

Sets or returns the HTTP 'Location'.

=head2 $res->status

Sets or returns the HTTP status.

    $c->response->status(404);

$res->code is an alias for this, to match HTTP::Response->code.
    
=head2 $res->write( $data )

Writes $data to the output stream.

=head2 meta

Provided by Moose

=head2 $res->print( @data )

Prints @data to the output stream, separated by $,.  This lets you pass
the response object to functions that want to write to an L<IO::Handle>.

=cut

sub print {
    my $self = shift;
    my $data = shift;

    defined $self->write($data) or return;

    for (@_) {
        defined $self->write($,) or return;
        defined $self->write($_) or return;
    }
    
    return 1;
}

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
