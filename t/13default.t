package TestApp;

use Catalyst qw[-Engine=Test];

sub default : Private {
    my ( $self, $c ) = @_;
    $c->res->output('bar');
}

__PACKAGE__->setup;

package TestApp::C::Foo::Bar;

use base 'Catalyst::Base';

sub default : Private {
    my ( $self, $c ) = @_;
    $c->res->output('yada');
}

package main;

use Test::More tests => 2;
use Catalyst::Test 'TestApp';

ok( get('/foo')         =~ /bar/ );
ok( get('/foo/bar/foo') =~ /yada/ );
