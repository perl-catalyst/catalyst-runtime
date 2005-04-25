package Catalyst::Engine::FCGI::Base;

use strict;
use FCGI;

=head1 NAME

Catalyst::Engine::FCGI::Base - Base class for FastCGI Engines

=head1 DESCRIPTION

This is a base class for FastCGI engines.

=head1 METHODS

=over 4

=item $c->run

=cut

sub run {
    my $class   = shift;
    my $request = FCGI::Request();
    while ( $request->Accept() >= 0 ) {
        $class->handler;
    }
}

=back

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
