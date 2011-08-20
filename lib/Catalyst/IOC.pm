package Catalyst::IOC;
use strict;
use warnings;
use Bread::Board qw/depends_on/;
use Catalyst::IOC::ConstructorInjection;
no strict 'refs';

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

sub container (&) {
    my $code = shift;
    my $caller = caller;
    ${"${caller}::customise_container"} = sub {
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
