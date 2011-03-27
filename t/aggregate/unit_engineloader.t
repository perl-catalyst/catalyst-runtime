use strict;
use warnings;
use Test::More;
use Catalyst::EngineLoader;

my $cases = {
    FastCGI => {
        expected_catalyst_engine_class => 'Catalyst::Engine',
        ENV => { CATALYST_ENGINE => 'FastCGI' },
    },
    CGI => {
        expected_catalyst_engine_class => 'Catalyst::Engine',
        ENV => { CATALYST_ENGINE => 'CGI' },
    },
    Apache1 => {
        expected_catalyst_engine_class => 'Catalyst::Engine',
        ENV => { CATALYST_ENGINE => 'Apache1' },
    },
};

foreach my $name (keys %$cases) {
    local %ENV = %{ $cases->{$name}->{ENV} };
    my $loader = Catalyst::EngineLoader->new(application_name => "TestApp");
    if (my $expected = $cases->{$name}->{expected_catalyst_engine_class}) {
        is $loader->catalyst_engine_class, $expected, $name . " catalyst_engine_class";
    }
}

done_testing;
