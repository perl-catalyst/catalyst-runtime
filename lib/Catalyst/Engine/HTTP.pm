package Catalyst::Engine::HTTP;

use strict;
use base 'Catalyst::Engine::Test';

use IO::Socket qw(AF_INET INADDR_ANY SOCK_STREAM SOMAXCONN);

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

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::Test>.

=over 4

=item $c->run

=cut

$SIG{'PIPE'} = 'IGNORE';

sub run {
    my $class = shift;
    my $port  = shift || 3000;

    my $daemon = Catalyst::Engine::HTTP::Catalyst->new(
        Listen    => SOMAXCONN,
        LocalPort => $port,
        ReuseAddr => 1,
        Type      => SOCK_STREAM,
    );

    unless ($daemon) {
        die("Failed to create daemon: $!\n");
    }

    my $base = URI->new( $daemon->url )->canonical;

    printf( "You can connect to your server at %s\n", $base );

    while ( my $connection = $daemon->accept ) {

        $connection->timeout(5);

        while ( my $request = $connection->get_request ) {

            $request->uri->scheme('http');    # Force URI::http
            $request->uri->host( $request->header('Host') || $base->host );
            $request->uri->port( $base->port );
            
            my $hostname = gethostbyaddr( $connection->peeraddr, AF_INET );

            my $http = Catalyst::Engine::Test::HTTP->new(
                address  => $connection->peerhost,
                hostname => $hostname || $connection->peerhost,
                request  => $request,
                response => HTTP::Response->new
            );

            $class->handler($http);
            $connection->send_response( $http->response );

        }

        $connection->close;
        undef($connection);
    }
}

=back

=head1 SEE ALSO

L<Catalyst>, L<HTTP::Daemon>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

package Catalyst::Engine::HTTP::Catalyst;

use strict;
use base 'HTTP::Daemon';

sub product_tokens {
    "Catalyst/$Catalyst::VERSION";
}

1;
