#!perl

use Test::More tests => 2;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

my @MESSAGES = ();

{
    package Catalyst::Log::Unit;
    use base qw/Catalyst::Log/;

}

use Catalyst::Test 'TestApp';

TestApp->setup;

my $unit = Catalyst::Log::Unit->new;

TestApp->log( $unit);

TestApp->config->{Debug}->{redact_parameters} = [ 'and this' ];

TestApp->log_parameters(
    'Query Parameters are',
    {
        'this is' => 'a unit test',
        'and this' => 'is hidden' 
    }
);

my $body = $unit->_body;

like($body, qr/this is\s*\|\s*a unit test/);
like($body, qr/and this\s*\|\s*\(redacted by config\)/);


