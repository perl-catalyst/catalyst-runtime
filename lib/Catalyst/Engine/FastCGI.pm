package Catalyst::Engine::FastCGI;

use strict;
use base qw(Catalyst::Engine::FastCGI::Base Catalyst::Engine::CGI);

=head1 NAME

Catalyst::Engine::FastCGI - Catalyst FastCGI Engine

=head1 SYNOPSIS

A script using the Catalyst::Engine::FastCGI module might look like:

    #!/usr/bin/perl -w

    BEGIN { 
       $ENV{CATALYST_ENGINE} = 'FastCGI';
    }

    use strict;
    use lib '/path/to/MyApp/lib';
    use MyApp;

    MyApp->run;

=head1 DESCRIPTION

This is the Catalyst engine for FastCGI.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::FastCGI::Base>
and C<Catalyst::Engine::CGI>.

=over 4

=item $c->prepare_body

=cut

sub prepare_body { 
    shift->Catalyst::Engine::CGI::prepare_body(@_);
}

=item $c->prepare_parameters

=cut

sub prepare_parameters { 
    shift->Catalyst::Engine::CGI::prepare_parameters(@_);
}

=item $c->prepare_request

=cut

sub prepare_request {
    my ( $c, $request, @arguments ) = @_;
    CGI::_reset_globals();
    $c->SUPER::prepare_request($request);
    $c->Catalyst::Engine::CGI::prepare_request(@arguments);
}

=item $c->prepare_uploads

=cut

sub prepare_uploads { 
    shift->Catalyst::Engine::CGI::prepare_uploads(@_);
}

=back 

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine::FastCGI::Base>, L<Catalyst::Engine::CGI>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
