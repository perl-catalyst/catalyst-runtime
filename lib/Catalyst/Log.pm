package Catalyst::Log;

use strict;
use base 'Class::Accessor::Fast';
use Data::Dumper;

$Data::Dumper::Terse = 1;

=head1 NAME

Catalyst::Log - Catalyst Log Class

=head1 SYNOPSIS

    $log = $c->log;
    $log->debug($msg, @args);
    $log->dump($ref);
    $log->error($msg, @args);
    $log->info($msg, @args);
    $log->warn($msg, @args);

See L<Catalyst>.

=head1 DESCRIPTION

This module provides the default, simple logging functionality for Catalyst.
If you want something different set C<$c->log> in your application module, e.g.:

    $c->log( MyLogger->new );

Your logging object is expected to provide the interface described here.


=head1 METHODS

=over 4

=item $log->debug($msg, @args)

Logs a debugging message.

=cut

sub debug { _format( 'debug', splice(@_, 1) ) }

=item $log->dump($ref)

Logs a formatted dump of a variable passed by reference (uses C<Data::Dumper>).

=cut

sub dump { _format( 'dump', Dumper( $_[1] ) ) }

=item $log->error($msg, @args)

Logs an error message.

=cut

sub error { _format( 'error', splice(@_, 1) ) }

=item $log->info($msg, @args)

Logs an informational message.

=cut

sub info { _format( 'info', splice(@_, 1) ) }

=item $log->warn($msg, @args)

Logs a warning message.

=cut

sub warn { _format( 'warn', splice(@_, 1) ) }

sub _format {
    if (@_ > 2) {
	printf STDERR '[' . localtime(time) . "] [catalyst] [$_[0]] $_[1]\n", splice(@_, 2);
    }
    else {
	print STDERR '[' . localtime(time) . "] [catalyst] [$_[0]] $_[1]\n";
    }
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
