use FindBin;
use lib "$FindBin::Bin/lib";
use Catalyst::Test 'TestApp', {default_host => 'default.com'};
use Catalyst::Request;

use Test::More;

{
    my @routes = (
        ["test_remove_body_with_304",
         304 ],
        ["test_remove_body_with_204",
         204 ],
        ["test_remove_body_with_100",
         100 ],
        ["test_nobody_with_100",
         100 ]
    );

    foreach my $element (@routes ) {
        my $route         = $element->[0];
        my $expected_code = $element->[1];
        my $request =
            HTTP::Request->new( GET => "http://localhost:3000/$route" );
        ok( my $response = request($request), "Request for $route");
        is( $response->code,
            $expected_code,
            "Status code for $route is $expected_code");
        is( $response->content,
            '',
            "Body for $route is not present");
    }
}

done_testing;
