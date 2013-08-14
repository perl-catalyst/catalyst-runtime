use strict;
use warnings;

use Data::Dumper;
$Data::Dumper::Maxdepth=1;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More tests => 13;
use Catalyst::Test 'TestApp';

sub ok_actions {
    my ($response, $actions, $msg) = @_;
    my $expected = join ", ",
        (map { "TestApp::Controller::Attributes->$_" } @$actions),
        'TestApp::Controller::Root->end';
    is( $response->header('x-catalyst-executed') => $expected,
        $msg || 'Executed correct acitons');
    }

ok( my $response = request('http://localhost/attributes/view'),
    'get /attributes/view' );
ok( !$response->is_success, 'Response Unsuccessful' );

ok( $response = request('http://localhost/attributes/foo'),
    "get /attributes/foo" );
ok_actions($response => ['foo']);

ok( $response = request('http://localhost/attributes/all_attrs'),
    "get /attributes/all_attrs" );
ok( $response->is_success, "Response OK" );
ok_actions($response => [qw/fetch all_attrs_action/]);

ok( $response = request('http://localhost/attributes/some_attrs'),
    "get /attributes/some_attrs" );
ok( $response->is_success, "Response OK" );
ok_actions($response => [qw/fetch some_attrs_action/]);

ok( $response = request('http://localhost/attributes/one_attr'),
    "get /attributes/one_attr" );
ok( $response->is_success, "Response OK" );
ok_actions($response => [qw/fetch one_attr_action/]);


