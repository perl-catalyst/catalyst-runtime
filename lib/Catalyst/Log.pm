package Catalyst::Log;

use strict;
use base 'Class::Accessor::Fast';
use Data::Dumper;

$Data::Dumper::Terse = 1;

=head1 NAME

Catalyst::Log - Catalyst Log Class

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

Simple logging functionality for Catalyst.

=head1 METHODS

=over 4

=item $c->debug($msg)

Logs a debugging message.

=cut

sub debug { _format( 'debug', $_[1] ) }

=item $c->dump($ref)

Logs a formatted dump of a variable passed by reference (uses C<Data::Dumper>).

=cut

sub dump { _format( 'dump', Dumper( $_[1] ) ) }

=item $c->error($msg)

Logs an error message.

=cut

sub error { _format( 'error', $_[1] ) }

=item $c->info($msg)

Logs an informational message.

=cut

sub info { _format( 'info', $_[1] ) }

=item $c->warn($msg)

Logs a warning message.

=cut

sub warn { _format( 'warn', $_[1] ) }

sub _format {
    print STDERR '[' . localtime(time) . "] [catalyst] [$_[0]] $_[1]\n";
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
