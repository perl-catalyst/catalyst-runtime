package Catalyst::Engine::CGI;

use strict;
use base 'Catalyst::Engine';

use CGI;
use URI;
use URI::http;

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
C<CGI> and C<CGI::Cookie> modules).  Normally Catalyst will select the
appropriate engine according to the environment that it detects, however you
can force Catalyst to use the CGI engine by specifying the following in your
application module:

    use Catalyst qw(-Engine=CGI);

The performance of this way of using Catalyst is not expected to be
useful in production applications, but it may be helpful for development.

=head1 METHODS

=over 4

=item $c->cgi

This config parameter contains the C<CGI> object.

=back

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

    # XXX this is undocumented in CGI.pm. If Content-Type is not
    # application/x-www-form-urlencoded or multipart/form-data
    # CGI.pm will read STDIN into a param, POSTDATA.

    $c->request->body( $c->cgi->param('POSTDATA') );
}

=item $c->prepare_connection

=cut

sub prepare_connection {
    my $c = shift;
    $c->req->hostname( $ENV{REMOTE_HOST} );
    $c->req->address( $ENV{REMOTE_ADDR} );
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

=item $c->prepare_parameters

=cut

sub prepare_parameters {
    my $c = shift;
    
    my ( @params );
    
    
    if ( $c->request->method eq 'POST' ) {

        for my $param ( $c->cgi->url_param ) {
            for my $value (  $c->cgi->url_param($param) ) {
                push ( @params, $param, $value );
            }
        }
    }

    for my $param ( $c->cgi->param ) { 
        for my $value (  $c->cgi->param($param) ) {
            push ( @params, $param, $value );
        }
    }
 
    $c->req->_assign_values( $c->req->parameters, \@params );
}

=item $c->prepare_path

=cut

sub prepare_path {
    my $c = shift;

    my $base;
    {
        my $scheme = $ENV{HTTPS} ? 'https' : 'http';
        my $host   = $ENV{HTTP_HOST}   || $ENV{SERVER_NAME};
        my $port   = $ENV{SERVER_PORT} || 80;
        my $path   = $ENV{SCRIPT_NAME} || '/';

        $base = URI->new;
        $base->scheme($scheme);
        $base->host($host);
        $base->port($port);
        $base->path($path);

        $base = $base->canonical->as_string;
    }

    my $path = $ENV{PATH_INFO} || '/';
    $path =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
    $path =~ s/^\///;

    $c->req->base($base);
    $c->req->path($path);
}

=item $c->prepare_request

=cut

sub prepare_request { 
    my ( $c, $cgi ) = @_;
    $c->cgi( $cgi || CGI->new );
    $c->cgi->_reset_globals;
}

=item $c->prepare_uploads

=cut

sub prepare_uploads {
    my $c = shift;

    my @uploads;
    
    for my $param ( $c->cgi->param ) {
    
        my @values = $c->cgi->param($param);

        next unless ref( $values[0] );

        for my $fh (@values) {

            next unless my $size = ( stat $fh )[7];

            my $info        = $c->cgi->uploadInfo($fh);
            my $tempname    = $c->cgi->tmpFileName($fh);
            my $type        = $info->{'Content-Type'};
            my $disposition = $info->{'Content-Disposition'};
            my $filename    = ( $disposition =~ / filename="([^;]*)"/ )[0];

            my $upload = Catalyst::Request::Upload->new(
                filename => $filename,
                size     => $size,
                tempname => $tempname,
                type     => $type
            );
            
            push( @uploads, $param, $upload );
        }
    }
    
    $c->req->_assign_values( $c->req->uploads, \@uploads );
}

=item $c->run

=cut

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
