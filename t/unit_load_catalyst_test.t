#!perl

use strict;
use warnings;

use Test::More;
use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Catalyst::Utils;
use HTTP::Request::Common;

plan tests => 11;

use_ok('Catalyst::Test');

eval "get('http://localhost')";
isnt( $@, "", "get returns an error message with no app specified");

eval "request('http://localhost')";
isnt( $@, "", "request returns an error message with no app specified");

# FIXME - These vhosts in tests tests should be somewhere else...

sub customize { Catalyst::Test::_customize_request(@_) }

{
    my $req = Catalyst::Utils::request('/dummy');
    customize( $req );
    is( $req->header('Host'), undef, 'normal request is unmodified' );
}

{
    my $req = Catalyst::Utils::request('/dummy');
    customize( $req, { host => 'customized.com' } );
    like( $req->header('Host'), qr/customized.com/, 'request is customizable via opts hash' );
}

{
    my $req = Catalyst::Utils::request('/dummy');
    local $Catalyst::Test::default_host = 'localized.com';
    customize( $req );
    like( $req->header('Host'), qr/localized.com/, 'request is customizable via package var' );
}

{
    my $req = Catalyst::Utils::request('/dummy');
    local $Catalyst::Test::default_host = 'localized.com';
    customize( $req, { host => 'customized.com' } );
    like( $req->header('Host'), qr/customized.com/, 'opts hash takes precedence over package var' );
}

{
    my $req = Catalyst::Utils::request('/dummy');
    local $Catalyst::Test::default_host = 'localized.com';
    customize( $req, { host => '' } );
    is( $req->header('Host'), undef, 'default value can be temporarily cleared via opts hash' );
}

# Back compat test, extra args used to be ignored, now a hashref of options.
use_ok('Catalyst::Test', 'TestApp', 'foobar');

# Back compat test, ensure that request ignores anything which isn't a hash.
lives_ok {
    request(GET('/dummy'), 'foo');
} 'scalar additional param to request method ignored';
lives_ok {
    request(GET('/dummy'), []);
} 'array additional param to request method ignored';
