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
    my $response = request('http://localhost/moose/the_answer');
    ok($response->is_success);
    is($response->content, 'the meaning of life: 42', 'attr defaults + BUILD works correctly');
}
