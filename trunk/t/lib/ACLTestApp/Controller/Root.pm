package ACLTestApp::Controller::Root;
use Test::More;

use base 'Catalyst::Controller';

__PACKAGE__->config->{namespace} = '';

sub foobar : Private {
    die $Catalyst::DETACH;
}

sub gorch : Local {
    my ( $self, $c, $frozjob ) = @_;
    is $frozjob, 'wozzle';
    $c->res->body("gorch");
}

1;
