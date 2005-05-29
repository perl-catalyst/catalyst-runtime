package Catalyst::Engine::HTTP::Daemon;

use strict;
use base 'Catalyst::Engine::HTTP::Base';

use IO::Select;

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
        Listen    => 1,
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

        for my $client ( $select->can_read ) {

            if ( $client == $daemon ) {
                $client = $daemon->accept;
                $client->blocking(0);
                $select->add($client);
            }

            else {
                next if $client->request;
                next if $client->response;

                my $read = $client->sysread( my $buf, 4096 );
                
                unless ( defined($read) && length($buf) ) {
             
                    $select->remove($client);
                    $client->close;

                    next;
                }

                $client->read_buffer($buf);
                $client->request( $client->get_request );
            }
        }

        for my $client ( $select->handles ) {

            next if $client == $daemon;
            next if $client->response;
            next unless $client->request;

            $client->response( HTTP::Response->new );
            $class->handler( $client->request, $client->response, $client );    
        }

        for my $client ( $select->can_write(0) ) {

            next unless $client->response;

            $client->send_response( $client->response );

            my $connection = $client->request->header('Connection');

            unless ( $connection && $connection =~ /Keep-Alive/i ) {
                $select->remove($client);
                $client->close;
            }

            $client->request(undef);
            $client->response(undef);
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

sub read_buffer {
    my $self = shift;

    if (@_) {
        ${*$self}{'httpd_rbuf'} .= shift;
    }

    return ${*$self}{'httpd_rbuf'};
}

sub request {
    my $self = shift;

    if (@_) {
        ${*$self}{'request'} = shift;
    }

    return ${*$self}{'request'};
}

sub response {
    my $self = shift;

    if (@_) {
        ${*$self}{'response'} = shift;
    }

    return ${*$self}{'response'};
}

1;
