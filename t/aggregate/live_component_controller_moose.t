use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More tests => 2;
use Catalyst::Test 'TestApp';

{
    my $response = request('http://localhost/moose/get_attribute');
    ok($response->is_success);
    is($response->content, '42', 'attribute default values get set correctly');
}
