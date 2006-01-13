use strict;
use warnings;

use Test::More tests => 24;
use Test::NoWarnings;    # Adds an extra test.

my $timestamp = '\[\w{3}\s\w{3}\s[ 123]\d\s\d{2}:\d{2}:\d{2}\s\d{4}\]';
my $LOG;

BEGIN {
    chdir 't' if -d 't';
    use lib '../lib';
    $LOG = 'Catalyst::Log';
    use_ok $LOG or die;
}
my @MESSAGES;
{
    no warnings 'redefine';
    *Catalyst::Log::_send_to_log = sub {
        my $self = shift;
        push @MESSAGES, @_;
    };
}

can_ok $LOG, 'new';
ok my $log = $LOG->new, '... and creating a new log object should succeed';
isa_ok $log, $LOG, '... and the object it returns';

can_ok $log, 'is_info';
ok $log->is_info, '... and the default behavior is to allow info messages';

can_ok $log, 'info';
ok $log->info('hello there!'),
    '... passing it an info message should succeed';

can_ok $log, "_flush";
$log->_flush;
ok @MESSAGES, '... and flushing the log should succeed';
is scalar @MESSAGES, 1, '... with one log message';
like $MESSAGES[0], qr/^$timestamp \[catalyst\] \[info\] hello there!$/,
    '... which should match the format we expect';

{

    package Catalyst::Log::Subclass;
    our @ISA = 'Catalyst::Log';

    sub _send_to_log {
        my $self = shift;
        push @MESSAGES, '---';
        push @MESSAGES, @_;
    }
}

my $SUBCLASS = 'Catalyst::Log::Subclass';
can_ok $SUBCLASS, 'new';
ok $log = Catalyst::Log::Subclass->new,
    '... and the log subclass constructor shoudl return a new object';
isa_ok $log, $SUBCLASS, '... and the object it returns';
isa_ok $log, $LOG,      '... and it also';

can_ok $log, 'info';
ok $log->info('hi there!'),
    '... passing it an info message should succeed';

can_ok $log, "_flush";
@MESSAGES = (); # clear the message log
$log->_flush;
ok @MESSAGES, '... and flushing the log should succeed';
is scalar @MESSAGES, 2, '... with two log messages';
is $MESSAGES[0], '---', '... with the first one being our new data';
like $MESSAGES[1], qr/^$timestamp \[catalyst\] \[info\] hi there!$/,
    '... which should match the format we expect';

