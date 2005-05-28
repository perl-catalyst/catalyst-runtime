package Catalyst::Log;

use strict;
use base 'Class::Accessor::Fast';
use Data::Dumper;

our @levels = qw[ debug info warn error fatal ];

{
    no strict 'refs';

    for ( my $i = 0 ; $i < @levels ; $i++ ) {

        my $name  = $levels[$i];
        my $level = 1 << $i;

        *{$name} = sub {
            my $self = shift;

            if ( $self->{level} & $level ) {
                $self->_log( $name, @_ );
            }
        };

        *{"is_$name"} = sub {
            my $self = shift;

            if (@_) {
                if ( $_[0] ) {
                    $self->{level} |= $level;
                }
                else {
                    $self->{level} &= ~$level;
                }
            }
            return $self->{level} & $level;
        };
    }

    *new = sub { bless( { level => ( 1 << @levels ) - 1 }, shift ) }
}

sub _dump { 
    my $self = shift;
    local $Data::Dumper::Terse = 1;
    $self->info( Dumper( $_[0] ) );
}

sub _log {
    my $self    = shift;
    my $level   = shift;
    my $time    = localtime(time);
    my $message = join( "\n", @_ );
    printf( STDERR "[%s] [catalyst] [%s] %s\n", $time, $level, $message );
}

1;

__END__

=head1 NAME

Catalyst::Log - Catalyst Log Class

=head1 SYNOPSIS

    $log = $c->log;
    $log->debug($message);
    $log->info($message);
    $log->warn($message);
    $log->error($message);
    $log->fatal($message);
    
    $log->is_debug;   # true if dubug messages is enabled
    $log->is_info;    # true if info messages is enabled
    $log->is_warn;    # true if warn messages is enabled 
    $log->is_error;   # true if error messages is enabled
    $log->is_fatal;   # true if fatal messages is enabled

    if ( $log->is_info ) {
         # expensive debugging
    }

See L<Catalyst>.

=head1 DESCRIPTION

This module provides the default, simple logging functionality for 
Catalyst.
If you want something different set C<$c->log> in your application 
module, e.g.:

    $c->log( MyLogger->new );

Your logging object is expected to provide the interface described here.


=head1 METHODS

=over 4

=item $log->debug($message)

Logs a debugging message.

=item $log->error($message)

Logs an error message.

=item $log->info($message)

Logs an informational message.

=item $log->warn($message)

Logs a warning message.

=back

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Marcus Ramberg, C<mramberg@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

1;
