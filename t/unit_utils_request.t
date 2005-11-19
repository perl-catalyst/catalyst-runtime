use strict;
use warnings;

use Test::More tests => 5;

use_ok('Catalyst::Utils');

{
    my $url = "/dump";
    ok(
        my $request = Catalyst::Utils::request($url),
        "Request: simple get without protocol nor host"
    );
    like( $request->uri, qr|^http://localhost/|,
        " has default protocol and host" );
}

{
    my $url = "/dump?url=http://www.somewhere.com/";
    ok(
        my $request = Catalyst::Utils::request($url),
        "Same with param containing a url"
    );
    like( $request->uri, qr|^http://localhost/|,
        " has default protocol and host" );
}

