use FindBin;
use lib "$FindBin::Bin/lib";
use Catalyst::Test 'TestApp';

use Test::More tests => 5;

content_like('/',qr/root/,'content check');
action_ok('/','Action ok ok','normal action ok');
action_redirect('/engine/response/redirect/one','redirect check');
action_notfound('/engine/response/status/s404','notfound check');
contenttype_is('/action/local/one','text/plain','Contenttype check');