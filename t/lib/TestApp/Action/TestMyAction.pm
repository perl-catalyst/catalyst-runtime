package TestApp::Action::TestMyAction;

use strict;
use warnings;

use base qw/Catalyst::Action/;

sub execute {
    my $self = shift;
    my ( $controller, $c, $test ) = @_;
    $c->res->header( 'X-TestAppActionTestMyAction', 'MyAction works' );
    $self->NEXT::execute(@_);
}

1;

