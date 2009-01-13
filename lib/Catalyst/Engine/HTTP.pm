package Catalyst::Engine::HTTP;

use Moose;
extends 'Catalyst::Engine::CGI';

use Data::Dump qw(dump);
use Errno 'EWOULDBLOCK';
use HTTP::Date ();
use HTTP::Headers;
use HTTP::Status;
use Socket;
use IO::Socket::INET ();
use IO::Select       ();

# For PAR
require Catalyst::Engine::HTTP::Restarter;
require Catalyst::Engine::HTTP::Restarter::Watcher;

use constant CHUNKSIZE => 64 * 1024;
use constant DEBUG     => $ENV{CATALYST_HTTP_DEBUG} || 0;

has options => ( is => 'rw' );
has _keepalive => ( is => 'rw', predicate => '_is_keepalive', clearer => '_clear_keepalive' );
has _write_error => ( is => 'rw', predicate => '_has_write_error' );

use namespace::clean -except => [qw/meta/];

# Refactoring note - could/should Eliminate all instances of $self->{inputbuf},
# which I haven't touched as it is used as an lvalue in a lot of places, and I guess
# doing it differently could be expensive.. Feel free to refactor and NYTProf :)

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
    my $res_headers = $c->response->headers;

    my @headers;
    push @headers, "$protocol $status $message";

    $res_headers->header( Date => HTTP::Date::time2str(time) );
    $res_headers->header( Status => $status );

    # Should we keep the connection open?
    my $connection = $c->request->header('Connection');
    if (   $self->options->{keepalive} 
        && $connection 
        && $connection =~ /^keep-alive$/i
    ) {
        $res_headers->header( Connection => 'keep-alive' );
        $self->_keepalive(1);
    }
    else {
        $res_headers->header( Connection => 'close' );
    }

    push @headers, $res_headers->as_string("\x0D\x0A");

    # Buffer the headers so they are sent with the first write() call
    # This reduces the number of TCP packets we are sending
    $self->_header_buf( join("\x0D\x0A", @headers, '') );
}

=head2 $self->finalize_read($c)

=cut

before finalize_read => sub {
    # Never ever remove this, it would result in random length output
    # streams if STDIN eq STDOUT (like in the HTTP engine)
    *STDIN->blocking(1);
};

=head2 $self->prepare_read($c)

=cut

before prepare_read => sub {
    # Set the input handle to non-blocking
    *STDIN->blocking(0);
};

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

Writes the buffer to the client.

=cut

around write => sub {
    my $orig = shift;
    my ( $self, $c, $buffer ) = @_;

    # Avoid 'print() on closed filehandle Remote' warnings when using IE
    return unless *STDOUT->opened();

    # Prepend the headers if they have not yet been sent
    if ( $self->_has_header_buf ) {
        $buffer = $self->_clear_header_buf . $buffer;
    }

    my $ret = $self->$orig($c, $buffer);

    if ( !defined $ret ) {
        $self->_write_error($!);
        DEBUG && warn "write: Failed to write response ($!)\n";
    }
    else {
        DEBUG && warn "write: Wrote response ($ret bytes)\n";
    }

    return $ret;
};

=head2 run

=cut

# A very very simple HTTP server that initializes a CGI environment
sub run {
    my ( $self, $class, $port, $host, $options ) = @_;

    $options ||= {};
    
    $self->options($options);

    if ($options->{background}) {
        my $child = fork;
        die "Can't fork: $!" unless defined($child);
        return $child if $child;
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

    # Restart on HUP
    local $SIG{HUP} = sub {
        $restart = 1;
        warn "Restarting server on SIGHUP...\n";
    };

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
                close Remote;
                next LISTEN;
            }

            my ( $method, $uri, $protocol ) = $self->_parse_request_line;

            DEBUG && warn "Parsed request: $method $uri $protocol\n";
            next unless $method;

            unless ( uc($method) eq 'RESTART' ) {

                # Fork
                if ( $options->{fork} ) {
                    if ( $pid = fork ) {
                        DEBUG && warn "Forked child $pid\n";
                        next;
                    }
                }

                $self->_handler( $class, $port, $method, $uri, $protocol );
            
                if ( $self->_has_write_error ) {
                    close Remote;
                    
                    if ( !defined $pid ) {
                        next LISTEN;
                    }
                }

                if ( defined $pid ) {
                    # Child process, close connection and exit
                    DEBUG && warn "Child process exiting\n";
                    $daemon->close;
                    exit;
                }
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
        
        exec $^X, $0, @{ $options->{argv} };
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
        if ( $self->_is_keepalive ) {
            $self->_clear_keepalive;
            
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

        if ( !defined $read ) {
            next if $! == EWOULDBLOCK;
            DEBUG && warn "Error reading headers: $!\n";
            return;
        } elsif ( $read == 0 ) {
            DEBUG && warn "EOF\n";
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
    # Leading CRLF sometimes sent by buggy IE versions
    if ( $self->{inputbuf} !~ s/^(?:\x0D\x0A)?(\w+)[ \t]+(\S+)(?:[ \t]+(HTTP\/\d+\.\d+))?[^\012]*\012// ) {
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
        peeraddr  => $iaddr 
            ? ( inet_ntoa($iaddr) || '127.0.0.1' )
            : '127.0.0.1',
        localname => gethostbyaddr( $localiaddr, AF_INET ) || 'localhost',
        localaddr => inet_ntoa($localiaddr) || '127.0.0.1',
    };

    return $data;
}

sub _inet_addr { unpack "N*", inet_aton( $_[0] ) }

no Moose;

=head2 options

Options hash passed to the http engine to control things like if keepalive
is supported.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine>

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 THANKS

Many parts are ripped out of C<HTTP::Server::Simple> by Jesse Vincent.

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
