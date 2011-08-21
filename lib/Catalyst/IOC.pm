package Catalyst::IOC;
use strict;
use warnings;
use Bread::Board qw/depends_on/;
use Catalyst::IOC::ConstructorInjection;

use Sub::Exporter -setup => {
    exports => [qw/
        depends_on
        component
        model
        view
        controller
        container
    /],
    groups  => { default => [qw/
        depends_on
        component
        model
        view
        controller
        container
    /]},
};

sub container (&) {
    my $code = shift;
    my $caller = caller;

    no strict 'refs';
    ${"${caller}::customise_container"} = sub {
        local ${"${caller}::current_container"} = shift;
        $code->();
    };
}

sub model (&)      { &_subcontainer }
sub view (&)       { &_subcontainer }
sub controller (&) { &_subcontainer }

sub _subcontainer {
    my $code = shift;

    my ( $caller, $f, $l, $subcontainer ) = caller(1);
    $subcontainer =~ s/^Catalyst::IOC:://;

    no strict 'refs';
    local ${"${caller}::current_container"} =
        ${"${caller}::current_container"}->get_sub_container($subcontainer);
    $code->();
}

sub component ($;%) {
    my ($name, %args) = @_;
    my $current_container;

    {
        no strict 'refs';
        my $caller = caller;
        $current_container = ${"${caller}::current_container"};
    }

    $args{dependencies} ||= {};
    $args{dependencies}{application_name} = depends_on( '/application_name' );

    my $lifecycle    = $args{lifecycle} || 'Singleton';
    $args{lifecycle} = grep( m/^$lifecycle$/, qw/COMPONENTSingleton Request/)
                     ? "+Catalyst::IOC::LifeCycle::$lifecycle"
                     : $lifecycle
                     ;

    # FIXME - check $args{type} here!

    my $component_name = join '::', (
        $current_container->resolve(service => '/application_name'),
        ucfirst($current_container->name),
        $name
    );

    $current_container->add_service(
        Catalyst::IOC::ConstructorInjection->new(
            %args,
            name => $name,
            catalyst_component_name => $component_name,
        )
    );
}

1;

__END__

=pod

=head1 NAME

Catalyst::IOC - IOC for Catalyst, based on Bread::Board

=head1 SYNOPSIS

    package MyApp::Container;
    use Moose;
    use Catalyst::IOC;
    extends 'Catalyst::IOC::Container';

    container {
        model {
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
        view {
            component HTML => ();
        };
        controller {
            component Root => ();
        };
    }

=head1 DESCRIPTION

Catalyst::IOC provides "sugar" methods to extend the behavior of the default
Catalyst container.

=head1 METHODS

=head2 container

Sets up the root container to be customised.

=head2 model

Sets up the model container to be customised.

=head2 view

Sets up the view container to be customised.

=head2 controller

Sets up the controller container to be customised.

=head2 component

Adds a component to the subcontainer. Works like L<Bread::Board::service>.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 SEE ALSO

L<Bread::Board>

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
