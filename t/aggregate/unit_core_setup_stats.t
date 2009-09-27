use strict;
use warnings;

use Test::More tests => 5;
use Class::MOP::Class;

use Catalyst ();

my %log_messages; # TODO - Test log messages as expected.
my $mock_log = Class::MOP::Class->create_anon_class(
    methods => {
        map { my $level = $_;
            $level => sub {
                $log_messages{$level} ||= [];
                push(@{ $log_messages{$level} }, $_[1]);
            },
        }
        qw/debug info warn error fatal/,
    },
)->new_object;

sub mock_app {
    my $name = shift;
    %log_messages = (); # Flatten log messages.
    my $meta = Moose->init_meta( for_class => $name );
    $meta->superclasses('Catalyst');
    $meta->add_method('log', sub { $mock_log });
    return $meta->name;
}

local %ENV = %ENV;

# Remove all relevant env variables to avoid accidental fail
foreach my $name (grep { /^(CATALYST|TESTAPP)/ } keys %ENV) {
    delete $ENV{$name};
}

{
    my $app = mock_app('TestAppNoStats');
    $app->setup_stats();
    ok !$app->use_stats, 'stats off by default';
}
{
    my $app = mock_app('TestAppStats');
    $app->setup_stats(1);
    ok $app->use_stats, 'stats on if you say >setup_stats(1)';
}
{
    my $app = mock_app('TestAppStatsDebugTurnsStatsOn');
    $app->meta->add_method('debug' => sub { 1 });
    $app->setup_stats();
    ok $app->use_stats, 'debug on turns stats on';
}
{
    local %ENV = %ENV;
    $ENV{CATALYST_STATS} = 1;
    my $app = mock_app('TestAppStatsEnvSet');
    $app->setup_stats();
    ok $app->use_stats, 'ENV turns stats on';
}
{
    local %ENV = %ENV;
    $ENV{CATALYST_STATS} = 0;
    my $app = mock_app('TestAppStatsEnvUnset');
    $app->meta->add_method('debug' => sub { 1 });
    $app->setup_stats(1);
    ok !$app->use_stats, 'ENV turns stats off, even when debug on and ->setup_stats(1)';
}

