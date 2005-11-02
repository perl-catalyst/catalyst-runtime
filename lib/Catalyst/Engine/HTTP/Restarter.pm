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
    my $restarter;
    my $parent = $$;
    
    unless ( $restarter = fork ) {

        # Prepare
        close STDIN;
        close STDOUT;
        
        my $watcher = Catalyst::Engine::HTTP::Restarter::Watcher->new(
            directory => File::Spec->catdir( $FindBin::Bin, '..' ),
            regex     => $options->{restart_regex},
            delay     => $options->{restart_delay},
        );

        while (1) {
            # poll for changed files
            my @changed_files = $watcher->watch();
            
            # check if our parent process has died
            exit if ( getppid == 1 );            
            
            # Restart if any files have changed
            if ( @changed_files ) {
                my $files = join ', ', @changed_files;
                print STDERR qq/File(s) "$files" modified, restarting\n\n/;
                kill( 1, $parent );
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

=over 4

=item run

=back

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
