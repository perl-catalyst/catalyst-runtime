use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;
use Catalyst::Test 'TestApp';

# body '0'
{
    my $res = request('/zerobody');
    is $res->content, '0';
    is $res->header('Content-Length'), '1';
}

# body ''
{
    my $res = request('/emptybody');
    is $res->content, '';
    ok !defined $res->header('Content-Length');
}

done_testing;

