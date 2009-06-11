package Catalyst::Engine::HTTP::Restarter;
use Moose;
use Moose::Util qw/find_meta/;
use namespace::clean -except => 'meta';

extends 'Catalyst::Engine::HTTP';

use Catalyst::Engine::HTTP::Restarter::Watcher;

around run => sub {
    my $orig = shift;
    my ( $self, $class, $port, $host, $options ) = @_;

    $options ||= {};

    # Setup restarter
    unless ( my $restarter = fork ) {

        # Prepare
        close STDIN;
        close STDOUT;

        # Avoid "Setting config after setup" error restarting MyApp.pm
        $class->setup_finished(0);
        # Best effort if we can't trap compiles..
        $self->_make_components_mutable($class)
            if !Catalyst::Engine::HTTP::Restarter::Watcher::DETECT_PACKAGE_COMPILATION;

        my $watcher = Catalyst::Engine::HTTP::Restarter::Watcher->new(
            directory => (
                $options->{restart_directory} ||
                File::Spec->catdir( $FindBin::Bin, '..' )
            ),
            follow_symlinks => $options->{follow_symlinks},
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

    return $self->$orig( $class, $port, $host, $options );
};

# Naive way of trying to avoid Moose blowing up when you re-require components
# which have been made immutable.
sub _make_components_mutable {
    my ($self, $class) = @_;

    my @metas = grep { defined($_) }
                map { find_meta($_) }
                ($class, map { blessed($_) }
                values %{ $class->components });

    foreach my $meta (@metas) {
        # Paranoia unneeded, all component metaclasses should have immutable
        $meta->make_mutable if $meta->is_immutable;
    }
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

Catalyst Contributors, see Catalyst.pm

=head1 THANKS

Many parts are ripped out of C<HTTP::Server::Simple> by Jesse Vincent.

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
