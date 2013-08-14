use strict;
use warnings;
use Test::More;

BEGIN { $ENV{TESTAPP_ENCODING} = 'UTF-8' };

# setup library path
use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
if ( !eval { require Test::WWW::Mechanize::Catalyst } || ! Test::WWW::Mechanize::Catalyst->VERSION('0.51') ) {
    plan skip_all => 'Need Test::WWW::Mechanize::Catalyst for this test';
}
}

# make sure testapp works
use_ok('TestAppUnicode');

use Test::WWW::Mechanize::Catalyst 'TestAppUnicode';
my $mech = Test::WWW::Mechanize::Catalyst->new;

{
    TestAppUnicode->encoding('UTF-8');
    $mech->get_ok('http://localhost/unicode', 'encoding configured ok');
}

done_testing;

