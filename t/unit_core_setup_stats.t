use strict;
use warnings;

use Test::More tests => 5;
use Test::MockObject;

use Catalyst ();

my %log_messages; # TODO - Test log messages as expected.
my $mock_log = Test::MockObject->new;
foreach my $level (qw/debug info warn error fatal/) {
    $mock_log->mock($level, sub { 
        $log_messages{$level} ||= [];
        push(@{ $log_messages{$level} }, $_[1]);
    });
}

sub mock_app {
    my $name = shift;
    %log_messages = (); # Flatten log messages.
    print "Setting up mock application: $name\n";
    my $meta = Moose->init_meta( for_class => $name );
    $meta->superclasses('Catalyst');
    $meta->add_method('log', sub { $mock_log }); 
    return $meta->name;
}

local %ENV; # Ensure blank or someone, somewhere will fail..

{
    my $app = mock_app('TestNoStats');
    $app->setup_stats();
    ok !$app->use_stats, 'stats off by default';
}
{
    my $app = mock_app('TestStats');
    $app->setup_stats(1);
    ok $app->use_stats, 'stats on if you say >setup_stats(1)';
}
{
    my $app = mock_app('TestStatsDebugTurnsStatsOn');
    $app->meta->add_method('debug' => sub { 1 });
    $app->setup_stats();
    ok $app->use_stats, 'debug on turns stats on';
}
{
    local %ENV = ( CATALYST_STATS => 1 );
    my $app = mock_app('TestStatsAppStatsEnvSet');
    $app->setup_stats();
    ok $app->use_stats, 'ENV turns stats on';
}
{
    local %ENV = ( CATALYST_STATS => 0 );
    my $app = mock_app('TestStatsAppStatsEnvUnset');
    $app->meta->add_method('debug' => sub { 1 });
    $app->setup_stats(1);
    ok !$app->use_stats, 'ENV turns stats off, even when debug on and ->setup_stats(1)';
}

