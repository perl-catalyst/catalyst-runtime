package Catalyst::Response;

use Moose;
use HTTP::Headers;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

with 'MooseX::Emulate::Class::Accessor::Fast';

has _response_cb => (
    is      => 'ro',
    isa     => 'CodeRef',
    writer  => '_set_response_cb',
    clearer => '_clear_response_cb',
    predicate => '_has_response_cb',
);

subtype 'Catalyst::Engine::Types::Writer',
    as duck_type([qw(write close)]);

has _writer => (
    is      => 'ro',
    isa     => 'Catalyst::Engine::Types::Writer',
    writer  => '_set_writer',
    clearer => '_clear_writer',
    predicate => '_has_writer',
);

sub DEMOLISH { $_[0]->_writer->close if $_[0]->_has_writer }

has cookies   => (is => 'rw', default => sub { {} });
has body      => (is => 'rw', default => undef);
sub has_body { defined($_[0]->body) }

has location  => (is => 'rw');
has status    => (is => 'rw', default => 200);
has finalized_headers => (is => 'rw', default => 0);
has headers   => (
  is      => 'rw',
  isa => 'HTTP::Headers',
  handles => [qw(content_encoding content_length content_type header)],
  default => sub { HTTP::Headers->new() },
  required => 1,
  lazy => 1,
);

sub output { shift->body(@_) }

sub code   { shift->status(@_) }

sub write {
    my ( $self, $buffer ) = @_;

    # Finalize headers if someone manually writes output
    $self->finalize_headers;

    $buffer = q[] unless defined $buffer;

    my $len = length($buffer);
    $self->_writer->write($buffer);  # ignore PerlIO's LEN, [OFFSET] params

    return $len;
}

sub finalize_headers {
    my ($self) = @_;

    # This is a less-than-pretty hack to avoid breaking the old
    # Catalyst::Engine::PSGI. 5.9 Catalyst::Engine sets a response_cb and
    # expects us to pass headers to it here, whereas Catalyst::Engine::PSGI
    # just pulls the headers out of $ctx->response in its run method and never
    # sets response_cb. So take the lack of a response_cb as a sign that we
    # don't need to set the headers.

    return unless $self->_has_response_cb;

    # If we already have a writer, we already did this, so don't do it again
    return if $self->_has_writer;

    my @headers;
    $self->headers->scan(sub { push @headers, @_ });

    my $writer = $self->_response_cb->([ $self->status, \@headers ]);
    $self->_set_writer($writer);
    $self->_clear_response_cb;

    return;
}

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

=head2 $res->body( $text | $fh | $iohandle_object )

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
references used to construct a L<CGI::Simple::Cookie> object.

    $c->response->cookies->{foo} = { value => '123' };

The keys of the hash reference on the right correspond to the L<CGI::Simple::Cookie>
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
want to C< return > or C<< $c->detach() >> to interrupt the normal
processing flow if you want the redirect to occur straight away.

B<Note:> do not give a relative URL as $url, i.e: one that is not fully
qualified (= C<http://...>, etc.) or that starts with a slash
(= C</path/here>). While it may work, it is not guaranteed to do the right
thing and is not a standard behaviour. You may opt to use uri_for() or
uri_for_action() instead.

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

=head2 $self->finalize_headers($c)

Writes headers to response if not already written

=head2 DEMOLISH

Ensures that the response is flushed and closed at the end of the
request.

=head2 meta

Provided by Moose

=head1 IO::Handle METHODS

Certain other methods are provided to ensure (reasonable) compatibility
to other functions expecting a L<IO::Handle> object:

    $res->open    # ignores all params and calls $res->finalize_headers
    $res->close
    $res->opened  # auto-opens
    $res->fileno
    $res->print( ARGS )  # uses $, & $\
    $res->printf( FMT, [ARGS] )
    $res->say( ARGS )
    $res->printflush( ARGS )
    
    # these are checked for similar methods within the writer
    $res->autoflush( [BOOL] )  # echos BOOL or 0 if method not found
    $res->blocking( [BOOL] )   # echos BOOL or 1 if method not found
    $res->binmode( [BOOL] )    # echos BOOL or 1 if method not found
    $res->error                # returns $! if method not found
    $res->clearerr             # clears $! and returns 0 if method not found
    $res->sync                 # tries $res->flush if method not found
    $res->flush                # returns "0 but true" if method not found

=for Pod::Coverage open(ed)?|close|fileno|print(f?|flush)|say

=cut

sub open   {
    # We are just going to blissfully ignore the params
    my ($self) = shift;
    
    $self->finalize_headers;
    return 1;
}
sub close  { return shift->_has_writer && shift->_writer->close(); }
sub opened { return shift->open(); }          # if it's asking, just open up the writer
sub fileno { return scalar shift->_writer; }  # scalar reference comparison should be good enough
sub print  {
    my ($self, @data) = (shift, @_);
    
    # (var usage per Perl print docs)
    @data = map { ($_, $,) } @data;       # poor man's "array join"
    splice(@data, -1, 1, $\) if (@data);  # remove trailing sep + add $\
    
    for (@data) { defined $self->write($_) or return; }
    
    return 1;
}
sub printf {
    my ($self) = shift;
    return $self->write( sprintf(@_) );  # per docs, printf doesn't use $/
}
sub say {
    my ($self) = shift;
    local $\ = "\n";
    return $self->print(@_);
}
sub printflush {
    my ($self) = shift;
    my $af  = $self->autoflush(1);
    my $ret = $self->print(@_);
    $self->autoflush($af);
    return $ret;
}

# I/O method checking
sub _attempt {
   my ($self, $method, $default, @data) = @_;
   no strict 'refs';  # no complainy at CODEREFs

    return $self->_has_writer && $self->_writer->can($method) ?
        $self->_writer->$method(@data) :
        ref $default eq 'CODE' ?
            &$default($self) :  # (kinda janky, but $self->$default isn't right either)
            defined $data[0] ? $data[0] : $default  # can't tell, but don't error on it, either (default action for booleans)
   ;
}   
   
foreach my $pair (
    [autoflush => 0],
    [blocking  => 1],
    [binmode   => 1],
    [error     => sub { $!             }],
    [clearerr  => sub { undef $! || 0  }],  # 0 = don't error
    [sync      => sub { shift->flush() }],  # fallback
    [flush     => sub { "0 but true"   }],  # don't error (but don't echo either, hence a CODEREF)
)                                #  $method           $self           @([$method, $default]), @data 
    { __PACKAGE__->meta->add_method($pair->[0], sub { shift->_attempt(@$pair, @_); }); }

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
