package Catalyst::Engine::CGI;

use strict;
use base 'Catalyst::Engine';
use URI;

require CGI::Simple;
require CGI::Cookie;

$CGI::Simple::POST_MAX        = 1048576;
$CGI::Simple::DISABLE_UPLOADS = 0;

__PACKAGE__->mk_accessors('cgi');

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

This is the Catalyst engine specialized for the CGI environment (using the
C<CGI::Simple> and C<CGI::Cookie> modules).  Normally Catalyst will select the
appropriate engine according to the environment that it detects, however you
can force Catalyst to use the CGI engine by specifying the following in your
application module:

    use Catalyst qw(-Engine=CGI);

Catalyst::Engine::CGI generates a full set of HTTP headers, which means that
applications using the engine must be be configured as "Non-parsed Headers"
scripts (at least when running under Apache).  To configure this under Apache
name the starting with C<nph->.

The performance of this way of using Catalyst is not expected to be
useful in production applications, but it may be helpful for development.

=head1 METHODS

=over 4

=item $c->run

To be called from a CGI script to start the Catalyst application.

=item $c->cgi

This config parameter contains the C<CGI::Simple> object.

=back

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst>.

=over 4

=item $c->finalize_headers

=cut

sub finalize_headers {
    my $c = shift;
    my %headers = ( -nph => 1 );
    $headers{-status} = $c->response->status if $c->response->status;
    for my $name ( $c->response->headers->header_field_names ) {
        $headers{"-$name"} = $c->response->headers->header($name);
    }
    my @cookies;
    while ( my ( $name, $cookie ) = each %{ $c->response->cookies } ) {
        push @cookies, $c->cgi->cookie(
            -name    => $name,
            -value   => $cookie->{value},
            -expires => $cookie->{expires},
            -domain  => $cookie->{domain},
            -path    => $cookie->{path},
            -secure  => $cookie->{secure} || 0
        );
    }
    $headers{-cookie} = \@cookies if @cookies;
    print $c->cgi->header(%headers);
}

=item $c->finalize_output

Prints the response output to STDOUT.

=cut

sub finalize_output {
    my $c = shift;
    print $c->response->output;
}

=item $c->prepare_connection

=cut

sub prepare_connection {
    my $c = shift;
    $c->req->hostname( $c->cgi->remote_host );
    $c->req->address( $c->cgi->remote_addr );
}

=item $c->prepare_cookies

Sets up cookies.

=cut

sub prepare_cookies { shift->req->cookies( { CGI::Cookie->fetch } ) }

=item $c->prepare_headers

=cut

sub prepare_headers {
    my $c = shift;
    $c->req->method( $c->cgi->request_method );
    for my $header ( $c->cgi->http ) {
        ( my $field = $header ) =~ s/^HTTPS?_//;
        $c->req->headers->header( $field => $c->cgi->http($header) );
    }
    $c->req->headers->header( 'Content-Type'   => $c->cgi->content_type );
    $c->req->headers->header( 'Content-Length' => $c->cgi->content_length );
}

=item $c->prepare_parameters

=cut

sub prepare_parameters {
    my $c    = shift;
    my %vars = $c->cgi->Vars;
    while ( my ( $key, $value ) = each %vars ) {
        my @values = split "\0", $value;
        $vars{$key} = @values <= 1 ? $values[0] : \@values;
    }
    $c->req->parameters( {%vars} );
}

=item $c->prepare_path

=cut

sub prepare_path {
    my $c = shift;
    $c->req->path( $c->cgi->url( -absolute => 1, -path_info => 1 ) );
    my $loc = $c->cgi->url( -absolute => 1 );
    no warnings 'uninitialized';
    $c->req->{path} =~ s/^($loc)?\///;
    $c->req->{path} .= '/' if $c->req->path eq $loc;
    my $base = $c->cgi->url;
    if ( $ENV{CATALYST_TEST} ) {
        my $script = $c->cgi->script_name;
        $base =~ s/$script$//i;
    }
    $base = URI->new($base);
    $base->path('/') if ( $ENV{CATALYST_TEST} || !$base->path );
    $c->req->base( $base->as_string );
}

=item $c->prepare_request

=cut

sub prepare_request { shift->cgi( CGI::Simple->new ) }

=item $c->prepare_uploads

=cut

sub prepare_uploads {
    my $c = shift;
    for my $name ( $c->cgi->upload ) {
        $c->req->uploads->{$name} = {
            fh   => $c->cgi->upload($name),
            size => $c->cgi->upload_info( $name, 'size' ),
            type => $c->cgi->upload_info( $name, 'mime' )
        };
    }
}

sub run { shift->handler }

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
