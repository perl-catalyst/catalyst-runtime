package TestApp;

use strict;
use Catalyst qw/
    Test::Errors 
    Test::Headers 
    Test::Plugin
    Test::Inline
    +TestApp::Plugin::FullyQualified
    +TestApp::Plugin::AddDispatchTypes
/;
use Catalyst::Utils;

our $VERSION = '0.01';

TestApp->config( name => 'TestApp', root => '/some/dir' );

TestApp->setup;

sub index : Private {
    my ( $self, $c ) = @_;
    $c->res->body('root index');
}

sub global_action : Private {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub execute {
    my $c      = shift;
    my $class  = ref( $c->component( $_[0] ) ) || $_[0];
    my $action = $_[1]->reverse;

    my $method;

    if ( $action =~ /->(\w+)$/ ) {
        $method = $1;
    }
    elsif ( $action =~ /\/(\w+)$/ ) {
        $method = $1;
    }
    elsif ( $action =~ /^(\w+)$/ ) {
        $method = $action;
    }

    if ( $class && $method && $method !~ /^_/ ) {
        my $executed = sprintf( "%s->%s", $class, $method );
        my @executed = $c->response->headers->header('X-Catalyst-Executed');
        push @executed, $executed;
        $c->response->headers->header(
            'X-Catalyst-Executed' => join ', ',
            @executed
        );
    }

    return $c->SUPER::execute(@_);
}

# Replace the very large HTML error page with
# useful info if something crashes during a test
sub finalize_error {
    my $c = shift;
    
    $c->next::method(@_);
    
    $c->res->status(500);
    $c->res->body( 'FATAL ERROR: ' . join( ', ', @{ $c->error } ) );
}

sub class_forward_test_method :Private {
    my ( $self, $c ) = @_;
    $c->response->headers->header( 'X-Class-Forward-Test-Method' => 1 );
}

sub class_go_test_method :Private {
    my ( $self, $c ) = @_;
    $c->response->headers->header( 'X-Class-Go-Test-Method' => 1 );
}

sub class_visit_test_method :Private {
    my ( $self, $c ) = @_;
    $c->response->headers->header( 'X-Class-Visit-Test-Method' => 1 );
}

sub loop_test : Local {
    my ( $self, $c ) = @_;

    for( 1..1001 ) {
        $c->forward( 'class_forward_test_method' );
    }
}

sub recursion_test : Local {
    my ( $self, $c ) = @_;
    $c->forward( 'recursion_test' );
}

{
    no warnings 'redefine';
    sub Catalyst::Log::error { }
}

# Make sure we can load Inline plugins. 

package Catalyst::Plugin::Test::Inline;

use strict;

use base qw/Catalyst::Base Class::Data::Inheritable/;

1;
