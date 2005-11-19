package Catalyst::Engine::HTTP::Restarter;

use strict;
use warnings;
use base 'Catalyst::Engine::HTTP';
use Catalyst::Engine::HTTP::Restarter::Watcher;
use NEXT;

sub run {
    my ( $self, $class, $port, $host, $options ) = @_;

    $options ||= {};

    # Setup restarter
    unless ( my $restarter = fork ) {

        # Prepare
        close STDIN;
        close STDOUT;

        my $watcher = Catalyst::Engine::HTTP::Restarter::Watcher->new(
            directory => File::Spec->catdir( $FindBin::Bin, '..' ),
            regex     => $options->{restart_regex},
            delay     => $options->{restart_delay},
        );

        $host ||= '127.0.0.1';
        while (1) {

            # poll for changed files
            my @changed_files = $watcher->watch();

            # check if our parent process has died
            exit if $^O ne 'MSWin32' and getppid == 1;

            # Restart if any files have changed
            if (@changed_files) {
                my $files = join ', ', @changed_files;
                print STDERR qq/File(s) "$files" modified, restarting\n\n/;

                require IO::Socket::INET;
                require HTTP::Headers;
                require HTTP::Request;

                my $client = IO::Socket::INET->new(
                    PeerAddr => $host,
                    PeerPort => $port
                  )
                  or die "Can't create client socket (is server running?): ",
                  $!;

                # build the Kill request
                my $req =
                  HTTP::Request->new( 'RESTART', '/',
                    HTTP::Headers->new( 'Connection' => 'close' ) );
                $req->protocol('HTTP/1.0');

                $client->send( $req->as_string )
                  or die "Can't send restart instruction: ", $!;
                $client->close();
                exit;
            }
        }
    }

    return $self->NEXT::run( $class, $port, $host, $options );
}

1;
__END__

=head1 NAME

Catalyst::Engine::HTTP::Restarter - Catalyst Auto-Restarting HTTP Engine

=head1 SYNOPSIS

    script/myapp_server.pl -restart

=head1 DESCRIPTION

The Restarter engine will monitor files in your application for changes
and restart the server when any changes are detected.

=head1 METHODS

=head2 run

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine::HTTP>, L<Catalyst::Engine::CGI>,
L<Catalyst::Engine>.

=head1 AUTHORS

Sebastian Riedel, <sri@cpan.org>

Dan Kubb, <dan.kubb-cpan@onautopilot.com>

Andy Grundman, <andy@hybridized.org>

=head1 THANKS

Many parts are ripped out of C<HTTP::Server::Simple> by Jesse Vincent.

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
