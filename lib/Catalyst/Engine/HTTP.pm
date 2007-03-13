package Catalyst::Engine::HTTP;

use strict;
use base 'Catalyst::Engine::CGI';
use Data::Dump qw(dump);
use Errno 'EWOULDBLOCK';
use HTTP::Date ();
use HTTP::Headers;
use HTTP::Status;
use NEXT;
use Socket;
use IO::Socket::INET ();
use IO::Select       ();

# For PAR
require Catalyst::Engine::HTTP::Restarter;
require Catalyst::Engine::HTTP::Restarter::Watcher;

sub CHUNKSIZE () { 64 * 1024 }

sub DEBUG () { $ENV{CATALYST_HTTP_DEBUG} || 0 }

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
    
    my @headers;
    push @headers, "$protocol $status $message";
    
    $c->response->headers->header( Date => HTTP::Date::time2str(time) );
    $c->response->headers->header( Status => $status );
    
    # Should we keep the connection open?
    my $connection = $c->request->header('Connection');
    if (   $self->{options}->{keepalive} 
        && $connection 
        && $connection =~ /^keep-alive$/i
    ) {
        $c->response->headers->header( Connection => 'keep-alive' );
        $self->{_keepalive} = 1;
    }
    else {
        $c->response->headers->header( Connection => 'close' );
    }
    
    push @headers, $c->response->headers->as_string("\x0D\x0A");
    
    # Buffer the headers so they are sent with the first write() call
    # This reduces the number of TCP packets we are sending
    $self->{_header_buf} = join("\x0D\x0A", @headers, '');
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
    
    # If we have any remaining data in the input buffer, send it back first
    if ( $_[0] = delete $self->{inputbuf} ) {
        my $read = length( $_[0] );
        DEBUG && warn "read_chunk: Read $read bytes from previous input buffer\n";
        return $read;
    }

    # support for non-blocking IO
    my $rin = '';
    vec( $rin, *STDIN->fileno, 1 ) = 1;

  READ:
    {
        select( $rin, undef, undef, undef );
        my $rc = *STDIN->sysread(@_);
        if ( defined $rc ) {
            DEBUG && warn "read_chunk: Read $rc bytes from socket\n";
            return $rc;
        }
        else {
            next READ if $! == EWOULDBLOCK;
            return;
        }
    }
}

=head2 $self->write($c, $buffer)

Writes the buffer to the client. Can only be called once for a request.

=cut

sub write {
    my ( $self, $c, $buffer ) = @_;
    
	# Avoid 'print() on closed filehandle Remote' warnings when using IE
	return unless *STDOUT->opened();
	
	my $ret;
	
	# Prepend the headers if they have not yet been sent
	if ( my $headers = delete $self->{_header_buf} ) {
	    DEBUG && warn "write: Wrote headers and first chunk (" . length($headers . $buffer) . " bytes)\n";
	    $ret = $self->NEXT::write( $c, $headers . $buffer );
    }
    else {
        DEBUG && warn "write: Wrote chunk (" . length($buffer) . " bytes)\n";
        $ret = $self->NEXT::write( $c, $buffer );
    }
    
    if ( !$ret ) {
        $self->{_write_error} = $!;
    }
    
    return $ret;
}

=head2 run

=cut

# A very very simple HTTP server that initializes a CGI environment
sub run {
    my ( $self, $class, $port, $host, $options ) = @_;

    $options ||= {};
    
    $self->{options} = $options;

    if ($options->{background}) {
        my $child = fork;
        die "Can't fork: $!" unless defined($child);
        exit if $child;
    }

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

    if ($options->{background}) {
        open STDIN,  "+</dev/null" or die $!;
        open STDOUT, ">&STDIN"     or die $!;
        open STDERR, ">&STDIN"     or die $!;
        if ( $^O !~ /MSWin32/ ) {
             require POSIX;
             POSIX::setsid()
                 or die "Can't start a new session: $!";
        }
    }

    if (my $pidfile = $options->{pidfile}) {
        if (! open PIDFILE, "> $pidfile") {
            warn("Cannot open: $pidfile: $!");
        }
        print PIDFILE "$$\n";
        close PIDFILE;
    }

    my $pid = undef;
    
    # Ignore broken pipes as an HTTP server should
    local $SIG{PIPE} = 'IGNORE';
    
    LISTEN:
    while ( !$restart ) {
        while ( accept( Remote, $daemon ) ) {        
            DEBUG && warn "New connection\n";

            select Remote;

            Remote->blocking(1);
        
            # Read until we see all headers
            $self->{inputbuf} = '';
            
            if ( !$self->_read_headers ) {
                # Error reading, give up
                next LISTEN;
            }

            my ( $method, $uri, $protocol ) = $self->_parse_request_line;
        
            DEBUG && warn "Parsed request: $method $uri $protocol\n";
        
            next unless $method;

            unless ( uc($method) eq 'RESTART' ) {

                # Fork
                if ( $options->{fork} ) { next if $pid = fork }

                $self->_handler( $class, $port, $method, $uri, $protocol );
            
                if ( my $error = delete $self->{_write_error} ) {
                    DEBUG && warn "Write error: $error\n";
                    close Remote;
                    next LISTEN;
                }

                $daemon->close if defined $pid;
            }
            else {
                my $sockdata = $self->_socket_data( \*Remote );
                my $ipaddr   = _inet_addr( $sockdata->{peeraddr} );
                my $ready    = 0;
                foreach my $ip ( keys %$allowed ) {
                    my $mask = $allowed->{$ip};
                    $ready = ( $ipaddr & _inet_addr($mask) ) == _inet_addr($ip);
                    last if $ready;
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
    }
    
    $daemon->close;
    
    DEBUG && warn "Shutting down\n";

    if ($restart) {
        $SIG{CHLD} = 'DEFAULT';
        wait;

        ### if the standalone server was invoked with perl -I .. we will loose
        ### those include dirs upon re-exec. So add them to PERL5LIB, so they
        ### are available again for the exec'ed process --kane
        use Config;
        $ENV{PERL5LIB} .= join $Config{path_sep}, @INC; 
        
        exec $^X . ' "' . $0 . '" ' . join( ' ', @{ $options->{argv} } );
    }

    exit;
}

sub _handler {
    my ( $self, $class, $port, $method, $uri, $protocol ) = @_;

    local *STDIN  = \*Remote;
    local *STDOUT = \*Remote;

    # We better be careful and just use 1.0
    $protocol = '1.0';

    my $sockdata    = $self->_socket_data( \*Remote );
    my %copy_of_env = %ENV;

    my $sel = IO::Select->new;
    $sel->add( \*STDIN );
    
    REQUEST:
    while (1) {
        my ( $path, $query_string ) = split /\?/, $uri, 2;

        # Initialize CGI environment
        local %ENV = (
            PATH_INFO       => $path         || '',
            QUERY_STRING    => $query_string || '',
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
            $self->_parse_headers;
        }

        # Pass flow control to Catalyst
        $class->handle_request;
    
        DEBUG && warn "Request done\n";
    
        # Allow keepalive requests, this is a hack but we'll support it until
        # the next major release.
        if ( delete $self->{_keepalive} ) {
            
            DEBUG && warn "Reusing previous connection for keep-alive request\n";
            
            if ( $sel->can_read(1) ) {            
                if ( !$self->_read_headers ) {
                    # Error reading, give up
                    last REQUEST;
                }

                ( $method, $uri, $protocol ) = $self->_parse_request_line;
                
                DEBUG && warn "Parsed request: $method $uri $protocol\n";
                
                # Force HTTP/1.0
                $protocol = '1.0';
                
                next REQUEST;
            }
            
            DEBUG && warn "No keep-alive request within 1 second\n";
        }
        
        last REQUEST;
    }
    
    DEBUG && warn "Closing connection\n";

    close Remote;
}

sub _read_headers {
    my $self = shift;
    
    while (1) {
        my $read = sysread Remote, my $buf, CHUNKSIZE;
    
        if ( !$read ) {
            DEBUG && warn "EOF or error: $!\n";
            return;
        }
    
        DEBUG && warn "Read $read bytes\n";
        $self->{inputbuf} .= $buf;
        last if $self->{inputbuf} =~ /(\x0D\x0A?\x0D\x0A?|\x0A\x0D?\x0A\x0D?)/s;
    }
    
    return 1;
}

sub _parse_request_line {
    my $self = shift;

    # Parse request line    
    if ( $self->{inputbuf} !~ s/^(\w+)[ \t]+(\S+)(?:[ \t]+(HTTP\/\d+\.\d+))?[^\012]*\012// ) {
        return ();
    }
    
    my $method = $1;
    my $uri    = $2;
    my $proto  = $3 || 'HTTP/0.9';
    
    return ( $method, $uri, $proto );
}

sub _parse_headers {
    my $self = shift;
    
    # Copy the buffer for header parsing, and remove the header block
    # from the content buffer.
    my $buf = $self->{inputbuf};
    $self->{inputbuf} =~ s/.*?(\x0D\x0A?\x0D\x0A?|\x0A\x0D?\x0A\x0D?)//s;
    
    # Parse headers
    my $headers = HTTP::Headers->new;
    my ($key, $val);
    HEADER:
    while ( $buf =~ s/^([^\012]*)\012// ) {
        $_ = $1;
        s/\015$//;
        if ( /^([\w\-~]+)\s*:\s*(.*)/ ) {
            $headers->push_header( $key, $val ) if $key;
            ($key, $val) = ($1, $2);
        }
        elsif ( /^\s+(.*)/ ) {
            $val .= " $1";
        }
        else {
            last HEADER;
        }
    }
    $headers->push_header( $key, $val ) if $key;
    
    DEBUG && warn "Parsed headers: " . dump($headers) . "\n";

    # Convert headers into ENV vars
    $headers->scan( sub {
        my ( $key, $val ) = @_;
        
        $key = uc $key;
        $key = 'COOKIE' if $key eq 'COOKIES';
        $key =~ tr/-/_/;
        $key = 'HTTP_' . $key
            unless $key =~ m/\A(?:CONTENT_(?:LENGTH|TYPE)|COOKIE)\z/;
            
        if ( exists $ENV{$key} ) {
            $ENV{$key} .= ", $val";
        }
        else {
            $ENV{$key} = $val;
        }
    } );
}

sub _socket_data {
    my ( $self, $handle ) = @_;

    my $remote_sockaddr       = getpeername($handle);
    my ( undef, $iaddr )      = $remote_sockaddr 
        ? sockaddr_in($remote_sockaddr) 
        : (undef, undef);
        
    my $local_sockaddr        = getsockname($handle);
    my ( undef, $localiaddr ) = sockaddr_in($local_sockaddr);

    # This mess is necessary to keep IE from crashing the server
    my $data = {
        peername  => $iaddr 
            ? ( gethostbyaddr( $iaddr, AF_INET ) || 'localhost' )
            : 'localhost',
        peeraddr  => $iaddr 
            ? ( inet_ntoa($iaddr) || '127.0.0.1' )
            : '127.0.0.1',
        localname => gethostbyaddr( $localiaddr, AF_INET ) || 'localhost',
        localaddr => inet_ntoa($localiaddr) || '127.0.0.1',
    };

    return $data;
}

sub _inet_addr { unpack "N*", inet_aton( $_[0] ) }

=head1 CONSTANTS

=head2 CHUNKSIZE

How much data to read at once.  This value is set to 64K.

=head2 DEBUG

Enables debugging via the environment variable CATALYST_HTTP_DEBUG.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine>.

=head1 AUTHORS

Sebastian Riedel, <sri@cpan.org>

Dan Kubb, <dan.kubb-cpan@onautopilot.com>

Sascha Kiefer, <esskar@cpan.org>

Andy Grundman, <andy@hybridized.org>

=head1 THANKS

Many parts are ripped out of C<HTTP::Server::Simple> by Jesse Vincent.

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
