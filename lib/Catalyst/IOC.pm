package Catalyst::IOC;
use strict;
use warnings;
use Bread::Board qw/depends_on/;
use Catalyst::IOC::ConstructorInjection;
no strict 'refs';

# FIXME - All of these imports need to get the importing package
#         as the customise_container and current_container variables
#         NEED to be in the containers package so there can be multiple
#         containers..
use Sub::Exporter -setup => {
    exports => [qw/
        depends_on
        component
        model
        container
    /],
    groups  => { default => [qw/
        depends_on
        component
        model
        container
    /]},
};
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
#use Moose::Exporter;
#Moose::Exporter->setup_import_methods(
#    also => ['Bread::Board'],
#);
sub container (&) {
    my $code = shift;
    my $caller = caller;
    ${"${caller}::customise_container"} = sub {
        warn("In customise container");
        local ${"${caller}::current_container"} = shift;
        $code->();
    };
}

sub model (&) {
    my $code = shift;
    my $caller = caller;
    local ${"${caller}::current_container"} = ${"${caller}::current_container"}->get_sub_container('model');
    $code->();
}

sub component {
    my ($name, %args) = @_;
    my $caller = caller;
    $args{dependencies} ||= {};
    $args{dependencies}{application_name} = depends_on( '/application_name' );

    my $lifecycle = $args{lifecycle};
    my %catalyst_lifecycles = map { $_ => 1 } qw/ COMPONENTSingleton Request /;
    $args{lifecycle} = $lifecycle
                     ? $catalyst_lifecycles{$lifecycle} ? "+Catalyst::IOC::LifeCycle::$lifecycle" : $lifecycle
                     : 'Singleton'
                     ;

    # FIXME - check $args{type} here!

    my $component_name = join '::', (
        ${"${caller}::current_container"}->resolve(service => '/application_name'),
        ucfirst(${"${caller}::current_container"}->name),
        $name
    );

    my $service = Catalyst::IOC::ConstructorInjection->new(
        %args,
        name => $name,
        catalyst_component_name => $component_name,
    );
    ${"${caller}::current_container"}->add_service($service);
}

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
