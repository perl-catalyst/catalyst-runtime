use FindBin;
use lib "$FindBin::Bin/lib";
use Catalyst::Test 'TestAppSimple', {default_host => 'default.com'};
use Catalyst::Request;

use Test::More;

content_like('/',qr/root/,'root check');
#content_like('/some_action',qr/some_action/,'some_action check');

done_testing;

