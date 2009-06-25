use strict;
use warnings;
use Class::MOP::Class;
use Catalyst::Runtime;

use Test::More tests => 29;

{
    # Silence the log.
    my $meta = Catalyst::Log->meta;
    $meta->make_mutable;
    $meta->remove_method('_send_to_log');
    $meta->add_method('_send_to_log', sub {});
}

sub build_test_app_with_setup {
    my ($name, @flags) = @_;
    my $flags = '(' . join(', ', map { "'".$_."'" } @flags) . ')';
    $flags = '' if $flags eq '()';
    eval qq{
        package $name;
        use Catalyst $flags;
        $name->setup;
    };
    die $@ if $@;
    return $name;
}

local %ENV; # Don't allow env variables to mess us up.

{
    my $app = build_test_app_with_setup('MyTestDebug', '-Debug');

    ok my $c = MyTestDebug->new, 'Get debug app object';
    ok my $log = $c->log, 'Get log object';
    isa_ok $log, 'Catalyst::Log', 'It should be a Catalyst::Log object';
    ok $log->is_warn, 'Warnings should be enabled';
    ok $log->is_error, 'Errors should be enabled';
    ok $log->is_fatal, 'Fatal errors should be enabled';
    ok $log->is_info, 'Info should be enabled';
    ok $log->is_debug, 'Debugging should be enabled';
    ok $app->debug, 'debug method should return true';
}

{
    my $app = build_test_app_with_setup('MyTestLogParam', '-Log=warn,error,fatal');

    ok my $c = $app->new, 'Get log app object';
    ok my $log = $c->log, 'Get log object';
    isa_ok $log, 'Catalyst::Log', 'It should be a Catalyst::Log object';
    ok $log->is_warn, 'Warnings should be enabled';
    ok $log->is_error, 'Errors should be enabled';
    ok $log->is_fatal, 'Fatal errors should be enabled';
    ok !$log->is_info, 'Info should be disabled';
    ok !$log->is_debug, 'Debugging should be disabled';
    ok !$c->debug, 'Catalyst debugging is off';
}
{
    my $app = build_test_app_with_setup('MyTestNoParams');

    ok my $c = $app->new, 'Get log app object';
    ok my $log = $c->log, 'Get log object';
    isa_ok $log, 'Catalyst::Log', 'It should be a Catalyst::Log object';
    ok $log->is_warn, 'Warnings should be enabled';
    ok $log->is_error, 'Errors should be enabled';
    ok $log->is_fatal, 'Fatal errors should be enabled';
    ok $log->is_info, 'Info should be enabled';
    ok $log->is_debug, 'Debugging should be enabled';
    ok !$c->debug, 'Catalyst debugging turned off';
}
my $log_meta = Class::MOP::Class->create_anon_class(
    methods => { map { $_ => sub { 0 } } qw/debug error fatal info warn/ },
);
{
    package MyTestAppWithOwnLogger;
    use base qw/Catalyst/;
    __PACKAGE__->log($log_meta->new_object);
    __PACKAGE__->setup('-Debug');
}

ok my $c = MyTestAppWithOwnLogger->new, 'Get with own logger app object';
ok $c->debug, '$c->debug is true';

