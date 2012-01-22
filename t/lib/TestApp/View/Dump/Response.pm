package TestApp::View::Dump::Response;

use strict;
use base qw[TestApp::View::Dump];

sub process {
    my ( $self, $c ) = @_;
    my $r = $c->response;
    local $r->{_writer};
    local $r->{_reponse_cb};
    return $self->SUPER::process( $c, $r );
}

1;
