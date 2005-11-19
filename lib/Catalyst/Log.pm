package Catalyst::Log;

use strict;
use base 'Class::Accessor::Fast';
use Data::Dumper;

our %LEVELS = ();

__PACKAGE__->mk_accessors('level');
__PACKAGE__->mk_accessors('body');
__PACKAGE__->mk_accessors('abort');

{
    my @levels = qw[ debug info warn error fatal ];

    for ( my $i = 0 ; $i < @levels ; $i++ ) {

        my $name  = $levels[$i];
        my $level = 1 << $i;

        $LEVELS{$name} = $level;

        no strict 'refs';

        *{$name} = sub {
            my $self = shift;

            if ( $self->{level} & $level ) {
                $self->_log( $name, @_ );
            }
        };

        *{"is_$name"} = sub {
            my $self = shift;
            return $self->{level} & $level;
        };
    }
}

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new;
    $self->levels( scalar(@_) ? @_ : keys %LEVELS );
    return $self;
}

sub levels {
    my ( $self, @levels ) = @_;
    $self->level(0);
    $self->enable(@levels);
}

sub enable {
    my ( $self, @levels ) = @_;
    $self->{level} |= $_ for map { $LEVELS{$_} } @levels;
}

sub disable {
    my ( $self, @levels ) = @_;
    $self->{level} &= ~$_ for map { $LEVELS{$_} } @levels;
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
    $self->{body} .=
      sprintf( "[%s] [catalyst] [%s] %s\n", $time, $level, $message );
}

sub _flush {
    my $self = shift;
    if ( $self->abort || !$self->body ) {
        $self->abort(undef);
    }
    else {
        print( STDERR $self->body );
    }
    $self->body(undef);
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

    if ( $log->is_debug ) {
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

=head1 LOG LEVELS

=head2 debug

    $log->is_debug;
    $log->debug($message);

=head2 info

    $log->is_info;
    $log->info($message);

=head2 warn

    $log->is_warn;
    $log->warn($message);

=head2 error

    $log->is_error;
    $log->error($message);

=head2 fatal

    $log->is_fatal;
    $log->fatal($message);

=head1 METHODS

=head2 new

Constructor. Defaults to enable all levels unless levels are provided in
arguments.

    $log = Catalyst::Log->new;
    $log = Catalyst::Log->new( 'warn', 'error' );

=head2 levels

Set log levels

    $log->levels( 'warn', 'error', 'fatal' );

=head2 enable

Enable log levels

    $log->enable( 'warn', 'error' );

=head2 disable

Disable log levels

    $log->disable( 'warn', 'error' );

=head2 is_debug

=head2 is_error

=head2 is_fatal

=head2 is_info

=head2 is_warn

Is the log level active?

=head2 abort

Should Catalyst emit logs for this request? Will be reset at the end of 
each request. 

*NOTE* This method is not compatible with other log apis, so if you plan
to use Log4Perl or another logger, you should call it like this:

    $c->log->abort(1) if $c->log->can('abort');

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Marcus Ramberg, C<mramberg@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
