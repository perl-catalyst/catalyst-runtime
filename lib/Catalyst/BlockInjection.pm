package Catalyst::BlockInjection;
use Moose;

extends 'Bread::Board::BlockInjection';

with 'Catalyst::Service::WithContext';

__PACKAGE__->meta->make_immutable;

no Moose;
1;

__END__

=pod

=head1 NAME

Catalyst::BlockInjection

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
