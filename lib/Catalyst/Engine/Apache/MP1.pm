package Catalyst::Engine::Apache::MP1;

use strict;
use base 'Catalyst::Engine::Apache';

use Apache ();
use Apache::Request ();
use Apache::Cookie ();

sub handler ($$) { shift->SUPER::handler(@_) }

=head1 NAME

Catalyst::Engine::Apache::MP1 - Catalyst Apache MP1 Engine

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is the Catalyst engine specialized for Apache mod_perl version 1.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::Apache>.

=over 4

=item $c->handler

=back

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine>, L<Catalyst::Engine::Apache>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
