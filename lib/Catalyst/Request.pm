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

has action => (is => 'rw');
has address => (is => 'rw');
has arguments => (is => 'rw', default => sub { [] });
has cookies => (is => 'rw', default => sub { {} });
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
  default => sub { HTTP::Headers->new() },
  required => 1,
  lazy => 1,
);

has _context => (
  is => 'rw',
  weak_ref => 1,
  handles => ['read'],
  clearer => '_clear_context',
);

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
  required => 1,
  lazy => 1,
  default => sub { {} },
);

# TODO:
# - Can we lose the before modifiers which just call prepare_body ?
#   they are wasteful, slow us down and feel cluttery.

#  Can we make _body an attribute, have the rest of
#  these lazy build from there and kill all the direct hash access
#  in Catalyst.pm and Engine.pm?

before $_ => sub {
    my ($self) = @_;
    my $context = $self->_context || return;
    $context->prepare_body;
} for qw/parameters body_parameters/;

around parameters => sub {
    my ($orig, $self, $params) = @_;
    if ($params) {
        if ( !ref $params ) {
            $self->_context->log->warn(
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
  $self->_context->prepare_body();
  $self->_body(@_) if scalar @_;
  return blessed $self->_body ? $self->_body->body : $self->_body;
}

has hostname => (
  is        => 'rw',
  required  => 1,
  lazy      => 1,
  default   => sub {
    my ($self) = @_;
    gethostbyaddr( inet_aton( $self->address ), AF_INET ) || 'localhost'
  },
);

has _path => ( is => 'rw', predicate => '_has_path', clearer => '_clear_path' );

# XXX: Deprecated in docs ages ago (2006), deprecated with warning in 5.8000 due
# to confusion between Engines and Plugin::Authentication. Remove in 5.8100?
has user => (is => 'rw');

sub args            { shift->arguments(@_) }
sub body_params     { shift->body_parameters(@_) }
sub input           { shift->body(@_) }
sub params          { shift->parameters(@_) }
sub query_params    { shift->query_parameters(@_) }
sub path_info       { shift->path(@_) }
sub snippets        { shift->captures(@_) }

=head1 NAME

Catalyst::Request - provides information about the current client request

=head1 SYNOPSIS

    $req = $c->request;
    $req->action;
    $req->address;
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
    $req->captures; # previously knows as snippets
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

=head2 $req->action

[DEPRECATED] Returns the name of the requested action.


Use C<< $c->action >> instead (which returns a
L<Catalyst::Action|Catalyst::Action> object).

=head2 $req->address

Returns the IP address of the client.

=head2 $req->arguments

Returns a reference to an array containing the arguments.

    print $c->request->arguments->[0];

For example, if your action was

    package MyApp::C::Foo;

    sub moose : Local {
        ...
    }

and the URI for the request was C<http://.../foo/moose/bah>, the string C<bah>
would be the first and only argument.

Arguments get automatically URI-unescaped for you.

=head2 $req->args

Shortcut for arguments.

=head2 $req->base

Contains the URI base. This will always have a trailing slash. Note that the
URI scheme (eg., http vs. https) must be determined through heuristics;
depending on your server configuration, it may be incorrect. See $req->secure
for more info.

If your application was queried with the URI
C<http://localhost:3000/some/path> then C<base> is C<http://localhost:3000/>.

=head2 $req->body

Returns the message body of the request, unless Content-Type is
C<application/x-www-form-urlencoded> or C<multipart/form-data>.

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

The cookies in the hash are indexed by name, and the values are L<CGI::Cookie>
objects.

=head2 $req->header

Shortcut for $req->headers->header.

=head2 $req->headers

Returns an L<HTTP::Headers> object containing the headers for the current request.

    print $c->request->headers->header('X-Catalyst');

=head2 $req->hostname

Returns the hostname of the client.

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

You have to set MyApp->config->{parse_on_demand} to use this directly.

=head2 $req->referer

Shortcut for $req->headers->referer. Returns the referring page.

=head2 $req->secure

Returns true or false, indicating whether the connection is secure
(https). Note that the URI scheme (eg., http vs. https) must be determined
through heuristics, and therefore the reliablity of $req->secure will depend
on your server configuration. If you are serving secure pages on the standard
SSL port (443) and/or setting the HTTPS environment variable, $req->secure
should be valid.

=head2 $req->captures

Returns a reference to an array containing captured args from chained
actions or regex captures.

    my @captures = @{ $c->request->captures };

=head2 $req->snippets

C<captures> used to be called snippets. This is still available for backwards
compatibility, but is considered deprecated.

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

Returns a URI object for the current request. Stringifies to the URI text.

=head2 $req->uri_with( { key => 'value' } );

Returns a rewritten URI object for the current request. Key/value pairs
passed in will override existing parameters. You can remove an existing
parameter by passing in an undef value. Unmodified pairs will be
preserved.

=cut

sub uri_with {
    my( $self, $args ) = @_;

    carp( 'No arguments passed to uri_with()' ) unless $args;

    foreach my $value ( values %$args ) {
        next unless defined $value;
        for ( ref $value eq 'ARRAY' ? @$value : $value ) {
            $_ = "$_";
            utf8::encode( $_ ) if utf8::is_utf8($_);
        }
    };

    my $uri   = $self->uri->clone;
    my %query = ( %{ $uri->query_form_hash }, %$args );

    $uri->query_form( {
        # remove undef values
        map { defined $query{ $_ } ? ( $_ => $query{ $_ } ) : () } keys %query
    } );
    return $uri;
}

=head2 $req->user

Returns the currently logged in user. B<Highly deprecated>, do not call,
this will be removed in version 5.81.

=head2 $req->remote_user

Returns the value of the C<REMOTE_USER> environment variable.

=head2 $req->user_agent

Shortcut to $req->headers->user_agent. Returns the user agent (browser)
version string.

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
