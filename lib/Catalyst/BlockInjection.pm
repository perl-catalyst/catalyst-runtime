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

=head1 AUTHOR

André Walker

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
