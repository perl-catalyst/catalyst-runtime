use FindBin;
use lib "$FindBin::Bin/lib";
use Catalyst::Test 'TestApp', {default_host => 'default.com'};
use Catalyst::Request;

use Test::More;

# test redirect
{
    my $request  =
      HTTP::Request->new( GET => 'http://localhost:3000/test_redirect' );

    ok( my $response = request($request), 'Request' );
    is( $response->code, 302, 'Response Code' );

    # When no body and no content_type has been set, redirecting should set both.
    is( $response->header( 'Content-Type' ), 'text/html; charset=utf-8', 'Content Type' );
    like( $response->content, qr/<body>/, 'Content contains HTML body' );
}

# test redirect without a body and but with a content_type set explicitly by the developer
{
    my $request  =
        HTTP::Request->new( GET => 'http://localhost:3000/test_redirect_with_contenttype' );

    ok( my $response = request($request), 'Request' );
    is( $response->code, 302, 'Response Code' );

    # When the developer has not set content body, we set it. The content type must always match the body, so it should be overwritten.
    is( $response->header( 'Content-Type' ), 'text/html; charset=utf-8', 'Content Type' );
    like( $response->content, qr/<body>/, 'Content contains HTML body' );
}

# test redirect without a body and but with a content_type set explicitly by the developer
{
    my $request  =
        HTTP::Request->new( GET => 'http://localhost:3000/test_redirect_with_content' );

    ok( my $response = request($request), 'Request' );
    is( $response->code, 302, 'Response Code' );

    # When the developer sets both the content body and content type, the set content body and content_type should get through.
    like( $response->header( 'Content-Type' ), qr{text/plain}, 'Content Type' );
    like( $response->content, qr/kind sir/, 'Content contains content set by the Controller' );
}

# test redirect with dodgy host
{
    local $Catalyst::Test::default_host = "-->\">'>'\"<sfi000003v407412>";
    my $request  =
      HTTP::Request->new( GET => 'http://localhost:3000/test_redirect_uri_for');

    ok( my $response = request($request), 'Request' );
    is( $response->code, 302, 'Response Code' );

    # When no body and no content_type has been set, redirecting should set both.
    is( $response->header( 'Content-Type' ), 'text/html; charset=utf-8', 'Content Type' );
    like( $response->content, qr/<body>/, 'Content contains HTML body' );
    like( $response->content, qr/href="[^"]+">here<\/a>/, 'link doesn\'t have xss' );
}

done_testing;

