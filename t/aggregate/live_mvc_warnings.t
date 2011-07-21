use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;
use Catalyst::Test 'TestAppMVCWarnings';

if ( $ENV{CATALYST_SERVER} ) {
    plan skip_all => 'Using remote server';
}

{
    ok( request('http://localhost/view'), 'Request' );
    like($TestAppMVCWarnings::log_messages[0], qr/Calling \$c->view\(\) is not supported/s, 'View failure warning received');

    @TestAppMVCWarnings::log_messages = ();

    ok( request('http://localhost/model'), 'Request' );
    like($TestAppMVCWarnings::log_messages[0], qr/Calling \$c->model\(\) is not supported/s, 'Model failure warning received');
}

done_testing;

