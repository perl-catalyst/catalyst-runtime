package Catalyst::Engine::Apache;

use strict;
use mod_perl;
use constant MP2 => $mod_perl::VERSION >= 1.99;
use base 'Catalyst::Engine';
use URI;

__PACKAGE__->mk_accessors(qw/apache/);

=head1 NAME

Catalyst::Engine::Apache - Catalyst Apache Engine

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is the Catalyst engine specialized for Apache (i.e. for mod_perl).

=head1 METHODS

=over 4

=item $c->apache

Returns an C<Apache::Request> object.

=back

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine>.

=over 4

=item $c->finalize_headers

=cut

sub finalize_headers {
    my $c = shift;

    for my $name ( $c->response->headers->header_field_names ) {
        next if $name =~ /Content-Type/i;
        my @values = $c->response->header($name);
        $c->apache->headers_out->add( $name => $_ ) for @values;
    }

    if ( $c->response->header('Set-Cookie') && $c->response->status >= 300 ) {
        my @values = $c->response->header('Set-Cookie');
        $c->apache->err_headers_out->add( 'Set-Cookie' => $_ ) for @values;
    }

    $c->apache->status( $c->response->status );
    $c->apache->content_type( $c->response->header('Content-Type') );

    unless ( MP2 ) {
        $c->apache->send_http_header;
    }

    return 0;
}

=item $c->finalize_output

=cut

sub finalize_output {
    my $c = shift;
    $c->apache->print( $c->response->{output} );
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
    my %args;
    foreach my $key ( $c->apache->param ) {
        my @values = $c->apache->param($key);
        $args{$key} = @values == 1 ? $values[0] : \@values;
    }
    $c->request->parameters( \%args );
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

=item $c->prepare_request($r)

=cut

sub prepare_request {
    my ( $c, $r ) = @_;
    $c->apache( Apache::Request->new($r) );
}

=item $c->prepare_uploads

=cut

sub prepare_uploads {
    my $c = shift;
    for my $upload ( $c->apache->upload ) {
        $upload = $c->apache->upload($upload) if MP2;
        $c->request->uploads->{ $upload->filename } = {
            fh   => $upload->fh,
            size => $upload->size,
            type => $upload->type
        };
    }
}

=item $c->run

=cut

sub run { }

=back

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
