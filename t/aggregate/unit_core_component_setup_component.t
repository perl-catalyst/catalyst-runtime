use strict;
use warnings;

# FIXME - backcompat?
use Test::More skip_all => "Removed setup_component from Catalyst.pm";
use Moose::Meta::Class;

my %config = (
    foo => 42,
    bar => 'myconf',
);

Moose::Meta::Class->create( TestAppComponent => (
    superclasses => ['Catalyst'],
));

TestAppComponent->config(
    'Model::With::Config' => { %config },
);

TestAppComponent->setup_config;

my @comps;
push @comps, "TestAppComponent::$_" for qw/
    Without::Component::Sub
    Model::With::Config
    Dieing
    NotBlessed
    Regular
/;
my ($no_sub, $config, $dieing, $not_blessed, $regular) = @comps;

Moose::Meta::Class->create( $no_sub => (
    superclasses => ['Catalyst::Component'],
));

Moose::Meta::Class->create( $config => (
    superclasses => ['Catalyst::Component'],
    methods      => {
        COMPONENT => sub { bless $_[2] }
    },
));

Moose::Meta::Class->create( $dieing => (
    superclasses => ['Catalyst::Component'],
    methods      => {
        COMPONENT => sub { die "Could not create component" }
    },
));

Moose::Meta::Class->create( $not_blessed => (
    superclasses => ['Catalyst::Component'],
    methods      => {
        COMPONENT => sub { {} }
    },
));

Moose::Meta::Class->create( $regular => (
    superclasses => ['Catalyst::Component'],
    methods      => {
        COMPONENT => sub { shift->new }
    },
));

{
    no warnings 'redefine', 'once';
    my $message;
    my $component;

    local *Catalyst::Exception::throw = sub { shift; my %h = @_; $message = $h{message} };

    $component = eval { TestAppComponent->setup_component($no_sub) };
    ok( !$@, "setup_component doesnt die with $no_sub" );
    is( $message, undef, "no exception thrown" );
    isa_ok( $component, $no_sub, "the returned value isa the component" );

    undef $message;
    $component = eval { TestAppComponent->setup_component($config) };
    ok( !$@, "setup_component doesnt die with $config" );
    is( $message, undef, "no exception thrown" );
    is_deeply( $component, \%config, "the returned config is correct" );

    undef $message;
    $component = eval { TestAppComponent->setup_component($dieing) };
    ok( !$@, "setup_component doesnt die with $dieing" );
    like( $message, qr/Could not create component/, "the exception is thrown correctly" );

    undef $message;
    $component = eval { TestAppComponent->setup_component($not_blessed) };
    ok( !$@, "setup_component doesnt die with $not_blessed" );
    isnt( $message, undef, "it throws an exception" );

    undef $message;
    $component = eval { TestAppComponent->setup_component($regular) };
    ok( !$@, "setup_component doesnt die with $regular" );
    is( $message, undef, "no exception thrown" );
    isa_ok( $component, $regular, "the returned value is correct" );
}

done_testing;
