package TestApp::ActionRole::TestMatchCaptures;

use Moose::Role;
use namespace::autoclean;

sub match_captures {
    my ($self, $c, $cap) = @_;
    if ($cap->[0] eq 'force') {
        $c->res->header( 'X-TestAppActionTestMatchCaptures', 'forcing' );
        return 1;
    } else {
        $c->res->header( 'X-TestAppActionTestMatchCaptures', 'fallthrough' );
        return 0;
    }
}

1;