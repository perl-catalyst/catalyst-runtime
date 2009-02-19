use strict;
use warnings;
use Test::More;

BEGIN {
    if (eval 'require Moose; 1') {
        plan tests => 2;
    }
    else {
        plan skip_all => 'Moose is required for this test';
    }
}

use FindBin;
use lib "$FindBin::Bin/lib";

use Catalyst::Test 'TestApp';

{
    my $response = request('http://localhost/moose/get_attribute');
    ok($response->is_success);
    is($response->content, '42', 'attribute default values get set correctly');
}
