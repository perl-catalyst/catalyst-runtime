package Catalyst::Engine::HTTP::Daemon;

use strict;
use base 'Catalyst::Engine::HTTP::Base';

use IO::Socket qw( SOCK_STREAM SOMAXCONN );

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
    my ( $class, $client ) = @_;

    $client->timeout(5);

    while ( my $request = $client->get_request ) {

        $request->uri->scheme('http');    # Force URI::http
        $request->uri->host( $request->header('Host') || $client->sockhost );
        $request->uri->port( $client->sockport );

        my $http = Catalyst::Engine::HTTP::Base::struct->new(
            address  => $client->peerhost,
            request  => $request,
            response => HTTP::Response->new
        );

        $class->SUPER::handler($http);

        $client->send_response( $http->response );
    }

    $client->close;
}

=item $c->run

=cut

sub run {
    my $class = shift;
    my $port  = shift || 3000;
    
    $SIG{'PIPE'} = 'IGNORE';
    
    $HTTP::Daemon::PROTO = 'HTTP/1.0'; # For now until we resolve the blocking 
                                       # issues with HTTP 1.1

    my $daemon = Catalyst::Engine::HTTP::Daemon::Catalyst->new(
        Listen    => SOMAXCONN,
        LocalPort => $port,
        ReuseAddr => 1,
        Type      => SOCK_STREAM,
    );
    
    unless ( defined $daemon ) {
        die( qq/Failed to create daemon. Reason: '$!'/ );
    }

    my $base = URI->new( $daemon->url )->canonical;

    printf( "You can connect to your server at %s\n", $base );

    while ( my $client = $daemon->accept ) {
        $class->handler($client);
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

sub product_tokens {
    "Catalyst/$Catalyst::VERSION";
}

1;
