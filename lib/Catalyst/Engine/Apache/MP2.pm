package Catalyst::Engine::Apache::MP2;

use strict;
use base 'Catalyst::Engine::Apache';

use Apache2 ();
use Apache::Connection ();
use Apache::RequestIO ();
use Apache::RequestRec ();
use Apache::RequestUtil ();
use Apache::Request ();
use Apache::Cookie ();
use Apache::Upload ();
use Apache::URI ();
use APR::URI ();

sub handler : method { shift->SUPER::handler(@_) }

=head1 NAME

Catalyst::Engine::Apache::MP2 - Catalyst Apache MP2 Engine

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is the Catalyst engine specialized for Apache mod_perl version 2.

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
