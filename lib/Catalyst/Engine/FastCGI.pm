package Catalyst::Engine::FastCGI;

use strict;
use base 'Catalyst::Engine::CGI';
use FCGI;

=head1 NAME

Catalyst::Engine::FastCGI - FastCGI Engine

=head1 DESCRIPTION

This is the FastCGI engine.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::CGI>.

=over 4

=item $self->run($c)

=cut

sub run {
    my ( $self, $class ) = @_;

    my $request = FCGI::Request();

    while ( $request->Accept >= 0 ) {
        $class->handle_request;
    }
}

=item $self->write($c, $buffer)

=cut

sub write {
    my ( $self, $c, $buffer ) = @_;

    unless ( $self->{_prepared_write} ) {
        $self->prepare_write($c);
        $self->{_prepared_write} = 1;
    }

    # FastCGI does not stream data properly if using 'print $handle',
    # but a syswrite appears to work properly.
    *STDOUT->syswrite($buffer);
}

=back

=head1 SEE ALSO

L<Catalyst>, L<FCGI>.

=head1 AUTHORS

Sebastian Riedel, <sri@cpan.org>

Christian Hansen, <ch@ngmedia.com>

Andy Grundman, <andy@hybridized.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
