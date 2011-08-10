package Catalyst::IOC;
use strict;
use warnings;
use Bread::Board;

# FIXME - neither of these work:
#use Sub::Exporter -setup => [
#    qw(
#        as
#        container
#        depends_on
#        service
#        alias
#        wire_names
#        include
#        typemap
#        infer
#    )
#];
#use Sub::Exporter -setup => [
#    qw(
#        Bread::Board::as
#        Bread::Board::container
#        Bread::Board::depends_on
#        Bread::Board::service
#        Bread::Board::alias
#        Bread::Board::wire_names
#        Bread::Board::include
#        Bread::Board::typemap
#        Bread::Board::infer
#    )
#];
# I'm probably doing it wrong.
# Anyway, I'll just use Moose::Exporter. Do I really have to use Sub::Exporter?
use Moose::Exporter;
Moose::Exporter->setup_import_methods(
    also => ['Bread::Board'],
);

1;

__END__

=pod

=head1 NAME

Catalyst::IOC - IOC for Catalyst, based on Bread::Board

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
