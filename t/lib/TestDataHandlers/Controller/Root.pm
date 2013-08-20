package TestDataHandlers::Controller::Root;

use base 'Catalyst::Controller';

sub test_json :Local {
    my ($self, $c) = @_;
    $c->res->body($c->req->body_data->{message});
}

1;
