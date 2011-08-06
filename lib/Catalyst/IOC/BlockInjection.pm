package Catalyst::IOC::BlockInjection;
use Moose;
extends 'Bread::Board::BlockInjection';

with 'Catalyst::IOC::Service::WithAcceptContext',
     'Catalyst::IOC::Service::WithParameters',
     'Bread::Board::Service::WithDependencies';

__PACKAGE__->meta->make_immutable;

no Moose; 1;

__END__

=pod

=head1 NAME

Catalyst::IOC::BlockInjection

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
