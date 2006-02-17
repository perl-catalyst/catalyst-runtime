package TestApp;

use strict;
use Catalyst qw/
    Test::Errors 
    Test::Headers 
    Test::Plugin
    +TestApp::Plugin::FullyQualified
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
    my $action = "$_[1]";

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

sub class_forward_test_method {
    my ( $self, $c ) = @_;
    $c->response->headers->header( 'X-Class-Forward-Test-Method' => 1 );
}

{
    no warnings 'redefine';
    sub Catalyst::Log::error { }
}
1;
