package Catalyst::Engine::Apache::Base;

use strict;
use base qw[Catalyst::Engine Catalyst::Engine::Apache];

use File::Spec;
use URI;
use URI::http;

__PACKAGE__->mk_accessors(qw/apache/);

=head1 NAME

Catalyst::Engine::Apache::Base - Base class for Apache Engines

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is a base class for Apache Engines.

=head1 METHODS

=over 4

=item $c->apache

Returns an C<Apache::Request> object.

=back

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine>.

=over 4

=item $c->finalize_body

=cut

sub finalize_body {
    my $c = shift;
    $c->apache->print( $c->response->body );
}

=item $c->prepare_body

=cut

sub prepare_body {
    my $c = shift;

    my $length = $c->request->content_length;
    my ( $buffer, $content );

    while ($length) {

        $c->apache->read( $buffer, ( $length < 8192 ) ? $length : 8192 );

        $length  -= length($buffer);
        $content .= $buffer;
    }
    
    $c->request->body($content);
}

=item $c->prepare_connection

=cut

sub prepare_connection {
    my $c = shift;
    $c->request->address( $c->apache->connection->remote_ip );
    $c->request->hostname( $c->apache->connection->remote_host );
    $c->request->protocol( $c->apache->protocol );
    $c->request->user( $c->apache->user );

    if ( $ENV{HTTPS} && uc( $ENV{HTTPS} ) eq 'ON' ) {
        $c->request->secure(1);
    }

    if ( $c->apache->get_server_port == 443 ) {
        $c->request->secure(1);
    }
}

=item $c->prepare_headers

=cut

sub prepare_headers {
    my $c = shift;
    $c->request->method( $c->apache->method );
    $c->request->header( %{ $c->apache->headers_in } );
}

=item $c->prepare_path

=cut

# XXX needs fixing, only work with <Location> directive,
# not <Directory> directive
sub prepare_path {
    my $c = shift;

    {
        my $path = $c->apache->uri;

        if ( my $location = $c->apache->location ) {

            if ( index( $path, $location ) == 0 ) {
                $path = substr( $path, length($location) );
            }
        }

        $path =~ s/^\///;

        if ( $c->apache->filename && -f $c->apache->filename && -x _ ) {

            my $filename = ( File::Spec->splitpath( $c->apache->filename ) )[2];

            if ( index( $path, $filename ) == 0 ) {
                $path = substr( $path, length($filename) );
            }
        }

        $path =~ s/^\///;

        $c->request->path($path);
    }

    {
        my $scheme = $c->request->secure ? 'https' : 'http';
        my $host   = $c->apache->hostname;
        my $port   = $c->apache->get_server_port;
        my $path   = $c->apache->uri;

        if ( length( $c->request->path ) ) {
            $path =~ s/\/$//;
            $path = substr( $path, 0, length($path) - length($c->req->path) );
        }

        unless ( $path =~ /\/$/ ) {
            $path .= '/';
        }

        my $base = URI->new;
        $base->scheme($scheme);
        $base->host($host);
        $base->port($port);
        $base->path($path);

        $c->request->base( $base->canonical->as_string );
    }
}

=item $c->prepare_request($r)

=cut

sub prepare_request {
    my ( $c, $r ) = @_;
    $c->apache($r);
}

=item $c->run

=cut

sub run { shift->handler(@_) }

=back

=head1 SEE ALSO

L<Catalyst> L<Catalyst::Engine>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
