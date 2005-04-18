package Catalyst::Engine::Apache;

use strict;
use base 'Catalyst::Engine';

use URI;
use URI::http;

__PACKAGE__->mk_accessors(qw/apache/);

=head1 NAME

Catalyst::Engine::Apache - Catalyst Apache Engine

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is a base class engine specialized for Apache (i.e. for mod_perl).

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
    $c->request->hostname( $c->apache->connection->remote_host );
    $c->request->address( $c->apache->connection->remote_ip );
}

=item $c->prepare_headers

=cut

sub prepare_headers {
    my $c = shift;
    $c->request->method( $c->apache->method );
    $c->request->header( %{ $c->apache->headers_in } );
}

=item $c->prepare_parameters

=cut

sub prepare_parameters {
    my $c = shift;

    foreach my $key ( $c->apache->param ) {
        my @values = $c->apache->param($key);
        $c->req->parameters->{$key} = ( @values == 1 ) ? $values[0] : \@values;
    }
}

=item $c->prepare_path

=cut

# XXX needs fixing, only work with <Location> directive,
# not <Directory> directive
sub prepare_path {
    my $c = shift;
    $c->request->path( $c->apache->uri );
    my $loc = $c->apache->location;
    no warnings 'uninitialized';
    $c->req->{path} =~ s/^($loc)?\///;
    my $base = URI->new;
    $base->scheme( $ENV{HTTPS} ? 'https' : 'http' );
    $base->host( $c->apache->hostname );
    $base->port( $c->apache->get_server_port );
    my $path = $c->apache->location;
    $base->path( $path =~ /\/$/ ? $path : "$path/" );
    $c->request->base( $base->as_string );
}

=item $c->run

=cut

sub run { }

=back

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
