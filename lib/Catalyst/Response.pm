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
    isa     => 'Catalyst::Engine::Types::Writer', #Pointless since we control how this is built
    #writer  => '_set_writer', Now that its lazy I think this is safe to remove
    clearer => '_clear_writer',
    predicate => '_has_writer',
    lazy      => 1,
    builder => '_build_writer',
);

sub _build_writer {
    my $self = shift;

    ## These two lines are probably crap now...
    $self->_context->finalize_headers unless
      $self->finalized_headers;

    my @headers;
    $self->headers->scan(sub { push @headers, @_ });

    my $writer = $self->_response_cb->([ $self->status, \@headers ]);
    $self->_clear_response_cb;

    return $writer;
}

has write_fh => (
  is=>'ro',
  predicate=>'_has_write_fh',
  lazy=>1,
  builder=>'_build_write_fh',
);

sub _build_write_fh { shift ->_writer }

sub DEMOLISH {
  my $self = shift;
  return if $self->_has_write_fh;
  if($self->_has_writer) {
    $self->_writer->close
  }
}

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
has _context => (
  is => 'rw',
  weak_ref => 1,
  clearer => '_clear_context',
);

before [qw(status headers content_encoding content_length content_type header)] => sub {
  my $self = shift;

  $self->_context->log->warn( 
    "Useless setting a header value after finalize_headers called." .
    " Not what you want." )
      if ( $self->finalized_headers && @_ );
};

sub output { shift->body(@_) }

sub code   { shift->status(@_) }

sub write {
    my ( $self, $buffer ) = @_;

    # Finalize headers if someone manually writes output
    $self->_context->finalize_headers unless $self->finalized_headers;

    $buffer = q[] unless defined $buffer;

    my $len = length($buffer);
    $self->_writer->write($buffer);

    return $len;
}

sub finalize_headers {
    my ($self) = @_;
    return;
}

sub from_psgi_response {
    my ($self, $psgi_res) = @_;
    if(ref $psgi_res eq 'ARRAY') {
        my ($status, $headers, $body) = @$psgi_res;
        $self->status($status);
        $self->headers(HTTP::Headers->new(@$headers));
        $self->body($body);
    } elsif(ref $psgi_res eq 'CODE') {
        $psgi_res->(sub {
            my $response = shift;
            my ($status, $headers, $maybe_body) = @$response;
            $self->status($status);
            $self->headers(HTTP::Headers->new(@$headers));
            if(defined $maybe_body) {
                $self->body($maybe_body);
            } else {
                return $self->write_fh;
            }
        });  
     } else {
        die "You can't set a Catalyst response from that, expect a valid PSGI response";
    }
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

When using a L<IO::Handle> type of object and no content length has been
already set in the response headers Catalyst will make a reasonable attempt
to determine the size of the Handle. Depending on the implementation of your
handle object, setting the content length may fail. If it is at all possible
for you to determine the content length of your handle object, 
it is recommended that you set the content length in the response headers
yourself, which will be respected and sent by Catalyst in the response.

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

=head2 $res->write_fh

Returns a PSGI $writer object that has two methods, write and close.  You can
close over this object for asynchronous and nonblocking applications.  For
example (assuming you are using a supporting server, like L<Twiggy>

    package AsyncExample::Controller::Root;

    use Moose;

    BEGIN { extends 'Catalyst::Controller' }

    sub prepare_cb {
      my $write_fh = pop;
      return sub {
        my $message = shift;
        $write_fh->write("Finishing: $message\n");
        $write_fh->close;
      };
    }

    sub anyevent :Local :Args(0) {
      my ($self, $c) = @_;
      my $cb = $self->prepare_cb($c->res->write_fh);

      my $watcher;
      $watcher = AnyEvent->timer(
        after => 5,
        cb => sub {
          $cb->(scalar localtime);
          undef $watcher; # cancel circular-ref
        });
    }

=head2 $res->print( @data )

Prints @data to the output stream, separated by $,.  This lets you pass
the response object to functions that want to write to an L<IO::Handle>.

=head2 $self->finalize_headers($c)

Writes headers to response if not already written

=head2 from_psgi_response

Given a PSGI response (either three element ARRAY reference OR coderef expecting
a $responder) set the response from it.

Properly supports streaming and delayed response and / or async IO if running
under an expected event loop.

Example:

    package MyApp::Web::Controller::Test;

    use base 'Catalyst::Controller';
    use Plack::App::Directory;


    my $app = Plack::App::Directory->new({ root => "/path/to/htdocs" })
      ->to_app;

    sub myaction :Local Args {
      my ($self, $c) = @_;
      $c->res->from_psgi_response($app->($c->req->env));
    }

Please note this does not attempt to map or nest your PSGI application under
the Controller and Action namespace or path.  

=head2 DEMOLISH

Ensures that the response is flushed and closed at the end of the
request.

=head2 meta

Provided by Moose

=cut

sub print {
    my $self = shift;
    my $data = shift;

    defined $self->write($data) or return;

    for (@_) {
        defined $self->write($,) or return;
        defined $self->write($_) or return;
    }
    defined $self->write($\) or return;

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
