package Catalyst::Engine::FastCGI::Base;

use strict;
use base 'Catalyst::Engine::CGI::Base';

use FCGI;

__PACKAGE__->mk_accessors('fastcgi');

=head1 NAME

Catalyst::Engine::FastCGI::Base - Base class for FastCGI Engines

=head1 DESCRIPTION

This is a base class for FastCGI engines.

=head1 METHODS

=over 4

=item $c->fastcgi

Contains the C<FCGI::Request> object.

=back

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::CGI::Base>.

=over 4

=item $c->prepare_request

=cut

sub prepare_request {
    my ( $c, $request ) = @_;
    $c->fastcgi($request);
}

=item $c->run

=cut

sub run {
    my ( $class, @arguments ) = @_;
    
    my $request = FCGI::Request();
    
    while ( $request->Accept >= 0 ) {
        $class->handler( $request, @arguments );
    }
}

=back

=head1 SEE ALSO

L<Catalyst>, L<FCGI>, L<Catalyst::Engine::CGI::Base>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
