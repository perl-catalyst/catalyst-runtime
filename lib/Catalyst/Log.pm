package Catalyst::Log;

use strict;
use base 'Class::Accessor::Fast';
use Data::Dumper;

$Data::Dumper::Terse = 1;

=head1 NAME

Catalyst::Log - Catalyst Log Class

=head1 SYNOPSIS

    $log = $c->log;
    $log->debug(@message);
    $log->error(@message);
    $log->info(@message);
    $log->warn(@message);

See L<Catalyst>.

=head1 DESCRIPTION

This module provides the default, simple logging functionality for Catalyst.
If you want something different set C<$c->log> in your application module, e.g.:

    $c->log( MyLogger->new );

Your logging object is expected to provide the interface described here.


=head1 METHODS

=over 4

=item $log->debug(@message)

Logs a debugging message.

=cut

sub debug { shift->_format( 'debug', @_ ) }

sub dump { shift->_format( 'dump', Dumper( $_[1] ) ) }

=item $log->error(@message)

Logs an error message.

=cut

sub error { shift->_format( 'error', @_ ) }

=item $log->info(@message)

Logs an informational message.

=cut

sub info { shift->_format( 'info', @_ ) }

=item $log->warn(@message)

Logs a warning message.

=cut

sub warn { shift->_format( 'warn', @_ ) }

sub _format {
    my $class   = shift;
    my $level   = shift;
    my $time    = localtime(time);
    my $message = join( "\n", @_ );
    printf( STDERR "[%s] [catalyst] [%s] %s\n", $time, $level, $message );
}

=back

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
