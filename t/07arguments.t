package TestApp;

use Catalyst qw[-Engine=Test];

sub foo : Global {
    my ( $self, $c, $arg ) = @_;
    $c->res->output($arg);
}

__PACKAGE__->setup;

package main;

use Test::More tests => 1;
use Catalyst::Test 'TestApp';

ok( get('/foo/bar') =~ /bar/ );
