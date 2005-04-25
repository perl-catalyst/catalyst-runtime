package Catalyst::Engine::HTTP;

use strict;
use base 'Catalyst::Engine::HTTP::Daemon';

=head1 NAME

Catalyst::Engine::HTTP - Catalyst HTTP Engine

=head1 SYNOPSIS

A script using the Catalyst::Engine::HTTP module might look like:

    #!/usr/bin/perl -w

    BEGIN {  $ENV{CATALYST_ENGINE} = 'HTTP' }

    use strict;
    use lib '/path/to/MyApp/lib';
    use MyApp;

    MyApp->run;

=head1 DESCRIPTION

This is the Catalyst engine specialized for development and testing.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine>, L<Catalyst::Engine::HTTP::Daemon>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
