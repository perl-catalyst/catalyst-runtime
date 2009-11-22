#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Test::More tests => 4;

my $warnings;
BEGIN { # Do this at compile time in case we generate a warning when use
        # DeprecatedTestApp
    $SIG{__WARN__} = sub {
        $warnings++ if $_[0] =~ /uses NEXT, which is deprecated/;
        $warnings++ if $_[0] =~ /trying to use NEXT, which is deprecated/;
    };
}
use Catalyst; # Cause catalyst to be used so I can fiddle with the logging.
my $mvc_warnings;
BEGIN {
    my $logger = Class::MOP::Class->create_anon_class(
    methods => {
        debug => sub {0},
        info  => sub {0},
        warn => sub {
            if ($_[1] =~ /switch your class names/) {
               $mvc_warnings++;
                return;
            }
            die "Caught unexpected warning: " . $_[1];
        },
    },
)->new_object;
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
