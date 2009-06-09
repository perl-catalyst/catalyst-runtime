package TestAppOneView::Controller::Root;

use base 'Catalyst::Controller';
use Scalar::Util ();

__PACKAGE__->config->{namespace} = '';

sub view_no_args : Local {
    my ( $self, $c ) = @_;

    my $v = $c->view;

    $c->res->body(Scalar::Util::blessed($v));
}

sub view_by_name : Local {
    my ( $self, $c ) = @_;

    my $v = $c->view($c->req->param('view'));

    $c->res->body(Scalar::Util::blessed($v));
}

1;
