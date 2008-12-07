use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;
use Carp ();
$SIG{__DIE__} = \&Carp::confess; # Stacktrace please.

# Doing various silly things, like for example
# use CGI qw/:stanard/ in your conrtoller / app
# will overwrite your meta method, therefore Catalyst
# can't depend on it being there correctly.

# This is/was demonstrated by Catalyst::Controller::WrapCGI
# and Catalyst::Plugin::Cache::Curried

{    
    package TestAppWithMeta;
    use Catalyst;
    sub meta {}
}

lives_ok { TestAppWithMeta->setup } 'Can setup an app which defines its own meta method';
