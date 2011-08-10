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

# FIXME - should the code example below be on this file or Catalyst::IOC::Container?

__END__

=pod

=head1 NAME

Catalyst::IOC - IOC for Catalyst, based on Bread::Board

=head1 SYNOPSIS

    package MyApp::Container;
    use Catalyst::IOC;

    sub BUILD {
        my $self = shift;

        container $self => as {
            container model => as {

                # default component
                component Foo => ();

                # model Bar needs model Foo to be built before
                # and Bar's constructor gets Foo as a parameter
                component Bar => ( dependencies => [
                    depends_on('/model/Foo'),
                ]);

                # Baz is rebuilt once per HTTP request
                component Baz => ( lifecycle => 'Request' );

                # built only once per application life time
                component Quux => ( lifecycle => 'Singleton' );

                # built once per app life time and uses an external model,
                # outside the default directory
                # no need for wrappers or Catalyst::Model::Adaptor
                component Fnar => (
                    lifecycle => 'Singleton',
                    class => 'My::External::Class',
                );
            };
        }
    }

=head1 DESCRIPTION

=head1 METHODS

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 SEE ALSO

L<Bread::Board>

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
