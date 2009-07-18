use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More tests => 6;
use Catalyst::Test 'TestApp';

{
    my $response = request('http://localhost/anon/test');
    ok($response->is_success);
    is($response->header('X-Component-Name-Action'),
        'TestApp::Controller::Anon', 'Action can see correct _component_name');
    isnt($response->header('X-Component-Instance-Name-Action'),
        'TestApp::Controller::Anon', 'ref($controller) ne _component_name');
    is($response->header('X-Component-Name-Controller'),
        'TestApp::Controller::Anon', 'Controller can see correct _component_name');
    is($response->header('X-Class-In-Action'),
        'TestApp::Controller::Anon', '$action->class is _component_name');
    is($response->header('X-Anon-Trait-Applied'),
        '1', 'Anon controller class has trait applied correctly');
}

