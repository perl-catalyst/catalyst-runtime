use strict;
use warnings;
use Test::More;
use HTTP::Request::Common qw/GET POST DELETE PUT /;
 
use FindBin;
use lib "$FindBin::Bin/../lib";

use Catalyst::Test 'TestApp';
 
is(request(GET    '/httpmethods/foo')->content, 'get');
is(request(POST   '/httpmethods/foo')->content, 'post');
is(request(DELETE '/httpmethods/foo')->content, 'default');
 
is(request(GET    '/httpmethods/bar')->content, 'get or post');
is(request(POST   '/httpmethods/bar')->content, 'get or post');
is(request(DELETE '/httpmethods/bar')->content, 'default');
 
is(request(GET    '/httpmethods/baz')->content, 'any');
is(request(POST   '/httpmethods/baz')->content, 'any');
is(request(DELETE '/httpmethods/baz')->content, 'any');

is(request(GET    '/httpmethods/chained_get')->content,    'chained_get');
is(request(POST   '/httpmethods/chained_post')->content,   'chained_post');
is(request(PUT    '/httpmethods/chained_put')->content,    'chained_put');
is(request(DELETE '/httpmethods/chained_delete')->content, 'chained_delete');

is(request(GET    '/httpmethods/get_put_post_delete')->content, 'get2');
is(request(POST   '/httpmethods/get_put_post_delete')->content, 'post2');
is(request(PUT    '/httpmethods/get_put_post_delete')->content, 'put2');
is(request(DELETE '/httpmethods/get_put_post_delete')->content, 'delete2');

is(request(GET    '/httpmethods/check_default')->content, 'get3');
is(request(POST   '/httpmethods/check_default')->content, 'post3');
is(request(PUT    '/httpmethods/check_default')->content, 'chain_default');

done_testing;
