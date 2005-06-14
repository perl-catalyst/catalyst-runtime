package Catalyst::Exception;

use strict;
use vars qw[@ISA $CATALYST_EXCEPTION_CLASS];
use UNIVERSAL::require;

BEGIN {
    push( @ISA, $CATALYST_EXCEPTION_CLASS || 'Catalyst::Exception::Base' );
}

package Catalyst::Exception::Base;

use strict;
use Carp ();

=head1 NAME

Catalyst::Exception - Catalyst Exception Class

=head1 SYNOPSIS

   Catalyst::Exception->throw( qq/Fatal exception/ );

See also L<Catalyst>.

=head1 DESCRIPTION

This is the Catalyst Exception class.

=head1 METHODS

=over 4

=item throw( $message )

=item throw( message => $message )

=item throw( error => $error )

Throws a fatal exception.

=cut

sub throw {
    my $class  = shift;
    my %params = @_ == 1 ? ( error => $_[0] ) : @_;

    my $message = $params{message} || $params{error} || $! || '';

    local $Carp::CarpLevel = 1;

    Carp::croak($message);
}

=back

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
