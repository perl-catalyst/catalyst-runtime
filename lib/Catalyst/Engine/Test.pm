package Catalyst::Engine::Test;

use strict;
use base 'Catalyst::Engine::CGI::NPH';

use HTTP::Request;
use HTTP::Response;
use IO::File;
use URI;

=head1 NAME

Catalyst::Engine::Test - Catalyst Test Engine

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is the Catalyst engine specialized for testing.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::CGI::NPH>.

=over 4

=item $c->run

=cut

sub run {
    my $class   = shift;
    my $request = shift || '/';

    unless ( ref $request ) {
        $request = URI->new( $request, 'http' );
    }
    unless ( ref $request eq 'HTTP::Request' ) {
        $request = HTTP::Request->new( 'GET', $request );
    }

    local ( *STDIN, *STDOUT );

    my %clean  = %ENV;
    my $output = '';
    $ENV{CONTENT_TYPE}   ||= $request->header('Content-Type')   || '';
    $ENV{CONTENT_LENGTH} ||= $request->header('Content-Length') || '';
    $ENV{GATEWAY_INTERFACE} ||= 'CGI/1.1';
    $ENV{HTTP_USER_AGENT}   ||= 'Catalyst';
    $ENV{HTTP_HOST}         ||= $request->uri->host || 'localhost';
    $ENV{QUERY_STRING}      ||= $request->uri->query || '';
    $ENV{REQUEST_METHOD}    ||= $request->method;
    $ENV{PATH_INFO}         ||= $request->uri->path || '/';
    $ENV{SCRIPT_NAME}       ||= '/';
    $ENV{SERVER_NAME}       ||= $request->uri->host || 'localhost';
    $ENV{SERVER_PORT}       ||= $request->uri->port;
    $ENV{SERVER_PROTOCOL}   ||= 'HTTP/1.1';

    for my $field ( $request->header_field_names ) {
        if ( $field =~ /^Content-(Length|Type)$/ ) {
            next;
        }
        $field =~ s/-/_/g;
        $ENV{ 'HTTP_' . uc($field) } = $request->header($field);
    }

    if ( $request->content_length ) {
        my $body = IO::File->new_tmpfile;
        $body->print( $request->content ) or die $!;
        $body->seek( 0, SEEK_SET ) or die $!;
        open( STDIN, "<&=", $body->fileno )
          or die("Failed to dup \$body: $!");
    }

    open( STDOUT, '>', \$output );
    $class->handler;
    %ENV = %clean;
    return HTTP::Response->parse($output);
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
