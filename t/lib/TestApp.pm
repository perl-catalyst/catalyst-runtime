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

# -----------
# t/aggregate/unit_core_ctx_attr.t pukes until lazy is true
package Greeting;
use Moose;
sub hello_notlazy { 'hello there' }
sub hello_lazy    { 'hello there' }

package TestApp;
has 'my_greeting_obj_notlazy' => (
   is      => 'ro',
   isa     => 'Greeting',
   default => sub { Greeting->new() },
   handles => [ qw( hello_notlazy ) ],
   lazy    => 0,
);
has 'my_greeting_obj_lazy' => (
   is      => 'ro',
   isa     => 'Greeting',
   default => sub { Greeting->new() },
   handles => [ qw( hello_lazy ) ],
   lazy    => 1,
);
# -----------

our $VERSION = '0.01';

TestApp->config( 
    name => 'TestApp', 
    root => '/some/dir', 
    use_request_uri_for_path => 1, 
    'Controller::Action::Action' => {
        action_args => {
            action_action_nine => { another_extra_arg => 13 }
        }
    },
    abort_chain_on_error_fix => 1,
);

# Test bug found when re-adjusting the metaclass compat code in Moose
# in 292360. Test added to Moose in 4b760d6, but leave this attribute
# above ->setup so we have some generated methods to be double sure.
has an_attribute_before_we_change_base_classes => ( is => 'ro');

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

# Pretend to be Plugin::Session and hook finalize_headers to send a header

sub finalize_headers {
    my $c = shift;

    $c->res->header('X-Test-Header', 'valid');

    my $call_count = $c->stash->{finalize_headers_call_count} || 0;
    $call_count++;
    $c->stash(finalize_headers_call_count => $call_count);
    $c->res->header('X-Test-Header-Call-Count' => $call_count);

    return $c->maybe::next::method(@_);
}

# Make sure we can load Inline plugins. 

package Catalyst::Plugin::Test::Inline;

use strict;

use base qw/Class::Data::Inheritable/;

1;
