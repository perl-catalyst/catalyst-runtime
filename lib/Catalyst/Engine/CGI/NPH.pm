package Catalyst::Engine::CGI::NPH;

use strict;
use base 'Catalyst::Engine::CGI';

use HTTP::Status ();

=head1 NAME

Catalyst::Engine::CGI::NPH - Catalyst CGI Engine

=head1 SYNOPSIS

A script using the Catalyst::Engine::CGI::NPH module might look like:

    #!/usr/bin/perl -w

    BEGIN { 
       $ENV{CATALYST_ENGINE} = 'CGI::NPH';
    }

    use strict;
    use lib '/path/to/MyApp/lib';
    use MyApp;

    MyApp->run;

=head1 DESCRIPTION

This Catalyst engine returns a complete HTTP response message.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::CGI>.

=over 4

=item $c->finalize_headers

=cut

sub finalize_headers {
    my $c = shift;

    my $protocol = $ENV{SERVER_PROTOCOL} || 'HTTP/1.0';
    my $status   = $c->response->status || 200;
    my $message  =  HTTP::Status::status_message($status);
   
    printf( "%s %d %s\015\012", $protocol, $status, $message );

    $c->SUPER::finalize_headers;
}

=back

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine::CGI>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
