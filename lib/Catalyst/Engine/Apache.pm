package Catalyst::Engine::Apache;

use strict;
use mod_perl;
use constant MP2 => $mod_perl::VERSION >= 1.99;
use base 'Catalyst::Engine';
use URI;

# mod_perl
if (MP2) {
    require Apache2;
    require Apache::RequestIO;
    require Apache::RequestRec;
    require Apache::SubRequest;
    require Apache::RequestUtil;
    require APR::URI;
    require Apache::URI;
}
else { require Apache }

# libapreq
require Apache::Request;
require Apache::Cookie;
require Apache::Upload if MP2;

__PACKAGE__->mk_accessors(qw/apache_request original_request/);

=head1 NAME

Catalyst::Engine::Apache - Catalyst Apache Engine

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

The Apache Engine.

=head2 METHODS

=head3 apache_request

Returns an C<Apache::Request> object.

=head3 original_request

Returns the original Apache request object.

=head2 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine>.

=head3 finalize_headers

=cut

sub finalize_headers {
    my $c = shift;
    for my $name ( $c->response->headers->header_field_names ) {
        next if $name =~ /Content-Type/i;
        $c->original_request->headers_out->set(
            $name => $c->response->headers->header($name) );
    }
    while ( my ( $name, $cookie ) = each %{ $c->response->cookies } ) {
        my %cookie = ( -name => $name, -value => $cookie->{value} );
        $cookie->{-expires} = $cookie->{expires} if $cookie->{expires};
        $cookie->{-domain}  = $cookie->{domain}  if $cookie->{domain};
        $cookie->{-path}    = $cookie->{path}    if $cookie->{path};
        $cookie->{-secure}  = $cookie->{secure}  if $cookie->{secure};
        my $cookie = Apache::Cookie->new( $c->original_request, %cookie );
        MP2
          ? $c->apache_request->err_headers_out->add(
            'Set-Cookie' => $cookie->as_string )
          : $cookie->bake;
    }
    $c->original_request->status( $c->response->status );
    $c->original_request->content_type( $c->response->headers->content_type
          || 'text/plain' );
    MP2 || $c->apache_request->send_http_header;
    return 0;
}

=head3 finalize_output

=cut

sub finalize_output {
    my $c = shift;
    $c->original_request->print( $c->response->{output} );
}

=head3 prepare_cookies

=cut

sub prepare_cookies {
    my $c = shift;
    MP2
      ? $c->req->cookies( { Apache::Cookie->fetch } )
      : $c->req->cookies(
        { Apache::Cookie->new( $c->apache_request )->fetch } );
}

=head3 prepare_headers

=cut

sub prepare_headers {
    my $c = shift;
    $c->req->method( $c->apache_request->method );
    $c->req->headers->header( %{ $c->apache_request->headers_in } );
}

=head3 prepare_parameters

=cut

sub prepare_parameters {
    my $c = shift;
    my %args;
    foreach my $key ( $c->apache_request->param ) {
        my @values = $c->apache_request->param($key);
        $args{$key} = @values == 1 ? $values[0] : \@values;
    }
    $c->req->parameters( \%args );
}

=head3 prepare_path

=cut

sub prepare_path {
    my $c = shift;
    $c->req->path( $c->apache_request->uri );
    my $loc = $c->apache_request->location;
    no warnings 'uninitialized';
    $c->req->{path} =~ s/^($loc)?\///;
    my $base = URI->new;
    $base->scheme( $c->apache_request->protocol =~ /HTTPS/ ? 'https' : 'http' );
    $base->host( $c->apache_request->hostname );
    $base->port( $c->apache_request->get_server_port );
    $base->path( $c->apache_request->location );
    $c->req->base( $base->as_string );
    $c->req->server_base( $base->scheme . '://' . $base->authority . '/' );
}

=head3 prepare_request

=cut

sub prepare_request {
    my ( $c, $r ) = @_;
    $c->apache_request( Apache::Request->new($r) );
    $c->original_request($r);
}

=head3 prepare_uploads

=cut

sub prepare_uploads {
    my $c = shift;
    for my $upload ( $c->apache_request->upload ) {
        $upload = $c->apache_request->upload($upload) if MP2;
        $c->req->uploads->{ $upload->filename } = {
            fh   => $upload->fh,
            size => $upload->size,
            type => $upload->type
        };
    }
}

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
