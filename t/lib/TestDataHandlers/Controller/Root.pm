package TestDataHandlers::Controller::Root;

use base 'Catalyst::Controller';

sub test_json :Local {
    my ($self, $c) = @_;
    $c->res->body($c->req->body_data->{message});
}

sub test_nested_for :Local {
    my ($self, $c) = @_;
    $c->res->body($c->req->body_data->{nested}->{value});
}

1;
