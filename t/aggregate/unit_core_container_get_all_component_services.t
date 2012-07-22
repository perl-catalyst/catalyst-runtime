#!/usr/bin/env perl
use strict;
use warnings;

# FIXME
# the exact return value of get_all_component_services
# needs to be reviewed and discussed
#
# See also note in Catalyst::IOC::Container
#
# the temporary solution is
# {
#     class_name => {
#         type               => (model|controller|view),
#         service            => Catalyst::IOC::*Injection instance, # most likely BlockInjection
#         backcompat_service => Catalyst::IOC::ConstructorInjection instance or undef,
#     },
#     class_name => ...
# }

use Test::More;
use Scalar::Util 'blessed';
use Test::Moose;
use FindBin '$Bin';
use lib "$Bin/../lib";
use TestAppGetAllComponentServices;

ok(my $c = TestAppGetAllComponentServices->container, 'get the container');
can_ok($c, 'get_all_component_services');
ok(my $comp_services = $c->get_all_component_services, 'component services are fetched');

my $expected = {
    'TestAppGetAllComponentServices::Controller::Root' => {
        type               => 'controller',
        service_isa        => 'Catalyst::IOC::BlockInjection',
        bcpt_service_isa   => 'Catalyst::IOC::ConstructorInjection',
    },
    'TestAppGetAllComponentServices::Model::Foo' => {
        type               => 'model',
        service_isa        => 'Catalyst::IOC::BlockInjection',
        bcpt_service_isa   => 'Catalyst::IOC::ConstructorInjection',
    },
    'TestAppGetAllComponentServices::Model::Bar' => {
        type               => 'model',
        service_isa        => 'Catalyst::IOC::BlockInjection',
        bcpt_service_isa   => 'Catalyst::IOC::ConstructorInjection',
    },
    'TestAppGetAllComponentServices::Model::Baz' => {
        type               => 'model',
        service_isa        => 'Catalyst::IOC::BlockInjection',
        bcpt_service_isa   => 'Catalyst::IOC::ConstructorInjection',
    },
    'TestAppGetAllComponentServices::View::Wibble' => {
        type               => 'view',
        service_isa        => 'Catalyst::IOC::BlockInjection',
        bcpt_service_isa   => 'Catalyst::IOC::ConstructorInjection',
    },
    'TestAppGetAllComponentServices::View::Wobble' => {
        type               => 'view',
        service_isa        => 'Catalyst::IOC::BlockInjection',
        bcpt_service_isa   => 'Catalyst::IOC::ConstructorInjection',
    },
    'TestAppGetAllComponentServices::View::Wubble' => {
        type               => 'view',
        service_isa        => 'Catalyst::IOC::BlockInjection',
        bcpt_service_isa   => 'Catalyst::IOC::ConstructorInjection',
    },
};

while (my ($class, $info) = each %$expected) {
    ok(exists $comp_services->{$class}, "class $class exists in the returned hash");
    my $received_info = $comp_services->{$class};
    is($received_info->{type}, $info->{type}, 'type is ok');
    isa_ok($received_info->{service}, $info->{service_isa}, 'service');
    isa_ok($received_info->{backcompat_service}, $info->{bcpt_service_isa}, 'backcompat_service');
}

my %singleton_component_classes;
can_ok($c, 'get_all_singleton_lifecycle_components');
ok(my $singleton_comps = $c->get_all_singleton_lifecycle_components, 'singleton components are fetched');
while (my ($class, $comp) = each %$singleton_comps) {
    ok(blessed $comp, "it's an object"); # it just happens this particular app has all components as objects, so I test it remains true
    is($class, ref $comp, "of class $class");

    ok(exists $expected->{$class}, "it's one of the existing components");
    ok(!exists $singleton_component_classes{$class}, "it's the first instance of class $class");
    $singleton_component_classes{$class} = 1;
}
is_deeply([ sort keys %$expected ], [ sort keys %singleton_component_classes ], 'all components returned');

done_testing;
