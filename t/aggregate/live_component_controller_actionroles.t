use strict;
use warnings;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Catalyst::Test 'TestApp';

my %roles = (
    foo  => 'TestApp::ActionRole::Guff',
    bar  => 'TestApp::ActionRole::Guff',
    baz  => 'Guff',
    quux => 'Catalyst::ActionRole::Zoo',
);

while (my ($path, $role) = each %roles) {
    my $resp = request("/actionroles/${path}");
    ok($resp->is_success);
    is($resp->content, $role);
    is($resp->header('X-Affe'), 'Tiger');
}

{
    my $resp = request("/actionroles/corge");
    ok($resp->is_success);
    is($resp->content, 'TestApp::ActionRole::Guff');
    is($resp->header('X-Affe'), 'Tiger');
    is($resp->header('X-Action-After'), 'moo');
}
{
    my $resp = request("/actionroles/frew");
    ok($resp->is_success);
    is($resp->content, 'hello', 'action_args are honored with ActionRoles');
 }
done_testing;
