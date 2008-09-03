use FindBin;
use lib "$FindBin::Bin/lib";
use Catalyst::Test 'TestApp';

use Test::More tests => 5;

content_like('/','foo');
action_ok('/','Action ok ok');
action_redirect('/engine/response/redirect/one');
action_notfound('/engine/response/status/s404');
contenttype_is('text/plain');