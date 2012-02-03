package Catalyst::Request;

use IO::Socket qw[AF_INET inet_aton];
use Carp;
use utf8;
use URI::http;
use URI::https;
use URI::QueryParam;
use HTTP::Headers;

use Moose;

use namespace::clean -except => 'meta';

with 'MooseX::Emulate::Class::Accessor::Fast';

has env => (is => 'ro', writer => '_set_env');
# XXX Deprecated crap here - warn?
has action => (is => 'rw');
# XXX: Deprecated in docs ages ago (2006), deprecated with warning in 5.8000 due
# to confusion between Engines and Plugin::Authentication. Remove in 5.8100?
has user => (is => 'rw');
sub snippets        { shift->captures(@_) }

has _read_position => (
    init_arg => undef,
    is => 'ro',
    writer => '_set_read_position',
    default => 0,
);
has _read_length => (
    init_arg => undef,
    is => 'ro',
    default => sub {
        my $self = shift;
        $self->header('Content-Length') || 0;
    },
    lazy => 1,
);

has address => (is => 'rw');
has arguments => (is => 'rw', default => sub { [] });
has cookies => (is => 'ro', builder => 'prepare_cookies', lazy => 1);

sub prepare_cookies {
    my ( $self ) = @_;

    if ( my $header = $self->header('Cookie') ) {
        return { CGI::Simple::Cookie->parse($header) };
    }
    {};
}

has query_keywords => (is => 'rw');
has match => (is => 'rw');
has method => (is => 'rw');
has protocol => (is => 'rw');
has query_parameters  => (is => 'rw', default => sub { {} });
has secure => (is => 'rw', default => 0);
has captures => (is => 'rw', default => sub { [] });
has uri => (is => 'rw', predicate => 'has_uri');
has remote_user => (is => 'rw');
has headers => (
  is      => 'rw',
  isa     => 'HTTP::Headers',
  handles => [qw(content_encoding content_length content_type header referer user_agent)],
  builder => 'prepare_headers',
  lazy => 1,
);

sub prepare_headers {
    my ($self) = @_;

    my $env = $self->env;
    my $headers = HTTP::Headers->new();

    for my $header (keys %{ $env }) {
        next unless $header =~ /^(HTTP|CONTENT|COOKIE)/i;
        (my $field = $header) =~ s/^HTTPS?_//;
        $field =~ tr/_/-/;
        $headers->header($field => $env->{$header});
    }
    return $headers;
}

has _log => (
    is => 'ro',
    weak_ref => 1,
    required => 1,
);

# Amount of data to read from input on each pass
our $CHUNKSIZE = 64 * 1024;

sub read {
    my ($self, $maxlength) = @_;
    my $remaining = $self->_read_length - $self->_read_position;
    $maxlength ||= $CHUNKSIZE;

    # Are we done reading?
    if ( $remaining <= 0 ) {
        return;
    }

    my $readlen = ( $remaining > $maxlength ) ? $maxlength : $remaining;
    my $rc = $self->read_chunk( my $buffer, $readlen );
    if ( defined $rc ) {
        if (0 == $rc) { # Nothing more to read even though Content-Length
                        # said there should be.
            return;
        }
        $self->_set_read_position( $self->_read_position + $rc );
        return $buffer;
    }
    else {
        Catalyst::Exception->throw(
            message => "Unknown error reading input: $!" );
    }
}

sub read_chunk {
    my $self = shift;
    return $self->env->{'psgi.input'}->read(@_);
}

has body_parameters => (
  is => 'rw',
  required => 1,
  lazy => 1,
  default => sub { {} },
);

has uploads => (
  is => 'rw',
  required => 1,
  default => sub { {} },
);

has parameters => (
    is => 'rw',
    lazy => 1,
    builder => 'prepare_parameters',
);

# TODO:
# - Can we lose the before modifiers which just call prepare_body ?
#   they are wasteful, slow us down and feel cluttery.

#  Can we make _body an attribute, have the rest of
#  these lazy build from there and kill all the direct hash access
#  in Catalyst.pm and Engine.pm?

sub prepare_parameters {
    my ( $self ) = @_;

    $self->prepare_body;
    my $parameters = {};
    my $body_parameters = $self->body_parameters;
    my $query_parameters = $self->query_parameters;
    # We copy, no references
    foreach my $name (keys %$query_parameters) {
        my $param = $query_parameters->{$name};
        $parameters->{$name} = ref $param eq 'ARRAY' ? [ @$param ] : $param;
    }

    # Merge query and body parameters
    foreach my $name (keys %$body_parameters) {
        my $param = $body_parameters->{$name};
        my @values = ref $param eq 'ARRAY' ? @$param : ($param);
        if ( my $existing = $parameters->{$name} ) {
          unshift(@values, (ref $existing eq 'ARRAY' ? @$existing : $existing));
        }
        $parameters->{$name} = @values > 1 ? \@values : $values[0];
    }
    $parameters;
}

before body_parameters => sub {
    my ($self) = @_;
    $self->prepare_body;
    $self->prepare_body_parameters;
};

has _uploadtmp => (
    is => 'ro',
    predicate => '_has_uploadtmp',
);

sub prepare_body {
    my ( $self ) = @_;

    if ( my $length = $self->_read_length ) {
        unless ( $self->_body ) {
            my $type = $self->header('Content-Type');
            $self->_body(HTTP::Body->new( $type, $length ));
            $self->_body->cleanup(1); # Make extra sure!
            $self->_body->tmpdir( $self->_uploadtmp )
              if $self->_has_uploadtmp;
        }

        # Check for definedness as you could read '0'
        while ( defined ( my $buffer = $self->read() ) ) {
            $self->prepare_body_chunk($buffer);
        }

        # paranoia against wrong Content-Length header
        my $remaining = $length - $self->_read_position;
        if ( $remaining > 0 ) {
            Catalyst::Exception->throw(
                "Wrong Content-Length value: $length" );
        }
    }
    else {
        # Defined but will cause all body code to be skipped
        $self->_body(0);
    }
}

sub prepare_body_chunk {
    my ( $self, $chunk ) = @_;

    $self->_body->add($chunk);
}

sub prepare_body_parameters {
    my ( $self ) = @_;

    return unless $self->_body;

    $self->{body_parameters} = $self->_body->param; # FIXME!! Recursion here.
}

sub prepare_connection {
    my ($self) = @_;

    my $env = $self->env;

    $self->address( $env->{REMOTE_ADDR} );
    $self->hostname( $env->{REMOTE_HOST} )
        if exists $env->{REMOTE_HOST};
    $self->protocol( $env->{SERVER_PROTOCOL} );
    $self->remote_user( $env->{REMOTE_USER} );
    $self->method( $env->{REQUEST_METHOD} );
    $self->secure( $env->{'psgi.url_scheme'} eq 'https' ? 1 : 0 );
}

# XXX - FIXME - method is here now, move this crap...
around parameters => sub {
    my ($orig, $self, $params) = @_;
    if ($params) {
        if ( !ref $params ) {
            $self->_log->warn(
                "Attempt to retrieve '$params' with req->params(), " .
                "you probably meant to call req->param('$params')"
            );
            $params = undef;
        }
        return $self->$orig($params);
    }
    $self->$orig();
};

has base => (
  is => 'rw',
  required => 1,
  lazy => 1,
  default => sub {
    my $self = shift;
    return $self->path if $self->has_uri;
  },
);

has _body => (
  is => 'rw', clearer => '_clear_body', predicate => '_has_body',
);
# Eugh, ugly. Should just be able to rename accessor methods to 'body'
#             and provide a custom reader..
sub body {
  my $self = shift;
  $self->prepare_body();
  croak 'body is a reader' if scalar @_;
  return blessed $self->_body ? $self->_body->body : $self->_body;
}

has hostname => (
  is        => 'rw',
  required  => 1,
  lazy      => 1,
  default   => sub {
    my ($self) = @_;
    gethostbyaddr( inet_aton( $self->address ), AF_INET ) || $self->address
  },
);

has _path => ( is => 'rw', predicate => '_has_path', clearer => '_clear_path' );

sub args            { shift->arguments(@_) }
sub body_params     { shift->body_parameters(@_) }
sub input           { shift->body(@_) }
sub params          { shift->parameters(@_) }
sub query_params    { shift->query_parameters(@_) }
sub path_info       { shift->path(@_) }

=for stopwords param params

=head1 NAME

Catalyst::Request - provides information about the current client request

=head1 SYNOPSIS

    $req = $c->request;
    $req->address eq "127.0.0.1";
    $req->arguments;
    $req->args;
    $req->base;
    $req->body;
    $req->body_parameters;
    $req->content_encoding;
    $req->content_length;
    $req->content_type;
    $req->cookie;
    $req->cookies;
    $req->header;
    $req->headers;
    $req->hostname;
    $req->input;
    $req->query_keywords;
    $req->match;
    $req->method;
    $req->param;
    $req->parameters;
    $req->params;
    $req->path;
    $req->protocol;
    $req->query_parameters;
    $req->read;
    $req->referer;
    $req->secure;
    $req->captures;
    $req->upload;
    $req->uploads;
    $req->uri;
    $req->user;
    $req->user_agent;

See also L<Catalyst>, L<Catalyst::Request::Upload>.

=head1 DESCRIPTION

This is the Catalyst Request class, which provides an interface to data for the
current client request. The request object is prepared by L<Catalyst::Engine>,
thus hiding the details of the particular engine implementation.

=head1 METHODS

=head2 $req->address

Returns the IP address of the client.

=head2 $req->arguments

Returns a reference to an array containing the arguments.

    print $c->request->arguments->[0];

For example, if your action was

    package MyApp::Controller::Foo;

    sub moose : Local {
        ...
    }

and the URI for the request was C<http://.../foo/moose/bah>, the string C<bah>
would be the first and only argument.

Arguments get automatically URI-unescaped for you.

=head2 $req->args

Shortcut for L</arguments>.

=head2 $req->base

Contains the URI base. This will always have a trailing slash. Note that the
URI scheme (e.g., http vs. https) must be determined through heuristics;
depending on your server configuration, it may be incorrect. See $req->secure
for more info.

If your application was queried with the URI
C<http://localhost:3000/some/path> then C<base> is C<http://localhost:3000/>.

=head2 $req->body

Returns the message body of the request, as returned by L<HTTP::Body>: a string,
unless Content-Type is C<application/x-www-form-urlencoded>, C<text/xml>, or
C<multipart/form-data>, in which case a L<File::Temp> object is returned.

=head2 $req->body_parameters

Returns a reference to a hash containing body (POST) parameters. Values can
be either a scalar or an arrayref containing scalars.

    print $c->request->body_parameters->{field};
    print $c->request->body_parameters->{field}->[0];

These are the parameters from the POST part of the request, if any.

=head2 $req->body_params

Shortcut for body_parameters.

=head2 $req->content_encoding

Shortcut for $req->headers->content_encoding.

=head2 $req->content_length

Shortcut for $req->headers->content_length.

=head2 $req->content_type

Shortcut for $req->headers->content_type.

=head2 $req->cookie

A convenient method to access $req->cookies.

    $cookie  = $c->request->cookie('name');
    @cookies = $c->request->cookie;

=cut

sub cookie {
    my $self = shift;

    if ( @_ == 0 ) {
        return keys %{ $self->cookies };
    }

    if ( @_ == 1 ) {

        my $name = shift;

        unless ( exists $self->cookies->{$name} ) {
            return undef;
        }

        return $self->cookies->{$name};
    }
}

=head2 $req->cookies

Returns a reference to a hash containing the cookies.

    print $c->request->cookies->{mycookie}->value;

The cookies in the hash are indexed by name, and the values are L<CGI::Simple::Cookie>
objects.

=head2 $req->header

Shortcut for $req->headers->header.

=head2 $req->headers

Returns an L<HTTP::Headers> object containing the headers for the current request.

    print $c->request->headers->header('X-Catalyst');

=head2 $req->hostname

Returns the hostname of the client. Use C<< $req->uri->host >> to get the hostname of the server.

=head2 $req->input

Alias for $req->body.

=head2 $req->query_keywords

Contains the keywords portion of a query string, when no '=' signs are
present.

    http://localhost/path?some+keywords

    $c->request->query_keywords will contain 'some keywords'

=head2 $req->match

This contains the matching part of a Regex action. Otherwise
it returns the same as 'action', except for default actions,
which return an empty string.

=head2 $req->method

Contains the request method (C<GET>, C<POST>, C<HEAD>, etc).

=head2 $req->param

Returns GET and POST parameters with a CGI.pm-compatible param method. This
is an alternative method for accessing parameters in $c->req->parameters.

    $value  = $c->request->param( 'foo' );
    @values = $c->request->param( 'foo' );
    @params = $c->request->param;

Like L<CGI>, and B<unlike> earlier versions of Catalyst, passing multiple
arguments to this method, like this:

    $c->request->param( 'foo', 'bar', 'gorch', 'quxx' );

will set the parameter C<foo> to the multiple values C<bar>, C<gorch> and
C<quxx>. Previously this would have added C<bar> as another value to C<foo>
(creating it if it didn't exist before), and C<quxx> as another value for
C<gorch>.

B<NOTE> this is considered a legacy interface and care should be taken when
using it. C<< scalar $c->req->param( 'foo' ) >> will return only the first
C<foo> param even if multiple are present; C<< $c->req->param( 'foo' ) >> will
return a list of as many are present, which can have unexpected consequences
when writing code of the form:

    $foo->bar(
        a => 'b',
        baz => $c->req->param( 'baz' ),
    );

If multiple C<baz> parameters are provided this code might corrupt data or
cause a hash initialization error. For a more straightforward interface see
C<< $c->req->parameters >>.

=cut

sub param {
    my $self = shift;

    if ( @_ == 0 ) {
        return keys %{ $self->parameters };
    }

    if ( @_ == 1 ) {

        my $param = shift;

        unless ( exists $self->parameters->{$param} ) {
            return wantarray ? () : undef;
        }

        if ( ref $self->parameters->{$param} eq 'ARRAY' ) {
            return (wantarray)
              ? @{ $self->parameters->{$param} }
              : $self->parameters->{$param}->[0];
        }
        else {
            return (wantarray)
              ? ( $self->parameters->{$param} )
              : $self->parameters->{$param};
        }
    }
    elsif ( @_ > 1 ) {
        my $field = shift;
        $self->parameters->{$field} = [@_];
    }
}

=head2 $req->parameters

Returns a reference to a hash containing GET and POST parameters. Values can
be either a scalar or an arrayref containing scalars.

    print $c->request->parameters->{field};
    print $c->request->parameters->{field}->[0];

This is the combination of C<query_parameters> and C<body_parameters>.

=head2 $req->params

Shortcut for $req->parameters.

=head2 $req->path

Returns the path, i.e. the part of the URI after $req->base, for the current request.

    http://localhost/path/foo

    $c->request->path will contain 'path/foo'

=head2 $req->path_info

Alias for path, added for compatibility with L<CGI>.

=cut

sub path {
    my ( $self, @params ) = @_;

    if (@params) {
        $self->uri->path(@params);
        $self->_clear_path;
    }
    elsif ( $self->_has_path ) {
        return $self->_path;
    }
    else {
        my $path     = $self->uri->path;
        my $location = $self->base->path;
        $path =~ s/^(\Q$location\E)?//;
        $path =~ s/^\///;
        $self->_path($path);

        return $path;
    }
}

=head2 $req->protocol

Returns the protocol (HTTP/1.0 or HTTP/1.1) used for the current request.

=head2 $req->query_parameters

=head2 $req->query_params

Returns a reference to a hash containing query string (GET) parameters. Values can
be either a scalar or an arrayref containing scalars.

    print $c->request->query_parameters->{field};
    print $c->request->query_parameters->{field}->[0];

=head2 $req->read( [$maxlength] )

Reads a chunk of data from the request body. This method is intended to be
used in a while loop, reading $maxlength bytes on every call. $maxlength
defaults to the size of the request if not specified.

=head2 $req->read_chunk(\$buff, $max)

Reads a chunk..

You have to set MyApp->config(parse_on_demand => 1) to use this directly.

=head2 $req->referer

Shortcut for $req->headers->referer. Returns the referring page.

=head2 $req->secure

Returns true or false, indicating whether the connection is secure
(https). Note that the URI scheme (e.g., http vs. https) must be determined
through heuristics, and therefore the reliability of $req->secure will depend
on your server configuration. If you are serving secure pages on the standard
SSL port (443) and/or setting the HTTPS environment variable, $req->secure
should be valid.

=head2 $req->captures

Returns a reference to an array containing captured args from chained
actions or regex captures.

    my @captures = @{ $c->request->captures };

=head2 $req->upload

A convenient method to access $req->uploads.

    $upload  = $c->request->upload('field');
    @uploads = $c->request->upload('field');
    @fields  = $c->request->upload;

    for my $upload ( $c->request->upload('field') ) {
        print $upload->filename;
    }

=cut

sub upload {
    my $self = shift;

    if ( @_ == 0 ) {
        return keys %{ $self->uploads };
    }

    if ( @_ == 1 ) {

        my $upload = shift;

        unless ( exists $self->uploads->{$upload} ) {
            return wantarray ? () : undef;
        }

        if ( ref $self->uploads->{$upload} eq 'ARRAY' ) {
            return (wantarray)
              ? @{ $self->uploads->{$upload} }
              : $self->uploads->{$upload}->[0];
        }
        else {
            return (wantarray)
              ? ( $self->uploads->{$upload} )
              : $self->uploads->{$upload};
        }
    }

    if ( @_ > 1 ) {

        while ( my ( $field, $upload ) = splice( @_, 0, 2 ) ) {

            if ( exists $self->uploads->{$field} ) {
                for ( $self->uploads->{$field} ) {
                    $_ = [$_] unless ref($_) eq "ARRAY";
                    push( @$_, $upload );
                }
            }
            else {
                $self->uploads->{$field} = $upload;
            }
        }
    }
}

=head2 $req->uploads

Returns a reference to a hash containing uploads. Values can be either a
L<Catalyst::Request::Upload> object, or an arrayref of
L<Catalyst::Request::Upload> objects.

    my $upload = $c->request->uploads->{field};
    my $upload = $c->request->uploads->{field}->[0];

=head2 $req->uri

Returns a L<URI> object for the current request. Stringifies to the URI text.

=head2 $req->mangle_params( { key => 'value' }, $appendmode);

Returns a hashref of parameters stemming from the current request's params,
plus the ones supplied.  Keys for which no current param exists will be
added, keys with undefined values will be removed and keys with existing
params will be replaced.  Note that you can supply a true value as the final
argument to change behavior with regards to existing parameters, appending
values rather than replacing them.

A quick example:

  # URI query params foo=1
  my $hashref = $req->mangle_params({ foo => 2 });
  # Result is query params of foo=2

versus append mode:

  # URI query params foo=1
  my $hashref = $req->mangle_params({ foo => 2 }, 1);
  # Result is query params of foo=1&foo=2

This is the code behind C<uri_with>.

=cut

sub mangle_params {
    my ($self, $args, $append) = @_;

    carp('No arguments passed to mangle_params()') unless $args;

    foreach my $value ( values %$args ) {
        next unless defined $value;
        for ( ref $value eq 'ARRAY' ? @$value : $value ) {
            $_ = "$_";
            utf8::encode( $_ ) if utf8::is_utf8($_);
        }
    };

    my %params = %{ $self->uri->query_form_hash };
    foreach my $key (keys %{ $args }) {
        my $val = $args->{$key};
        if(defined($val)) {

            if($append && exists($params{$key})) {

                # This little bit of heaven handles appending a new value onto
                # an existing one regardless if the existing value is an array
                # or not, and regardless if the new value is an array or not
                $params{$key} = [
                    ref($params{$key}) eq 'ARRAY' ? @{ $params{$key} } : $params{$key},
                    ref($val) eq 'ARRAY' ? @{ $val } : $val
                ];

            } else {
                $params{$key} = $val;
            }
        } else {

            # If the param wasn't defined then we delete it.
            delete($params{$key});
        }
    }


    return \%params;
}

=head2 $req->uri_with( { key => 'value' } );

Returns a rewritten URI object for the current request. Key/value pairs
passed in will override existing parameters. You can remove an existing
parameter by passing in an undef value. Unmodified pairs will be
preserved.

You may also pass an optional second parameter that puts C<uri_with> into
append mode:

  $req->uri_with( { key => 'value' }, { mode => 'append' } );

See C<mangle_params> for an explanation of this behavior.

=cut

sub uri_with {
    my( $self, $args, $behavior) = @_;

    carp( 'No arguments passed to uri_with()' ) unless $args;

    my $append = 0;
    if((ref($behavior) eq 'HASH') && defined($behavior->{mode}) && ($behavior->{mode} eq 'append')) {
        $append = 1;
    }

    my $params = $self->mangle_params($args, $append);

    my $uri = $self->uri->clone;
    $uri->query_form($params);

    return $uri;
}

=head2 $req->remote_user

Returns the value of the C<REMOTE_USER> environment variable.

=head2 $req->user_agent

Shortcut to $req->headers->user_agent. Returns the user agent (browser)
version string.

=head1 SETUP METHODS

You should never need to call these yourself in application code,
however they are useful if extending Catalyst by applying a request role.

=head2 $self->prepare_headers()

Sets up the C<< $res->headers >> accessor.

=head2 $self->prepare_body()

Sets up the body using L<HTTP::Body>

=head2 $self->prepare_body_chunk()

Add a chunk to the request body.

=head2 $self->prepare_body_parameters()

Sets up parameters from body.

=head2 $self->prepare_cookies()

Parse cookies from header. Sets up a L<CGI::Simple::Cookie> object.

=head2 $self->prepare_connection()

Sets up various fields in the request like the local and remote addresses,
request method, hostname requested etc.

=head2 $self->prepare_parameters()

Ensures that the body has been parsed, then builds the parameters, which are
combined from those in the request and those in the body.

This method is the builder for the 'parameters' attribute.

=head2 meta

Provided by Moose

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
