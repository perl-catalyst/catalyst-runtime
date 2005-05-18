package Catalyst::Engine::CGI::Base;

use strict;
use base 'Catalyst::Engine';

use URI;
use URI::http;

=head1 NAME

Catalyst::Engine::CGI::Base - Base class for CGI Engines

=head1 DESCRIPTION

This is a base class for CGI engines.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine>.

=over 4

=item $c->finalize_body

Prints the response output to STDOUT.

=cut

sub finalize_body {
    my $c = shift;
    print $c->response->output;
}

=item $c->finalize_headers

=cut

sub finalize_headers {
    my $c = shift;

    $c->response->header( Status => $c->response->status );

    print $c->response->headers->as_string("\015\012");
    print "\015\012";
}

=item $c->prepare_body

=cut

sub prepare_body {
    my $c = shift;
    
    my $body = undef;
    
    while ( read( STDIN, my $buffer, 8192 ) ) {
        $body .= $buffer;
    }
    
    $c->request->body($body);
}

=item $c->prepare_connection

=cut

sub prepare_connection {
    my $c = shift;
    $c->request->address( $ENV{REMOTE_ADDR} );
    $c->request->hostname( $ENV{REMOTE_HOST} );
    $c->request->protocol( $ENV{SERVER_PROTOCOL} );
    $c->request->user( $ENV{REMOTE_USER} );

    if ( $ENV{HTTPS} || $ENV{SERVER_PORT} == 443 ) {
        $c->request->secure(1);
    }
}

=item $c->prepare_headers

=cut

sub prepare_headers {
    my $c = shift;

    while ( my ( $header, $value ) = each %ENV ) {

        next unless $header =~ /^(HTTP|CONTENT)/i;

        ( my $field = $header ) =~ s/^HTTPS?_//;

        $c->req->headers->header( $field => $value );
    }

    $c->req->method( $ENV{REQUEST_METHOD} || 'GET' );
}

=item $c->prepare_path

=cut

sub prepare_path {
    my $c = shift;

    my $base;
    {
        my $scheme = $c->request->secure ? 'https' : 'http';
        my $host   = $ENV{HTTP_HOST}   || $ENV{SERVER_NAME};
        my $port   = $ENV{SERVER_PORT} || 80;
        my $path   = $ENV{SCRIPT_NAME} || '/';

        unless ( $path =~ /\/$/ ) {
            $path .= '/';
        }

        $base = URI->new;
        $base->scheme($scheme);
        $base->host($host);
        $base->port($port);
        $base->path($path);

        $base = $base->canonical->as_string;
    }

    my $location = $ENV{SCRIPT_NAME} || '/';
    my $path = $ENV{PATH_INFO} || '/';
    $path =~ s/^($location)?\///;
    $path =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
    $path =~ s/^\///;

    $c->req->base($base);
    $c->req->path($path);
}

=item $c->run

=cut

sub run { shift->handler(@_) }

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
