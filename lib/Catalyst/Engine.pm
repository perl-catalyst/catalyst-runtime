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

=over 4

=item $self->finalize_output

<obsolete>, see finalize_body

=item $self->finalize_body($c)

Finalize body.  Prints the response output.

=cut

sub finalize_body {
    my ( $self, $c ) = @_;
    if ( ref $c->response->body && $c->response->body->can('read') ) {
        while ( !$c->response->body->eof() ) {
            $c->response->body->read( my $buffer, $CHUNKSIZE );
            $self->write( $c, $buffer );
        }
        $c->response->body->close();
    }
    else {
        $self->write( $c, $c->response->body );
    }
}

=item $self->finalize_cookies($c)

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

    if (@cookies) {
        $c->res->headers->push_header( 'Set-Cookie' => join ',', @cookies );
    }
}

=item $self->finalize_error($c)

=cut

sub finalize_error {
    my ( $self, $c ) = @_;

    $c->res->headers->content_type('text/html');
    my $name = $c->config->{name} || 'Catalyst Application';

    my ( $title, $error, $infos );
    if ( $c->debug ) {

        # For pretty dumps
        local $Data::Dumper::Terse = 1;
        $error = join '',
          map { '<code class="error">' . encode_entities($_) . '</code>' }
          @{ $c->error };
        $error ||= 'No output';
        $title = $name = "$name on Catalyst $Catalyst::VERSION";

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
        $infos = <<"";
<br/>
<b><u>Request</u></b><br/>
<pre>$req</pre>
<b><u>Response</u></b><br/>
<pre>$res</pre>
<b><u>Stash</u></b><br/>
<pre>$stash</pre>

    }
    else {
        $title = $name;
        $error = '';
        $infos = <<"";
<pre>
(en) Please come back later
(de) Bitte versuchen sie es spaeter nocheinmal
(nl) Gelieve te komen later terug
(no) Vennligst prov igjen senere
(fr) Veuillez revenir plus tard
(es) Vuelto por favor mas adelante
(pt) Voltado por favor mais tarde
(it) Ritornato prego più successivamente
</pre>

        $name = '';
    }
    $c->res->body( <<"" );
<html>
<head>
    <title>$title</title>
    <style type="text/css">
        body {
            font-family: "Bitstream Vera Sans", "Trebuchet MS", Verdana,
                         Tahoma, Arial, helvetica, sans-serif;
            color: #ddd;
            background-color: #eee;
            margin: 0px;
            padding: 0px;
        }
        div.box {
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
            white-space: pre;
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

}

=item $self->finalize_headers($c)

=cut

sub finalize_headers { }

=item $self->finalize_read($c)

=cut

sub finalize_read {
    my ( $self, $c ) = @_;

    undef $self->{_prepared_read};
}

=item $self->finalize_uploads($c)

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

=item $self->prepare_body($c)

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

=item $self->prepare_body_chunk($c)

=cut

sub prepare_body_chunk {
    my ( $self, $c, $chunk ) = @_;

    $c->request->{_body}->add($chunk);
}

=item $self->prepare_body_parameters($c)

=cut

sub prepare_body_parameters {
    my ( $self, $c ) = @_;
    $c->request->body_parameters( $c->request->{_body}->param );
}

=item $self->prepare_connection($c)

=cut

sub prepare_connection { }

=item $self->prepare_cookies($c)

=cut

sub prepare_cookies {
    my ( $self, $c ) = @_;

    if ( my $header = $c->request->header('Cookie') ) {
        $c->req->cookies( { CGI::Cookie->parse($header) } );
    }
}

=item $self->prepare_headers($c)

=cut

sub prepare_headers { }

=item $self->prepare_parameters($c)

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

=item $self->prepare_path($c)

=cut

sub prepare_path { }

=item $self->prepare_request($c)

=item $self->prepare_query_parameters($c)

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

=item $self->prepare_read($c)

=cut

sub prepare_read {
    my ( $self, $c ) = @_;

    # Reset the read position
    $self->read_position(0);
}

=item $self->prepare_request(@arguments)

=cut

sub prepare_request { }

=item $self->prepare_uploads($c)

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

=item $self->prepare_write($c)

=cut

sub prepare_write { }

=item $self->read($c, [$maxlength])

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

=item $self->read_chunk($c, $buffer, $length)

Each engine inplements read_chunk as its preferred way of reading a chunk
of data.

=cut

sub read_chunk { }

=item $self->read_length

The length of input data to be read.  This is obtained from the Content-Length
header.

=item $self->read_position

The amount of input data that has already been read.

=item $self->run($c)

=cut

sub run { }

=item $self->write($c, $buffer)

=cut

sub write {
    my ( $self, $c, $buffer ) = @_;

    unless ( $self->{_prepared_write} ) {
        $self->prepare_write($c);
        $self->{_prepared_write} = 1;
    }

    print STDOUT $buffer;
}

=back

=head1 AUTHORS

Sebastian Riedel, <sri@cpan.org>

Andy Grundman, <andy@hybridized.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
