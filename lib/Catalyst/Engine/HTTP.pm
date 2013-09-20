package # Hide from PAUSE
    Catalyst::Engine::HTTP;
use strict;
use warnings;

use base 'Catalyst::Engine';

warn("You are loading Catalyst::Engine::HTTP explicitly.

This is almost certainly a bad idea, as Catalyst::Engine::HTTP
has been removed in this version of Catalyst.

Please update your application's scripts with:

  catalyst.pl -force -scripts MyApp

to update your scripts to not do this.\n") unless $ENV{HARNESS_ACTIVE};

1;

__END__

=head1 NAME

Catalyst::Engine::HTTP - removed module

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is here only as some old generated scripts require Catalyst::Engine::HTTP

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
