use strict;
use warnings;

use Test::More tests => 4;

use Catalyst::Utils;

##############################################################################
### No env vars defined
##############################################################################
{
    ok( !Catalyst::Utils::env_value( 'MyApp', 'Key' ),
        'No env values defined returns false'
    );
}

##############################################################################
### App env var defined
##############################################################################
{
    $ENV{'MYAPP2_KEY'} = 'Env value 2';
    is( Catalyst::Utils::env_value( 'MyApp2', 'Key' ),
        'Env value 2', 'Got the right value from the application var' );
}

##############################################################################
### Catalyst env var defined
##############################################################################
{
    $ENV{'CATALYST_KEY'} = 'Env value 3';
    is( Catalyst::Utils::env_value( 'MyApp3', 'Key' ),
        'Env value 3', 'Got the right value from the catalyst var' );
}

##############################################################################
### Catalyst and Application env vars defined
##############################################################################
{
    $ENV{'CATALYST_KEY'} = 'Env value bad';
    $ENV{'MYAPP4_KEY'}   = 'Env value 4';
    is( Catalyst::Utils::env_value( 'MyApp4', 'Key' ),
        'Env value 4', 'Got the right value from the application var' );
}

