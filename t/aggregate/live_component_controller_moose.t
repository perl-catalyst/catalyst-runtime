use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More tests => 7;
use Catalyst::Test 'TestApp';

{
    my $response = request('http://localhost/moose/get_attribute');
    ok($response->is_success);
    is($response->content, '42', 'attribute default values get set correctly');
    is($response->header('X-Catalyst-Test-Before'), 'before called', 'before works as expected');
}

{
    TODO: {
        local $TODO = 'Wrapping methods in a subclass, when the subclass contains no other methods with attributes is broken';
        my $response = request('http://localhost/moose/methodmodifiers/get_attribute');       
        ok($response->is_success);
        is($response->content, '42', 'parent controller method called');
        is($response->header('X-Catalyst-Test-Before'), 'before called', 'before works as expected');
        is($response->header('X-Catalyst-Test-After'), 'after called', 'after works as expected');
    }
}
