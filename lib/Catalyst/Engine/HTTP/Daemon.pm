package Catalyst::Engine::HTTP::Daemon;

use strict;
use base 'Catalyst::Engine::HTTP::Base';

use IO::Select;
use IO::Socket;

BEGIN {

    if ( $^O eq 'MSWin32' ) {

        *EINTR       = sub { 10004 };
        *EINPROGRESS = sub { 10036 };
        *EWOULDBLOCK = sub { 10035 };
        *F_GETFL     = sub {     0 };
        *F_SETFL     = sub {     0 };

        *IO::Socket::blocking = sub {
            my ( $self, $blocking ) = @_;
            my $nonblocking = $blocking ? 0 : 1;
            ioctl( $self, 0x8004667e, \$nonblocking );
        };
    }

    else {
        Errno->require;
        Errno->import( qw[EWOULDBLOCK EINPROGRESS EINTR] );
    }
}

=head1 NAME

Catalyst::Engine::HTTP::Daemon - Catalyst HTTP Daemon Engine

=head1 SYNOPSIS

A script using the Catalyst::Engine::HTTP::Daemon module might look like:

    #!/usr/bin/perl -w

    BEGIN {  $ENV{CATALYST_ENGINE} = 'HTTP::Daemon' }

    use strict;
    use lib '/path/to/MyApp/lib';
    use MyApp;

    MyApp->run;

=head1 DESCRIPTION

This is the Catalyst engine specialized for development and testing.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::HTTP::Base>.

=over 4

=item $c->handler

=cut

sub handler {
    my ( $class, $request, $response, $client ) = @_;

    $request->uri->scheme('http');    # Force URI::http
    $request->uri->host( $request->header('Host') || $client->sockhost );
    $request->uri->port( $client->sockport );

    my $http = Catalyst::Engine::HTTP::Base::struct->new(
        address  => $client->peerhost,
        request  => $request,
        response => $response
    );

    $class->SUPER::handler($http);
}

=item $c->run

=cut

sub run {
    my $class = shift;
    my $port  = shift || 3000;

    $SIG{'PIPE'} = 'IGNORE';

    my $daemon = Catalyst::Engine::HTTP::Daemon::Catalyst->new(
        Listen    => SOMAXCONN,
        LocalPort => $port,
        ReuseAddr => 1,
        Timeout   => 5
    );

    unless ( defined $daemon ) {
        die(qq/Failed to create daemon. Reason: '$!'/);
    }

    my $base = URI->new( $daemon->url )->canonical;

    printf( "You can connect to your server at %s\n", $base );

    my $select = IO::Select->new($daemon);

    while (1) {

        for my $client ( $select->can_read(0.01) ) {

            if ( $client == $daemon ) {
                $client = $daemon->accept;
                $client->timestamp = time;
                $client->blocking(0);
                $select->add($client);
            }

            else {
                next if $client->request;
                next if $client->response;

                my $nread = $client->sysread( my $buf, 4096 );

                unless ( $nread ) {

                    next if $! == EWOULDBLOCK;
                    next if $! == EINPROGRESS;
                    next if $! == EINTR;

                    $select->remove($client);
                    $client->close;

                    next;
                }

                $client->request_buffer .= $buf;

                if ( my $request = $client->get_request ) {
                    $client->request   = $request;
                    $client->timestamp = time
                }
            }
        }

        for my $client ( $select->handles ) {

            next if $client == $daemon;

            if ( ( time - $client->timestamp ) > 60 ) {

                $select->remove($client);
                $client->close;

                next;
            }

            next if $client->response;
            next unless $client->request;

            $client->response = HTTP::Response->new;
            $client->response->protocol( $client->request->protocol );

            $class->handler( $client->request, $client->response, $client );
        }

        for my $client ( $select->can_write(0.01) ) {

            next unless $client->response;

            unless ( $client->response_buffer ) {

                $client->response->header( Server => $daemon->product_tokens );

                my $connection = $client->request->header('Connection') || '';

                if ( $connection =~ /Keep-Alive/i ) {
                    $client->response->header( 'Connection' => 'Keep-Alive' );
                    $client->response->header( 'Keep-Alive' => 'timeout=60, max=100' );
                }

                if ( $connection =~ /close/i ) {
                    $client->response->header( 'Connection' => 'close' );
                }

                $client->response_buffer = $client->response->as_string("\x0D\x0A");
                $client->response_offset = 0;
            }

            my $nwrite = $client->syswrite( $client->response_buffer,
                                            $client->response_length,
                                            $client->response_offset );

            unless ( $nwrite ) {

                next if $! == EWOULDBLOCK;
                next if $! == EINPROGRESS;
                next if $! == EINTR;

                $select->remove($client);
                $client->close;

                next;
            }

            $client->response_offset += $nwrite;

            if ( $client->response_offset == $client->response_length ) {

                my $connection = $client->request->header('Connection') || '';
                my $protocol   = $client->request->protocol;
                my $persistent = 0;

                if ( $protocol eq 'HTTP/1.1' && $connection !~ /close/i ) {
                    $persistent++;
                }

                if ( $protocol ne 'HTTP/1.1' && $connection =~ /Keep-Alive/i ) {
                    $persistent++;
                }

                unless ( $persistent ) {
                    $select->remove($client);
                    $client->close;
                }

                $client->response        = undef;
                $client->request         = undef;
                $client->response_buffer = undef;
            }
        }
    }
}

=back

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine>, L<Catalyst::Engine::HTTP::Base>,
L<HTTP::Daemon>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

package Catalyst::Engine::HTTP::Daemon::Catalyst;

use strict;
use base 'HTTP::Daemon';

sub accept {
    return shift->SUPER::accept('Catalyst::Engine::HTTP::Daemon::Client');
}

sub product_tokens {
    return "Catalyst/$Catalyst::VERSION";
}

package Catalyst::Engine::HTTP::Daemon::Client;

use strict;
use base 'HTTP::Daemon::ClientConn';

sub request : lvalue {
    my $self = shift;
    ${*$self}{'request'};
}

sub request_buffer : lvalue {
    my $self = shift;
    ${*$self}{'httpd_rbuf'};
}

sub response : lvalue {
    my $self = shift;
    ${*$self}{'response'};
}

sub response_buffer : lvalue {
    my $self = shift;
    ${*$self}{'httpd_wbuf'};
}

sub response_length {
    my $self = shift;
    return length( $self->response_buffer );
}

sub response_offset : lvalue {
    my $self = shift;
    ${*$self}{'httpd_woffset'};
}

sub timestamp : lvalue {
    my $self = shift;
    ${*$self}{'timestamp'};
}

1;
