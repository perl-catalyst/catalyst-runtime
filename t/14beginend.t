package TestApp;

use Catalyst qw[-Engine=Test];


sub begin : Private { 
    my ( $self, $c ) = @_;
    $c->res->output('foo');
}

sub default : Private { }

sub end : Private { 
    my ( $self, $c ) = @_;
    $c->res->output( $c->res->output . 'bar' );
}


__PACKAGE__->setup;

package TestApp::C::Foo::Bar;

use base 'Catalyst::Base';

sub begin : Private { 
    my ( $self, $c ) = @_;
    $c->res->output('yada');
}

sub default : Private { }

sub end : Private { 
    my ( $self, $c ) = @_;
    $c->res->output( $c->res->output . 'yada' );
}

package main;

use Test::More tests => 2;
use Catalyst::Test 'TestApp';

ok( get('/foo')         =~ /foobar/ );
ok( get('/foo/bar/foo') =~ /yadayada/ );
