package Catalyst::Engine;

use Moose;
with 'MooseX::Emulate::Class::Accessor::Fast';

use CGI::Simple::Cookie;
use Data::Dump qw/dump/;
use Errno 'EWOULDBLOCK';
use HTML::Entities;
use HTTP::Body;
use HTTP::Headers;
use URI::QueryParam;
use Moose::Util::TypeConstraints;
use Plack::Loader;
use Plack::Middleware::Conditional;
use Plack::Middleware::ReverseProxy;

use namespace::clean -except => 'meta';

has env => (is => 'ro', writer => '_set_env', clearer => '_clear_env');

# input position and length
has read_length => (is => 'rw');
has read_position => (is => 'rw');

has _prepared_write => (is => 'rw');

has _response_cb => (
    is      => 'ro',
    isa     => 'CodeRef',
    writer  => '_set_response_cb',
    clearer => '_clear_response_cb',
);

has _writer => (
    is      => 'ro',
    isa     => duck_type([qw(write close)]),
    writer  => '_set_writer',
    clearer => '_clear_writer',
);

# Amount of data to read from input on each pass
our $CHUNKSIZE = 64 * 1024;

=head1 NAME

Catalyst::Engine - The Catalyst Engine

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS


=head2 $self->finalize_body($c)

Finalize body.  Prints the response output.

=cut

sub finalize_body {
    my ( $self, $c ) = @_;
    my $body = $c->response->body;
    no warnings 'uninitialized';
    if ( blessed($body) && $body->can('read') or ref($body) eq 'GLOB' ) {
        my $got;
        do {
            $got = read $body, my ($buffer), $CHUNKSIZE;
            $got = 0 unless $self->write( $c, $buffer );
        } while $got > 0;

        close $body;
    }
    else {
        $self->write( $c, $body );
    }

    $self->_writer->close;
    $self->_clear_writer;
    $self->_clear_env;

    return;
}

=head2 $self->finalize_cookies($c)

Create CGI::Simple::Cookie objects from $c->res->cookies, and set them as
response headers.

=cut

sub finalize_cookies {
    my ( $self, $c ) = @_;

    my @cookies;
    my $response = $c->response;

    foreach my $name (keys %{ $response->cookies }) {

        my $val = $response->cookies->{$name};

        my $cookie = (
            blessed($val)
            ? $val
            : CGI::Simple::Cookie->new(
                -name    => $name,
                -value   => $val->{value},
                -expires => $val->{expires},
                -domain  => $val->{domain},
                -path    => $val->{path},
                -secure  => $val->{secure} || 0,
                -httponly => $val->{httponly} || 0,
            )
        );

        push @cookies, $cookie->as_string;
    }

    for my $cookie (@cookies) {
        $response->headers->push_header( 'Set-Cookie' => $cookie );
    }
}

=head2 $self->finalize_error($c)

Output an appropriate error message. Called if there's an error in $c
after the dispatch has finished. Will output debug messages if Catalyst
is in debug mode, or a `please come back later` message otherwise.

=cut

sub _dump_error_page_element {
    my ($self, $i, $element) = @_;
    my ($name, $val)  = @{ $element };

    # This is fugly, but the metaclass is _HUGE_ and demands waaay too much
    # scrolling. Suggestions for more pleasant ways to do this welcome.
    local $val->{'__MOP__'} = "Stringified: "
        . $val->{'__MOP__'} if ref $val eq 'HASH' && exists $val->{'__MOP__'};

    my $text = encode_entities( dump( $val ));
    sprintf <<"EOF", $name, $text;
<h2><a href="#" onclick="toggleDump('dump_$i'); return false">%s</a></h2>
<div id="dump_$i">
    <pre wrap="">%s</pre>
</div>
EOF
}

sub finalize_error {
    my ( $self, $c ) = @_;

    $c->res->content_type('text/html; charset=utf-8');
    my $name = ref($c)->config->{name} || join(' ', split('::', ref $c));

    my ( $title, $error, $infos );
    if ( $c->debug ) {

        # For pretty dumps
        $error = join '', map {
                '<p><code class="error">'
              . encode_entities($_)
              . '</code></p>'
        } @{ $c->error };
        $error ||= 'No output';
        $error = qq{<pre wrap="">$error</pre>};
        $title = $name = "$name on Catalyst $Catalyst::VERSION";
        $name  = "<h1>$name</h1>";

        # Don't show context in the dump
        $c->req->_clear_context;
        $c->res->_clear_context;

        # Don't show body parser in the dump
        $c->req->_clear_body;

        my @infos;
        my $i = 0;
        for my $dump ( $c->dump_these ) {
            push @infos, $self->_dump_error_page_element($i, $dump);
            $i++;
        }
        $infos = join "\n", @infos;
    }
    else {
        $title = $name;
        $error = '';
        $infos = <<"";
<pre>
(en) Please come back later
(fr) SVP veuillez revenir plus tard
(de) Bitte versuchen sie es spaeter nocheinmal
(at) Konnten's bitt'schoen spaeter nochmal reinschauen
(no) Vennligst prov igjen senere
(dk) Venligst prov igen senere
(pl) Prosze sprobowac pozniej
(pt) Por favor volte mais tarde
(ru) Попробуйте еще раз позже
(ua) Спробуйте ще раз пізніше
</pre>

        $name = '';
    }
    $c->res->body( <<"" );
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
    <meta http-equiv="Content-Language" content="en" />
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <title>$title</title>
    <script type="text/javascript">
        <!--
        function toggleDump (dumpElement) {
            var e = document.getElementById( dumpElement );
            if (e.style.display == "none") {
                e.style.display = "";
            }
            else {
                e.style.display = "none";
            }
        }
        -->
    </script>
    <style type="text/css">
        body {
            font-family: "Bitstream Vera Sans", "Trebuchet MS", Verdana,
                         Tahoma, Arial, helvetica, sans-serif;
            color: #333;
            background-color: #eee;
            margin: 0px;
            padding: 0px;
        }
        :link, :link:hover, :visited, :visited:hover {
            color: #000;
        }
        div.box {
            position: relative;
            background-color: #ccc;
            border: 1px solid #aaa;
            padding: 4px;
            margin: 10px;
        }
        div.error {
            background-color: #cce;
            border: 1px solid #755;
            padding: 8px;
            margin: 4px;
            margin-bottom: 10px;
        }
        div.infos {
            background-color: #eee;
            border: 1px solid #575;
            padding: 8px;
            margin: 4px;
            margin-bottom: 10px;
        }
        div.name {
            background-color: #cce;
            border: 1px solid #557;
            padding: 8px;
            margin: 4px;
        }
        code.error {
            display: block;
            margin: 1em 0;
            overflow: auto;
        }
        div.name h1, div.error p {
            margin: 0;
        }
        h2 {
            margin-top: 0;
            margin-bottom: 10px;
            font-size: medium;
            font-weight: bold;
            text-decoration: underline;
        }
        h1 {
            font-size: medium;
            font-weight: normal;
        }
        /* from http://users.tkk.fi/~tkarvine/linux/doc/pre-wrap/pre-wrap-css3-mozilla-opera-ie.html */
        /* Browser specific (not valid) styles to make preformatted text wrap */
        pre {
            white-space: pre-wrap;       /* css-3 */
            white-space: -moz-pre-wrap;  /* Mozilla, since 1999 */
            white-space: -pre-wrap;      /* Opera 4-6 */
            white-space: -o-pre-wrap;    /* Opera 7 */
            word-wrap: break-word;       /* Internet Explorer 5.5+ */
        }
    </style>
</head>
<body>
    <div class="box">
        <div class="error">$error</div>
        <div class="infos">$infos</div>
        <div class="name">$name</div>
    </div>
</body>
</html>


    # Trick IE
    $c->res->{body} .= ( ' ' x 512 );

    # Return 500
    $c->res->status(500);
}

=head2 $self->finalize_headers($c)

Abstract method, allows engines to write headers to response

=cut

sub finalize_headers {
    my ($self, $ctx) = @_;

    my @headers;
    $ctx->response->headers->scan(sub { push @headers, @_ });

    $self->_set_writer($self->_response_cb->([ $ctx->response->status, \@headers ]));
    $self->_clear_response_cb;

    return;
}

=head2 $self->finalize_read($c)

=cut

sub finalize_read { }

=head2 $self->finalize_uploads($c)

Clean up after uploads, deleting temp files.

=cut

sub finalize_uploads {
    my ( $self, $c ) = @_;

    my $request = $c->request;
    foreach my $key (keys %{ $request->uploads }) {
        my $upload = $request->uploads->{$key};
        unlink grep { -e $_ } map { $_->tempname }
          (ref $upload eq 'ARRAY' ? @{$upload} : ($upload));
    }

}

=head2 $self->prepare_body($c)

sets up the L<Catalyst::Request> object body using L<HTTP::Body>

=cut

sub prepare_body {
    my ( $self, $c ) = @_;

    my $appclass = ref($c) || $c;
    if ( my $length = $self->read_length ) {
        my $request = $c->request;
        unless ( $request->_body ) {
            my $type = $request->header('Content-Type');
            $request->_body(HTTP::Body->new( $type, $length ));
            $request->_body->tmpdir( $appclass->config->{uploadtmp} )
              if exists $appclass->config->{uploadtmp};
        }

        # Check for definedness as you could read '0'
        while ( defined ( my $buffer = $self->read($c) ) ) {
            $c->prepare_body_chunk($buffer);
        }

        # paranoia against wrong Content-Length header
        my $remaining = $length - $self->read_position;
        if ( $remaining > 0 ) {
            $self->finalize_read($c);
            Catalyst::Exception->throw(
                "Wrong Content-Length value: $length" );
        }
    }
    else {
        # Defined but will cause all body code to be skipped
        $c->request->_body(0);
    }
}

=head2 $self->prepare_body_chunk($c)

Add a chunk to the request body.

=cut

sub prepare_body_chunk {
    my ( $self, $c, $chunk ) = @_;

    $c->request->_body->add($chunk);
}

=head2 $self->prepare_body_parameters($c)

Sets up parameters from body.

=cut

sub prepare_body_parameters {
    my ( $self, $c ) = @_;

    return unless $c->request->_body;

    $c->request->body_parameters( $c->request->_body->param );
}

=head2 $self->prepare_connection($c)

Abstract method implemented in engines.

=cut

sub prepare_connection {
    my ($self, $ctx) = @_;

    my $env = $self->env;
    my $request = $ctx->request;

    $request->address( $env->{REMOTE_ADDR} );
    $request->hostname( $env->{REMOTE_HOST} )
        if exists $env->{REMOTE_HOST};
    $request->protocol( $env->{SERVER_PROTOCOL} );
    $request->remote_user( $env->{REMOTE_USER} );
    $request->method( $env->{REQUEST_METHOD} );
    $request->secure( $env->{'psgi.url_scheme'} eq 'https' ? 1 : 0 );

    return;
}

=head2 $self->prepare_cookies($c)

Parse cookies from header. Sets a L<CGI::Simple::Cookie> object.

=cut

sub prepare_cookies {
    my ( $self, $c ) = @_;

    if ( my $header = $c->request->header('Cookie') ) {
        $c->req->cookies( { CGI::Simple::Cookie->parse($header) } );
    }
}

=head2 $self->prepare_headers($c)

=cut

sub prepare_headers {
    my ($self, $ctx) = @_;

    my $env = $self->env;
    my $headers = $ctx->request->headers;

    for my $header (keys %{ $env }) {
        next unless $header =~ /^(HTTP|CONTENT|COOKIE)/i;
        (my $field = $header) =~ s/^HTTPS?_//;
        $field =~ tr/_/-/;
        $headers->header($field => $env->{$header});
    }
}

=head2 $self->prepare_parameters($c)

sets up parameters from query and post parameters.

=cut

sub prepare_parameters {
    my ( $self, $c ) = @_;

    my $request = $c->request;
    my $parameters = $request->parameters;
    my $body_parameters = $request->body_parameters;
    my $query_parameters = $request->query_parameters;
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
}

=head2 $self->prepare_path($c)

abstract method, implemented by engines.

=cut

sub prepare_path {
    my ($self, $ctx) = @_;

    my $env = $self->env;

    my $scheme    = $ctx->request->secure ? 'https' : 'http';
    my $host      = $env->{HTTP_HOST} || $env->{SERVER_NAME};
    my $port      = $env->{SERVER_PORT} || 80;
    my $base_path = $env->{SCRIPT_NAME} || "/";

    # set the request URI
    my $req_uri = $env->{REQUEST_URI};
    $req_uri =~ s/\?.*$//;
    my $path = $req_uri;
    $path =~ s{^/+}{};

    # Using URI directly is way too slow, so we construct the URLs manually
    my $uri_class = "URI::$scheme";

    # HTTP_HOST will include the port even if it's 80/443
    $host =~ s/:(?:80|443)$//;

    if ($port !~ /^(?:80|443)$/ && $host !~ /:/) {
        $host .= ":$port";
    }

    my $query = $env->{QUERY_STRING} ? '?' . $env->{QUERY_STRING} : '';
    my $uri   = $scheme . '://' . $host . '/' . $path . $query;

    $ctx->request->uri( bless \$uri, $uri_class );

    # set the base URI
    # base must end in a slash
    $base_path .= '/' unless $base_path =~ m{/$};

    my $base_uri = $scheme . '://' . $host . $base_path;

    $ctx->request->base( bless \$base_uri, $uri_class );

    return;
}

=head2 $self->prepare_request($c)

=head2 $self->prepare_query_parameters($c)

process the query string and extract query parameters.

=cut

sub prepare_query_parameters {
    my ($self, $c) = @_;

    my $query_string = exists $self->env->{QUERY_STRING}
        ? $self->env->{QUERY_STRING}
        : '';

    # Check for keywords (no = signs)
    # (yes, index() is faster than a regex :))
    if ( index( $query_string, '=' ) < 0 ) {
        $c->request->query_keywords( $self->unescape_uri($query_string) );
        return;
    }

    my %query;

    # replace semi-colons
    $query_string =~ s/;/&/g;

    my @params = grep { length $_ } split /&/, $query_string;

    for my $item ( @params ) {

        my ($param, $value)
            = map { $self->unescape_uri($_) }
              split( /=/, $item, 2 );

        $param = $self->unescape_uri($item) unless defined $param;

        if ( exists $query{$param} ) {
            if ( ref $query{$param} ) {
                push @{ $query{$param} }, $value;
            }
            else {
                $query{$param} = [ $query{$param}, $value ];
            }
        }
        else {
            $query{$param} = $value;
        }
    }

    $c->request->query_parameters( \%query );
}

=head2 $self->prepare_read($c)

prepare to read from the engine.

=cut

sub prepare_read {
    my ( $self, $c ) = @_;

    # Initialize the read position
    $self->read_position(0);

    # Initialize the amount of data we think we need to read
    $self->read_length( $c->request->header('Content-Length') || 0 );
}

=head2 $self->prepare_request(@arguments)

Populate the context object from the request object.

=cut

sub prepare_request {
    my ($self, $ctx, %args) = @_;
    $self->_set_env($args{env});
}

=head2 $self->prepare_uploads($c)

=cut

sub prepare_uploads {
    my ( $self, $c ) = @_;

    my $request = $c->request;
    return unless $request->_body;

    my $uploads = $request->_body->upload;
    my $parameters = $request->parameters;
    foreach my $name (keys %$uploads) {
        my $files = $uploads->{$name};
        my @uploads;
        for my $upload (ref $files eq 'ARRAY' ? @$files : ($files)) {
            my $headers = HTTP::Headers->new( %{ $upload->{headers} } );
            my $u = Catalyst::Request::Upload->new
              (
               size => $upload->{size},
               type => $headers->content_type,
               headers => $headers,
               tempname => $upload->{tempname},
               filename => $upload->{filename},
              );
            push @uploads, $u;
        }
        $request->uploads->{$name} = @uploads > 1 ? \@uploads : $uploads[0];

        # support access to the filename as a normal param
        my @filenames = map { $_->{filename} } @uploads;
        # append, if there's already params with this name
        if (exists $parameters->{$name}) {
            if (ref $parameters->{$name} eq 'ARRAY') {
                push @{ $parameters->{$name} }, @filenames;
            }
            else {
                $parameters->{$name} = [ $parameters->{$name}, @filenames ];
            }
        }
        else {
            $parameters->{$name} = @filenames > 1 ? \@filenames : $filenames[0];
        }
    }
}

=head2 $self->prepare_write($c)

Abstract method. Implemented by the engines.

=cut

sub prepare_write { }

=head2 $self->read($c, [$maxlength])

Reads from the input stream by calling C<< $self->read_chunk >>.

Maintains the read_length and read_position counters as data is read.

=cut

sub read {
    my ( $self, $c, $maxlength ) = @_;

    my $remaining = $self->read_length - $self->read_position;
    $maxlength ||= $CHUNKSIZE;

    # Are we done reading?
    if ( $remaining <= 0 ) {
        $self->finalize_read($c);
        return;
    }

    my $readlen = ( $remaining > $maxlength ) ? $maxlength : $remaining;
    my $rc = $self->read_chunk( $c, my $buffer, $readlen );
    if ( defined $rc ) {
        if (0 == $rc) { # Nothing more to read even though Content-Length
                        # said there should be.
            $self->finalize_read;
            return;
        }
        $self->read_position( $self->read_position + $rc );
        return $buffer;
    }
    else {
        Catalyst::Exception->throw(
            message => "Unknown error reading input: $!" );
    }
}

=head2 $self->read_chunk($c, $buffer, $length)

Each engine implements read_chunk as its preferred way of reading a chunk
of data. Returns the number of bytes read. A return of 0 indicates that
there is no more data to be read.

=cut

sub read_chunk {
    my ($self, $ctx) = (shift, shift);
    return $self->env->{'psgi.input'}->read(@_);
}

=head2 $self->read_length

The length of input data to be read.  This is obtained from the Content-Length
header.

=head2 $self->read_position

The amount of input data that has already been read.

=head2 $self->run($c)

Start the engine. Implemented by the various engine classes.

=cut

sub run {
    my ($self, $app, @args) = @_;
    Carp::cluck("Run");
    # FIXME - Do something sensible with the options we're passed
    $self->_run_psgi_app($self->_build_psgi_app($app, @args), @args);
}

sub _build_psgi_app {
    my ($self, $app, @args) = @_;

    my $psgi_app = sub {
        my ($env) = @_;

        return sub {
            my ($respond) = @_;
            $self->_set_response_cb($respond);
            $app->handle_request(env => $env);
        };
    };

    $psgi_app = Plack::Middleware::Conditional->wrap(
        $psgi_app,
        condition => sub {
            my ($env) = @_;
            return if $app->config->{ignore_frontend_proxy};
            return $env->{REMOTE_ADDR} eq '127.0.0.1' || $app->config->{using_frontend_proxy};
        },
        builder   => sub { Plack::Middleware::ReverseProxy->wrap($_[0]) },
    );

    return $psgi_app;
}

sub _run_psgi_app {
    my ($self, $psgi_app, @args);
    # FIXME - Need to be able to specify engine and pass options..
    Plack::Loader->auto()->run($psgi_app);
}

=head2 $self->write($c, $buffer)

Writes the buffer to the client.

=cut

sub write {
    my ( $self, $c, $buffer ) = @_;

    unless ( $self->_prepared_write ) {
        $self->prepare_write($c);
        $self->_prepared_write(1);
    }

    return 0 if !defined $buffer;

    my $len = length($buffer);
    $self->_writer->write($buffer);

    return $len;
}

=head2 $self->unescape_uri($uri)

Unescapes a given URI using the most efficient method available.  Engines such
as Apache may implement this using Apache's C-based modules, for example.

=cut

sub unescape_uri {
    my ( $self, $str ) = @_;

    $str =~ s/(?:%([0-9A-Fa-f]{2})|\+)/defined $1 ? chr(hex($1)) : ' '/eg;

    return $str;
}

=head2 $self->finalize_output

<obsolete>, see finalize_body

=head2 $self->env

Hash containing enviroment variables including many special variables inserted
by WWW server - like SERVER_*, REMOTE_*, HTTP_* ...

Before accesing enviroment variables consider whether the same information is
not directly available via Catalyst objects $c->request, $c->engine ...

BEWARE: If you really need to access some enviroment variable from your Catalyst
application you should use $c->engine->env->{VARNAME} instead of $ENV{VARNAME},
as in some enviroments the %ENV hash does not contain what you would expect.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
