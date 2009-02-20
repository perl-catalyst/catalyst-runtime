#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Test::More tests => 4;
use Test::MockObject;

my $warnings;
BEGIN { # Do this at compile time in case we generate a warning when use
        # DeprecatedTestApp
    $SIG{__WARN__} = sub { $warnings++ if $_[0] =~ /trying to use NEXT/ };
}
use Catalyst; # Cause catalyst to be used so I can fiddle with the logging.
my $mvc_warnings;
BEGIN {
    my $logger = Test::MockObject->new;
    $logger->mock('warn', sub { $mvc_warnings++ if $_[1] =~ /switch your class names/ });
    Catalyst->log($logger);
}

use Catalyst::Test 'DeprecatedTestApp';
is( $mvc_warnings, 1, 'Get the ::MVC:: warning' );

ok( my $response = request('http://localhost/'), 'Request' );
is( $response->header('X-Catalyst-Plugin-Deprecated'), '1', 'NEXT plugin ran correctly' );

SKIP: {
    skip 'non-dev release', 1 unless Catalyst::_IS_DEVELOPMENT_VERSION();
    is( $warnings, 1, 'Got one and only one Adopt::NEXT warning');
}
