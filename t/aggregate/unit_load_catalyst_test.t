#!perl

use strict;
use warnings;

use Test::More;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use Catalyst::Utils;
use HTTP::Request::Common;
use Test::Exception;

my $Class   = 'Catalyst::Test';
my $App     = 'TestApp';
my $Pkg     = __PACKAGE__;
my $Url     = 'http://localhost/';
my $Content = "root index";

my %Meth    = (
    $Pkg    => [qw|get request ctx_request|],          # exported
    $Class  => [qw|local_request remote_request|],  # not exported
);

### make sure we're not trying to connect to a remote host -- these are local tests
local $ENV{CATALYST_SERVER};

use Catalyst::Test ();

### check available methods
{   ### turn of redefine warnings, we'll get new subs exported
    ### XXX 'no warnings' and 'local $^W' wont work as warnings are turned on in
    ### test.pm, so trap them for now --kane
    {   local $SIG{__WARN__} = sub {};
        ok( $Class->import,     "Argumentless import for methods only" );
    }

    while( my($class, $meths) = each %Meth ) {
        for my $meth ( @$meths ) { SKIP: {

            ### method available?
            can_ok( $class,     $meth );

            ### only for exported methods
            skip "Error tests only for exported methods", 2 unless $class eq $Pkg;

            ### check error conditions
            eval { $class->can($meth)->( $Url ) };
            ok( $@,             "   $meth without app gives error" );
            like( $@, qr/$Class/,
                                "       Error filled with expected content for '$meth'" );
        } }
    }
}

### simple tests for exported methods
{   ### turn of redefine warnings, we'll get new subs exported
    ### XXX 'no warnings' and 'local $^W' wont work as warnings are turned on in
    ### test.pm, so trap them for now --kane
    {   local $SIG{__WARN__} = sub {};
        ok( $Class->import( $App ),
                                "Loading $Class for App $App" );
    }

    ### test exported methods again
    for my $meth ( @{ $Meth{$Pkg} } ) { SKIP: {

        ### do a call, we should get a result and perhaps a $c if it's 'ctx_request';
        my ($res, $c) = eval { $Pkg->can($meth)->( $Url ) };

        ok( 1,                  "   Called $Pkg->$meth( $Url )" );
        ok( !$@,                "       No critical error $@" );
        ok( $res,               "       Result obtained" );

        ### get the content as a string, to make sure we got what we expected
        my $res_as_string = $meth eq 'get' ? $res : $res->content;
        is( $res_as_string, $Content,
                                "           Content as expected: $res_as_string" );

        ### some tests for 'ctx_request'
        skip "Context tests skipped for '$meth'", 6 unless $meth eq 'ctx_request';

        ok( $c,                 "           Context object returned" );
        isa_ok( $c, $App,       "               Object" );
        is( $c->request->uri, $Url,
                                "               Url recorded in request" );
        is( $c->response->body, $Content,
                                "               Content recorded in response" );
        ok( $c->stash,          "               Stash accessible" );
        ok( $c->action,         "               Action object accessible" );
        ok( $res->request,      "               Response has request object" );
        lives_and { is( $res->request->uri, $Url) }
                                "               Request object has correct url";
    } }
}

### perl5.8.8 + cat 5.80's Cat::Test->ctx_request didn't return $c the 2nd
### time it was invoked. Without tracking the bug down all the way, it was
### clearly related to the Moose'ification of Cat::Test and a scoping issue
### with a 'my'd variable. Since the same code works fine in 5.10, a bug in
### either Moose or perl 5.8 is suspected.
{   ok( 1,                      "Testing consistency of ctx_request()" );
    for( 1..2 ) {
        my($res, $c) = ctx_request( $Url );
        ok( $c,                 "   Call $_: Context object returned" );
    }
}

# FIXME - These vhosts in tests tests should be somewhere else...

sub customize { Catalyst::Test::_customize_request($_[0], {}, @_[1 .. $#_]) }

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

done_testing;
