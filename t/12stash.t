package TestApp;

use Catalyst qw[-Engine=Test];

sub foo : Global {
    my ( $self, $c ) = @_;
    $c->stash->{test} ||= 'foo';
    $c->forward('bar');
}
sub bar : Global {
        my ( $self, $c ) = @_;
        $c->stash->{test} ||= 'bar';
        $c->forward('yada');
}
sub yada : Global {
        my ( $self, $c ) = @_;
        $c->stash->{test} ||= 'yada';
        $c->res->output( $c->stash->{test} );
}

__PACKAGE__->setup;

package main;

use Test::More tests => 2;
use Catalyst::Test 'TestApp';

ok( get('/foo') =~ /foo/ );
ok( get('/bar') =~ /bar/ );
