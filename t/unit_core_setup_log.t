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

local %ENV; # Ensure blank or someone, somewhere will fail..

{
    my $app = mock_app('TestLogAppParseLevels');
    $app->setup_log('error,warn');
    ok !$app->debug, 'Not in debug mode';
    test_log_object($app->log,
        fatal => 0, # WTF - I thought log levels were additive these days,
                    # or do I not understand the patch which pupported to make
                    # them so?
        error => 1,
        warn => 1,
        info => 0,
        debug => 0,
    );
}
{
    local %ENV = ( CATALYST_DEBUG => 1 );
    my $app = mock_app('TestLogAppDebugEnvSet');
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
    local %ENV = ( CATALYST_DEBUG => 0 );
    my $app = mock_app('TestLogAppDebugEnvUnset');
    $app->setup_log('warn');
    ok !$app->debug, 'Not In debug mode';
    test_log_object($app->log,
        fatal => 0,
        error => 0,
        warn => 1,
        info => 0,
        debug => 0,
    );
}
{
    my $app = mock_app('TestLogAppEmptyString');
    $app->setup_log('');
    ok !$app->debug, 'Not In debug mode';
    TODO: {
        local $TODO = 'THis is insane';
        test_log_object($app->log,
            fatal => 0,
            error => 0,
            warn => 0,
            info => 0,
            debug => 0,
        );
    }
}
{
    my $app = mock_app('TestLogAppDebugOnly');
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
