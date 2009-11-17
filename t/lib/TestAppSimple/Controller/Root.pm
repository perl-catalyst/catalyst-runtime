package TestAppSimple::Controller::Root;
use base 'Catalyst::Controller';
use Scalar::Util ();

__PACKAGE__->config->{namespace} = '';

sub index : Private {
    my ( $self, $c ) = @_;
    $c->res->body('root index');
}

sub some_action : Local {
    my ( $self, $c ) = @_;
    $c->res->body('some_action');
}


1;
