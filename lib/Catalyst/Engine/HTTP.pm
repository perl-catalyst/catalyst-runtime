package Catalyst::Engine::HTTP;

use strict;
use base 'Catalyst::Engine';

use CGI::Simple::Cookie;
use Class::Struct ();
use HTTP::Headers::Util 'split_header_words';
use HTTP::Request;
use HTTP::Response;
use IO::File;
use URI;

__PACKAGE__->mk_accessors(qw/http/);

Class::Struct::struct 'Catalyst::Engine::HTTP::LWP' => {
    request  => 'HTTP::Request',
    response => 'HTTP::Response',
    hostname => '$',
    address  => '$'
};


=head1 NAME

Catalyst::Engine::HTTP - Catalyst HTTP Engine

=head1 SYNOPSIS

L<Catalyst>.

=head1 DESCRIPTION

This Catalyst engine is meant to be subclassed.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine>.

=over 4

=item $c->finalize_headers

=cut

sub finalize_headers {
    my $c = shift;

    my $status   = $c->response->status || 200;
    my $headers  = $c->response->headers;
    my $response = HTTP::Response->new( $status, undef, $headers );

    while ( my ( $name, $cookie ) = each %{ $c->response->cookies } ) {
        my $cookie = CGI::Simple::Cookie->new(
            -name    => $name,
            -value   => $cookie->{value},
            -expires => $cookie->{expires},
            -domain  => $cookie->{domain},
            -path    => $cookie->{path},
            -secure  => $cookie->{secure} || 0
        );

        $response->header( 'Set-Cookie' => $cookie->as_string );
    }

    $c->http->response($response);
}

=item $c->finalize_output

=cut

sub finalize_output {
    my $c = shift;
    $c->http->response->content_ref( \$c->response->{output} );
}

=item $c->prepare_connection

=cut

sub prepare_connection {
    my $c = shift;
    $c->req->hostname( $c->http->hostname );
    $c->req->address( $c->http->address );
}

=item $c->prepare_cookies

=cut

sub prepare_cookies {
    my $c = shift;

    if ( my $header = $c->http->request->header('Cookie') ) {
        $c->req->cookies( { CGI::Simple::Cookie->parse($header) } );
    }
}

=item $c->prepare_headers

=cut

sub prepare_headers {
    my $c = shift;
    $c->req->method( $c->http->request->method );
    $c->req->headers( $c->http->request->headers );
}

=item $c->prepare_parameters

=cut

sub prepare_parameters {
    my $c = shift;

    my @params  = ();
    my $request = $c->http->request;

    push( @params, $request->uri->query_form );

    if ( $request->content_type eq 'application/x-www-form-urlencoded' ) {
        my $uri = URI->new('http:');
        $uri->query( $request->content );
        push( @params, $uri->query_form );
    }

    if ( $request->content_type eq 'multipart/form-data' ) {

        for my $part ( $request->parts ) {

            my $disposition = $part->header('Content-Disposition');
            my %parameters  = @{ ( split_header_words($disposition) )[0] };

            if ( $parameters{filename} ) {

                my $fh = IO::File->new_tmpfile;
                $fh->write( $part->content ) or die $!;
                $fh->seek( SEEK_SET, 0 ) or die $!;

                $c->req->uploads->{ $parameters{filename} } = {
                    fh   => $fh,
                    size => ( stat $fh )[7],
                    type => $part->content_type
                };

                push( @params, $parameters{filename}, $fh );
            }
            else {
                push( @params, $parameters{name}, $part->content );
            }
        }
    }

    my $parameters = $c->req->parameters;

    while ( my ( $name, $value ) = splice( @params, 0, 2 ) ) {

        if ( exists $parameters->{$name} ) {
            for ( $parameters->{$name} ) {
                $_ = [$_] unless ref($_) eq "ARRAY";
                push( @$_, $value );
            }
        }
        else {
            $parameters->{$name} = $value;
        }
    }
}

=item $c->prepare_path

=cut

sub prepare_path {
    my $c = shift;

    my $base;
    {
        my $scheme = $c->http->request->uri->scheme;
        my $host   = $c->http->request->uri->host;
        my $port   = $c->http->request->uri->port;

        $base = URI->new;
        $base->scheme($scheme);
        $base->host($host);
        $base->port($port);

        $base = $base->canonical->as_string;
    }

    my $path = $c->http->request->uri->path || '/';
    $path =~ s/^\///;

    $c->req->base($base);
    $c->req->path($path);
}

=item $c->prepare_request($r)

=cut

sub prepare_request {
    my ( $c, $http ) = @_;
    $c->http($http);
}

=item $c->prepare_uploads

=cut

sub prepare_uploads {
    my $c = shift;
}

=back

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
