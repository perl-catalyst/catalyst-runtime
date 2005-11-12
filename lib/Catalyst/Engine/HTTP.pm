package Catalyst::Engine::HTTP;

use strict;
use base 'Catalyst::Engine::CGI';
use Errno 'EWOULDBLOCK';
use HTTP::Status;
use NEXT;
use Socket;

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

=over 4

=item $self->finalize_headers($c)

=cut

sub finalize_headers {
    my ( $self, $c ) = @_;
    my $protocol = $c->request->protocol;
    my $status   = $c->response->status;
    my $message  = status_message($status);
    print "$protocol $status $message\015\012";
    $c->response->headers->date(time);
    $self->NEXT::finalize_headers($c);
}

=item $self->finalize_read($c)

=cut

sub finalize_read {
    my ( $self, $c ) = @_;

    # Never ever remove this, it would result in random length output
    # streams if STDIN eq STDOUT (like in the HTTP engine)
    *STDIN->blocking(1);

    return $self->NEXT::finalize_read($c);
}

=item $self->prepare_read($c)

=cut

sub prepare_read {
    my ( $self, $c ) = @_;

    # Set the input handle to non-blocking
    *STDIN->blocking(0);

    return $self->NEXT::prepare_read($c);
}

=item $self->read_chunk($c, $buffer, $length)

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

=item run

=cut

# A very very simple HTTP server that initializes a CGI environment
sub run {
    my ( $self, $class, $port, $host, $options ) = @_;

    $options ||= {};

    my $restart = 0;
    local $SIG{CHLD} = 'IGNORE';

    my $allowed = $options->{allowed} || { '127.0.0.1' => '255.255.255.255' };

    # Handle requests

    # Setup socket
    $host = $host ? inet_aton($host) : INADDR_ANY;
    socket( HTTPDaemon, PF_INET, SOCK_STREAM, getprotobyname('tcp') )
      || die "Couldn't assign TCP socket: $!";
    setsockopt( HTTPDaemon, SOL_SOCKET, SO_REUSEADDR, pack( "l", 1 ) )
      || die "Couldn't set TCP socket options: $!";
    bind( HTTPDaemon, sockaddr_in( $port, $host ) )
      || die "Couldn't bind socket to $port on $host: $!";
    listen( HTTPDaemon, SOMAXCONN )
      || die "Couldn't listen to socket on $port on $host: $!";
    my $url = 'http://';
    if ( $host eq INADDR_ANY ) {
        require Sys::Hostname;
        $url .= lc Sys::Hostname::hostname();
    }
    else {
        $url .= gethostbyaddr( $host, AF_INET ) || inet_ntoa($host);
    }
    $url .= ":$port";
    print "You can connect to your server at $url\n";

    my $parent = $$;
    my $pid    = undef;
    while ( accept( Remote, HTTPDaemon ) ) {

        select Remote;

        # Request data
        my $remote_sockaddr = getpeername( \*Remote );
        my ( undef, $iaddr ) = sockaddr_in($remote_sockaddr);
        my $peername = gethostbyaddr( $iaddr, AF_INET ) || "localhost";
        my $peeraddr = inet_ntoa($iaddr) || "127.0.0.1";
        my $local_sockaddr = getsockname( \*Remote );
        my ( undef, $localiaddr ) = sockaddr_in($local_sockaddr);
        my $localname = gethostbyaddr( $localiaddr, AF_INET )
          || "localhost";
        my $localaddr = inet_ntoa($localiaddr) || "127.0.0.1";

        Remote->blocking(1);

        # Parse request line
        my $line = $self->_get_line( \*Remote );
        next
          unless my ( $method, $uri, $protocol ) =
          $line =~ m/\A(\w+)\s+(\S+)(?:\s+HTTP\/(\d+(?:\.\d+)?))?\z/;

        unless ( uc($method) eq 'RESTART' ) {

            # Fork
            if ( $options->{fork} ) { next if $pid = fork }

            close HTTPDaemon if defined $pid;

            # Ignore broken pipes as an HTTP server should
            local $SIG{PIPE} = sub { close Remote };

            local *STDIN  = \*Remote;
            local *STDOUT = \*Remote;

            # We better be careful and just use 1.0
            $protocol = '1.0';

            my ( $path, $query_string ) = split /\?/, $uri, 2;

            # Initialize CGI environment
            local %ENV = (
                PATH_INFO      => $path         || '',
                QUERY_STRING   => $query_string || '',
                REMOTE_ADDR    => $peeraddr,
                REMOTE_HOST    => $peername,
                REQUEST_METHOD => $method       || '',
                SERVER_NAME    => $localname,
                SERVER_PORT    => $port,
                SERVER_PROTOCOL => "HTTP/$protocol",
                %ENV,
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
        }
        else {
            my $ipaddr = _inet_addr($peeraddr);
            my $ready  = 0;
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
    close HTTPDaemon;

    if ($restart) {
        $SIG{CHLD} = 'DEFAULT';
        wait;
        exec $^X . ' "' . $0 . '" ' . join( ' ', @{ $options->{argv} } );
    }

    exit;
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

=back

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine>.

=head1 AUTHORS

Sebastian Riedel, <sri@cpan.org>

Dan Kubb, <dan.kubb-cpan@onautopilot.com>

=head1 THANKS

Many parts are ripped out of C<HTTP::Server::Simple> by Jesse Vincent.

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
