#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../../lib";

use Test::More tests => 10;
use Catalyst::Test 'TestApp';
    
for ( 1 .. 1 ) {
    # test root index
    {
        ok( my $response = request('http://localhost/'), 'root index' );
        is( $response->content, 'root index', 'root index ok' );
        
        ok( $response = request('http://localhost'), 'root index no slash' );
        is( $response->content, 'root index', 'root index no slash ok' );
    }
    
    # test controller index
    {
        ok( my $response = request('http://localhost/action/index/'), 'controller index' );
        is( $response->content, 'Action::Index index', 'controller index ok' );
        
        ok( $response = request('http://localhost/action/index'), 'controller index no slash' );
        is( $response->content, 'Action::Index index', 'controller index no slash ok' );        
    }
    
    # test controller default when index is present
    {
        ok( my $response = request('http://localhost/action/index/foo'), 'default with index' );
        is( $response->content, "Error - TestApp::Controller::Action\n", 'default with index ok' );
    }
}
