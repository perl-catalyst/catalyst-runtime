package Catalyst::Test;

use strict;
use UNIVERSAL::require;
use IO::File;
use HTTP::Request;
use HTTP::Response;
use Socket;
use URI;

require Catalyst;

my $class;
$ENV{CATALYST_ENGINE} = 'CGI';
$ENV{CATALYST_TEST}   = 1;

=head1 NAME

Catalyst::Test - Test Catalyst applications

=head1 SYNOPSIS

    # Helper
    script/test.pl

    # Tests
    use Catalyst::Test 'TestApp';
    request('index.html');
    get('index.html');

    # Request
    perl -MCatalyst::Test=MyApp -e1 index.html

=head1 DESCRIPTION

Test Catalyst applications.

=head2 METHODS

=head3 get

Returns the content.

    my $content = get('foo/bar?test=1');

=head3 request

Returns a C<HTTP::Response> object.

    my $res =request('foo/bar?test=1');

=cut

{
    no warnings;
    CHECK {
        if ( ( caller(0) )[1] eq '-e' ) {
            print request( $ARGV[0] || 'http://localhost' )->content;
        }
    }
}

sub import {
    my $self = shift;
    if ( $class = shift ) {
        $class->require;
        unless ( $INC{'Test/Builder.pm'} ) {
            die qq/Couldn't load "$class", "$@"/ if $@;
        }
        my $caller = caller(0);
        no strict 'refs';
        *{"$caller\::request"} = \&request;
        *{"$caller\::get"} = sub { request(@_)->content };
    }
}

sub request {
    my $request = shift;
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
    $ENV{SCRIPT_NAME}       ||= $request->uri->path || '/';
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

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
