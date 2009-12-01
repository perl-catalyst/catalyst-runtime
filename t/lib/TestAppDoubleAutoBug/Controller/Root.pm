package TestAppDoubleAutoBug::Controller::Root;

use base 'Catalyst::Controller';

__PACKAGE__->config->{namespace} = '';

sub auto : Private {
    my ( $self, $c ) = @_;
    ++$c->stash->{auto_count};
    return 1;
}

sub default : Private {
    my ( $self, $c ) = @_;
    $c->res->body( sprintf 'default, auto=%d', $c->stash->{auto_count} );
}

sub end : Private {
    my ($self,$c) = @_;
}

1;
