package TestApp;

use Catalyst qw[-Engine=Test];

sub testregex : Regex(foo/(.*)) {
        my ( $self, $c ) = @_;
        $c->res->output( $c->req->snippets->[0] );
}

__PACKAGE__->setup();

package main;

use Test::More tests => 1;
use Catalyst::Test 'TestApp';

ok( get('/foo/bar') =~ /bar/ );
