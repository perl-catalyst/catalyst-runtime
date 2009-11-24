use strict;
use warnings;

use Test::More tests => 30;
use Test::Exception;

use Catalyst ();

sub mock_app {
    my $name = shift;
    print "Setting up mock application: $name\n";
    my $meta = Moose->init_meta( for_class => $name );
    $meta->superclasses('Catalyst');
    return $meta->name;
}

sub test_log_object {
    my ($log, %expected) = @_;
    foreach my $level (keys %expected) {
        my $method_name = "is_$level";
        if ($expected{$level}) {
            ok( $log->$method_name(), "Level $level on" );
        }
        else {
            ok( !$log->$method_name(), "Level $level off" );
        }
    }
}

local %ENV = %ENV;

# Remove all relevant env variables to avoid accidental fail
foreach my $name (grep { /^(CATALYST|TESTAPP)/ } keys %ENV) {
    delete $ENV{$name};
}

{
    my $app = mock_app('TestAppParseLogLevels');
    $app->setup_log('error,warn');
    ok !$app->debug, 'Not in debug mode';
    test_log_object($app->log,
        fatal => 1,
        error => 1,
        warn => 1,
        info => 0,
        debug => 0,
    );
}
{
    local %ENV = %ENV;
    $ENV{CATALYST_DEBUG} = 1;
    my $app = mock_app('TestAppLogDebugEnvSet');
    $app->setup_log('');
    ok $app->debug, 'In debug mode';
    test_log_object($app->log,
        fatal => 1,
        error => 1,
        warn => 1,
        info => 1,
        debug => 1,
    );
}
{
    local %ENV = %ENV;
    $ENV{CATALYST_DEBUG} = 0;
    my $app = mock_app('TestAppLogDebugEnvUnset');
    $app->setup_log('warn');
    ok !$app->debug, 'Not In debug mode';
    test_log_object($app->log,
        fatal => 1,
        error => 1,
        warn => 1,
        info => 0,
        debug => 0,
    );
}
{
    my $app = mock_app('TestAppLogEmptyString');
    $app->setup_log('');
    ok !$app->debug, 'Not In debug mode';
    # Note that by default, you get _all_ the log levels turned on
    test_log_object($app->log,
        fatal => 1,
        error => 1,
        warn => 1,
        info => 1,
        debug => 1,
    );
}
{
    my $app = mock_app('TestAppLogDebugOnly');
    $app->setup_log('debug');
    ok $app->debug, 'In debug mode';
    test_log_object($app->log,
        fatal => 1,
        error => 1,
        warn => 1,
        info => 1,
        debug => 1,
    );
}
