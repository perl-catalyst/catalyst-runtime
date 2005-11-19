package Catalyst::Engine::HTTP;

use strict;
use base 'Catalyst::Engine::CGI';
use Errno 'EWOULDBLOCK';
use HTTP::Status;
use NEXT;
use Socket;
use IO::Socket::INET ();
use IO::Select       ();

# For PAR
require Catalyst::Engine::HTTP::Restarter;
require Catalyst::Engine::HTTP::Restarter::Watcher;

=head1 NAME

Catalyst::Engine::HTTP - Catalyst HTTP Engine

=head1 SYNOPSIS

A script using the Catalyst::Engine::HTTP module might look like:

    #!/usr/bin/perl -w

    BEGIN {  $ENV{CATALYST_ENGINE} = 'HTTP' }

    use strict;
    use lib '/path/to/MyApp/lib';
    use MyApp;

    MyApp->run;

=head1 DESCRIPTION

This is the Catalyst engine specialized for development and testing.

=head1 METHODS

=head2 $self->finalize_headers($c)

=cut

sub finalize_headers {
    my ( $self, $c ) = @_;
    my $protocol = $c->request->protocol;
    my $status   = $c->response->status;
    my $message  = status_message($status);
    print "$protocol $status $message\015\012";
    $c->response->headers->date(time);
    $c->response->headers->header(
        Connection => $self->_keep_alive ? 'keep-alive' : 'close' );
    $self->NEXT::finalize_headers($c);
}

=head2 $self->finalize_read($c)

=cut

sub finalize_read {
    my ( $self, $c ) = @_;

    # Never ever remove this, it would result in random length output
    # streams if STDIN eq STDOUT (like in the HTTP engine)
    *STDIN->blocking(1);

    return $self->NEXT::finalize_read($c);
}

=head2 $self->prepare_read($c)

=cut

sub prepare_read {
    my ( $self, $c ) = @_;

    # Set the input handle to non-blocking
    *STDIN->blocking(0);

    return $self->NEXT::prepare_read($c);
}

=head2 $self->read_chunk($c, $buffer, $length)

=cut

sub read_chunk {
    my $self = shift;
    my $c    = shift;

    # support for non-blocking IO
    my $rin = '';
    vec( $rin, *STDIN->fileno, 1 ) = 1;

  READ:
    {
        select( $rin, undef, undef, undef );
        my $rc = *STDIN->sysread(@_);
        if ( defined $rc ) {
            return $rc;
        }
        else {
            next READ if $! == EWOULDBLOCK;
            return;
        }
    }
}

=head2 run

=cut

# A very very simple HTTP server that initializes a CGI environment
sub run {
    my ( $self, $class, $port, $host, $options ) = @_;

    $options ||= {};

    my $restart = 0;
    local $SIG{CHLD} = 'IGNORE';

    my $allowed = $options->{allowed} || { '127.0.0.1' => '255.255.255.255' };
    my $addr = $host ? inet_aton($host) : INADDR_ANY;
    if ( $addr eq INADDR_ANY ) {
        require Sys::Hostname;
        $host = lc Sys::Hostname::hostname();
    }
    else {
        $host = gethostbyaddr( $addr, AF_INET ) || inet_ntoa($addr);
    }

    # Handle requests

    # Setup socket
    my $daemon = IO::Socket::INET->new(
        Listen    => SOMAXCONN,
        LocalAddr => inet_ntoa($addr),
        LocalPort => $port,
        Proto     => 'tcp',
        ReuseAddr => 1,
        Type      => SOCK_STREAM,
      )
      or die "Couldn't create daemon: $!";

    my $url = "http://$host";
    $url .= ":$port" unless $port == 80;

    print "You can connect to your server at $url\n";

    $self->_keep_alive( $options->{keepalive} || 0 );

    my $parent = $$;
    my $pid    = undef;
    while ( accept( Remote, $daemon ) )
    {    # TODO: get while ( my $remote = $daemon->accept ) to work

        select Remote;

        # Request data

        Remote->blocking(1);

        next
          unless my ( $method, $uri, $protocol ) =
          $self->_parse_request_line( \*Remote );

        unless ( uc($method) eq 'RESTART' ) {

            # Fork
            if ( $options->{fork} ) { next if $pid = fork }

            $self->_handler( $class, $port, $method, $uri, $protocol );

            $daemon->close if defined $pid;

        }
        else {
            my $sockdata = $self->_socket_data( \*Remote );
            my $ipaddr   = _inet_addr( $sockdata->{peeraddr} );
            my $ready    = 0;
            while ( my ( $ip, $mask ) = each %$allowed and not $ready ) {
                $ready = ( $ipaddr & _inet_addr($mask) ) == _inet_addr($ip);
            }
            if ($ready) {
                $restart = 1;
                last;
            }
        }

        exit if defined $pid;
    }
    continue {
        close Remote;
    }
    $daemon->close;

    if ($restart) {
        $SIG{CHLD} = 'DEFAULT';
        wait;
        exec $^X . ' "' . $0 . '" ' . join( ' ', @{ $options->{argv} } );
    }

    exit;
}

sub _handler {
    my ( $self, $class, $port, $method, $uri, $protocol ) = @_;

    # Ignore broken pipes as an HTTP server should
    local $SIG{PIPE} = sub { close Remote };

    local *STDIN  = \*Remote;
    local *STDOUT = \*Remote;

    # We better be careful and just use 1.0
    $protocol = '1.0';

    my $sockdata    = $self->_socket_data( \*Remote );
    my %copy_of_env = %ENV;

    my $sel = IO::Select->new;
    $sel->add( \*STDIN );

    while (1) {
        my ( $path, $query_string ) = split /\?/, $uri, 2;

        # Initialize CGI environment
        local %ENV = (
            PATH_INFO    => $path         || '',
            QUERY_STRING => $query_string || '',
            REMOTE_ADDR     => $sockdata->{peeraddr},
            REMOTE_HOST     => $sockdata->{peername},
            REQUEST_METHOD  => $method || '',
            SERVER_NAME     => $sockdata->{localname},
            SERVER_PORT     => $port,
            SERVER_PROTOCOL => "HTTP/$protocol",
            %copy_of_env,
        );

        # Parse headers
        if ( $protocol >= 1 ) {
            while (1) {
                my $line = $self->_get_line( \*STDIN );
                last if $line eq '';
                next
                  unless my ( $name, $value ) =
                  $line =~ m/\A(\w(?:-?\w+)*):\s(.+)\z/;

                $name = uc $name;
                $name = 'COOKIE' if $name eq 'COOKIES';
                $name =~ tr/-/_/;
                $name = 'HTTP_' . $name
                  unless $name =~ m/\A(?:CONTENT_(?:LENGTH|TYPE)|COOKIE)\z/;
                if ( exists $ENV{$name} ) {
                    $ENV{$name} .= "; $value";
                }
                else {
                    $ENV{$name} = $value;
                }
            }
        }

        # Pass flow control to Catalyst
        $class->handle_request;

        my $connection = lc $ENV{HTTP_CONNECTION};
        last
          unless $self->_keep_alive()
          && index( $connection, 'keep-alive' ) > -1
          && index( $connection, 'te' ) == -1          # opera stuff
          && $sel->can_read(5);

        last
          unless ( $method, $uri, $protocol ) =
          $self->_parse_request_line( \*STDIN );
    }

    close Remote;
}

sub _keep_alive {
    my ( $self, $keepalive ) = @_;

    my $r = $self->{_keepalive} || 0;
    $self->{_keepalive} = $keepalive if defined $keepalive;

    return $r;

}

sub _parse_request_line {
    my ( $self, $handle ) = @_;

    # Parse request line
    my $line = $self->_get_line($handle);
    return ()
      unless my ( $method, $uri, $protocol ) =
      $line =~ m/\A(\w+)\s+(\S+)(?:\s+HTTP\/(\d+(?:\.\d+)?))?\z/;
    return ( $method, $uri, $protocol );
}

sub _socket_data {
    my ( $self, $handle ) = @_;

    my $remote_sockaddr = getpeername($handle);
    my ( undef, $iaddr ) = sockaddr_in($remote_sockaddr);
    my $local_sockaddr = getsockname($handle);
    my ( undef, $localiaddr ) = sockaddr_in($local_sockaddr);

    my $data = {
        peername => gethostbyaddr( $iaddr, AF_INET ) || "localhost",
        peeraddr => inet_ntoa($iaddr) || "127.0.0.1",
        localname => gethostbyaddr( $localiaddr, AF_INET ) || "localhost",
        localaddr => inet_ntoa($localiaddr) || "127.0.0.1",
    };

    return $data;
}

sub _get_line {
    my ( $self, $handle ) = @_;

    my $line = '';

    while ( sysread( $handle, my $byte, 1 ) ) {
        last if $byte eq "\012";    # eol
        $line .= $byte;
    }

    1 while $line =~ s/\s\z//;

    return $line;
}

sub _inet_addr { unpack "N*", inet_aton( $_[0] ) }

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine>.

=head1 AUTHORS

Sebastian Riedel, <sri@cpan.org>

Dan Kubb, <dan.kubb-cpan@onautopilot.com>

Sascha Kiefer, <esskar@cpan.org>

=head1 THANKS

Many parts are ripped out of C<HTTP::Server::Simple> by Jesse Vincent.

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
