use strict;
use warnings;
use Catalyst::Runtime;

use Test::More tests => 18;

{
    # Silence the log.
    no warnings 'redefine';
    *Catalyst::Log::_send_to_log = sub {};
}

TESTDEBUG: {
    package MyTestDebug;
    use parent qw/Catalyst/;
    __PACKAGE__->setup(
        '-Debug',
    );
}

ok my $c = MyTestDebug->new, 'Get debug app object';
ok my $log = $c->log, 'Get log object';
isa_ok $log,        'Catalyst::Log', 'It should be a Catalyst::Log object';
ok !$log->is_warn,  'Warnings should be disabled';
ok !$log->is_error, 'Errors should be disabled';
ok !$log->is_fatal, 'Fatal errors should be disabled';
ok !$log->is_info,  'Info should be disabled';
ok $log->is_debug,  'Debugging should be enabled';
can_ok 'MyTestDebug', 'debug';
ok +MyTestDebug->debug, 'And it should return true';


TESTAPP: {
    package MyTestLog;
    use parent qw/Catalyst/;
    __PACKAGE__->setup(
        '-Log=warn,error,fatal'
    );
}

ok $c = MyTestLog->new, 'Get log app object';
ok $log = $c->log, 'Get log object';
isa_ok $log,        'Catalyst::Log', 'It should be a Catalyst::Log object';
ok $log->is_warn,   'Warnings should be enabled';
ok $log->is_error,  'Errors should be enabled';
ok $log->is_fatal,  'Fatal errors should be enabled';
ok !$log->is_info,  'Info should be disabled';
ok !$log->is_debug, 'Debugging should be disabled';
