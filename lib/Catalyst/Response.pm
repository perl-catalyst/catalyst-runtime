package Catalyst::Response;

use Moose;
use HTTP::Headers;
use Moose::Util::TypeConstraints;
use Scalar::Util 'blessed';
use Catalyst::Response::Writer;
use Catalyst::Utils ();

use namespace::clean -except => ['meta'];

with 'MooseX::Emulate::Class::Accessor::Fast';

our $DEFAULT_ENCODE_CONTENT_TYPE_MATCH = qr{text|xml$|javascript$};

has encodable_content_type => (
    is => 'rw',
    required => 1,
    default => sub { $DEFAULT_ENCODE_CONTENT_TYPE_MATCH }
);

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

sub _build_write_fh {
  my $writer = $_[0]->_writer; # We need to get the finalize headers side effect...
  my $requires_encoding = $_[0]->encodable_response;
  my %fields = (
    _writer => $writer,
    _context => $_[0]->_context,
    _requires_encoding => $requires_encoding,
  );

  return bless \%fields, 'Catalyst::Response::Writer';
}

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
  handles => [qw(content_encoding content_length content_type content_type_charset header)],
  default => sub { HTTP::Headers->new() },
  required => 1,
  lazy => 1,
);
has _context => (
  is => 'rw',
  weak_ref => 1,
  clearer => '_clear_context',
);

before [qw(status headers content_encoding content_length content_type )] => sub {
  my $self = shift;

  $self->_context->log->warn(
    "Useless setting a header value after finalize_headers and the response callback has been called." .
    " Since we don't support tail headers this will not work as you might expect." )
      if ( $self->_context && $self->finalized_headers && !$self->_has_response_cb && @_ );
};

# This has to be different since the first param to ->header is the header name and presumably
# you should be able to request the header even after finalization, just not try to change it.
before 'header' => sub {
  my $self = shift;
  my $header = shift;

  $self->_context->log->warn(
    "Useless setting a header value after finalize_headers and the response callback has been called." .
    " Since we don't support tail headers this will not work as you might expect." )
      if ( $self->_context && $self->finalized_headers && !$self->_has_response_cb && @_ );
};

sub output { shift->body(@_) }

sub code   { shift->status(@_) }

sub write {
    my ( $self, $buffer ) = @_;

    # Finalize headers if someone manually writes output
    $self->_context->finalize_headers unless $self->finalized_headers;

    $buffer = q[] unless defined $buffer;

    if($self->encodable_response) {
      $buffer = $self->_context->encoding->encode( $buffer, $self->_context->_encode_check )
    }

    my $len = length($buffer);
    $self->_writer->write($buffer);

    return $len;
}

sub unencoded_write {
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
    if(blessed($psgi_res) && $psgi_res->can('as_psgi')) {
      $psgi_res = $psgi_res->as_psgi;
    }
    if(ref $psgi_res eq 'ARRAY') {
        my ($status, $headers, $body) = @$psgi_res;
        $self->status($status);
        $self->headers(HTTP::Headers->new(@$headers));
        # Can be arrayref or filehandle...
        if(defined $body) { # probably paranoia
          ref $body eq 'ARRAY' ? $self->body(join('', @$body)) : $self->body($body);
        }
    } elsif(ref $psgi_res eq 'CODE') {

        # Its not clear to me this is correct.  Right now if the PSGI application wants
        # to stream, we stream immediately and then completely bypass the rest of the
        # Catalyst finalization process (unlike if the PSGI app sets an arrayref).  Part of
        # me thinks we should override the current _response_cb and then let finalize_body
        # call that.  I'm not sure the downside of bypassing those bits.  I'm going to leave
        # this be for now and document the behavior.

        $psgi_res->(sub {
            my $response = shift;
            my ($status, $headers, $maybe_body) = @$response;
            $self->status($status);
            $self->headers(HTTP::Headers->new(@$headers));
            if(defined $maybe_body) {
                # Can be arrayref or filehandle...
                ref $maybe_body eq 'ARRAY' ? $self->body(join('', @$maybe_body)) : $self->body($maybe_body);
            } else {
                return $self->write_fh;
            }
        });
     } else {
        die "You can't set a Catalyst response from that, expect a valid PSGI response";
    }

    # Encoding compatibilty.   If the response set a charset, well... we need
    # to assume its properly encoded and NOT encode for this response.  Otherwise
    # We risk double encoding.

    # We check first to make sure headers have not been finalized.  Headers might be finalized
    # in the case where a PSGI response is streaming and the PSGI application already wrote
    # to the output stream and close the filehandle.
    if(!$self->finalized_headers && $self->content_type_charset) {
      # We have to do this since for backcompat reasons having a charset doesn't always
      # mean that the body is already encoded :(
      $self->_context->clear_encoding;
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
you might want to use a L<IO::Handle> type of object (Something that implements the getline method
in the same fashion), or a filehandle GLOB. These will be passed down to the PSGI
handler you are using and might be optimized using server specific abilities (for
example L<Twiggy> will attempt to server a real local file in a non blocking manner).

If you are using a filehandle as the body response you are responsible for
making sure it conforms to the L<PSGI> specification with regards to content
encoding.  Unlike with scalar body values or when using the streaming interfaces
we currently do not attempt to normalize and encode your filehandle.  In general
this means you should be sure to be sending bytes not UTF8 decoded multibyte
characters.

Most of the time when you do:

    open(my $fh, '<:raw', $path);

You should be fine.  If you open a filehandle with a L<PerlIO> layer you probably
are not fine.  You can usually fix this by explicitly using binmode to set
the IOLayer to :raw.  Its possible future versions of L<Catalyst> will try to
'do the right thing'.

When using a L<IO::Handle> type of object and no content length has been
already set in the response headers Catalyst will make a reasonable attempt
to determine the size of the Handle. Depending on the implementation of your
handle object, setting the content length may fail. If it is at all possible
for you to determine the content length of your handle object,
it is recommended that you set the content length in the response headers
yourself, which will be respected and sent by Catalyst in the response.

Please note that the object needs to implement C<getline>, not just
C<read>.  Older versions of L<Catalyst> expected your filehandle like objects
to do read.  If you have code written for this expectation and you cannot
change the code to meet the L<PSGI> specification, you can try the following
middleware L<Plack::Middleware::AdaptFilehandleRead> which will attempt to
wrap your object in an interface that so conforms.

Starting from version 5.90060, when using an L<IO::Handle> object, you
may want to use L<Plack::Middleware::XSendfile>, to delegate the
actual serving to the frontend server. To do so, you need to pass to
C<body> an IO object with a C<path> method. This can be achieved in
two ways.

Either using L<Plack::Util>:

  my $fh = IO::File->new($file, 'r');
  Plack::Util::set_io_path($fh, $file);

Or using L<IO::File::WithPath>

  my $fh = IO::File::WithPath->new($file, 'r');

And then passing the filehandle to body and setting headers, if needed.

  $c->response->body($fh);
  $c->response->headers->content_type('text/plain');
  $c->response->headers->content_length(-s $file);
  $c->response->headers->last_modified((stat($file))[9]);

L<Plack::Middleware::XSendfile> can be loaded in the application so:

 __PACKAGE__->config(
     psgi_middleware => [
         'XSendfile',
         # other middlewares here...
        ],
 );

B<Beware> that loading the middleware without configuring the
webserver to set the request header C<X-Sendfile-Type> to a supported
type (C<X-Accel-Redirect> for nginx, C<X-Sendfile> for Apache and
Lighttpd), could lead to the disclosure of private paths to malicious
clients setting that header.

Nginx needs the additional X-Accel-Mapping header to be set in the
webserver configuration, so the middleware will replace the absolute
path of the IO object with the internal nginx path. This is also
useful to prevent a buggy app to server random files from the
filesystem, as it's an internal redirect.

An nginx configuration for FastCGI could look so:

 server {
     server_name example.com;
     root /my/app/root;
     location /private/repo/ {
         internal;
         alias /my/app/repo/;
     }
     location /private/staging/ {
         internal;
         alias /my/app/staging/;
     }
     location @proxy {
         include /etc/nginx/fastcgi_params;
         fastcgi_param SCRIPT_NAME '';
         fastcgi_param PATH_INFO   $fastcgi_script_name;
         fastcgi_param HTTP_X_SENDFILE_TYPE X-Accel-Redirect;
         fastcgi_param HTTP_X_ACCEL_MAPPING /my/app=/private;
         fastcgi_pass  unix:/my/app/run/app.sock;
    }
 }

In the example above, passing filehandles with a local path matching
/my/app/staging or /my/app/repo will be served by nginx. Passing paths
with other locations will lead to an internal server error.

Setting the body to a filehandle without the C<path> method bypasses
the middleware completely.

For Apache and Lighttpd, the mapping doesn't apply and setting the
X-Sendfile-Type is enough.

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

=head2 $res->content_type_charset

Shortcut for $res->headers->content_type_charset;

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

B<Note:> If $url is an object that does ->as_string (such as L<URI>, which is
what you get from ->uri_for) we automatically call that to stringify.  This
should ease the common case usage

    return $c->res->redirect( $c->uri_for(...));

=cut

sub redirect {
    my $self = shift;

    if (@_) {
        my $location = shift;
        my $status   = shift || 302;

        if(blessed($location) && $location->can('as_string')) {
            $location = $location->as_string;
        }

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

Writes $data to the output stream.  Calling this method will finalize your
headers and send the headers and status code response to the client (so changing
them afterwards is a waste... be sure to set your headers correctly first).

You may call this as often as you want throughout your response cycle.  You may
even set a 'body' afterward.  So for example you might write your HTTP headers
and the HEAD section of your document and then set the body from a template
driven from a database.  In some cases this can seem to the client as if you had
a faster overall response (but note that unless your server support chunked
body your content is likely to get queued anyway (L<Starman> and most other
http 1.1 webservers support this).

If there is an encoding set, we encode each line of the response (the default
encoding is UTF-8).

=head2 $res->unencoded_write( $data )

Works just like ->write but we don't apply any content encoding to C<$data>.  Use
this if you are already encoding the $data or the data is arriving from an encoded
storage.

=head2 $res->write_fh

Returns an instance of L<Catalyst::Response::Writer>, which is a lightweight
decorator over the PSGI C<$writer> object (see L<PSGI.pod\Delayed-Response-and-Streaming-Body>).

In addition to proxying the C<write> and C<close> method from the underlying PSGI
writer, this proxy object knows any application wide encoding, and provides a method
C<write_encoded> that will properly encode your written lines based upon your
encoding settings.  By default in L<Catalyst> responses are UTF-8 encoded and this
is the encoding used if you respond via C<write_encoded>.  If you want to handle
encoding yourself, you can use the C<write> method directly.

Encoding only applies to content types for which it matters.  Currently the following
content types are assumed to need encoding: text (including HTML), xml and javascript.

We provide access to this object so that you can properly close over it for use in
asynchronous and nonblocking applications.  For example (assuming you are using a supporting
server, like L<Twiggy>:

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

Like the 'write' method, calling this will finalize headers. Unlike 'write' when you
can this it is assumed you are taking control of the response so the body is never
finalized (there isn't one anyway) and you need to call the close method.

=head2 $res->print( @data )

Prints @data to the output stream, separated by $,.  This lets you pass
the response object to functions that want to write to an L<IO::Handle>.

=head2 $res->finalize_headers()

Writes headers to response if not already written

=head2 from_psgi_response

Given a PSGI response (either three element ARRAY reference OR coderef expecting
a $responder) set the response from it.

Properly supports streaming and delayed response and / or async IO if running
under an expected event loop.

If passed an object, will expect that object to do a method C<as_psgi>.

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

    sub streaming_body :Local {
      my ($self, $c) = @_;
      my $psgi_app = sub {
          my $respond = shift;
          my $writer = $respond->([200,["Content-Type" => "text/plain"]]);
          $writer->write("body");
          $writer->close;
      };
      $c->res->from_psgi_response($psgi_app);
    }

Please note this does not attempt to map or nest your PSGI application under
the Controller and Action namespace or path. You may wish to review 'PSGI Helpers'
under L<Catalyst::Utils> for help in properly nesting applications.

B<NOTE> If your external PSGI application returns a response that has a character
set associated with the content type (such as "text/html; charset=UTF-8") we set
$c->clear_encoding to remove any additional content type encoding processing later
in the application (this is done to avoid double encoding issues).

B<NOTE> If your external PSGI application is streaming, we assume you completely
handle the entire jobs (including closing the stream).  This will also bypass
the output finalization methods on Catalyst (such as 'finalize_body' which gets
called but then skipped when it finds that output is already finished.)  Its possible
this might cause issue with some plugins that want to do 'things' during those
finalization methods.  Just understand what is happening.

=head2 encodable_content_type

This is a regular expression used to determine of the current content type
should be considered encodable.  Currently we apply default encoding (usually
UTF8) to text type contents.  Here's the default regular expression:

This would match content types like:

    text/plain
    text/html
    text/xml
    application/javascript
    application/xml
    application/vnd.user+xml

B<NOTE>: We don't encode JSON content type responses by default since most
of the JSON serializers that are commonly used for this task will do so
automatically and we don't want to double encode.  If you are not using a
tool like L<JSON> to produce JSON type content, (for example you are using
a template system, or creating the strings manually) you will need to either
encoding the body yourself:

    $c->response->body( $c->encoding->encode( $body, $c->_encode_check ) );

Or you can alter the regular expression using this attribute.

=head2 encodable_response

Given a L<Catalyst::Response> return true if its one that can be encoded.

     make sure there is an encoding set on the response
     make sure the content type is encodable
     make sure no content type charset has been already set to something different from the global encoding
     make sure no content encoding is present.

Note this does not inspect a body since we do allow automatic encoding on streaming
type responses.

=cut

sub encodable_response {
  my ($self) = @_;
  return 0 unless $self->_context; # Cases like returning a HTTP Exception response you don't have a context here...
  return 0 unless $self->_context->encoding;

  # The response is considered to have a 'manual charset' when a charset is already set on
  # the content type of the response AND it is not the same as the one we set in encoding.
  # If there is no charset OR we are asking for the one which is the same as the current
  # required encoding, that is a flag that we want Catalyst to encode the response automatically.
  my $has_manual_charset = 0;
  if(my $charset = $self->content_type_charset) {
    $has_manual_charset = (uc($charset) ne uc($self->_context->encoding->mime_name)) ? 1:0;
  }

  # Content type is encodable if it matches the regular expression stored in this attribute
  my $encodable_content_type = $self->content_type =~ m/${\$self->encodable_content_type}/ ? 1:0;

  # The content encoding is allowed (for charset encoding) only if its empty or is set to identity
  my $allowed_content_encoding = (!$self->content_encoding || $self->content_encoding eq 'identity') ? 1:0;

  # The content type must be an encodable type, and there must be NO manual charset and also
  # the content encoding must be the allowed values;
  if(
      $encodable_content_type and
      !$has_manual_charset and
      $allowed_content_encoding
  ) {
    return 1;
  } else {
    return 0;
  }
}

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
