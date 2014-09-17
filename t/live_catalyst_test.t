use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use Catalyst::Test 'TestApp', {default_host => 'default.com'};
use Catalyst::Request;
use HTTP::Request::Common;

use Test::More;
use Test::Exception;

content_like('/',qr/root/,'content check');
action_ok('/','Action ok ok','normal action ok');
action_redirect('/engine/response/redirect/one','redirect check');
action_notfound('/engine/response/status/s404','notfound check');

# so we can see the default test name
action_ok('/');

contenttype_is('/action/local/one','text/plain','Contenttype check');

### local_request() was not setting response base from base href
{
    my $response = request('/base_href_test');
    is( $response->base, 'http://www.example.com/', 'response base set from base href');
}

my $creq;
my $req = '/dump/request';

{
    eval '$creq = ' . request($req)->content;
    is( $creq->uri->host, 'default.com', 'request targets default host set via import' );
}

{
    local $Catalyst::Test::default_host = 'localized.com';
    eval '$creq = ' . request($req)->content;
    is( $creq->uri->host, 'localized.com', 'target host is mutable via package var' );
}

{
    my %opts = ( host => 'opthash.com' );
    eval '$creq = ' . request($req, \%opts)->content;
    is( $creq->uri->host, $opts{host}, 'target host is mutable via options hashref' );
}

{
	my $response = request( POST( '/bodyparams', { override => 'this' } ) )->content;
    is($response, 'that', 'body param overridden');
}

{
	my $response = request( POST( '/bodyparams/no_params' ) )->content;
    is($response, 'HASH', 'empty body param is hashref');
}

{
	eval '$creq = ' . request($req, { headers => { host => 'www.headers.com' } })->content;
	is( $creq->uri->host, 'www.headers.com', 'Setting host via headers works' );
}

{
	throws_ok( sub { request($req, { headers => { host => 'www.headers.com' }, host => 'adad'} ) },
			qr{'host' and 'headers->{host}' both exist. Use ONLY ONE},
			'Correct exception thrown for using host and headers->{host}'
	);
}

{
	eval '$creq = ' . request($req, { headers => {
							'X-HEAD1'	=> 'First Header',
							'X-HEAD2'	=> 'Second Header',
					} } )->content;
	is( $creq->headers->header('X-HEAD1'), 'First Header', 'First header is correct' );
	is( $creq->headers->header('X-HEAD2'), 'Second Header', 'Second header is correct' );
}

done_testing;

