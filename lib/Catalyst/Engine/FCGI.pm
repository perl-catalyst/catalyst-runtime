package Catalyst::Engine::FCGI;

use strict;
use base 'Catalyst::Engine::CGI';
use FCGI;

=head1 NAME

Catalyst::Engine::FCGI - Catalyst FCGI Engine

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is the Catalyst engine for FastCGI.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::CGI>.

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

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
