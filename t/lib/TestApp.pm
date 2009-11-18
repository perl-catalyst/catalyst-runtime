package TestApp;

use strict;
use Catalyst qw/
    Test::MangleDollarUnderScore
    Test::Errors 
    Test::Headers 
    Test::Plugin
    Test::Inline
    +TestApp::Plugin::FullyQualified
    +TestApp::Plugin::AddDispatchTypes
    +TestApp::Role
/;
use Catalyst::Utils;
use TestApp::Context;

use Moose;
use namespace::autoclean;

our $VERSION = '0.01';

TestApp->config( name => 'TestApp', root => '/some/dir' );

TestApp->context_class( 'TestApp::Context' );
TestApp->setup;

{
    no warnings 'redefine';
    sub Catalyst::Log::error { }
}

# Make sure we can load Inline plugins. 

package Catalyst::Plugin::Test::Inline;

use strict;

use base qw/Class::Data::Inheritable/;

1;
