package Catalyst::Engine::SpeedyCGI::Base;

use strict;
use base 'Catalyst::Engine::CGI::Base';

use CGI::SpeedyCGI;

__PACKAGE__->mk_accessors('speedycgi');

=head1 NAME

Catalyst::Engine::SpeedyCGI::Base - Base class for SpeedyCGI Engines

=head1 DESCRIPTION

This is a base class for SpeedyCGI engines.

=head1 METHODS

=over 4

=item $c->speedycgi

Contains the C<CGI::SpeedyCGI> object.

=back

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::CGI::Base>.

=over 4

=item $c->prepare_request

=cut

sub prepare_request {
    my ( $c, $speedycgi ) = @_;
    $c->speedycgi($speedycgi);
}

=item $c->run

=cut

sub run {
    my ( $class, @arguments ) = @_; 
    $class->handler( CGI::SpeedyCGI->new, @arguments );
}

=back

=head1 SEE ALSO

L<Catalyst>, L<CGI::SpeedyCGI>, L<Catalyst::Engine::CGI::Base>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
