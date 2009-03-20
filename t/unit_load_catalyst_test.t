#!perl

use strict;
use warnings;

use FindBin;
use lib         "$FindBin::Bin/lib";
use Test::More  tests => 48;


my $Class   = 'Catalyst::Test';
my $App     = 'TestApp';
my $Pkg     = __PACKAGE__;
my $Url     = 'http://localhost/';
my $Content = "root index";

my %Meth    = (
    $Pkg    => [qw|get request ctx_request|],       # exported
    $Class  => [qw|local_request remote_request|],  # not exported
);

### make sure we're not trying to connect to a remote host -- these are local tests
local $ENV{CATALYST_SERVER};                

use_ok( $Class );

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
    } }
}
