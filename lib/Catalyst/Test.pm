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
    script/cgi-server.pl
    script/server.pl
    script/test.pl

    # Tests
    use Catalyst::Test 'TestApp';
    request('index.html');
    get('index.html');

    # Request
    perl -MCatalyst::Test=MyApp -e1 index.html

    # Server
    perl -MCatalyst::Test=MyApp -e1 3000

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
            if ( $ARGV[0] =~ /^\d+$/ ) { server( $ARGV[0] ) }
            else { print request( $ARGV[0] || 'http://localhost' )->content }
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

=head3 server

Starts a testserver.

    Catalyst::Test::server(3000);

=cut

sub server {
    my ( $port, $script ) = @_;

    # Listen
    my $tcp = getprotobyname('tcp');
    socket( HTTPDaemon, PF_INET, SOCK_STREAM, $tcp ) or die $!;
    setsockopt( HTTPDaemon, SOL_SOCKET, SO_REUSEADDR, pack( "l", 1 ) )
      or warn $!;
    bind( HTTPDaemon, sockaddr_in( $port, INADDR_ANY ) ) or die $!;
    listen( HTTPDaemon, SOMAXCONN ) or die $!;

    print "You can connect to your server at http://localhost:$port\n";

    # Process
    my %clean = %ENV;
    for ( ; accept( Remote, HTTPDaemon ) ; close Remote ) {
        *STDIN  = *Remote;
        *STDOUT = *Remote;
        my $remote_sockaddr = getpeername(STDIN);
        my ( undef, $iaddr ) = sockaddr_in($remote_sockaddr);
        my $peername = gethostbyaddr( $iaddr, AF_INET ) || "localhost";
        my $peeraddr = inet_ntoa($iaddr) || "127.0.0.1";
        my $local_sockaddr = getsockname(STDIN);
        my ( undef, $localiaddr ) = sockaddr_in($local_sockaddr);
        my $localname = gethostbyaddr( $localiaddr, AF_INET ) || 'localhost';
        my $localaddr = inet_ntoa($localiaddr) || '127.0.0.1';
        my $chunk;

        while ( sysread( STDIN, my $buff, 1 ) ) {
            last if $buff eq "\n";
            $chunk .= $buff;
        }
        my ( $method, $request_uri, $proto, undef ) = split /\s+/, $chunk;
        my ( $file, undef, $query_string ) =
          ( $request_uri =~ /([^?]*)(\?(.*))?/ );
        last if ( $method !~ /^(GET|POST|HEAD)$/ );
        %ENV = %clean;

        $chunk = '';
        while ( sysread( STDIN, my $buff, 1 ) ) {
            if ( $buff eq "\n" ) {
                $chunk =~ s/[\r\l\n\s]+$//;
                if ( $chunk =~ /^([\w\-]+): (.+)/i ) {
                    my $tag = uc($1);
                    $tag =~ s/^COOKIES$/COOKIE/;
                    my $val = $2;
                    $tag =~ s/-/_/g;
                    $tag = "HTTP_" . $tag
                      unless ( grep /^$tag$/, qw(CONTENT_LENGTH CONTENT_TYPE) );
                    if ( $ENV{$tag} ) { $ENV{$tag} .= "; $val" }
                    else { $ENV{$tag} = $val }
                }
                last if $chunk =~ /^$/;
                $chunk = '';
            }
            else { $chunk .= $buff }
        }
        $ENV{SERVER_PROTOCOL} = $proto;
        $ENV{SERVER_PORT}     = $port;
        $ENV{SERVER_NAME}     = $localname;
        $ENV{SERVER_URL}      = "http://$localname:$port/";
        $ENV{PATH_INFO}       = $file;
        $ENV{REQUEST_URI}     = $request_uri;
        $ENV{REQUEST_METHOD}  = $method;
        $ENV{REMOTE_ADDR}     = $peeraddr;
        $ENV{REMOTE_HOST}     = $peername;
        $ENV{QUERY_STRING}    = $query_string || '';
        $ENV{CONTENT_TYPE}    ||= 'multipart/form-data';
        $ENV{SERVER_SOFTWARE} ||= "Catalyst/$Catalyst::VERSION";
        $script ? print STDOUT `$script` : $class->run;
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
