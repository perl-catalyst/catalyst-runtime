package Catalyst::Engine;

use strict;
use base 'Class::Accessor::Fast';
use CGI::Cookie;
use Data::Dumper;
use HTML::Entities;
use HTTP::Body;
use HTTP::Headers;
use URI::QueryParam;

# input position and length
__PACKAGE__->mk_accessors(qw/read_position read_length/);

# Stringify to class
use overload '""' => sub { return ref shift }, fallback => 1;

# Amount of data to read from input on each pass
our $CHUNKSIZE = 4096;

=head1 NAME

Catalyst::Engine - The Catalyst Engine

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=head2 $self->finalize_output

<obsolete>, see finalize_body

=head2 $self->finalize_body($c)

Finalize body.  Prints the response output.

=cut

sub finalize_body {
    my ( $self, $c ) = @_;
    if ( ref $c->response->body && $c->response->body->can('read') ) {
        while ( !$c->response->body->eof() ) {
            $c->response->body->read( my $buffer, $CHUNKSIZE );
            last unless $self->write( $c, $buffer );
        }
        $c->response->body->close();
    }
    else {
        $self->write( $c, $c->response->body );
    }
}

=head2 $self->finalize_cookies($c)

=cut

sub finalize_cookies {
    my ( $self, $c ) = @_;

    my @cookies;
    while ( my ( $name, $cookie ) = each %{ $c->response->cookies } ) {

        my $cookie = CGI::Cookie->new(
            -name    => $name,
            -value   => $cookie->{value},
            -expires => $cookie->{expires},
            -domain  => $cookie->{domain},
            -path    => $cookie->{path},
            -secure  => $cookie->{secure} || 0
        );

        push @cookies, $cookie->as_string;
    }

    for my $cookie (@cookies) {
        $c->res->headers->push_header( 'Set-Cookie' => $cookie );
    }
}

=head2 $self->finalize_error($c)

=cut

sub finalize_error {
    my ( $self, $c ) = @_;

    $c->res->content_type('text/html; charset=utf-8');
    my $name = $c->config->{name} || 'Catalyst Application';

    my ( $title, $error, $infos );
    if ( $c->debug ) {

        # For pretty dumps
        local $Data::Dumper::Terse = 1;
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
        delete $c->req->{_context};
        delete $c->res->{_context};

        # Don't show body parser in the dump
        delete $c->req->{_body};

        # Don't show response header state in dump
        delete $c->res->{_finalized_headers};

        my $req   = encode_entities Dumper $c->req;
        my $res   = encode_entities Dumper $c->res;
        my $stash = encode_entities Dumper $c->stash;

        my @infos;
        my $i = 0;
        for my $dump ( $c->dump_these ) {
            my $name  = $dump->[0];
            my $value = encode_entities( Dumper $dump->[1] );
            push @infos, sprintf <<"EOF", $name, $value;
<h2><a href="#" onclick="toggleDump('dump_$i'); return false">%s</a></h2>
<div id="dump_$i">
    <pre wrap="">%s</pre>
</div>
EOF
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
(de) Bitte versuchen sie es spaeter nocheinmal
(at) Konnten's bitt'schoen spaeter nochmal reinschauen
(no) Vennligst prov igjen senere
(dk) Venligst prov igen senere
(pl) Prosze sprobowac pozniej
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
            color: #ddd;
            background-color: #eee;
            margin: 0px;
            padding: 0px;
        }
        :link, :link:hover, :visited, :visited:hover {
            color: #ddd;
        }
        div.box {
            position: relative;
            background-color: #ccc;
            border: 1px solid #aaa;
            padding: 4px;
            margin: 10px;
            -moz-border-radius: 10px;
        }
        div.error {
            background-color: #977;
            border: 1px solid #755;
            padding: 8px;
            margin: 4px;
            margin-bottom: 10px;
            -moz-border-radius: 10px;
        }
        div.infos {
            background-color: #797;
            border: 1px solid #575;
            padding: 8px;
            margin: 4px;
            margin-bottom: 10px;
            -moz-border-radius: 10px;
        }
        div.name {
            background-color: #779;
            border: 1px solid #557;
            padding: 8px;
            margin: 4px;
            -moz-border-radius: 10px;
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

=cut

sub finalize_headers { }

=head2 $self->finalize_read($c)

=cut

sub finalize_read {
    my ( $self, $c ) = @_;

    undef $self->{_prepared_read};
}

=head2 $self->finalize_uploads($c)

=cut

sub finalize_uploads {
    my ( $self, $c ) = @_;

    if ( keys %{ $c->request->uploads } ) {
        for my $key ( keys %{ $c->request->uploads } ) {
            my $upload = $c->request->uploads->{$key};
            unlink map { $_->tempname }
              grep     { -e $_->tempname }
              ref $upload eq 'ARRAY' ? @{$upload} : ($upload);
        }
    }
}

=head2 $self->prepare_body($c)

=cut

sub prepare_body {
    my ( $self, $c ) = @_;

    $self->read_length( $c->request->header('Content-Length') || 0 );
    my $type = $c->request->header('Content-Type');

    unless ( $c->request->{_body} ) {
        $c->request->{_body} = HTTP::Body->new( $type, $self->read_length );
    }

    if ( $self->read_length > 0 ) {
        while ( my $buffer = $self->read($c) ) {
            $c->prepare_body_chunk($buffer);
        }
    }
}

=head2 $self->prepare_body_chunk($c)

=cut

sub prepare_body_chunk {
    my ( $self, $c, $chunk ) = @_;

    $c->request->{_body}->add($chunk);
}

=head2 $self->prepare_body_parameters($c)

=cut

sub prepare_body_parameters {
    my ( $self, $c ) = @_;
    $c->request->body_parameters( $c->request->{_body}->param );
}

=head2 $self->prepare_connection($c)

=cut

sub prepare_connection { }

=head2 $self->prepare_cookies($c)

=cut

sub prepare_cookies {
    my ( $self, $c ) = @_;

    if ( my $header = $c->request->header('Cookie') ) {
        $c->req->cookies( { CGI::Cookie->parse($header) } );
    }
}

=head2 $self->prepare_headers($c)

=cut

sub prepare_headers { }

=head2 $self->prepare_parameters($c)

=cut

sub prepare_parameters {
    my ( $self, $c ) = @_;

    # We copy, no references
    while ( my ( $name, $param ) = each %{ $c->request->query_parameters } ) {
        $param = ref $param eq 'ARRAY' ? [ @{$param} ] : $param;
        $c->request->parameters->{$name} = $param;
    }

    # Merge query and body parameters
    while ( my ( $name, $param ) = each %{ $c->request->body_parameters } ) {
        $param = ref $param eq 'ARRAY' ? [ @{$param} ] : $param;
        if ( my $old_param = $c->request->parameters->{$name} ) {
            if ( ref $old_param eq 'ARRAY' ) {
                push @{ $c->request->parameters->{$name} },
                  ref $param eq 'ARRAY' ? @$param : $param;
            }
            else { $c->request->parameters->{$name} = [ $old_param, $param ] }
        }
        else { $c->request->parameters->{$name} = $param }
    }
}

=head2 $self->prepare_path($c)

=cut

sub prepare_path { }

=head2 $self->prepare_request($c)

=head2 $self->prepare_query_parameters($c)

=cut

sub prepare_query_parameters {
    my ( $self, $c, $query_string ) = @_;

    # replace semi-colons
    $query_string =~ s/;/&/g;

    my $u = URI->new( '', 'http' );
    $u->query($query_string);
    for my $key ( $u->query_param ) {
        my @vals = $u->query_param($key);
        $c->request->query_parameters->{$key} = @vals > 1 ? [@vals] : $vals[0];
    }
}

=head2 $self->prepare_read($c)

=cut

sub prepare_read {
    my ( $self, $c ) = @_;

    # Reset the read position
    $self->read_position(0);
}

=head2 $self->prepare_request(@arguments)

=cut

sub prepare_request { }

=head2 $self->prepare_uploads($c)

=cut

sub prepare_uploads {
    my ( $self, $c ) = @_;
    my $uploads = $c->request->{_body}->upload;
    for my $name ( keys %$uploads ) {
        my $files = $uploads->{$name};
        $files = ref $files eq 'ARRAY' ? $files : [$files];
        my @uploads;
        for my $upload (@$files) {
            my $u = Catalyst::Request::Upload->new;
            $u->headers( HTTP::Headers->new( %{ $upload->{headers} } ) );
            $u->type( $u->headers->content_type );
            $u->tempname( $upload->{tempname} );
            $u->size( $upload->{size} );
            $u->filename( $upload->{filename} );
            push @uploads, $u;
        }
        $c->request->uploads->{$name} = @uploads > 1 ? \@uploads : $uploads[0];

        # support access to the filename as a normal param
        my @filenames = map { $_->{filename} } @uploads;
        $c->request->parameters->{$name} =
          @filenames > 1 ? \@filenames : $filenames[0];
    }
}

=head2 $self->prepare_write($c)

=cut

sub prepare_write { }

=head2 $self->read($c, [$maxlength])

=cut

sub read {
    my ( $self, $c, $maxlength ) = @_;

    unless ( $self->{_prepared_read} ) {
        $self->prepare_read($c);
        $self->{_prepared_read} = 1;
    }

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
        $self->read_position( $self->read_position + $rc );
        return $buffer;
    }
    else {
        Catalyst::Exception->throw(
            message => "Unknown error reading input: $!" );
    }
}

=head2 $self->read_chunk($c, $buffer, $length)

Each engine inplements read_chunk as its preferred way of reading a chunk
of data.

=cut

sub read_chunk { }

=head2 $self->read_length

The length of input data to be read.  This is obtained from the Content-Length
header.

=head2 $self->read_position

The amount of input data that has already been read.

=head2 $self->run($c)

=cut

sub run { }

=head2 $self->write($c, $buffer)

=cut

sub write {
    my ( $self, $c, $buffer ) = @_;

    unless ( $self->{_prepared_write} ) {
        $self->prepare_write($c);
        $self->{_prepared_write} = 1;
    }

    print STDOUT $buffer;
}

=head1 AUTHORS

Sebastian Riedel, <sri@cpan.org>

Andy Grundman, <andy@hybridized.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
