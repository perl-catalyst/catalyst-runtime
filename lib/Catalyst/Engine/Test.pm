package Catalyst::Engine::Test;

use strict;
use base 'Catalyst::Engine';

use Class::Struct ();
use HTTP::Headers::Util 'split_header_words';
use HTTP::Request;
use HTTP::Response;
use File::Temp;
use URI;

__PACKAGE__->mk_accessors(qw/http/);

Class::Struct::struct 'Catalyst::Engine::Test::HTTP' => {
    request  => 'HTTP::Request',
    response => 'HTTP::Response',
    hostname => '$',
    address  => '$'
};

=head1 NAME

Catalyst::Engine::Test - Catalyst Test Engine

=head1 SYNOPSIS

A script using the Catalyst::Engine::Test module might look like:

    #!/usr/bin/perl -w

    BEGIN { 
       $ENV{CATALYST_ENGINE} = 'Test';
    }

    use strict;
    use lib '/path/to/MyApp/lib';
    use MyApp;

    MyApp->run('/a/path');

=head1 DESCRIPTION

This is the Catalyst engine specialized for testing.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine>.

=over 4

=item $c->finalize_headers

=cut

sub finalize_headers {
    my $c = shift;

    $c->http->response->code( $c->response->status );

    for my $name ( $c->response->headers->header_field_names ) {
        $c->http->response->push_header( $name => [ $c->response->header($name) ] );
    }
}

=item $c->finalize_output

=cut

sub finalize_output {
    my $c = shift;
    $c->http->response->content( $c->response->output );
}

=item $c->prepare_connection

=cut

sub prepare_connection {
    my $c = shift;
    $c->req->hostname( $c->http->hostname );
    $c->req->address( $c->http->address );
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
                $fh->write( $part->content ) or die $!;
                $fh->flush or die $!;

                my $upload = Catalyst::Request::Upload->new(
                    filename => $parameters{filename},
                    size     => ( $fh->stat )[7],
                    tempname => $fh->filename,
                    type     => $part->content_type
                );
                
                $fh->close;

                push( @uploads, $parameters{name}, $upload );
                push( @params,  $parameters{name}, $parameters{filename} );
            }
            else {
                push( @params, $parameters{name}, $part->content );
            }
        }
    }
    
    $c->req->_assign_values( $c->req->parameters, \@params );
    $c->req->_assign_values( $c->req->uploads, \@uploads );
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

=item $c->run

=cut

sub run {
    my $class   = shift;
    my $request = shift || '/';

    unless ( ref $request ) {

        my $uri =
          ( $request =~ m/http/i )
          ? URI->new($request)
          : URI->new( 'http://localhost' . $request );

        $request = $uri->canonical;
    }

    unless ( ref $request eq 'HTTP::Request' ) {
        $request = HTTP::Request->new( 'GET', $request );
    }

    my $host = sprintf( '%s:%d', $request->uri->host, $request->uri->port );
    $request->header( 'Host' => $host );

    my $http = Catalyst::Engine::Test::HTTP->new(
        address  => '127.0.0.1',
        hostname => 'localhost',
        request  => $request,
        response => HTTP::Response->new
    );

    $http->response->date(time);

    $class->handler($http);

    return $http->response;
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
