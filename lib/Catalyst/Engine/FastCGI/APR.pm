package Catalyst::Engine::FastCGI::APR;

use strict;
use base qw(Catalyst::Engine::FastCGI::Base Catalyst::Engine::CGI::APR);

=head1 NAME

Catalyst::Engine::FastCGI::APR - Catalyst FastCGI APR Engine

=head1 SYNOPSIS

A script using the Catalyst::Engine::FastCGI::APR module might look like:

    #!/usr/bin/perl -w

    BEGIN { 
       $ENV{CATALYST_ENGINE} = 'FastCGI::APR';
    }

    use strict;
    use lib '/path/to/MyApp/lib';
    use MyApp;

    MyApp->run;

=head1 DESCRIPTION

This is the Catalyst engine for FastCGI and APR.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine::CGI::APR>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
