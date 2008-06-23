package Catalyst::Base;

use MRO::Compat;
use mro 'c3';
use Moose;
BEGIN{ extends qw/Catalyst::Controller/ };
no Moose;

1;

__END__

=head1 NAME

Catalyst::Base - Deprecated base class

=head1 DESCRIPTION

This used to be the base class for Catalyst Controllers. It
remains here for compability reasons.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Controller>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Marcus Ramberg, C<mramberg@cpan.org>
Matt S Trout, C<mst@shadowcatsystems.co.uk>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
