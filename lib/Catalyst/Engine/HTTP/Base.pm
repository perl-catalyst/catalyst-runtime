package Catalyst::Engine::HTTP::Base;

use strict;
use base 'Catalyst::Engine';

use Catalyst::Exception;
use Class::Struct ();
use HTTP::Headers::Util 'split_header_words';
use HTTP::Request;
use HTTP::Response;
use File::Temp;
use URI;

__PACKAGE__->mk_accessors(qw/http/);

Class::Struct::struct 'Catalyst::Engine::HTTP::Base::struct' => {
    request  => 'HTTP::Request',
    response => 'HTTP::Response',
    hostname => '$',
    address  => '$'
};

=head1 NAME

Catalyst::Engine::HTTP::Base - Base class for HTTP Engines

=head1 DESCRIPTION

This is a base class for HTTP Engines.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine>.

=over 4

=item $c->finalize_body

=cut

sub finalize_body {
    my $c = shift;
    $c->http->response->content( $c->response->body );
}

=item $c->finalize_headers

=cut

sub finalize_headers {
    my $c = shift;

    $c->http->response->code( $c->response->status );

    for my $name ( $c->response->headers->header_field_names ) {
        $c->http->response->push_header( $name => [ $c->response->header($name) ] );
    }
}

=item $c->prepare_body

=cut

sub prepare_body {
    my $c = shift;
    $c->request->body( $c->http->request->content );
}

=item $c->prepare_connection

=cut

sub prepare_connection {
    my $c = shift;
    $c->request->address( $c->http->address );
    $c->request->hostname( $c->http->hostname );
    $c->request->protocol( $c->http->request->protocol );
}

=item $c->prepare_headers

=cut

sub prepare_headers {
    my $c = shift;
    $c->request->method( $c->http->request->method );
    $c->request->headers( $c->http->request->headers );
}

=item $c->prepare_parameters

=cut

sub prepare_parameters {
    my $c = shift;

    my ( @params, @uploads );

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

                my $fh = File::Temp->new( UNLINK => 0 );
                
                unless ( $fh->write( $part->content ) ) {
                    Catalyst::Exception->throw( message => $! );
                }
                
                unless ( $fh->flush ) {
                    Catalyst::Exception->throw( message => $! );
                }

                my $upload = Catalyst::Request::Upload->new(
                    filename => $parameters{filename},
                    size     => ( $fh->stat )[7],
                    tempname => $fh->filename,
                    type     => $part->content_type
                );

                unless ( $fh->close ) {
                    Catalyst::Exception->throw( message => $! );
                }

                push( @uploads, $parameters{name}, $upload );
                push( @params,  $parameters{name}, $parameters{filename} );
            }
            else {
                push( @params, $parameters{name}, $part->content );
            }
        }
    }

    $c->request->param(@params);
    $c->request->upload(@uploads);
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
    $path =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
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
