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

use Moose;
use namespace::autoclean;

our $VERSION = '0.01';

TestApp->config( name => 'TestApp', root => '/some/dir' );

if ($::setup_leakchecker && eval { Class::MOP::load_class('CatalystX::LeakChecker'); 1 }) {
    with 'CatalystX::LeakChecker';

    has leaks => (
        is      => 'ro',
        default => sub { [] },
    );
}

sub found_leaks {
    my ($ctx, @leaks) = @_;
    push @{ $ctx->leaks }, @leaks;
}

sub count_leaks {
    my ($ctx) = @_;
    return scalar @{ $ctx->leaks };
}

TestApp->setup;

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
    no warnings 'recursion';
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

{
    no warnings 'redefine';
    sub Catalyst::Log::error { }
}

# Make sure we can load Inline plugins. 

package Catalyst::Plugin::Test::Inline;

use strict;

use base qw/Class::Data::Inheritable/;

1;
