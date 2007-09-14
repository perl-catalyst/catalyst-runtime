package Catalyst::Engine::CGI;

use strict;
use base 'Catalyst::Engine';
use NEXT;

__PACKAGE__->mk_accessors('env');

=head1 NAME

Catalyst::Engine::CGI - The CGI Engine

=head1 SYNOPSIS

A script using the Catalyst::Engine::CGI module might look like:

    #!/usr/bin/perl -w

    use strict;
    use lib '/path/to/MyApp/lib';
    use MyApp;

    MyApp->run;

The application module (C<MyApp>) would use C<Catalyst>, which loads the
appropriate engine module.

=head1 DESCRIPTION

This is the Catalyst engine specialized for the CGI environment.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine>.

=head2 $self->finalize_headers($c)

=cut

sub finalize_headers {
    my ( $self, $c ) = @_;

    $c->response->header( Status => $c->response->status );

    $self->{_header_buf} 
        = $c->response->headers->as_string("\015\012") . "\015\012";
}

=head2 $self->prepare_connection($c)

=cut

sub prepare_connection {
    my ( $self, $c ) = @_;
    local (*ENV) = $self->env || \%ENV;

    $c->request->address( $ENV{REMOTE_ADDR} );

  PROXY_CHECK:
    {
        unless ( $c->config->{using_frontend_proxy} ) {
            last PROXY_CHECK if $ENV{REMOTE_ADDR} ne '127.0.0.1';
            last PROXY_CHECK if $c->config->{ignore_frontend_proxy};
        }
        last PROXY_CHECK unless $ENV{HTTP_X_FORWARDED_FOR};

        # If we are running as a backend server, the user will always appear
        # as 127.0.0.1. Select the most recent upstream IP (last in the list)
        my ($ip) = $ENV{HTTP_X_FORWARDED_FOR} =~ /([^,\s]+)$/;
        $c->request->address($ip);
    }

    $c->request->hostname( $ENV{REMOTE_HOST} );
    $c->request->protocol( $ENV{SERVER_PROTOCOL} );
    $c->request->user( $ENV{REMOTE_USER} );
    $c->request->method( $ENV{REQUEST_METHOD} );

    if ( $ENV{HTTPS} && uc( $ENV{HTTPS} ) eq 'ON' ) {
        $c->request->secure(1);
    }

    if ( $ENV{SERVER_PORT} == 443 ) {
        $c->request->secure(1);
    }
}

=head2 $self->prepare_headers($c)

=cut

sub prepare_headers {
    my ( $self, $c ) = @_;
    local (*ENV) = $self->env || \%ENV;

    # Read headers from %ENV
    foreach my $header ( keys %ENV ) {
        next unless $header =~ /^(?:HTTP|CONTENT|COOKIE)/i;
        ( my $field = $header ) =~ s/^HTTPS?_//;
        $c->req->headers->header( $field => $ENV{$header} );
    }
}

=head2 $self->prepare_path($c)

=cut

sub prepare_path {
    my ( $self, $c ) = @_;
    local (*ENV) = $self->env || \%ENV;

    my $scheme = $c->request->secure ? 'https' : 'http';
    my $host      = $ENV{HTTP_HOST}   || $ENV{SERVER_NAME};
    my $port      = $ENV{SERVER_PORT} || 80;
    my $base_path;
    if ( exists $ENV{REDIRECT_URL} ) {
        $base_path = $ENV{REDIRECT_URL};
        $base_path =~ s/$ENV{PATH_INFO}$//;
    }
    else {
        $base_path = $ENV{SCRIPT_NAME} || '/';
    }

    # If we are running as a backend proxy, get the true hostname
  PROXY_CHECK:
    {
        unless ( $c->config->{using_frontend_proxy} ) {
            last PROXY_CHECK if $host !~ /localhost|127.0.0.1/;
            last PROXY_CHECK if $c->config->{ignore_frontend_proxy};
        }
        last PROXY_CHECK unless $ENV{HTTP_X_FORWARDED_HOST};

        $host = $ENV{HTTP_X_FORWARDED_HOST};

        # backend could be on any port, so
        # assume frontend is on the default port
        $port = $c->request->secure ? 443 : 80;
    }

    # set the request URI
    my $path = $base_path . ( $ENV{PATH_INFO} || '' );
    $path =~ s{^/+}{};
    
    # Using URI directly is way too slow, so we construct the URLs manually
    my $uri_class = "URI::$scheme";
    
    # HTTP_HOST will include the port even if it's 80/443
    $host =~ s/:(?:80|443)$//;
    
    if ( $port !~ /^(?:80|443)$/ && $host !~ /:/ ) {
        $host .= ":$port";
    }
    
    # Escape the path
    $path =~ s/([^$URI::uric])/$URI::Escape::escapes{$1}/go;
    $path =~ s/\?/%3F/g; # STUPID STUPID SPECIAL CASE
    
    my $query = $ENV{QUERY_STRING} ? '?' . $ENV{QUERY_STRING} : '';
    my $uri   = $scheme . '://' . $host . '/' . $path . $query;

    $c->request->uri( bless \$uri, $uri_class );

    # set the base URI
    # base must end in a slash
    $base_path .= '/' unless $base_path =~ m{/$};
    
    my $base_uri = $scheme . '://' . $host . $base_path;

    $c->request->base( bless \$base_uri, $uri_class );
}

=head2 $self->prepare_query_parameters($c)

=cut

sub prepare_query_parameters {
    my ( $self, $c ) = @_;
    local (*ENV) = $self->env || \%ENV;

    if ( $ENV{QUERY_STRING} ) {
        $self->SUPER::prepare_query_parameters( $c, $ENV{QUERY_STRING} );
    }
}

=head2 $self->prepare_request($c, (env => \%env))

=cut

sub prepare_request {
    my ( $self, $c, %args ) = @_;

    if ( $args{env} ) {
        $self->env( $args{env} );
    }
}

=head2 $self->prepare_write($c)

Enable autoflush on the output handle for CGI-based engines.

=cut

sub prepare_write {
    my ( $self, $c ) = @_;

    # Set the output handle to autoflush
    *STDOUT->autoflush(1);

    $self->NEXT::prepare_write($c);
}

=head2 $self->write($c, $buffer)

Writes the buffer to the client.

=cut

sub write {
    my ( $self, $c, $buffer ) = @_;

    # Prepend the headers if they have not yet been sent
    if ( my $headers = delete $self->{_header_buf} ) {
        $buffer = $headers . $buffer;
    }
    
    return $self->NEXT::write( $c, $buffer );
}

=head2 $self->read_chunk($c, $buffer, $length)

=cut

sub read_chunk { shift; shift; *STDIN->sysread(@_); }

=head2 $self->run

=cut

sub run { shift; shift->handle_request(@_) }

=head1 SEE ALSO

L<Catalyst> L<Catalyst::Engine>.

=head1 AUTHORS

Sebastian Riedel, <sri@cpan.org>

Christian Hansen, <ch@ngmedia.com>

Andy Grundman, <andy@hybridized.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
