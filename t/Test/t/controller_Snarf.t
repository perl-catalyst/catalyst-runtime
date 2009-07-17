use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'Snarf' }
BEGIN { use_ok 'Test::Controller::Snarf' }

ok( request('/snarf')->is_success, 'Request should succeed' );


