#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../live/lib";

use Test::More;
use Catalyst::Test 'TestApp';
use Catalyst::Request;
use Config;

if ( $Config{useithreads} && !$ENV{CATALYST_SERVER} ) {
    require threads;
    plan tests => 3;
}
else {
    if ( $ENV{CATALYST_SERVER} ) {
        plan skip_all => 'Using remote server';
    }
    else {
        plan skip_all => 'Needs a Perl with ithreads enabled';
    }
}
 
no warnings 'redefine';
sub request {
    my $thr = threads->new( 
        sub { TestApp->run(@_) },
        @_ 
    );
    $thr->join;
}

# test that running inside a thread works ok
{
    my @expected = qw[
        TestApp::Controller::Action::Default->begin
        TestApp::Controller::Action::Default->default
        TestApp::View::Dump::Request->process
        TestApp->end
    ];

    my $expected = join( ", ", @expected );
    
    ok( my $response = request('http://localhost/action/default'), 'Request' );
    ok( $response->is_success, 'Response Successful 2xx' );
    is( $response->header('X-Catalyst-Executed'), $expected, 'Executed actions' );
}
