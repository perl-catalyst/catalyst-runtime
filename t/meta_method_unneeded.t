use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Test::More tests => 2;
use Test::Exception;
use Carp ();

# Doing various silly things, like for example
# use CGI qw/:standard/ in your conrtoller / app
# will overwrite your meta method, therefore Catalyst
# can't depend on it being there correctly.

# This is/was demonstrated by Catalyst::Controller::WrapCGI
# and Catalyst::Plugin::Cache::Curried

{    
    package TestAppWithMeta;
    use Catalyst;
    no warnings 'redefine';
    sub meta {}
}
BEGIN {
    lives_ok { TestAppWithMeta->setup } 'Can setup an app which defines its own meta method';
}

use Catalyst::Test 'TestAppWithMeta';

ok( request('/')->is_success );

